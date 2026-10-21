import Foundation

public enum LetterboxError: Error, LocalizedError, Equatable {
    case invalidCode, unavailable, expired, nameRequired, memberRequired, forbidden, limit
    public var errorDescription: String? {
        switch self {
        case .invalidCode: return "That isn’t a Letters preview invitation. Scan a Letterbox preview QR code or enter its full code."
        case .unavailable: return "This invitation is unknown, revoked or already used. Ask for a new invitation."
        case .expired: return "This invitation has expired. Ask for a new invitation."
        case .nameRequired: return "Enter a sample name of 1–40 characters."
        case .memberRequired: return "Join Letters with a member invitation before accepting a group invitation."
        case .forbidden: return "Only an approved group administrator can create that invitation."
        case .limit: return "This preview has reached its invitation limit. Revoke an unused invitation first."
        }
    }
}

public struct LetterboxMember: Identifiable, Equatable {
    public let id: String
    public let name: String
}

public struct LetterboxInvitation: Identifiable, Equatable {
    public let id: UUID
    public let code: String
    public let groupID: String?
    public let expiresAt: Date
    public fileprivate(set) var usedBy: String?
    public fileprivate(set) var revoked = false
    public var qrPayload: String { "letters-preview://invite?code=\(code)" }
    public func isAvailable(at now: Date) -> Bool { !revoked && usedBy == nil && expiresAt > now }
}

/// An offline demonstration, never the authority for real account admission.
public struct LetterboxPreview {
    public static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    public static let ownerID = "preview-owner"
    public private(set) var members: [LetterboxMember] = [
        .init(id: ownerID, name: "You"), .init(id: "maya", name: "Maya"), .init(id: "dad", name: "Dad")
    ]
    public private(set) var invitations: [LetterboxInvitation] = []
    public private(set) var groupMembers: [String: Set<String>] = ["home": [ownerID], "weekend": [ownerID]]
    public private(set) var contactIDs: Set<String> = ["maya", "dad"]
    private let administeredGroupIDs: Set<String> = ["home", "weekend"]
    public init() {}

    public static func canonicalCode(_ input: String) throws -> String {
        guard input.utf8.count <= 512 else { throw LetterboxError.invalidCode }
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.contains("://") {
            guard let url = URLComponents(string: value), url.scheme == "letters-preview", url.host == "invite",
                  url.path.isEmpty, url.user == nil, url.password == nil, url.port == nil, url.fragment == nil,
                  let items = url.queryItems, items.count == 1, items[0].name == "code", let code = items[0].value else {
                throw LetterboxError.invalidCode
            }
            value = code
        }
        let compact = value.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard compact.hasPrefix("DEMOLBOX") else { throw LetterboxError.invalidCode }
        let secret = String(compact.dropFirst(8))
        guard secret.count == 32, secret.allSatisfy({ alphabet.contains($0) }) else { throw LetterboxError.invalidCode }
        let chars = Array(secret)
        return "DEMO-LBOX-" + stride(from: 0, to: 32, by: 8).map { String(chars[$0..<$0+8]) }.joined(separator: "-")
    }

    @discardableResult public mutating func issue(secret: String, groupID: String? = nil, now: Date = Date()) throws -> LetterboxInvitation {
        if let groupID, !administeredGroupIDs.contains(groupID) { throw LetterboxError.forbidden }
        guard invitations.filter({ $0.isAvailable(at: now) }).count < 20 else { throw LetterboxError.limit }
        let code = try Self.canonicalCode("DEMO-LBOX-" + secret)
        guard !invitations.contains(where: { $0.code == code }) else { throw LetterboxError.unavailable }
        let invite = LetterboxInvitation(id: UUID(), code: code, groupID: groupID, expiresAt: now.addingTimeInterval(86400))
        invitations.insert(invite, at: 0)
        return invite
    }

    public func inspect(_ input: String, now: Date = Date()) throws -> LetterboxInvitation {
        let code = try Self.canonicalCode(input)
        guard let invite = invitations.first(where: { $0.code == code }), !invite.revoked, invite.usedBy == nil else {
            throw LetterboxError.unavailable
        }
        guard invite.expiresAt > now else { throw LetterboxError.expired }
        return invite
    }

    @discardableResult public mutating func redeem(_ input: String, name: String, existingMemberID: String? = nil,
                                                  now: Date = Date()) throws -> LetterboxMember {
        let invite = try inspect(input, now: now)
        let member: LetterboxMember
        if let existingMemberID {
            guard let existing = members.first(where: { $0.id == existingMemberID }), existing.id != Self.ownerID else {
                throw LetterboxError.memberRequired
            }
            member = existing
        } else {
            guard invite.groupID == nil else { throw LetterboxError.memberRequired }
            let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, cleaned.count <= 40, !cleaned.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw LetterboxError.nameRequired
            }
            member = .init(id: UUID().uuidString, name: cleaned)
            members.append(member)
        }
        if let group = invite.groupID { groupMembers[group, default: []].insert(member.id) }
        else { contactIDs.insert(member.id) }
        let index = invitations.firstIndex(where: { $0.id == invite.id })!
        invitations[index].usedBy = member.id
        return member
    }

    public mutating func revoke(_ id: UUID) {
        guard let index = invitations.firstIndex(where: { $0.id == id }), invitations[index].usedBy == nil else { return }
        invitations[index].revoked = true
    }
}
