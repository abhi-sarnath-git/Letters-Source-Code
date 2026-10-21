import Foundation
import MatrixRustSDK

public enum MessagingError: Error, Equatable {
    case invalidServer, secureStorageUnavailable, noSession, alreadySignedIn
    case invalidSession, encryptionUnavailable, roomNotJoined, recipientsChanged
    case invalidMessage, notText, notInvited, operationInProgress
}

public enum LettersMessagingFoundation {
    public static let sdkRelease = "26.10.02"
}

/// Development messaging boundary. Not connected to the portfolio composer or
/// Letterbox admission yet; callers cannot treat Matrix membership as approval.
public actor LettersMessagingClient {
    private let endpoint: URL
    private let root: URL
    private let vault: any SessionVault
    private var client: Client?
    private var sessionDelegate: SessionDelegate?
    private var operationInProgress = false
    private func beginOperation() throws {
        guard !operationInProgress else { throw MessagingError.operationInProgress }
        operationInProgress = true
    }
    private func endOperation() { operationInProgress = false }

    public init(server: URL, storageDirectory: URL, keychainAccount: String) throws {
        endpoint = try Self.validateServer(server)
        root = storageDirectory
        vault = KeychainSessionVault(account: keychainAccount)
    }

    // Tests alone can address an isolated loopback Synapse. No public API or app
    // setting permits plaintext HTTP, disables TLS checks, or follows discovery.
    init(loopbackForTests server: URL, storageDirectory: URL, vault: any SessionVault) throws {
        guard server.scheme == "http", server.host == "127.0.0.1",
              server.user == nil, server.password == nil,
              server.query == nil, server.fragment == nil,
              server.path.isEmpty || server.path == "/" else { throw MessagingError.invalidServer }
        endpoint = server; root = storageDirectory; self.vault = vault
    }

    static func validateServer(_ url: URL) throws -> URL {
        guard url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { throw MessagingError.invalidServer }
        return url
    }

    private func build(_ record: StoredSession) async throws -> Client {
        guard record.storeKey.count == 32 else { throw MessagingError.secureStorageUnavailable }
        let base = root.appendingPathComponent(record.storeID.uuidString, isDirectory: true)
        let data = base.appendingPathComponent("data", isDirectory: true)
        let cache = base.appendingPathComponent("cache", isDirectory: true)
        for var directory in [root, base, data, cache] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                   attributes: [.posixPermissions: 0o700])
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
                                                   ofItemAtPath: directory.path)
            #endif
        }
        let delegate = SessionDelegate(vault: vault)
        let sdk = try await ClientBuilder()
            .homeserverUrl(url: endpoint.absoluteString)
            .disableWellKnownLookup(disableWellKnownLookup: true)
            .sqliteStore(config: SqliteStoreBuilder(dataPath: data.path, cachePath: cache.path).key(key: record.storeKey))
            .slidingSyncVersionBuilder(versionBuilder: .none)
            .autoEnableCrossSigning(autoEnableCrossSigning: true)
            .autoEnableBackups(autoEnableBackups: false)
            .roomKeyRecipientStrategy(strategy: .identityBasedStrategy)
            .decryptionSettings(decryptionSettings: DecryptionSettings(senderDeviceTrustRequirement: .crossSigned))
            .setSessionDelegate(sessionDelegate: delegate)
            .userAgent(userAgent: "Letters/0.1 (development)")
            .requestConfig(config: RequestConfig(retryLimit: 1, timeout: 15000, maxConcurrentRequests: 4, maxRetryTime: 20000))
            .build()
        sessionDelegate = delegate
        return sdk
    }

    public func signIn(username: String, password: String) async throws {
        try beginOperation(); defer { endOperation() }
        guard client == nil, try vault.load()?.credentials == nil else { throw MessagingError.alreadySignedIn }
        guard !username.isEmpty, !password.isEmpty else { throw MessagingError.invalidSession }
        let record = try StoredSession.fresh()
        try vault.save(record)
        let sdk = try await build(record)
        do {
            try await sdk.login(username: username, password: password, initialDeviceName: "Letters", deviceId: nil)
            sessionDelegate?.saveSessionInKeychain(session: try sdk.session())
            try sessionDelegate?.check()
            await sdk.encryption().waitForE2eeInitializationTasks()
            try await requireCrypto(sdk)
            client = sdk
        } catch {
            // If the network is unavailable logout can fail; keep the record so
            // the same session can be restored/revoked rather than losing it.
            do { try await sdk.logout(); try vault.remove() } catch { /* Keep retryable credentials. */ }
            throw error
        }
    }

    public func restore() async throws {
        try beginOperation(); defer { endOperation() }
        guard client == nil else { throw MessagingError.alreadySignedIn }
        guard let record = try vault.load(), let session = record.credentials else { throw MessagingError.noSession }
        guard URL(string: session.homeserver)?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ==
                endpoint.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) else {
            throw MessagingError.invalidSession
        }
        let sdk = try await build(record)
        try await sdk.restoreSession(session: session.sdk)
        await sdk.encryption().waitForE2eeInitializationTasks()
        try await requireCrypto(sdk)
        client = sdk
    }

    private func requireCrypto(_ sdk: Client) async throws {
        try sessionDelegate?.check()
        guard await sdk.encryption().curve25519Key() != nil,
              await sdk.encryption().ed25519Key() != nil else { throw MessagingError.encryptionUnavailable }
    }

    private func authenticated() throws -> Client {
        try sessionDelegate?.check()
        guard let client else { throw MessagingError.noSession }
        return client
    }

    public func userID() throws -> String { try authenticated().userId() }
    public func deviceID() throws -> String { try authenticated().deviceId() }

    public func syncOnce() async throws {
        try beginOperation(); defer { endOperation() }
        let sdk = try authenticated()
        _ = try await sdk.syncOnceV2(settings: SyncSettingsV2(timeoutMs: 0))
        try sessionDelegate?.check()
    }

    public func createEncryptedRoom(name: String, recipients: Set<String>) async throws -> String {
        try beginOperation(); defer { endOperation() }
        let sdk = try authenticated()
        try await requireCrypto(sdk)
        let own = try sdk.userId()
        guard !recipients.isEmpty, !recipients.contains(own), recipients.allSatisfy({ $0.hasPrefix("@") && $0.contains(":") }) else {
            throw MessagingError.recipientsChanged
        }
        return try await sdk.createRoom(request: CreateRoomParameters(
            name: name, isEncrypted: true, isDirect: recipients.count == 1,
            visibility: .private, preset: .privateChat, invite: recipients.sorted(),
            historyVisibilityOverride: .joined))
    }

    public func joinInvitation(roomID: String) async throws {
        try beginOperation(); defer { endOperation() }
        let sdk = try authenticated()
        guard let room = try sdk.getRoom(roomId: roomID), room.membership() == .invited else {
            throw MessagingError.notInvited
        }
        // Invited users cannot fetch full room state on a private homeserver.
        // Joining sends no message or room keys. Inspect state as a member and
        // leave on failure; guardedRoom still independently blocks every send.
        try await room.join()
        do {
            _ = try await sdk.syncOnceV2(settings: SyncSettingsV2(timeoutMs: 0))
            guard try await room.latestEncryptionState() == .encrypted else {
                throw MessagingError.encryptionUnavailable
            }
        } catch {
            try? await room.leave()
            throw error
        }
    }

    private func guardedRoom(_ roomID: String, recipients: Set<String>) async throws -> Room {
        let sdk = try authenticated()
        try await requireCrypto(sdk)
        guard let room = try sdk.getRoom(roomId: roomID), room.membership() == .joined else {
            throw MessagingError.roomNotJoined
        }
        guard try await room.latestEncryptionState() == .encrypted else { throw MessagingError.encryptionUnavailable }
        let own = try sdk.userId()
        guard !recipients.isEmpty, !recipients.contains(own),
              Set(try await room.activeHumanMemberIds()) == recipients.union([own]) else {
            throw MessagingError.recipientsChanged
        }
        return room
    }

    /// Returns a homeserver event ID, not a delivery/read acknowledgement.
    public func sendText(_ text: String, roomID: String, recipients: Set<String>) async throws -> String {
        try beginOperation(); defer { endOperation() }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 16000 else {
            throw MessagingError.invalidMessage
        }
        let room = try await guardedRoom(roomID, recipients: recipients)
        let json = try JSONSerialization.data(withJSONObject: ["msgtype": "m.text", "body": text])
        return try await room.sendRaw(eventType: "m.room.message", content: String(decoding: json, as: UTF8.self))
    }

    public func readText(eventID: String, roomID: String, recipients: Set<String>) async throws -> String {
        try beginOperation(); defer { endOperation() }
        let room = try await guardedRoom(roomID, recipients: recipients)
        let event = try await room.loadOrFetchEvent(eventId: eventID)
        if case let .messageLike(content) = try event.content(),
           case let .roomMessage(type, _) = content,
           case let .text(text) = type { return text.body }
        throw MessagingError.notText
    }

    /// Stops local access only. This does not revoke the device on the server.
    public func close() throws {
        try beginOperation(); defer { endOperation() }
        client = nil; sessionDelegate = nil
    }

    public func signOut() async throws {
        try beginOperation(); defer { endOperation() }
        let sdk = try authenticated()
        try await sdk.logout() // Keep credentials on failure so revocation can be retried.
        client = nil; sessionDelegate = nil
        try vault.remove()
        // Retain encrypted files for now; deletion/recovery UX is a release gate.
    }
}
