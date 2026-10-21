import SwiftUI
import LettersMessaging

struct MessagingFoundationView: View {
    var body: some View {
        List {
            Section {
                Label("Messaging is being built", systemImage: "lock.shield")
                    .font(.headline).foregroundStyle(LettersTheme.accent)
                Text("The sample chats cannot send private messages. Keep using fictional content in this preview.")
            }
            Section("Encryption foundation") {
                LabeledContent("Matrix SDK", value: LettersMessagingFoundation.sdkRelease)
                Text("The development client requires encrypted rooms and uses the system Keychain for its session credentials. It blocks sending if the room is unencrypted or its audience changes.")
                Text("Cross-signed devices are required. Cross-signing alone does not verify that a contact is the person you expect.")
            }
            Section("Before private chats are available") {
                Label("Connect Letterbox invitations to real accounts", systemImage: "envelope.open")
                Label("Add device verification and recovery", systemImage: "key")
                Label("Connect live chats and encrypted attachments", systemImage: "bubble.left.and.bubble.right")
                Label("Verify notifications and offline behaviour", systemImage: "bell")
            }
            Section("Separate features still needed") {
                Text("Voice calls and Alert All remain previews. Neither sends anything or contacts anyone.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(LettersTheme.background)
        .navigationTitle("Messaging progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}
