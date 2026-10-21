import SwiftUI

struct PreviewMessage: Identifiable {
    let id = UUID()
    var text: String
    let outgoing: Bool
    var sticker: PreviewSticker? = nil
}

struct PreviewConversation: Identifiable {
    let id: String
    let name: String
    let initials: String
    let group: Bool
    var unread: Int
    let time: String
    var messages: [PreviewMessage]
    var favorite = false
    var archived = false
    var lastMessage: String { messages.last?.text ?? "Start a conversation" }
}

/// Sample state only. No networking, credentials, delivery receipts, or encryption claims.
@MainActor final class PreviewStore: ObservableObject {
    @Published var letterbox = LetterboxPreview()
    @Published var alertAll = AlertAllPreviewState()
    @Published var stickers = PreviewSticker.orbitPack
    @Published var conversations: [PreviewConversation] = [
        .init(id: "home", name: "The home team", initials: "HT", group: true,
              unread: 3, time: "Now", messages: [
                .init(text: "Sunday dinner at ours? Everyone is welcome 🌿", outgoing: false),
                .init(text: "I'll bring dessert. What time?", outgoing: true),
                .init(text: "Six sounds perfect. See you all there!", outgoing: false)
              ], favorite: true),
        .init(id: "maya", name: "Maya", initials: "MA", group: false,
              unread: 1, time: "12:42", messages: [
                .init(text: "This little corner of the internet feels like home.", outgoing: false),
                .init(text: "That's exactly what I wanted Letters to feel like.", outgoing: true),
                .init(te…158 tokens truncated…enture?", outgoing: false)
              ])
    ]

    @discardableResult func acceptLetterbox(_ code: String, name: String, existingID: String?) throws -> LetterboxMember {
        let invitation = try letterbox.inspect(code)
        let member = try letterbox.redeem(code, name: name, existingMemberID: existingID)
        if invitation.groupID == nil && !conversations.contains(where: { $0.id == member.id }) {
            let initials = String(member.name.prefix(2)).uppercased()
            conversations.insert(.init(id: member.id, name: member.name, initials: initials, group: false,
                                       unread: 0, time: "Preview", messages: []), at: 0)
        }
        return member
    }

    func appendPreview(_ text: String, to id: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].messages.append(.init(text: cleaned, outgoing: true))
    }

    func markRead(_ id: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].unread = 0
    }

    func appendSticker(_ sticker: PreviewSticker, to id: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].messages.append(.init(text: "Sticker: \(sticker.name)", outgoing: true, sticker: sticker))
    }
}
