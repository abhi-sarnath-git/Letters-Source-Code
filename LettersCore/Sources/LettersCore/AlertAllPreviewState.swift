import Foundation

/// Local rehearsal state only. Never represents delivery, encryption or a real recipient.
public struct AlertAllRehearsal: Identifiable, Equatable {
    public let id: UUID
    public let note: String
    public let createdAt: Date
    public internal(set) var endedAt: Date?
}

public struct AlertAllPreviewState {
    public static let maximumNoteLength = 280
    public private(set) var latest: AlertAllRehearsal?
    public var hasActiveRehearsal: Bool { latest != nil && latest?.endedAt == nil }

    public init() {}

    /// UI must request explicit confirmation before calling this method.
    /// Returning false keeps existing state unchanged, including on duplicate taps.
    @discardableResult public mutating func createRehearsal(note: String, now: Date = Date()) -> Bool {
        let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hasActiveRehearsal, cleaned.count <= Self.maximumNoteLength else { return false }
        latest = AlertAllRehearsal(id: UUID(), note: cleaned.isEmpty ? "I need help. Please check on me." : cleaned,
                                   createdAt: now, endedAt: nil)
        return true
    }

    @discardableResult public mutating func endRehearsal(now: Date = Date()) -> Bool {
        guard hasActiveRehearsal, let createdAt = latest?.createdAt, now >= createdAt else { return false }
        latest?.endedAt = now
        return true
    }
}
