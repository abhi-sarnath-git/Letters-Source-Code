// Bounded public RSS loading/parsing. Provider links are validated and external XML entities are disabled.

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum WorldNewsCategory: String, CaseIterable, Identifiable {
    case world = "World news", stocks = "Global stocks", oil = "Oil", crypto = "Crypto"
    public var id: String { rawValue }
    public var path: String {
        switch self {
        case .world: return "/world"
        case .stocks: return "/business/stock-markets"
        case .oil: return "/business/oil"
        case .crypto: return "/technology/cryptocurrencies"
        }
    }
    public var feedURL: URL { URL(string: "https://www.theguardian.com" + path + "/rss")! }
    public var sourceURL: URL { URL(string: "https://www.theguardian.com" + path)! }
}

public struct WorldHeadline: Identifiable, Equatable {
    public let title: String
    public let url: URL
    public let publishedAt: Date?
    public var id: String { url.absoluteString }
    public init(title: String, url: URL, publishedAt: Date?) {
        self.title = title; self.url = url; self.publishedAt = publishedAt
    }
}

public enum WorldNewsError: Error { case invalidResponse, tooLarge, invalidFeed, emptyFeed }

public enum WorldNewsFeed {
    public static let refreshInterval: TimeInterval = 300
    public static let maximumBytes = 1_000_000

    public static func safeArticleURL(_ value: String) -> URL? {
        guard value.utf8.count <= 2048, let components = URLComponents(string: value),
              components.scheme == "https", components.host == "www.theguardian.com",
              components.user == nil, components.password == nil, components.port == nil,
              !components.path.isEmpty else { return nil }
        return components.url
    }

    public static func parse(_ data: Data) throws -> [WorldHeadline] {
        guard data.count <= maximumBytes else { throw WorldNewsError.tooLarge }
        let delegate = FeedParser()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), !delegate.rejected else { throw WorldNewsError.invalidFeed }
        guard !delegate.headlines.isEmpty else { throw WorldNewsError.emptyFeed }
        return delegate.headlines
    }

    public static func fetch(_ category: WorldNewsCategory) async throws -> [WorldHeadline] {
        var request = URLRequest(url: category.feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForResource = 25
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        // Stream and cap the response, rather than trusting Content-Length or buffering an unbounded feed.
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url == category.feedURL,
              ["application/rss+xml", "application/xml", "text/xml"].contains(http.mimeType ?? ""),
              http.expectedContentLength <= Int64(maximumBytes) else { throw WorldNewsError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw WorldNewsError.tooLarge }
            data.append(byte)
        }
        return try parse(data)
    }
}

private final class FeedParser: NSObject, XMLParserDelegate {
    var headlines: [WorldHeadline] = []
    var rejected = false
    private var inItem = false
    private var field = ""
    private var title = "", link = "", date = ""
    private var depth = 0
    private var seen: Set<String> = []
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String:String]) {
        depth += 1
        guard depth < 32 else { rejected = true; parser.abortParsing(); return }
        if elementName == "item" { inItem = true; title = ""; link = ""; date = "" }
        field = elementName
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { append(string) }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) { append(string) }
    }
    private func append(_ string: String) {
        guard inItem else { return }
        switch field {
        case "title": if title.count < 2000 { title += string }
        case "link": if link.count < 4096 { link += string }
        case "pubDate": if date.count < 100 { date += string }
        default: break
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        defer { depth -= 1; field = "" }
        guard elementName == "item" else { return }
        inItem = false
        let cleanTitle = title.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard headlines.count < 20, !cleanTitle.isEmpty, cleanTitle.count <= 1000,
              let url = WorldNewsFeed.safeArticleURL(link.trimmingCharacters(in: .whitespacesAndNewlines)),
              seen.insert(url.absoluteString).inserted else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        headlines.append(.init(title: cleanTitle, url: url, publishedAt: formatter.date(from: date.trimmingCharacters(in: .whitespacesAndNewlines))))
    }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? { nil }
}
