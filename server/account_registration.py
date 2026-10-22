"""Development account boundary: invitation + SMS proof + verified WebAuthn passkey.

Not exposed by the legacy loopback HTTP demo. SMS is disabled unless an operator
explicitly injects a provider. Test doubles belong in tests, never runtime routes.
"""
import base64
import hashlib
import hmac
import json
import re
import secrets
import uuid
from urllib.parse import urlparse
from letterbox_service import Denied, digest, normalized_code, display_name


def b64(value):
    return base64.urlsafe_b64encode(value).decode().rstrip('=')


def phone_number(country_code, national_number):
    # Deliberately require explicit international prefix and no national trunk 0.
    # This is format validation; an SMS provider must validate routability.
    if not isinstance(country_code, str) or not re.fullmatch(r'\+[1-9][0-9]{0,2}', country_code):
        raise Denied('Enter a country calling code, such as +44')
    if not isinstance(national_number, str) or not re.fullmatch(r'[0-9 ()-]{4,24}', national_number):
        raise Denied('Enter a national phone number')
    digits = re.sub(r'[ ()-]', '', national_number)
    value = country_code + digits
    if not re.fullmatch(r'\+[1-9][0-9]{6,14}', value) or digits.startswith('0'):
        raise Denied('Use international format without a national trunk zero')
    return value


class WebAuthnVerifier:
    """Use a maintained verifier, not hand-written signature or authenticator parsing."""
    def register(self, credential, challenge, rp_id, origin):
        from webauthn import verify_registration_response
        result = verify_registration_response(credential=credential, expected_challenge=challenge,
            expected_rp_id=rp_id, expected_origin=origin, require_user_verification=True)
        return result.credential_id, result.credential_public_key, result.sign_count

    def authenticate(self, credential, challenge, rp_id, origin, public_key, sign_count):
        from webauthn import verify_authentication_response
        result = verify_authentication_response(credential=credential, expected_challenge=challenge,
            expected_rp_id=rp_id, expected_origin=origin, credential_public_key=public_key,
            credential_current_sign_count=sign_count, require_user_verification=True)
        return result.new_sign_count


class AccountRegistration:
    def __init__(self, admission, *, phone_hmac_key, rp_id, origin, sms_sender=None):
        parsed = urlparse(origin)
        if (len(phone_hmac_key) < 32 or parsed.scheme != 'https' or parsed.hostname != rp_id
                or parsed.path not in ('', '/') or parsed.query or parsed.fragment or parsed.username
                or not re.fullmatch(r'[a-z0-9]+(?:[.-][a-z0-9]+)*\.[a-z]{2,}', rp_id)):
            raise ValueError('Configure a private HMAC key and trusted HTTPS relying-party origin')
        self.admission, self.key, self.rp_id, self.origin = admission, phone_hmac_key, rp_id, origin.rstrip('/')
        self.sms = sms_sender  # None is the shipping default. Never fall back to a fixed OTP.
        self.verifier = WebAuthnVerifier()
        with admission.db() as c:
            c.executescript('''
            CREATE TABLE IF NOT EXISTS enrollment(id TEXT PRIMARY KEY, invitation TEXT NOT NULL,
              phone_hash TEXT NOT NULL, name TEXT NOT NULL, member TEXT NOT NULL,
              otp_hash TEXT NOT NULL, created REAL NOT NULL, expires REAL NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0, verified INTEGER NOT NULL DEFAULT 0,
              challenge BLOB, consumed INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS account_credentials(credential BLOB PRIMARY KEY,
              member TEXT UNIQUE NOT NULL REFERENCES members(id), phone_hash TEXT UNIQUE NOT NULL,
              public_key BLOB NOT NULL, sign_count INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS account_challenges(id TEXT PRIMARY KEY,
              credential BLOB NOT NULL, challenge BLOB NOT NULL, expires REAL NOT NULL, used INTEGER NOT NULL DEFAULT 0);
            ''')

    def _hash(self, purpose, value):
        # Phone hashes need a private HMAC key: plain hashes permit phone-directory guessing.
        return hmac.new(self.key, (purpose + ':' + value).encode(), hashlib.sha256).hexdigest()

    def _invite(self, c, invitation_id):
        row = c.execute('''SELECT i.* FROM invitations i JOIN members m ON i.issuer=m.id
            WHERE i.id=? AND i.revoked=0 AND i.used_by IS NULL AND i.expires>? AND m.active=1
            AND i.group_id IS NULL''', (invitation_id, self.admission.clock())).fetchone()
        if row is None:
            raise Denied('Registration unavailable')
        return row

    def begin(self, invitation_code, name, country_code, national_number):
        if self.sms is None:
            raise Denied('SMS registration is disabled in this development build')
        phone = phone_number(country_code, national_number)
        code = normalized_code(invitation_code)
        name = display_name(name)
        now = self.admission.clock()
        phone_hash = self._hash('phone', phone)
        handle, member = secrets.token_urlsafe(32), str(uuid.uuid4())
        otp = f'{secrets.randbelow(1000000):06d}'
        with self.admission.db() as c:
            c.execute('DELETE FROM enrollment WHERE created<?', (now-86400,))
            c.execute('DELETE FROM account_challenges WHERE expires<?', (now-3600,))
            row = c.execute('SELECT id FROM invitations WHERE hash=?', (digest(code),)).fetchone()
            if row is None:
                raise Denied('Registration unavailable')
            invite = self._invite(c, row['id'])
            if c.execute('SELECT 1 FROM account_credentials WHERE phone_hash=?', (phone_hash,)).fetchone():
                raise Denied('Registration unavailable; existing accounts use their passkey')
            # Persistent per-phone/per-invite/global caps; no client-supplied IP is trusted.
            counts = c.execute('''SELECT count(*), sum(phone_hash=?), sum(invitation=?)
                FROM enrollment WHERE created>?''', (phone_hash, invite['id'], now-3600)).fetchone()
            if counts[0] >= 100 or (counts[1] or 0) >= 3 or (counts[2] or 0) >= 10:
                raise Denied('Registration limit reached; try later')
            c.execute('UPDATE enrollment SET consumed=1 WHERE phone_hash=?', (phone_hash,))
            c.execute('INSERT INTO enrollment(id,invitation,phone_hash,name,member,otp_hash,created,expires) VALUES(?,?,?,?,?,?,?,?)',
                (self._hash('handle', handle), invite['id'], phone_hash, name, member, self._hash(handle, otp), now, now+300))
        # Never persist or return the phone or OTP; only the provider receives it.
        # A failed send still counts against limits. Invalidate the unusable challenge.
        try:
            self.sms(phone, otp)
        except Exception:
            with self.admission.db() as c:
                c.execute('UPDATE enrollment SET consumed=1 WHERE id=?', (self._hash('handle', handle),))
            raise Denied('Verification delivery unavailable') from None
        return {'enrollment': handle, 'expires_at': now+300}

    def verify_phone(self, handle, otp):
        # Persist wrong attempts even when denying; raising inside db() would roll them back.
        failure = False
        options = None
        with self.admission.db() as c:
            row = c.execute('SELECT * FROM enrollment WHERE id=?', (self._hash('handle', handle),)).fetchone()
            if row is None or row['consumed'] or row['verified'] or row['expires'] <= self.admission.clock() or row['attempts'] >= 5:
                failure = True
            else:
                self._invite(c, row['invitation'])
                if not isinstance(otp, str) or not re.fullmatch(r'[0-9]{6}', otp) or not hmac.compare_digest(row['otp_hash'], self._hash(handle, otp)):
                    c.execute('UPDATE enrollment SET attempts=attempts+1 WHERE id=?', (row['id'],))
                    failure = True
                else:
                    challenge = secrets.token_bytes(32)
                    c.execute('UPDATE enrollment SET verified=1,challenge=? WHERE id=?', (challenge,row['id']))
                    options = {'challenge': b64(challenge), 'rp_id': self.rp_id, 'user_id': b64(uuid.UUID(row['member']).bytes),
                        'user_name': row['name'], 'user_verification': 'required', 'resident_key': 'required'}
        if failure:
            raise Denied('Verification unavailable')
        return options

    def finish(self, handle, credential):
        result = None
        with self.admission.db() as c:
            row = c.execute('SELECT * FROM enrollment WHERE id=?', (self._hash('handle', handle),)).fetchone()
            if row is None or row['consumed'] or not row['verified'] or row['attempts'] >= 5 or row['expires'] <= self.admission.clock():
                raise Denied('Registration unavailable')
            invite = self._invite(c, row['invitation'])
            try:
                if len(json.dumps(credential)) > 32768:
                    raise ValueError('Oversized credential')
                verified = self.verifier.register(credential, row['challenge'], self.rp_id, self.origin)
            except Exception:
                verified = None
                # Commit failed-ceremony attempts rather than rolling them back on denial.
                c.execute('UPDATE enrollment SET attempts=attempts+1 WHERE id=?', (row['id'],))
            if verified is not None:
                credential_id, public_key, counter = verified
                # Invite, member, contact and passkey commit atomically. OTP alone creates nothing.
                c.execute('INSERT INTO members(id,name,active) VALUES(?,?,1)', (row['member'],row['name']))
                c.execute('INSERT INTO account_credentials VALUES(?,?,?,?,?)', (credential_id,row['member'],row['phone_hash'],public_key,counter))
                a,b = sorted([invite['issuer'],row['member']])
                c.execute('INSERT INTO contacts VALUES(?,?)', (a,b))
                c.execute('UPDATE invitations SET used_by=? WHERE id=?', (row['member'],invite['id']))
                c.execute('UPDATE enrollment SET consumed=1 WHERE id=?', (row['id'],))
                result = {'member_id':row['member'], 'session_token':self.admission._session(c,row['member'])}
        if result is None:
            raise Denied('Passkey verification failed')
        return result

    def login_challenge(self, credential_id):
        # Native passkey picker supplies the credential ID. It is not a phone-based recovery route.
        if not isinstance(credential_id, bytes) or not 1 <= len(credential_id) <= 1024:
            raise Denied('Sign-in unavailable')
        handle, challenge = secrets.token_urlsafe(32), secrets.token_bytes(32)
        now = self.admission.clock()
        with self.admission.db() as c:
            if not c.execute('SELECT 1 FROM account_credentials k JOIN members m ON k.member=m.id WHERE k.credential=? AND m.active=1', (credential_id,)).fetchone():
                raise Denied('Sign-in unavailable')
            c.execute('DELETE FROM account_challenges WHERE expires<?', (now-3600,))
            if c.execute('SELECT count(*) FROM account_challenges WHERE credential=? AND expires>?', (credential_id,now-300)).fetchone()[0] >= 20:
                raise Denied('Sign-in limit reached')
            c.execute('INSERT INTO account_challenges(id,credential,challenge,expires) VALUES(?,?,?,?)', (self._hash('login',handle),credential_id,challenge,now+60))
        return {'login':handle, 'challenge':b64(challenge), 'rp_id':self.rp_id, 'credential_id':b64(credential_id)}

    def login(self, handle, credential):
        # Consume challenge even on invalid signatures to bound online retries.
        result = None
        with self.admission.db() as c:
            row = c.execute('''SELECT q.*,k.member,k.public_key,k.sign_count FROM account_challenges q
                JOIN account_credentials k ON q.credential=k.credential JOIN members m ON k.member=m.id
                WHERE q.id=? AND q.used=0 AND q.expires>? AND m.active=1''', (self._hash('login',handle),self.admission.clock())).fetchone()
            if row is not None:
                c.execute('UPDATE account_challenges SET used=1 WHERE id=?', (row['id'],))
                try:
                    if len(json.dumps(credential)) > 32768 or credential.get('id') != b64(row['credential']):
                        raise ValueError('Credential binding')
                    counter = self.verifier.authenticate(credential, row['challenge'], self.rp_id, self.origin, row['public_key'], row['sign_count'])
                except Exception:
                    counter = None
                if counter is not None:
                    c.execute('UPDATE account_credentials SET sign_count=? WHERE credential=?', (counter,row['credential']))
                    result = {'member_id':row['member'], 'session_token':self.admission._session(c,row['member'])}
        if result is None:
            raise Denied('Sign-in unavailable')
        return result
