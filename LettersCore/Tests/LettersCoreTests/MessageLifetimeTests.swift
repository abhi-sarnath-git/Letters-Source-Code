import XCTest
@testable import LettersCore
final class MessageLifetimeTests:XCTestCase {
    func testExactChoicesAndElapsedIntervals() throws {
        XCTAssertEqual(MessageLifetime.allCases.map(\.rawValue),["1 hour","12 hours","1 day","7 days","a month","six months","one year","never"])
        let sent=Date(timeIntervalSince1970:1000)
        for (policy,seconds) in [(MessageLifetime.hour,3600.0),(.halfDay,43200),(.day,86400),(.week,604800)] {
            let expiry=try XCTUnwrap(policy.expiry(after:sent)); XCTAssertEqual(expiry.timeIntervalSince(sent),seconds)
            XCTAssertFalse(MessageLifetime.hasExpired(expiry,at:expiry.addingTimeInterval(-0.001)))
            XCTAssertTrue(MessageLifetime.hasExpired(expiry,at:expiry))
        }
        XCTAssertNil(MessageLifetime.never.expiry(after:sent))
        XCTAssertFalse(MessageLifetime.hasExpired(nil,at:.distantFuture))
    }
    func testCalendarMonthsAndLeapYear() throws {
        let formatter=ISO8601DateFormatter()
        let sent=try XCTUnwrap(formatter.date(from:"2024-08-31T10:00:00Z"))
        XCTAssertEqual(MessageLifetime.month.expiry(after:sent),formatter.date(from:"2024-09-30T10:00:00Z"))
        XCTAssertEqual(MessageLifetime.halfYear.expiry(after:sent),formatter.date(from:"2025-02-28T10:00:00Z"))
        let leap=try XCTUnwrap(formatter.date(from:"2024-02-29T10:00:00Z"))
        XCTAssertEqual(MessageLifetime.year.expiry(after:leap),formatter.date(from:"2025-02-28T10:00:00Z"))
    }
}
