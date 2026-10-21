import Foundation
import Security
import MatrixRustSDK

// The SDK's token and encrypted SQLite key live together in one atomic Keychain
// record. No password is retained. A Keychain failure must stop the client.
protocol SessionVault: Sendable {
    func load() throws -> StoredSession?
    func save(_ record: StoredSession) throws
    func remove() throws
}

struct StoredSession: Codable {
    let storeID: UUID
    let storeKey: Data
    var credentials: Credentials?

    struct Credentials: Codable {
        let accessToken: String
        let refreshToken: String?
        let userID: String
        let deviceID: String
        let homeserver: String
        let oauthData: String?
        let nativeSync: Bool

        init(_ session: Session) {
            accessToken = session.accessToken
            refreshToken = session.refreshToken
            userID = session.userId
            deviceID = session.deviceId
            homeserver = session.homeserverUrl
            oauthData = session.oauthData
            nativeSync = session.slidingSyncVersion == .native
        }

        var sdk: Session {
            Session(accessToken: accessToken, refreshToken: refreshToken,
                    userId: userID, deviceId: deviceID, homeserverUrl: homeserver,
                    oauthData: oauthData, slidingSyncVersion: nativeSync ? .native : .none)
        }
    }

    static func fresh() throws -> Self {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw MessagingError.secureStorageUnavailable
        }
        return Self(storeID: UUID(), storeKey: Data(bytes), credentials: nil)
    }
}

final class KeychainSessionVault: SessionVault, @unchecked Sendable {
    private let account: String
    private let lock = NSLock()
    init(account: String) { self.account = account }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "Letters.MatrixSession.v1",
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    func load() throws -> StoredSession? {
        lock.lock(); defer { lock.unlock() }
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw MessagingError.secureStorageUnavailable
        }
        do {
            let value = try JSONDecoder().decode(StoredSession.self, from: data)
            guard value.storeKey.count == 32 else { throw MessagingError.secureStorageUnavailable }
            return value
        } catch { throw MessagingError.secureStorageUnavailable }
    }

    func save(_ record: StoredSession) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try JSONEncoder().encode(record)
        let values: [String: Any] = [kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            values.forEach { insert[$0.key] = $0.value }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else {
                throw MessagingError.secureStorageUnavailable
            }
        } else if status != errSecSuccess { throw MessagingError.secureStorageUnavailable }
    }

    func remove() throws {
        lock.lock(); defer { lock.unlock() }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MessagingError.secureStorageUnavailable
        }
    }
}

// Token refresh callbacks can arrive on SDK threads. Retain the existing store
// key and fail closed on any persistence error; never silently reset identity.
final class SessionDelegate: ClientSessionDelegate, @unchecked Sendable {
    private let vault: any SessionVault
    private let lock = NSLock()
    private var failed = false
    init(vault: any SessionVault) { self.vault = vault }

    func retrieveSessionFromKeychain(userId: String) throws -> Session {
        guard let record = try vault.load(), let credentials = record.credentials,
              credentials.userID == userId else { throw MessagingError.noSession }
        return credentials.sdk
    }

    func saveSessionInKeychain(session: Session) {
        do {
            guard var record = try vault.load() else { throw MessagingError.noSession }
            if let old = record.credentials {
                guard old.userID == session.userId, old.deviceID == session.deviceId,
                      old.homeserver == session.homeserverUrl else { throw MessagingError.invalidSession }
            }
            record.credentials = .init(session)
            try vault.save(record)
        } catch {
            lock.lock(); failed = true; lock.unlock()
        }
    }

    func check() throws {
        lock.lock(); defer { lock.unlock() }
        guard !failed else { throw MessagingError.secureStorageUnavailable }
    }
}
