import XCTest
import Foundation
import MatrixRustSDK
@testable import LettersMessaging

final class MemoryVault: SessionVault, @unchecked Sendable {
    private let lock = NSLock()
    private var record: StoredSession?
    var rejectWrites = false
    func load() throws -> StoredSession? { lock.lock(); defer { lock.unlock() }; return record }
    func save(_ value: StoredSession) throws {
        lock.lock(); defer { lock.unlock() }
        if rejectWrites { throw MessagingError.secureStorageUnavailable }
        record = value
    }
    func remove() throws { lock.lock(); defer { lock.unlock() }; record = nil }
}

final class MessagingTests: XCTestCase {
    func testProductionEndpointsRequireHTTPSAndNoEmbeddedSecrets() throws {
        for value in ["http://example.com", "https://user:secret@example.com", "https://example.com/?token=x",
                      "https://example.com/#secret", "https://example.com/path"] {
            XCTAssertThrowsError(try LettersMessagingClient.validateServer(URL(string: value)!))
        }
        XCTAssertNoThrow(try LettersMessagingClient.validateServer(URL(string: "https://letters.example:8448")!))
    }

    func testLoginGrantExpiryValidationAndRedactedDebugOutput() throws {
        let now = Date(timeIntervalSince1970: 1000)
        func decode(expiry: Double, secret: String) throws -> LetterboxLoginGrant {
            let json: [String: Any] = ["user_id": "@letters_" + String(repeating: "a", count: 32) + ":letters.test",
                                       "login_grant": secret, "expires_at": expiry]
            return try JSONDecoder().decode(LetterboxLoginGrant.self, from: JSONSerialization.data(withJSONObject: json))
        }
        let secret = "LLOGIN-" + String(repeating: "a", count: 43)
        let good = try decode(expiry: 1060, secret: secret)
        XCTAssertNoThrow(try good.validate(now: now))
        XCTAssertFalse(String(describing: good).contains(secret))
        XCTAssertFalse(String(reflecting: good).contains(secret))
        XCTAssertThrowsError(try decode(expiry: 1000, secret: secret).validate(now: now))
        XCTAssertThrowsError(try decode(expiry: 1300, secret: secret).validate(now: now))
        XCTAssertThrowsError(try decode(expiry: 1060, secret: "bad").validate(now: now))
    }

    func testDevelopmentDisplayRejectsPlaintextAndUnsafeTrustWarnings() {
        XCTAssertTrue(ConversationSnapshot.permitsDevelopmentDisplay(.none))
        XCTAssertTrue(ConversationSnapshot.permitsDevelopmentDisplay(.red(code: .unverifiedIdentity)))
        for code in [TimelineEventShieldStateCode.sentInClear, .mismatchedSender, .unknownDevice,
                     .unsignedDevice, .verificationViolation, .authenticityNotGuaranteed] {
            XCTAssertFalse(ConversationSnapshot.permitsDevelopmentDisplay(.red(code: code)))
            XCTAssertFalse(ConversationSnapshot.permitsDevelopmentDisplay(.grey(code: code)))
        }
    }

    func testFreshStoreKeysAreIndependentAndCredentialsAreNotPasswords() throws {
        let first = try StoredSession.fresh(), second = try StoredSession.fresh()
        XCTAssertEqual(first.storeKey.count, 32)
        XCTAssertNotEqual(first.storeKey, second.storeKey)
        XCTAssertNotEqual(first.storeID, second.storeID)
        XCTAssertNil(first.credentials)
        let roundTrip = try JSONDecoder().decode(StoredSession.self, from: JSONEncoder().encode(first))
        XCTAssertEqual(first.storeKey, roundTrip.storeKey)
    }

    func testLockedOrUnavailableVaultBlocksLoginBeforeNetwork() async throws {
        let vault = MemoryVault(); vault.rejectWrites = true
        let client = try LettersMessagingClient(loopbackForTests: URL(string: "http://127.0.0.1:1")!,
            storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), vault: vault)
        do { try await client.signIn(username: "synthetic", password: "synthetic"); XCTFail("Storage failure must block login") }
        catch { XCTAssertEqual(error as? MessagingError, .secureStorageUnavailable) }
        do { _ = try await client.sendText("test", roomID: "!absent:letters.test", recipients: ["@bob:letters.test"]); XCTFail() }
        catch { XCTAssertEqual(error as? MessagingError, .noSession) }
    }

    func testAttachmentPolicyRejectsUnsafeInputsAndBoundsVoiceDuration() throws {
        let data = Data([1, 2, 3])
        XCTAssertThrowsError(try EncryptedAttachmentDraft(kind: .file, bytes: data, filename: "../secret", mimeType: "text/plain"))
        XCTAssertThrowsError(try EncryptedAttachmentDraft(kind: .gif, bytes: data, filename: "x.gif", mimeType: "image/jpeg"))
        for duration in [0.0, 301.0, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try EncryptedAttachmentDraft(kind: .voiceNote, bytes: data, filename: "voice.m4a", mimeType: "audio/mp4", duration: duration))
        }
        XCTAssertThrowsError(try EncryptedAttachmentDraft(kind: .file, bytes: Data(), filename: "x", mimeType: "text/plain"))
        XCTAssertThrowsError(try EncryptedAttachmentDraft(kind: .file, bytes: Data(count: EncryptedAttachmentDraft.maximumBytes + 1), filename: "x", mimeType: "application/octet-stream"))
    }

    // The full test is mandatory in CI; ordinary package users can run the
    // deterministic tests without installing a homeserver.
    func testRealEncryptedExchangeAndServerBoundaries() async throws {
        guard let path = ProcessInfo.processInfo.environment["LETTERS_MATRIX_TEST_FIXTURE"] else {
            throw XCTSkip("Run scripts/test-encrypted-messaging.py for the isolated integration test")
        }
        struct Fixture: Decodable { let base: String; let grants: [String: LetterboxLoginGrant]; let stores: String }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let base = URL(string: fixture.base)!
        let aliceVault = MemoryVault(), bobVault = MemoryVault(), outsiderVault = MemoryVault()
        func make(_ name: String, _ vault: MemoryVault) throws -> LettersMessagingClient {
            try LettersMessagingClient(loopbackForTests: base,
                storageDirectory: URL(fileURLWithPath: fixture.stores).appendingPathComponent(name), vault: vault)
        }
        let alice = try make("alice", aliceVault), bob = try make("bob", bobVault)
        let outsider = try make("outsider", outsiderVault)
        try await alice.signIn(using: XCTUnwrap(fixture.grants["alice"]))
        try await bob.signIn(using: XCTUnwrap(fixture.grants["bob"]))
        try await outsider.signIn(using: XCTUnwrap(fixture.grants["outsider"]))
        let aliceID = try await alice.userID(), bobID = try await bob.userID()
        let originalDevice = try await alice.deviceID()
        for _ in 0..<3 { try await alice.syncOnce(); try await bob.syncOnce() }
        let roomID = try await alice.createEncryptedRoom(name: "Synthetic encrypted test", recipients: [bobID])
        try await bob.syncOnce()
        try await bob.joinInvitation(roomID: roomID)
        for _ in 0..<4 { try await alice.syncOnce(); try await bob.syncOnce() }

        let body = "Synthetic Letters message \(UUID().uuidString)"
        let eventID = try await alice.sendText(body, roomID: roomID, recipients: [bobID])
        var received: String?
        for _ in 0..<20 {
            try await bob.syncOnce(); try await alice.syncOnce()
            received = try? await bob.readText(eventID: eventID, roomID: roomID, recipients: [aliceID])
            if received == body { break }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        XCTAssertEqual(received, body, "Independent recipient must decrypt the synthetic text")

        let aliceSession = try XCTUnwrap(aliceVault.load()?.credentials)
        let outsiderSession = try XCTUnwrap(outsiderVault.load()?.credentials)
        // Inspect the actual server event, not the SDK's decrypted cache.
        let raw = try await api(base, "/_matrix/client/v3/rooms/\(escape(roomID))/event/\(escape(eventID))", token: aliceSession.accessToken)
        XCTAssertEqual(raw.status, 200)
        let event = try XCTUnwrap(try JSONSerialization.jsonObject(with: raw.data) as? [String: Any])
        XCTAssertEqual(event["type"] as? String, "m.room.encrypted")
        let content = try XCTUnwrap(event["content"] as? [String: Any])
        XCTAssertEqual(content["algorithm"] as? String, "m.megolm.v1.aes-sha2")
        XCTAssertNotNil(content["ciphertext"])
        XCTAssertNil(content["body"])
        XCTAssertFalse(String(decoding: raw.data, as: UTF8.self).contains(body))
        // Exercise all five encrypted media envelopes between independent client stores.
        // Synthetic bytes verify transport, encryption and decryption, not media codec playback.
        var seenEvents: Set<String> = [eventID]
        for (kind, mime, ext) in [(AttachmentType.voiceNote, "audio/mp4", "m4a"),
                                 (.image, "image/png", "png"), (.gif, "image/gif", "gif"),
                                 (.video, "video/mp4", "mp4"), (.file, "application/pdf", "pdf")] {
            let bytes = Data(("Synthetic private attachment \(kind.rawValue) \(UUID().uuidString)").utf8)
            let draft = try EncryptedAttachmentDraft(kind: kind, bytes: bytes, filename: "synthetic." + ext,
                mimeType: mime, duration: kind == .voiceNote ? 1 : nil)
            let sentAttachmentID = try await alice.sendAttachment(draft, roomID: roomID, recipients: [bobID])
            var attachment: ReceivedAttachment?, attachmentID: String?
            var failureType = "No new encrypted media event"
            for _ in 0..<20 {
                try await alice.syncOnce(); try await bob.syncOnce()
                let page = try await api(base, "/_matrix/client/v3/rooms/\(escape(roomID))/messages?dir=b&limit=30", token: aliceSession.accessToken)
                let pageJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: page.data) as? [String: Any])
                let events = pageJSON["chunk"] as? [[String: Any]] ?? []
                XCTAssertEqual(page.status, 200)
                for item in events where item["type"] as? String == "m.room.encrypted" {
                    guard let id = item["event_id"] as? String, !seenEvents.contains(id) else { continue }
                    do {
                        let received = try await bob.readAttachment(eventID: id, roomID: roomID, recipients: [aliceID])
                        if received.bytes == bytes { attachment = received; attachmentID = id; break }
                        failureType = "Decrypted payload mismatch"
                    } catch {
                        // Report a type only: SDK error descriptions may contain media/session details.
                        failureType = String(reflecting: Swift.type(of: error))
                        if let error = error as? AttachmentError { failureType += ": " + String(describing: error) }
                    }
                }
                if attachment != nil { break }
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            let received = try XCTUnwrap(attachment, "Recipient must decrypt \(kind.rawValue): \(failureType)")
            let id = try XCTUnwrap(attachmentID); seenEvents.insert(id)
            XCTAssertEqual(id, sentAttachmentID)
            XCTAssertEqual(received.kind, kind)
            XCTAssertEqual(received.bytes, bytes)
            let envelope = try await api(base, "/_matrix/client/v3/rooms/\(escape(roomID))/event/\(escape(id))", token: aliceSession.accessToken)
            XCTAssertFalse(String(decoding: envelope.data, as: UTF8.self).contains(draft.filename))
            XCTAssertFalse(String(decoding: envelope.data, as: UTF8.self).contains("Synthetic private attachment"))
            let locator = try XCTUnwrap(URL(string: received.encryptedMediaURL))
            let server = try XCTUnwrap(locator.host)
            let ciphertext = try await api(base, "/_matrix/client/v1/media/download/\(escape(server))\(locator.path)", token: aliceSession.accessToken)
            XCTAssertEqual(ciphertext.status, 200)
            XCTAssertNotEqual(ciphertext.data, bytes, "Uploaded media must be ciphertext, not merely a TLS upload")
            XCTAssertFalse(ciphertext.data.range(of: bytes) != nil)
            do { _ = try await outsider.readAttachment(eventID: id, roomID: roomID, recipients: [aliceID]); XCTFail("Outsider media read must fail") }
            catch { XCTAssertEqual(error as? MessagingError, .roomNotJoined) }
        }

        let denied = try await api(base, "/_matrix/client/v3/rooms/\(escape(roomID))/event/\(escape(eventID))", token: outsiderSession.accessToken)
        // Synapse deliberately hides private event existence from outsiders.
        XCTAssertEqual(denied.status, 404)
        let denial = try XCTUnwrap(try JSONSerialization.jsonObject(with: denied.data) as? [String: Any])
        XCTAssertEqual(denial["errcode"] as? String, "M_NOT_FOUND")
        XCTAssertNil(denial["content"])
        XCTAssertFalse(String(decoding: denied.data, as: UTF8.self).contains(body))
        let joinDenied = try await api(base, "/_matrix/client/v3/join/\(escape(roomID))", token: outsiderSession.accessToken, json: [:])
        XCTAssertEqual(joinDenied.status, 403)
        let registration = try await api(base, "/_matrix/client/v3/register", token: nil,
            json: ["username": "not_invited", "password": "synthetic", "auth": ["type": "m.login.dummy"]])
        XCTAssertEqual(registration.status, 403)

        do { _ = try await alice.sendText("must fail", roomID: roomID, recipients: ["@outsider:letters.test"]); XCTFail("Changed audience must fail") }
        catch { XCTAssertEqual(error as? MessagingError, .recipientsChanged) }

        let plain = try await api(base, "/_matrix/client/v3/createRoom", token: aliceSession.accessToken,
                                  json: ["preset": "private_chat", "visibility": "private", "invite": [bobID]])
        XCTAssertEqual(plain.status, 200)
        let plainJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: plain.data) as? [String: Any])
        let plainID = try XCTUnwrap(plainJSON["room_id"] as? String)
        try await alice.syncOnce()
        try await bob.syncOnce()
        do { try await bob.joinInvitation(roomID: plainID); XCTFail("Plain invitation must not remain joined") }
        catch { XCTAssertEqual(error as? MessagingError, .encryptionUnavailable) }
        let departed = try await api(base, "/_matrix/client/v3/rooms/\(escape(plainID))/state/m.room.member/\(escape(bobID))", token: aliceSession.accessToken)
        XCTAssertEqual(departed.status, 200)
        let membership = try XCTUnwrap(try JSONSerialization.jsonObject(with: departed.data) as? [String: Any])
        XCTAssertEqual(membership["membership"] as? String, "leave")
        do { _ = try await alice.sendText("must never be sent", roomID: plainID, recipients: [bobID]); XCTFail("Plain room must fail") }
        catch { XCTAssertEqual(error as? MessagingError, .encryptionUnavailable) }

        let reply = "Synthetic encrypted reply " + UUID().uuidString
        let replyID = try await bob.sendText(reply, roomID: roomID, recipients: [aliceID])
        for _ in 0..<3 { try await bob.syncOnce(); try await alice.syncOnce() }

        // A room encryption flag does not prevent a malicious client sending a
        // plaintext event. Native history must refuse to display that injected body.
        let injected = try await api(base, "/_matrix/client/v3/rooms/\(escape(roomID))/send/m.room.message/\(UUID().uuidString)",
            token: aliceSession.accessToken, json: ["msgtype": "m.text", "body": "Synthetic injected cleartext"], method: "PUT")
        XCTAssertEqual(injected.status, 200)
        let injectedJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: injected.data) as? [String: Any])
        let injectedID = try XCTUnwrap(injectedJSON["event_id"] as? String)

        try await alice.close()
        try await alice.restore()
        let restoredDevice = try await alice.deviceID()
        XCTAssertEqual(restoredDevice, originalDevice, "Restore must preserve device identity")
        // The native history path must discover messages without manually supplying event IDs.
        var discovered: [ConversationMessage] = []
        for _ in 0..<8 {
            try await alice.syncOnce()
            discovered = try await alice.conversation(roomID: roomID, recipients: [bobID])
            if discovered.contains(where: { $0.id == eventID && $0.body == body }) && discovered.contains(where: { $0.id == replyID && $0.body == reply }) { break }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTAssertTrue(discovered.contains(where: { $0.id == eventID && $0.body == body }))
        XCTAssertEqual(Set(discovered.map(\.id)).count, discovered.count)
        XCTAssertFalse(discovered.contains(where: { $0.id == injectedID }))
        do { _ = try await alice.readText(eventID: injectedID, roomID: roomID, recipients: [bobID]); XCTFail("Event-ID reads must also reject cleartext") }
        catch { XCTAssertEqual(error as? MessagingError, .encryptionUnavailable) }
        do { _ = try await alice.readAttachment(eventID: injectedID, roomID: roomID, recipients: [bobID]); XCTFail("Attachment reads must reject a cleartext outer event") }
        catch { XCTAssertEqual(error as? MessagingError, .encryptionUnavailable) }
        XCTAssertTrue(discovered.contains(where: { $0.id == replyID && $0.body == reply && !$0.isOwn }))
        do { _ = try await alice.conversation(roomID: roomID, recipients: ["@outsider:letters.test"]); XCTFail("History must refuse an unexpected audience") }
        catch { XCTAssertEqual(error as? MessagingError, .recipientsChanged) }

        let restoredText = try await alice.readText(eventID: eventID, roomID: roomID, recipients: [bobID])
        XCTAssertEqual(restoredText, body)
        try await alice.signOut(); try await bob.signOut(); try await outsider.signOut()
        XCTAssertNil(try aliceVault.load())
    }

    private struct Response { let status: Int; let data: Data }
    private func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }
    private func api(_ base: URL, _ path: String, token: String?, json: [String: Any]? = nil, method: String? = nil) async throws -> Response {
        var request = URLRequest(url: URL(string: base.absoluteString + path)!)
        request.timeoutInterval = 10
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let json {
            request.httpMethod = method ?? "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        return Response(status: try XCTUnwrap(response as? HTTPURLResponse).statusCode, data: data)
    }
}
