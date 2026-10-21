// Home-menu-only market browser. Provider widgets display quotes; Letters never
// scrapes prices, embeds API secrets, or passes chat/account data to the provider.
import SwiftUI
import WebKit
import SafariServices

enum MarketSection: String, CaseIterable, Identifiable {
    case stocks = "Stocks", oil = "Oil", bitcoin = "Bitcoin"
    var id: String { rawValue }
    var instruments: [MarketInstrument] {
        switch self {
        case .stocks: return [
            .init(id: "NASDAQ:AAPL", name: "Apple", detail: "United States · USD"),
            .init(id: "NASDAQ:MSFT", name: "Microsoft", detail: "United States · USD"),
            .init(id: "XETR:SAP", name: "SAP", detail: "Germany · EUR · end-of-day feed"),
            .init(id: "ASX:BHP", name: "BHP", detail: "Australia · AUD · delayed feed")]
        case .oil: return [
            .init(id: "TVC:USOIL", name: "WTI crude", detail: "Indicative CFD · USD per barrel"),
            .init(id: "TVC:UKOIL", name: "Brent crude", detail: "Indicative CFD · USD per barrel")]
        case .bitcoin: return [.init(id: "COINBASE:BTCUSD", name: "Bitcoin / US dollar", detail: "Coinbase · BTC/USD · venue-specific price")]
        }
    }
    var note: String {
        switch self {
        case .stocks: return "A starting selection across US, German and Australian markets. Prices stay in each listing’s currency; some feeds are delayed or end-of-day."
        case .oil: return "WTI and Brent are indicative TradingView CFD quotes, not physical spot prices or exchange futures settlements."
        case .bitcoin: return "This is Coinbase’s BTC/USD market, not a guaranteed price across every crypto exchange."
        }
    }
}

struct MarketInstrument: Identifiable {
    let id: String
    let name: String
    let detail: String
    var sourceURL: URL { URL(string: "https://www.tradingview.com/symbols/" + id.replacingOccurrences(of: ":", with: "-") + "/")! }
}

struct MarketsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var section = MarketSection.stocks
    @State private var selectedID = "NASDAQ:AAPL"
    @State private var visible = false
    @State private var reloadID = UUID()
    @State private var article: MarketArticle?
    private var sample: Bool { ProcessInfo.processInfo.arguments.contains("--preview-markets") }
    private var selected: MarketInstrument { section.instruments.first(where: { $0.id == selectedID }) ?? section.instruments[0] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A wider orbit.").font(.title2.weight(.semibold))
                        Text("Stocks, energy & Bitcoin").foregroundStyle(LettersTheme.secondary)
                    }
                    Spacer()
                    OrbitalEarth(active: visible && scenePhase == .active).frame(width: 58, height: 58)
                }
                Picker("Market category", selection: $section) {
                    ForEach(MarketSection.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                Picker("Instrument", selection: $selectedID) {
                    ForEach(section.instruments) { Text($0.name).tag($0.id) }
                }.pickerStyle(.menu).tint(LettersTheme.accent)
                VStack(alignment: .leading, spacing: 7) {
                    Text(selected.name).font(.headline)
                    Text(selected.detail).font(.caption).foregroundStyle(LettersTheme.secondary)
                }
                if sample {
                    // Portfolio mode is deliberately offline and visibly labelled.
                    // Fictional values must never appear as a failed-feed fallback.
                    VStack(alignment: .leading, spacing: 14) {
                        Label("SAMPLE · NOT CURRENT PRICES", systemImage: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(LettersTheme.accent)
                        Text(section == .stocks ? (selected.id == "XETR:SAP" ? "EUR 153.25" : selected.id == "ASX:BHP" ? "AUD 153.25" : "USD 153.25") : section == .oil ? "USD 78.90 / barrel" : "USD 67,890.12")
                            .font(.largeTitle.weight(.medium)).monospacedDigit()
                        Text("Fictional portfolio data. Normal mode loads the provider’s quote and chart.")
                            .font(.footnote).foregroundStyle(LettersTheme.secondary)
                    }.padding(24).frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
                        .background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                } else if visible && scenePhase == .active {
                    // Destroy the provider view when hidden/backgrounded. Its data
                    // store is ephemeral and has no connection to Letters sessions.
                    MarketWidget(instrument: selected, openLink: { article = MarketArticle(url: $0) })
                        .id(selected.id + reloadID.uuidString).frame(height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Text("Market view paused").frame(maxWidth: .infinity, minHeight: 180)
                }
                Text(section.note).font(.footnote).foregroundStyle(LettersTheme.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Link("Quotes and charts by TradingView ↗", destination: selected.sourceURL)
                    Text("Provider data may be delayed, end-of-day, unavailable or paused when a market is closed. Check the quote’s own timestamp/status. Opening this screen connects to TradingView; chat data is not shared.")
                        .font(.caption).foregroundStyle(LettersTheme.secondary)
                    HStack {
                        Button("Reload prices") { reloadID = UUID() }.disabled(sample)
                        Spacer()
                        Button("Open source") { article = MarketArticle(url: selected.sourceURL) }
                    }.font(.subheadline).frame(minHeight: 44)
                    Text("If the quote does not appear, reload or open its source. Letters does not substitute saved or sample prices in normal mode.")
                        .font(.caption).foregroundStyle(LettersTheme.secondary)
                }
            }.padding(22)
        }.background(OrbitBackdrop()).navigationTitle("Markets").navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .onAppear { visible = true }
            .onDisappear { visible = false }
            .onChange(of: section) { newValue in selectedID = newValue.instruments[0].id }
            .sheet(item: $article) { MarketSafari(url: $0.url) }
    }
}

private struct MarketArticle: Identifiable { let id = UUID(); let url: URL }
private struct MarketSafari: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// Use the official configurable widget with its attribution intact. Only fixed
// catalogue symbols enter this HTML; no user-entered script or native JS bridge.
private struct MarketWidget: UIViewRepresentable {
    let instrument: MarketInstrument
    let openLink: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(openLink: openLink) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        let settings: [String: Any] = [
            "symbols": [[instrument.name, instrument.id + "|1D"]],
            "colorTheme": "dark", "isTransparent": false, "autosize": true,
            "width": "100%", "height": "100%", "locale": "en", "chartOnly": false,
            "hideMarketStatus": false, "hideDateRanges": false, "dateRanges": ["1d|1", "1m|30", "12m|1D"]]
        // Serialize configuration rather than interpolating arbitrary text into JS.
        let json = String(decoding: try! JSONSerialization.data(withJSONObject: settings, options: [.sortedKeys]), as: UTF8.self)
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta name="referrer" content="no-referrer">
        <style>html,body{margin:0;background:#101826;color:white;height:100%;font-family:-apple-system,sans-serif}
        .tradingview-widget-container{height:100%;width:100%}.tradingview-widget-container__widget{height:calc(100% - 32px)}
        .tradingview-widget-copyright{padding:6px;font-size:12px}a{color:#7ae7e7}</style></head><body>
        <div class="tradingview-widget-container"><div class="tradingview-widget-container__widget"></div>
        <div class="tradingview-widget-copyright"><a href="\(instrument.sourceURL.absoluteString)" rel="noopener nofollow" target="_blank">Market prices</a> by TradingView</div>
        <script src="https://s3.tradingview.com/external-embedding/embed-widget-symbol-overview.js" async>\(json)</script>
        </div></body></html>
        """
        web.loadHTMLString(html, baseURL: nil)
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading(); uiView.navigationDelegate = nil; uiView.uiDelegate = nil
        uiView.loadHTMLString("", baseURL: nil)
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let openLink: (URL) -> Void
        init(openLink: @escaping (URL) -> Void) { self.openLink = openLink }
        private func allowed(_ url: URL) -> Bool {
            guard url.scheme == "https", let host = url.host?.lowercased(), url.user == nil, url.password == nil else { return false }
            return ["tradingview.com", "tradingview-widget.com"].contains { host == $0 || host.hasSuffix("." + $0) }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if url.absoluteString == "about:blank" { decisionHandler(.allow); return }
            guard allowed(url) else { decisionHandler(.cancel); return }
            if navigationAction.navigationType == .linkActivated {
                openLink(url); decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url, allowed(url), navigationAction.navigationType == .linkActivated { openLink(url) }
            return nil
        }
    }
}
