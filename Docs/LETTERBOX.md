# Letterbox invitations

## Implemented on 21 October 2026

The native preview has an invite/accept flow from the envelope button on Chats. Every approved member can issue their own Letterbox QR. Contact relationships are per member: when Maya invites Alex, Alex and Maya become contacts, while the owner and unrelated members gain no contact access. A clearly labelled local profile selector lets you demonstrate each fictional member’s separate contact list and empty conversations; it is not live account switching or a production member directory. Every profile can create its own sample groups and administer their invitations.

Implemented flow:

- Generate a one-use, 24-hour preview invitation and a matching QR code.
- Share the typed code, scan a QR with the camera, or read a PNG/JPEG QR image locally.
- Review the invitation and the sample recipient before accepting. Cancellation consumes nothing.
- Revoke unused invitations. Reject expired, unknown, already used, malformed or revoked codes.
- Member invitations create one sample contact with an empty local conversation. No group membership is implied.
- Group invitations require an existing approved sample member and grant membership only to the specified group. They do not add other contacts or copy history.

Codes are prefixed `DEMO-LBOX-` and QR payloads use `letters-preview://invite`. They work only against this app's in-memory sample state, which resets on restart. The screen never claims that a real account or encrypted connection was established. Codes are not passwords or encryption keys. Camera access is requested only after choosing Scan QR; QR images/frames are not uploaded. Denied/unavailable camera access leaves manual entry and image import available. Unknown QR URLs are parsed, not opened. The app does not automatically accept invitations from links.

## Server implementation

`server/letterbox_service.py` is a runnable, loopback-only admission prototype using Python standard-library SQLite. It is a separate implementation, **not connected to the iPhone preview**. It implements authenticated invitation issuance/revocation, atomic single-use redemption, persistent membership, private contact lists, direct-room identity, group creation/admin-controlled admission and owner-controlled account deactivation.

Live-service-format codes start `LBOX-` and deliberately cannot be accepted by the offline preview. Codes contain 160 bits of system-generated randomness. Only SHA-256 token digests are stored. Session tokens are random 256-bit credentials, expire after 30 days, and are returned once; deactivation removes them. The database transaction serializes concurrent redemptions. New membership never grants every member's contact list or automatic group access. Group metadata records a join boundary and returns no messages.

The opt-in development [Matrix admission bridge](MATRIX_ADMISSION.md) now connects approved identities to SDK device login using expiring one-use grants. The service still has **no message endpoints, key distribution, account recovery, device verification or push notifications**, and the native UI remains disconnected. Direct/group records are metadata, not working chats. `messaging_available` is always false. Existing chat UI messages remain local sample content. Neither passing these tests nor running this service proves E2EE.

### Run locally

Use Python 3.9 or newer. Keep the data directory outside the public source. Do not commit its contents.

```sh
python3 server/letterbox_service.py --data-dir /private/tmp/letters-private --init
python3 server/letterbox_service.py --data-dir /private/tmp/letters-private
```

Initialization writes `owner-session.json` into that private directory with restrictive permissions; it refuses to overwrite an existing file or bootstrap an existing membership database. It prints no credential. Protect this credential as account access. The HTTP adapter binds **127.0.0.1 only**, rejects browser-Origin requests, limits request bodies and suppresses request logging. It is for developer experiments, not an internet service; do not proxy it publicly.

All requests are JSON `POST`, with `Authorization: Bearer <session>` except new-member redemption. No HTTP examples embed real credentials or invite codes.

| Path | JSON fields | Behavior |
|---|---|---|
| `/v1/messaging/login-grant` | `{}` with admission session | Opt-in 60-second one-use Matrix login grant; ten/member/hour |
| `/v1/invitations` | optional `group_id`, `ttl` seconds (60–604800) | Issue member/contact invite or admin-authorized group invite; max 20 active per issuer |
| `/v1/redeem` | `code`, `name` for new membership | One-use redemption; group redemption requires an existing session |
| `/v1/revoke` | `invitation_id` | Issuer or owner can revoke |
| `/v1/contacts` | `{}` | Own contacts only |
| `/v1/direct` | `member_id` | Idempotent room metadata for two active contacts |
| `/v1/groups` | `name` | Create private group metadata; creator becomes admin |
| `/v1/group` | `group_id` | Group metadata only for admitted members |
| `/v1/deactivate` | `member_id` | Owner disables membership, sessions, group access and outstanding invitations |

An initial member invitation authorizes admission directly, as agreed; there is no extra owner-approval queue. Anyone holding it can redeem it before expiry. Share through a trusted channel. Display names are not verified identities. Adding a contact does not disclose unrelated contacts. An existing approved member can use an invitation with their session rather than create another identity. Group invitations never enroll strangers.

### Verification

```sh
python3 -m unittest discover -s server -v
```

Tests cover expiry, revocation, replay (including six concurrent attempts), hashed storage, invalid input, invalid sessions/names, scope separation, unauthorized group admission, contact privacy, direct-room deduplication, membership deactivation, per-member invitation chains, independent group administration, HTTP authentication/origin/body boundaries and persistence. Swift package tests separately cover native parser parity between QR/manual codes and local lifecycle behavior.

## Remaining integration before family use

1. Review production authentication/account recovery and secure device enrollment; store client session secrets in Keychain. No shared Letterbox Password should act as every member's account password.
2. Deploy an audited framework/service with HTTPS, rate limits, request/time/resource limits, monitoring and secure storage/backups. Review and apply the saved Oracle stack only when capacity and cost checks allow. No server is currently deployed.
3. Connect admitted identities to a reviewed Matrix deployment and SDK; enforce invitations and room access at that boundary. Local UI membership must never be authoritative. Handle retries/rollback between admission and room provisioning.
4. Disable public registration/federation as intended; apply per-group admin checks, membership/key rotation and history visibility so new members cannot decrypt old conversations. Account removal cannot erase messages already saved by a recipient.
5. Integrate authenticated HTTPS invitation APIs in the iPhone app. Add owned-domain universal links and complete cross-device camera, expiry, revocation, reconnection, accessibility and malicious-link tests.
6. Prove actual encrypted direct/group messages between independent iPhones. Keep real messaging disabled until missing trust or encryption state fails closed.

No live service, external accounts or real invitation was created by this change.
