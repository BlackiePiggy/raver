import XCTest
@testable import RaverMVP

@MainActor
final class EventTimetableAIParsingTests: XCTestCase {
    func testEditableTimetableImportResultUsesResolvedEventDayRefAndNormalized24HourClock() throws {
        let viewModel = makeViewModel()
        let response = EventTimetableImageImportResponse(
            rawJson: EventTimetableAIResult(
                schemaVersion: "raver_timetable_ai_v3",
                imageType: "timetable",
                weeks: [
                    EventTimetableAIWeek(
                        weekIndex: 2,
                        weekLabel: "Weekend 2",
                        days: [
                            EventTimetableAIDay(
                                weekIndex: 2,
                                dayIndexInWeek: 1,
                                dayLabel: "Weekend 2 Friday",
                                weekday: "friday",
                                dateText: "2026-07-24",
                                eventDayRef: EventTimetableAIResolvedEventDay(
                                    eventDayId: "w2d1",
                                    weekIndex: 2,
                                    dayIndexInWeek: 1,
                                    overallDayIndex: 4,
                                    date: "2026-07-24",
                                    resolutionReason: "Visible weekend label",
                                    confidence: 0.98
                                ),
                                stages: [
                                    EventTimetableAIStage(
                                        stageName: "Mainstage",
                                        order: 1,
                                        slots: [
                                            EventTimetableAISlot(
                                                orderInStage: 1,
                                                performerType: "solo",
                                                performerNames: ["Charlotte de Witte"],
                                                displayName: "Charlotte de Witte",
                                                rawTimeText: "23:30 - 01:00",
                                                startTimeText: "23:30",
                                                endTimeText: "01:00",
                                                normalizedStartTime: "23:30",
                                                normalizedEndTime: "25:00",
                                                confidence: 0.97,
                                                notes: ["cross-midnight"]
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ],
                unparsedTexts: ["tiny footer"],
                warnings: nil
            )
        )

        let result = viewModel.editableTimetableImportResult(from: response)

        XCTAssertEqual(result.warnings, [])
        XCTAssertEqual(result.unparsedTexts, ["tiny footer"])
        XCTAssertEqual(result.slots.count, 1)

        let slot = try XCTUnwrap(result.slots.first)
        XCTAssertEqual(slot.eventDayId, "w2d1")
        XCTAssertEqual(slot.weekIndex, 2)
        XCTAssertEqual(slot.dayIndexInWeek, 1)
        XCTAssertEqual(slot.overallDayIndex, 4)
        XCTAssertEqual(slot.localDate, "2026-07-24")
        XCTAssertEqual(slot.dayLabel, "Weekend 2 Friday")
        XCTAssertEqual(slot.stageName, "Mainstage")
        XCTAssertEqual(slot.performerNamesText, "Charlotte de Witte")
        XCTAssertEqual(slot.startTimeText, "23:30")
        XCTAssertEqual(slot.endTimeText, "01:00")
        XCTAssertEqual(slot.startDayOffset, .sameDay)
        XCTAssertEqual(slot.endDayOffset, .nextDay)
        XCTAssertEqual(slot.notes, ["cross-midnight"])
    }

    func testEditableTimetableImportResultPreservesAmbiguityWarningsAndLeavesEventDayUnbound() throws {
        let viewModel = makeViewModel()
        let warning = "ambiguous day marker: Friday maps to multiple eventDays; manual confirmation required"
        let response = EventTimetableImageImportResponse(
            rawJson: EventTimetableAIResult(
                schemaVersion: "raver_timetable_ai_v3",
                imageType: "timetable",
                weeks: [
                    EventTimetableAIWeek(
                        weekIndex: 1,
                        weekLabel: nil,
                        days: [
                            EventTimetableAIDay(
                                weekIndex: 1,
                                dayIndexInWeek: 1,
                                dayLabel: "Friday",
                                weekday: "friday",
                                dateText: nil,
                                eventDayRef: EventTimetableAIResolvedEventDay(
                                    eventDayId: nil,
                                    weekIndex: 1,
                                    dayIndexInWeek: 1,
                                    overallDayIndex: nil,
                                    date: nil,
                                    resolutionReason: "Ambiguous Friday marker",
                                    confidence: 0.24
                                ),
                                stages: [
                                    EventTimetableAIStage(
                                        stageName: "Freedom",
                                        order: 2,
                                        slots: [
                                            EventTimetableAISlot(
                                                orderInStage: 3,
                                                performerType: "b2b",
                                                performerNames: ["DJ Heart", "DJ Soul"],
                                                displayName: "DJ Heart b2b DJ Soul",
                                                rawTimeText: "20:00 - 21:30",
                                                startTimeText: "20:00",
                                                endTimeText: "21:30",
                                                normalizedStartTime: "20:00",
                                                normalizedEndTime: "21:30",
                                                confidence: 0.64,
                                                notes: ["needs manual date confirmation"]
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ],
                unparsedTexts: [],
                warnings: [warning]
            )
        )

        let result = viewModel.editableTimetableImportResult(from: response)

        XCTAssertEqual(result.warnings, [warning])
        XCTAssertEqual(result.unparsedTexts, [])
        XCTAssertEqual(result.slots.count, 1)

        let slot = try XCTUnwrap(result.slots.first)
        XCTAssertNil(slot.eventDayId)
        XCTAssertEqual(slot.weekIndex, 1)
        XCTAssertEqual(slot.dayIndexInWeek, 1)
        XCTAssertEqual(slot.overallDayIndex, 1)
        XCTAssertNil(slot.localDate)
        XCTAssertEqual(slot.dayLabel, "Friday")
        XCTAssertEqual(slot.stageName, "Freedom")
        XCTAssertEqual(slot.performerNamesText, "DJ Heart, DJ Soul")
        XCTAssertEqual(slot.startTimeText, "20:00")
        XCTAssertEqual(slot.endTimeText, "21:30")
        XCTAssertEqual(slot.startDayOffset, .sameDay)
        XCTAssertEqual(slot.endDayOffset, .sameDay)
        XCTAssertEqual(slot.notes, ["needs manual date confirmation"])
    }

    func testLocationSummaryUsesManualLocationFormattedAddressSemantics() {
        let viewModel = makeViewModel()
        viewModel.draft.preferredLanguage = .zh
        viewModel.draft.city = EventUploadLocalizedFields(zh: "上海", en: "Shanghai")
        viewModel.draft.country = EventUploadLocalizedFields(zh: "中国", en: "China", enFull: "China")
        viewModel.draft.detailAddress = EventUploadLocalizedFields(zh: "徐汇滨江 88 号", en: "88 Xuhui Riverside")
        viewModel.draft.latitude = 31.1891
        viewModel.draft.longitude = 121.4542
        viewModel.draft.pickedPlaceName = "滨江仓库"
        viewModel.draft.pickedMapAddress = "Riverside Warehouse"

        XCTAssertEqual(viewModel.locationSummary, "中国 · 上海 · 徐汇滨江 88 号")
    }

    func testVenueDisplaySummaryUsesVenueDisplayAddressSemantics() {
        let viewModel = makeViewModel()
        viewModel.draft.preferredLanguage = .zh
        viewModel.draft.city = EventUploadLocalizedFields(zh: "上海", en: "Shanghai")
        viewModel.draft.country = EventUploadLocalizedFields(zh: "中国", en: "China", enFull: "China")
        viewModel.draft.detailAddress = EventUploadLocalizedFields(zh: "徐汇滨江 88 号", en: "88 Xuhui Riverside")
        viewModel.draft.latitude = 31.1891
        viewModel.draft.longitude = 121.4542
        viewModel.draft.pickedPlaceName = "滨江仓库"
        viewModel.draft.pickedMapAddress = "Riverside Warehouse"

        XCTAssertEqual(viewModel.venueDisplaySummary, "中国 · 上海 · 徐汇滨江 88 号")
        XCTAssertEqual(viewModel.coordinateSummary, "31.189100, 121.454200")
    }

    private func makeViewModel() -> EventUploadFlowViewModel {
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

        let defaults = UserDefaults(suiteName: "EventTimetableAIParsingTests.\(UUID().uuidString)")!
        let viewModel = EventUploadFlowViewModel(
            mode: .create,
            event: nil,
            userID: "test-user",
            webService: MockWebFeatureService(),
            draftStore: EventUploadDraftStore(defaults: defaults)
        )
        viewModel.draft = draft
        return viewModel
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
}
