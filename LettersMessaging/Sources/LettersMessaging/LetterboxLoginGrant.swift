import Foundation

/// A short-lived credential exchanged for a device session, not a permanent
/// password or permission to join a chat. Never persist it or include it in logs.
public struct LetterboxLoginGrant: Decodable, CustomStringConvertible, CustomDebugStringConvertible {
    public let userID: String
    let secret: String
    let expiresAt: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id", secret = "login_grant", expiresAt = "expires_at"
    }

    // Debug descriptions intentionally omit both the secret and private user ID.
    public var description: String { "LetterboxLoginGrant(<redacted>)" }
    public var debugDescription: String { description }

    func validate(now: Date = Date()) throws {
        guard userID.hasPrefix("@letters_"), userID.contains(":"), userID.utf8.count < 300,
              secret.hasPrefix("LLOGIN-"), secret.utf8.count == 50,
              secret.dropFirst(7).allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }),
              expiresAt > now.timeIntervalSince1970, expiresAt <= now.timeIntervalSince1970 + 120 else {
            throw MessagingError.invalidSession
        }
    }
}
