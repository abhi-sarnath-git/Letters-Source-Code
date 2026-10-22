// A real SDK-backed development surface, kept separate from portfolio conversations.
// No SMS, public registration, contact approval or identity-verification claims.
import SwiftUI
import CryptoKit
import LettersMessaging

@MainActor
final class DevelopmentChatModel: ObservableObject {
    @Published var connected = false
    @Published var busy = false
    @Published var messages: [ConversationMessage] = []
    @Published var status = "No development session connected."
    @Published var ownID = ""
    @Published var roomID = ""
    @Published var peerID = ""
    private var client: LettersMessagingClient?
    private var configuredServer: URL?
    var displayEnabled = true

    // Bind the Keychain record and encrypted store to one explicit HTTPS server.
    // Changing servers cannot restore another server's device credentials.
    func connect(server: String, grantJSON: String?, restoring: Bool) async {
        guard !busy, !connected else { return }
        busy = true; defer { busy = false }
        do {
            guard let url = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw MessagingError.invalidServer
            }
            if configuredServer != url, let client {
                try await client.close()
                self.client = nil
            }
            if client == nil {
                let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
                let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: true).appendingPathComponent("DevelopmentMessaging/" + key)
                client = try LettersMessagingClient(server: url, storageDirectory: root,
                    keychainAccount: "letters.development." + key)
                configuredServer = url
            }
            guard let client else { return }
            if restoring { try await client.restore() }
            else {
                let data = Data((grantJSON ?? "").utf8)
                guard data.count <= 4096 else { throw MessagingError.invalidSession }
                try await client.signIn(using: JSONDecoder().decode(LetterboxLoginGrant.self, from: data))
            }
            ownID = try await client.userID()
            connected = true
            status = "Development session connected. Contact identity is not yet verified."
        } catch { status = Self.safeMessage(error) }
    }

    func createRoom() async {
        await perform { client in
            self.roomID = try await client.createEncryptedRoom(name: "Letters development chat", recipients: [self.peerID])
            self.status = "Encrypted invitation created. Share the room ID with the development recipient."
        }
    }

    func joinRoom() async {
        await perform { client in
            try await client.syncOnce()
            try await client.joinInvitation(roomID: self.roomID)
            self.status = "Invitation accepted; refresh after both accounts have joined."
        }
    }

    func refresh() async {
        guard !roomID.isEmpty, !peerID.isEmpty else { return }
        await perform { client in
            try await client.syncOnce()
            let updated = try await client.conversation(roomID: self.roomID, recipients: [self.peerID])
            self.messages = self.displayEnabled ? updated : []
            self.status = "History refreshed. Server acceptance does not mean delivered or read."
        }
    }

    func send(_ text: String) async -> Bool {
        guard connected, !busy, let client else { return false }
        busy = true; defer { busy = false }
        do {
            _ = try await client.sendText(text, roomID: roomID, recipients: [peerID])
            status = "Server accepted encrypted message."
            return true
        } catch {
            status = Self.safeMessage(error) + " A failed response can have an uncertain outcome; refresh before retrying."
            return false
        }
    }

    func signOut() async {
        await perform { client in
            try await client.signOut()
            self.client = nil; self.connected = false; self.ownID = ""
            self.roomID = ""; self.peerID = ""; self.messages = []
            self.status = "Device session revoked on the server."
        }
    }

    private func perform(_ action: (LettersMessagingClient) async throws -> Void) async {
        guard connected, !busy, let client else { return }
        busy = true; defer { busy = false }
        do { try await action(client) }
        catch { messages = []; status = Self.safeMessage(error) }
    }

    // Never place raw SDK errors, tokens or server response bodies in UI/log output.
    private static func safeMessage(_ error: Error) -> String {
        switch error as? MessagingError {
        case .invalidServer: return "Use an explicitly trusted HTTPS homeserver, without credentials or a path."
        case .recipientsChanged: return "Chat paused: the current audience does not match the selected contact."
        case .encryptionUnavailable: return "Chat paused: required encryption is unavailable."
        case .secureStorageUnavailable: return "Unlock the device and retry secure storage."
        case .noSession: return "No saved session exists for this server."
        case .alreadySignedIn: return "A saved device session exists. Restore it instead of creating another identity."
        case .notInvited: return "No matching invitation is available. Refresh and check the room ID."
        default: return "The operation could not complete. Check the development server, invitation and connection."
        }
    }
}

struct DevelopmentChatView: View {
    @StateObject private var model = DevelopmentChatModel()
    @Environment(\.scenePhase) private var phase
    @State private var server = ""
    @State private var grant = ""
    @State private var draft = ""

    var body: some View {
        Form {
            Section {
                Label("Development accounts only", systemImage: "hammer.fill").foregroundStyle(LettersTheme.accent)
                Text("Real encrypted transport. Use synthetic messages on a trusted development server. Member room policy, contact verification and recovery are still unfinished.")
            }
            Section("Secure connection") {
                TextField("Trusted HTTPS server", text: $server).keyboardType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().disabled(model.connected || model.busy)
                if !model.connected {
                    SecureField("One-use Letterbox login grant JSON", text: $grant)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Connect development account") {
                        let supplied = grant; grant = ""
                        Task { await model.connect(server: server, grantJSON: supplied, restoring: false) }
                    }.disabled(grant.isEmpty || server.isEmpty || model.busy)
                    Button("Restore saved device session") {
                        Task { await model.connect(server: server, grantJSON: nil, restoring: true) }
                    }.disabled(server.isEmpty || model.busy)
                } else {
                    Text(model.ownID).font(.caption).textSelection(.enabled)
                    Button("Revoke this device session", role: .destructive) { Task { await model.signOut() } }
                        .disabled(model.busy)
                }
            }
            if model.connected {
                Section("Development conversation") {
                    TextField("Recipient Matrix ID", text: $model.peerID)
                    TextField("Room ID", text: $model.roomID)
                    Button("Create encrypted invitation") { Task { await model.createRoom() } }
                        .disabled(model.peerID.isEmpty)
                    Button("Accept invitation") { Task { await model.joinRoom() } }.disabled(model.roomID.isEmpty)
                    Button("Refresh encrypted history") { Task { await model.refresh() } }
                    Text("Only the selected recipient and this account may be active members. Changing these fields clears visible history.")
                        .font(.caption)
                }.textInputAutocapitalization(.never).autocorrectionDisabled().disabled(model.busy)
                Section("Encrypted messages") {
                    if model.messages.isEmpty { Text("No messages loaded.").foregroundStyle(.secondary) }
                    ForEach(model.messages) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message.isOwn ? "You" : "Selected contact").font(.caption).foregroundStyle(LettersTheme.accent)
                            Text(message.body ?? "Encrypted attachment, unsupported event or unavailable content")
                        }.padding(.vertical, 4)
                    }
                    TextField("Development message", text: $draft, axis: .vertical)
                    Button("Send encrypted message") {
                        let text = draft
                        Task {
                            if await model.send(text) { if draft == text { draft = "" }; await model.refresh() }
                        }
                    }.disabled(model.busy || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.roomID.isEmpty || model.peerID.isEmpty)
                }
            }
            Section("Connection status") {
                if model.busy { ProgressView() }
                Text(model.status).font(.footnote).accessibilityLabel("Connection status: " + model.status)
                Text("Refresh is manual. No background sync, push notifications, automatic retries or remote self-destruct is enabled here. Attachments are the next native integration step.")
                    .font(.caption)
            }
        }
        .scrollContentBackground(.hidden).background(LettersTheme.background)
        .navigationTitle("Encrypted development chat").navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .onChange(of: model.roomID) { _ in model.messages = []; draft = "" }
        .onChange(of: model.peerID) { _ in model.messages = []; draft = "" }
        .onChange(of: phase) { value in
            model.displayEnabled = value == .active
            if value != .active { grant = ""; draft = ""; model.messages = [] }
        }
        .overlay { if phase != .active { LettersTheme.background.ignoresSafeArea().overlay(Text("Letters locked")) } }
        .onAppear { model.displayEnabled = phase == .active }
        .onDisappear { model.displayEnabled = false; grant = ""; draft = ""; model.messages = [] }
    }
}
