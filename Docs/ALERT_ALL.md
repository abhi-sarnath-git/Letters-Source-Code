# Alert All

## Agreed scope — 21 October 2026

Alert All replaces video calling in the current Letters scope. Voice calling remains. The intended recipients are **all approved Letters members**, not just the sender's direct contacts. The remaining feature inventory still applies with this explicit owner-approved exception.

## Current preview

The Alert All tab presents its intended audience, an optional note (maximum 280 characters), a confirmation step, a local rehearsal record and an explicit end-rehearsal action. Empty notes use “I need help. Please check on me.” Duplicate submissions cannot replace an active rehearsal. Ending a rehearsal is idempotent. State is held in memory and resets on restart.

This is a local rehearsal only: no notifications, recipient acknowledgements, location, network requests or encryption are generated. There are no fake “sent”, “delivered”, “help is coming” or member counts. No emergency services are contacted. Live delivery remains unimplemented.

## Required live behavior

- Resolve recipients from authenticated, current, approved membership at submission. Never trust a list from the client. Define removed/blocked-member policy explicitly; “all approved” is the agreed audience, and membership implications must be clear during onboarding.
- Encrypt alert details for authorized member devices using the reviewed messaging SDK. Use a private membership-controlled room or equivalent verified fan-out; fail closed on encryption/trust errors. Ensure removed devices cannot decrypt future alerts.
- Bind a unique alert ID and idempotency key to the authenticated sender. Confirmation must precede submission. Rate-limit abuse at the service, without silently discarding a legitimate retry.
- Distinguish local draft, sending, server accepted, device received, explicit human acknowledgement, expired, failed and resolved. Server acceptance or APNs acceptance does not prove a person saw the alert. Show partial failures and offline state accurately.
- Capture recipients at send time; new members must not receive historical emergency details through unrestricted history. Prevent replay and duplicate notification on retries/reconnects; expire stale alerts.
- Use a generic push notification with an opaque event reference, not plaintext emergency details or keys. Fetch/decrypt in the authorized client. Obtain notification consent and handle disabled notifications, stale tokens and offline devices.
- Provide a conspicuous recipient alert with sender identity, time and an explicit acknowledgement action. Do not generate acknowledgements automatically when a notification arrives. Acknowledgements disclose identity only to the agreed audience.
- Let the sender mark an alert resolved or sent in error; propagate an encrypted update to the original authorized audience without pretending the original alert was unseen or retracting OS notifications reliably.
- Do not automatically collect or attach location. Any future optional location sharing needs explicit consent and a clear audience.
- State that Letters does not contact emergency services or guarantee delivery, immediate attention or assistance.

## iPhone notification constraints

Ordinary notifications depend on connectivity, permission and device settings. They cannot promise to sound on every device. Critical Alerts that override silent mode/Focus require Apple's special entitlement and the user's permission. Letters does not have that entitlement and must not simulate urgency through fake calls or bypass system preferences.

Apple references:
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts
- https://developer.apple.com/documentation/usernotifications/unauthorizationoptions/criticalalert

## Acceptance evidence before live use

1. Two independent iPhones plus a third approved member receive the encrypted event; sender UI reports exact observable states. Uninvited/removed/expired-session users are denied, including direct API access.
2. Duplicate taps/retries deliver one logical alert. Network interruption, offline members, denied notification permission and revoked tokens have truthful outcomes and recovery paths.
3. Acknowledgements are explicit, authenticated, idempotent and bound to the correct alert. Resolution cannot be forged by another ordinary member.
4. Membership/key rotation, expiry and history rules prevent unauthorized access and stale replays. Push payloads, logs and analytics contain no emergency text or keys.
5. Verify VoiceOver, large text, confirmation cancellation, long notes and accidental activation behavior. Test with fictional rehearsals and consented participants.

Hosting is still blocked by Osaka capacity; the saved Oracle stack has not been applied. Push provisioning and physical-device distribution are also outstanding.
