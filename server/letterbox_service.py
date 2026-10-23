"""Local admission-service prototype. No message transport or encryption implementation.

Binds loopback only; not a production server. Never expose this HTTP endpoint publicly.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from contextlib import contextmanager

ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'


class Denied(Exception):
    pass


def digest(value):
    return hashlib.sha256(value.encode('ascii')).hexdigest()


# Canonical formatting is allowed; arbitrary URLs and malformed invite payloads are rejected.
def normalized_code(value):
    if not isinstance(value, str) or len(value) > 128:
        raise Denied('Invitation unavailable')
    compact = re.sub(r'[\s-]', '', value.upper())
    if not compact.startswith('LBOX') or len(compact) != 36 or any(c not in ALPHABET for c in compact[4:]):
        raise Denied('Invitation unavailable')
    return 'LBOX-' + compact[4:]


def display_name(value):
    if not isinstance(value, str):
        raise Denied('Display name required')
    value = value.strip()
    if not 1 <= len(value) <= 40 or any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise Denied('Display name must contain 1–40 characters')
    return value


class LetterboxService:
    def __init__(self, path, clock=time.time, matrix_server_name=None):
        self.path, self.clock = str(path), clock
        # The trusted deployment chooses the Matrix domain, never an HTTP caller.
        if matrix_server_name is not None and not re.fullmatch(r'[a-z0-9][a-z0-9.-]*(?::[0-9]{1,5})?', matrix_server_name):
            raise ValueError('Invalid Matrix server name')
        self.matrix_server_name = matrix_server_name
        with self.db() as c:
            c.executescript('''
            CREATE TABLE IF NOT EXISTS members(id TEXT PRIMARY KEY, name TEXT NOT NULL, active INTEGER NOT NULL, owner INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY, member TEXT NOT NULL REFERENCES members(id), expires REAL NOT NULL);
            CREATE TABLE IF NOT EXISTS groups(id TEXT PRIMARY KEY, name TEXT NOT NULL, admin TEXT NOT NULL REFERENCES members(id));
            CREATE TABLE IF NOT EXISTS group_members(group_id TEXT REFERENCES groups(id), member TEXT REFERENCES members(id), joined REAL NOT NULL, PRIMARY KEY(group_id,member));
            CREATE TABLE IF NOT EXISTS contacts(a TEXT REFERENCES members(id), b TEXT REFERENCES members(id), PRIMARY KEY(a,b));
            CREATE TABLE IF NOT EXISTS invitations(id TEXT PRIMARY KEY, hash TEXT UNIQUE NOT NULL, issuer TEXT NOT NULL REFERENCES members(id), group_id TEXT REFERENCES groups(id), expires REAL NOT NULL, revoked INTEGER NOT NULL DEFAULT 0, used_by TEXT REFERENCES members(id));
            CREATE TABLE IF NOT EXISTS direct_rooms(id TEXT PRIMARY KEY, a TEXT, b TEXT, UNIQUE(a,b));
            CREATE TABLE IF NOT EXISTS matrix_login_grants(hash TEXT PRIMARY KEY, member TEXT NOT NULL REFERENCES members(id), session_hash TEXT NOT NULL REFERENCES sessions(hash) ON DELETE CASCADE, user_id TEXT NOT NULL, issued REAL NOT NULL, expires REAL NOT NULL, used INTEGER NOT NULL DEFAULT 0);
            CREATE INDEX IF NOT EXISTS matrix_grant_member ON matrix_login_grants(member,issued);
            ''')

    # One immediate transaction protects invitation redemption and login grants from replay races.
    @contextmanager
    def db(self):
        c = sqlite3.connect(self.path, timeout=10)
        c.row_factory = sqlite3.Row
        c.execute('PRAGMA foreign_keys=ON')
        try:
            c.execute('BEGIN IMMEDIATE')
            yield c
            c.commit()
        except Exception:
            c.rollback()
            raise
        finally:
            c.close()

    # Session secrets leave the server once; SQLite stores their hashes, never bearer credentials.
    def _session(self, c, member):
        token = secrets.token_urlsafe(32)
        c.execute('INSERT INTO sessions VALUES(?,?,?)', (digest(token), member, self.clock() + 30*86400))
        return token

    # Every privileged operation checks both session expiry and current active membership.
    def _auth(self, c, token):
        if not isinstance(token, str) or not 32 <= len(token) <= 128 or not token.isascii():
            raise Denied('Authentication required')
        row = c.execute('SELECT m.* FROM members m JOIN sessions s ON m.id=s.member WHERE s.hash=? AND s.expires>? AND m.active=1', (digest(token), self.clock())).fetchone()
        if row is None:
            raise Denied('Authentication required')
        return row

    def bootstrap(self):
        with self.db() as c:
            if c.execute('SELECT 1 FROM members LIMIT 1').fetchone():
                raise Denied('Already initialized')
            member = str(uuid.uuid4())
            c.execute('INSERT INTO members VALUES(?,?,1,1)', (member, 'Owner'))
            return {'member_id': member, 'session_token': self._session(c, member)}

    def issue(self, token, group_id=None, ttl=86400):
        if type(ttl) is not int or not 60 <= ttl <= 7*86400:
            raise Denied('Expiry must be between one minute and seven days')
        with self.db() as c:
            issuer = self._auth(c, token)['id']
            if group_id is not None:
                if not isinstance(group_id, str) or not c.execute('SELECT 1 FROM groups WHERE id=? AND admin=?', (group_id, issuer)).fetchone():
                    raise Denied('Group administrator required')
            count = c.execute('SELECT count(*) FROM invitations WHERE issuer=? AND revoked=0 AND used_by IS NULL AND expires>?', (issuer, self.clock())).fetchone()[0]
            if count >= 20:
                raise Denied('Too many active invitations')
            code = 'LBOX-' + ''.join(secrets.choice(ALPHABET) for _ in range(32))
            invite_id = str(uuid.uuid4())
            expires = self.clock()+ttl
            c.execute('INSERT INTO invitations(id,hash,issuer,group_id,expires) VALUES(?,?,?,?,?)', (invite_id,digest(code),issuer,group_id,expires))
            return {'id': invite_id, 'code': code, 'group_id': group_id, 'expires_at': expires}

    # Admission creates only the inviter/recipient contact edge; group membership requires its own invitation.
    def redeem(self, code, name=None, token=None):
        code = normalized_code(code)
        with self.db() as c:
            invite = c.execute('SELECT i.* FROM invitations i JOIN members m ON i.issuer=m.id WHERE i.hash=? AND i.revoked=0 AND i.used_by IS NULL AND i.expires>? AND m.active=1', (digest(code),self.clock())).fetchone()
            if invite is None:
                raise Denied('Invitation unavailable')
            session = None
            if token is not None:
                member = self._auth(c, token)['id']
                if member == invite['issuer']:
                    raise Denied('Cannot accept your own invitation')
            else:
                if invite['group_id'] is not None:
                    raise Denied('Join Letters before accepting a group invitation')
                member = str(uuid.uuid4())
                c.execute('INSERT INTO members(id,name,active) VALUES(?,?,1)', (member,display_name(name)))
                session = self._session(c, member)
            if invite['group_id'] is not None:
                if not c.execute('SELECT 1 FROM groups WHERE id=? AND admin=?', (invite['group_id'],invite['issuer'])).fetchone():
                    raise Denied('Invitation unavailable')
                c.execute('INSERT OR IGNORE INTO group_members VALUES(?,?,?)', (invite['group_id'],member,self.clock()))
            else:
                a,b = sorted([invite['issuer'],member])
                c.execute('INSERT OR IGNORE INTO contacts VALUES(?,?)', (a,b))
            c.execute('UPDATE invitations SET used_by=? WHERE id=? AND used_by IS NULL', (member,invite['id']))
            # Tokens are returned once, never persisted in cleartext. Real clients need Keychain.
            result = {'member_id':member, 'group_id':invite['group_id']}
            if session:
                result['session_token'] = session
            return result

    def revoke(self, token, invitation_id):
        with self.db() as c:
            member = self._auth(c,token)
            invite = c.execute('SELECT issuer FROM invitations WHERE id=?', (invitation_id,)).fetchone()
            if invite is None or (invite['issuer'] != member['id'] and not member['owner']):
                raise Denied('Invitation unavailable')
            c.execute('UPDATE invitations SET revoked=1 WHERE id=?', (invitation_id,))
            return {'revoked':True}

    def contacts(self, token):
        with self.db() as c:
            member = self._auth(c,token)['id']
            return [dict(r) for r in c.execute('SELECT m.id,m.name FROM contacts x JOIN members m ON m.id=CASE WHEN x.a=? THEN x.b ELSE x.a END WHERE (x.a=? OR x.b=?) AND m.active=1', (member,member,member))]

    # A direct-room placeholder requires an existing personal contact. It is not a live Matrix room.
    def direct(self, token, other):
        with self.db() as c:
            member = self._auth(c,token)['id']
            if not isinstance(other, str) or other == member:
                raise Denied('Approved contact required')
            a,b = sorted([member,other])
            if not c.execute('SELECT 1 FROM contacts x JOIN members m ON m.id=? WHERE x.a=? AND x.b=? AND m.active=1', (other,a,b)).fetchone():
                raise Denied('Approved contact required')
            c.execute('INSERT OR IGNORE INTO direct_rooms VALUES(?,?,?)', (str(uuid.uuid4()),a,b))
            return {'id':c.execute('SELECT id FROM direct_rooms WHERE a=? AND b=?',(a,b)).fetchone()[0], 'messaging_available':False}

    def create_group(self, token, name):
        with self.db() as c:
            member = self._auth(c,token)['id']
            group = str(uuid.uuid4())
            c.execute('INSERT INTO groups VALUES(?,?,?)', (group,display_name(name),member))
            c.execute('INSERT INTO group_members VALUES(?,?,?)',(group,member,self.clock()))
            return {'id':group, 'name':name.strip(), 'messaging_available':False}

    def group(self, token, group_id):
        with self.db() as c:
            member = self._auth(c,token)['id']
            row = c.execute('SELECT g.id,g.name,gm.joined FROM groups g JOIN group_members gm ON gm.group_id=g.id WHERE g.id=? AND gm.member=?', (group_id,member)).fetchone()
            if row is None:
                raise Denied('Group unavailable')
            return dict(row, messaging_available=False)

    def matrix_user_id(self, member_id):
        """Map an admission UUID to one stable local Matrix identity, not a name."""
        if self.matrix_server_name is None:
            raise Denied('Messaging connection unavailable')
        return '@letters_' + uuid.UUID(member_id).hex + ':' + self.matrix_server_name

    def matrix_room_audience(self, token, *, contact_id=None, group_id=None):
        """Resolve an authenticated conversation's audience from admission data.

        Callers choose a contact OR group identifier, never a list of Matrix IDs.
        This is an authorization query, not permission to create an arbitrary
        Matrix room: the homeserver must independently enforce the same policy.
        """
        if (contact_id is None) == (group_id is None):
            raise Denied('Choose one conversation')
        if self.matrix_server_name is None:
            raise Denied('Messaging connection unavailable')
        with self.db() as c:
            own = self._auth(c, token)['id']
            if contact_id is not None:
                if not isinstance(contact_id, str) or own == contact_id:
                    raise Denied('Approved contact required')
                a, b = sorted([own, contact_id])
                edge = c.execute(
                    'SELECT 1 FROM contacts WHERE a=? AND b=?', (a, b)).fetchone()
                active = c.execute(
                    'SELECT 1 FROM members WHERE id=? AND active=1', (contact_id,)).fetchone()
                if edge is None or active is None:
                    raise Denied('Approved contact required')
                members = [own, contact_id]
            else:
                if not isinstance(group_id, str) or not c.execute(
                    'SELECT 1 FROM group_members WHERE group_id=? AND member=?',
                    (group_id, own)).fetchone():
                    raise Denied('Group unavailable')
                # Removed accounts never remain in a newly resolved audience.
                members = [r['member'] for r in c.execute(
                    'SELECT gm.member FROM group_members gm JOIN members m ON m.id=gm.member '
                    'WHERE gm.group_id=? AND m.active=1 ORDER BY gm.member', (group_id,))]
            return {'own_user_id': self.matrix_user_id(own),
                    'recipient_user_ids': sorted(self.matrix_user_id(member)
                                                 for member in members if member != own)}

    def issue_matrix_login(self, token):
        """Return a 60-second sign-in grant once; persist only its SHA-256 hash."""
        if self.matrix_server_name is None:
            raise Denied('Messaging connection unavailable')
        with self.db() as c:
            member = self._auth(c, token)['id']
            now = self.clock()
            # Bound table growth and credential churn; never log returned grants.
            c.execute('DELETE FROM matrix_login_grants WHERE expires<=?', (now-3600,))
            recent = c.execute('SELECT count(*) FROM matrix_login_grants WHERE member=? AND issued>?', (member, now-3600)).fetchone()[0]
            if recent >= 10:
                raise Denied('Sign-in limit reached; try later')
            # A fresh request replaces this member's unused credential. Existing
            # Matrix device sessions are unaffected and require separate policy.
            c.execute('UPDATE matrix_login_grants SET used=1 WHERE member=?', (member,))
            grant = 'LLOGIN-' + secrets.token_urlsafe(32)
            user_id = self.matrix_user_id(member)
            c.execute('INSERT INTO matrix_login_grants VALUES(?,?,?,?,?,?,0)',
                      (digest(grant), member, digest(token), user_id, now, now+60))
            return {'user_id': user_id, 'login_grant': grant, 'expires_at': now+60}

    def consume_matrix_login(self, user_id, grant):
        """Atomically bind an unused grant to its approved account and session."""
        if not isinstance(user_id, str) or not isinstance(grant, str) or not re.fullmatch(r'LLOGIN-[A-Za-z0-9_-]{43}', grant):
            raise Denied('Sign-in unavailable')
        with self.db() as c:
            # BEGIN IMMEDIATE in db() makes concurrent replays compete for one
            # write transaction. Account, admission session and expiry all matter.
            row = c.execute('''SELECT m.id,m.name FROM matrix_login_grants g
                JOIN members m ON m.id=g.member JOIN sessions s ON s.hash=g.session_hash
                WHERE g.hash=? AND g.user_id=? AND g.used=0 AND g.expires>?
                AND s.expires>? AND m.active=1''',
                (digest(grant), user_id, self.clock(), self.clock())).fetchone()
            if row is None or self.matrix_user_id(row['id']) != user_id:
                raise Denied('Sign-in unavailable')
            c.execute('UPDATE matrix_login_grants SET used=1 WHERE hash=?', (digest(grant),))
            return dict(row)

    def matrix_account_active(self, user_id):
        """Recheck membership for existing Matrix sessions; do not cache approval."""
        if not isinstance(user_id, str) or self.matrix_server_name is None:
            return False
        pattern = r'@letters_([0-9a-f]{32}):' + re.escape(self.matrix_server_name)
        match = re.fullmatch(pattern, user_id)
        if match is None:
            return False
        with self.db() as c:
            row = c.execute('SELECT active FROM members WHERE id=?', (str(uuid.UUID(hex=match[1])),)).fetchone()
            return row is not None and row['active'] == 1

    # Removing a member revokes admission sessions/grants and blocks future Synapse requests via the module.
    def deactivate(self, token, member_id):
        with self.db() as c:
            actor = self._auth(c,token)
            if not actor['owner'] or member_id == actor['id']:
                raise Denied('Owner required; cannot deactivate yourself')
            c.execute('UPDATE members SET active=0 WHERE id=?',(member_id,))
            c.execute('DELETE FROM sessions WHERE member=?',(member_id,))
            c.execute('UPDATE invitations SET revoked=1 WHERE issuer=?',(member_id,))
            c.execute('DELETE FROM group_members WHERE member=?',(member_id,))
            return {'deactivated':True}


def handler(service):
    class Handler(BaseHTTPRequestHandler):
        # No request/body/token logging. Loopback-only development adapter.
        def log_message(self, *args):
            pass

        def do_POST(self):
            try:
                if self.headers.get('Origin') is not None:
                    raise Denied('Browser-origin requests are not accepted')
                size = int(self.headers.get('Content-Length','0'))
                if not 0 < size <= 4096 or self.headers.get('Transfer-Encoding'):
                    raise Denied('Invalid request size')
                data = json.loads(self.rfile.read(size))
                if not isinstance(data,dict):
                    raise Denied('Invalid JSON object')
                auth = self.headers.get('Authorization','')
                token = auth[7:] if auth.startswith('Bearer ') else None
                # Dispatch only named operations; caller-provided IDs are re-authorized by each method.
                routes = {
                    '/v1/messaging/login-grant':lambda:service.issue_matrix_login(token),
                    '/v1/invitations':lambda:service.issue(token,data.get('group_id'),data.get('ttl',86400)),
                    '/v1/redeem':lambda:service.redeem(data.get('code'),data.get('name'),token),
                    '/v1/revoke':lambda:service.revoke(token,data.get('invitation_id')),
                    '/v1/contacts':lambda:service.contacts(token),
                    '/v1/direct':lambda:service.direct(token,data.get('member_id')),
                    '/v1/groups':lambda:service.create_group(token,data.get('name')),
                    '/v1/group':lambda:service.group(token,data.get('group_id')),
                    '/v1/deactivate':lambda:service.deactivate(token,data.get('member_id')),
                }
                if self.path not in routes:
                    self.respond(404,{'error':'Not found'});return
                self.respond(200,routes[self.path]())
            except Denied as e:
                self.respond(403,{'error':str(e)})
            except (ValueError,TypeError,UnicodeError,sqlite3.Error):
                self.respond(400,{'error':'Invalid request'})

        def respond(self,status,data):
            body = json.dumps(data).encode()
            self.send_response(status)
            self.send_header('Content-Type','application/json')
            self.send_header('Cache-Control','no-store')
            self.send_header('Content-Length',str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    return Handler


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir',required=True,help='Private directory outside the public source')
    parser.add_argument('--init',action='store_true')
    parser.add_argument('--port',type=int,default=8808)
    parser.add_argument('--matrix-server-name',help='Trusted local Matrix domain; development bridge only')
    args=parser.parse_args()
    os.umask(0o077)
    folder=Path(args.data_dir).expanduser().resolve()
    folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    service=LetterboxService(folder/'letterbox.sqlite3',matrix_server_name=args.matrix_server_name)
    if args.init:
        # Create private output before bootstrapping, so an existing credential cannot be overwritten.
        with (folder/'owner-session.json').open('x') as out:
            json.dump(service.bootstrap(),out)
        print('Initialized. Owner credential saved privately; never commit or share it.')
    else:
        print('Local prototype at 127.0.0.1. No messaging or E2EE. Do not expose publicly.')
        ThreadingHTTPServer(('127.0.0.1',args.port),handler(service)).serve_forever()


if __name__ == '__main__':
    main()
