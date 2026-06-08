import SwiftUI

private func inferredEventWeekTitle(from rawLabel: String?) -> String? {
    guard let rawLabel = rawLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawLabel.isEmpty else {
        return nil
    }

    let patterns = [
        #"(?i)\bweekend\s*\d+\b"#,
        #"(?i)\bweek\s*\d+\b"#,
        #"第\s*\d+\s*[周週]"#
    ]

    for pattern in patterns {
        if let range = rawLabel.range(of: pattern, options: .regularExpression) {
            return String(rawLabel[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    return nil
}

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

    static func resolve(
        startDate: Date,
        endDate: Date,
        derivedStatus: String? = nil,
        isCancelled: Bool? = nil,
        now: Date = Date()
    ) -> EventVisualStatus {
        if let isCancelled, isCancelled {
            return .cancelled
        }
        let fallback = from(raw: derivedStatus)
        guard endDate >= startDate else {
            return fallback ?? (now < startDate ? .upcoming : .ended)
        }
        if now < startDate { return .upcoming }
        if now > endDate { return .ended }
        return fallback ?? .ongoing
    }

    static func resolve(event: WebEvent, now: Date = Date()) -> EventVisualStatus {
        resolve(
            startDate: event.startDate,
            endDate: event.endDate,
            isCancelled: event.isCancelled,
            now: now
        )
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
        case "cancelled":
            return .cancelled
        default:
            return nil
        }
    }

    static func derivedRawValue(for event: WebEvent, now: Date = Date()) -> String {
        resolve(event: event, now: now).rawValue
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

extension Date {
    fileprivate func appLocalizedYMDTextRawForEventPresentation(in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguagePreference.current.effectiveLanguage.localeIdentifier)
        formatter.timeZone = timeZone
        switch AppLanguagePreference.current.effectiveLanguage {
        case .zh, .system:
            formatter.dateFormat = "yyyy年M月d日"
        case .en:
            formatter.dateFormat = "MMM d, yyyy"
        case .ja:
            formatter.dateFormat = "yyyy年M月d日"
        }
        return formatter.string(from: self)
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
        if normalized.contains("cover") {
            return "cover"
        }
        if normalized.contains("poster") {
            return "poster"
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

    var posterAssetURLs: [String] {
        let fromAssets = normalizedImageAssets
            .filter { normalizedAssetBucket($0.type) == "poster" }
            .map(\.url)
        return dedupedURLs(fromAssets + [coverImageUrl ?? ""])
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
        let serverCard = cardImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let serverCard, !serverCard.isEmpty {
            return serverCard
        }
        return posterAssetURLs.first ?? coverAssetURL ?? lineupAssetURLs.first
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
        return posterAssetURLs.first ?? lineupAssetURLs.first
    }

    var discreteDateRanges: [EventDiscreteDateRange] {
        let sortedWeeks = weeks.sorted { lhs, rhs in
            if lhs.weekIndex != rhs.weekIndex { return lhs.weekIndex < rhs.weekIndex }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.startDate < rhs.startDate
        }
        if !sortedWeeks.isEmpty {
            return sortedWeeks.map { week in
                EventDiscreteDateRange(
                    id: week.id,
                    weekIndex: week.weekIndex,
                    label: week.label,
                    startDate: week.startDate,
                    endDate: week.endDate
                )
            }
        }

        let groupedEventDays = Dictionary(grouping: eventDays) { $0.weekIndex }
        let sortedWeekIndexes = groupedEventDays.keys.sorted()
        if sortedWeekIndexes.count > 1 {
            return sortedWeekIndexes.compactMap { weekIndex in
                guard let days = groupedEventDays[weekIndex]?.sorted(by: { $0.date < $1.date }),
                      let first = days.first,
                      let last = days.last else {
                    return nil
                }
                let label = days.compactMap { inferredEventWeekTitle(from: $0.label) }.first
                    ?? localizedEventWeekTitle(weekIndex)
                return EventDiscreteDateRange(
                    id: "event-days-week-\(weekIndex)",
                    weekIndex: weekIndex,
                    label: label,
                    startDate: first.date,
                    endDate: last.date
                )
            }
        }

        return [
            EventDiscreteDateRange(
                id: "event-range",
                weekIndex: 1,
                label: nil,
                startDate: startDate,
                endDate: endDate
            )
        ]
    }

    var primaryDisplayDate: Date {
        discreteDateRanges.first?.startDate ?? startDate
    }

    var totalDisplayDayCount: Int {
        if !eventDays.isEmpty {
            return eventDays.count
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eventTimeZone
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let span = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        return max(span, 1)
    }

    var displayDayCountText: String {
        localizedEventDayCountText(dayCount: totalDisplayDayCount)
    }

    func discreteDateSummaryDateLines(
        in timeZone: TimeZone? = nil,
        includeTimeZonePerLine: Bool = false
    ) -> [String] {
        let resolvedTimeZone = timeZone ?? eventTimeZone
        let baseDateLines = eventDiscreteDateSummaryDateLines(
            ranges: discreteDateRanges,
            fallbackStartDate: startDate,
            fallbackEndDate: endDate,
            timeZone: resolvedTimeZone
        )
        guard includeTimeZonePerLine else {
            return baseDateLines
        }
        let timeZoneLabel = Date.appLocalizedTimeZoneLabel(resolvedTimeZone)
        guard !timeZoneLabel.isEmpty else {
            return baseDateLines
        }
        return baseDateLines.map { "\($0) · \(timeZoneLabel)" }
    }

    func discreteDateSummaryLines(
        in timeZone: TimeZone? = nil,
        includeTimeZonePerLine: Bool = false
    ) -> [String] {
        let dateLines = discreteDateSummaryDateLines(
            in: timeZone,
            includeTimeZonePerLine: includeTimeZonePerLine
        )
        if includeTimeZonePerLine {
            return dateLines + [displayDayCountText]
        }
        return eventDiscreteDateSummaryDisplayLines(
            dateLines: dateLines,
            dayCountText: displayDayCountText
        )
    }

    func discreteDateSummaryText(
        in timeZone: TimeZone? = nil,
        includeTimeZone: Bool = true,
        separator: String = "\n"
    ) -> String {
        let resolvedTimeZone = timeZone ?? eventTimeZone
        let dateLines = discreteDateSummaryDateLines(in: resolvedTimeZone, includeTimeZonePerLine: false)
        if includeTimeZone {
            return eventDiscreteDateSummaryDisplayText(
                dateLines: dateLines,
                dayCountText: displayDayCountText,
                timeZone: resolvedTimeZone,
                separator: separator
            )
        }
        return eventDiscreteDateSummaryDisplayText(
            dateLines: dateLines,
            dayCountText: displayDayCountText,
            timeZone: nil,
            separator: separator
        )
    }

    func discreteDateSummaryTextWithoutDayCount(
        in timeZone: TimeZone? = nil,
        includeTimeZone: Bool = true,
        separator: String = "\n"
    ) -> String {
        let resolvedTimeZone = timeZone ?? eventTimeZone
        let dateLines = discreteDateSummaryDateLines(in: resolvedTimeZone, includeTimeZonePerLine: false)
        return eventDiscreteDateSummaryDisplayText(
            dateLines: dateLines,
            dayCountText: "",
            timeZone: includeTimeZone ? resolvedTimeZone : nil,
            separator: separator
        )
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

                    Label {
                        Text(eventDateRangeText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    } icon: {
                        Image(systemName: "calendar")
                    }
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
#if DEBUG
            .onAppear {
                debugLogCardSelection(surface: "discover-event-row")
            }
#endif
    }

#if DEBUG
    private func debugLogCardSelection(surface: String) {
        guard event.id == "e87c26d3-a3eb-4ae5-a221-49e074ce905d" else { return }
        print(
            "[EventCardDebug] surface=\(surface) eventId=\(event.id) " +
            "card=\(event.cardImageURL ?? "nil") coverAsset=\(event.coverAssetURL ?? "nil") " +
            "cover=\(event.coverImageUrl ?? "nil") " +
            "lineup=\(event.lineupImageUrl ?? "nil") posterCandidates=\(event.posterAssetURLs.count) " +
            "lineupAssets=\(event.lineupAssetURLs.count)"
        )
    }
#endif

    private var eventDateBadge: some View {
        let badgeDate = event.primaryDisplayDate
        return VStack(spacing: 0) {
            Text(badgeDate.appLocalizedMonthBadgeText(in: event.eventTimeZone))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(eventDateBadgeTextColor)
            Text("\(Calendar.eventCalendar(timeZone: event.eventTimeZone).component(.day, from: badgeDate))")
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
        event.discreteDateSummaryTextWithoutDayCount()
    }

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
