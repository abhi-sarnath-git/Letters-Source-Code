# Native encrypted development chat

This is the first native connection to the real messaging client. The normal portfolio conversations stay local. In a Debug build, open **You → Messaging development → Encrypted development chat**. Release builds have no navigation entry. It is not a family pilot or a completed registration flow.

## Development procedure

1. An operator must configure a trusted HTTPS Synapse with the Letters admission module and provision two approved synthetic members. No public server is supplied by this change. The existing CI harness runs a temporary loopback server for SDK tests only; iPhone simulator localhost and the Mac's localhost are not interchangeable configurations here.
2. Enter that trusted server URL. Obtain a short-lived, one-use login-grant JSON from the authenticated admission development service for each account. Paste only into the secure grant field. Grants are cleared on submission, backgrounding and navigation away, and never written to preferences or logs.
3. Connect each account on a separate simulator/device. Enter the other's exact Matrix ID. One creates an encrypted invitation and shares the room ID through the operator. The other enters that ID and accepts. Refresh after both have joined.
4. Send synthetic text. Refresh manually on the recipient. The SDK handles encryption; server acceptance is not a delivery/read receipt. Failed responses may leave an uncertain outcome: refresh before retrying. No automatic resend is added.
5. Reopen the screen, enter the same server URL and restore the saved device session. Enter the same contact/room IDs and refresh to recover SDK history. Session credentials and store keys use Keychain, while SDK history uses its keyed store. Room/contact fields and plaintext UI messages are not saved in preferences.
6. Revoke the development device session when finished. Revocation must reach the server; failures keep the session available for a retry.

The history adapter retains SDK timeline ordering and updates, filters remote message events, and fetches contents through the existing SDK trust policy. It checks encryption and the exact active audience before and after the history read. Sender IDs must also match the current selected account/contact pair. Event-ID text and attachment read APIs use the same timeline trust gate. SDK trust shields block plaintext, unknown/unsigned devices, changed identities and mismatched senders. Unverified human identity is the one explicitly disclosed development exception; it is not contact verification. The current window is at most 200 timeline rows; initial backward pagination requests 50 events. It is not complete historical export, continuous/background synchronization or an offline outbox. Encrypted attachment rows offer an explicit download action. The native composer supports voice notes, GIFs, photos, videos and files: prepare/review first, then explicitly send from the chat. Recipient bytes pass the SDK encryption/hash checks and the local MIME/size/image limits before preview; documents show metadata only. Voice duration is derived from decoded audio. There is no automatic media download or file export. Protected temporary playback files are removed on closing the preview.

## Remaining release boundaries

Client audience checks are not server-enforced Letterbox contact/group permissions. An operator can currently specify account/room IDs manually. Human contact verification, recovery, multi-device policy, production authorization, push, background behavior and physical-device security testing remain required. Existing sample-chat timers and Self-Destruct Now do not affect real development messages. SMS is still disabled, and this screen does not bypass the SMS decision by claiming production registration.

The SDK media queue can persist pending operations; production reauthorization on restart/audience changes remains a release gate. Development testing uses synthetic attachments only. A timeout is not a promise of recall or a safe reason to resend.

The app obscures its development screen outside the active scene and clears visible plaintext on leaving/backgrounding. This is not screenshot prevention or proof against a compromised device. Real iPhone Keychain/lock/reboot testing remains outstanding.

## Validation

Local syntax and project-format checks passed. The expanded hosted integration must prove bidirectional text discovery after session restoration, unique event IDs, refusal of an unexpected audience, and rejection of plaintext events maliciously injected into an encrypted room, alongside the existing encrypted text/media, raw-server ciphertext, outsiders and session tests. Do not infer a passed hosted result from source publication; the final CI result is recorded in the progress checkpoint.
