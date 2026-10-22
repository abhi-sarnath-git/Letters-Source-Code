# Letters' Source Code

An original, invite-only iPhone messenger targeting the agreed WhatsApp-style feature set, with a futuristic interface and end-to-end encryption as a release requirement.

<img src="Letters/Assets.xcassets/AppIcon.appiconset/LettersIcon.png" alt="Letters: beige envelope with an S seal" width="128">

Letters is the app name. **Letters' Source Code** is this public portfolio project's title; the public GitHub repository is [Letters-Source-Code](https://github.com/abhi-sarnath-git/Letters-Source-Code).

## Reading and debugging the code

Source files now include comments explaining responsibilities, security guards and important blocks: `//` / `///` in Swift and `#` in Python, shell and workflow YAML. Start with the [code and debugging guide](Docs/CODE_GUIDE.md). Keep these explanations current when extending Letters; do not put secrets or private messages in debugging output.

## Portfolio screenshots

[View Prototype Screenshots](Letters/Prototype%20Screenshots/README.md) for verified native captures of Chats, Alert All and Letterbox QR, including implementation status and build evidence. Screenshots will accompany completed feature milestones; previews are labelled accurately.

## What this build actually does

This is a native SwiftUI portfolio foundation, not a working private messaging service. It has Letters branding, a custom icon, chat navigation, sample conversations, search, unread/favorites/group filters, a local sample-message composer, settings, and honest roadmap screens for voice calls and updates. Sample conversations are fictional and held in memory. No public messaging server, push service or real calls are supplied. A separate Debug-only native development chat now connects to the pinned Matrix encryption SDK using operator-provided synthetic Letterbox accounts, with text/media sends and manual encrypted history refresh. It is separate from the sample composer and local invitation screens. See [development setup and limits](Docs/DEVELOPMENT_CHAT.md). Home separately fetches public news headlines; conversation data is not sent to that service. No sample messages leave the app. Restarting resets the samples.

The space-age revision adds a beige-envelope/S-seal icon, static starfield, cyan accents, six symbol-based Orbit stickers, and local PNG/JPEG sticker imports. Native sticker code has passed a hosted Xcode build; interactive sticker QA remains outstanding. Imports disappear when the app restarts. Whole sticker packs, animation, persistence and real encrypted sticker delivery are still outstanding. See `Docs/DESIGN_DIRECTION.md` and `Docs/FREE_OPTIONS.md`.

The standalone LettersCore package tests a release-readiness checklist. It is not wired into the demo app and is not a security enforcement layer. Passing these checklist tests does not establish that E2EE exists or is secure.

The calling revision adds searchable sample contacts, voice buttons in direct chats, and an offline call-preparation screen. It does not dial, ring, capture media, or show a fake connection. A server account and a verified MatrixRTC integration are still required for live encrypted calls. See [Calling setup and acceptance criteria](Docs/CALLING.md).

## Alert All — replacing video calls

At the owner's request, video calling is replaced by **Alert All**, intended to notify **all approved Letters members** during an emergency. Voice calling stays in scope. The new tab offers an optional note, confirmation, a local rehearsal record and an end-rehearsal action. It sends nothing and cannot be used for real emergencies. Encrypted alert delivery, notifications and member acknowledgements remain unimplemented. See [Alert All requirements and acceptance criteria](Docs/ALERT_ALL.md).

## Letterbox invitations

The envelope button on Chats now opens Letterbox. Every member can create their own Letterbox QR; accepting links only the inviter and recipient as contacts. The local profile selector demonstrates separate contact lists and personal group administration. Generate a one-use, expiring QR/code, scan or enter it, review it, and accept as a sample member. Member invitations add one sample contact and an empty local conversation. Group invitations are separate and require an existing approved member. Revocation, expiry and replay checks are implemented locally. **Preview codes work only in this session, not across devices.**

A separate loopback-only Python admission service implements persistent, server-enforced invitation and membership rules, with tests for concurrent redemption, revocation and private contact/group access. It is not deployed or connected to the native preview and has no encrypted message transport. See [Letterbox implementation and integration limits](Docs/LETTERBOX.md). Real accounts, private cross-device chats and E2EE remain outstanding.

## Home news and orbital Earth

Home now replaces the Letters word heading with an animated Earth/atom, alongside “Live Around The World.” Its menu selects World News, Global Stocks, Oil or Crypto headlines from The Guardian. Normal mode refreshes while Home is visible; screenshot mode uses a labelled sample. Source timestamps, unavailable/cached states, a pause control and Reduce Motion handling are included. This is news, not market quotes. See [implementation and verification limits](Docs/WORLD_PULSE.md).

## Approved account connection

A development Synapse authentication module now exchanges an approved Letterbox member's short-lived, one-use grant for a real SDK device session. Grant hashing, expiry, account binding, replay protection and current-membership checks are implemented. See [the admission bridge and remaining limits](Docs/MATRIX_ADMISSION.md). The native invitation and chat screens are still sample-only; server-enforced contact/group room policy and secure enrollment UX remain outstanding.

## Encrypted messaging development

`LettersMessaging` now pins Matrix Rust SDK Swift **26.10.02**, with Keychain session storage, a keyed persistent SDK store, private encrypted rooms, guarded text sending, session restore and logout. The hosted workflow tests this against ephemeral loopback Synapse **1.163.0**, including recipient decryption and raw server ciphertext checks. See [implementation, test evidence and limits](Docs/ENCRYPTED_MESSAGING.md). The You tab includes an honest development status screen. **This is not yet a usable private messenger:** production Letterbox/account integration, finished native chat UX, device verification, recovery and notifications remain outstanding. The Debug development screen connects real text/media operations; it requires an explicitly configured test server and is not a public download service.

## Markets from the Home menu

Open **Home menu → Markets** for Stocks, Indexes, Oil and Bitcoin, with a native Back button. Bottom navigation is unchanged. A fixed starting global-stock selection, WTI/Brent indicative CFDs and Coinbase BTC/USD use attributed TradingView widgets; data can be delayed, end-of-day or unavailable. No quote API key is embedded in this public repository. News topics remain separate. See [Markets implementation and limits](Docs/MARKETS.md) and the labelled portfolio capture in [Prototype Screenshots](Letters/Prototype%20Screenshots/README.md).

## Download Letters

**No iPhone download or TestFlight invitation is available yet.** [Download/install guide](Docs/DOWNLOADS.md) explains the free source/simulator route, personal iPhone testing with Xcode, and future family/friend installation through TestFlight.

The workflow now packages an unsigned **Simulator-only** app as the `letters-simulator-download` artifact, retained seven days. Use a successful run containing the packaging step. It needs a compatible Mac with full Xcode/Simulator and cannot install on an iPhone. The package includes build information and a checksum. It contains the same offline portfolio preview, not an encrypted messenger.

## Open and build

Open `Letters.xcodeproj` in Xcode. Select the shared Letters scheme and an iPhone simulator, then Run. The preview targets iOS 16+. Physical-device installation needs an Apple account and a unique bundle identifier; this project deliberately has no signing team or credentials. Camera permission is requested only when you choose the Letterbox QR scanner. QR image import uses a file picker; no microphone, contacts or full photo-library permission is requested.

This Mac was inspected on 21 October 2026: macOS 13.7.8, Swift 5.8.1 command-line tools, no full Xcode or iOS SDK. Native compilation cannot run locally here. The first GitHub-hosted unsigned iPhone simulator build and standalone checklist tests passed on 21 October 2026 using Xcode 16.4. The subsequent hosted iPhone simulator launch and screenshot capture also passed (run 39517134620). Interactive UI QA and device testing remain outstanding. Swift syntax parsing succeeds. The local checklist test attempt was blocked by the command-line-tools installation lacking the SDK PlatformPath; those tests subsequently passed on the hosted Mac.

## Older Mac / remote builds

### GitHub Actions — recommended for this public project

The included `.github/workflows/ios-preview.yml` runs standalone checklist tests and builds the unsigned iPhone simulator app on a standard hosted Mac. It runs on pushes to `main`, pull requests, or manual dispatch. Standard GitHub-hosted runners are free for public repositories, subject to GitHub's usage policies. The workflow has a 30-minute timeout, cancels superseded runs, requests read-only repository access, and saves preview screenshots for seven days. No Apple signing account or cloud secrets are needed. The workflow also boots an available iPhone simulator, launches the offline preview and captures its home, Alert All and Letterbox screens. The [Alert All revision](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39547086390) passed: package tests, native compilation, both simulator launches and both screenshot captures. Both screenshots were visually inspected; interactive UI and accessibility testing remain outstanding. The [first cloud run](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39512206616) passed: checklist tests and native simulator compilation succeeded. This is compilation evidence, not an interactive UI test or proof of E2EE.

An unsigned simulator build is not an installable iPhone release. This workflow does not publish an app, provide an interactive simulator, provision a deployed messaging service, or establish production security. The new isolated encryption test has its own limited evidence and outstanding gates, described above.

### Local Xcode and alternative builds

Apple lists Xcode 15.2 as compatible with macOS Ventura 13.5+, so an older Xcode downloaded from Apple's Developer Downloads may support local UI development on this machine. That does not make it suitable for current App Store uploads or guarantee compatibility with the eventual current Matrix SDK and your iPhone's iOS version.

For current builds, `codemagic.yaml` provides an unsigned simulator-build workflow for a hosted Mac. It has not been run against a cloud account. Put this folder at the root of a repository, connect that repository to your own Codemagic account, and choose the workflow. No paid signing membership is required for this unsigned simulator build; the produced app cannot be installed on a physical iPhone. Codemagic is build automation, not a full interactive remote Xcode desktop. Simulator screenshots and automated UI tests should be added to that workflow once the first build passes. Interactive testing can use a compatible local simulator or an interactive rented Mac.

Physical distribution through TestFlight requires Apple Developer Program membership, signing configuration, a device build, and Apple's applicable review. The included workflow does not do this. The source is published on GitHub. No iPhone app has been distributed, hosting provisioned, or paid service purchased.

The [per-member Letterbox build](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39549406715) passed 10 Swift tests, 10 server tests, native compilation, simulator launches and decoding the Letterbox QR from its screenshot. Physical-camera, interactive flow and accessibility QA remain outstanding.

## Next engineering milestone

Connect the pinned Matrix client boundary to server-enforced Letterbox admission and native accounts/chats; complete review and private test infrastructure. Require encrypted rooms and encrypted media without plaintext fallback. Implement secure session storage, device verification, recovery, account lifecycle, and revoke/ban behavior. Prove messaging between two independent devices before describing Letters as an encrypted messenger. Calls require a separate encrypted calling integration and verification.

Track progress in [the project checklist](Docs/CHECKLIST.md). See `Docs/FEATURE_PARITY.md` and `Docs/SECURITY_ARCHITECTURE.md` for the full target and outstanding work. These requirements remain outstanding, not silently removed to fit a portfolio demo.

## Sources

- Apple Xcode compatibility: https://developer.apple.com/xcode/system-requirements
- Apple Developer downloads: https://developer.apple.com/download/all/
- Codemagic pricing: https://docs.codemagic.io/billing/pricing/
- GitHub Actions public-repository usage: https://docs.github.com/en/actions/concepts/billing-and-usage
- Matrix Rust SDK: https://github.com/matrix-org/matrix-rust-sdk
- Swift bindings: https://github.com/matrix-org/matrix-rust-components-swift

No Element application source has been copied. The pinned SDK's Apache license is retained in Docs/ThirdParty; a full transitive dependency notice inventory remains a release gate. Present Letters in a portfolio as original product/UI work using an established messaging SDK, with the actual implementation status clearly stated.

## Media and account-access development

Sample chats now prepare voice notes, GIFs, photos, videos and files, and expose a futuristic clock menu for local timer settings and confirmed Self-Destruct Now. A separate SDK boundary implements encrypted attachment operations. Invitation+phone OTP+passkey registration is a development boundary with SMS disabled; native account actions are labelled unavailable. Read [implementation and security limits](Docs/ACCOUNT_AND_MEDIA.md) before interpreting portfolio screens as live messaging or account support.

[Browse Letters’ per-feature portfolio screenshots](Letters/Prototype%20Screenshots/FEATURE_GALLERY.md), including news and all Markets categories. Captions distinguish local previews from separately tested service foundations.
