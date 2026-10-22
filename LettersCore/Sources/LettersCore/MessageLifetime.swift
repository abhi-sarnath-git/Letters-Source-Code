// Calendar-aware disappearing-message policy. Transport and server redaction are separate responsibilities.
import Foundation

public enum MessageLifetime: String, CaseIterable, Identifiable, Codable {
    case hour = "1 hour", halfDay = "12 hours", day = "1 day", week = "7 days"
    case month = "a month", halfYear = "six months", year = "one year", never = "never"
    public var id: String { rawValue }
    /// Start at message creation/send time, not read time. Calendar units use UTC for consistent devices.
    public func expiry(after sentAt: Date) -> Date? {
        var calendar=Calendar(identifier:.gregorian); calendar.timeZone=TimeZone(secondsFromGMT:0)!
        switch self {
        case .hour: return sentAt.addingTimeInterval(3600)
        case .halfDay: return sentAt.addingTimeInterval(43200)
        case .day: return sentAt.addingTimeInterval(86400)
        case .week: return sentAt.addingTimeInterval(7*86400)
        case .month: return calendar.date(byAdding:.month,value:1,to:sentAt)
        case .halfYear: return calendar.date(byAdding:.month,value:6,to:sentAt)
        case .year: return calendar.date(byAdding:.year,value:1,to:sentAt)
        case .never: return nil
        }
    }
    public static func hasExpired(_ expiry: Date?, at now: Date) -> Bool { expiry.map { now >= $0 } ?? false }
}
