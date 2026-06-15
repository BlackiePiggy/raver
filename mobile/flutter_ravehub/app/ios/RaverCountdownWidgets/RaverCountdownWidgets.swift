import WidgetKit
import SwiftUI

// MARK: - Entry

struct EventCountdownEntry: TimelineEntry {
    let date: Date
    let eventName: String
    let eventId: String
    let daysUntil: Int
    let hoursUntil: Int
    let venueName: String
}

// MARK: - Timeline Provider

struct CountdownTimelineProvider: TimelineProvider {
    private let suiteName = "group.com.ravehub.app"

    func placeholder(in context: Context) -> EventCountdownEntry {
        EventCountdownEntry(
            date: Date(),
            eventName: "EDM Festival 2026",
            eventId: "",
            daysUntil: 7,
            hoursUntil: 168,
            venueName: "Main Stage"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (EventCountdownEntry) -> Void) {
        let entry = buildEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventCountdownEntry>) -> Void) {
        let entry = buildEntry()
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func buildEntry() -> EventCountdownEntry {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return placeholderEntry()
        }

        let eventId = defaults.string(forKey: "upcoming_event_id") ?? ""
        let eventName = defaults.string(forKey: "upcoming_event_name") ?? ""
        let eventDateString = defaults.string(forKey: "upcoming_event_date") ?? ""
        let venueName = defaults.string(forKey: "upcoming_event_venue") ?? ""

        guard !eventId.isEmpty, !eventName.isEmpty, !eventDateString.isEmpty else {
            return placeholderEntry()
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let eventDate = formatter.date(from: eventDateString)
                ?? ISO8601DateFormatter().date(from: eventDateString) else {
            return placeholderEntry()
        }

        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour], from: now, to: eventDate)
        let daysUntil = max(components.day ?? 0, 0)
        let hoursUntil = max(components.hour ?? 0, 0)

        return EventCountdownEntry(
            date: now,
            eventName: eventName,
            eventId: eventId,
            daysUntil: daysUntil,
            hoursUntil: hoursUntil,
            venueName: venueName
        )
    }

    private func placeholderEntry() -> EventCountdownEntry {
        EventCountdownEntry(
            date: Date(),
            eventName: "",
            eventId: "",
            daysUntil: 0,
            hoursUntil: 0,
            venueName: ""
        )
    }
}

// MARK: - Widget Entry View

struct CountdownWidgetEntryView: View {
    var entry: EventCountdownEntry
    @Environment(\.widgetFamily) var family

    private let darkBackground = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0x0D / 255.0, green: 0x0D / 255.0, blue: 0x0D / 255.0),
            Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x2E / 255.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let accentPurple = Color(red: 0x7B / 255.0, green: 0x2F / 255.0, blue: 0xFF / 255.0)

    var body: some View {
        Group {
            if entry.eventName.isEmpty {
                noEventView
            } else {
                switch family {
                case .systemMedium:
                    mediumView
                default:
                    smallView
                }
            }
        }
        .widgetURL(widgetURL)
    }

    // MARK: - No Event View

    private var noEventView: some View {
        ZStack {
            darkBackground
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 28))
                    .foregroundColor(accentPurple)
                Text("No upcoming events")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                Text("RAVEHUB")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentPurple.opacity(0.7))
            }
            .padding()
        }
    }

    // MARK: - Small View

    private var smallView: some View {
        ZStack {
            darkBackground
            VStack(alignment: .leading, spacing: 4) {
                Text("RAVEHUB")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(accentPurple)

                Spacer()

                Text(entry.eventName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if !entry.venueName.isEmpty {
                    Text(entry.venueName)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.daysUntil)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(accentPurple)
                    Text(entry.daysUntil == 1 ? "DAY" : "DAYS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(12)
        }
    }

    // MARK: - Medium View

    private var mediumView: some View {
        ZStack {
            darkBackground
            HStack(spacing: 16) {
                // Left: countdown
                VStack(spacing: 4) {
                    Text("\(entry.daysUntil)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(accentPurple)
                    Text(entry.daysUntil == 1 ? "DAY" : "DAYS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(entry.hoursUntil)h remaining")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(width: 90)

                // Divider
                Rectangle()
                    .fill(accentPurple.opacity(0.3))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                // Right: event info
                VStack(alignment: .leading, spacing: 6) {
                    Text("RAVEHUB")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(accentPurple)

                    Spacer()

                    Text(entry.eventName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if !entry.venueName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(accentPurple.opacity(0.8))
                            Text(entry.venueName)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }

                Spacer()
            }
            .padding(14)
        }
    }

    // MARK: - Deep Link URL

    private var widgetURL: URL? {
        guard !entry.eventId.isEmpty else { return nil }
        return URL(string: "raver://event/\(entry.eventId)")
    }
}

// MARK: - Widget Configuration

struct RaverCountdownWidget: Widget {
    let kind: String = "RaverCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownTimelineProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Event Countdown")
        .description("Countdown to your next rave.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct RaverCountdownWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RaverCountdownWidget()
    }
}

// MARK: - Previews

struct RaverCountdownWidget_Previews: PreviewProvider {
    static var previews: some View {
        CountdownWidgetEntryView(
            entry: EventCountdownEntry(
                date: Date(),
                eventName: "Tomorrowland 2026",
                eventId: "evt_123",
                daysUntil: 42,
                hoursUntil: 1008,
                venueName: "Boom, Belgium"
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        CountdownWidgetEntryView(
            entry: EventCountdownEntry(
                date: Date(),
                eventName: "Tomorrowland 2026",
                eventId: "evt_123",
                daysUntil: 42,
                hoursUntil: 1008,
                venueName: "Boom, Belgium"
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))

        CountdownWidgetEntryView(
            entry: EventCountdownEntry(
                date: Date(),
                eventName: "",
                eventId: "",
                daysUntil: 0,
                hoursUntil: 0,
                venueName: ""
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
