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
    def __init__(self, path, clock=time.time):
        self.path, self.clock = str(path), clock
        with self.db() as c:
            c.executescript('''
            CREATE TABLE IF NOT EXISTS members(id TEXT PRIMARY KEY, name TEXT NOT NULL, active INTEGER NOT NULL, owner INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY, member TEXT NOT NULL REFERENCES members(id), expires REAL NOT NULL);
            CREATE TABLE IF NOT EXISTS groups(id TEXT PRIMARY KEY, name TEXT NOT NULL, admin TEXT NOT NULL REFERENCES members(id));
            CREATE TABLE IF NOT EXISTS group_members(group_id TEXT REFERENCES groups(id), member TEXT REFERENCES members(id), joined REAL NOT NULL, PRIMARY KEY(group_id,member));
            CREATE TABLE IF NOT EXISTS contacts(a TEXT REFERENCES members(id), b TEXT REFERENCES members(id), PRIMARY KEY(a,b));
            CREATE TABLE IF NOT EXISTS invitations(id TEXT PRIMARY KEY, hash TEXT UNIQUE NOT NULL, issuer TEXT NOT NULL REFERENCES members(id), group_id TEXT REFERENCES groups(id), expires REAL NOT NULL, revoked INTEGER NOT NULL DEFAULT 0, used_by TEXT REFERENCES members(id));
            CREATE TABLE IF NOT EXISTS direct_rooms(id TEXT PRIMARY KEY, a TEXT, b TEXT, UNIQUE(a,b));
            ''')

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

    def _session(self, c, member):
        token = secrets.token_urlsafe(32)
        c.execute('INSERT INTO sessions VALUES(?,?,?)', (digest(token), member, self.clock() + 30*86400))
        return token

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
                routes = {
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
    args=parser.parse_args()
    os.umask(0o077)
    folder=Path(args.data_dir).expanduser().resolve()
    folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    service=LetterboxService(folder/'letterbox.sqlite3')
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
