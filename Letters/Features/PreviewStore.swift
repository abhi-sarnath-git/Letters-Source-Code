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
    private var savedProfiles: [String: [PreviewConversation]] = [:]
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
                .init(text: "Coffee and a catch-up tomorrow? ☕", outgoing: false)
              ]),
        .init(id: "dad", name: "Dad", initials: "DA", group: false,
              unread: 0, time: "11:28", messages: [
                .init(text: "Made it home. Thanks for a lovely weekend.", outgoing: false),
                .init(text: "Already looking forward to the next one.", outgoing: true)
              ], favorite: true),
        .init(id: "weekend", name: "Weekend people", initials: "WP", group: true,
              unread: 0, time: "Yesterday", messages: [
                .init(text: "Same time, new adventure?", outgoing: false)
              ])
    ]

    func switchLetterboxProfile(_ id: String) {
        savedProfiles[letterbox.activeMemberID] = conversations
        do { try letterbox.selectProfile(id) } catch { return }
        conversations = savedProfiles[id] ?? []
        refreshLetterboxConversations()
    }

    func refreshLetterboxConversations() {
        let contacts = letterbox.contactIDs
        let groups = letterbox.groupMembers.filter { $0.value.contains(letterbox.activeMemberID) }
        conversations.removeAll { $0.group ? groups[$0.id] == nil : !contacts.contains($0.id) }
        for member in letterbox.members where contacts.contains(member.id) && !conversations.contains(where: { $0.id == member.id }) {
            conversations.append(.init(id: member.id, name: member.name, initials: String(member.name.prefix(2)).uppercased(),
                                       group: false, unread: 0, time: "Preview", messages: []))
        }
        for (id, _) in groups where !conversations.contains(where: { $0.id == id }) {
            conversations.append(.init(id: id, name: letterbox.groupNames[id] ?? "Group", initials: "GR",
                                       group: true, unread: 0, time: "Preview", messages: []))
        }
    }

    @discardableResult func acceptLetterbox(_ code: String, name: String, existingID: String?) throws -> LetterboxMember {
        let member = try letterbox.redeem(code, name: name, existingMemberID: existingID)
        refreshLetterboxConversations()
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
