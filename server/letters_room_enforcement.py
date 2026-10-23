"""Fail-closed Synapse boundary for server-provisioned Letters rooms.

This module is intentionally separate from the legacy SDK test server. Rooms
must be bound by trusted provisioning before clients can use them. Do not turn
this on with the old unrestricted room-creation flow: it will refuse those rooms.
"""
import sqlite3
from letters_synapse_auth import LettersAuthProvider
from letterbox_service import Denied, LetterboxService
from room_policy import RoomPolicy


class LettersRoomEnforcement:
    parse_config = staticmethod(LettersAuthProvider.parse_config)

    def __init__(self, config, api):
        # Import Synapse only when loading its adapter; policy unit tests do not
        # require installing or starting a homeserver.
        from synapse.module_api import NOT_SPAM
        from synapse.module_api.errors import Codes
        self.allowed, self.denied = NOT_SPAM, Codes.FORBIDDEN
        self.api = api
        self.policy = RoomPolicy(LetterboxService(config['admission_database'],
                                                matrix_server_name=api.server_name))
        api.register_third_party_rules_callbacks(
            on_create_room=self.on_create_room,
            check_event_allowed=self.check_creation,
            check_visibility_can_be_modified=self.visibility)
        api.register_spam_checker_callbacks(user_may_join_room=self.may_join,
                                           user_may_invite=self.may_invite,
                                           check_event_for_spam=self.check_event)

    async def on_create_room(self, requester, request_content, is_requester_admin):
        from synapse.module_api.errors import SynapseError
        # A group selector is only a reference: bind() independently checks the
        # current admission administrator and members before persisting authority.
        invites = request_content.get('invite', [])
        group = request_content.pop('letters_group_id', None)
        if not isinstance(invites, list) or not all(isinstance(v, str) for v in invites):
            raise SynapseError(403, 'Letters room approval required')
        if request_content.get('visibility', 'private') != 'private' or request_content.get('room_alias_name'):
            raise SynapseError(403, 'Letters rooms are private')
        if group is None and len(invites) != 1:
            raise SynapseError(403, 'Choose one approved contact')
        creation = dict(request_content.get('creation_content', {}))
        creation['m.federate'] = False
        creation['org.letters.policy'] = {'peer': invites[0] if group is None else None,
                                         'group': group, 'invites': invites}
        request_content['creation_content'] = creation
        # Replace security-sensitive initial state rather than trusting a preset
        # or client-supplied duplicate state entries.
        secured = {'m.room.encryption': {'algorithm': 'm.megolm.v1.aes-sha2'},
                   'm.room.join_rules': {'join_rule': 'invite'},
                   'm.room.history_visibility': {'history_visibility': 'joined'},
                   'm.room.guest_access': {'guest_access': 'forbidden'}}
        initial = request_content.get('initial_state', [])
        if not isinstance(initial, list) or not all(isinstance(v, dict) for v in initial):
            raise SynapseError(403, 'Invalid initial state')
        request_content['initial_state'] = [v for v in initial if v.get('type') not in secured] + [
            {'type': kind, 'state_key': '', 'content': value} for kind, value in secured.items()]
        request_content['preset'] = 'private_chat'

    async def check_creation(self, event, state_events):
        if event.type != 'm.room.create':
            return True, None
        try:
            policy = event.content.get('org.letters.policy', {})
            await self.api.defer_to_thread(self.policy.bind, event.room_id, event.sender,
                                           peer_user_id=policy.get('peer'), group_id=policy.get('group'))
            audience = await self.api.defer_to_thread(self.policy.authorize, event.room_id, event.sender)
            if set(policy.get('invites', [])) != set(audience) - {event.sender}:
                return False, None
            return event.content.get('m.federate') is False, None
        except (Denied, sqlite3.Error, TypeError, ValueError):
            return False, None

    async def visibility(self, room_id, state_events, new_visibility):
        return new_visibility == 'private'

    async def _authorized(self, room, actor, invitee=None):
        try:
            await self.api.defer_to_thread(self.policy.authorize, room, actor,
                                           invitee_user_id=invitee)
            return True
        except (Denied, sqlite3.Error):
            # Database failure must never preserve access by falling back to a
            # cached membership list. No credentials/event bodies enter logs.
            return False

    async def may_join(self, user, room, is_invited):
        return self.allowed if is_invited and await self._authorized(room, user) else self.denied

    async def may_invite(self, inviter, invitee, room_id):
        return self.allowed if await self._authorized(room_id, inviter, invitee) else self.denied

    async def check_event(self, event):
        if event.type == 'm.room.create':
            return self.allowed if (await self.check_creation(event, {}))[0] else self.denied
        if not await self._authorized(event.room_id, event.sender):
            return self.denied
        kind, content = event.type, event.content
        # The server can enforce encrypted envelopes without seeing plaintext.
        # Checking a room's encryption flag alone would allow injected cleartext.
        if kind == 'm.room.message':
            return self.denied
        if kind == 'm.room.encrypted':
            return self.allowed if content.get('algorithm') == 'm.megolm.v1.aes-sha2' else self.denied
        if kind == 'm.room.member':
            if content.get('membership') == 'invite':
                return await self.may_invite(event.sender, event.state_key, event.room_id)
            if content.get('membership') == 'join':
                return self.allowed if event.sender == event.state_key else self.denied
            # Leave/ban authority also remains subject to normal Matrix auth.
            return self.allowed if content.get('membership') in ('leave', 'ban') else self.denied
        if kind == 'm.room.encryption':
            return self.allowed if content.get('algorithm') == 'm.megolm.v1.aes-sha2' else self.denied
        if kind == 'm.room.join_rules':
            return self.allowed if content.get('join_rule') == 'invite' else self.denied
        if kind == 'm.room.history_visibility':
            return self.allowed if content.get('history_visibility') == 'joined' else self.denied
        if kind == 'm.room.guest_access':
            return self.allowed if content.get('guest_access') == 'forbidden' else self.denied
        # No generic allow fallback: new event types need explicit review.
        return self.allowed if kind in ('m.room.name', 'm.room.topic', 'm.room.avatar',
                                       'm.room.power_levels', 'm.room.redaction') else self.denied
