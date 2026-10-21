import XCTest
@testable import LettersCore

final class WorldNewsTests: XCTestCase {
    func testRSSDecodesCDATAEntitiesDatesAndDeduplicates() throws {
        let xml = """
        <rss><channel><title>Channel title</title>
        <item><title><![CDATA[Example markets & companies]]></title><link>https://www.theguardian.com/business/example</link><pubDate>Wed, 21 Oct 2026 05:00:00 +0000</pubDate></item>
        <item><title>Duplicate</title><link>https://www.theguardian.com/business/example</link></item>
        <item><title>Oil &amp; energy</title><link>https://www.theguardian.com/business/energy-example</link></item>
        </channel></rss>
        """
        let items = try WorldNewsFeed.parse(Data(xml.utf8))
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "Example markets & companies")
        XCTAssertNotNil(items[0].publishedAt)
        XCTAssertEqual(items[1].title, "Oil & energy")
    }
    func testUnsafeLinksMalformedAndOversizedFeedsAreRejected() {
        for url in ["http://www.theguardian.com/world/story", "https://www.theguardian.com.evil.test/world/story", "javascript:alert(1)", "https://user:secret@www.theguardian.com/world/story"] {
            XCTAssertNil(WorldNewsFeed.safeArticleURL(url))
        }
        for xml in ["<rss>", "<rss><channel><item><title>Bad</title><link>https://evil.test</link></item></channel></rss>"] {
            XCTAssertThrowsError(try WorldNewsFeed.parse(Data(xml.utf8)))
        }
        XCTAssertThrowsError(try WorldNewsFeed.parse(Data(repeating: 65, count: WorldNewsFeed.maximumBytes+1)))
    }
    func testCategoriesHaveDistinctFixedHTTPSFeeds() {
        XCTAssertEqual(Set(WorldNewsCategory.allCases.map(\.feedURL)).count, 4)
        XCTAssertTrue(WorldNewsCategory.allCases.allSatisfy { $0.feedURL.scheme == "https" && $0.feedURL.host == "www.theguardian.com" })
    }
    func testLiveFeedsWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["LETTERS_CHECK_PUBLIC_FEEDS"] == "1" else { throw XCTSkip("Live public feed check is opt-in") }
        for category in WorldNewsCategory.allCases {
            let headlines = try await WorldNewsFeed.fetch(category)
            XCTAssertFalse(headlines.isEmpty)
            print("Verified public feed: \(category.rawValue), \(headlines.count) headlines; text omitted")
        }
    }
}
