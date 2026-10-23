# Portfolio verification checkpoint — 23 October 2026

## Source and hosted evidence

Functional source: [`c590c1ada3bbd7019c4265d708192b7bd152d42b`](https://github.com/abhi-sarnath-git/Letters-Source-Code/commit/c590c1ada3bbd7019c4265d708192b7bd152d42b).

Hosted validation: [workflow 39927607570](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39927607570), [job 120327991666](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39927607570/job/120327991666). The following result is recorded from GitHub's completed step summaries, not inferred from source syntax or screenshots.

**Result: SUCCESS.** All hosted job steps completed successfully:

- Server admission/contact boundaries and invitation/alert/readiness component tests.
- Public news-feed connectivity and parsing.
- Pinned account-registration cryptographic boundary tests (historical research, not native account login).
- Real Synapse direct-room permission enforcement, including unauthorized invitation and plaintext/downgrade refusal.
- Unsigned native iPhone simulator build.
- Real SDK encrypted messaging/server-boundary tests, including the new typed admission transport validation.
- Simulator launch/captures and QR check; simulator ZIP packaging and artifact upload.

Hosted logs confirm **8 messaging tests passed**, **9 account-registration tests passed**, and **16 core tests ran with one opt-in live-feed check skipped in that invocation**. The workflow then ran the live-feed check separately with its explicit enable flag and it passed. Skipped tests are not counted as passed.

Artifacts are retained for seven days; this checkpoint preserves source and existing committed screenshots, not a permanent hosted binary. Build success does not extend the feature claims in the status table.

The documentation checkpoint changes presentation/status only; it does not add missing app integrations. The final documentation commit can be obtained from this file's GitHub history. The separate local backup records its exact public commit and tree in CHECKPOINT.json.

## Additional checks performed locally

- Python server suite: 32 tests run, 31 passed and one optional real cryptographic passkey test explicitly skipped because its dependency was absent locally. The hosted environment separately installs pinned dependencies for the real signature check.
- All 25 committed native PNGs match their SHA256 manifest. Their original capture provenance remains in the gallery; they were not replaced with mockups or represented as captures of later functionality.
- New README/setup/status/archive documentation links resolve within the source snapshot.
- Local source matched the public functional tree before documentation changes. Backup preparation uses a public-tree allowlist and verifies Git blob identities, followed by ZIP integrity and per-file byte checks. Private work folders are not copied.

## What these checks do not establish

No physical-iPhone test was performed; the owner declined participation. No completed native invitation-to-chat user journey, dependable emergency alert, real call, remote self-destruct, biometric login or production service is claimed. Hosted SDK clients use independent synthetic accounts/stores in one Mac process. Simulator launch/capture is a smoke check, not interactive accessibility or security QA. There has been no independent security audit.

See [feature status](FEATURE_STATUS.md) for the remaining work. Work-in-progress archival requires explicit owner approval; this checkpoint does not archive or release the app.
