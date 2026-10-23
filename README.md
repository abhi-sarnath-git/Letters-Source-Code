# Letters — Native iOS Messaging: Design & Engineering Case Study

**A space-age interface. Personal invitations. Encryption tested beyond the UI.**

Letters brings original SwiftUI product design together with encrypted text and media integration, invitation-based access control, and automated validation against a real test homeserver. This repository documents the engineering behind a private messaging concept—from its orbital Home screen and Letterbox QR invitations to the security boundaries governing who can join a conversation.

**SwiftUI · Swift Concurrency · Matrix Rust SDK · Python · SQLite · GitHub Actions**

This is a portfolio case study with working development components and documented integration gaps. It is not a production release. [Implementation status and remaining work →](Docs/FEATURE_STATUS.md)

<img src="Letters/Assets.xcassets/AppIcon.appiconset/LettersIcon.png" alt="Letters beige envelope with an S seal" width="96">

## Engineering highlights

- **Encrypted messaging with observable evidence.** Independent synthetic SDK accounts exchange text and five media types; integration checks inspect server ciphertext and reject plaintext or unexpected room audiences.
- **Private access modeled on the server.** Persistent, expiring, one-use Letterbox invitations, isolated contact lists, group authorization and a Synapse room-policy module make access control an explicit backend responsibility.
- **Native product design with a distinct identity.** A beige envelope and S seal, orbital Earth animation, media composition, attributed news and Markets form a consistent SwiftUI interface. The gallery labels local previews and development screens individually.
- **Reproducible validation.** The latest hosted run passed native simulator compilation, eight messaging tests, server permission checks, capture/QR checks and packaging. [Read the exact evidence and test limits →](Docs/VERIFICATION_CHECKPOINT.md)

## Review the project

- [Feature status and limitations](Docs/FEATURE_STATUS.md) — what is implemented, tested, preview-only or unfinished.
- [25 original native screenshots](Letters/Prototype%20Screenshots/FEATURE_GALLERY.md) — per-feature captions and provenance.
- [Build and test instructions](Docs/PORTFOLIO_SETUP.md) and [verification checkpoint](Docs/VERIFICATION_CHECKPOINT.md).
- [Annotated code-reading guide](Docs/CODE_GUIDE.md), [security architecture](Docs/SECURITY_ARCHITECTURE.md) and [archive plan](Docs/ARCHIVE_PLAN.md).

## Architecture and design decisions

The application separates local product previews from a Debug-only encrypted development chat. This makes the boundary between interface design and live transport visible during review. Local sample messages remain on the device; the development screen exercises the real SDK integration.

The Python admission service persists expiring, one-use invitations and private contact/group permissions. Its Matrix bridge exchanges short-lived grants for SDK sessions. A separate Synapse room-policy module restricts synthetic development rooms. The Swift messaging package uses the established Matrix SDK for encryption, Keychain session credentials and a keyed SDK store; it checks room encryption, audience and message trust before displaying supported content. These components have automated tests, but they are not yet a seamless native enrollment-to-chat application or an audited security product.

```text
SwiftUI local portfolio screens       Debug encrypted chat
       │                                  │
       │ separate sample state            ▼
       │                           LettersMessaging / Matrix SDK
       │                                  │
       └── no sample delivery             ▼
                                  Temporary test Synapse
                                          │
                                  Letterbox admission + room policy
```

Start reading at `Letters/Features/DevelopmentChatView.swift`, then `LettersMessaging/Sources/LettersMessaging/LettersMessagingClient.swift`, `server/letterbox_service.py` and `server/letters_room_enforcement.py`. Comments explain responsibilities, security guards and important state transitions; the [code guide](Docs/CODE_GUIDE.md) covers the wider source map.

## Native interface gallery

Explore 25 original native simulator captures spanning messaging, invitations, news, Markets and media composition. Captions identify sample data and development boundaries.

| Orbital Home and news | Markets | Encrypted development screen |
| --- | --- | --- |
| <img src="Letters/Prototype%20Screenshots/04-orbital-home-news-preview.png" width="230" alt="Orbital Home news preview"> | <img src="Letters/Prototype%20Screenshots/06-market-indexes-preview.png" width="230" alt="Markets preview"> | <img src="Letters/Prototype%20Screenshots/25-encrypted-development-chat.png" width="230" alt="Disconnected encrypted development configuration"> |

The [full gallery](Letters/Prototype%20Screenshots/FEATURE_GALLERY.md) lists every capture and its provenance. A screenshot is not evidence of cross-device delivery.

## Run it

Use a compatible Mac with full Xcode; open `Letters.xcodeproj`, select the Letters scheme and an iPhone simulator, then Run. The ordinary experience contains fictional local conversations. See [exact build/test commands](Docs/PORTFOLIO_SETUP.md). The optional encrypted development path requires deliberately configured synthetic accounts and a trusted HTTPS server; [setup and limits](Docs/DEVELOPMENT_CHAT.md) explain that separate workflow.

The hosted workflow builds an unsigned simulator app, runs component/integration tests and captures native screens. Its temporary artifacts expire after seven days. The source and committed screenshots remain in this repository. An unsigned simulator app cannot be installed on an iPhone.

## Implementation scope and next steps

Normal native invitation enrollment, contact/group chat integration, recovery and device verification remain unfinished. Timers and Self-Destruct Now affect sample conversations only. Calls and Alert All are previews; Alert All sends no emergency notification. Imported stickers are local and nonpersistent. Phone/OTP/passkey images are historical research previews; SMS is disabled, and native biometric account access is not implemented. News and Markets depend on external providers and may be unavailable or delayed.

Validation covers automated component/integration checks and simulator smoke tests. Physical-iPhone testing was not performed. Automated SDK clients and simulator smoke checks do not establish real-device security, usability or production readiness. There has been no independent security audit. See the [status table](Docs/FEATURE_STATUS.md) before making feature or security claims.

## Case study preservation

This repository preserves the source, design work, test evidence and engineering roadmap as a reviewable portfolio case study. It includes a reproducible development setup and records the remaining integrations explicitly. No paid services or public launch are part of this checkpoint. **Archival is pending owner review and approval.** The [preservation plan](Docs/ARCHIVE_PLAN.md) describes the verified source backup and archive procedure.

Matrix SDK third-party licensing is retained under [Docs/ThirdParty](Docs/ThirdParty); a complete transitive dependency notice inventory remains unfinished. No Element application source is copied. This repository presents original product/UI work alongside an established encryption SDK.
