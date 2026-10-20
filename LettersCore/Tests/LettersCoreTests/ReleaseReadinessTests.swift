import XCTest
@testable import LettersCore

final class ReleaseReadinessTests: XCTestCase {
    func testDefaultProjectCannotBeCalledReadyForPrivateMessages() {
        let evidence = ReleaseEvidence()
        XCTAssertFalse(evidence.readyForMessagingPilot)
        XCTAssertEqual(evidence.missingRequirements.count, 6)
    }

    func testEachMissingSecurityRequirementBlocksPilot() {
        let checks: [WritableKeyPath<ReleaseEvidence, Bool>] = [
            \.matrixEncryptionIntegrated, \.inviteOnlyServerVerified,
            \.deviceVerificationTested, \.encryptedRecoveryTested,
            \.encryptedMediaTested, \.plaintextFallbackAbsent
        ]
        let complete = ReleaseEvidence(matrixEncryptionIntegrated: true,
            inviteOnlyServerVerified: true, deviceVerificationTested: true,
            encryptedRecoveryTested: true, encryptedMediaTested: true,
            plaintextFallbackAbsent: true)
        XCTAssertTrue(complete.readyForMessagingPilot)
        for check in checks {
            var incomplete = complete
            incomplete[keyPath: check] = false
            XCTAssertFalse(incomplete.readyForMessagingPilot)
            XCTAssertEqual(incomplete.missingRequirements.count, 1)
        }
    }
}
