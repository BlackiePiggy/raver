import SwiftUI

enum EventCalendarViewFilter: String, CaseIterable, Hashable, Identifiable {
    case all
    case marked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L("全部活动", "All Events")
        case .marked: return L("已标记", "Marked")
        }
    }

    var icon: String {
        switch self {
        case .all: return "calendar"
        case .marked: return "bookmark.fill"
        }
    }
}

enum EventTypeOption: String, CaseIterable {
    case festival
    case barEvent = "bar_event"
    case outdoorEvent = "outdoor_event"
    case clubParty = "club_party"
    case warehouseParty = "warehouse_party"
    case tourSpecial = "tour_special"
    case other

    private static let aliasesByOption: [EventTypeOption: Set<String>] = [
        .festival: ["festival", "music_festival", "电音节"],
        .barEvent: ["bar_event", "barevent", "bar_activity", "酒吧活动"],
        .outdoorEvent: ["outdoor_event", "outdoorevent", "露天活动"],
        .clubParty: ["club_party", "clubparty", "俱乐部派对"],
        .warehouseParty: ["warehouse_party", "warehouseparty", "仓库派对"],
        .tourSpecial: ["tour_special", "tourspecial", "巡演专场"],
        .other: ["other", "其他"]
    ]

    private static func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    static func from(raw value: String?) -> EventTypeOption? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let normalized = normalizedKey(value)
        for option in EventTypeOption.allCases {
            if aliasesByOption[option]?.contains(normalized) == true {
                return option
            }
        }
        return nil
    }

    static func key(for rawValue: String?) -> String {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return ""
        }
        if let option = from(raw: rawValue) {
            return option.rawValue
        }
        return rawValue
    }

    static func displayTitle(for key: String) -> String {
        if let option = EventTypeOption(rawValue: key) {
            return option.localizedTitle
        }
        return key
    }

    static func displayText(for rawValue: String?, fallbackWhenEmpty: Bool = true) -> String {
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return fallbackWhenEmpty ? uncategorizedTitle : ""
        }
        if let option = from(raw: trimmed) {
            return option.localizedTitle
        }
        return trimmed
    }

    static func submissionValue(for key: String?) -> String? {
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return nil
        }
        if let option = EventTypeOption(rawValue: key) {
            return option.rawValue
        }
        return key
    }

    static func matches(rawValue: String?, selectedKey: String) -> Bool {
        key(for: rawValue) == selectedKey
    }

    static var allEventsTitle: String {
        L("全部活动", "All Events")
    }

    static var pickerPrompt: String {
        L("请选择活动性质", "Select Event Type")
    }

    static var uncategorizedTitle: String {
        L("未分类", "Uncategorized")
    }

    private var localizedTitle: String {
        switch AppLanguagePreference.current.effectiveLanguage {
        case .zh:
            switch self {
            case .festival: return "电音节"
            case .barEvent: return "酒吧活动"
            case .outdoorEvent: return "露天活动"
            case .clubParty: return "俱乐部派对"
            case .warehouseParty: return "仓库派对"
            case .tourSpecial: return "巡演专场"
            case .other: return "其他"
            }
        case .en, .system:
            switch self {
            case .festival: return "Festival"
            case .barEvent: return "Bar Event"
            case .outdoorEvent: return "Outdoor Event"
            case .clubParty: return "Club Party"
            case .warehouseParty: return "Warehouse Party"
            case .tourSpecial: return "Tour Special"
            case .other: return "Other"
            }
        }
    }
}

struct EventCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss

    let events: [WebEvent]
    let markedEventIDs: Set<String>
    @Binding var selectedDate: Date
    @Binding var selectedFilters: Set<EventCalendarViewFilter>
    let onEventSelected: (WebEvent) -> Void

    @State private var displayedMonth: Date
    private let calendar = Calendar.current

    init(
        events: [WebEvent],
        markedEventIDs: Set<String>,
        selectedDate: Binding<Date>,
        selectedFilters: Binding<Set<EventCalendarViewFilter>>,
        onEventSelected: @escaping (WebEvent) -> Void
    ) {
        self.events = events
        self.markedEventIDs = markedEventIDs
        _selectedDate = selectedDate
        _selectedFilters = selectedFilters
        self.onEventSelected = onEventSelected
        _displayedMonth = State(initialValue: Calendar.current.startOfMonth(for: selectedDate.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(LL("活动日历"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EventCalendarViewFilter.allCases) { filter in
                            Button {
                                toggleFilter(filter)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: filter.icon)
                                        .font(.caption.weight(.semibold))
                                    Text(filter.title)
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(selectedFilters.contains(filter) ? RaverTheme.accent : RaverTheme.card)
                                )
                                .foregroundStyle(selectedFilters.contains(filter) ? Color.white : RaverTheme.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 10) {
                    HStack {
                        Button {
                            shiftMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(RaverTheme.secondaryText)

                        Spacer()

                        Text(displayedMonth.appLocalizedYMText())
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)

                        Spacer()

                        Button {
                            shiftMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(RaverTheme.secondaryText)
                    }

                    let weekdays = calendar.shortStandaloneWeekdaySymbols
                    HStack(spacing: 0) {
                        ForEach(weekdays.indices, id: \.self) { idx in
                            Text(weekdays[idx])
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                        ForEach(monthCells.indices, id: \.self) { idx in
                            if let date = monthCells[idx] {
                                Button {
                                    selectedDate = date
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("\(calendar.component(.day, from: date))")
                                            .font(.subheadline.weight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular))
                                            .foregroundStyle(dayTextColor(for: date))

                                        HStack(spacing: 3) {
                                            ForEach(dayMarkerColors(for: date).indices, id: \.self) { markerIdx in
                                                Circle()
                                                    .fill(dayMarkerColors(for: date)[markerIdx])
                                                    .frame(width: 5, height: 5)
                                            }
                                        }
                                        .frame(height: 6)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .padding(.vertical, 2)
                                    .background(dayBackground(for: date))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(height: 42)
                            }
                        }
                    }
                }
                .padding(12)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(selectedDate.appLocalizedYMDText())
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)
                        Spacer()
                        Text(L("共 \(eventsOnSelectedDay.count) 场", "\(eventsOnSelectedDay.count) events"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if eventsOnSelectedDay.isEmpty {
                        ContentUnavailableView(LL("当日暂无活动"), systemImage: "calendar")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(eventsOnSelectedDay) { event in
                                    Button {
                                        onEventSelected(event)
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            eventCoverImage(event)
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(event.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(RaverTheme.primaryText)
                                                    .lineLimit(2)
                                                Text(event.startDate.formatted(date: .omitted, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundStyle(RaverTheme.secondaryText)
                                                if !event.summaryLocation.isEmpty {
                                                    Text(event.summaryLocation)
                                                        .font(.caption2)
                                                        .foregroundStyle(RaverTheme.secondaryText)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                            VStack(spacing: 4) {
                                                if markedEventIDs.contains(event.id) {
                                                    tag(L("标记", "Marked"), color: RaverTheme.accent)
                                                }
                                            }
                                        }
                                        .padding(10)
                                        .background(RaverTheme.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .background(RaverTheme.background)
            .onChange(of: selectedDate) { _, newDate in
                let monthStart = calendar.startOfMonth(for: newDate)
                if !calendar.isDate(monthStart, equalTo: displayedMonth, toGranularity: .month) {
                    displayedMonth = monthStart
                }
            }
    }

    private var filteredEvents: [WebEvent] {
        let filters = selectedFilters.isEmpty ? Set([EventCalendarViewFilter.all]) : selectedFilters
        if filters.contains(.all) {
            return events.sorted(by: { $0.startDate < $1.startDate })
        }
        return events
            .filter { event in
                filters.contains(.marked) && markedEventIDs.contains(event.id)
            }
            .sorted(by: { $0.startDate < $1.startDate })
    }

    private var eventsOnSelectedDay: [WebEvent] {
        filteredEvents.filter { calendar.isDate($0.startDate, inSameDayAs: selectedDate) }
    }

    private var monthCells: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private func dayMarkerColors(for date: Date) -> [Color] {
        let dayEvents = filteredEvents.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
        guard !dayEvents.isEmpty else { return [] }
        let hasMarked = dayEvents.contains(where: { markedEventIDs.contains($0.id) })
        var markers: [Color] = []
        markers.append(RaverTheme.accent)
        if hasMarked { markers.append(Color.orange) }
        return Array(markers.prefix(3))
    }

    private func dayTextColor(for date: Date) -> Color {
        if calendar.isDate(date, inSameDayAs: selectedDate) {
            return .white
        }
        if calendar.isDate(date, inSameDayAs: Date()) {
            return RaverTheme.accent
        }
        return RaverTheme.primaryText
    }

    private func dayBackground(for date: Date) -> some ShapeStyle {
        if calendar.isDate(date, inSameDayAs: selectedDate) {
            return AnyShapeStyle(RaverTheme.accent)
        }
        return AnyShapeStyle(Color.clear)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }

    private func toggleFilter(_ filter: EventCalendarViewFilter) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
            if selectedFilters.isEmpty {
                selectedFilters = [.all]
            }
            return
        }
        selectedFilters.insert(filter)
    }

    private func shiftMonth(by delta: Int) {
        if let date = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = calendar.startOfMonth(for: date)
        }
    }

    @ViewBuilder
    private func eventCoverImage(_ event: WebEvent) -> some View {
        if let cover = AppConfig.resolvedURLString(event.cardImageURL), let url = URL(string: cover) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    eventFallbackCover
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    eventFallbackCover
                @unknown default:
                    eventFallbackCover
                }
            }
        } else {
            eventFallbackCover
        }
    }

    private var eventFallbackCover: some View {
        ZStack {
            LinearGradient(
                colors: [RaverTheme.accent.opacity(0.35), RaverTheme.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }
}
