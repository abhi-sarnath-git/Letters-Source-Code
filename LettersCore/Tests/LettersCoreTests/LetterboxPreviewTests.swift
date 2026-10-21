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
    func testEveryMemberCanInviteAndContactListsRemainSeparate() throws {
        var box = LetterboxPreview()
        try box.selectProfile("maya")
        let invite = try box.issue(secret: secret, now: now)
        XCTAssertEqual(invite.issuerID, "maya")
        let alex = try box.redeem(invite.code, name: "Alex", now: now)
        XCTAssertTrue(box.contacts(for: "maya").contains(alex.id))
        XCTAssertEqual(box.contacts(for: alex.id), ["maya"])
        XCTAssertFalse(box.contacts(for: LetterboxPreview.ownerID).contains(alex.id))
        try box.selectProfile(alex.id)
        let own = try box.issue(secret: String(repeating: "B", count: 32), now: now)
        XCTAssertEqual(own.issuerID, alex.id)
        let sam = try box.redeem(own.code, name: "Sam", now: now)
        XCTAssertEqual(box.contacts(for: sam.id), [alex.id])
        XCTAssertFalse(box.contacts(for: "maya").contains(sam.id))
        let group = try box.createGroup(name: "Alex's friends")
        XCTAssertTrue(box.canInvite(to: group))
        let groupInvite = try box.issue(secret: String(repeating: "C", count: 32), groupID: group, now: now)
        try box.selectProfile("maya")
        XCTAssertFalse(box.canInvite(to: group))
        box.revoke(groupInvite.id)
        XCTAssertFalse(try box.inspect(groupInvite.code, now: now).revoked)
        _ = try box.redeem(groupInvite.code, name: "", existingMemberID: sam.id, now: now)
        XCTAssertTrue(box.groupMembers[group]!.contains(sam.id))
        XCTAssertFalse(box.groupMembers[group]!.contains("maya"))
    }

}
