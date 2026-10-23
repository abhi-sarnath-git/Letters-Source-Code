"""Room authorization must remain independent of an authenticated user's claims."""
from pathlib import Path
import tempfile
import unittest
from letterbox_service import LetterboxService, Denied
from room_policy import RoomPolicy


class RoomPolicyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.service = LetterboxService(Path(self.tmp.name)/'admission.sqlite3', matrix_server_name='letters.test')
        self.owner = self.service.bootstrap()
        self.friends = [self.service.redeem(self.service.issue(self.owner['session_token'])['code'], name)
                        for name in ('First', 'Second')]
        self.policy = RoomPolicy(self.service)
        self.own = self.service.matrix_user_id(self.owner['member_id'])
        self.first, self.second = [self.service.matrix_user_id(m['member_id']) for m in self.friends]

    def tearDown(self):
        self.tmp.cleanup()

    def test_direct_binding_is_private_immutable_and_persistent(self):
        self.policy.bind('!direct:letters.test', self.own, peer_user_id=self.first)
        expected = sorted([self.own, self.first])
        self.assertEqual(RoomPolicy(self.service).authorize('!direct:letters.test', self.first), expected)
        with self.assertRaises(Denied): self.policy.authorize('!direct:letters.test', self.second)
        with self.assertRaises(Denied):
            self.policy.authorize('!direct:letters.test', self.own, invitee_user_id=self.second)
        with self.assertRaises(Denied):
            self.policy.bind('!direct:letters.test', self.own, peer_user_id=self.second)
        # A mutual inviter does not establish a personal contact edge.
        with self.assertRaises(Denied):
            self.policy.bind('!other:letters.test', self.first, peer_user_id=self.second)

    def test_removal_and_missing_rooms_fail_closed(self):
        with self.assertRaises(Denied): self.policy.authorize('!missing:letters.test', self.own)
        self.policy.bind('!direct:letters.test', self.own, peer_user_id=self.first)
        self.service.deactivate(self.owner['session_token'], self.friends[0]['member_id'])
        with self.assertRaises(Denied): self.policy.authorize('!direct:letters.test', self.own)
        with self.assertRaises(Denied): self.policy.authorize('!direct:letters.test', self.first)

    def test_group_authority_follows_admission_not_client_power_levels(self):
        group = self.service.create_group(self.owner['session_token'], 'Synthetic group')['id']
        with self.assertRaises(Denied): self.policy.bind('!group:letters.test', self.first, group_id=group)
        invitation = self.service.issue(self.owner['session_token'], group_id=group)
        self.service.redeem(invitation['code'], token=self.friends[0]['session_token'])
        self.policy.bind('!group:letters.test', self.own, group_id=group)
        self.assertEqual(self.policy.authorize('!group:letters.test', self.first), sorted([self.own, self.first]))
        with self.assertRaises(Denied):
            self.policy.authorize('!group:letters.test', self.first, invitee_user_id=self.own)
        with self.service.db() as c:
            c.execute('DELETE FROM group_members WHERE group_id=? AND member=?', (group, self.friends[0]['member_id']))
        with self.assertRaises(Denied): self.policy.authorize('!group:letters.test', self.first)
