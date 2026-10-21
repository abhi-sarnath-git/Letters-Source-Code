"""Development Synapse module connecting approved Letterbox members to devices.

Load only on the isolated single-process test server until deployment review.
No passwords, grants, access tokens or message contents belong in module logs.
"""
import sqlite3
from pathlib import Path

from letterbox_service import Denied, LetterboxService


class LettersAuthProvider:
    @staticmethod
    def parse_config(config):
        # Require an existing private admission database. A typo must not create
        # an empty replacement database and silently change the approval source.
        path = Path(config['admission_database']).resolve(strict=True)
        if not path.is_file():
            raise ValueError('Admission database required')
        return {'admission_database': str(path)}

    def __init__(self, config, api):
        self.api = api
        self.admission = LetterboxService(config['admission_database'], matrix_server_name=api.server_name)
        # Use the SDK's ordinary login path so Synapse creates a real device;
        # admin impersonation tokens have no device and cannot replace this.
        api.register_password_auth_provider_callbacks(
            auth_checkers={('m.login.password', ('password',)): self.check_auth})
        api.register_account_validity_callbacks(is_user_expired=self.is_user_expired)

    async def check_auth(self, user, login_type, login_dict):
        """Consume a grant, lazily register its user, then allow device login."""
        if login_type != 'm.login.password' or not isinstance(user, str):
            return None
        user_id = user if user.startswith('@') else '@' + user + ':' + self.api.server_name
        try:
            # SQLite work runs outside Synapse's reactor. No SQL transaction is
            # held while awaiting remote/account registration work.
            member = await self.api.defer_to_thread(
                self.admission.consume_matrix_login, user_id, login_dict.get('password'))
            existing = await self.api.check_user_exists(user_id)
            if existing is None:
                localpart = user_id[1:].split(':', 1)[0]
                await self.api.register_user(localpart=localpart, displayname=member['name'], admin=False)
            # Approval can change while registration yields; check it again.
            if not await self.api.defer_to_thread(self.admission.matrix_account_active, user_id):
                return None
            return user_id, None
        except (Denied, sqlite3.Error):
            # Generic denial avoids disclosing whether the grant/account exists.
            return None

    async def is_user_expired(self, user_id):
        """Block authenticated requests after admission removal or DB failure."""
        try:
            active = await self.api.defer_to_thread(self.admission.matrix_account_active, user_id)
            return not active
        except sqlite3.Error:
            # An unavailable approval database must not extend existing access.
            return True
