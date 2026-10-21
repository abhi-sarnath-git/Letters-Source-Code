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
