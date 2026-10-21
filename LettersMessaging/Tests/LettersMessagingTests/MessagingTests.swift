import XCTest
import Foundation
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

    // The full test is mandatory in CI; ordinary package users can run the
    // deterministic tests without installing a homeserver.
    func testRealEncryptedExchangeAndServerBoundaries() async throws {
        guard let path = ProcessInfo.processInfo.environment["LETTERS_MATRIX_TEST_FIXTURE"] else {
            throw XCTSkip("Run scripts/test-encrypted-messaging.py for the isolated integration test")
        }
        struct Fixture: Decodable { let base: String; let accounts: [String: String]; let stores: String }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let base = URL(string: fixture.base)!
        let aliceVault = MemoryVault(), bobVault = MemoryVault(), outsiderVault = MemoryVault()
        func make(_ name: String, _ vault: MemoryVault) throws -> LettersMessagingClient {
            try LettersMessagingClient(loopbackForTests: base,
                storageDirectory: URL(fileURLWithPath: fixture.stores).appendingPathComponent(name), vault: vault)
        }
        let alice = try make("alice", aliceVault), bob = try make("bob", bobVault)
        let outsider = try make("outsider", outsiderVault)
        try await alice.signIn(username: "alice", password: XCTUnwrap(fixture.accounts["alice"]))
        try await bob.signIn(username: "bob", password: XCTUnwrap(fixture.accounts["bob"]))
        try await outsider.signIn(username: "outsider", password: XCTUnwrap(fixture.accounts["outsider"]))
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

        try await alice.close()
        try await alice.restore()
        let restoredDevice = try await alice.deviceID()
        XCTAssertEqual(restoredDevice, originalDevice, "Restore must preserve device identity")
        let restoredText = try await alice.readText(eventID: eventID, roomID: roomID, recipients: [bobID])
        XCTAssertEqual(restoredText, body)
        try await alice.signOut(); try await bob.signOut(); try await outsider.signOut()
        XCTAssertNil(try aliceVault.load())
    }

    private struct Response { let status: Int; let data: Data }
    private func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }
    private func api(_ base: URL, _ path: String, token: String?, json: [String: Any]? = nil) async throws -> Response {
        var request = URLRequest(url: URL(string: base.absoluteString + path)!)
        request.timeoutInterval = 10
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let json {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        return Response(status: try XCTUnwrap(response as? HTTPURLResponse).statusCode, data: data)
    }
}
