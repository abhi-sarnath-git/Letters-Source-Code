// SDK adapter for sessions and encrypted text. Security checks fail closed; the portfolio composer is not wired here yet.

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

/// Development messaging boundary; the portfolio composer is still disconnected.
/// Letterbox grants authorize device login, not personal contact/group membership.
public actor LettersMessagingClient {
    private let endpoint: URL
    private let root: URL
    private let vault: any SessionVault
    private var client: Client?
    private var sessionDelegate: SessionDelegate?
    private var operationInProgress = false
    // Actors can re-enter at await. This gate keeps logout, sync and send from overlapping.
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
        // Keep the SDK store key separate from files and use cross-signed-device crypto policy.
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
        try await performSignIn(username: username, password: password)
    }

    /// Exchange an approved member's one-use Letterbox grant for a real device.
    /// The configured homeserver is never taken from the invitation or payload.
    public func signIn(using grant: LetterboxLoginGrant) async throws {
        try beginOperation(); defer { endOperation() }
        try grant.validate()
        try await performSignIn(username: grant.userID, password: grant.secret, expectedUserID: grant.userID)
    }

    private func performSignIn(username: String, password: String, expectedUserID: String? = nil) async throws {
        guard client == nil, try vault.load()?.credentials == nil else { throw MessagingError.alreadySignedIn }
        guard !username.isEmpty, !password.isEmpty else { throw MessagingError.invalidSession }
        let record = try StoredSession.fresh()
        try vault.save(record)
        let sdk = try await build(record)
        do {
            try await sdk.login(username: username, password: password, initialDeviceName: "Letters", deviceId: nil)
            // Refuse account substitution before exposing the authenticated client.
            if let expectedUserID, try sdk.userId() != expectedUserID { throw MessagingError.invalidSession }
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

    /// Restore the same device and encrypted store; never generate a replacement identity here.
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

    // Refresh encryption and audience before content access. This is a snapshot, not server-side contact authorization.
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
        // JSON encoding escapes arbitrary text; the SDK encrypts the resulting room message.
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

    /// The room timeline encrypts BOTH uploaded bytes and the message containing the media key.
    /// Generic Client.uploadMedia uploads plaintext and must never be used for private attachments.
    /// Completion is an SDK send completion, not a recipient delivery/read acknowledgement.
    public func sendAttachment(_ draft: EncryptedAttachmentDraft, roomID: String, recipients: Set<String>) async throws {
        try beginOperation(); defer { endOperation() }
        let room = try await guardedRoom(roomID, recipients: recipients)
        let timeline = try await room.timeline()
        // Re-check after timeline construction (an await); no upload occurs before this second guard.
        _ = try await guardedRoom(roomID, recipients: recipients)
        let size = UInt64(draft.bytes.count)
        let attachment: AttachmentKind
        switch draft.kind {
        case .voiceNote:
            attachment = .voice(audioInfo: AudioInfo(duration: draft.duration, size: size, mimetype: draft.mimeType), waveform: [])
        case .image, .gif:
            attachment = .image(imageInfo: ImageInfo(height: nil, width: nil, mimetype: draft.mimeType, size: size,
                thumbnailInfo: nil, thumbnailSource: nil, blurhash: nil, isAnimated: draft.kind == .gif), thumbnailSource: nil)
        case .video:
            attachment = .video(videoInfo: VideoInfo(duration: draft.duration, height: nil, width: nil,
                mimetype: draft.mimeType, size: size, thumbnailInfo: nil, thumbnailSource: nil, blurhash: nil), thumbnailSource: nil)
        case .file:
            attachment = .file(fileInfo: FileInfo(mimetype: draft.mimeType, size: size, thumbnailInfo: nil, thumbnailSource: nil))
        }
        let params = UploadParameters(source: .data(bytes: draft.bytes, filename: draft.filename),
            caption: nil, formattedCaption: nil, mentions: nil, inReplyTo: nil)
        let handle = try timeline.sendAttachment(params: params, attachment: attachment)
        try await withTaskCancellationHandler(operation: {
            try await handle.join()
            try Task.checkCancellation()
        }, onCancel: { handle.cancel() })
    }

    /// Read only a supported encrypted attachment in a still-approved encrypted room.
    /// SDK verifies the attachment hash and decrypts it; no URL downloader bypass exists.
    public func readAttachment(eventID: String, roomID: String, recipients: Set<String>) async throws -> ReceivedAttachment {
        try beginOperation(); defer { endOperation() }
        let sdk = try authenticated()
        let room = try await guardedRoom(roomID, recipients: recipients)
        let event = try await room.loadOrFetchEvent(eventId: eventID)
        guard case let .messageLike(content) = try event.content(),
              case let .roomMessage(type, _) = content else { throw AttachmentError.unsupportedEvent }
        let source: MediaSource, name: String, mime: String, size: UInt64?, kind: AttachmentType
        switch type {
        case let .audio(c):
            source = c.source; name = c.filename; mime = c.info?.mimetype ?? "application/octet-stream"
            size = c.info?.size; kind = c.voice == nil ? .file : .voiceNote
        case let .image(c):
            source = c.source; name = c.filename; mime = c.info?.mimetype ?? "application/octet-stream"
            size = c.info?.size; kind = mime == "image/gif" ? .gif : .image
        case let .video(c):
            source = c.source; name = c.filename; mime = c.info?.mimetype ?? "application/octet-stream"
            size = c.info?.size; kind = .video
        case let .file(c):
            source = c.source; name = c.filename; mime = c.info?.mimetype ?? "application/octet-stream"
            size = c.info?.size; kind = .file
        default: throw AttachmentError.unsupportedEvent
        }
        guard let size, size > 0, size <= UInt64(EncryptedAttachmentDraft.maximumBytes) else { throw AttachmentError.tooLarge }
        // Ruma serializes MediaSource as {"file": encryptedFile}; a {"url": ...} source is plaintext.
        guard let json = try JSONSerialization.jsonObject(with: Data(source.toJson().utf8)) as? [String: Any],
              let encrypted = json["file"] as? [String: Any],
              encrypted["key"] is [String: Any], encrypted["iv"] is String, encrypted["hashes"] is [String: Any],
              encrypted["v"] as? String == "v2" else { throw AttachmentError.notEncrypted }
        _ = try await guardedRoom(roomID, recipients: recipients)
        let folder = root.appendingPathComponent("incoming-media", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var privateFolder = folder
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try privateFolder.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)
        #endif
        // No persistent plaintext SDK cache. The owning handle removes its file when released.
        let file = try await sdk.getMediaFile(mediaSource: source, filename: nil, mimeType: mime, useCache: false, tempDir: folder.path)
        let path = try file.path()
        defer { _ = file }
        let count = (try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0
        guard count > 0, count <= EncryptedAttachmentDraft.maximumBytes, count == Int(size) else { throw AttachmentError.tooLarge }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        _ = try await guardedRoom(roomID, recipients: recipients)
        return ReceivedAttachment(kind: kind, filename: name, mimeType: mime, bytes: data, encryptedMediaURL: source.url())
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
