# Prototype Screenshots

Original screenshots of Letters running in an iPhone 16 Pro simulator, captured on 21 October 2026 with Xcode 16.4 / iOS 18.5. These are actual native SwiftUI screens, not design mockups. All conversations and profiles are fictional.

**Current stage: offline portfolio prototype.** These screenshots demonstrate completed local interfaces and behavior, not working encrypted communication. E2EE, live messages, voice calls, emergency notifications and cross-device invitation redemption remain unimplemented.

## Chats — local interface

Letters branding, beige envelope with S seal, space-age theme, fictional conversations, search and conversation filters. Message composition and sticker use stay in memory on this device.

<img src="01-chats-preview.png" alt="Letters chat list with fictional family and friend conversations" width="320">

## Alert All — local rehearsal

Emergency-alert preparation for all approved Letters members, optional note, explicit confirmation, duplicate-active protection and ending a rehearsal. It does not notify anyone, contact emergency services or fabricate acknowledgements.

<img src="02-alert-all-rehearsal.png" alt="Alert All screen clearly labelled local rehearsal only" width="320">

## Letterbox QR — local invitation preview

A member's one-use invitation QR and matching manual code. Every sample member can generate their own invitations and have a different contact list. Groups require separate admission. Preview codes are session-local and grant no online access; the QR shown here is harmless fictional test data.

<img src="03-letterbox-qr-preview.png" alt="Letterbox QR preview with matching demo invitation code and explicit local-only notice" width="320">

## Verification and provenance

- Source: [`fe2ee0c5b552b0d2f1b3bf4a83f0f45d38b467e9`](https://github.com/abhi-sarnath-git/Letters-Source-Code/commit/fe2ee0c5b552b0d2f1b3bf4a83f0f45d38b467e9).
- [Successful capture run](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39549406715): 10 Swift tests, 10 server admission tests, native compilation and simulator launches passed. The Letterbox QR was decoded directly from the screenshot by Apple's Vision framework.
- Original artifact SHA-256: `60d5ab815d7e42fc835507b8c12bd31e936a57ecff960aa709d393e4dd80f81e`.
- Images are the original PNG captures, without retouching or compositing. Physical-device camera scanning, VoiceOver, large-text and interactive end-to-end UI QA are not certified by these captures.

## Portfolio updates

For each completed feature, capture its actual native screen after relevant build/tests pass, inspect the image, then add it here with a concise caption, source commit and verification evidence. Label local previews and live functionality separately. Use fictional accounts and data only; never publish real invitation/session tokens, keys, private chats or infrastructure/account screenshots.

The full completion checklist remains in [Docs/CHECKLIST.md](../../Docs/CHECKLIST.md). Deployment and app-distribution work is deferred at the owner's request while app development continues.
