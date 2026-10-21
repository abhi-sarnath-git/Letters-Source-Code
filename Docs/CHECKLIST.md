# Letters project checklist

Updated 21 October 2026. Checked items describe completed work, not security certification.

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

- [ ] Integrate and pin reviewed Matrix SDK Swift bindings.
- [ ] Invite-only account creation, removal and session revocation.
- [ ] Encrypted rooms/media, secure key storage, device verification and recovery.
- [ ] Prove encrypted delivery between two independent devices with no plaintext fallback.
- [ ] Integrate and verify encrypted voice calls, including relay behavior.
- [ ] Encrypted Alert All to all approved members, truthful acknowledgements and resolution.
- [ ] Push notifications and iOS background calling behavior.
- [ ] Persistent encrypted messages and stickers; importable sticker packs.
- [ ] Complete remaining feature families in FEATURE_PARITY.md and perform security review.

The current app is an offline portfolio preview. End-to-end encryption and live calls remain release requirements and are not implemented.
