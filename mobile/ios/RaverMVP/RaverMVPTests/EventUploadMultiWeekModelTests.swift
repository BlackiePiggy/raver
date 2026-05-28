import XCTest
@testable import RaverMVP

final class EventUploadMultiWeekModelTests: XCTestCase {
    func testStructuredEventDaysUseMultiWeekIdentifiersAndRebindSlots() {
        var draft = makeMultiWeekDraft()
        var slot = EventUploadLineupSlotDraft()
        slot.weekIndex = 2
        slot.dayIndexInWeek = 1
        slot.overallDayIndex = 4
        slot.dayIndex = 4
        slot.localDate = Self.date("2026-07-24", timeZoneID: "Europe/Brussels")
        slot.performerNames = ["Charlotte de Witte"]
        slot.stageName = "Mainstage"
        draft.timetableSlots = [slot]

        XCTAssertEqual(
            draft.structuredEventDays.map(\.eventDayId),
            ["w1d1", "w1d2", "w1d3", "w2d1", "w2d2", "w2d3"]
        )

        draft.rebuildStructuredScheduleBindings()

        XCTAssertEqual(draft.timetableSlots.first?.eventDayId, "w2d1")
        XCTAssertEqual(draft.timetableSlots.first?.weekIndex, 2)
        XCTAssertEqual(draft.timetableSlots.first?.dayIndexInWeek, 1)
        XCTAssertEqual(draft.timetableSlots.first?.overallDayIndex, 4)
    }

    func testCreateInputOutputsStructuredScheduleAndNilFestivalDayIndex() {
        var draft = makeMultiWeekDraft()
        draft.name.zh = "Tomorrowland"
        draft.city.zh = "Boom"
        draft.country.zh = "Belgium"
        draft.detailAddress.zh = "Provinciaal Recreatiedomein De Schorre"

        var slot = EventUploadLineupSlotDraft()
        slot.eventDayId = "w2d1"
        slot.weekIndex = 2
        slot.dayIndexInWeek = 1
        slot.overallDayIndex = 4
        slot.dayIndex = 4
        slot.localDate = Self.date("2026-07-24", timeZoneID: "Europe/Brussels")
        slot.performerNames = ["Charlotte de Witte"]
        slot.stageName = "Mainstage"
        slot.startTime = Self.dateTime("2026-07-24 23:30", timeZoneID: "Europe/Brussels")
        slot.endTime = Self.dateTime("2026-07-24 01:00", timeZoneID: "Europe/Brussels")
        draft.timetableSlots = [slot]

        let input = EventUploadMappers.createInput(from: draft)

        XCTAssertEqual(input.schedule?.mode, "multi_week")
        XCTAssertEqual(input.weeks?.count, 2)
        XCTAssertEqual(input.eventDays?.map(\.eventDayId), ["w1d1", "w1d2", "w1d3", "w2d1", "w2d2", "w2d3"])
        XCTAssertEqual(input.lineupSlots?.count, 1)
        XCTAssertEqual(input.lineupSlots?.first?.eventDayId, "w2d1")
        XCTAssertEqual(input.lineupSlots?.first?.weekIndex, 2)
        XCTAssertEqual(input.lineupSlots?.first?.dayIndexInWeek, 1)
        XCTAssertEqual(input.lineupSlots?.first?.overallDayIndex, 4)
        XCTAssertNil(input.lineupSlots?.first?.festivalDayIndex)
        XCTAssertEqual(input.lineupSlots?.first?.localDate, Self.date("2026-07-24", timeZoneID: "Europe/Brussels"))
    }

    func testValidationFlagsMissingEventDayBinding() {
        var draft = makeMultiWeekDraft()
        var slot = EventUploadLineupSlotDraft()
        slot.eventDayId = "missing-event-day"
        slot.weekIndex = 2
        slot.dayIndexInWeek = 1
        slot.overallDayIndex = 4
        slot.dayIndex = 4
        slot.performerNames = ["Amelie Lens"]
        slot.stageName = "Mainstage"
        slot.startTime = Self.dateTime("2026-07-24 20:00", timeZoneID: "Europe/Brussels")
        slot.endTime = Self.dateTime("2026-07-24 21:00", timeZoneID: "Europe/Brussels")
        draft.timetableSlots = [slot]

        let issues = EventUploadValidation.issues(for: draft)

        XCTAssertTrue(issues.contains { $0.step == .timetable && $0.message.contains("event day") || $0.message.contains("活动日") })
    }

    private func makeMultiWeekDraft() -> EventUploadDraft {
        var draft = EventUploadDraft.create()
        draft.timeZoneIdentifier = "Europe/Brussels"
        draft.dayRolloverHour = 6
        draft.applyScheduleMode(.multiWeek)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2026-07-17", timeZoneID: "Europe/Brussels"),
                endDate: Self.date("2026-07-19", timeZoneID: "Europe/Brussels")
            ),
            EventUploadWeekRangeDraft(
                startDate: Self.date("2026-07-24", timeZoneID: "Europe/Brussels"),
                endDate: Self.date("2026-07-26", timeZoneID: "Europe/Brussels")
            ),
        ])
        return draft
    }

    private static func date(_ value: String, timeZoneID: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else {
            fatalError("Failed to parse date \(value)")
        }
        return date
    }

    private static func dateTime(_ value: String, timeZoneID: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let date = formatter.date(from: value) else {
            fatalError("Failed to parse date time \(value)")
        }
        return date
    }
}
