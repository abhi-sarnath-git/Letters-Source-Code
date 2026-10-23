// Typed admission transport. No redirects, discovery, raw error-body logging or
// plaintext endpoint fallback: credentials go only to the configured HTTPS host.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AdmissionError: Error { case invalidEndpoint, invalidResponse, denied, unavailable }

private final class AdmissionRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

public struct AdmissionAccount: Decodable, Sendable {
    public let memberID: String
    public let name: String
    public let matrixUserID: String
    enum CodingKeys: String, CodingKey { case memberID = "member_id", name, matrixUserID = "matrix_user_id" }
}
public struct AdmissionContact: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String
}
public struct AdmissionAudience: Decodable, Sendable {
    public let ownUserID: String
    public let recipients: [String]
    enum CodingKeys: String, CodingKey { case ownUserID = "own_user_id", recipients = "recipient_user_ids" }
}

public actor LetterboxAPI {
    private let endpoint: URL
    private let session: URLSession
    private let redirects: AdmissionRedirectPolicy

    public init(endpoint: URL) throws {
        guard endpoint.scheme == "https", endpoint.host != nil, endpoint.user == nil, endpoint.password == nil,
              endpoint.query == nil, endpoint.fragment == nil, endpoint.path.isEmpty || endpoint.path == "/" else {
            throw AdmissionError.invalidEndpoint
        }
        self.endpoint = endpoint
        let redirectPolicy = AdmissionRedirectPolicy()
        redirects = redirectPolicy
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
        session = URLSession(configuration: config, delegate: redirectPolicy, delegateQueue: nil)
    }

    private func request<T: Decodable>(_ operation: String, token: String, body: [String: String] = [:]) async throws -> T {
        guard token.utf8.count >= 32, token.utf8.count <= 128,
              token.unicodeScalars.allSatisfy({ $0.isASCII && !CharacterSet.controlCharacters.contains($0) }) else {
            throw AdmissionError.denied
        }
        var request = URLRequest(url: endpoint.appendingPathComponent("v1/" + operation))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AdmissionError.invalidResponse }
        if response.statusCode == 403 { throw AdmissionError.denied }
        guard response.statusCode == 200, data.count <= 65536 else { throw AdmissionError.invalidResponse }
        // Never decode/display a server's error strings or credential-bearing debug body.
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func account(token: String) async throws -> AdmissionAccount { try await request("account", token: token) }
    public func contacts(token: String) async throws -> [AdmissionContact] { try await request("contacts", token: token) }
    public func audience(token: String, contactID: String) async throws -> AdmissionAudience {
        try await request("messaging/audience", token: token, body: ["contact_id": contactID])
    }
    public func loginGrant(token: String) async throws -> LetterboxLoginGrant {
        try await request("messaging/login-grant", token: token)
    }
    public func signOut(token: String) async throws {
        struct Result: Decodable { let signed_out: Bool }
        let result: Result = try await request("sign-out", token: token)
        guard result.signed_out else { throw AdmissionError.invalidResponse }
    }
}
