import XCTest
@testable import RaverMVP

final class EventLineupDraftDerivationTests: XCTestCase {
    func testLineupOnlySlotsFollowTimetableOrderAndDeduplicateActs() {
        var solo = EventUploadLineupSlotDraft()
        solo.actType = .solo
        solo.performerNames = ["Amelie Lens"]
        solo.performerDJIDs = ["dj_amelie"]
        solo.performerAvatarURLs = ["https://cdn.example.com/amelie.jpg"]
        solo.normalizePerformers()

        var duplicateSolo = EventUploadLineupSlotDraft()
        duplicateSolo.actType = .solo
        duplicateSolo.performerNames = ["Amelie Lens"]
        duplicateSolo.performerDJIDs = ["dj_amelie"]
        duplicateSolo.performerAvatarURLs = ["https://cdn.example.com/amelie-2.jpg"]
        duplicateSolo.normalizePerformers()

        var b2b = EventUploadLineupSlotDraft()
        b2b.actType = .b2b
        b2b.performerNames = ["Anyma", "MRAK"]
        b2b.performerDJIDs = ["dj_anyma", "dj_mrak"]
        b2b.performerAvatarURLs = ["https://cdn.example.com/anyma.jpg", "https://cdn.example.com/mrak.jpg"]
        b2b.normalizePerformers()

        let lineupOnlySlots = EventLineupDraftDerivation.lineupOnlySlots(
            from: [solo, duplicateSolo, b2b]
        )

        XCTAssertEqual(lineupOnlySlots.count, 2)
        XCTAssertEqual(lineupOnlySlots.map(\.actType), [.solo, .b2b])
        XCTAssertEqual(lineupOnlySlots.first?.performerNames, ["Amelie Lens"])
        XCTAssertEqual(lineupOnlySlots.first?.performerDJIDs, ["dj_amelie"])
        XCTAssertEqual(lineupOnlySlots.first?.performerAvatarURLs, ["https://cdn.example.com/amelie.jpg"])
        XCTAssertEqual(lineupOnlySlots.last?.performerNames, ["Anyma", "MRAK"])
        XCTAssertEqual(lineupOnlySlots.last?.performerDJIDs, ["dj_anyma", "dj_mrak"])
    }

    func testLineupOnlySlotsSkipIncompleteActs() {
        var incompleteB2B = EventUploadLineupSlotDraft()
        incompleteB2B.actType = .b2b
        incompleteB2B.performerNames = ["Anyma", ""]
        incompleteB2B.performerDJIDs = ["dj_anyma", nil]
        incompleteB2B.normalizePerformers()

        let lineupOnlySlots = EventLineupDraftDerivation.lineupOnlySlots(from: [incompleteB2B])

        XCTAssertTrue(lineupOnlySlots.isEmpty)
    }
}
