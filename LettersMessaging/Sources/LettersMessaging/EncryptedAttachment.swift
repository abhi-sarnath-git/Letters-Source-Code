// Media policy shared by recording/import and the real SDK boundary. Never infer encryption from a padlock icon.
import Foundation

public enum AttachmentType: String, CaseIterable, Sendable { case voiceNote, image, gif, video, file }
public enum AttachmentError: Error, Equatable { case invalidMetadata, tooLarge, notEncrypted, unsupportedEvent }

public struct EncryptedAttachmentDraft: Sendable {
    public static let maximumBytes = 20 * 1024 * 1024
    public let kind: AttachmentType
    public let bytes: Data
    public let filename: String
    public let mimeType: String
    public let duration: TimeInterval?
    public init(kind: AttachmentType, bytes: Data, filename: String, mimeType: String, duration: TimeInterval? = nil) throws {
        guard !bytes.isEmpty, bytes.count <= Self.maximumBytes else { throw AttachmentError.tooLarge }
        guard !filename.isEmpty, filename.utf8.count <= 120,
              filename != ".", filename != "..", !filename.contains("/"), !filename.contains("\\"),
              !filename.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              mimeType.range(of: #"^[a-z0-9.+-]+/[a-z0-9.+-]+$"#, options: .regularExpression) != nil else {
            throw AttachmentError.invalidMetadata
        }
        switch kind {
        case .voiceNote:
            guard ["audio/mp4", "audio/ogg", "audio/wav"].contains(mimeType),
                  let duration, duration.isFinite, duration > 0, duration <= 300 else { throw AttachmentError.invalidMetadata }
        case .image: guard ["image/png", "image/jpeg", "image/heic", "image/webp"].contains(mimeType) else { throw AttachmentError.invalidMetadata }
        case .gif: guard mimeType == "image/gif" else { throw AttachmentError.invalidMetadata }
        case .video: guard ["video/mp4", "video/quicktime", "video/webm"].contains(mimeType) else { throw AttachmentError.invalidMetadata }
        case .file: break
        }
        if let duration, !duration.isFinite || duration <= 0 { throw AttachmentError.invalidMetadata }
        self.kind = kind; self.bytes = bytes; self.filename = filename; self.mimeType = mimeType; self.duration = duration
    }
}

/// Decrypted bytes belong to the recipient. Never log or persist this value without protected storage.
public struct ReceivedAttachment: Sendable {
    public let kind: AttachmentType
    public let filename: String
    public let mimeType: String
    public let bytes: Data
    // Ciphertext locator is useful to the isolated integration test; decryption keys never leave the SDK.
    public let encryptedMediaURL: String
}
