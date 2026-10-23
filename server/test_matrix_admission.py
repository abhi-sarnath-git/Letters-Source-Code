"""Test the admission-to-device boundary without a server or real credentials."""
import concurrent.futures
from pathlib import Path
import tempfile
import unittest
from letterbox_service import Denied, LetterboxService


class MatrixAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.now = 1000
        self.path = Path(self.tmp.name) / 'admission.sqlite3'
        self.service = LetterboxService(self.path, clock=lambda: self.now, matrix_server_name='letters.test')
        self.owner = self.service.bootstrap()
        invitation = self.service.issue(self.owner['session_token'])
        self.friend = self.service.redeem(invitation['code'], 'Synthetic Friend')

    def tearDown(self):
        self.tmp.cleanup()

    def test_room_audience_requires_personal_contact_and_current_session(self):
        token = self.friend['session_token']
        result = self.service.matrix_room_audience(token, contact_id=self.owner['member_id'])
        self.assertEqual(result['recipient_user_ids'],
                         [self.service.matrix_user_id(self.owner['member_id'])])
        invitation = self.service.issue(self.owner['session_token'])
        other = self.service.redeem(invitation['code'], 'Separate contact')
        # Sharing an inviter does not make two people each other's contacts.
        with self.assertRaises(Denied):
            self.service.matrix_room_audience(token, contact_id=other['member_id'])
        for kwargs in ({}, {'contact_id': self.owner['member_id'], 'group_id': 'x'},
                       {'contact_id': self.friend['member_id']}, {'group_id': 'unknown'}):
            with self.assertRaises(Denied): self.service.matrix_room_audience(token, **kwargs)
        with self.assertRaises(Denied):
            self.service.matrix_room_audience('invalid', contact_id=self.owner['member_id'])
        self.service.deactivate(self.owner['session_token'], self.friend['member_id'])
        with self.assertRaises(Denied):
            self.service.matrix_room_audience(token, contact_id=self.owner['member_id'])

    def test_group_audience_is_member_only_and_not_the_contact_directory(self):
        group = self.service.create_group(self.owner['session_token'], 'Synthetic group')
        own = self.service.matrix_room_audience(self.owner['session_token'], group_id=group['id'])
        self.assertEqual(own['recipient_user_ids'], [])
        with self.assertRaises(Denied):
            self.service.matrix_room_audience(self.friend['session_token'], group_id=group['id'])

    def test_grant_is_hashed_bound_to_account_and_single_use(self):
        grant = self.service.issue_matrix_login(self.friend['session_token'])
        self.assertNotIn(grant['login_grant'].encode(), self.path.read_bytes())
        wrong = self.service.matrix_user_id(self.owner['member_id'])
        with self.assertRaises(Denied):
            self.service.consume_matrix_login(wrong, grant['login_grant'])
        # A wrong-account attempt does not consume the correct account's grant.
        member = self.service.consume_matrix_login(grant['user_id'], grant['login_grant'])
        self.assertEqual(member['id'], self.friend['member_id'])
        with self.assertRaises(Denied):
            self.service.consume_matrix_login(grant['user_id'], grant['login_grant'])

    def test_expiry_replacement_session_revocation_and_removal(self):
        first = self.service.issue_matrix_login(self.friend['session_token'])
        replacement = self.service.issue_matrix_login(self.friend['session_token'])
        with self.assertRaises(Denied): self.service.consume_matrix_login(first['user_id'], first['login_grant'])
        self.now += 60
        with self.assertRaises(Denied): self.service.consume_matrix_login(replacement['user_id'], replacement['login_grant'])
        fresh = self.service.issue_matrix_login(self.friend['session_token'])
        self.service.deactivate(self.owner['session_token'], self.friend['member_id'])
        self.assertFalse(self.service.matrix_account_active(fresh['user_id']))
        with self.assertRaises(Denied): self.service.consume_matrix_login(fresh['user_id'], fresh['login_grant'])
        with self.assertRaises(Denied): self.service.issue_matrix_login(self.friend['session_token'])

    def test_concurrent_grant_replay_allows_one_login(self):
        grant = self.service.issue_matrix_login(self.friend['session_token'])
        def attempt(_):
            try:
                self.service.consume_matrix_login(grant['user_id'], grant['login_grant'])
                return True
            except Denied:
                return False
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            self.assertEqual(sum(pool.map(attempt, range(8))), 1)

    def test_session_expiry_and_hourly_limit_fail_closed(self):
        grant = self.service.issue_matrix_login(self.friend['session_token'])
        with self.service.db() as connection:
            connection.execute('UPDATE sessions SET expires=? WHERE member=?', (self.now, self.friend['member_id']))
        with self.assertRaises(Denied): self.service.consume_matrix_login(grant['user_id'], grant['login_grant'])
        for _ in range(10): self.service.issue_matrix_login(self.owner['session_token'])
        with self.assertRaises(Denied): self.service.issue_matrix_login(self.owner['session_token'])
        self.now += 3601
        self.assertIn('login_grant', self.service.issue_matrix_login(self.owner['session_token']))

    def test_only_current_approved_identity_is_active_and_bridge_is_opt_in(self):
        user = self.service.matrix_user_id(self.friend['member_id'])
        self.assertTrue(self.service.matrix_account_active(user))
        self.assertFalse(self.service.matrix_account_active(user.replace('letters.test', 'external.test')))
        self.assertFalse(self.service.matrix_account_active('@unknown:letters.test'))
        disabled = LetterboxService(self.path)
        with self.assertRaises(Denied): disabled.issue_matrix_login(self.owner['session_token'])
        with self.assertRaises(Denied): self.service.issue_matrix_login('not authenticated')
        reopened = LetterboxService(self.path, matrix_server_name='letters.test')
        self.assertEqual(reopened.matrix_user_id(self.friend['member_id']), user)
