# Completion and portfolio archive plan

## Owner's scope — 22 October 2026

Finish a usable native SwiftUI portfolio application, validate it with reproducible local infrastructure, then archive the project. Do not substitute a half-finished milestone for the finished application. There is no public launch, App Store/TestFlight release, paid service or production deployment authorized. The budget for external services is zero.

The owner selected invitation-based enrollment instead of SMS, accepted weekly free sideload refresh for optional personal testing, and excluded capabilities unavailable to free Apple signing. Native APNs and the current associated-domain passkey design are outside this scope. Local biometric protection is a separate implementation task, not an already completed account login. Historical phone/passkey design images remain labelled historical previews; they must not become nonfunctional controls in the finished app.

## What finished means

- Real invitation enrollment and per-person contacts, with server-enforced direct/group permissions.
- A normal native account/contact/chat flow without operator-entered Matrix IDs or a developer console.
- Independently verified encrypted text and media, persistent history, safe failures and clear send states.
- Device trust/key-change handling, local access protection and documented recovery/revocation behavior.
- Working timer/clear controls with honest cross-device deletion limits; no claim of erasing recipients' screenshots or exports.
- Every included screen performs its advertised function. Remaining planned functionality belongs in the roadmap, not inert controls presented as implemented features. Any change to the agreed feature set must be explicit.
- Reproducible local server/application setup, meaningful tests, native UI verification and security/privacy limitations documented.
- Reader-friendly source comments explaining decisions, responsibilities, state changes and security boundaries; no secrets or sensitive message content in logs.

The current Debug encrypted chat is a tested integration milestone, not satisfaction of this list. Voice calling, Alert All, native Letterbox enrollment and other preview surfaces remain incomplete until implemented and tested or explicitly removed from the final scope. Background native push is excluded; an in-app broadcast cannot be presented as dependable emergency notification.

## Recruiter-facing delivery

The repository landing page will lead with what the finished app does, authentic native screenshots, a short architecture map and a link to a reproducible demonstration. A code-reading guide will trace invitation → identity/session → room permission → SDK encryption → delivery/decryption. Setup instructions will state exact runtime requirements, commands, expected results and troubleshooting steps. Test evidence will identify the source version and distinguish synthetic integration tests, simulator checks and any actual physical-device testing.

No unsupported feature, simulated OTP, local preview or isolated SDK test will be described as a fully operational end-user feature.

## Archive location and sequence

The primary archive is the existing public repository [Letters' Source Code](https://github.com/abhi-sarnath-git/Letters-Source-Code). The source, instructions, native screenshots, license information and test evidence will remain publicly readable there. A separate local source/docs backup will also be preserved on the owner's Mac, excluding account databases, sessions, real conversations, credentials and private administration keys.

Only after completion and final verification: freeze an identified final version, verify the backup/checksum and documentation links, then use GitHub's repository archive setting to make it read-only. The repository is not archived now, and no paid or public deployment is a prerequisite for this portfolio archive.
