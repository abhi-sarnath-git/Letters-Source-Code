# Account access, encrypted media and message timers

## Implementation status

The app is still a portfolio prototype, not a released private messenger. The native composer remains disconnected from authenticated rooms. The development SDK boundary now includes encrypted attachment sending/reading for voice notes, images, GIFs, videos and files. Its hosted test must prove recipient decryption and server-side ciphertext independently of the UI. Synthetic envelope bytes test transport, not every codec's playback.

## Media preparation

In a sample chat, **+** opens Attachments: record a voice note (up to five minutes), stop/review/play, discard, or choose an image, GIF, video or file. Imported content is limited to 20 MB. Image dimensions/frame decoding are bounded; GIFs decode locally and respect Reduce Motion. There is no external GIF search or third-party disclosure of chat terms. Videos use native playback; files display metadata without executing documents. Recording cancels on background/interruption, permissions denial is explained, and recording never sends automatically. At the time limit, review remains explicit.

Local sample attachments stay in memory. Recordings and video playback use temporary protected private folders, removed after use. These are device-local protections, not end-to-end transmission. Local playback/file lifecycle, microphone denial, interruptions and large-text/VoiceOver require physical-device QA. Photos/videos may contain identifying metadata; metadata stripping and user controls remain unfinished.

The real transport calls the pinned Matrix SDK's encrypted-room timeline attachment API, not the generic plaintext media upload API. Room encryption and audience guards run before upload. The SDK encrypts bytes and encrypts the room event containing the attachment key. Reads reject plain MediaSource URLs, check metadata/size, download/decrypt through the SDK without a persistent plaintext cache, and verify room/audience again before returning. Cancellation requests cancel the SDK send; a raced send cannot be recalled by cancellation alone. Completion is not a delivery/read receipt. Server contact authorization and key-verification/recovery remain separate release gates.

The receiver checks actual downloaded size before reading bytes into memory. The SDK's download itself still needs server media-size quotas, disk budgets and crash/locked-device cleanup review before production. A malicious sender's declared size is not an enforced streaming download limit.

## Invitation + phone + passkey

The intended account sequence is: personal Letterbox invitation → country calling code and national phone number → short-lived SMS OTP → native passkey ceremony → server verification → atomic account creation and inviter contact edge. OTP alone creates no account. Existing members' group invitations do not create new accounts. Phone is private account data, not a broadcast contact-directory identifier.

**SMS is disabled by owner choice.** AccountAccessView is a labelled design preview with disabled SMS/passkey account buttons. Numbers typed there are neither submitted nor stored. The server AccountRegistration development library has no runtime SMS provider by default and is not exposed through the legacy loopback HTTP demo. Test SMS captures synthetic codes only inside tests. There is no fixed OTP, password fallback or auto-approved passkey.

AccountRegistration checks active/revoked/expired invitations, uses a private server HMAC key for phone and OTP hashes, bounds OTP attempts and phone/invitation/global sends, invalidates resend proofs and consumes the invitation atomically with account/passkey/contact creation. Phone format uses explicit international prefix with no national trunk zero; actual routability requires the future SMS provider. No real numbers or OTPs belong in logs, screenshots, source or CI artifacts.

WebAuthn verification uses pinned py_webauthn, validates server challenges, RP ID, HTTPS origin, credential identity, signatures/counters and required user verification. Challenge replay, revoked members and expiry are denied. The native AuthenticationServices adapter creates/asserts passkeys, returning a credential for server verification; a native callback alone never issues an account session. A trusted domain, apple-app-site-association, associated-domain entitlement, signed app and HTTPS account endpoints remain required and unconfigured. Dependency installation is for synthetic CI tests, not a running account service.

Face ID/Touch ID approve passkey use locally; iOS may permit a device passcode. Letters does not receive biometric templates and cannot honestly promise a passkey enforces biometrics exclusively. The optional local biometric capability demonstration is not server login or protection of message keys. Passkeys authenticate accounts; message keys, verified devices and recovery remain separate. SMS alone must not recover account passkeys or encrypted history. Lost-device, changed-number, SIM-swap, revocation, multi-device and recovery UX remain release gates.

The legacy admission demo remains a separate developer-only path with its existing token/bootstrap flows. It is NOT a production bypass-compatible phone registration service. Production must remove or firewall legacy new-account redemption/bootstrap routes and enforce the new account policy across every entry point before exposure.

## Self-destruct controls

A cyan orbital clock at the top right of a sample chat opens **Set timer** and **Self-Destruct Now**. Choices are exactly: **1 hour, 12 hours, 1 day, 7 days, a month, six months, one year, never**. Timers apply only to future sample messages/stickers/attachments; expiry starts when added, not when read. Month/year units use the Gregorian calendar in UTC. Earlier messages retain their original expiry.

Foreground sweeps remove expired payloads from active and saved local sample profiles. On returning to the foreground the app sweeps again. Self-Destruct Now requires confirmation and clears only the current local sample chat and its active-profile snapshot; contacts and timer remain. It does not claim to erase other members' data. Copies in device memory, backups, recipient screenshots or exports cannot be guaranteed erased.

**Remote disappearing messages are not implemented.** Before connecting these controls to real chats, add encrypted expiry metadata, recipient-side expiry, permission-aware server event redaction, encrypted-blob retention/cleanup, offline-device policy and honest failure/retry states. A Matrix event redaction alone does not guarantee media deletion or secure erasure. Clock manipulation and persistent-store recovery must be covered in production tests.

## References

- [Apple: supporting passkeys](https://developer.apple.com/documentation/authenticationservices/supporting-passkeys)
- [Duo: registration verification](https://duo-labs.github.io/py_webauthn/registration.html)
- [Pinned Matrix Swift SDK](https://github.com/matrix-org/matrix-rust-components-swift/tree/26.10.02)
- [Matrix encrypted attachment specification](https://spec.matrix.org/latest/client-server-api/#extensions-to-mroommessage-msgtypes)

No SMS account, paid service, deployment, new entitlement enrollment or real account was created in this milestone.

## Hosted verification evidence

Source `86fa1244f3a55bfc99cc91f755fd52eb018f2830`, [workflow 39729529591](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39729529591): account/passkey tests, timer/core tests, native iPhone compilation and SDK media integration steps passed. All five media kinds reached a separate SDK recipient, decrypted to the original synthetic bytes, and had ciphertext at the server media endpoint. Outsider attachment access failed. The send boundary waits for a matching server event acknowledgement and maps queue errors without logging raw details. File metadata parsing explicitly rejects plaintext media sources.

The WebAuthn test uses a synthetic P-256 authenticator and validates actual signatures, origin, required user verification, counters, replay/expiry and removed-member denial. No real SMS, biometric enrollment, Apple passkey account or physical iPhone is involved. Snapshot capture and interactive device QA are separate from these checks.

Final native GIF layout source `50984f8210d640091425d09553987205c9856163`, [run 39730967900](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39730967900), passed all checks again. All 18 new feature captures were inspected before portfolio publication. Live release still needs persisted authorization for pending SDK send-queue items across restarts/audience changes; timeout or cancellation alone cannot guarantee a queued send is recalled.
