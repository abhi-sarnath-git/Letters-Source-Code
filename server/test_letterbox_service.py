import concurrent.futures
import json
from pathlib import Path
import tempfile
import unittest
from letterbox_service import LetterboxService, Denied


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name)/'private.sqlite3'
        self.now = 1000
        self.service = LetterboxService(self.path,clock=lambda:self.now)
        self.owner = self.service.bootstrap()
        self.token = self.owner['session_token']

    def tearDown(self):
        self.tmp.cleanup()

    def join(self,name='Friend'):
        invite=self.service.issue(self.token)
        return self.service.redeem(invite['code'],name)

    def test_invite_code_and_session_are_hashed_and_one_use(self):
        invite=self.service.issue(self.token)
        friend=self.service.redeem(invite['code'].lower(), 'Alex')
        with self.assertRaises(Denied): self.service.redeem(invite['code'],'Replay')
        with self.service.db() as c:
            self.assertNotEqual(c.execute('SELECT hash FROM invitations').fetchone()[0],invite['code'])
            self.assertEqual(c.execute('SELECT count(*) FROM members').fetchone()[0],2)
        raw=self.path.read_bytes()
        self.assertNotIn(invite['code'].encode(),raw)
        self.assertNotIn(friend['session_token'].encode(),raw)

    def test_expiry_revocation_and_invalid_input(self):
        invite=self.service.issue(self.token,ttl=60)
        self.now+=60
        with self.assertRaises(Denied): self.service.redeem(invite['code'],'Alex')
        invite=self.service.issue(self.token)
        self.service.revoke(self.token,invite['id'])
        with self.assertRaises(Denied): self.service.redeem(invite['code'],'Alex')
        for code in ['',None,'DEMO-LBOX-'+('A'*32),'https://evil.example/','LBOX-'+'A'*31]:
            with self.assertRaises(Denied): self.service.redeem(code,'Alex')
        with self.assertRaises(Denied): self.service.issue('bad session')

    def test_concurrent_replay_creates_exactly_one_account(self):
        code=self.service.issue(self.token)['code']
        def attempt(_):
            try: return self.service.redeem(code,'Concurrent')['member_id']
            except Denied: return None
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            results=list(pool.map(attempt,range(6)))
        self.assertEqual(sum(r is not None for r in results),1)
        with self.service.db() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM members').fetchone()[0],2)

    def test_contacts_are_private_and_direct_room_is_idempotent(self):
        alex=self.join('Alex');sam=self.join('Sam')
        contacts=self.service.contacts(alex['session_token'])
        self.assertEqual([c['id'] for c in contacts],[self.owner['member_id']])
        with self.assertRaises(Denied): self.service.direct(alex['session_token'],sam['member_id'])
        first=self.service.direct(self.token,alex['member_id'])
        second=self.service.direct(alex['session_token'],self.owner['member_id'])
        self.assertEqual(first,second)
        self.assertFalse(first['messaging_available'])

    def test_group_admission_is_separate_authenticated_and_admin_only(self):
        friend=self.join()
        group=self.service.create_group(self.token,'Family')
        with self.assertRaises(Denied): self.service.group(friend['session_token'],group['id'])
        with self.assertRaises(Denied): self.service.issue(friend['session_token'],group['id'])
        invite=self.service.issue(self.token,group['id'])
        with self.assertRaises(Denied): self.service.redeem(invite['code'],'Unapproved')
        self.now+=5
        self.service.redeem(invite['code'],token=friend['session_token'])
        result=self.service.group(friend['session_token'],group['id'])
        self.assertEqual(result['joined'],self.now)
        self.assertNotIn('messages',result)

    def test_deactivation_revokes_sessions_and_outstanding_invitations(self):
        friend=self.join()
        invitation=self.service.issue(friend['session_token'])
        self.service.deactivate(self.token,friend['member_id'])
        with self.assertRaises(Denied): self.service.contacts(friend['session_token'])
        with self.assertRaises(Denied): self.service.redeem(invitation['code'],'Someone')
        with self.assertRaises(Denied): self.service.direct(self.token,friend['member_id'])

    def test_invalid_name_and_wrong_actor_do_not_consume_invite(self):
        friend=self.join()
        invite=self.service.issue(self.token)
        with self.assertRaises(Denied): self.service.redeem(invite['code'],' \n ')
        with self.assertRaises(Denied): self.service.revoke(friend['session_token'],invite['id'])
        self.assertIn('session_token',self.service.redeem(invite['code'],'Valid'))
        with self.assertRaises(Denied): self.service.bootstrap()

    def test_active_invitation_limit_and_restart_persistence(self):
        for _ in range(20): self.service.issue(self.token)
        with self.assertRaises(Denied): self.service.issue(self.token)
        reloaded=LetterboxService(self.path,clock=lambda:self.now)
        self.assertEqual(reloaded.contacts(self.token),[])


if __name__=='__main__': unittest.main()
