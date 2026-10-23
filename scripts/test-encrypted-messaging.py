"""Prove approved Letterbox admission reaches real encrypted SDK device sessions.

The homeserver, membership records and credentials are ephemeral and loopback-only.
No real user accounts, Oracle deployment or public listener are involved.
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

# Import our source from its observed repository location, not from the network.
SERVER_SOURCE = Path(__file__).resolve().parents[1] / 'server'
sys.path.insert(0, str(SERVER_SOURCE))
from letterbox_service import LetterboxService
from synapse.api.errors import Codes


def request(base, path, data=None, token=None, method=None):
    """Return HTTP status/body without echoing request credentials or server logs."""
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(base + path, data=None if data is None else json.dumps(data).encode(), headers=headers, method=method)
    try:
        response = urllib.request.urlopen(req, timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status, json.load(response)


def login(base, grant, expected):
    status, body = request(base, '/_matrix/client/v3/login', {
        'type': 'm.login.password', 'identifier': {'type': 'm.id.user', 'user': grant['user_id']},
        'password': grant['login_grant'], 'initial_device_display_name': 'Synthetic boundary probe'})
    if status != expected:
        raise RuntimeError('Unexpected authentication boundary result (credentials redacted)')
    return body


def main():
    with tempfile.TemporaryDirectory(prefix='letters-encryption-') as temporary:
        root = Path(temporary)
        # All SDK test accounts now come from real one-use Letterbox invitations.
        admission = LetterboxService(root/'admission.sqlite3', matrix_server_name='letters.test')
        owner = admission.bootstrap()
        members = {'alice': owner}
        for name in ('bob', 'outsider', 'probe'):
            invitation = admission.issue(owner['session_token'])
            members[name] = admission.redeem(invitation['code'], 'Synthetic ' + name)
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        base = f'http://127.0.0.1:{port}'
        config = {
            'server_name': 'letters.test', 'pid_file': str(root/'synapse.pid'),
            'listeners': [{'port': port, 'tls': False, 'type': 'http', 'bind_addresses': ['127.0.0.1'],
                           'resources': [{'names': ['client', 'media'], 'compress': False}]}],
            'database': {'name': 'sqlite3', 'args': {'database': str(root/'homeserver.db')}},
            'media_store_path': str(root/'media'), 'signing_key_path': str(root/'signing.key'),
            'report_stats': False, 'enable_registration': False, 'trusted_key_servers': [],
            'suppress_key_server_warning': True, 'federation_domain_whitelist': [],
            'serve_server_wellknown': False, 'enable_media_repo': True,
            # Exercise encrypted uploads on this disposable loopback server only.
            'max_upload_size': '20M', 'url_preview_enabled': False,
            # A standard stored password must not bypass Letterbox approval.
            'password_config': {'enabled': True, 'localdb_enabled': False},
            'modules': [{'module': 'letters_synapse_auth.LettersAuthProvider',
                         'config': {'admission_database': str(root/'admission.sqlite3')}}],
            'rc_login': {'address': {'per_second': 100, 'burst_count': 100},
                         'account': {'per_second': 100, 'burst_count': 100},
                         'failed_attempts': {'per_second': 100, 'burst_count': 100}},
            'rc_message': {'per_second': 100, 'burst_count': 100},
        }
        policy_only = '--room-policy-only' in sys.argv
        if policy_only:
            config['modules'].append({'module': 'letters_room_enforcement.LettersRoomEnforcement',
                                      'config': {'admission_database': str(root/'admission.sqlite3')}})
        config_path = root/'homeserver.yaml' 
        config_path.write_text(json.dumps(config)); config_path.chmod(0o600)
        env = dict(os.environ, PYTHONPATH=str(SERVER_SOURCE))
        with (root/'synapse.log').open('wb') as log:
            server = subprocess.Popen([sys.executable, '-m', 'synapse.app.homeserver', '-c', str(config_path)],
                                      stdout=log, stderr=subprocess.STDOUT, cwd=root, env=env)
            try:
                for _ in range(120):
                    if server.poll() is not None:
                        raise RuntimeError('Isolated homeserver exited; private logs were not published')
                    try:
                        status, _ = request(base, '/_matrix/client/versions')
                        if status == 200:
                            break
                    except OSError:
                        pass
                    time.sleep(.5)
                else:
                    raise RuntimeError('Isolated homeserver did not become ready')
                if policy_only:
                    accounts = {name: login(base, admission.issue_matrix_login(member['session_token']), 200)
                                for name, member in members.items() if name in ('alice', 'bob', 'outsider')}
                    alice, bob, outsider = [accounts[name] for name in ('alice', 'bob', 'outsider')]
                    def expect(status, wanted, label):
                        if status != wanted:
                            raise RuntimeError(label + ': unexpected status ' + str(status))
                    status, created = request(base, '/_matrix/client/v3/createRoom',
                        {'preset': 'private_chat', 'invite': [bob['user_id']]}, alice['access_token'])
                    expect(status, 200, 'Approved direct room')
                    room = created['room_id']
                    status, encryption = request(base, '/_matrix/client/v3/rooms/'+room+'/state/m.room.encryption',
                                                 token=alice['access_token'])
                    expect(status, 200, 'Encryption state')
                    if encryption.get('algorithm') != 'm.megolm.v1.aes-sha2':
                        raise RuntimeError('Required encryption missing')
                    status, _ = request(base, '/_matrix/client/v3/join/'+room, {}, bob['access_token'])
                    expect(status, 200, 'Approved invited join')
                    status, _ = request(base, '/_matrix/client/v3/rooms/'+room+'/invite',
                                        {'user_id': outsider['user_id']}, alice['access_token'])
                    expect(status, 403, 'Audience expansion')
                    status, _ = request(base, '/_matrix/client/v3/createRoom',
                        {'invite': [outsider['user_id']]}, bob['access_token'])
                    expect(status, 403, 'Noncontact room')
                    status, _ = request(base, '/_matrix/client/v3/rooms/'+room+'/send/m.room.message/policy-test',
                        {'msgtype': 'm.text', 'body': 'Synthetic rejected plaintext'}, alice['access_token'], 'PUT')
                    expect(status, 403, 'Plaintext send')
                    status, _ = request(base, '/_matrix/client/v3/rooms/'+room+'/state/m.room.join_rules',
                        {'join_rule': 'public'}, alice['access_token'], 'PUT')
                    expect(status, 403, 'Public join downgrade')
                    print('Real Synapse room creation/contact/invite/encryption/plaintext boundaries passed.', flush=True)
                    return
                # Build first: one-use grants must not expire during SDK compilation.
                subprocess.run(['swift', 'build', '--build-tests', '--package-path', 'LettersMessaging'], check=True, timeout=600)
                probe_member = members['probe']
                expired_clock = admission.clock
                admission.clock = lambda: time.time()-61
                expired = admission.issue_matrix_login(probe_member['session_token'])
                admission.clock = expired_clock
                login(base, expired, 403)
                grant = admission.issue_matrix_login(probe_member['session_token'])
                wrong = dict(grant, user_id=admission.matrix_user_id(owner['member_id']))
                login(base, wrong, 403)
                authenticated = login(base, grant, 200)
                if not authenticated.get('device_id'):
                    raise RuntimeError('Login must create a real Matrix device')
                login(base, grant, 403)
                login(base, dict(grant, user_id='@uninvited:letters.test'), 403)
                # Existing tokens must lose normal client access on removal.
                token = authenticated['access_token']
                status, _ = request(base, '/_matrix/client/v3/sync?timeout=0', token=token)
                if status != 200:
                    raise RuntimeError('Approved session must sync before removal')
                admission.deactivate(owner['session_token'], probe_member['member_id'])
                status, denied = request(base, '/_matrix/client/v3/sync?timeout=0', token=token)
                if status != 403 or denied.get('errcode') != Codes.EXPIRED_ACCOUNT:
                    raise RuntimeError('Removed admission must block an existing session: status=' + str(status) + ', category=' + str(denied.get('errcode')))
                print('Letterbox login/replay/expiry/account-binding/removal boundaries passed.', flush=True)
                grants = {name: admission.issue_matrix_login(member['session_token'])
                          for name, member in members.items() if name != 'probe'}
                fixture = root/'accounts.json'
                fixture.write_text(json.dumps({'base': base, 'grants': grants, 'stores': str(root/'stores')}))
                fixture.chmod(0o600)
                test_env = dict(os.environ, LETTERS_MATRIX_TEST_FIXTURE=str(fixture))
                # Only test outcomes leave the runner: no accounts, grants,
                # access tokens, databases, stores or server logs are artifacts.
                subprocess.run(['swift', 'test', '--skip-build', '--package-path', 'LettersMessaging'],
                               env=test_env, check=True, timeout=180)
            finally:
                server.terminate()
                try:
                    server.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    server.kill(); server.wait()


if __name__ == '__main__':
    main()
