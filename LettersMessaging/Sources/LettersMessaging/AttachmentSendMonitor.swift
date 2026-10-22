// Track the actual server event, not just completion of an upload task. Never log queue error details.
import Foundation
import MatrixRustSDK

enum AttachmentSendError: Error { case paused, timedOut, cancelled, insecureDevices, identityChanged, verificationRequired, expiredSession, missingMedia, invalidMime, serverError }

final class AttachmentSendMonitor: SendQueueListener, @unchecked Sendable {
    private let lock=NSLock()
    private var transaction:String?
    private var result:Result<String,Error>?
    private var continuation:CheckedContinuation<String,Error>?
    func onUpdate(update:RoomSendQueueUpdate) {
        lock.lock()
        var completion:Result<String,Error>?
        switch update {
        case let .newLocalEvent(id): if transaction == nil { transaction=id }
        case let .sentEvent(id,eventID): if id == transaction { completion = .success(eventID) }
        case let .cancelledLocalEvent(id): if id == transaction { completion = .failure(AttachmentSendError.cancelled) }
        case let .sendError(id,error,_):
            if id == transaction {
                let safe:AttachmentSendError
                switch error {
                case .insecureDevices: safe = .insecureDevices
                case .identityViolations: safe = .identityChanged
                case .crossVerificationRequired: safe = .verificationRequired
                case .expiredAccessToken: safe = .expiredSession
                case .missingMediaContent: safe = .missingMedia
                case .invalidMimeType: safe = .invalidMime
                case .genericApiError: safe = .serverError
                }
                completion = .failure(safe)
            }
        default: break
        }
        lock.unlock()
        if let completion { finish(completion) }
    }
    func finish(_ value:Result<String,Error>) {
        lock.lock(); guard result == nil else { lock.unlock(); return }
        result=value; let pending=continuation; continuation=nil; lock.unlock()
        pending?.resume(with:value)
    }
    func wait() async throws -> String {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { pending in
                lock.lock()
                if let result { lock.unlock(); pending.resume(with:result) }
                else { continuation=pending; lock.unlock() }
            }
        }, onCancel:{ self.finish(.failure(AttachmentSendError.cancelled)) })
    }
}
