# Letters project checklist

Updated 22 October 2026. Checked items describe completed work, not security certification.

## Portfolio foundation

- [x] Public repository titled Letters' Source Code.
- [x] Letters app name and beige-envelope icon with an S seal.
- [x] Native space-age SwiftUI chat preview with fictional in-memory data.
- [x] Local Orbit stickers and PNG/JPEG import interface.
- [x] Offline voice call-preparation screens for sample contacts.
- [x] Hosted Xcode simulator compilation and standalone readiness tests passed.
- [x] Previous hosted simulator launch and screenshot capture passed (run 39517134620).
- [x] New home and Alert All screenshots captured and visually inspected; cloud run 39547086390 passed.
- [x] Alert rehearsal lifecycle tests passed, including duplicate submission, note limits and ending/restarting.
- [x] Add Alert All local rehearsal with confirmation and duplicate-submission protection.
- [x] Replace video calling with Alert All per owner request; retain voice calling.
- [ ] Interactive accessibility, navigation, sticker import and small-screen QA.
- [ ] Physical iPhone signing and distribution.
- [x] Add download/install guide distinguishing source, simulator and signed iPhone builds.
- [ ] Verify downloadable simulator ZIP and checksum in the hosted workflow.

## Letterbox invitations

- [x] Native preview generation of QR and matching typed code, review/accept and revocation.
- [x] Camera QR scanner with permission handling and local QR-image import.
- [x] Separate member/contact admission and existing-member group invitations; empty new sample chats.
- [x] Local-only admission service with persistent, atomic one-use redemption, session checks, private contacts and group authorization.
- [x] Server invitation/security-boundary tests passed locally.
- [x] Letterbox cloud build passed 10 Swift tests, 10 server tests, native compilation, launch and screenshot QR decoding (run 39549406715).
- [x] Every approved member can issue invitations; tests verify independent contact lists and personal group administration.
- [x] Visually inspect the Letterbox screenshot and verify the original artifact checksum.
- [x] Prepare public portfolio gallery at `Letters/Prototype Screenshots` with original native captures and honest captions.
- [ ] Continue adding verified screenshots with completed feature milestones.
- [ ] Deploy reviewed HTTPS service with production authentication and abuse controls.
- [ ] Connect native invitations to live membership and verified encrypted direct/group rooms.
- [ ] Cross-device scanning, malicious input, camera-denial, VoiceOver and cancellation QA.

## Free hosting — deferred while Osaka has no capacity

- [x] Retry the approved Osaka ARM server configuration; Oracle rejected provisioning for lack of capacity.
- [x] Save Oracle Resource Manager stack `letters-osaka-free-server` without running Apply.
- [x] Confirm the saved stack has no deployment jobs.
- [x] Check Melbourne availability: account region limit prevents subscribing; Always Free compute is restricted to the home region.
- [ ] Review saved Terraform network references and free-tier eligibility before applying.
- [ ] Retry Osaka when capacity is available: 2 OCPUs, 12 GB RAM, approximately 50 GB boot storage, dedicated network, no public IP.
- [ ] Verify successful provisioning and actual cost limits; no server currently exists.
- [ ] Decide and approve secure external connectivity before opening any public service.

No paid upgrade, scheduled retry, running server or working messaging service is implied by saving the stack. Credentials and account identifiers stay outside this public repository.

## Working private messenger

- [x] Pin and link Matrix Rust SDK Swift 26.10.02 in a separate development package.
- [x] Implement guarded encrypted text/session operations and Keychain-backed session storage.
- [x] Verify independent SDK-client decryption, raw server ciphertext, outsider read/join denial and disabled signup.
- [x] Verify plaintext/audience guards, plaintext-invitation departure and device-preserving session restore in isolated Synapse.
- [x] Compile the native iPhone simulator app with the pinned SDK linked.
- [ ] Verify real iPhone Keychain/locked-device/reinstall behavior and independent physical devices.
- [x] Annotate source responsibilities, security guards and important logic; add CODE_GUIDE.md.
- [x] Implement one-use Letterbox login grants and development Synapse authentication/account-validity callbacks.
- [x] Verify the new admission-to-SDK bridge, real device-session login, replay/expiry/account binding, removed-member sync denial and encrypted exchange in hosted tests (run 39679172969).
- [ ] Finish server-enforced contact/group room policy, verification, recovery, native account/chat integration and security review.
- [ ] Invite-only account creation, removal and session revocation.
- [ ] Encrypted rooms/media, secure key storage, device verification and recovery.
- [ ] Prove encrypted delivery between two independent devices with no plaintext fallback.
- [ ] Integrate and verify encrypted voice calls, including relay behavior.
- [ ] Encrypted Alert All to all approved members, truthful acknowledgements and resolution.
- [ ] Push notifications and iOS background calling behavior.
- [ ] Persistent encrypted messages and stickers; importable sticker packs.
- [ ] Complete remaining feature families in FEATURE_PARITY.md and perform security review.

The native chats remain a portfolio preview. A separate encrypted-messaging development boundary now exists; live native chats, verified identities, recovery and encrypted calls remain release gates. See ENCRYPTED_MESSAGING.md for the exact scope and test evidence.

## Current owner preference

Finish app functionality before discussing deployment. Continue with the encrypted messaging integration milestone; do not treat gallery screenshots or passing local prototype tests as completion of the app. No deployment, purchase or signing enrollment is part of the screenshot update.

## Orbital Home / world headlines

- [x] Implement animated Earth/atom in place of the Home text heading, retaining the original app icon.
- [x] Implement category runner for global stocks, oil, crypto and world headlines.
- [x] Add attributed RSS client, bounded parser, category caches and honest offline/age states.
- [x] Add pause, Reduce Motion and foreground-only lifecycle handling.
- [x] Hosted parser tests, all four live Guardian feeds, native compilation and captures passed (run 39556128782).
- [x] Inspect and publish the labelled-sample orbital Home screenshot as `04-orbital-home-news-preview.png`.
- [ ] Interactive device/accessibility/offline lifecycle QA.

- [x] Group Home navigation by intent (Chats & People, Around the World, Connect, Safety, You); keep shallow submenus and common shortcuts.
- [x] Add reduced-motion-aware fades, deferred menu navigation and a stable article reading snapshot.


## Markets — Home drop-down only

- [x] Keep repository public per owner preference; no new license selected.
- [x] Add Home menu Markets destination; retain the existing five bottom tabs.
- [x] Add Stocks/Indexes/Oil/Bitcoin sections, instrument selection, attribution, source links and reload.
- [x] Identify currencies, delayed/end-of-day feeds, indicative oil CFDs and venue-specific Bitcoin.
- [x] Isolate provider in ephemeral WebKit storage and stop it when hidden/backgrounded.
- [x] Native build and labelled Markets sample capture passed (run 39682680676).
- [x] Inspect sample capture and verify artifact SHA-256 before portfolio publication.
- [x] Inspect actual-provider simulator captures for Apple, WTI and Coinbase Bitcoin (run 39684615837); provider quotes rendered.
- [x] Inspect Indexes provider capture and four-section sample image (run 39687281594). S&P 500 is provider-restricted in the widget; its source link remains available.
- [ ] Resolve embedded index quote availability; check every remaining catalogue instrument and interactive switching on a physical device.
- [ ] Physical-device/VoiceOver/large-text/offline/provider-availability interaction QA.
