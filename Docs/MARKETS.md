# Markets — Home-menu destination

Open **Home menu → Explore → Markets**. Markets is a pushed screen with a native Back button, not a new bottom tab. The existing Chats, Updates, Calls, Alert All and You tabs are unchanged. The provider view is destroyed when hidden or backgrounded; returning reloads it.

The screen has Stocks/Indexes/Oil/Bitcoin sections and an instrument picker:

- Stocks: a starting global selection of Apple and Microsoft (US/USD), SAP (Germany/EUR, end-of-day widget feed) and BHP (Australia/AUD, delayed widget feed). This is not a complete global security search.
- Indexes: S&P 500, Nasdaq 100, Dow Jones Industrial Average, DAX and Japan 225. These are benchmark values in index points; provider access/delays may differ from exchange feeds.
- Oil: TradingView TVC WTI and Brent indicative CFD quotes, USD/barrel. These are not physical spot prices or exchange futures settlements.
- Bitcoin: Coinbase BTC/USD, explicitly venue-specific.

Normal mode loads the official TradingView Symbol Overview widget, including quotes, price/percentage change, chart ranges and market status as available. The original provider branding and linked attribution remain intact. There is no scraping, price export, custom quote API, API key, market server or paid subscription set up. Quote rights, availability, timestamps, market-close state and delays are controlled by the provider/exchanges; no promise of universal real-time data is made.

The widget has an ephemeral WebKit data store, no native JavaScript bridge, no shared Letters session storage and no access to chat data. It connects to a third party, which receives ordinary network information such as IP address and the requested instrument. Navigation is restricted to HTTPS TradingView/widget domains, and user-clicked source links open a separate browser sheet. A fixed catalogue, JSON-encoded settings and no arbitrary HTML inputs limit injection risk. Third-party widget content still needs normal provider/network trust and real-device accessibility review.

Reload and Open source remain available if a symbol/feed fails. Letters does not copy cached prices or fall back to invented quotes. Loading the wrapper does not prove the provider delivered a quote; interactive checks of actual data availability remain separate from compilation.

`--preview-markets` is an isolated, explicitly labelled fictional-price portfolio mode with no widget networking. It is used by hosted screenshot capture. A sample screenshot is not evidence of current prices or working live quotes. Normal mode never enables this flag automatically on errors.

## Sources

- [Official Symbol Overview embed](https://www.tradingview.com/widget-docs/widgets/charts/symbol-overview/)
- [Widget data/delay FAQs](https://www.tradingview.com/widget-docs/faq/data/)
- [Available widget markets](https://www.tradingview.com/widget-docs/markets/)
- [Meaning and limits of TVC instruments](https://www.tradingview.com/support/solutions/43000709178-what-does-tvc-stand-for-in-the-instrument-ticker/)

No real user accounts, chat infrastructure, messaging behavior or repository visibility changed. Source stays public at the owner's request; no new open-source license is selected.

## Verification

Run [39684615837](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39684615837) passed native compilation and tests. The downloaded screenshot artifact SHA-256 was `acb3d15f6ddcd4be46a3a9fc0fbc7e605f24bf89ca8c6815e6dc6fabe9ebc17d`. Actual normal-mode simulator captures were inspected for Apple, WTI and Coinbase Bitcoin: attributed provider quotes/charts rendered, including a delayed-data marker for Apple. This verifies those default instruments at capture time, not every catalogue symbol, current prices, physical-device interaction or universal real-time availability.

The Indexes update passed native compilation and all workflow checks in [run 39687281594](https://github.com/abhi-sarnath-git/Letters-Source-Code/actions/runs/39687281594), source `6701fd9a0864d92b700d20f333f4e82e121e4c10`. Screenshot artifact SHA-256: `d169fcbda77c669b796a8d119c8bf676d0b8acfc4578ddd42a5de2e2ea5ea277`. Both the four-section sample and actual S&P 500 widget were inspected. **S&P 500 is not available inside this widget**: the provider displays “This symbol is only available on TradingView.” Open source offers the provider page. Other index feeds have not been individually verified; the Indexes UI is complete, but embedded index quote coverage remains unresolved. No fabricated quote is substituted.
