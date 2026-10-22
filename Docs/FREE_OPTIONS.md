# Zero-cost portfolio development and installation options

Provider documentation checked 22 October 2026. The owner requires zero paid services and has chosen a completed native portfolio application followed by an archive, without a public launch or production deployment. See [the completion/archive plan](ARCHIVE_PLAN.md). No new accounts, billing upgrades, sideload tools or public services were activated for this research.

## Chosen path

Keep SwiftUI and the existing GitHub-hosted native builds. Finish the actual account/contact/chat flows and validate against isolated, reproducible local infrastructure. Invitations replace real SMS enrollment. Preserve source, screenshots, setup instructions and test evidence on GitHub. Personal device installation is optional testing, not a family distribution commitment.

Apple's free Personal Team provisioning expires after seven days and has device/app limits. A compatible Xcode installation is one personal-testing route; the current Mac cannot build the pinned app locally, so hosted builds remain necessary. See [Apple's free-account limits](https://developer.apple.com/help/account/basics/about-your-developer-account/).

Apple's capability table does not provide Associated Domains or native push notifications to a free Apple account. The current native passkey design needs Associated Domains, so free signing is not a complete substitute for that design. Local biometric access protection is a different feature and still requires implementation/testing. TestFlight/App Store distribution is outside the chosen scope. See [Apple's capability matrix](https://developer.apple.com/help/account/reference/supported-capabilities-ios/).

## Optional free personal installation

[AltStore Classic](https://altstore.io/) is a third-party sideloading route worth testing after we produce a physical-device build; the existing simulator ZIP cannot be installed on an iPhone. Its current Mac download requires macOS 11 or later. This is a candidate, not a verified Letters installation on the owner's Mac/iPhone.

[AltStore's limits](https://faq.altstore.io/altstore-classic/your-altstore) include seven-day app expiry/refresh and three active sideloaded apps per device. It requires device pairing/setup and Apple authentication handled by the owner. It does not unlock Apple's unsupported signing entitlements. No signing tools were installed and no Apple credentials were requested or uploaded.

## Free hosting alternatives researched — not being deployed

| Option | Suitable use | Limits and tradeoffs |
|---|---|---|
| Existing compatible computer | Local Synapse/admission database and repeatable demo | Must stay on for a live demo; storage, backups, electricity and network availability remain the owner's responsibility. Internet access is a separate security decision. |
| Oracle Always Free | Possible future small experimental server | Home-region capacity can be unavailable, and idle machines can be reclaimed. The saved Osaka stack is not a running server. Do not upgrade to paid billing. [Official limits](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm). |
| Tailscale Personal | Optional private access to an existing server | Currently up to six users for noncommercial personal use. It supplies networking, not compute/storage. An optional public Funnel has bandwidth limits; enabling it exposes a service and is not authorized here. [Pricing](https://tailscale.com/pricing), [Funnel limits](https://tailscale.com/docs/features/tailscale-funnel). |
| GitHub Pages | Free static recruiter-facing documentation/demo site | It cannot host our Synapse process, admission database or private messaging backend. [Official description](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages). |
| Render Free | Short-lived experiments | Services sleep after inactivity, files are ephemeral and its free Postgres expires after 30 days. This is unsuitable as the durable store for the current messaging design. [Official limits](https://render.com/docs/free). |

No ongoing free SMS delivery service has been verified for this project. For example, [Twilio's trial](https://www.twilio.com/docs/usage/trials) is time-limited, not permanent free verification. The owner chose invitation-based enrollment; test OTPs must never be represented as proof that a real phone number was verified.

A Home Screen web application was also considered: Safari supports web passkeys and web push without native distribution, but it would require a separate web implementation. The owner chose to retain native SwiftUI instead. This document does not authorize that pivot.

## Honest boundaries

Free tools can support a complete, reproducible portfolio app. They do not establish uninterrupted public service, unlimited media storage, guaranteed emergency alerts, Apple-supported family distribution, or identical WhatsApp behavior. The finished application must advertise its actual included scope and remove misleading nonfunctional controls. Infrastructure limitations and any unvalidated physical-device behavior must remain visible in the archive.
