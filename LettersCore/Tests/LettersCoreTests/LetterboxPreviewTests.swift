import XCTest
@testable import LettersCore

final class LetterboxPreviewTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1000)
    let secret = String(repeating: "A", count: 32)

    func testQRAndTypedCodeResolveToSameOneUseInvitation() throws {
        var box = LetterboxPreview()
        let invitation = try box.issue(secret: secret, now: now)
        XCTAssertEqual(try box.inspect(invitation.qrPayload, now: now).id, invitation.id)
        let typed = invitation.code.lowercased().replacingOccurrences(of: "-", with: " ")
        let member = try box.redeem(typed, name: " Alex ", now: now)
        XCTAssertEqual(member.name, "Alex")
        XCTAssertTrue(box.contactIDs.contains(member.id))
        XCTAssertTrue(box.groupMembers.values.allSatisfy { !$0.contains(member.id) })
        XCTAssertThrowsError(try box.redeem(invitation.code, name: "Replay", now: now))
        XCTAssertEqual(box.members.count, 4)
    }

    func testExpiryRevocationAndMalformedLinksFailClosed() throws {
        var box = LetterboxPreview()
        let invitation = try box.issue(secret: secret, now: now)
        XCTAssertThrowsError(try box.inspect(invitation.code, now: now.addingTimeInterval(86400)))
        box.revoke(invitation.id)
        XCTAssertThrowsError(try box.inspect(invitation.code, now: now))
        for input in ["https://evil.example/?code=\(invitation.code)",
                      invitation.qrPayload + "&code=another", "LBOX-" + secret,
                      "letters-preview://invite/other?code=\(invitation.code)", String(repeating: "A", count: 513)] {
            XCTAssertThrowsError(try LetterboxPreview.canonicalCode(input))
        }
    }

    func testGroupAdmissionRequiresExistingMemberAndIsSeparateFromContacts() throws {
        var box = LetterboxPreview()
        let invitation = try box.issue(secret: secret, groupID: "home", now: now)
        XCTAssertThrowsError(try box.redeem(invitation.code, name: "Stranger", now: now))
        XCTAssertNil(try box.inspect(invitation.code, now: now).usedBy)
        _ = try box.redeem(invitation.code, name: "", existingMemberID: "maya", now: now)
        XCTAssertTrue(box.groupMembers["home"]!.contains("maya"))
        XCTAssertFalse(box.groupMembers["weekend"]!.contains("maya"))
        XCTAssertThrowsError(try box.issue(secret: String(repeating: "B", count: 32), groupID: "unknown", now: now))
    }

    func testInvalidNameDoesNotConsumeInvitation() throws {
        var box = LetterboxPreview()
        let invitation = try box.issue(secret: secret, now: now)
        XCTAssertThrowsError(try box.redeem(invitation.code, name: " \n ", now: now))
        XCTAssertNil(try box.inspect(invitation.code, now: now).usedBy)
        XCTAssertEqual(box.members.count, 3)
    }
}
