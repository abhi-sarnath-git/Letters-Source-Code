"""Authoritative room permissions derived from Letterbox, never client rosters.

This policy deliberately has no message decryption keys. The Matrix adapter must
call it on room creation, invitations, joins and sends; client guards alone are
not an authorization boundary.
"""
import re
import uuid

from letterbox_service import Denied


class RoomPolicy:
    def __init__(self, admission):
        self.admission = admission
        with admission.db() as c:
            c.execute('''CREATE TABLE IF NOT EXISTS authorized_matrix_rooms(
                room_id TEXT PRIMARY KEY, creator TEXT NOT NULL,
                peer TEXT, group_id TEXT,
                CHECK ((peer IS NULL) != (group_id IS NULL)))''')

    def _member(self, c, user_id):
        server = self.admission.matrix_server_name
        match = re.fullmatch(r'@letters_([0-9a-f]{32}):' + re.escape(server or ''), user_id or '')
        if match is None or server is None:
            raise Denied('Approved local account required')
        member = str(uuid.UUID(hex=match[1]))
        if not c.execute('SELECT 1 FROM members WHERE id=? AND active=1', (member,)).fetchone():
            raise Denied('Approved local account required')
        return member

    def _audience(self, c, room):
        # Query live approval on every operation; removing an account/contact or
        # group membership must not leave a cached permission valid indefinitely.
        creator = room['creator']
        if room['peer'] is not None:
            peer = room['peer']
            a, b = sorted([creator, peer])
            if not c.execute('SELECT 1 FROM contacts WHERE a=? AND b=?', (a, b)).fetchone():
                raise Denied('Contact approval required')
            members = {creator, peer}
        else:
            members = {r[0] for r in c.execute(
                'SELECT member FROM group_members WHERE group_id=?', (room['group_id'],))}
        active = {r[0] for r in c.execute('SELECT id FROM members WHERE active=1')}
        if not members or not members.issubset(active):
            raise Denied('Room approval changed')
        return members

    def bind(self, room_id, creator_user_id, *, peer_user_id=None, group_id=None):
        """Called by a trusted server adapter, never exposed as a client route.

        Binding is immutable. A room cannot be repurposed after it has acquired
        encrypted history. Creation must separately enforce private/encrypted
        state and prevent invitations before this transaction succeeds.
        """
        if not isinstance(room_id, str) or not room_id.startswith('!') or len(room_id) > 512:
            raise Denied('Invalid room')
        if (peer_user_id is None) == (group_id is None):
            raise Denied('Choose one room kind')
        with self.admission.db() as c:
            creator = self._member(c, creator_user_id)
            peer = None
            if peer_user_id is not None:
                peer = self._member(c, peer_user_id)
                if creator == peer:
                    raise Denied('Different contact required')
            elif not isinstance(group_id, str) or not c.execute(
                'SELECT 1 FROM groups WHERE id=? AND admin=?', (group_id, creator)).fetchone():
                raise Denied('Group administrator required')
            desired = {'creator': creator, 'peer': peer, 'group_id': group_id}
            self._audience(c, desired)
            existing = c.execute('SELECT * FROM authorized_matrix_rooms WHERE room_id=?', (room_id,)).fetchone()
            if existing is not None:
                if any(existing[key] != value for key, value in desired.items()):
                    raise Denied('Room binding cannot change')
                return
            c.execute('INSERT INTO authorized_matrix_rooms VALUES(?,?,?,?)',
                      (room_id, creator, peer, group_id))

    def authorize(self, room_id, actor_user_id, *, invitee_user_id=None):
        """Resolve current authority or raise; unknown rooms fail closed.

        Returned IDs are metadata for the server, not a decryption grant. Group
        invitations require the group's current administrator, not merely a
        Matrix power-level supplied by another client.
        """
        with self.admission.db() as c:
            actor = self._member(c, actor_user_id)
            room = c.execute('SELECT * FROM authorized_matrix_rooms WHERE room_id=?', (room_id,)).fetchone()
            if room is None:
                raise Denied('Unapproved room')
            audience = self._audience(c, room)
            if actor not in audience:
                raise Denied('Room membership required')
            if invitee_user_id is not None:
                invitee = self._member(c, invitee_user_id)
                if invitee not in audience:
                    raise Denied('Recipient is not approved for this room')
                if room['group_id'] is not None and not c.execute(
                    'SELECT 1 FROM groups WHERE id=? AND admin=?', (room['group_id'], actor)).fetchone():
                    raise Denied('Group administrator required')
            return sorted(self.admission.matrix_user_id(member) for member in audience)
