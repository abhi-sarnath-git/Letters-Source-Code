# Letters feature-parity target

Baseline: WhatsApp consumer iPhone experience, reviewed 21 October 2026. All feature families below remain requirements. This is an initial inventory, not a completed exhaustive audit of every regional rollout, numerical limit, or edge case. A versioned behavior-level audit is required before claiming identical features. Family-only access changes discovery and membership; it must not become an excuse to drop messaging features.

## Status definitions

- **Preview**: fictional, local UI behavior only.
- **Planned**: no implementation yet.
- **External dependency**: availability requires third-party services, eligibility, platform access, or separate infrastructure.

| Feature family | Required behavior | Current status |
|---|---|---|
| Identity and membership | Profiles, avatars, about, invite acceptance, expiring/revocable invitations, device sessions, account deletion | Planned; profile/invite explanations in preview |
| Invitations | Server-enforced admission, single-use redemption, expiry, replay prevention, revocation and member removal | Planned |
| Direct and group chat | Real-time messages, history, offline queue, retry, deduplication, ordering, groups and administration | Local sample preview only |
| Chat organization | Search, unread, favorites, lists, groups, archive, pin, mute, mark unread | Search/unread/favorites/groups preview; remaining planned |
| Delivery state | Queued/sent/delivered/read, typing, presence and last seen with privacy controls | Planned; preview does not fabricate delivery |
| Message actions | Reply/quote, forward, edit, delete for self/everyone, reactions, star, pin, rich formatting, mentions | Planned |
| Media | Camera capture, photos/HD photos, videos/HD videos, captions, albums, files, downloads and sharing | Planned |
| Expression | Voice notes, playback speed, video notes, GIFs, stickers, avatars, emoji, transcripts | Planned; some media features need provider/OS integration |
| Sticker library | Built-in packs, personal imports, animated packs, favorites, recents, creation, sharing, deletion and encrypted delivery | Six space-themed symbol stickers and individual still-image import in local preview source; remaining planned |
| Shared context | Contacts, location, live location, links and previews | Planned |
| Groups | Member roles, admission approval, group settings/permissions, group links and QR codes, exits, admin moderation | Planned |
| Coordination | Polls, events, RSVPs, scheduled calls | Planned |
| Communities | Topic groups, announcements, replies, admin management | Planned |
| Broadcasts and channels | Broadcast lists, channel posts, following, reactions and audience controls inside the invite-only network | Planned |
| Status | Text/photo/video/voice updates, expiry, views, replies, mentions, resharing and audience controls | Planned; roadmap screen only |
| Calling | Encrypted voice/video, one-to-one and groups, incoming/background calls, missed calls, mute, speaker, camera switching | Planned; separate calling infrastructure required |
| Advanced calling | Call links, scheduling, screen sharing, picture-in-picture, video effects/backgrounds | Planned |
| Security | E2EE, device verification, key change warnings, secure local storage, encrypted media and key recovery | Planned; mandatory before real messaging |
| Privacy | Disappearing messages, view-once media, locked chats/app, blocked users, granular audience/presence/read controls | Planned |
| Devices and backups | Linked devices, secure sync, revocation, recovery, encrypted backup/restore, migration | Planned |
| Notifications | APNs, background behavior, notification privacy, per-chat settings, badge state and sounds | Planned; Apple provisioning required |
| Storage and data | Usage, media retention, download controls, connectivity handling, low-data modes, export and deletion | Planned |
| UX and accessibility | Dynamic Type, VoiceOver, contrast, reduced motion, one-handed use, themes, localization, RTL | Native accessibility hooks present; full device QA planned |
| Other platforms | Web/desktop, Android, watch integration | Outstanding dependencies for literal cross-platform WhatsApp parity; iPhone is the first requested client |
| Region/provider services | Payments, business interactions, AI assistants, subscriptions or other current region-specific services | External dependency; feasibility/eligibility audit pending, no silent exclusions |
| WhatsApp interoperability | Talking directly to WhatsApp users | No connection exists; requires an authorized integration, cannot be assumed from feature similarity |

## Milestones

1. Portfolio foundation: original identity, native navigation, sample interactions. **Prepared; native build and UI QA pending.**
2. Encrypted messaging pilot: server, accounts, invites, Matrix SDK, verified devices, encrypted text/media and recovery. **Not implemented.**
3. Messaging completeness: action parity, groups, media, privacy, reliable offline behavior and notifications. **Not implemented.**
4. Calls and updates: encrypted calling, background calls, status, communities, channels and broadcasts. **Not implemented.**
5. Parity audit and release: all outstanding families, limits, eligibility dependencies, multi-device/device recovery tests, accessibility and reliability validation. **Not implemented.**

## Reference pages

- Messaging: https://www.whatsapp.com/messaging
- Groups, polls, events and group calls: https://www.whatsapp.com/groups
- Calling: https://www.whatsapp.com/calling
- Privacy: https://www.whatsapp.com/privacy
- Communities: https://faq.whatsapp.com/495856382464992
- Channels: https://www.whatsapp.com/channels

Features vary over time and by availability. Literal parity cannot be certified from these marketing pages alone; retain the audit requirement rather than making an unsupported completion claim.
