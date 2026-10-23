# Build, inspect and reproduce

## Native portfolio interface

Requirements: a compatible Mac with full Xcode and an iOS simulator. Hosted validation uses macOS 15 / Xcode 16.4; the project targets iOS 16+. This owner's older Mac has command-line tools only, so hosted compilation is the authoritative native build evidence.

From the repository root:

```sh
xcodebuild -project Letters.xcodeproj -scheme Letters -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

For interactive use, open `Letters.xcodeproj`, choose Letters and an iPhone simulator, then Run. Ordinary conversations and invitation controls are local samples. Restarting resets sample state. Microphone/camera functions require relevant permission and suitable hardware; simulator capture does not prove them on an iPhone.

## Component tests

```sh
python3 -m unittest discover -s server -v
cd LettersCore
swift test
```

Run each block from the repository root unless it changes directory. Python without optional dependencies skips the real cryptographic passkey test explicitly. For the full pinned integration environment, use Python 3.12:

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r scripts/requirements-integration.txt
LETTERS_REQUIRE_PASSKEY_TESTS=1 .venv/bin/python -m unittest discover -s server -p test_account_registration.py -v
.venv/bin/python scripts/test-encrypted-messaging.py --room-policy-only
.venv/bin/python scripts/test-encrypted-messaging.py
```

The harness provisions an ephemeral loopback Synapse with synthetic accounts, runs checks and cleans up. The full messaging harness also requires compatible Xcode/Swift tooling and network access for pinned packages. A failing check exits nonzero. Do not use real contacts/messages or expose the test server publicly. The real-server policy test and SDK adversarial test use deliberately different module configurations; passing one does not replace the other.

## Optional encrypted native development screen

Read [DEVELOPMENT_CHAT.md](DEVELOPMENT_CHAT.md) before opening Debug **You → Messaging development → Encrypted development chat**. This manual operator flow needs a trusted HTTPS server, synthetic approved members and short-lived grants. CI's temporary server is not a deployed endpoint. Normal native enrollment is unfinished; there is no one-click production setup.

## Troubleshooting and interpretation

- Missing Xcode/iOS SDK: use a compatible full Xcode installation or inspect the hosted workflow evidence. Command-line syntax parsing alone is not a native build.
- Feed/widget unavailable: external providers may restrict access or delay data. Do not substitute fabricated prices/headlines as live data.
- Encrypted operation fails: check the trusted server, active membership, grant expiry and exact room audience. Never disable encryption or trust guards to make a demo pass. Refresh before retrying an uncertain send.
- Artifact expired: rebuild from the recorded source. GitHub artifacts are temporary; committed portfolio PNGs have their own SHA256 manifest.
- No iPhone installer: this project provides source and an unsigned simulator workflow. No public release is supplied.

See [feature status](FEATURE_STATUS.md), [verification evidence](VERIFICATION_CHECKPOINT.md) and [code-reading guide](CODE_GUIDE.md). No physical-device validation has been performed.
