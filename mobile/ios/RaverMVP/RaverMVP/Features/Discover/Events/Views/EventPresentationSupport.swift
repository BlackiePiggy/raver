import SwiftUI

enum EventVisualStatus: String {
    case upcoming
    case ongoing
    case ended
    case cancelled

    var title: String {
        switch AppLanguagePreference.current.effectiveLanguage {
        case .zh:
            switch self {
            case .upcoming: return "即将开始"
            case .ongoing: return "进行中"
            case .ended: return "已结束"
            case .cancelled: return "已取消"
            }
        case .ja:
            switch self {
            case .upcoming: return "まもなく開始"
            case .ongoing: return "開催中"
            case .ended: return "終了"
            case .cancelled: return "キャンセル済み"
            }
        case .en, .system:
            switch self {
            case .upcoming: return "Upcoming"
            case .ongoing: return "Ongoing"
            case .ended: return "Ended"
            case .cancelled: return "Cancelled"
            }
        }
    }

    var apiValue: String { rawValue }

    var badgeBackground: Color {
        switch self {
        case .upcoming: return Color.orange.opacity(0.68)
        case .ongoing: return Color.green.opacity(0.68)
        case .ended: return Color.black.opacity(0.58)
        case .cancelled: return Color(red: 0.86, green: 0.20, blue: 0.28).opacity(0.66)
        }
    }

    var badgeBorder: Color {
        switch self {
        case .upcoming: return Color.orange.opacity(0.82)
        case .ongoing: return Color.green.opacity(0.84)
        case .ended: return RaverTheme.secondaryText.opacity(0.95)
        case .cancelled: return Color(red: 1.0, green: 0.45, blue: 0.50).opacity(0.9)
        }
    }

    static func resolve(startDate: Date, endDate: Date, fallbackStatus: String? = nil, now: Date = Date()) -> EventVisualStatus {
        if let fallback = from(raw: fallbackStatus), fallback == .cancelled {
            return .cancelled
        }
        guard endDate >= startDate else {
            return from(raw: fallbackStatus) ?? (now < startDate ? .upcoming : .ended)
        }
        if now < startDate { return .upcoming }
        if now > endDate { return .ended }
        return .ongoing
    }

    static func resolve(event: WebEvent, now: Date = Date()) -> EventVisualStatus {
        resolve(startDate: event.startDate, endDate: event.endDate, fallbackStatus: event.status, now: now)
    }

    static func from(raw value: String?) -> EventVisualStatus? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else {
            return nil
        }
        switch value {
        case "upcoming":
            return .upcoming
        case "ongoing":
            return .ongoing
        case "ended":
            return .ended
        case "cancelled", "canceled":
            return .cancelled
        default:
            return nil
        }
    }
}

struct LiveActivityBarsView: View {
    let color: Color
    var barCount: Int = 3
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var minHeight: CGFloat = 5
    var maxHeight: CGFloat = 13
    var animationSpeed: Double = 5.6
    var phaseShift: Double = 1.35
    var cornerRadius: CGFloat = 1.5
    var minimumInterval: TimeInterval = 1.0 / 30.0

    var body: some View {
        TimelineView(.animation(minimumInterval: minimumInterval)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let normalizedWave = (sin(time * animationSpeed + Double(index) * phaseShift) + 1) / 2
                    let height = minHeight + CGFloat(normalizedWave) * (maxHeight - minHeight)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(color)
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(height: maxHeight, alignment: .bottom)
        }
        .frame(height: maxHeight)
    }
}

struct OngoingStatusBars: View {
    var body: some View {
        LiveActivityBarsView(
            color: Color.white.opacity(0.98),
            barWidth: 2.6,
            minHeight: 3,
            maxHeight: 10,
            cornerRadius: 1.3,
            minimumInterval: 1.0 / 30.0
        )
        .frame(width: 13, height: 10)
    }
}

extension WebEvent {
    private var normalizedImageAssets: [WebEventImageAsset] {
        let assets = imageAssets ?? []
        return assets.sorted { lhs, rhs in
            let leftOrder = lhs.order ?? Int.max
            let rightOrder = rhs.order ?? Int.max
            if leftOrder != rightOrder { return leftOrder < rightOrder }
            let leftSort = lhs.sort ?? Int.max
            let rightSort = rhs.sort ?? Int.max
            if leftSort != rightSort { return leftSort < rightSort }
            return lhs.url < rhs.url
        }
    }

    private func normalizedAssetBucket(_ rawType: String?) -> String {
        let normalized = (rawType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")

        if normalized == "tt" || normalized.contains("timetable") {
            return "timetable"
        }
        if normalized == "luall" || normalized.contains("lineup") {
            return "lineup"
        }
        if normalized.contains("cover") || normalized.contains("poster") {
            return "cover"
        }
        return "other"
    }

    private func dedupedURLs(_ urls: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in urls {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    var lineupAssetURLs: [String] {
        let fromAssets = normalizedImageAssets
            .filter { normalizedAssetBucket($0.type) == "lineup" }
            .map(\.url)
        return dedupedURLs(fromAssets + [lineupImageUrl ?? ""])
    }

    var timetableAssetURLs: [String] {
        let fromAssets = normalizedImageAssets
            .filter { normalizedAssetBucket($0.type) == "timetable" }
            .map(\.url)
        return dedupedURLs(fromAssets)
    }

    var cardImageURL: String? {
        lineupAssetURLs.first ?? coverAssetURL
    }

    var coverAssetURL: String? {
        let fromAssets = normalizedImageAssets
            .first { normalizedAssetBucket($0.type) == "cover" }?
            .url
        let trimmedAsset = fromAssets?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedAsset, !trimmedAsset.isEmpty {
            return trimmedAsset
        }
        let trimmedCover = coverImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCover?.isEmpty == false {
            return trimmedCover
        }
        return lineupAssetURLs.first
    }
}

struct EventRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let event: WebEvent
    private let coverWidth: CGFloat = 144
    private let coverHeight: CGFloat = 172
    private let actionColumnReserveWidth: CGFloat = 48

    var body: some View {
        let visualStatus = EventVisualStatus.resolve(event: event)
        let coverShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        HStack(alignment: .top, spacing: 12) {
            eventCoverLayer
                .frame(width: coverWidth, height: coverHeight)
                .clipShape(coverShape)
                .contentShape(coverShape)
                .overlay(alignment: .topLeading) {
                    eventDateBadge
                        .padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    eventStatusBadge(visualStatus)
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 7) {
                Text(event.name)
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                VStack(alignment: .leading, spacing: 7) {
                    Text(EventTypeOption.displayText(for: event.eventType))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RaverTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(RaverTheme.accent.opacity(0.15))
                        )

                    Label(eventDateRangeText, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    let addressText = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !addressText.isEmpty {
                        Label(addressText, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.trailing, actionColumnReserveWidth)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: coverHeight + 4, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    @ViewBuilder
    private var eventCoverLayer: some View {
        ImageLoaderView(urlString: event.cardImageURL, resizingMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [RaverTheme.accent.opacity(0.35), RaverTheme.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "ticket.fill")
                            .font(.title3)
                            .foregroundStyle(RaverTheme.secondaryText)
                    )
            )
    }

    private var eventDateBadge: some View {
        VStack(spacing: 0) {
            Text(event.startDate.appLocalizedMonthBadgeText())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(eventDateBadgeTextColor)
            Text("\(Calendar.current.component(.day, from: event.startDate))")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(eventDateBadgeTextColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var eventDateBadgeTextColor: Color {
        colorScheme == .light ? Color.white.opacity(0.96) : RaverTheme.primaryText
    }

    private var eventDateRangeText: String {
        let calendar = Calendar.current
        let start = event.startDate
        let end = event.endDate

        if AppLanguagePreference.current.effectiveLanguage != .en {
            return start.appLocalizedDateRangeText(to: end)
        }

        guard end >= start else {
            return Self.eventFullDateFormatter.string(from: start)
        }

        if calendar.isDate(start, inSameDayAs: end) {
            return Self.eventFullDateFormatter.string(from: start)
        }

        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)

        if startYear == endYear, startMonth == endMonth {
            let monthText = Self.eventMonthFormatter.string(from: start)
            let startDay = calendar.component(.day, from: start)
            let endDay = calendar.component(.day, from: end)
            return "\(monthText) \(startDay)-\(endDay), \(startYear)"
        }

        if startYear == endYear {
            let startText = Self.eventMonthDayFormatter.string(from: start)
            let endText = Self.eventMonthDayFormatter.string(from: end)
            return "\(startText)-\(endText), \(startYear)"
        }

        let startText = Self.eventFullDateFormatter.string(from: start)
        let endText = Self.eventFullDateFormatter.string(from: end)
        return "\(startText)-\(endText)"
    }

    private static let eventMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let eventMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let eventFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    @ViewBuilder
    private func eventStatusBadge(_ status: EventVisualStatus) -> some View {
        HStack(spacing: 6) {
            if status == .ongoing {
                OngoingStatusBars()
            }
            Text(status.title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(status.badgeBackground)
        )
        .overlay(
            Capsule()
                .stroke(status.badgeBorder, lineWidth: 0.85)
        )
    }
}
