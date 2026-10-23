# Letters — native iPhone messaging exploration

**A work-in-progress portfolio project:** original SwiftUI interface, private invitation-service foundations, and real encrypted text/media integration using the Matrix Rust SDK. Letters is not a completed or production-ready private messenger. No public service or iPhone release is provided.

<img src="Letters/Assets.xcassets/AppIcon.appiconset/LettersIcon.png" alt="Letters beige envelope with an S seal" width="96">

## Explore the project

- [Feature status and limitations](Docs/FEATURE_STATUS.md) — what is implemented, tested, preview-only or unfinished.
- [25 original native screenshots](Letters/Prototype%20Screenshots/FEATURE_GALLERY.md) — per-feature captions and provenance.
- [Build and test instructions](Docs/PORTFOLIO_SETUP.md) and [verification checkpoint](Docs/VERIFICATION_CHECKPOINT.md).
- [Annotated code-reading guide](Docs/CODE_GUIDE.md), [security architecture](Docs/SECURITY_ARCHITECTURE.md) and [archive plan](Docs/ARCHIVE_PLAN.md).

## Product and engineering work

Letters explores a space-age messenger with personal Letterbox invitations, an orbital Home screen, attributed news, Markets, and media composition. The implementation separates the local portfolio experience from a Debug-only encrypted development chat, so sample messages never masquerade as delivered messages.

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

These are native simulator captures, not design renders. Captions identify sample data and development boundaries.

| Orbital Home and news | Markets | Encrypted development screen |
| --- | --- | --- |
| <img src="Letters/Prototype%20Screenshots/04-orbital-home-news-preview.png" width="230" alt="Orbital Home news preview"> | <img src="Letters/Prototype%20Screenshots/06-market-indexes-preview.png" width="230" alt="Markets preview"> | <img src="Letters/Prototype%20Screenshots/25-encrypted-development-chat.png" width="230" alt="Disconnected encrypted development configuration"> |

The [full gallery](Letters/Prototype%20Screenshots/FEATURE_GALLERY.md) lists every capture and its provenance. A screenshot is not evidence of cross-device delivery.

## Run it

Use a compatible Mac with full Xcode; open `Letters.xcodeproj`, select the Letters scheme and an iPhone simulator, then Run. The ordinary experience contains fictional local conversations. See [exact build/test commands](Docs/PORTFOLIO_SETUP.md). The optional encrypted development path requires deliberately configured synthetic accounts and a trusted HTTPS server; [setup and limits](Docs/DEVELOPMENT_CHAT.md) explain that separate workflow.

The hosted workflow builds an unsigned simulator app, runs component/integration tests and captures native screens. Its temporary artifacts expire after seven days. The source and committed screenshots remain in this repository. An unsigned simulator app cannot be installed on an iPhone.

## Honest boundaries

Normal native invitation enrollment, contact/group chat integration, recovery and device verification remain unfinished. Timers and Self-Destruct Now affect sample conversations only. Calls and Alert All are previews; Alert All sends no emergency notification. Imported stickers are local and nonpersistent. Phone/OTP/passkey images are historical research previews; SMS is disabled, and native biometric account access is not implemented. News and Markets depend on external providers and may be unavailable or delayed.

No physical-iPhone testing was performed; the owner declined participation. Automated SDK clients and simulator smoke checks do not establish real-device security, usability or production readiness. There has been no independent security audit. See the [status table](Docs/FEATURE_STATUS.md) before making feature or security claims.

## Portfolio preservation

The owner chose to preserve this work as an explicitly unfinished portfolio project, without paid services or a public launch. Preparation for archival does not mark the app complete. **The repository remains unarchived pending explicit owner approval.** The [archive plan](Docs/ARCHIVE_PLAN.md) records the checkpoint and backup procedure.

Matrix SDK third-party licensing is retained under [Docs/ThirdParty](Docs/ThirdParty); a complete transitive dependency notice inventory remains unfinished. No Element application source is copied. This repository presents original product/UI work alongside an established encryption SDK.
