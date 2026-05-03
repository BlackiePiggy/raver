import SwiftUI
import UIKit
import WidgetKit

struct EventCountdownEntry: TimelineEntry {
    let date: Date
    let layoutStyle: WidgetCountdownLayoutStyle
    let state: EventCountdownWidgetState
}

enum EventCountdownWidgetState {
    case placeholder
    case notConfigured
    case emptyList
    case missingData
    case event(WidgetCountdownEvent, WidgetCountdownTimeState)
}

enum WidgetCountdownTimeState: Hashable {
    case upcoming(days: Int)
    case ongoing(day: Int)
    case ended(days: Int)

    var text: String {
        switch self {
        case .upcoming(let days):
            return "还有 \(days) 天"
        case .ongoing(let day):
            return "Day \(day)"
        case .ended(let days):
            return "过去 \(days) 天"
        }
    }
}

struct EventCountdownTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> EventCountdownEntry {
        EventCountdownEntry(date: Date(), layoutStyle: .original, state: .placeholder)
    }

    func snapshot(
        for configuration: SelectCountdownEventIntent,
        in context: Context
    ) async -> EventCountdownEntry {
        let snapshot = (try? WidgetCountdownStore.shared.loadSnapshot()) ?? .empty
        return EventCountdownEntry(
            date: Date(),
            layoutStyle: snapshot.selectedLayoutStyle,
            state: state(for: configuration, in: snapshot, at: Date())
        )
    }

    func timeline(
        for configuration: SelectCountdownEventIntent,
        in context: Context
    ) async -> Timeline<EventCountdownEntry> {
        let now = Date()
        let snapshot = (try? WidgetCountdownStore.shared.loadSnapshot()) ?? .empty
        let entry = EventCountdownEntry(
            date: now,
            layoutStyle: snapshot.selectedLayoutStyle,
            state: state(for: configuration, in: snapshot, at: now)
        )
        return Timeline(entries: [entry], policy: .after(nextRefreshDate(after: now)))
    }

    private func state(
        for configuration: SelectCountdownEventIntent,
        in snapshot: WidgetCountdownSnapshot,
        at date: Date
    ) -> EventCountdownWidgetState {
        guard !snapshot.events.isEmpty else {
            return .emptyList
        }

        guard let selectedID = configuration.event?.id else {
            return .notConfigured
        }

        guard let event = snapshot.events.first(where: { $0.id == selectedID }) else {
            return .missingData
        }

        return .event(event, WidgetCountdownDateCalculator.state(for: event, at: date))
    }

    private func nextRefreshDate(after date: Date) -> Date {
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(24 * 60 * 60)
        return calendar.date(byAdding: .minute, value: 5, to: nextDay) ?? nextDay
    }
}

enum WidgetCountdownDateCalculator {
    static func state(for event: WidgetCountdownEvent, at date: Date, calendar: Calendar = .current) -> WidgetCountdownTimeState {
        let today = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: event.startDate)
        let normalizedEnd = event.endDate < event.startDate ? event.startDate : event.endDate
        let endDay = calendar.startOfDay(for: normalizedEnd)

        if today < startDay {
            return .upcoming(days: max(0, calendar.dateComponents([.day], from: today, to: startDay).day ?? 0))
        }

        if today <= endDay {
            let day = (calendar.dateComponents([.day], from: startDay, to: today).day ?? 0) + 1
            return .ongoing(day: max(1, day))
        }

        return .ended(days: max(0, calendar.dateComponents([.day], from: endDay, to: today).day ?? 0))
    }
}

struct EventCountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: EventCountdownEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            readabilityOverlay
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .containerBackground(for: .widget) {
            background
        }
        .widgetURL(widgetURL)
    }

    @ViewBuilder
    private var background: some View {
        switch entry.state {
        case .event(let event, _):
            if let image = WidgetBackgroundImageCache.loadDisplayImage(
                relativePath: event.cachedBackgroundImageRelativePath,
                maxPixelSize: backgroundMaxPixelSize
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                fallbackBackground
            }
        default:
            fallbackBackground
        }
    }

    private var fallbackBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.09),
                Color(red: 0.42, green: 0.11, blue: 0.25),
                Color(red: 0.96, green: 0.44, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var readabilityOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.12), location: 0),
                .init(color: .black.opacity(0.25), location: 0.42),
                .init(color: .black.opacity(0.82), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .event(let event, let timeState):
            eventContent(event: event, timeState: timeState)
        case .placeholder:
            messageView(title: "Raver", subtitle: "Event Countdown")
        case .notConfigured:
            messageView(title: "选择活动", subtitle: "长按小组件编辑")
        case .emptyList:
            messageView(title: "暂无活动", subtitle: "先在活动详情页添加")
        case .missingData:
            messageView(title: "活动不可用", subtitle: "请重新选择")
        }
    }

    private func messageView(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(eventNameFont)
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(subtitle)
                .font(statusFont)
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(contentPadding)
    }

    @ViewBuilder
    private func eventContent(
        event: WidgetCountdownEvent,
        timeState: WidgetCountdownTimeState
    ) -> some View {
        switch entry.layoutStyle {
        case .original:
            VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 7) {
                Text(event.displayName)
                    .font(eventNameFont)
                    .foregroundStyle(.white)
                    .lineLimit(family == .systemSmall ? 2 : 2)
                    .minimumScaleFactor(0.82)
                    .shadow(color: .black.opacity(0.35), radius: 7, y: 2)

                Text(timeState.text)
                    .font(statusFont)
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .shadow(color: .black.opacity(0.35), radius: 7, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(contentPadding)
        case .distance:
            VStack(alignment: .leading, spacing: 0) {
                (
                    Text("距离")
                        .font(distancePrefixFont)
                        .fontWeight(.regular)
                    + Text(event.displayName)
                        .font(distancePrefixFont)
                        .fontWeight(.bold)
                )
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 2 : 2)
                .minimumScaleFactor(0.72)
                .shadow(color: .black.opacity(0.35), radius: 7, y: 2)

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(distanceNumberText(for: timeState))
                        .font(distanceNumberFont)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(distanceUnitText(for: timeState))
                        .font(distancePrefixFont)
                        .fontWeight(.regular)
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .shadow(color: .black.opacity(0.35), radius: 7, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(distanceLayoutPadding)
        }
    }

    private var eventNameFont: Font {
        family == .systemSmall
        ? .system(size: 18, weight: .heavy)
        : .system(size: 24, weight: .heavy)
    }

    private var statusFont: Font {
        family == .systemSmall
        ? .system(size: 13, weight: .bold)
        : .system(size: 16, weight: .bold)
    }

    private var distancePrefixFont: Font {
        family == .systemSmall
        ? .system(size: 13, weight: .regular)
        : .system(size: 15, weight: .regular)
    }

    private var distanceNumberFont: Font {
        family == .systemSmall
        ? .system(size: 42, weight: .heavy)
        : .system(size: 58, weight: .heavy)
    }

    private var contentPadding: EdgeInsets {
        family == .systemSmall
        ? EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        : EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    }

    private var distanceLayoutPadding: EdgeInsets {
        family == .systemSmall
        ? EdgeInsets(top: 10, leading: 10, bottom: 8, trailing: 10)
        : EdgeInsets(top: 12, leading: 12, bottom: 10, trailing: 12)
    }

    private var backgroundMaxPixelSize: CGFloat {
        family == .systemSmall ? 700 : 900
    }

    private var widgetURL: URL? {
        guard case .event(let event, _) = entry.state else { return nil }
        return URL(string: "\(RaverWidgetConstants.eventDeeplinkScheme)://event/\(event.id)")
    }

    private func distanceNumberText(for timeState: WidgetCountdownTimeState) -> String {
        switch timeState {
        case .upcoming(let days):
            return "\(days)"
        case .ongoing(let day):
            return "\(day)"
        case .ended(let days):
            return "\(days)"
        }
    }

    private func distanceUnitText(for timeState: WidgetCountdownTimeState) -> String {
        switch timeState {
        case .upcoming:
            return "天"
        case .ongoing:
            return "天"
        case .ended:
            return "天"
        }
    }
}

struct EventCountdownWidget: Widget {
    let kind = "EventCountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCountdownEventIntent.self,
            provider: EventCountdownTimelineProvider()
        ) { entry in
            EventCountdownWidgetView(entry: entry)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Raver Countdown")
        .description("Pin one event from your Raver countdown list.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
