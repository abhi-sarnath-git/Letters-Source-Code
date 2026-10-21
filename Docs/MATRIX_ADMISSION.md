# Letterbox-to-Matrix admission bridge — development only

Approved Letterbox members can now request a **60-second, one-use device-login grant** from `POST /v1/messaging/login-grant` with their admission bearer session. The deployment fixes the Matrix domain; callers cannot choose a target account, domain or expiry. This endpoint is disabled unless the local service has an explicit `--matrix-server-name`.

The admission UUID deterministically maps to one opaque local Matrix ID. Only a grant hash is stored, bound to that ID and the issuing admission session. Issuing a fresh grant invalidates the member's older unused grant; at most ten grants per member/hour are issued. Atomic consumption rejects expired, replaced, replayed, wrong-account and removed-member credentials. No permanent Matrix password or admin impersonation token is distributed.

`letters_synapse_auth.LettersAuthProvider` uses Synapse's supported password-auth callback to consume the grant, lazily create a non-admin account, and allow ordinary SDK login to create a real device. The admission database must already exist. SQLite work runs in Synapse's thread pool, and approval is checked again after account creation. The account-validity callback blocks ordinary authenticated requests when membership is removed or the database cannot be read. Logout/revocation endpoints may intentionally permit expired sessions; this is not a claim that every token is erased or every in-flight sync is cancelled.

The trusted test configuration disables public registration, local-password authentication and federation; it exposes client APIs only on IPv4 loopback. Do not add another auth provider/password fallback without reviewing whether it bypasses Letterbox. Admin impersonation is unsuitable for client sign-in because those tokens have no device identity.

The Swift `LetterboxLoginGrant` model decodes the response, validates format/expiry, redacts debug descriptions and binds login to the expected account. The existing HTTPS-configured SDK client exchanges the grant for a normal Keychain-backed device session. A grant is not stored as a password and does not choose the homeserver. Lost/consumed grants require another authenticated request. Subsequent/new-device verification and recovery remain unfinished.

## Verification

Five additional Python tests cover grant hashing, expiry, replay races, replacement, binding, session expiry, removal, limits, opt-in configuration and stable IDs. The hosted harness loads the actual module into pinned Synapse and tests failed logins, a successful real-device login, replay and loss of normal `/sync` access after removal. Independent SDK clients then sign in with fresh approved grants and exercise encrypted exchange, server ciphertext and the existing failure/restore/logout checks.

Swift tests check credential validation and redacted debug output. The fixture contains synthetic credentials only, is created after SDK compilation so grants do not expire during builds, and is deleted rather than published. All source is annotated; see `CODE_GUIDE.md`.

## Outstanding before real use

The preview invitation/composer UI is not connected to the HTTP admission service or SDK. Matrix room creation/invitation policy does not yet enforce personal contact edges or group administration against a modified client. Current access checks are point-in-time: no guarantee covers cancellation of in-flight requests, key recovery, removing previously decrypted history or a malicious homeserver. Do not deploy this development module or enable live user UI before review, room-policy integration, TLS/abuse controls, device verification/recovery and physical-device tests.

The native QR screenshot remains a local preview; no new image claims this backend boundary is working private chat UI.

## Official API references

- [Synapse password-auth callbacks](https://element-hq.github.io/synapse/latest/modules/password_auth_provider_callbacks.html)
- [Account-validity callbacks](https://element-hq.github.io/synapse/latest/modules/account_validity_callbacks.html)
- [Synapse module API at the tested release](https://github.com/element-hq/synapse/blob/v1.163.0/synapse/module_api/__init__.py)
- [Password configuration](https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html#password_config)
