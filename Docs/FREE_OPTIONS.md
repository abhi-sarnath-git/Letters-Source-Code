# Free-first development plan

Checked against provider documentation on 21 October 2026. No accounts created, payments enabled, source published, or infrastructure provisioned.

| Need | Free route | Limitation |
|---|---|---|
| Code and portfolio presentation | Local project, design previews and source repository | A preview does not establish working messaging or E2EE |
| Current Mac build tools | GitHub Actions standard macOS runners for a public repository | Public source is a deliberate choice; storage limits still apply; no interactive remote desktop |
| Private-source build alternative | Codemagic personal plan: 500 free macOS M2 build minutes/month | Allowance is for individuals; overage becomes paid if billing is enabled; builds are not an interactive simulator service |
| Local experimentation | Older compatible Xcode, such as 15.2 on Ventura 13.5+ | Does not guarantee support for modern SDK dependencies, current iPhones or current App Store submissions |
| Messaging server prototype | Oracle Always Free eligible Arm compute | Currently 2 OCPUs / 12 GB total and 200 GB combined volume allowance; regional capacity limits and idle reclamation; stay within all resource allowances |
| Local server demonstration | Existing computer, local network | No new hosting bill, but needs power and availability; external access requires deliberate network configuration |
| End-to-end encryption foundation | Matrix Rust SDK | Free SDK; integration, recovery, operation and security validation still required |
| Personal iPhone testing | Free Apple account and compatible local Xcode | Provisioning expires in seven days; device limits; not practical family distribution |
| TestFlight and App Store | No generally free route for an ordinary individual portfolio project | Apple Developer Program normally US$99/year or local equivalent; organizational fee-waiver eligibility is limited |

## Recommendation

Keep the portfolio phase at $0: use local previews and a free Mac cloud build allowance. Choose public-source GitHub Actions only if the owner wants the source public; otherwise begin with Codemagic's personal allowance. Neither requires buying a new Mac for cloud compilation. A cloud simulator build cannot be installed directly on an iPhone. Real family deployment comes after encryption and membership verification, with Apple distribution and dependable hosting budgeted separately.

Oracle is a plausible free server experiment, not a promise of uninterrupted family service. A free build host is not a messaging host. Full feature parity, especially video calls, large media and storage, cannot be guaranteed to stay within free allowances indefinitely.

## Sources

- https://docs.github.com/en/billing/concepts/product-billing/github-actions
- https://docs.codemagic.io/billing/pricing/
- https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- https://developer.apple.com/xcode/system-requirements
- https://developer.apple.com/help/account/basics/about-your-developer-account
- https://developer.apple.com/help/account/membership/program-enrollment/
- https://developer.apple.com/help/account/membership/fee-waivers/
- https://github.com/matrix-org/matrix-rust-sdk
