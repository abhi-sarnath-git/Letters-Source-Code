# Encrypted messaging foundation — development only

The native preview now links a separate `LettersMessaging` package using the Matrix Rust SDK Swift bindings, pinned to **26.10.02** (tag commit `55650a2320cc6e3264c1d5508a5094f8dd7e51a5`; upstream binary SHA-256 `954420a70dee62f3c73a772d530b9668da17393da3bc71a219f0105006f93573`). The sample composer is deliberately not connected. There is no deployed Letters messaging server or real user login screen. This milestone does not make the portfolio app a usable private messenger.

## Implemented boundary

- Password sign-in, session restoration and explicit server logout through the SDK. Passwords are not retained.
- One atomic Keychain record contains the access/refresh session and a random 32-byte SDK SQLite store key. Items are nonsynchronizing and accessible only when unlocked on this device. SDK directories are excluded from backup, owner-only, and receive complete file protection on iOS.
- Production configuration requires a bare HTTPS server URL, rejects embedded credentials/query/fragment/path, disables well-known server discovery and retains TLS verification. Only an internal test initializer accepts IPv4 loopback HTTP.
- Cross-signing is enabled; key sharing uses the SDK's identity-based strategy, with cross-signed sender devices required for decryption. Automatic server backups are disabled pending recovery UX. Cross-signing is **not** proof of a person's identity or a substitute for contact verification.
- New rooms are private, invite-only, encrypted at creation, and history is limited to joined members. No automatic joining of unsolicited rooms. An explicitly accepted invitation is joined before full encryption state can be fetched; the client immediately checks it and attempts to leave on failure, without sending any message.
- Before sending text, the client checks session/key storage, SDK crypto keys, joined membership, authoritative room encryption state, and the expected active member set. It refuses plaintext/unknown encryption and mismatched audiences. It never upgrades a plaintext room or retries through an unencrypted transport.
- JSON encoding handles message text, limited to 16 KB. A successful send returns the actual server event ID. This means server acceptance, **not** delivery, decryption, reading, or a human acknowledgement.
- SDK operations are serialized across actor suspension points. Local close preserves the session; logout revokes it before deleting local credentials. Logout failure retains credentials to retry revocation. Encrypted store files remain pending the deletion/recovery design.

E2EE protects message text; the homeserver still sees metadata such as room names, membership and event timing. The recipient check is a point-in-time defense, not atomic server authorization. Matrix membership alone does not prove Letters approval. The admission service must ultimately control account provisioning, contact authorization, room membership and removal. No live client should be enabled before that bridge and device verification exist.

## Integration test

`scripts/test-encrypted-messaging.py` starts pinned Synapse **1.163.0** on a kernel-selected `127.0.0.1` port inside an ephemeral directory. Public registration is disabled, only client HTTP resources are exposed, and federation is restricted. An ephemeral registration secret provisions three synthetic test users. No live account or Oracle resources are used.

The Swift integration test signs in independent clients and checks:

1. An encrypted private room sends real text that the second SDK client decrypts.
2. The actual homeserver event is `m.room.encrypted`, uses Megolm, contains ciphertext, and contains neither a plaintext body nor the synthetic message.
3. An uninvited third account cannot read the event or join the room; unauthenticated signup is disabled.
4. A changed expected audience and a plaintext room block sending; explicitly accepting a plaintext invitation immediately leaves that room.
5. Closing/restoring preserves the sender's device identity and message decryption; logout removes its local session.

Separate deterministic tests check production URL restrictions, independent random store keys and storage-failure blocking. Integration tests use an in-memory session-vault double; **real iOS Keychain behavior, locked-device handling and reboot/reinstall behavior still require device tests**. Both clients run in one hosted Mac process, not on separate physical iPhones. Test accounts, tokens, database, key stores and private server logs are deleted and are not uploaded as artifacts.

Run using Python 3.12 in a private virtual environment with `matrix-synapse==1.163.0`, then invoke that environment's Python on the script from the repository root. Full Xcode/current Swift and the pinned SDK binary download are required. The hosted workflow performs this setup; no local Xcode installation or hosting purchase is needed.

## Verified source

Source [`4eaf24821dae85f11bb324fef496acf697008f31`](https://github.com/abhi-sarnath-git/Letters-Source-Code/commit/4eaf24821dae85f11bb324fef496acf697008f31), [hosted run 39560168763](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39560168763): all four messaging tests, existing admission/core/news checks and native iPhone simulator compilation passed on 21 October 2026. The integration test was enabled, not skipped. The two SDK clients used different accounts, device identities and persistent stores in one Mac test process. This is not a physical-device or interactive chat test.

## Remaining release gates

Connect server-enforced Letterbox membership to real accounts and encrypted rooms; add usable live chat sync/history, verification/key-change warnings, encrypted recovery, media/stickers, offline queue and delivery states. Add real-device security/lifecycle tests and review logs, database artifacts and notification payloads. Voice calls and Alert All need separate encrypted transports and notification verification.

A successful integration run establishes only the tested exchange and failure cases. It is not a security audit, production deployment, proof against a malicious server, or full WhatsApp feature parity.

## Sources and licensing

- [Pinned Swift package and binary manifest](https://github.com/matrix-org/matrix-rust-components-swift/tree/26.10.02)
- [Matrix Rust SDK](https://github.com/matrix-org/matrix-rust-sdk)
- [Synapse installation requirements](https://element-hq.github.io/synapse/latest/setup/installation.html)
- [Synapse test release](https://github.com/element-hq/synapse/releases/tag/v1.163.0)

Matrix Rust SDK's Apache 2.0 license is retained under `ThirdParty/MatrixRustSDK-LICENSE.txt`. Transitive dependencies and binary contents still need a release notice/license inventory. Synapse is an isolated test dependency; it is not bundled with the app.
