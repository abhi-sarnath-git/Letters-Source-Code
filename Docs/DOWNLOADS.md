# Download and install Letters

Updated 21 October 2026. Letters is an offline portfolio preview. There is **no signed iPhone release, App Store listing or TestFlight invitation yet**. A GitHub source download or simulator archive is not an iPhone installation.

## What is available

| Download | Who can use it | Current status |
|---|---|---|
| Source code | Developers with compatible Xcode; anyone inspecting the portfolio | [Repository](https://github.com/abhi-sarnath-git/Letters-Source-Code), Code → Download ZIP |
| Simulator preview | A compatible Mac with full Xcode and an iPhone simulator runtime | Workflow packages `letters-simulator-download`; verify the latest run's success before downloading |
| Screenshots | Anyone viewing the portfolio | Successful workflow artifact `letters-iphone-preview` |
| Signed iPhone beta | Invited family/friends using TestFlight | Not configured or distributed |

## Download the simulator preview

1. Open [GitHub Actions](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/workflows/ios-preview.yml).
2. Choose a **successful** run that includes the “Package downloadable simulator preview” step.
3. Under Artifacts, download **letters-simulator-download**. GitHub may require sign-in. Artifacts expire after seven days; a new workflow run can regenerate them.
4. Extract the downloaded artifact, then extract `Letters-Simulator-Preview.zip` inside it. Read `READ-ME-FIRST.txt` and `BUILD-INFO.txt` in the resulting folder. `SHA256SUMS.txt` verifies the inner ZIP.
5. On a compatible Mac, launch an iPhone Simulator through Xcode and drag `Letters.app` onto the booted simulator. Open Letters from its home screen.

The package also documents manual simulator installation commands. No installer runs automatically and no Apple signing credentials are included. The package is built for Simulator; it is not an `.ipa` and cannot install on a physical iPhone. Do not rename it or bypass operating-system security warnings.

The tested cloud environment currently uses Xcode 16.4 and iOS 18.5. Check the package's build information for changes. An older Mac without compatible Xcode cannot run this archive. A borrowed compatible Mac is an option; cloud compilation does not provide an interactive Mac desktop or connect automatically to your iPhone.

## Install on your own iPhone without paid membership

Apple permits personal development testing using a free Apple Account/Personal Team in Xcode, subject to capability and device limits. You need a compatible Mac/Xcode and an iOS version supported by that Xcode.

1. Download the source, open `Letters.xcodeproj`, and select the Letters scheme.
2. Sign into your own Apple Account in Xcode, choose your Personal Team under Signing & Capabilities, and select a unique bundle identifier.
3. Connect/pair your iPhone, follow Apple's device/developer-mode setup, select the phone as the run destination, and build/run.

Personal Team provisioning profiles expire seven days after issuance, so you must rebuild/reinstall as needed. This is personal testing, not an ordinary download link for family/friends. Some capabilities are unavailable. No Apple credential should be committed to this repository or sent through chat.

## Install for family and friends: TestFlight

The intended beta flow is:

1. The owner joins the Apple Developer Program (Apple currently lists US$99 per membership year, with local pricing where available).
2. Configure the app identity, signing and App Store Connect entry. Produce a signed device build using an Apple-accepted Xcode/SDK. The current simulator workflow does not do this.
3. Upload the beta, prepare required metadata/privacy and encryption declarations, and complete any required TestFlight review for external testing.
4. Invite selected testers by email. They install Apple's TestFlight app, accept the invitation, then install Letters.
5. Inside Letters, use separately enforced Letterbox invitations to join and add contacts. TestFlight installation is not membership authorization.

Testers do not need their own paid developer memberships. TestFlight builds can be tested for up to 90 days and need replacement builds. It is a beta channel, not a permanent private distribution solution. A later App Store distribution decision is separate; live accounts can still remain invite-only even if an app is downloadable.

We have not purchased membership, created a signing identity, enrolled any devices or invited testers. Keep building the encrypted pilot before relying on it for private communication. The preview has no real messaging, E2EE, live voice calls or emergency notifications, and its Letterbox codes work only within its current local session.

## Official references

- [Apple developer account and Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Running an app on simulator or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Apple Developer Program enrollment and price](https://developer.apple.com/programs/enroll/)
- [TestFlight overview and expiry](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [External TestFlight invitations and review](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
