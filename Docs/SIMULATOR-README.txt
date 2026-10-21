LETTERS — SIMULATOR PREVIEW

This is an unsigned iPhone SIMULATOR app for a compatible Mac with full Xcode
and an installed iPhone simulator runtime. It cannot be installed on an iPhone,
iPad, Windows PC or Android device. Renaming it to .ipa will not make it work.
The old project Mac without Xcode cannot run it either.

CURRENT BEHAVIOR
Offline portfolio preview with fictional conversations, local stickers,
Alert All rehearsal and per-member Letterbox QR/code demonstrations.
No live accounts, real messages, push notifications, calls or E2EE.
Letterbox codes are local preview codes and do not grant online access.
Do not use this build to send private messages or request emergency help.

DOWNLOAD
On the public repository's Actions tab, open a successful current
"Letters iPhone preview" run. Download "letters-simulator-download" from
Artifacts. GitHub may require sign-in. The artifact is retained for seven days;
rerun the workflow if expired. Unzip the artifact and then unzip the included
Letters-Simulator-Preview.zip. BUILD-INFO.txt records the source commit,
Xcode, SDK and architectures. SHA256SUMS.txt checks the inner ZIP.

RUN ON A COMPATIBLE MAC
1. Open Xcode and an iPhone Simulator. The verified cloud environment uses
   Xcode 16.4 and an iOS 18.5 simulator; check BUILD-INFO.txt for this build.
   The Mac must support the required Xcode/runtime. Other runtimes are not
   guaranteed to work just because the app declares iOS 16 as its minimum.
2. With the simulated iPhone booted, drag Letters.app onto its window.
3. Open Letters from the simulated iPhone's home screen.

If drag-and-drop fails, use Terminal from the extracted package folder:
  xcrun simctl install booted ./Letters.app
  xcrun simctl launch booted com.example.letters

No script runs automatically. Do not bypass macOS security warnings.
Camera scanning needs a real camera/device and remains unverified on iPhone.
Manual Letterbox entry works in the preview; its state resets on restart.

IPHONE INSTALLATION
There is no signed iPhone download or TestFlight invitation yet.
For personal development installation, build the SOURCE using compatible
Xcode, your Apple Account/Personal Team and your connected iPhone. Free
Personal Team profiles expire after seven days and have capability limits.
For family/friend beta installation, the owner needs Apple Developer Program
membership, signing and App Store Connect/TestFlight setup. TestFlight beta
builds expire after up to 90 days. External testing may require Apple review.
Installing an app never grants membership in Letters: Letterbox admission
and verified encrypted messaging are separate work still outstanding.

Source and implementation status:
https://github.com/abhi-sarnath-git/Letters-Source-Code
See Docs/DOWNLOADS.md and Docs/LETTERBOX.md in that repository.
