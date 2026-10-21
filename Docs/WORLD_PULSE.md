# Home: Live Around The World

Owner-approved scope: replace the Home app-name heading with a small Earth/atom and visibly orbiting electrons, with a news runner to its left. Categories are World News, Global Stocks, Oil and Crypto. The owner selected global markets and category headlines, not market prices. The beige-envelope/S-seal app icon is unchanged.

## Implemented

- Native SwiftUI Earth/atom with three orbital paths and moving electrons. Movement pauses offscreen/inactive and for Reduce Motion; a user pause control stops both atom and headline rotation.
- A consolidated Home drop-down menu for news categories, pause/resume, conversation filters, Letterbox invitations/groups, voice calls, Alert All, Updates and profile/settings. Existing chat filters remain available as shortcuts.
- Rotating headlines, with a full-headline sheet and a link to the publisher.
- Public HTTPS RSS from The Guardian: `/world/rss`, `/business/stock-markets/rss`, `/business/oil/rss`, `/technology/cryptocurrencies/rss`. Source attribution remains visible. No API key, subscriber credential, price data or scraping bypass is used.
- Fetch on visible Home and category changes; at most once per category per five minutes, with periodic refresh while Home is foregrounded. This is regularly refreshed news, not instantaneous breaking-news delivery or financial quotes. iOS background execution is not kept running.
- Failed refreshes preserve per-category in-memory results and visibly mark them cached. No response shows unavailable rather than invented news. Fetch time and source publication time are different and are labelled separately.
- Ephemeral URLSession without cookie storage. No chats, contact lists, invitations or user identity are sent to feeds. Public requests still expose ordinary connection metadata such as IP address to the publisher. Opening a story visits the publisher's site.
- Fixed HTTPS feed addresses, byte-limited streamed responses, disabled external XML entity resolution, a headline-count cap, duplicate filtering and strict article-link host validation. Empty, malformed and unsafe feeds fail rather than render arbitrary links.
- Automated tests exercise RSS/CDATAs/entities, publication date parsing, duplicate filtering, malformed/oversized feeds, unsafe links and fixed category endpoints. A separate opt-in hosted test fetches all four real feeds, without logging article text.

## Portfolio capture

`--preview-world-pulse` displays an explicitly labelled fictional headline and does not contact news endpoints. The standard app fetches the real feeds. This keeps public screenshots reproducible and avoids re-publishing a changing news archive. A screenshot cannot prove continuous animation or network reliability; those need interaction/device QA. The capture must be described as a sample.

## Remaining verification / limits

Check the hosted build and all four feed tests, inspect the new native screenshot, and test menu selection, source links, pause, Reduce Motion, large text, VoiceOver, foreground/background and offline recovery on a device. Live news does not enable encrypted messaging, voice calls or emergency notifications.

The Guardian documents RSS for personal, non-commercial use. Revisit publisher permissions before wider/commercial distribution; the existence of a public feed is not a blanket redistribution licence. Only headlines and links are shown; the app does not reproduce article bodies or images.

Sources:
- https://www.theguardian.com/help/feeds
- https://www.theguardian.com/help/terms-of-service
