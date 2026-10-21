# Security architecture — proposed, not implemented

## Foundation

Use supported Matrix Rust SDK Swift bindings for sessions, synchronization, encrypted rooms, encrypted attachments, device trust, and recovery. Do not create a custom cryptographic protocol or treat TLS as E2EE. Pin and review an SDK release and its known limitations before integration. The SDK alone does not deliver WhatsApp feature parity or guarantee the security of our app.

## Membership boundary

Use a private server with public registration disabled and controlled account provisioning, or a compatible authentication service with server-validated invitations. Disallow external membership and federation at the server/network boundary where the family-only deployment requires it. Verify those restrictions with a separate external account. Client-side hiding of signup is not access control. Invites require expiry, single-use redemption, revocation and abuse controls; account removal must revoke sessions and block future access. It cannot erase plaintext already seen or saved by a former member.

## Client requirements

Require encrypted rooms before any real message is accepted for sending. Do not fall back to plaintext if device trust, key state, or crypto initialization fails. Store access tokens in Keychain; keep the SDK store protected using its supported secure-storage configuration and iOS file protection. Preserve device identity across restarts. Implement verification, cross-signing, key change warnings and recovery UX using the SDK's actual state. Do not paint a lock icon based on an arbitrary boolean.

Attachments, thumbnails, voice notes, status updates and other user content need explicit encrypted designs. Link previews must not leak message contents to a server-side preview fetcher. Push payloads must not contain message plaintext or sensitive preview content; implement a compatible push gateway and account for metadata. The membership server and delivery service will still observe some metadata even with E2EE.

## Recovery and backup

Back up room keys only through the SDK-supported encrypted recovery mechanisms. Explain what a lost recovery key means. Do not store decryptable message archives or recovery secrets alongside ciphertext on the server. Define retention, deletion, restore and device-transfer behavior. Membership administration must not grant the administrator message decryption capabilities.

## Calls

Choose a supported encrypted calling stack compatible with the selected Matrix deployment. Verify end-to-end media encryption across one-to-one voice, group voice, reconnect and TURN/SFU paths. Transport encryption to a relay is insufficient. Integrate CallKit, audio sessions and supported Apple background/VoIP push behavior. No calling stack is integrated yet.

## Alert All

Alert All replaces video calling by owner request. Emergency details, acknowledgements and resolution updates must be encrypted for all approved members, with server-enforced membership, replay protection and truthful delivery state. Do not put emergency text or keys in APNs payloads. Never equate notification acceptance with a human response. See ALERT_ALL.md for acceptance criteria and platform limits. No live alert transport exists yet.

## Required integration evidence before a family pilot

1. Two independently signed-in devices exchange encrypted text and attachments; inspect captured server events for absence of plaintext.
2. An uninvited user cannot register, join, discover private groups or message members through an external server.
3. Missing room encryption, missing crypto initialization and invalid session state block sending without a plaintext fallback.
4. New/unverified devices, key changes, device revocation, reinstallation and encrypted recovery behave as documented.
5. Expired/replayed/revoked invites fail at the server; a removed account cannot regain access through a cached session.
6. Notifications, logs, analytics, backups and crash reports contain no message plaintext or reusable secrets.
7. Offline queues, duplicates, failed uploads and retries preserve encryption and correct user-visible status.
8. Calling and other feature families receive their own cryptographic and platform validation before being enabled.

The current portfolio preview has no messaging transport or cryptographic dependency. Home uses isolated public RSS requests for news; see WORLD_PULSE.md. Those requests contain no chats, contact lists or invitation credentials. It cannot be used to send encrypted messages. Its unit tests exercise release bookkeeping and local alert rehearsal state; they are not the evidence above or a security audit.

## Letterbox admission prototype

See LETTERBOX.md. A separate loopback-only admission service implements hashed invitations/sessions, transactional single-use redemption, restricted contact/group metadata and member deactivation. It is not deployed, not production reviewed and not connected to Matrix or the native preview. The native demo codes are deliberately separate from service codes. Neither prototype grants a client the authority to declare real membership or encryption.
