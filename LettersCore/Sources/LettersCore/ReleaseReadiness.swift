// Release checklist bookkeeping only. These flags do not enable encryption or authorize a real user.

import Foundation

/// Release evidence, not a cryptographic implementation or runtime authorization check.
/// These flags must eventually be produced by integration checks, never client input.
public struct ReleaseEvidence: Equatable {
    public var matrixEncryptionIntegrated: Bool
    public var inviteOnlyServerVerified: Bool
    public var deviceVerificationTested: Bool
    public var encryptedRecoveryTested: Bool
    public var encryptedMediaTested: Bool
    public var plaintextFallbackAbsent: Bool

    public init(matrixEncryptionIntegrated: Bool = false,
                inviteOnlyServerVerified: Bool = false,
                deviceVerificationTested: Bool = false,
                encryptedRecoveryTested: Bool = false,
                encryptedMediaTested: Bool = false,
                plaintextFallbackAbsent: Bool = false) {
        self.matrixEncryptionIntegrated = matrixEncryptionIntegrated
        self.inviteOnlyServerVerified = inviteOnlyServerVerified
        self.deviceVerificationTested = deviceVerificationTested
        self.encryptedRecoveryTested = encryptedRecoveryTested
        self.encryptedMediaTested = encryptedMediaTested
        self.plaintextFallbackAbsent = plaintextFallbackAbsent
    }

    public var missingRequirements: [String] {
        [
            (matrixEncryptionIntegrated, "Matrix encryption integration"),
            (inviteOnlyServerVerified, "Server-enforced invitations"),
            (deviceVerificationTested, "Device verification"),
            (encryptedRecoveryTested, "Encrypted recovery"),
            (encryptedMediaTested, "Encrypted attachments"),
            (plaintextFallbackAbsent, "No plaintext fallback")
        ].compactMap { $0.0 ? nil : $0.1 }
    }

    public var readyForMessagingPilot: Bool { missingRequirements.isEmpty }
}
