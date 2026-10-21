import XCTest
@testable import LettersCore

final class AlertAllPreviewStateTests: XCTestCase {
    func testWhitespaceUsesDefaultAndRepeatedTapDoesNotReplaceActiveRehearsal() {
        var state = AlertAllPreviewState()
        XCTAssertTrue(state.createRehearsal(note: " \n "))
        let original = state.latest
        XCTAssertEqual(original?.note, "I need help. Please check on me.")
        XCTAssertFalse(state.createRehearsal(note: "Duplicate"))
        XCTAssertEqual(state.latest, original)
    }

    func testOversizedNoteIsRejectedWithoutDiscardingPreviousState() {
        var state = AlertAllPreviewState()
        XCTAssertFalse(state.createRehearsal(note: String(repeating: "a", count: 281)))
        XCTAssertNil(state.latest)
        XCTAssertTrue(state.createRehearsal(note: String(repeating: "🚀", count: 280)))
    }

    func testEndingIsIdempotentAndNewRehearsalHasNewIdentity() {
        var state = AlertAllPreviewState()
        let start = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(state.endRehearsal(now: start))
        XCTAssertTrue(state.createRehearsal(note: "  Please check in  ", now: start))
        let firstID = state.latest?.id
        XCTAssertEqual(state.latest?.note, "Please check in")
        XCTAssertFalse(state.endRehearsal(now: start.addingTimeInterval(-1)))
        XCTAssertTrue(state.endRehearsal(now: start.addingTimeInterval(1)))
        XCTAssertFalse(state.hasActiveRehearsal)
        XCTAssertFalse(state.endRehearsal(now: start.addingTimeInterval(2)))
        XCTAssertTrue(state.createRehearsal(note: "Another rehearsal", now: start.addingTimeInterval(3)))
        XCTAssertNotEqual(state.latest?.id, firstID)
    }
}
