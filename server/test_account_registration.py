"""Synthetic local checks. Never sends SMS, enrolls device biometrics or uses a real phone."""
import base64
import hashlib
import json
import struct
import tempfile
import unittest
from pathlib import Path
from account_registration import AccountRegistration, phone_number, b64
from letterbox_service import LetterboxService, Denied


class AccountTests(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory()
        self.now=1000.0
        self.service=LetterboxService(Path(self.folder.name)/'test.sqlite3',clock=lambda:self.now)
        self.owner=self.service.bootstrap()
        self.invite=self.service.issue(self.owner['session_token'])
        self.messages=[]
        self.accounts=AccountRegistration(self.service,phone_hmac_key=b'x'*32,rp_id='letters.test',origin='https://letters.test',sms_sender=lambda phone,otp:self.messages.append((phone,otp)))
    def tearDown(self):
        self.folder.cleanup()
    def begin(self):
        return self.accounts.begin(self.invite['code'],'Synthetic member','+44','7700 900123')['enrollment']
    def verify(self,handle):
        return self.accounts.verify_phone(handle,self.messages[-1][1])
    def testDisabledByDefaultAndInternationalFormatting(self):
        disabled=AccountRegistration(self.service,phone_hmac_key=b'x'*32,rp_id='letters.test',origin='https://letters.test')
        with self.assertRaises(Denied): disabled.begin(self.invite['code'],'Test','+44','7700900123')
        self.assertEqual(phone_number('+44','7700 900123'),'+447700900123')
        for country,number in [('+00','1234567'),('+44','07700900123'),('+1','abc'),('44','7700900123')]:
            with self.assertRaises(Denied): phone_number(country,number)
    def testOTPAloneDoesNotCreateAccountOrPersistPhone(self):
        handle=self.begin(); self.verify(handle)
        with self.service.db() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM members').fetchone()[0],1)
            dump='\n'.join(c.iterdump())
            self.assertNotIn('+447700900123',dump)
            self.assertNotIn(self.messages[-1][1],dump)
        with self.assertRaises(Denied): self.accounts.finish(handle,{'id':'not-a-passkey'})
        with self.service.db() as c: self.assertEqual(c.execute('SELECT count(*) FROM members').fetchone()[0],1)
    def testWrongOTPAttemptsPersistAndLockOut(self):
        handle=self.begin()
        for _ in range(5):
            with self.assertRaises(Denied): self.accounts.verify_phone(handle,'invalid')
        with self.assertRaises(Denied): self.verify(handle)
    def testExpiryAndRevokedInvitationBlockRegistration(self):
        handle=self.begin(); self.now+=301
        with self.assertRaises(Denied): self.verify(handle)
        self.now=1000; handle=self.begin(); self.service.revoke(self.owner['session_token'],self.invite['id'])
        with self.assertRaises(Denied): self.verify(handle)
    def testResendInvalidatesOldProofAndRequestCap(self):
        first=self.begin(); second=self.begin()
        with self.assertRaises(Denied): self.verify(first)
        self.verify(second)
        self.begin()
        with self.assertRaises(Denied): self.begin()
    def testGroupInviteCannotCreateAccount(self):
        group=self.service.create_group(self.owner['session_token'],'Test')
        code=self.service.issue(self.owner['session_token'],group_id=group['id'])['code']
        with self.assertRaises(Denied): self.accounts.begin(code,'Test','+44','7700900123')
    def testSMSDeliveryFailureDoesNotLeaveUsableProof(self):
        def fail(phone,otp): raise RuntimeError('Synthetic provider failure')
        self.accounts.sms=fail
        with self.assertRaises(Denied): self.begin()
        with self.service.db() as c: self.assertEqual(c.execute('SELECT consumed FROM enrollment').fetchone()[0],1)

    # Real cryptographic verification runs after CI installs the pinned verifier.
    # The virtual authenticator signs with an ephemeral synthetic P-256 key.
    def testCryptographicPasskeyRegistrationAndLogin(self):
        try:
            import webauthn
            from cryptography.hazmat.primitives.asymmetric import ec
            from cryptography.hazmat.primitives import hashes
        except ImportError:
            if __import__('os').environ.get('LETTERS_REQUIRE_PASSKEY_TESTS') == '1': self.fail('Required WebAuthn test dependency missing')
            self.skipTest('Install pinned test requirements to exercise real signature verification')
        def cbor(value):
            def header(major,n):
                if n<24: return bytes([major*32+n])
                if n<256: return bytes([major*32+24,n])
                return bytes([major*32+25])+struct.pack('>H',n)
            if isinstance(value,int): return header(0,value) if value>=0 else header(1,-1-value)
            if isinstance(value,bytes): return header(2,len(value))+value
            if isinstance(value,str): return header(3,len(value.encode()))+value.encode()
            if isinstance(value,dict): return header(5,len(value))+b''.join(cbor(k)+cbor(v) for k,v in value.items())
            raise TypeError()
        private=ec.generate_private_key(ec.SECP256R1()); public=private.public_key().public_numbers()
        cose=cbor({1:2,3:-7,-1:1,-2:public.x.to_bytes(32,'big'),-3:public.y.to_bytes(32,'big')})
        credential_id=b'synthetic-credential'
        def client(challenge,kind,origin='https://letters.test'):
            return json.dumps({'type':kind,'challenge':challenge,'origin':origin,'crossOrigin':False}).encode()
        handle=self.begin(); options=self.verify(handle)
        auth=hashlib.sha256(b'letters.test').digest()+bytes([0x45])+struct.pack('>I',0)+bytes(16)+struct.pack('>H',len(credential_id))+credential_id+cose
        attestation=cbor({'fmt':'none','attStmt':{},'authData':auth})
        credential={'id':b64(credential_id),'rawId':b64(credential_id),'type':'public-key','response':{'clientDataJSON':b64(client(options['challenge'],'webauthn.create')),'attestationObject':b64(attestation)}}
        bad=json.loads(json.dumps(credential)); bad['response']['clientDataJSON']=b64(client(options['challenge'],'webauthn.create','https://evil.test'))
        with self.assertRaises(Denied): self.accounts.finish(handle,bad)
        member=self.accounts.finish(handle,credential)
        with self.assertRaises(Denied): self.accounts.finish(handle,credential)
        self.assertEqual([x['id'] for x in self.service.contacts(self.owner['session_token'])],[member['member_id']])
        with self.assertRaises(Denied): self.begin() # phone uniqueness
        def assertion(options,counter=1,uv=True):
            data=client(options['challenge'],'webauthn.get')
            authenticator=hashlib.sha256(b'letters.test').digest()+bytes([5 if uv else 1])+struct.pack('>I',counter)
            signature=private.sign(authenticator+hashlib.sha256(data).digest(),ec.ECDSA(hashes.SHA256()))
            return {'id':b64(credential_id),'rawId':b64(credential_id),'type':'public-key','response':{'clientDataJSON':b64(data),'authenticatorData':b64(authenticator),'signature':b64(signature),'userHandle':options.get('user_id')}}
        login=self.accounts.login_challenge(credential_id)
        result=self.accounts.login(login['login'],assertion(login))
        self.assertEqual(result['member_id'],member['member_id'])
        with self.assertRaises(Denied): self.accounts.login(login['login'],assertion(login))
        login=self.accounts.login_challenge(credential_id)
        with self.assertRaises(Denied): self.accounts.login(login['login'],assertion(login,2,False))
        with self.assertRaises(Denied): self.accounts.login(login['login'],assertion(login,2))
        login=self.accounts.login_challenge(credential_id)
        with self.assertRaises(Denied): self.accounts.login(login['login'],assertion(login,1)) # counter replay
        login=self.accounts.login_challenge(credential_id); self.now+=61
        with self.assertRaises(Denied): self.accounts.login(login['login'],assertion(login,3))
        self.service.deactivate(self.owner['session_token'],member['member_id'])
        with self.assertRaises(Denied): self.accounts.login_challenge(credential_id)

if __name__ == '__main__': unittest.main()
