# Letters' Source Code

An original, invite-only iPhone messenger targeting the agreed WhatsApp-style feature set, with a futuristic interface and end-to-end encryption as a release requirement.

<img src="Letters/Assets.xcassets/AppIcon.appiconset/LettersIcon.png" alt="Letters: beige envelope with an S seal" width="128">

Letters is the app name. **Letters' Source Code** is this public portfolio project's title; the public GitHub repository is [Letters-Source-Code](https://github.com/abhi-sarnath-git/Letters-Source-Code).

## What this build actually does

This is a native SwiftUI portfolio foundation, not a working private messaging service. It has Letters branding, a custom icon, chat navigation, sample conversations, search, unread/favorites/group filters, a local sample-message composer, settings, and honest roadmap screens for voice calls and updates. All data is fictional and held in memory. There is no account, network transport, encryption engine, server, push service, or real call functionality yet. No sample messages leave the app. Restarting resets the samples.

The space-age revision adds a beige-envelope/S-seal icon, static starfield, cyan accents, six symbol-based Orbit stickers, and local PNG/JPEG sticker imports. Native sticker code has passed a hosted Xcode build; interactive sticker QA remains outstanding. Imports disappear when the app restarts. Whole sticker packs, animation, persistence and real encrypted sticker delivery are still outstanding. See `Docs/DESIGN_DIRECTION.md` and `Docs/FREE_OPTIONS.md`.

The standalone LettersCore package tests a release-readiness checklist. It is not wired into the demo app and is not a security enforcement layer. Passing these checklist tests does not establish that E2EE exists or is secure.

The calling revision adds searchable sample contacts, voice buttons in direct chats, and an offline call-preparation screen. It does not dial, ring, capture media, or show a fake connection. A server account and a verified MatrixRTC integration are still required for live encrypted calls. See [Calling setup and acceptance criteria](Docs/CALLING.md).

## Alert All — replacing video calls

At the owner's request, video calling is replaced by **Alert All**, intended to notify **all approved Letters members** during an emergency. Voice calling stays in scope. The new tab offers an optional note, confirmation, a local rehearsal record and an end-rehearsal action. It sends nothing and cannot be used for real emergencies. Encrypted alert delivery, notifications and member acknowledgements remain unimplemented. See [Alert All requirements and acceptance criteria](Docs/ALERT_ALL.md).

## Open and build

Open `Letters.xcodeproj` in Xcode. Select the shared Letters scheme and an iPhone simulator, then Run. The preview targets iOS 16+. Physical-device installation needs an Apple account and a unique bundle identifier; this project deliberately has no signing team or credentials. No camera, microphone, contacts, or photo permissions are requested by the demo.

This Mac was inspected on 21 October 2026: macOS 13.7.8, Swift 5.8.1 command-line tools, no full Xcode or iOS SDK. Native compilation cannot run locally here. The first GitHub-hosted unsigned iPhone simulator build and standalone checklist tests passed on 21 October 2026 using Xcode 16.4. The subsequent hosted iPhone simulator launch and screenshot capture also passed (run 39517134620). Interactive UI QA and device testing remain outstanding. Swift syntax parsing succeeds. The local checklist test attempt was blocked by the command-line-tools installation lacking the SDK PlatformPath; those tests subsequently passed on the hosted Mac.

## Older Mac / remote builds

### GitHub Actions — recommended for this public project

The included `.github/workflows/ios-preview.yml` runs standalone checklist tests and builds the unsigned iPhone simulator app on a standard hosted Mac. It runs on pushes to `main`, pull requests, or manual dispatch. Standard GitHub-hosted runners are free for public repositories, subject to GitHub's usage policies. The workflow has a 20-minute timeout, cancels superseded runs, requests read-only repository access, and saves preview screenshots for seven days. No Apple signing account or cloud secrets are needed. The workflow also boots an available iPhone simulator, launches the offline preview and captures its home and Alert All screens. The previous home-screen launch/capture run passed; the Alert All revision requires a new run. The [first cloud run](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39512206616) passed: checklist tests and native simulator compilation succeeded. This is compilation evidence, not an interactive UI test or proof of E2EE.

An unsigned simulator build is not an installable iPhone release. This workflow does not publish an app, provide an interactive simulator, provision a messaging server, or establish working encryption.

### Local Xcode and alternative builds

Apple lists Xcode 15.2 as compatible with macOS Ventura 13.5+, so an older Xcode downloaded from Apple's Developer Downloads may support local UI development on this machine. That does not make it suitable for current App Store uploads or guarantee compatibility with the eventual current Matrix SDK and your iPhone's iOS version.

For current builds, `codemagic.yaml` provides an unsigned simulator-build workflow for a hosted Mac. It has not been run against a cloud account. Put this folder at the root of a repository, connect that repository to your own Codemagic account, and choose the workflow. No paid signing membership is required for this unsigned simulator build; the produced app cannot be installed on a physical iPhone. Codemagic is build automation, not a full interactive remote Xcode desktop. Simulator screenshots and automated UI tests should be added to that workflow once the first build passes. Interactive testing can use a compatible local simulator or an interactive rented Mac.

Physical distribution through TestFlight requires Apple Developer Program membership, signing configuration, a device build, and Apple's applicable review. The included workflow does not do this. The source is published on GitHub. No iPhone app has been distributed, hosting provisioned, or paid service purchased.

## Next engineering milestone

Integrate the Matrix Rust SDK's supported Swift bindings, pin a reviewed release, and provision an invite-only server. Require encrypted rooms and encrypted media without plaintext fallback. Implement secure session storage, device verification, recovery, account lifecycle, and revoke/ban behavior. Prove messaging between two independent devices before describing Letters as an encrypted messenger. Calls require a separate encrypted calling integration and verification.

Track progress in [the project checklist](Docs/CHECKLIST.md). See `Docs/FEATURE_PARITY.md` and `Docs/SECURITY_ARCHITECTURE.md` for the full target and outstanding work. These requirements remain outstanding, not silently removed to fit a portfolio demo.

## Sources

- Apple Xcode compatibility: https://developer.apple.com/xcode/system-requirements
- Apple Developer downloads: https://developer.apple.com/download/all/
- Codemagic pricing: https://docs.codemagic.io/billing/pricing/
- GitHub Actions public-repository usage: https://docs.github.com/en/actions/concepts/billing-and-usage
- Matrix Rust SDK: https://github.com/matrix-org/matrix-rust-sdk
- Swift bindings: https://github.com/matrix-org/matrix-rust-components-swift

No Element application source has been copied. A future SDK integration must retain its required license notices and attribution. Present Letters in a portfolio as original product/UI work using an established messaging SDK, with the actual implementation status clearly stated.
