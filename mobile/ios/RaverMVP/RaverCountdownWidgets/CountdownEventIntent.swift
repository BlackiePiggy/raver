import AppIntents
import Foundation

struct CountdownEventEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Event")
    static var defaultQuery = CountdownEventQuery()

    let id: String
    let name: String
    let subtitle: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle.map { "\($0)" }
        )
    }
}

struct CountdownEventQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [CountdownEventEntity.ID]) async throws -> [CountdownEventEntity] {
        let events = loadEntities()
        let requested = Set(identifiers)
        return events.filter { requested.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CountdownEventEntity] {
        loadEntities()
    }

    func entities(matching string: String) async throws -> [CountdownEventEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return loadEntities() }
        return loadEntities().filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || ($0.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func loadEntities() -> [CountdownEventEntity] {
        let snapshot = (try? WidgetCountdownStore.shared.loadSnapshot()) ?? .empty
        return snapshot.events.map { event in
            CountdownEventEntity(
                id: event.id,
                name: event.displayName,
                subtitle: [event.nextRelevantDateText(), event.city, event.venueName]
                    .compactMap(widgetTrimmed)
                    .joined(separator: " · ")
            )
        }
    }
}

private extension WidgetCountdownEvent {
    func nextRelevantDateText(now: Date = Date(), calendar: Calendar = .current) -> String? {
        let today = calendar.startOfDay(for: now)
        let ranges = normalizedDateRanges
        let selectedRange = ranges.first {
            calendar.startOfDay(for: max($0.endDate, $0.startDate)) >= today
        } ?? ranges.last

        guard let selectedRange else { return nil }
        let startDay = calendar.startOfDay(for: selectedRange.startDate)
        let endDay = calendar.startOfDay(for: max(selectedRange.endDate, selectedRange.startDate))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = calendar.isDate(startDay, inSameDayAs: endDay) ? "M月d日" : "M月d日-M月d日"
        if calendar.isDate(startDay, inSameDayAs: endDay) {
            return formatter.string(from: startDay)
        }
        return "\(formatter.string(from: startDay))-\(formatter.string(from: endDay))"
    }
}

struct SelectCountdownEventIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Event Countdown"
    static var description = IntentDescription("Choose one event from your Raver countdown list.")

    @Parameter(title: "Event")
    var event: CountdownEventEntity?
}
