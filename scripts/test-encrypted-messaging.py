"""Isolated CI-only Synapse. No public listener, federation, real users or artifacts."""
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


def request(base, path, data=None):
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(base + path, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as response:
        return json.load(response)


def main():
    with tempfile.TemporaryDirectory(prefix="letters-encryption-") as temporary:
        root = Path(temporary)
        # Kernel-selected port; listener is explicitly IPv4 loopback-only.
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        secret = secrets.token_hex(32)
        config = {
            "server_name": "letters.test", "pid_file": str(root / "synapse.pid"),
            "listeners": [{"port": port, "tls": False, "type": "http", "bind_addresses": ["127.0.0.1"],
                           "resources": [{"names": ["client"], "compress": False}]}],
            "database": {"name": "sqlite3", "args": {"database": str(root / "homeserver.db")}},
            "media_store_path": str(root / "media"), "signing_key_path": str(root / "signing.key"),
            "report_stats": False, "enable_registration": False,
            "registration_shared_secret": secret, "trusted_key_servers": [],
            "suppress_key_server_warning": True, "federation_domain_whitelist": [],
            "serve_server_wellknown": False, "enable_media_repo": False,
            "rc_login": {"address": {"per_second": 100, "burst_count": 100},
                         "account": {"per_second": 100, "burst_count": 100},
                         "failed_attempts": {"per_second": 100, "burst_count": 100}},
            "rc_message": {"per_second": 100, "burst_count": 100},
        }
        # JSON is valid YAML; do not print this configuration or account fixture.
        config_path = root / "homeserver.yaml"
        config_path.write_text(json.dumps(config))
        config_path.chmod(0o600)
        base = f"http://127.0.0.1:{port}"
        with (root / "synapse.log").open("wb") as log:
            server = subprocess.Popen([sys.executable, "-m", "synapse.app.homeserver", "-c", str(config_path)],
                                      stdout=log, stderr=subprocess.STDOUT, cwd=root)
            try:
                for _ in range(120):
                    if server.poll() is not None:
                        raise RuntimeError("Isolated homeserver exited; private logs were not published")
                    try:
                        request(base, "/_matrix/client/versions")
                        break
                    except (OSError, urllib.error.URLError):
                        time.sleep(.5)
                else:
                    raise RuntimeError("Isolated homeserver did not become ready")
                accounts = {}
                for username in ("alice", "bob", "outsider"):
                    password = secrets.token_urlsafe(32)
                    nonce = request(base, "/_synapse/admin/v1/register")["nonce"]
                    message = b"\x00".join(x.encode() for x in (nonce, username, password, "notadmin"))
                    mac = hmac.new(secret.encode(), message, hashlib.sha1).hexdigest()
                    request(base, "/_synapse/admin/v1/register", {
                        "nonce": nonce, "username": username, "password": password, "admin": False, "mac": mac})
                    accounts[username] = password
                fixture = root / "accounts.json"
                fixture.write_text(json.dumps({"base": base, "accounts": accounts, "stores": str(root / "stores")}))
                fixture.chmod(0o600)
                env = dict(os.environ, LETTERS_MATRIX_TEST_FIXTURE=str(fixture))
                # No tokens, account fixture, database, SDK store or server logs
                # are uploaded. Only synthetic test outcomes reach the CI log.
                subprocess.run(["swift", "test", "--package-path", "LettersMessaging"], env=env, check=True)
            finally:
                server.terminate()
                try:
                    server.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    server.kill(); server.wait()


if __name__ == "__main__":
    main()
