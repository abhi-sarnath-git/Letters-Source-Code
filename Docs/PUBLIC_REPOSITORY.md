# GitHub publication preparation

- Project title: **Letters' Source Code**.
- Intended repository name: `Letters-Source-Code` (a URL-friendly form of the requested title).
- Visibility authorized by the owner: **public**.
- Suggested description: `Letters — an invite-only, space-age iPhone messaging portfolio project. SwiftUI preview; end-to-end encryption and WhatsApp feature parity are planned, not complete.`
- Default branch: `main`.
- Repository contents: this Letters folder, including hidden `.github/` and `.gitignore` files.

Repository: https://github.com/abhi-sarnath-git/Letters-Source-Code

The public repository has been created in the connected owner's account and contains the initial source. The [first cloud build](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39512206616) passed on 21 October 2026: the bookkeeping tests and unsigned native simulator build succeeded using Xcode 16.4. All 22 published files were downloaded and matched against the local source before this documentation update. Do not claim a successful build until the run result is verified. No open-source license has been selected; publishing the source is distinct from choosing a license.

The local machine can parse Swift source but lacks full Xcode; GitHub-hosted compilation now verifies the native project. Interactive simulator/device QA and real end-to-end encryption remain outstanding. Documentation-only updates after the verified build use [skip ci] to avoid needlessly repeating an unchanged native build.

No account credentials, signing certificates, membership records, real conversations or private sticker uploads belong in the public repository. Store any future required credentials in repository/environment secrets, and grant jobs only the permissions they need.
