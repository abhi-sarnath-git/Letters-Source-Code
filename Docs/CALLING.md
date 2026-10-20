# Voice and video calls for Letters

## Confirmed requirement

One-to-one in-app voice and video calls between private, invited contacts, with end-to-end encryption mandatory. Group calls remain in the wider WhatsApp-parity target. The owner requested free options and has no server/cloud account yet.

## Current implementation

The Calls tab lists fictional direct contacts with voice/video entry points and search. The same actions are available in direct sample chats. They open an accessible full-screen preparation interface, allow selection between voice and video, and explain the outstanding setup. Group chat buttons are not presented as one-to-one calling. No fake call history, ringing, connection timer, delivery, media capture or encryption success is generated.

The [calling revision cloud build](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39513047308) passed on 21 October 2026: unsigned iPhone simulator compilation and the existing bookkeeping tests succeeded. This is not an interactive call test.

These are offline UI flows, not functional calls. They deliberately request no microphone/camera permissions and do not open a public calling website as a shortcut. Account membership and cryptographic trust cannot be inferred from the sample conversation list.

## Live implementation path

1. Connect authenticated private accounts to a controlled Matrix homeserver; validate invited/active/unblocked membership on the server. Disable unauthorized external membership for this deployment.
2. Integrate a compatible MatrixRTC client using the selected stable Matrix SDK and a supported native or embedded calling implementation. Review release maturity, minimum iOS/Xcode requirements and licensing before selecting the actual dependency. No calling dependency has been added yet.
3. Deploy the compatible MatrixRTC authorization service and LiveKit SFU/relay with trusted HTTPS, WSS and the required media ports. Apply the current upstream transport discovery and homeserver prerequisites for the pinned versions. An SFU's transport encryption alone is not proof of end-to-end media encryption.
4. Verify authorization for each participant/room at the service boundary. Public or guessable room links and a generic public JWT endpoint are not private contact controls. Do not ship long-lived LiveKit secrets in an app or public repository.
5. Bind actual call state and device key state to the native UI. Fail on missing encryption, authentication or authorization. Add an encryption indicator only after verified SDK state. Do not downgrade to unencrypted media.
6. Request microphone permission only on a real voice/video action; request camera permission only for video. Handle denied/restricted access, audio routes, camera selection, CallKit, interruptions, app background behavior and VoIP pushes using supported Apple APIs.
7. Record actual call results and implement no-answer, busy, decline, reconnect, end and missed-call behavior. Do not fabricate results for setup errors.

## Free-first infrastructure

Oracle Always Free is a candidate for a small experimental deployment, subject to regional capacity, eligible resource limits, network requirements and idle reclamation. A free account must be opened by the owner, including Oracle's verification and terms. Nothing is provisioned yet. Keep the account within Always Free allowances; do not silently upgrade to paid usage.

GitHub's hosted Mac builds are only for building/testing the source, not for hosting a continuously running calling server. A server's free allowance does not remove Apple's distribution fees, guarantee always-on service, or guarantee free video relay bandwidth indefinitely.

## Acceptance evidence for real calls

- Two independently authenticated iPhones place and receive both voice and video calls over different networks.
- Uninvited, removed, blocked and expired-session users cannot obtain call access, including through direct API requests or replayed links/tokens.
- The relay cannot decode audio/video; media encryption survives reconnects and participant/device changes, or the call fails closed.
- Audio-only calls do not request camera permission. Permission denials lead to recovery instructions without repeated prompts or capture.
- Decline, no-answer, busy, interruptions, headset/audio route changes, background calls and hang-up release resources and show accurate history.
- No plaintext media keys, private room tokens or long-lived service credentials appear in logs, analytics, public URLs or source.

## Primary references

- MatrixRTC self-hosting prerequisites: https://github.com/element-hq/element-call/blob/main/docs/self_hosting.md
- Embedded messenger integration: https://github.com/element-hq/element-call/blob/main/docs/embedded_standalone.md
- Native iOS implementation under evaluation: https://github.com/element-hq/element-call-ios
- Oracle Free Tier FAQ: https://www.oracle.com/cloud/free/faq/

These references change; pin and test a compatible set of releases before deployment. No third-party calling code has been copied into Letters.
