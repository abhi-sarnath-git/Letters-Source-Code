# Source annotations and debugging map

Comments explain each file's responsibility, important blocks, security decisions and limits. Swift uses `//` for ordinary comments and `///` for API documentation; Python, shell and workflow YAML use `#`. Do not insert Python-style `#` comments into Swift: some Swift `#` forms are compiler directives, not comments.

Keep comments next to the code they explain. Describe why a guard, transaction or lifecycle rule exists, and update the explanation when behavior changes. Avoid repeating obvious assignments, hard-coding line numbers in explanations or modifying generated third-party SDK sources. Tests establish observed behavior; comments do not prove security.

## Follow a feature

| Responsibility | Start here | Important distinction |
|---|---|---|
| App startup, Home menu, chat navigation | `Letters/App/LettersApp.swift`, `Letters/Features/LettersRootView.swift` | The visible chat composer is still sample-only |
| Sample contacts/conversations | `Letters/Features/PreviewStore.swift` | In-memory profile isolation is not server authorization |
| Local Letterbox QR, scanner and review | `LetterboxView.swift`, `LetterboxScanner.swift`, `LettersCore/.../LetterboxPreview.swift` | Scanning a QR does not itself authorize admission |
| Real admission/invites/contact edges | `server/letterbox_service.py` | Authentication and transactions enforce boundaries; no live room is created by `direct()` |
| Approved member to Matrix device | `server/letters_synapse_auth.py`, `LetterboxLoginGrant.swift` | One-use login grants are separate from invitation QR codes and device access tokens |
| Crypto, session restore and sends | `LettersMessaging/.../LettersMessagingClient.swift`, `SessionVault.swift` | SDK encryption and Keychain policy are separate from membership approval |
| Native encrypted development chat | `DevelopmentChatView.swift`, `ConversationSnapshot.swift` | Manual synthetic-account setup; SDK history trust warnings and audience guards fail closed; no production contact approval claim |
| Public headlines/animation | `WorldPulseView.swift`, `LettersCore/.../WorldNews.swift` | Public news has no chat secrets; cached/offline state is explicit |
| Alert All and voice preparation | `AlertAllView.swift`, `LettersCallsView.swift` | Rehearsals/preparation do not notify or call anyone |
| Hosted verification | `.github/workflows/ios-preview.yml`, `scripts/test-encrypted-messaging.py` | Synthetic server tests and simulator captures are not real-iPhone QA |

## Diagnose a failure

1. Identify whether it is preview UI state, admission, device login, encryption, news or infrastructure. Follow the matching boundary above.
2. Reproduce using fictional accounts and the relevant tests. Admission tests run with `python3 -m unittest discover -s server -v`. Hosted CI runs the pinned homeserver/SDK test and native build because this Mac lacks full Xcode.
3. For login denial check grant expiry, replacement/replay, account binding, admission-session expiry and current membership. Do not bypass any guard to make a test pass. A consumed or lost-response grant requires a fresh grant, not reuse.
4. For encrypted send refusal check authenticated SDK state, room membership, authoritative encryption state and expected audience. Never add plaintext fallback or label server acceptance as delivery.
5. Record the failing test/step, non-sensitive error category, expected result and source commit. Never log QR invitation secrets, grants, passwords, access/refresh tokens, store keys, real messages or serialized session records.

The new login bridge is development-only. Review `MATRIX_ADMISSION.md` and `ENCRYPTED_MESSAGING.md` before extending it; native account UI, server-enforced room/contact policy, device verification and recovery are still required.
