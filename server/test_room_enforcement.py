"""Exercise callback decisions without a Synapse dependency or real secrets."""
import asyncio
from types import SimpleNamespace
import unittest
from letterbox_service import Denied
from letters_room_enforcement import LettersRoomEnforcement


class EnforcementTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.module = LettersRoomEnforcement.__new__(LettersRoomEnforcement)
        self.module.allowed, self.module.denied = 'allow', 'deny'
        self.approved = True
        async def authorized(*args): return self.approved
        self.module._authorized = authorized

    async def test_cleartext_unknown_events_and_downgrades_are_denied(self):
        for kind, content in [('m.room.message', {'body': 'synthetic'}),
                              ('m.room.encryption', {'algorithm': 'none'}),
                              ('m.room.join_rules', {'join_rule': 'public'}),
                              ('m.room.history_visibility', {'history_visibility': 'world_readable'}),
                              ('unknown.event', {})]:
            event = SimpleNamespace(room_id='!synthetic:test', sender='@synthetic:test', type=kind, content=content)
            self.assertEqual(await self.module.check_event(event), 'deny')
        encrypted = SimpleNamespace(room_id='!synthetic:test', sender='@synthetic:test',
                                    type='m.room.encrypted', content={'algorithm':'m.megolm.v1.aes-sha2'})
        self.assertEqual(await self.module.check_event(encrypted), 'allow')
        self.approved = False
        self.assertEqual(await self.module.check_event(encrypted), 'deny')

    async def test_join_requires_invitation_and_current_approval(self):
        self.assertEqual(await self.module.may_join('@synthetic:test', '!synthetic:test', False), 'deny')
        self.assertEqual(await self.module.may_join('@synthetic:test', '!synthetic:test', True), 'allow')
        self.approved = False
        self.assertEqual(await self.module.may_join('@synthetic:test', '!synthetic:test', True), 'deny')
