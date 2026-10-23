# Feature status — portfolio preservation checkpoint

Status describes the source, not a released application. **Implemented** means code exists; **tested** identifies actual evidence; **preview-only** means local/sample behavior; **unfinished** names the missing integration. These categories can coexist within one feature.

| Feature | Implementation / preview | Verification | Unfinished or excluded |
| --- | --- | --- | --- |
| SwiftUI branding, navigation and search | Implemented local portfolio experience | Hosted native compilation, simulator launch/captures | Interactive accessibility and physical-device QA |
| Orbital Home and news | Implemented foreground feed retrieval, source/offline states and Reduce Motion; captures may use labelled fixtures | Hosted public-feed parsing/connectivity and native build | Provider availability; no always-running background news service |
| Markets: Stocks, Indexes, Oil, Bitcoin | Implemented attributed external widgets | Native compilation/captures; selected instruments visually checked | Provider delays/restrictions; every index not individually verified |
| Personal Letterbox QR and contacts | Preview-only native local flows; implemented persistent Python admission service | Invitation expiry, replay, concurrency, revocation and contact isolation tests | Native enrollment and secure admission-token persistence |
| Groups and room permissions | Implemented service policy and Synapse module | Policy unit tests and real-server direct-room enforcement test | Normal native group UX; exhaustive group/revocation synchronization validation |
| Native admission API | Implemented typed HTTPS transport and account/session endpoints | Endpoint-rejection and server account/session tests | Connection to normal native screens and secure admission vault |
| Encrypted text/history | Implemented SDK boundary and separate Debug development screen | Independent synthetic SDK accounts, restore/history, ciphertext and adversarial checks | Normal chat integration, continuous sync, retry/outbox policy, human identity verification |
| Encrypted voice notes, GIFs, images, videos, files | Implemented SDK transport; native prepare/review and on-demand preview in development screen | Encrypted roundtrips, ciphertext and plaintext-rejection tests; native build | Two-device native user journey, bounded streaming download and queue review |
| Session protection | Implemented Keychain credentials and keyed SDK store | SDK restore/logout and vault-failure tests | Real iPhone lock/reboot behavior, biometric lock, recovery and multi-device policy |
| Device trust | Implemented development trust filtering | Unsafe shield/plaintext checks | Finished contact verification and key-change UX; unverified identity remains a disclosed development exception |
| Self-destruct timers and Self-Destruct Now | Preview-only local sample conversation controls | Local timer logic and native captures | Remote expiry/redaction, attachment cleanup and cross-device enforcement |
| Stickers | Preview-only symbols and local PNG/JPEG import | Native build/captures | Persistence, packs and encrypted delivery |
| Voice calls | Preview-only call preparation | Native build/capture | Actual signaling, ringing and encrypted audio |
| Alert All | Preview-only local rehearsal | Local lifecycle checks and capture | Actual member broadcast/acknowledgements; never use for emergencies |
| Phone OTP and native passkey | Historical preview/research service boundary; SMS disabled | Isolated account boundary/signature tests in hosted environment | Excluded from agreed zero-cost native edition; not working account login |
| Native push / public deployment | Not supplied | None claimed | Excluded; no paid services, App Store/TestFlight or production hosting |

## Evidence limits

See [verification checkpoint](VERIFICATION_CHECKPOINT.md) for exact source and run. Build success is not interactive UI QA. Synthetic independent SDK stores in one hosted process are not two physical iPhones. The owner declined physical-device participation; those checks remain unperformed. Screenshots are evidence of visible UI only. No security audit or WhatsApp feature parity is claimed.

## If development resumes

Prioritize native invitation/account/contact integration, normal encrypted chat UX, current-room audience reconciliation, device verification/recovery, server-backed timers, and remaining calling/alert/sticker transport. Reassess pending upload authorization, media resource bounds and dependency notices before any real-user trial. Preserve current limitations until verified behavior supports changing them.
