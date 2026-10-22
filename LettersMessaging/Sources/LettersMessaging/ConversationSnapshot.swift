import Foundation
import MatrixRustSDK

/// Plaintext exists in memory only after the SDK has applied its decryption policy.
public struct ConversationMessage: Identifiable, Sendable {
    public let id: String
    public let sender: String
    public let body: String?
    public let isOwn: Bool
}

/// Retains SDK ordering, including virtual rows, so diff indices remain meaningful.
/// SDK callbacks can arrive off the main thread; no message text is logged here.
final class ConversationSnapshot: TimelineListener, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [TimelineItem] = []
    private var valid = true

    func onUpdate(diff: [TimelineDiff]) {
        lock.lock(); defer { lock.unlock() }
        for change in diff {
            switch change {
            case .reset(let values): items = values; valid = true
            case .clear: items.removeAll(); valid = true
            case .append(let values): items.append(contentsOf: values)
            case .pushFront(let value): items.insert(value, at: 0)
            case .pushBack(let value): items.append(value)
            case .popFront: if !items.isEmpty { items.removeFirst() } else { valid = false }
            case .popBack: if !items.isEmpty { items.removeLast() } else { valid = false }
            case .insert(let index, let value):
                if Int(index) <= items.count { items.insert(value, at: Int(index)) } else { valid = false }
            case .set(let index, let value):
                if Int(index) < items.count { items[Int(index)] = value } else { valid = false }
            case .remove(let index):
                if Int(index) < items.count { items.remove(at: Int(index)) } else { valid = false }
            case .truncate(let length):
                if Int(length) <= items.count { items = Array(items.prefix(Int(length))) } else { valid = false }
            }
        }
    }

    // Human verification is explicitly unfinished in this development screen.
    // Other trust warnings, including plaintext injected into an encrypted room,
    // must never be presented as an encrypted conversation message.
    static func permitsDevelopmentDisplay(_ shield: ShieldState) -> Bool {
        switch shield {
        case .none: return true
        case .red(let code), .grey(let code): return code == .unverifiedIdentity
        }
    }

    func events() throws -> [EventTimelineItem] {
        lock.lock(); defer { lock.unlock() }
        guard valid else { throw MessagingError.invalidSession }
        return items.suffix(200).compactMap { $0.asEvent() }
    }
}
