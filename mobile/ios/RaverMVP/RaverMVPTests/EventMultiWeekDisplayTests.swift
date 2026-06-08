import XCTest
@testable import RaverMVP

final class EventMultiWeekDisplayTests: XCTestCase {
    private var originalLanguage: AppLanguage = .system

    override func setUp() {
        super.setUp()
        originalLanguage = AppLanguagePreference.current
        AppLanguagePreference.current = .en
    }

    override func tearDown() {
        AppLanguagePreference.current = originalLanguage
        super.tearDown()
    }

    func testDiscreteDateRangesKeepStructuredWeeksAsSeparateSegments() {
        let event = makeEvent(
            weeks: [
                WebEventWeek(
                    id: "week-1",
                    weekIndex: 1,
                    label: "Weekend 1",
                    startDate: Self.date("2026-07-17", timeZoneID: "Europe/Brussels"),
                    endDate: Self.date("2026-07-19", timeZoneID: "Europe/Brussels"),
                    sortOrder: 1
                ),
                WebEventWeek(
                    id: "week-2",
                    weekIndex: 2,
                    label: "Weekend 2",
                    startDate: Self.date("2026-07-24", timeZoneID: "Europe/Brussels"),
                    endDate: Self.date("2026-07-26", timeZoneID: "Europe/Brussels"),
                    sortOrder: 2
                ),
            ],
            eventDays: [
                makeEventDay(
                    id: "day-1",
                    eventDayId: "w1d1",
                    weekIndex: 1,
                    dayIndexInWeek: 1,
                    overallDayIndex: 1,
                    label: "Weekend 1 Friday",
                    date: "2026-07-17"
                ),
                makeEventDay(
                    id: "day-4",
                    eventDayId: "w2d1",
                    weekIndex: 2,
                    dayIndexInWeek: 1,
                    overallDayIndex: 4,
                    label: "Weekend 2 Friday",
                    date: "2026-07-24"
                ),
            ]
        )

        XCTAssertEqual(event.discreteDateRanges.map(\.weekIndex), [1, 2])
        XCTAssertEqual(event.discreteDateRanges.map(\.label), ["Weekend 1", "Weekend 2"])
        XCTAssertEqual(
            event.discreteDateSummaryLines(in: TimeZone(identifier: "Europe/Brussels"), includeTimeZonePerLine: false),
            [
                "Weekend 1 · Jul 17, 2026 - Jul 19, 2026",
                "Weekend 2 · Jul 24, 2026 - Jul 26, 2026",
            ]
        )
    }

    func testDiscreteDateSummaryDerivesCompactWeekPrefixesFromEventDaysWhenWeeksMissing() {
        let event = makeEvent(
            weeks: [],
            eventDays: [
                makeEventDay(
                    id: "day-1",
                    eventDayId: "w1d1",
                    weekIndex: 1,
                    dayIndexInWeek: 1,
                    overallDayIndex: 1,
                    label: "Weekend 1 Friday",
                    date: "2026-07-17"
                ),
                makeEventDay(
                    id: "day-2",
                    eventDayId: "w1d2",
                    weekIndex: 1,
                    dayIndexInWeek: 2,
                    overallDayIndex: 2,
                    label: "Weekend 1 Saturday",
                    date: "2026-07-18"
                ),
                makeEventDay(
                    id: "day-4",
                    eventDayId: "w2d1",
                    weekIndex: 2,
                    dayIndexInWeek: 1,
                    overallDayIndex: 4,
                    label: "Weekend 2 Friday",
                    date: "2026-07-24"
                ),
                makeEventDay(
                    id: "day-5",
                    eventDayId: "w2d2",
                    weekIndex: 2,
                    dayIndexInWeek: 2,
                    overallDayIndex: 5,
                    label: "Weekend 2 Saturday",
                    date: "2026-07-25"
                ),
            ]
        )

        XCTAssertEqual(event.discreteDateRanges.map(\.label), ["Weekend 1", "Weekend 2"])
        XCTAssertEqual(
            event.discreteDateSummaryLines(in: TimeZone(identifier: "Europe/Brussels"), includeTimeZonePerLine: false),
            [
                "Weekend 1 · Jul 17, 2026 - Jul 18, 2026",
                "Weekend 2 · Jul 24, 2026 - Jul 25, 2026",
            ]
        )
    }

    func testDiscreteDateSummaryFallsBackToEventRangeWhenStructuredWeeksAreUnavailable() {
        let event = makeEvent(weeks: [], eventDays: [])

        XCTAssertEqual(event.discreteDateRanges.count, 1)
        XCTAssertNil(event.discreteDateRanges.first?.label)
        XCTAssertEqual(
            event.discreteDateSummaryLines(in: TimeZone(identifier: "Europe/Brussels"), includeTimeZonePerLine: false),
            ["Jul 17, 2026 - Jul 26, 2026"]
        )
    }

    private func makeEvent(weeks: [WebEventWeek], eventDays: [WebEventDay]) -> WebEvent {
        WebEvent(
            id: "event-1",
            name: "Tomorrowland",
            slug: "tomorrowland",
            coverImageUrl: nil,
            lineupImageUrl: nil,
            eventType: "festival",
            organizerName: nil,
            city: "Boom",
            country: "Belgium",
            startDate: Self.date("2026-07-17", timeZoneID: "Europe/Brussels"),
            endDate: Self.date("2026-07-26", timeZoneID: "Europe/Brussels"),
            schedule: WebEventSchedule(mode: "multi_week", timeZone: "Europe/Brussels", dayRolloverHour: 6),
            weeks: weeks,
            eventDays: eventDays,
            timeZone: "Europe/Brussels",
            startTime: nil,
            endTime: nil,
            dayRolloverHour: 6,
            ticketUrl: nil,
            ticketPriceMin: nil,
            ticketPriceMax: nil,
            ticketCurrency: nil,
            ticketNotes: nil,
            officialWebsite: nil,
            isVerified: true,
            createdAt: Self.date("2026-01-01", timeZoneID: "Europe/Brussels"),
            updatedAt: Self.date("2026-01-01", timeZoneID: "Europe/Brussels"),
            ticketTiers: [],
            lineupSlots: []
        )
    }

    private func makeEventDay(
        id: String,
        eventDayId: String,
        weekIndex: Int,
        dayIndexInWeek: Int,
        overallDayIndex: Int,
        label: String,
        date: String
    ) -> WebEventDay {
        WebEventDay(
            id: id,
            eventDayId: eventDayId,
            weekIndex: weekIndex,
            dayIndexInWeek: dayIndexInWeek,
            overallDayIndex: overallDayIndex,
            label: label,
            weekday: nil,
            date: Self.date(date, timeZoneID: "Europe/Brussels"),
            sortOrder: overallDayIndex
        )
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
