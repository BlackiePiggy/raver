import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UIKit

private enum EventCalendarViewFilter: String, CaseIterable, Hashable, Identifiable {
    case all
    case marked
    case planned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部活动"
        case .marked: return "已标记"
        case .planned: return "计划前往"
        }
    }

    var icon: String {
        switch self {
        case .all: return "calendar"
        case .marked: return "bookmark.fill"
        case .planned: return "paperplane.fill"
        }
    }
}

private struct HorizontalAxisLockedScrollView<Content: View>: UIViewRepresentable {
    let showsIndicators: Bool
    let content: Content

    init(showsIndicators: Bool = false, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = showsIndicators
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.clipsToBounds = true

        let hostedView = context.coordinator.hostingController.view
        hostedView?.backgroundColor = .clear
        hostedView?.translatesAutoresizingMaskIntoConstraints = false

        if let hostedView {
            scrollView.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                hostedView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
            ])
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        uiView.showsHorizontalScrollIndicator = showsIndicators
        context.coordinator.hostingController.rootView = content
    }

    final class Coordinator {
        let hostingController: UIHostingController<Content>

        init(content: Content) {
            hostingController = UIHostingController(rootView: content)
            hostingController.view.backgroundColor = .clear
        }
    }
}

private func topSafeAreaInset() -> CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })?
        .safeAreaInsets.top ?? 0
}

struct EventsModuleView: View {
    @EnvironmentObject private var appState: AppState
    private let service = AppEnvironment.makeWebService()
    private static let predefinedEventTypes = ["电音节", "酒吧活动", "露天活动", "俱乐部派对", "仓库派对", "巡演专场", "其他"]

    private enum EventScope: String, CaseIterable, Identifiable {
        case all
        case mine

        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "全部活动"
            case .mine: return "我的活动"
            }
        }
    }

    @State private var events: [WebEvent] = []
    @State private var myPublishedEvents: [WebEvent] = []
    @State private var markedEvents: [WebEvent] = []
    @State private var plannedEvents: [WebEvent] = []
    @State private var markedCheckinIDsByEventID: [String: String] = [:]
    @State private var plannedCheckinIDsByEventID: [String: String] = [:]
    @State private var page = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var selectedScope: EventScope = .all
    @State private var selectedEventType = ""
    @State private var searchText = ""
    @State private var searchDraft = ""
    @State private var showSearchPrompt = false
    @State private var showCreate = false
    @State private var showCalendar = false
    @State private var calendarSelectedDate = Date()
    @State private var calendarFilters: Set<EventCalendarViewFilter> = [.all]
    @State private var selectedEventForDetail: WebEvent?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && contentIsEmpty {
                    ProgressView("活动加载中...")
                } else if selectedScope == .all {
                    allEventsContent
                } else {
                    myEventsContent
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    HorizontalAxisLockedScrollView(showsIndicators: false) {
                        HStack(spacing: 8) {
                            myEventsScopeChip
                            eventTypeChip(title: "全部活动", value: "")
                            ForEach(eventTypeTabs, id: \.self) { type in
                                eventTypeChip(title: type, value: type)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 34)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(RaverTheme.background)
            }
            .onChange(of: selectedScope) { _, _ in
                Task { await reload() }
            }
            .onChange(of: selectedEventType) { _, _ in
                if selectedScope == .all {
                    Task { await reload() }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }

                    Button {
                        searchDraft = searchText
                        showSearchPrompt = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }

                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSearchPrompt) {
                EventSearchSheet(initialText: searchText) { keyword in
                    searchText = keyword
                    Task { await reload() }
                }
            }
            .sheet(isPresented: $showCreate) {
                EventEditorView(mode: .create) {
                    Task { await reload() }
                }
            }
            .sheet(isPresented: $showCalendar) {
                EventCalendarSheet(
                    events: calendarSourceEvents,
                    markedEventIDs: Set(markedCheckinIDsByEventID.keys),
                    plannedEventIDs: Set(plannedCheckinIDsByEventID.keys),
                    selectedDate: $calendarSelectedDate,
                    selectedFilters: $calendarFilters,
                    onEventSelected: { event in
                        showCalendar = false
                        selectedEventForDetail = event
                    }
                )
                .presentationDetents([.fraction(0.8), .large])
            }
            .fullScreenCover(item: $selectedEventForDetail) { event in
                NavigationStack {
                    EventDetailView(eventID: event.id)
                }
            }
            .task {
                await reload()
            }
            .refreshable {
                await reload()
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func reload() async {
        page = 1
        totalPages = 1
        events = []
        myPublishedEvents = []
        await loadPersonalEventCheckins()
        if selectedScope == .all {
            await loadMore(reset: true)
        } else {
            await loadMine()
        }
    }

    private func loadMore(reset: Bool = false) async {
        guard selectedScope == .all else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.fetchEvents(
                page: page,
                limit: 20,
                search: searchText,
                eventType: selectedEventType.nilIfEmpty
            )
            if reset {
                events = result.items
            } else {
                events.append(contentsOf: result.items)
            }
            totalPages = result.pagination?.totalPages ?? 1
            page += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMine() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            myPublishedEvents = try await service.fetchMyEvents().sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPersonalEventCheckins() async {
        guard appState.session != nil else {
            markedCheckinIDsByEventID = [:]
            markedEvents = []
            plannedCheckinIDsByEventID = [:]
            plannedEvents = []
            return
        }

        do {
            let page = try await service.fetchMyCheckins(page: 1, limit: 200, type: "event")
            let checkins = page.items.filter { ($0.type.lowercased() == "event") && $0.eventId != nil }
            var markedMap: [String: String] = [:]
            var plannedMap: [String: String] = [:]
            for item in checkins {
                guard let eventID = item.eventId else { continue }
                let note = item.note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                if note == "planned" {
                    plannedMap[eventID] = item.id
                } else {
                    // Backward compatible: nil/empty/marked 都视为“标记活动”
                    markedMap[eventID] = item.id
                }
            }

            markedCheckinIDsByEventID = markedMap
            plannedCheckinIDsByEventID = plannedMap
            markedEvents = await fetchEventsByIDs(Array(markedMap.keys))
            plannedEvents = await fetchEventsByIDs(Array(plannedMap.keys))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleMarked(event: WebEvent) async {
        guard appState.session != nil else {
            errorMessage = "请先登录再标记活动"
            return
        }

        do {
            if let checkinID = markedCheckinIDsByEventID[event.id] {
                try await service.deleteCheckin(id: checkinID)
                markedCheckinIDsByEventID[event.id] = nil
                markedEvents.removeAll { $0.id == event.id }
            } else {
                let created = try await service.createCheckin(
                    input: CreateCheckinInput(type: "event", eventId: event.id, djId: nil, note: "marked", rating: nil)
                )
                markedCheckinIDsByEventID[event.id] = created.id
                if !markedEvents.contains(where: { $0.id == event.id }) {
                    markedEvents.insert(event, at: 0)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func togglePlanned(event: WebEvent) async {
        guard appState.session != nil else {
            errorMessage = "请先登录再设置计划前往"
            return
        }

        do {
            if let checkinID = plannedCheckinIDsByEventID[event.id] {
                try await service.deleteCheckin(id: checkinID)
                plannedCheckinIDsByEventID[event.id] = nil
                plannedEvents.removeAll { $0.id == event.id }
            } else {
                let created = try await service.createCheckin(
                    input: CreateCheckinInput(type: "event", eventId: event.id, djId: nil, note: "planned", rating: nil)
                )
                plannedCheckinIDsByEventID[event.id] = created.id
                if !plannedEvents.contains(where: { $0.id == event.id }) {
                    plannedEvents.insert(event, at: 0)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isMarked(_ eventID: String) -> Bool {
        markedCheckinIDsByEventID[eventID] != nil
    }

    private func isPlanned(_ eventID: String) -> Bool {
        plannedCheckinIDsByEventID[eventID] != nil
    }

    private var contentIsEmpty: Bool {
        if selectedScope == .all {
            return events.isEmpty
        }
        return filteredMarkedEvents.isEmpty && filteredPlannedEvents.isEmpty && filteredPublishedEvents.isEmpty
    }

    private var filteredMarkedEvents: [WebEvent] {
        guard !selectedEventType.isEmpty else { return markedEvents }
        return markedEvents.filter { $0.eventType == selectedEventType }
    }

    private var filteredPublishedEvents: [WebEvent] {
        guard !selectedEventType.isEmpty else { return myPublishedEvents }
        return myPublishedEvents.filter { $0.eventType == selectedEventType }
    }

    private var filteredPlannedEvents: [WebEvent] {
        guard !selectedEventType.isEmpty else { return plannedEvents }
        return plannedEvents.filter { $0.eventType == selectedEventType }
    }

    private var eventTypeTabs: [String] {
        let dynamic = Set((events + myPublishedEvents + markedEvents + plannedEvents).compactMap { event in
            let value = event.eventType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : value
        })
        var ordered = Self.predefinedEventTypes
        for value in dynamic.sorted() where !ordered.contains(value) {
            ordered.append(value)
        }
        return ordered
    }

    private var calendarSourceEvents: [WebEvent] {
        var lookup: [String: WebEvent] = [:]
        for event in events + myPublishedEvents + markedEvents + plannedEvents {
            lookup[event.id] = event
        }
        return lookup.values.sorted(by: { $0.startDate < $1.startDate })
    }

    private func fetchEventsByIDs(_ ids: [String]) async -> [WebEvent] {
        guard !ids.isEmpty else { return [] }
        let loaded = await withTaskGroup(of: WebEvent?.self, returning: [WebEvent].self) { group in
            for id in ids.sorted() {
                group.addTask {
                    try? await service.fetchEvent(id: id)
                }
            }
            var result: [WebEvent] = []
            for await item in group {
                if let item {
                    result.append(item)
                }
            }
            return result
        }
        return loaded.sorted(by: { $0.startDate < $1.startDate })
    }

    @ViewBuilder
    private var allEventsContent: some View {
        if events.isEmpty {
            ContentUnavailableView("暂无活动", systemImage: "calendar.badge.plus")
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(events) { event in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                selectedEventForDetail = event
                            } label: {
                                EventRow(event: event)
                            }
                            .buttonStyle(.plain)

                            eventActionButtons(event)
                                .padding(.top, 10)
                                .padding(.trailing, 10)
                        }
                    }

                    if page < totalPages {
                        Button("加载更多") {
                            Task { await loadMore() }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 18)
            }
        }
    }

    @ViewBuilder
    private var myEventsContent: some View {
        if filteredMarkedEvents.isEmpty && filteredPlannedEvents.isEmpty && filteredPublishedEvents.isEmpty {
            ContentUnavailableView("暂无我的活动", systemImage: "bookmark.circle")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !filteredMarkedEvents.isEmpty {
                        sectionHeader("我标记的活动")
                        ForEach(filteredMarkedEvents) { event in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    selectedEventForDetail = event
                                } label: {
                                    EventRow(event: event)
                                }
                                .buttonStyle(.plain)

                                eventActionButtons(event)
                                    .padding(.top, 10)
                                    .padding(.trailing, 10)
                            }
                        }
                    }

                    if !filteredPlannedEvents.isEmpty {
                        sectionHeader("我计划前往")
                        ForEach(filteredPlannedEvents) { event in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    selectedEventForDetail = event
                                } label: {
                                    EventRow(event: event)
                                }
                                .buttonStyle(.plain)

                                eventActionButtons(event)
                                    .padding(.top, 10)
                                    .padding(.trailing, 10)
                            }
                        }
                    }

                    if !filteredPublishedEvents.isEmpty {
                        sectionHeader("我发布的活动")
                        ForEach(filteredPublishedEvents) { event in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    selectedEventForDetail = event
                                } label: {
                                    EventRow(event: event)
                                }
                                .buttonStyle(.plain)

                                eventActionButtons(event)
                                    .padding(.top, 10)
                                    .padding(.trailing, 10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 18)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(RaverTheme.primaryText)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private func eventTypeChip(title: String, value: String) -> some View {
        let isSelected = selectedEventType == value
        return Button {
            selectedEventType = value
        } label: {
            Text(title)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white : RaverTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? RaverTheme.accent : RaverTheme.card)
                )
        }
        .buttonStyle(.plain)
    }

    private var myEventsScopeChip: some View {
        let isSelected = selectedScope == .mine
        return Button {
            selectedScope = isSelected ? .all : .mine
        } label: {
            Image(systemName: "person.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : RaverTheme.secondaryText)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isSelected ? RaverTheme.accent : RaverTheme.card)
                )
        }
        .buttonStyle(.plain)
    }

    private func eventActionButtons(_ event: WebEvent) -> some View {
        VStack(spacing: 8) {
            Button {
                Task { await toggleMarked(event: event) }
            } label: {
                Image(systemName: isMarked(event.id) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isMarked(event.id) ? .white : RaverTheme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(isMarked(event.id) ? RaverTheme.accent : RaverTheme.card.opacity(0.92))
                    )
            }
            .buttonStyle(.plain)

            Button {
                Task { await togglePlanned(event: event) }
            } label: {
                Image(systemName: isPlanned(event.id) ? "paperplane.fill" : "paperplane")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isPlanned(event.id) ? .white : RaverTheme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(isPlanned(event.id) ? Color.blue : RaverTheme.card.opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct EventRow: View {
    let event: WebEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if let cover = AppConfig.resolvedURLString(event.coverImageUrl),
                   let url = URL(string: cover) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(RaverTheme.card)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(RaverTheme.card)
                        @unknown default:
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(RaverTheme.card)
                        }
                    }
                } else {
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
                }
                VStack(spacing: 0) {
                    Text(event.startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(event.startDate.formatted(.dateTime.day()))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RaverTheme.primaryText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(8)

                if let statusLabel {
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.55))
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(8)
                }
            }
            .frame(width: 132, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 6) {
                    Text(event.name)
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)
                    if event.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                    }
                }

                if let description = event.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(2)
                }

                if let eventType = event.eventType, !eventType.isEmpty {
                    Text(eventType)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RaverTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(RaverTheme.accent.opacity(0.15))
                        )
                }

                Label(event.startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)

                if let venue = event.venueName, !venue.isEmpty {
                    Label(venue, systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                if !event.summaryLocation.isEmpty {
                    Label(event.summaryLocation, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                if let priceText = priceRangeText {
                    Label(priceText, systemImage: "ticket")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 38)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    private var priceRangeText: String? {
        guard event.ticketPriceMin != nil || event.ticketPriceMax != nil else { return nil }
        let currency = event.ticketCurrency ?? "CNY"
        let minText = event.ticketPriceMin.map { String(Int($0)) } ?? "-"
        let maxText = event.ticketPriceMax.map { String(Int($0)) }
        if let maxText {
            return "\(currency) \(minText)-\(maxText)"
        }
        return "\(currency) \(minText)"
    }

    private var statusLabel: String? {
        guard let status = event.status?.lowercased(), !status.isEmpty else { return nil }
        switch status {
        case "upcoming":
            return "即将开始"
        case "ongoing":
            return "进行中"
        case "ended":
            return "已结束"
        default:
            return status
        }
    }
}

private struct EventCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss

    let events: [WebEvent]
    let markedEventIDs: Set<String>
    let plannedEventIDs: Set<String>
    @Binding var selectedDate: Date
    @Binding var selectedFilters: Set<EventCalendarViewFilter>
    let onEventSelected: (WebEvent) -> Void

    @State private var displayedMonth: Date
    private let calendar = Calendar.current

    init(
        events: [WebEvent],
        markedEventIDs: Set<String>,
        plannedEventIDs: Set<String>,
        selectedDate: Binding<Date>,
        selectedFilters: Binding<Set<EventCalendarViewFilter>>,
        onEventSelected: @escaping (WebEvent) -> Void
    ) {
        self.events = events
        self.markedEventIDs = markedEventIDs
        self.plannedEventIDs = plannedEventIDs
        _selectedDate = selectedDate
        _selectedFilters = selectedFilters
        self.onEventSelected = onEventSelected
        _displayedMonth = State(initialValue: Calendar.current.startOfMonth(for: selectedDate.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("活动日历")
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

                        Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
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
                        Text(selectedDate.formatted(.dateTime.year().month().day()))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)
                        Spacer()
                        Text("共 \(eventsOnSelectedDay.count) 场")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if eventsOnSelectedDay.isEmpty {
                        ContentUnavailableView("当日暂无活动", systemImage: "calendar")
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
                                                    tag("标记", color: RaverTheme.accent)
                                                }
                                                if plannedEventIDs.contains(event.id) {
                                                    tag("计划", color: Color.blue)
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
                (filters.contains(.marked) && markedEventIDs.contains(event.id))
                    || (filters.contains(.planned) && plannedEventIDs.contains(event.id))
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
        let hasPlanned = dayEvents.contains(where: { plannedEventIDs.contains($0.id) })
        var markers: [Color] = []
        markers.append(RaverTheme.accent)
        if hasMarked { markers.append(Color.orange) }
        if hasPlanned { markers.append(Color.blue) }
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
        if let cover = AppConfig.resolvedURLString(event.coverImageUrl), let url = URL(string: cover) {
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

private struct EventSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onApply: (String) -> Void

    init(initialText: String, onApply: @escaping (String) -> Void) {
        _text = State(initialValue: initialText)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("活动名称、城市或关键词", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .navigationTitle("搜索活动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("搜索") {
                        onApply(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    private let service = AppEnvironment.makeWebService()

    let eventID: String

    private struct EventLineupDJEntry: Identifiable, Hashable {
        let id: String
        let name: String
        let avatarUrl: String?
        let djID: String?
    }

    @State private var event: WebEvent?
    @State private var isLoading = false
    @State private var showEdit = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading, event == nil {
                ProgressView("加载活动详情...")
            } else if let event {
                ScrollView {
                    VStack(spacing: 0) {
                        heroSection(event)

                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 10) {
                                Button {
                                    Task { await checkin() }
                                } label: {
                                    Label("标记活动", systemImage: "bookmark.fill")
                                }
                                .buttonStyle(.borderedProminent)

                                if let ticketURL = event.ticketUrl, let url = URL(string: ticketURL) {
                                    Link(destination: url) {
                                        Label("前往购票", systemImage: "ticket")
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Spacer()

                                if isMine(event) {
                                    Button("编辑") {
                                        showEdit = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("活动信息")
                                        .font(.headline)
                                        .foregroundStyle(RaverTheme.primaryText)

                                    infoLine(icon: "calendar", text: "开始：\(event.startDate.formatted(date: .complete, time: .shortened))")
                                    infoLine(icon: "clock", text: "结束：\(event.endDate.formatted(date: .complete, time: .shortened))")

                                    if let status = event.status, !status.isEmpty {
                                        HStack(spacing: 8) {
                                            Image(systemName: "dot.radiowaves.up.forward")
                                                .foregroundStyle(RaverTheme.secondaryText)
                                            Text("状态：\(statusLabel(status))")
                                                .foregroundStyle(RaverTheme.secondaryText)
                                                .font(.subheadline)
                                        }
                                    }

                                    if let venue = event.venueName, !venue.isEmpty {
                                        infoLine(icon: "building.2", text: venue)
                                    }
                                    if let address = event.venueAddress, !address.isEmpty {
                                        infoLine(icon: "map", text: address)
                                    }
                                    if !event.summaryLocation.isEmpty {
                                        infoLine(icon: "mappin.and.ellipse", text: event.summaryLocation)
                                    }
                                    if let website = event.officialWebsite, !website.isEmpty {
                                        infoLine(icon: "globe", text: website)
                                    }
                                }
                            }

                            if let description = event.description, !description.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("活动介绍")
                                        .font(.headline)
                                    Text(description)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                            }

                            if let lineupImage = AppConfig.resolvedURLString(event.lineupImageUrl),
                               let lineupURL = URL(string: lineupImage) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("活动阵容图")
                                        .font(.headline)
                                    AsyncImage(url: lineupURL) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(maxWidth: .infinity, minHeight: 180)
                                                .background(RaverTheme.card)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: .infinity)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        case .failure:
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(RaverTheme.card)
                                                .frame(maxWidth: .infinity, minHeight: 180)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .foregroundStyle(RaverTheme.secondaryText)
                                                )
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }

                                    lineupDJsStrip(for: event)
                                }
                            }

                            if !event.lineupSlots.isEmpty {
                                NavigationLink {
                                    EventRoutineView(event: event)
                                } label: {
                                    HStack {
                                        Label("查看日程（\(event.lineupSlots.count) 场）", systemImage: "calendar.badge.clock")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
                                }
                            }

                            if !event.ticketTiers.isEmpty || ((event.ticketNotes ?? "").isEmpty == false) {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("票档信息")
                                            .font(.headline)
                                        ForEach(event.ticketTiers) { tier in
                                            HStack {
                                                Text(tier.name)
                                                Spacer()
                                                Text("\(tier.currency ?? event.ticketCurrency ?? "CNY") \(Int(tier.price ?? 0))")
                                                    .foregroundStyle(RaverTheme.secondaryText)
                                            }
                                            .font(.subheadline)
                                        }
                                        if let notes = event.ticketNotes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.subheadline)
                                                .foregroundStyle(RaverTheme.secondaryText)
                                        }
                                    }
                                }
                            }

                            if let organizer = event.organizer {
                                NavigationLink {
                                    UserProfileView(userID: organizer.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(
                                            AppConfig.resolvedUserAvatarAssetName(
                                                userID: organizer.id,
                                                username: organizer.username,
                                                avatarURL: organizer.avatarUrl
                                            )
                                        )
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .background(RaverTheme.card)
                                        .clipShape(Circle())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("发布方")
                                                .font(.caption)
                                                .foregroundStyle(RaverTheme.secondaryText)
                                            Text(organizer.displayName ?? organizer.username)
                                                .font(.subheadline)
                                                .foregroundStyle(RaverTheme.primaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 2)
                            } else if let organizerName = event.organizerName, !organizerName.isEmpty {
                                infoLine(icon: "person.2", text: "发布方：\(organizerName)")
                            }

                            if isMine(event) {
                                Button(role: .destructive) {
                                    Task { await deleteEvent() }
                                } label: {
                                    Text("删除活动")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
                .sheet(isPresented: $showEdit) {
                    EventEditorView(mode: .edit(event)) {
                        Task { await load() }
                    }
                }
            } else {
                ContentUnavailableView("活动不存在", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            floatingDismissButton
        }
        .task {
            await load()
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func isMine(_ event: WebEvent) -> Bool {
        event.organizer?.id == appState.session?.user.id
    }

    private func heroSection(_ event: WebEvent) -> some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    RaverTheme.card
                    if let cover = AppConfig.resolvedURLString(event.coverImageUrl), let url = URL(string: cover) {
                        AsyncImage(url: url, transaction: Transaction(animation: .none)) { phase in
                            switch phase {
                            case .empty:
                                RaverTheme.card
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            case .failure:
                                RaverTheme.card
                            @unknown default:
                                RaverTheme.card
                            }
                        }
                    } else {
                        LinearGradient(
                            colors: [RaverTheme.accent.opacity(0.35), RaverTheme.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.42), RaverTheme.background.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    Text(event.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 85)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
        .zIndex(1)
    }

    private var floatingDismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .padding(.leading, 12)
        .padding(.top, topSafeAreaInset() + 10)
        .zIndex(10)
    }

    @ViewBuilder
    private func lineupDJsStrip(for event: WebEvent) -> some View {
        let djs = lineupDJEntries(for: event)
        if !djs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("参演 DJ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(djs) { dj in
                            lineupDJAvatarItem(dj)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func lineupDJAvatarItem(_ dj: EventLineupDJEntry) -> some View {
        let content = VStack(spacing: 6) {
            if let avatar = AppConfig.resolvedURLString(dj.avatarUrl), let url = URL(string: avatar) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(RaverTheme.card)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Circle().fill(RaverTheme.card)
                    @unknown default:
                        Circle().fill(RaverTheme.card)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(RaverTheme.card)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(dj.name.prefix(1)).uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(RaverTheme.secondaryText)
                    )
            }

            Text(dj.name)
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)
                .frame(width: 70)
        }

        if let djID = dj.djID, !djID.isEmpty {
            NavigationLink {
                DJDetailView(djID: djID)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func lineupDJEntries(for event: WebEvent) -> [EventLineupDJEntry] {
        var seen = Set<String>()
        var result: [EventLineupDJEntry] = []

        for slot in event.lineupSlots.sorted(by: { $0.startTime < $1.startTime }) {
            if let dj = slot.dj {
                let key = "dj-\(dj.id)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                result.append(EventLineupDJEntry(id: key, name: dj.name, avatarUrl: dj.avatarUrl, djID: dj.id))
                continue
            }

            let trimmedName = slot.djName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let fallbackID = slot.djId?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedFallbackID = (fallbackID?.isEmpty == false) ? fallbackID : nil
            let key = "name-\((resolvedFallbackID ?? trimmedName.lowercased()))"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(EventLineupDJEntry(id: key, name: trimmedName, avatarUrl: nil, djID: resolvedFallbackID))
        }

        return result
    }

    private func infoLine(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(RaverTheme.secondaryText)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "upcoming":
            return "即将开始"
        case "ongoing":
            return "进行中"
        case "ended":
            return "已结束"
        default:
            return status
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            event = try await service.fetchEvent(id: eventID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkin() async {
        do {
            _ = try await service.createCheckin(input: CreateCheckinInput(type: "event", eventId: eventID, djId: nil, note: nil, rating: nil))
            errorMessage = "打卡成功"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEvent() async {
        do {
            try await service.deleteEvent(id: eventID)
            errorMessage = "活动已删除，请返回列表刷新"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EventRoutineView: View {
    let event: WebEvent

    private struct DayStageGroup: Identifiable {
        let id: String
        let dayLabel: String
        let stageName: String
        let slots: [WebEventLineupSlot]
    }

    private var grouped: [DayStageGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var map: [String: [String: [WebEventLineupSlot]]] = [:]
        for slot in event.lineupSlots {
            let dayKey = formatter.string(from: slot.startTime)
            let stage = (slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? slot.stageName!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "未命名舞台"
            map[dayKey, default: [:]][stage, default: []].append(slot)
        }

        return map
            .sorted(by: { $0.key < $1.key })
            .flatMap { dayKey, stageMap in
                stageMap.sorted(by: { $0.key < $1.key }).map { stageName, slots in
                    DayStageGroup(
                        id: "\(dayKey)-\(stageName)",
                        dayLabel: dayKey,
                        stageName: stageName,
                        slots: slots.sorted(by: { $0.startTime < $1.startTime })
                    )
                }
            }
    }

    var body: some View {
        List {
            if grouped.isEmpty {
                ContentUnavailableView("暂无排期", systemImage: "calendar.badge.exclamationmark")
            }

            ForEach(grouped) { group in
                Section("\(group.dayLabel) · \(group.stageName)") {
                    ForEach(group.slots) { slot in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slot.dj?.name ?? slot.djName)
                                .font(.headline)
                            Text("\(slot.startTime.formatted(date: .omitted, time: .shortened)) - \(slot.endTime.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("活动日程")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EventEditorView: View {
    enum Mode {
        case create
        case edit(WebEvent)

        var title: String {
            switch self {
            case .create: return "发布活动"
            case .edit: return "编辑活动"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let mode: Mode
    let onSaved: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var city = ""
    @State private var country = ""
    @State private var venueName = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7200)
    @State private var coverImageUrl = ""
    @State private var lineupImageUrl = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedLineupPhoto: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("活动名称", text: $name)
                    TextField("简介", text: $description, axis: .vertical)
                    TextField("城市", text: $city)
                    TextField("国家", text: $country)
                    TextField("场地", text: $venueName)
                }

                Section("时间") {
                    DatePicker("开始时间", selection: $startDate)
                    DatePicker("结束时间", selection: $endDate)
                }

                Section("图片") {
                    TextField("封面 URL", text: $coverImageUrl)
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label("上传封面图", systemImage: "photo")
                    }

                    TextField("活动阵容图 URL", text: $lineupImageUrl)
                    PhotosPicker(selection: $selectedLineupPhoto, matching: .images) {
                        Label("上传活动阵容图", systemImage: "photo.on.rectangle")
                    }
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                prefillIfNeeded()
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func prefillIfNeeded() {
        guard case .edit(let event) = mode else { return }
        if !name.isEmpty { return }

        name = event.name
        description = event.description ?? ""
        city = event.city ?? ""
        country = event.country ?? ""
        venueName = event.venueName ?? ""
        startDate = event.startDate
        endDate = event.endDate
        coverImageUrl = event.coverImageUrl ?? ""
        lineupImageUrl = event.lineupImageUrl ?? ""
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "请输入活动名称"
            return
        }

        if endDate < startDate {
            errorMessage = "结束时间不能早于开始时间"
            return
        }

        isSaving = true
        defer { isSaving = false }

        var finalCover = coverImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        var finalLineup = lineupImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let selectedCoverPhoto,
               let data = try await selectedCoverPhoto.loadTransferable(type: Data.self) {
                let upload = try await service.uploadEventImage(
                    imageData: data,
                    fileName: "event-cover-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalCover = upload.url
            }

            if let selectedLineupPhoto,
               let data = try await selectedLineupPhoto.loadTransferable(type: Data.self) {
                let upload = try await service.uploadEventImage(
                    imageData: data,
                    fileName: "event-lineup-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalLineup = upload.url
            }

            switch mode {
            case .create:
                _ = try await service.createEvent(
                    input: CreateEventInput(
                        name: trimmedName,
                        description: description.nilIfEmpty,
                        city: city.nilIfEmpty,
                        country: country.nilIfEmpty,
                        venueName: venueName.nilIfEmpty,
                        startDate: startDate,
                        endDate: endDate,
                        coverImageUrl: finalCover.nilIfEmpty,
                        lineupImageUrl: finalLineup.nilIfEmpty,
                        status: "upcoming"
                    )
                )
            case .edit(let event):
                _ = try await service.updateEvent(
                    id: event.id,
                    input: UpdateEventInput(
                        name: trimmedName,
                        description: description.nilIfEmpty,
                        city: city.nilIfEmpty,
                        country: country.nilIfEmpty,
                        venueName: venueName.nilIfEmpty,
                        startDate: startDate,
                        endDate: endDate,
                        coverImageUrl: finalCover.nilIfEmpty,
                        lineupImageUrl: finalLineup.nilIfEmpty,
                        status: event.status
                    )
                )
            }

            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DJsModuleView: View {
    private let service = AppEnvironment.makeWebService()

    @State private var djs: [WebDJ] = []
    @State private var rankingBoards: [RankingBoard] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSection: DJsModuleSection = .hot
    @State private var searchText = ""
    @State private var selectedDJForDetail: WebDJ?
    @State private var selectedBoardForDetail: RankingBoard?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: selectedSection == .rankings) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DJsModuleSection.allCases, id: \.self) { item in
                                    Button(item.title) {
                                        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.84)) {
                                            selectedSection = item
                                        }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedSection == item ? RaverTheme.accent : RaverTheme.card)
                                    .foregroundStyle(selectedSection == item ? Color.white : RaverTheme.primaryText)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scrollClipDisabled()
                        .defaultScrollAnchor(.leading)

                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(RaverTheme.secondaryText)
                            TextField("搜索", text: $searchText)
                                .font(.subheadline)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(width: 136)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if selectedSection == .hot {
                        if isLoading && filteredDJs.isEmpty {
                            ProgressView("加载中...")
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else if filteredDJs.isEmpty {
                            ContentUnavailableView("暂无 DJ", systemImage: "music.mic")
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else if !trimmedSearchText.isEmpty {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(filteredDJs) { dj in
                                    Button {
                                        selectedDJForDetail = dj
                                    } label: {
                                        DJSearchResultCard(dj: dj)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            DJWebMarqueeWall(rows: marqueeRows) { tapped in
                                selectedDJForDetail = tapped
                            }
                            .frame(height: marqueeWallHeight)
                            .padding(.horizontal, -16)
                        }
                    } else {
                        if isLoading && filteredRankingBoards.isEmpty {
                            ProgressView("加载榜单中...")
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else if filteredRankingBoards.isEmpty {
                            ContentUnavailableView("暂无榜单", systemImage: "list.number")
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(filteredRankingBoards) { board in
                                    Button {
                                        selectedBoardForDetail = board
                                    } label: {
                                        RankingBoardCoverCard(board: board)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, topContentInset)
                .padding(.bottom, 16)
            }
            .scrollDisabled(selectedSection == .hot)
            .background(RaverTheme.background)
            .task {
                await load()
            }
            .refreshable {
                await load()
            }
            .fullScreenCover(item: $selectedDJForDetail) { dj in
                NavigationStack {
                    DJDetailView(djID: dj.id)
                }
            }
            .navigationDestination(item: $selectedBoardForDetail) { board in
                RankingBoardDetailView(board: board)
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredDJs: [WebDJ] {
        guard !trimmedSearchText.isEmpty else { return djs }
        let keyword = trimmedSearchText.lowercased()
        return djs.filter { item in
            item.name.lowercased().contains(keyword)
                || (item.country?.lowercased().contains(keyword) ?? false)
        }
    }

    private var filteredRankingBoards: [RankingBoard] {
        guard !trimmedSearchText.isEmpty else { return rankingBoards }
        let keyword = trimmedSearchText.lowercased()
        return rankingBoards.filter { board in
            board.title.lowercased().contains(keyword)
                || (board.subtitle?.lowercased().contains(keyword) ?? false)
        }
    }

    private var marqueeRows: [[WebDJ]] {
        let pool = Array(filteredDJs.prefix(40))
        guard !pool.isEmpty else { return [] }

        return (0..<4).map { mod in
            let row = pool.enumerated().compactMap { index, item in
                index % 4 == mod ? item : nil
            }
            return row.isEmpty ? Array(pool.prefix(8)) : row
        }
    }

    private var topContentInset: CGFloat {
        selectedSection == .hot ? 14 : 8
    }

    private var marqueeWallHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        switch screenHeight {
        case ..<700:
            return 420
        case ..<800:
            return 470
        case ..<900:
            return 520
        default:
            return 560
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            errorMessage = nil
            async let djsTask = service.fetchDJs(page: 1, limit: 60, search: nil, sortBy: "followerCount")
            async let boardsTask = service.fetchRankingBoards()
            djs = (try await djsTask).items
            rankingBoards = try await boardsTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum DJsModuleSection: CaseIterable {
    case hot
    case rankings

    var title: String {
        switch self {
        case .hot: return "热度 DJ"
        case .rankings: return "榜单"
        }
    }
}

private struct RankingBoardCoverCard: View {
    let board: RankingBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let coverImageUrl = board.coverImageUrl, let url = URL(string: coverImageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                boardFallbackCover
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                boardFallbackCover
                            @unknown default:
                                boardFallbackCover
                            }
                        }
                    } else {
                        boardFallbackCover
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                Text(board.yearsText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.white)
                    .padding(10)
            }
            .frame(height: 162)

            VStack(alignment: .leading, spacing: 6) {
                Text(board.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Text(board.subtitle ?? board.defaultSubtitle)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .topLeading)
                Text("进入榜单详情")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.32, green: 0.66, blue: 0.98))
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .topLeading)
        }
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(height: 254)
    }

    private var boardFallbackCover: some View {
        ZStack {
            boardGradient
            Circle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 90, height: 90)
                .blur(radius: 8)
                .offset(x: 36, y: -24)
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 120, height: 120)
                .blur(radius: 10)
                .offset(x: -44, y: 42)
            Text(board.shortMark)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }

    private var boardGradient: LinearGradient {
        switch board.id {
        case "djmag":
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.20, blue: 0.33), Color(red: 0.52, green: 0.12, blue: 0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "dongye":
            return LinearGradient(
                colors: [Color(red: 0.17, green: 0.53, blue: 0.98), Color(red: 0.11, green: 0.77, blue: 0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(red: 0.35, green: 0.35, blue: 0.40), Color(red: 0.15, green: 0.17, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct DJWebMarqueeWall: View {
    let rows: [[WebDJ]]
    let onSelect: (WebDJ) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = DJWebMarqueeMetrics.make(containerHeight: proxy.size.height, rowCount: max(1, rows.count))

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.04, blue: 0.08), Color(red: 0.02, green: 0.06, blue: 0.13), Color(red: 0.03, green: 0.02, blue: 0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.cyan.opacity(0.22))
                    .frame(width: metrics.glowPrimarySize, height: metrics.glowPrimarySize)
                    .blur(radius: metrics.glowPrimaryBlur)
                    .offset(x: -metrics.glowPrimaryOffsetX, y: -metrics.glowPrimaryOffsetY)

                Circle()
                    .fill(Color.purple.opacity(0.24))
                    .frame(width: metrics.glowSecondarySize, height: metrics.glowSecondarySize)
                    .blur(radius: metrics.glowSecondaryBlur)
                    .offset(x: metrics.glowSecondaryOffsetX, y: metrics.glowSecondaryOffsetY)

                VStack(spacing: metrics.rowSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        DJWebMarqueeRow(
                            items: row,
                            reverse: index % 2 == 1,
                            speed: speed(for: index),
                            rowHeight: metrics.rowHeight,
                            avatarSize: metrics.avatarSize,
                            avatarHorizontalSpacing: metrics.avatarHorizontalSpacing,
                            onSelect: onSelect
                        )
                    }
                }
                .padding(.top, metrics.topInset)
            }
        }
    }

    private struct DJWebMarqueeMetrics {
        let avatarSize: CGFloat
        let avatarHorizontalSpacing: CGFloat
        let rowHeight: CGFloat
        let rowSpacing: CGFloat
        let topInset: CGFloat
        let glowPrimarySize: CGFloat
        let glowPrimaryBlur: CGFloat
        let glowPrimaryOffsetX: CGFloat
        let glowPrimaryOffsetY: CGFloat
        let glowSecondarySize: CGFloat
        let glowSecondaryBlur: CGFloat
        let glowSecondaryOffsetX: CGFloat
        let glowSecondaryOffsetY: CGFloat

        static func make(containerHeight: CGFloat, rowCount: Int) -> DJWebMarqueeMetrics {
            let safeHeight = max(360, containerHeight)
            let avatar = max(54, min(74, safeHeight / 8.4))
            let rowHeight = avatar + 26
            let estimatedSpacing = (safeHeight - CGFloat(rowCount) * rowHeight - 20) / CGFloat(max(1, rowCount - 1))
            let rowSpacing = max(8, min(26, estimatedSpacing))
            let topInset = max(10, min(20, safeHeight * 0.03))
            return DJWebMarqueeMetrics(
                avatarSize: avatar,
                avatarHorizontalSpacing: max(6, min(12, avatar * 0.13)),
                rowHeight: rowHeight,
                rowSpacing: rowSpacing,
                topInset: topInset,
                glowPrimarySize: max(180, min(260, safeHeight * 0.42)),
                glowPrimaryBlur: max(60, min(86, safeHeight * 0.15)),
                glowPrimaryOffsetX: 110,
                glowPrimaryOffsetY: 96,
                glowSecondarySize: max(220, min(320, safeHeight * 0.52)),
                glowSecondaryBlur: max(70, min(98, safeHeight * 0.17)),
                glowSecondaryOffsetX: 132,
                glowSecondaryOffsetY: 152
            )
        }
    }

    private func speed(for rowIndex: Int) -> Double {
        switch rowIndex {
        case 0: return 34
        case 1: return 40
        case 2: return 36
        default: return 44
        }
    }
}

private struct DJWebMarqueeRow: View {
    let items: [WebDJ]
    let reverse: Bool
    let speed: Double
    let rowHeight: CGFloat
    let avatarSize: CGFloat
    let avatarHorizontalSpacing: CGFloat
    let onSelect: (WebDJ) -> Void

    @State private var rowWidth: CGFloat = 1

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let travel = CGFloat((elapsed * speed).truncatingRemainder(dividingBy: Double(max(rowWidth, 1))))
                let offset = reverse ? (-rowWidth + travel) : -travel

                HStack(spacing: 0) {
                    rowContent
                    rowContent
                }
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: offset)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: DJWebMarqueeWidthKey.self, value: proxy.size.width / 2.0)
                    }
                )
                .onPreferenceChange(DJWebMarqueeWidthKey.self) { value in
                    if value > 1 {
                        rowWidth = value
                    }
                }
            }
        }
        .frame(height: rowHeight)
        .clipped()
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                ForEach(items) { dj in
                    Button {
                        onSelect(dj)
                    } label: {
                        DJWebAvatar(dj: dj, size: avatarSize)
                            .padding(.horizontal, avatarHorizontalSpacing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DJWebAvatar: View {
    let dj: WebDJ
    let size: CGFloat

    var body: some View {
        Group {
            if let avatar = AppConfig.resolvedURLString(dj.avatarUrl),
               let url = URL(string: lowResAvatarURL(avatar)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.34), radius: 10, y: 4)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.42, green: 0.22, blue: 0.78), Color(red: 0.15, green: 0.45, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials(of: dj.name))
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
    }
}

private struct DJWebCard: View {
    static let cardWidth: CGFloat = 168

    let dj: WebDJ
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                cover
                    .frame(width: Self.cardWidth, height: Self.cardWidth)
                    .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(dj.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if dj.isVerified == true {
                            Text("✓")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.green)
                        }
                    }

                    if let bio = dj.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(2)
                    }

                    if let country = dj.country, !country.isEmpty {
                        Label(country, systemImage: "globe")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Label("\(dj.followerCount ?? 0) 粉丝", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if dj.spotifyId != nil {
                            tag("Spotify", color: .green)
                        }
                        if dj.soundcloudUrl != nil {
                            tag("SoundCloud", color: .blue)
                        }
                        if dj.instagramUrl != nil {
                            tag("Instagram", color: .pink)
                        }
                    }
                    .lineLimit(1)
                }
                .padding(12)
                .frame(height: 170, alignment: .topLeading)
            }
            .frame(width: Self.cardWidth, height: Self.cardWidth + 170)
            .background(RaverTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var cover: some View {
        Group {
            if let avatar = AppConfig.resolvedURLString(dj.avatarUrl),
               let url = URL(string: highResAvatarURL(avatar)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackCover
                    }
                }
            } else {
                fallbackCover
            }
        }
    }

    private var fallbackCover: some View {
        LinearGradient(
            colors: [Color(red: 0.42, green: 0.22, blue: 0.78), Color(red: 0.15, green: 0.45, blue: 1.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text("🎧")
                .font(.system(size: 52))
        )
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct DJWebMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private func initials(of name: String) -> String {
    let parts = name.split(separator: " ").prefix(2)
    if parts.isEmpty {
        return String(name.prefix(2)).uppercased()
    }
    return parts.compactMap { $0.first }.map(String.init).joined().uppercased()
}

private func lowResAvatarURL(_ url: String) -> String {
    url
        .replacingOccurrences(of: "ab6761610000e5eb", with: "ab6761610000f178")
        .replacingOccurrences(of: "ab67616100005174", with: "ab6761610000f178")
        .replacingOccurrences(of: "ab67616d0000b273", with: "ab67616d00004851")
        .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d00004851")
}

private func highResAvatarURL(_ url: String) -> String {
    url
        .replacingOccurrences(of: "ab6761610000f178", with: "ab6761610000e5eb")
        .replacingOccurrences(of: "ab67616100005174", with: "ab6761610000e5eb")
        .replacingOccurrences(of: "ab67616d00004851", with: "ab67616d0000b273")
        .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273")
}

private struct DJDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    private let service = AppEnvironment.makeWebService()

    let djID: String

    @State private var dj: WebDJ?
    @State private var sets: [WebDJSet] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading, dj == nil {
                ProgressView("加载 DJ 详情...")
            } else if let dj {
                ScrollView {
                    VStack(spacing: 0) {
                        heroSection(dj)

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Button((dj.isFollowing ?? false) ? "已关注" : "关注") {
                                    Task { await toggleFollow(dj) }
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    Task { await checkin() }
                                } label: {
                                    Label("DJ 打卡", systemImage: "checkmark.seal")
                                }
                                .buttonStyle(.bordered)
                            }

                            HStack(spacing: 14) {
                                infoPill(icon: "person.2", text: "\(dj.followerCount ?? 0) 粉丝")
                                if let country = dj.country, !country.isEmpty {
                                    infoPill(icon: "globe", text: country)
                                }
                                if dj.isVerified == true {
                                    infoPill(icon: "checkmark.seal.fill", text: "认证")
                                }
                            }

                            if let bio = dj.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }

                            socialLinks(dj)

                            Text("DJ Sets")
                                .font(.title3.bold())
                                .padding(.top, 4)

                            if sets.isEmpty {
                                Text("暂无内容")
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .padding(.vertical, 6)
                            } else {
                                ForEach(sets) { set in
                                    NavigationLink {
                                        DJSetDetailView(setID: set.id)
                                    } label: {
                                        setRow(set)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
            } else {
                ContentUnavailableView("DJ 不存在", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            floatingDismissButton
        }
        .task {
            await load()
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let djTask = service.fetchDJ(id: djID)
            async let setsTask = service.fetchDJSets(djID: djID)
            dj = try await djTask
            sets = try await setsTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFollow(_ item: WebDJ) async {
        do {
            dj = try await service.toggleDJFollow(djID: item.id, shouldFollow: !(item.isFollowing ?? false))
            await appState.refreshUnreadMessages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkin() async {
        do {
            _ = try await service.createCheckin(input: CreateCheckinInput(type: "dj", eventId: nil, djId: djID, note: nil, rating: nil))
            errorMessage = "打卡成功"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func heroSection(_ dj: WebDJ) -> some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    RaverTheme.card
                    if let imageURL = heroImageURL(for: dj), let url = URL(string: imageURL) {
                        AsyncImage(
                            url: url,
                            transaction: Transaction(animation: .none)
                        ) { phase in
                            switch phase {
                            case .empty:
                                RaverTheme.card
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            case .failure:
                                RaverTheme.card
                            @unknown default:
                                RaverTheme.card
                            }
                        }
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.22, blue: 0.78), Color(red: 0.15, green: 0.45, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.40), RaverTheme.background.opacity(0.80)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    Text(dj.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 85)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
        .zIndex(1)
    }

    private var floatingDismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .padding(.leading, 12)
        .padding(.top, topSafeAreaInset() + 10)
        .zIndex(10)
    }

    private func heroImageURL(for dj: WebDJ) -> String? {
        if let avatar = AppConfig.resolvedURLString(dj.avatarUrl), !avatar.isEmpty {
            return highResAvatarURL(avatar)
        }
        if let banner = AppConfig.resolvedURLString(dj.bannerUrl), !banner.isEmpty {
            return highResAvatarURL(banner)
        }
        return nil
    }

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(RaverTheme.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(RaverTheme.card)
        )
    }

    @ViewBuilder
    private func socialLinks(_ dj: WebDJ) -> some View {
        HStack(spacing: 8) {
            if let spotifyID = dj.spotifyId, !spotifyID.isEmpty {
                Button {
                    openURL(URL(string: "https://open.spotify.com/artist/\(spotifyID)")!)
                } label: {
                    socialChip("Spotify", color: .green)
                }
                .buttonStyle(.plain)
            }
            if let ig = dj.instagramUrl, let url = URL(string: ig) {
                Button {
                    openURL(url)
                } label: {
                    socialChip("Instagram", color: .pink)
                }
                .buttonStyle(.plain)
            }
            if let sc = dj.soundcloudUrl, let url = URL(string: sc) {
                Button {
                    openURL(url)
                } label: {
                    socialChip("SoundCloud", color: .orange)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func socialChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.15))
            )
    }

    private func setRow(_ set: WebDJSet) -> some View {
        HStack(spacing: 10) {
            setCover(set)
                .frame(width: 116, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(set.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                Text(set.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                if let venue = set.venue, !venue.isEmpty {
                    Text(venue)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    @ViewBuilder
    private func setCover(_ set: WebDJSet) -> some View {
        if let thumbnail = AppConfig.resolvedURLString(set.thumbnailUrl), let url = URL(string: thumbnail) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RaverTheme.card
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    RaverTheme.card
                @unknown default:
                    RaverTheme.card
                }
            }
        } else {
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.16, blue: 0.19), Color(red: 0.12, green: 0.12, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.title3)
                    .foregroundStyle(RaverTheme.secondaryText)
            )
        }
    }
}

struct SetsModuleView: View {
    private let service = AppEnvironment.makeWebService()
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    @State private var sets: [WebDJSet] = []
    @State private var page = 1
    @State private var totalPages = 1
    @State private var sortBy = "latest"
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var errorMessage: String?
    @State private var selectedSetForPlayback: WebDJSet?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && displayedSets.isEmpty {
                    ProgressView("Sets 加载中...")
                } else if displayedSets.isEmpty {
                    ContentUnavailableView(searchTextTrimmed.isEmpty ? "暂无 Sets" : "未找到匹配 Sets", systemImage: "waveform.path.ecg")
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(displayedSets) { set in
                                Button {
                                    selectedSetForPlayback = set
                                } label: {
                                    DJSetGridCard(set: set)
                                }
                                .buttonStyle(.plain)
                            }

                            if page < totalPages, searchTextTrimmed.isEmpty {
                                Button("加载更多") {
                                    Task { await loadMore() }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .gridCellColumns(2)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        TextField("搜索 Sets / DJ", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.primaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Menu {
                        Button("最新") {
                            sortBy = "latest"
                            Task { await reload() }
                        }
                        Button("热门") {
                            sortBy = "popular"
                            Task { await reload() }
                        }
                        Button("Tracks") {
                            sortBy = "tracks"
                            Task { await reload() }
                        }
                    } label: {
                        Label(sortTitle, systemImage: "arrow.up.arrow.down.circle")
                    }
                    .labelStyle(.titleOnly)
                    .font(.subheadline)
                    .buttonStyle(.bordered)

                    Button {
                        showCreate = true
                    } label: {
                        Label("发布", systemImage: "plus")
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(RaverTheme.background)
            }
            .sheet(isPresented: $showCreate) {
                DJSetEditorView(mode: .create) {
                    Task { await reload() }
                }
            }
            .fullScreenCover(item: $selectedSetForPlayback) { set in
                NavigationStack {
                    DJSetDetailView(setID: set.id)
                }
                .toolbar(.hidden, for: .tabBar)
            }
            .task {
                await reload()
            }
            .refreshable {
                await reload()
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func reload() async {
        page = 1
        totalPages = 1
        sets = []
        await loadMore(reset: true)
    }

    private func loadMore(reset: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.fetchDJSets(page: page, limit: 20, sortBy: sortBy, djID: nil)
            if reset {
                sets = result.items
            } else {
                sets.append(contentsOf: result.items)
            }
            totalPages = result.pagination?.totalPages ?? 1
            page += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var searchTextTrimmed: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedSets: [WebDJSet] {
        guard !searchTextTrimmed.isEmpty else { return sets }
        let keyword = searchTextTrimmed.lowercased()
        return sets.filter { item in
            item.title.lowercased().contains(keyword)
                || (item.dj?.name.lowercased().contains(keyword) ?? false)
                || item.djId.lowercased().contains(keyword)
        }
    }

    private var sortTitle: String {
        switch sortBy {
        case "popular": return "热门"
        case "tracks": return "Tracks"
        default: return "最新"
        }
    }
}

private struct DJSetGridCard: View {
    let set: WebDJSet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(RaverTheme.card)
                if let thumb = AppConfig.resolvedURLString(set.thumbnailUrl), !thumb.isEmpty {
                    AsyncImage(url: URL(string: thumb)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "video")
                                .font(.title3)
                                .foregroundStyle(RaverTheme.secondaryText)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "video")
                        .font(.title3)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipped()

            Text(set.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

            HStack(spacing: 6) {
                if let avatar = AppConfig.resolvedURLString(set.dj?.avatarUrl), !avatar.isEmpty {
                    AsyncImage(url: URL(string: avatar)) { phase in
                        switch phase {
                        case .empty:
                            Circle().fill(RaverTheme.card)
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Circle().fill(RaverTheme.card)
                        @unknown default:
                            Circle().fill(RaverTheme.card)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(RaverTheme.card)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(RaverTheme.secondaryText)
                        )
                }

                Text(set.dj?.name ?? set.djId)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.bottom, 6)
    }
}

struct DJSetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    private let service = AppEnvironment.makeWebService()

    let setID: String

    @State private var set: WebDJSet?
    @State private var comments: [WebSetComment] = []
    @State private var inputComment = ""
    @State private var isLoading = false
    @State private var showEdit = false
    @State private var showTrackEditor = false
    @State private var errorMessage: String?
    @State private var playbackTime: Double = 0
    @State private var playbackDuration: Double = 0
    @State private var pendingSeekTime: Double?
    @State private var activeTrackID: String?
    @State private var nativePlayerError: String?
    @StateObject private var nativePlayerSession = NativeVideoSession()
    @State private var isTracklistExpanded = false
    @State private var tracklists: [WebTracklistSummary] = []
    @State private var selectedTracklistID: String?
    @State private var currentTracklistInfo: WebTracklistDetail?
    @State private var currentTracks: [WebDJSetTrack] = []
    @State private var showTracklistSelector = false
    @State private var showTracklistUpload = false
    @State private var selectedArtistDJ: WebDJ?
    @State private var selectedContributor: WebContributorProfile?
    @State private var selectedCommentUser: WebUserLite?
    @State private var wheelDragTranslation: CGFloat = 0
    @State private var wheelLastHapticShift = 0
    @State private var playerSeekDeltaSeconds: Double = 0
    @State private var showPlayerSeekIndicator = false
    @State private var hideSeekIndicatorTask: Task<Void, Never>?
    @State private var showPlayerVolumeIndicator = false
    @State private var hideVolumeIndicatorTask: Task<Void, Never>?
    @State private var playerVolumeLevel: Float = 1.0
    @State private var playerVolumeBaseLevel: Float?
    @State private var playerVolumeHapticStep = -1
    @State private var playerGestureAxis: PlayerGestureAxis = .undecided
    @State private var controlsVisible = true
    @State private var controlsAutoHideTask: Task<Void, Never>?
    @State private var isPlaybackPaused = true
    @State private var isTracklistHidden = false
    @State private var isScrubbingProgress = false

    var body: some View {
        Group {
            if isLoading, set == nil {
                ProgressView("加载 Set 详情...")
            } else if let set {
                GeometryReader { proxy in
                    if proxy.size.width > proxy.size.height {
                        landscapePlayerContent(for: set, in: proxy.size)
                    } else {
                        portraitDetailContent(for: set)
                    }
                }
                .sheet(isPresented: $showEdit) {
                    DJSetEditorView(mode: .edit(set)) {
                        Task { await load() }
                    }
                }
                .sheet(isPresented: $showTrackEditor) {
                    TracklistEditorView(set: set) {
                        Task { await load() }
                    }
                }
                .sheet(isPresented: $showTracklistSelector) {
                    NavigationStack {
                        TracklistSelectorSheet(
                            set: set,
                            tracklists: tracklists,
                            selectedTracklistID: selectedTracklistID
                        ) { selectedID in
                            Task {
                                await switchTracklist(selectedID)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showTracklistUpload) {
                    NavigationStack {
                        UploadTracklistSheet(set: set) { uploaded in
                            Task {
                                await refreshTracklists()
                                await switchTracklist(uploaded.id)
                            }
                        }
                    }
                }
                .onChange(of: playbackTime) { _, newTime in
                    syncActiveTrack(for: set, at: newTime)
                }
                .onDisappear {
                    hideSeekIndicatorTask?.cancel()
                    hideSeekIndicatorTask = nil
                    hideVolumeIndicatorTask?.cancel()
                    hideVolumeIndicatorTask = nil
                    controlsAutoHideTask?.cancel()
                    controlsAutoHideTask = nil
                    nativePlayerSession.pause()
                    nativePlayerSession.reset()
                    forcePortraitOrientation()
                }
            } else {
                ContentUnavailableView("Set 不存在", systemImage: "waveform.badge.exclamationmark")
            }
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $selectedArtistDJ) { dj in
            DJDetailView(djID: dj.id)
        }
        .navigationDestination(item: $selectedContributor) { contributor in
            UserProfileView(userID: contributor.id)
        }
        .navigationDestination(item: $selectedCommentUser) { user in
            UserProfileView(userID: user.id)
        }
        .task {
            await load()
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func portraitDetailContent(for set: WebDJSet) -> some View {
        VStack(spacing: 0) {
            playerViewport(for: set, isFullscreen: false, reservedTrailingWidth: 0)
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipped()

            currentTrackPinnedCard(for: set)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, isTracklistExpanded ? 8 : 10)

            if isTracklistExpanded {
                expandedTracklistSection(for: set)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(set.title)
                        .font(.title3.bold())
                        .foregroundStyle(RaverTheme.primaryText)

                    if let dj = set.dj {
                        Button {
                            selectedArtistDJ = dj
                        } label: {
                            HStack(spacing: 8) {
                                if let avatar = AppConfig.resolvedURLString(dj.avatarUrl), !avatar.isEmpty {
                                    AsyncImage(url: URL(string: avatar)) { phase in
                                        switch phase {
                                        case .empty:
                                            Circle().fill(RaverTheme.card)
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure:
                                            Circle().fill(RaverTheme.card)
                                        @unknown default:
                                            Circle().fill(RaverTheme.card)
                                        }
                                    }
                                    .frame(width: 22, height: 22)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(RaverTheme.card)
                                        .frame(width: 22, height: 22)
                                }
                                Text(dj.name)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .font(.subheadline)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(RaverTheme.card)
                                .frame(width: 22, height: 22)
                            Text(set.djId)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .font(.subheadline)
                        }
                    }

                    ProgressView(value: progressValue(for: set))
                        .progressViewStyle(.linear)
                    Text("当前时间 \(formatTrackTime(Int(playbackTime))) / \(formatTrackTime(Int(max(1, resolvedDuration(for: set)))))")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    if let playerError = nativePlayerError {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(playerError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Text("\(sortedTracks(for: set).count) tracks · \(set.viewCount) views")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    if isMine(set) {
                        HStack {
                            Button("编辑 Set") {
                                showEdit = true
                            }
                            .buttonStyle(.bordered)

                            Button("编辑 Tracklist") {
                                showTrackEditor = true
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                Task { await deleteSet() }
                            } label: {
                                Text("删除 Set")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    contributorSection(for: set)
                    commentsSection
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
        }
    }

    @ViewBuilder
    private func playerViewport(for set: WebDJSet, isFullscreen: Bool, reservedTrailingWidth: CGFloat) -> some View {
        GeometryReader { proxy in
            let interactiveWidth = max(40, proxy.size.width - reservedTrailingWidth)
            ZStack {
                playerSection(for: set)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                playerGestureLayer(for: set, reservedTrailingWidth: reservedTrailingWidth)

                if showPlayerSeekIndicator {
                    Text(playerSeekIndicatorText(for: set))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.58))
                        .clipShape(Capsule())
                        .position(
                            x: (interactiveWidth / 2) + 6,
                            y: proxy.size.height * 0.22
                        )
                }

                if showPlayerVolumeIndicator {
                    playerVolumeIndicatorOverlay
                        .position(
                            x: interactiveWidth / 2,
                            y: proxy.size.height / 2
                        )
                }

                playerControlsOverlay(
                    for: set,
                    isFullscreen: isFullscreen,
                    interactiveWidth: interactiveWidth
                )
                .opacity(controlsVisible ? 1 : 0)
                .allowsHitTesting(controlsVisible)
            }
            .animation(.easeInOut(duration: 0.2), value: controlsVisible)
            .onAppear {
                playerVolumeLevel = min(max(nativePlayerSession.player.volume, 0), 1)
                showControlsTemporarily()
            }
        }
    }

    @ViewBuilder
    private func playerGestureLayer(for set: WebDJSet, reservedTrailingWidth: CGFloat) -> some View {
        GeometryReader { proxy in
            let interactiveWidth = max(40, proxy.size.width - reservedTrailingWidth)
            Color.clear
                .frame(width: interactiveWidth, height: proxy.size.height, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    togglePlayback()
                    showControlsTemporarily()
                }
                .onTapGesture {
                    handleSingleTapControls()
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            handlePlayerDragChanged(value, viewportHeight: proxy.size.height)
                        }
                        .onEnded { value in
                            handlePlayerDragEnded(value, in: set, viewportHeight: proxy.size.height)
                        }
                )
        }
    }

    @ViewBuilder
    private func playerControlsOverlay(for set: WebDJSet, isFullscreen: Bool, interactiveWidth: CGFloat) -> some View {
        let controlHitSize: CGFloat = 46
        ZStack {
            VStack {
                HStack {
                    Button {
                        if isFullscreen {
                            forcePortraitOrientation()
                        } else {
                            forcePortraitOrientation()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.36))
                            .clipShape(Circle())
                    }
                    .frame(width: controlHitSize, height: controlHitSize)
                    .contentShape(Circle())
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 12)
                .padding(.leading, 12)
                Spacer()
            }

            VStack {
                Spacer()
                VStack(spacing: 1) {
                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: isPlaybackPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.65), radius: 6, x: 0, y: 1)
                        }
                        .frame(width: controlHitSize, height: controlHitSize)
                        .contentShape(Circle())
                        .buttonStyle(.plain)

                        playerProgressScrubber(for: set)
                            .frame(height: 14)

                        Button {
                            if isFullscreen {
                                forcePortraitOrientation()
                            } else {
                                forceLandscapeOrientation()
                            }
                            showControlsTemporarily()
                        } label: {
                            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 34, height: 34)
                                .shadow(color: Color.black.opacity(0.55), radius: 4, x: 0, y: 1)
                        }
                        .frame(width: controlHitSize, height: controlHitSize)
                        .contentShape(Circle())
                        .buttonStyle(.plain)
                    }
                    .offset(y: 16)

                    HStack {
                        Text(formatTrackTime(Int(playbackTime)))
                        Spacer()
                        Text(formatTrackTime(Int(max(1, resolvedDuration(for: set)))))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.leading, controlHitSize + 8)
                    .padding(.trailing, controlHitSize + 8)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 6)
                .frame(width: interactiveWidth, alignment: .leading)
                .padding(.leading, 2)
                .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private func playerProgressScrubber(for set: WebDJSet) -> some View {
        GeometryReader { geo in
            let total = max(1, resolvedDuration(for: set))
            let normalized = min(max(playbackTime / total, 0), 1)
            let thumbSize: CGFloat = isScrubbingProgress ? 12 : 10
            let trackHeight: CGFloat = isScrubbingProgress ? 5 : 4
            let effectiveWidth = max(1, geo.size.width - thumbSize)
            let thumbX = (effectiveWidth * normalized)
            let activeColor = isScrubbingProgress ? Color(red: 0.42, green: 0.24, blue: 0.78) : RaverTheme.accent

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(height: 3)

                Capsule()
                    .fill(activeColor)
                    .frame(width: max(trackHeight, thumbX + (thumbSize / 2)), height: trackHeight)

                Circle()
                    .fill(activeColor)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.35), radius: isScrubbingProgress ? 3 : 1, x: 0, y: 0)
                    .offset(x: thumbX)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbingProgress = true
                        let ratio = min(max(value.location.x / max(1, geo.size.width), 0), 1)
                        seekToTime(total * ratio, in: set)
                        showControlsTemporarily()
                    }
                    .onEnded { value in
                        let ratio = min(max(value.location.x / max(1, geo.size.width), 0), 1)
                        seekToTime(total * ratio, in: set)
                        isScrubbingProgress = false
                        scheduleControlsAutoHide()
                    }
            )
        }
    }

    private enum PlayerGestureAxis {
        case undecided
        case horizontal
        case vertical
    }

    private var playerVolumeLevelClamped: Float {
        min(max(playerVolumeLevel, 0), 1)
    }

    private var playerVolumeIconName: String {
        let level = playerVolumeLevelClamped
        if level <= 0.001 { return "speaker.slash.fill" }
        if level < 0.5 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    @ViewBuilder
    private var playerVolumeIndicatorOverlay: some View {
        let ratio = CGFloat(playerVolumeLevelClamped)

        HStack(spacing: 10) {
            Image(systemName: playerVolumeIconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.94))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 132, height: 6)

                if ratio > 0.001 {
                    Capsule()
                        .fill(RaverTheme.accent)
                        .frame(width: max(8, 132 * ratio), height: 6)
                }
            }
            .animation(.easeOut(duration: 0.15), value: ratio)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 16, x: 0, y: 6)
    }

    private func handlePlayerDragChanged(_ value: DragGesture.Value, viewportHeight: CGFloat) {
        if playerGestureAxis == .undecided {
            let horizontal = abs(value.translation.width)
            let vertical = abs(value.translation.height)
            guard max(horizontal, vertical) >= 8 else { return }
            playerGestureAxis = horizontal >= vertical ? .horizontal : .vertical
        }

        switch playerGestureAxis {
        case .horizontal:
            handlePlayerSeekDragChanged(value)
        case .vertical:
            handlePlayerVolumeDragChanged(value, viewportHeight: viewportHeight)
        case .undecided:
            break
        }
    }

    private func handlePlayerDragEnded(_ value: DragGesture.Value, in set: WebDJSet, viewportHeight: CGFloat) {
        switch playerGestureAxis {
        case .horizontal:
            handlePlayerSeekDragEnded(value, in: set)
        case .vertical:
            handlePlayerVolumeDragEnded(value, viewportHeight: viewportHeight)
        case .undecided:
            break
        }

        playerGestureAxis = .undecided
        playerVolumeBaseLevel = nil
    }

    private func handlePlayerSeekDragChanged(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        guard abs(horizontal) > abs(vertical) else { return }

        playerSeekDeltaSeconds = Double(horizontal / 8)
        showControlsTemporarily()
        if !showPlayerSeekIndicator {
            showPlayerSeekIndicator = true
        }
        hideSeekIndicatorTask?.cancel()
    }

    private func handlePlayerSeekDragEnded(_ value: DragGesture.Value, in set: WebDJSet) {
        let horizontal = value.predictedEndTranslation.width
        let vertical = value.predictedEndTranslation.height
        guard abs(horizontal) > abs(vertical) else {
            playerSeekDeltaSeconds = 0
            scheduleSeekIndicatorHide()
            return
        }

        let deltaSeconds = Double(horizontal / 8)
        applySeekDelta(deltaSeconds, in: set)
        playerSeekDeltaSeconds = 0
        scheduleSeekIndicatorHide()
    }

    private func handlePlayerVolumeDragChanged(_ value: DragGesture.Value, viewportHeight: CGFloat) {
        if playerVolumeBaseLevel == nil {
            playerVolumeBaseLevel = min(max(nativePlayerSession.player.volume, 0), 1)
        }

        let base = playerVolumeBaseLevel ?? 1
        let sensitivity = max(180, viewportHeight * 0.75)
        let delta = Float(-value.translation.height / sensitivity)
        let targetVolume = min(max(base + delta, 0), 1)

        nativePlayerSession.player.volume = targetVolume
        playerVolumeLevel = targetVolume
        showPlayerVolumeIndicator = true
        showControlsTemporarily()

        let currentStep = Int((targetVolume * 10).rounded())
        if currentStep != playerVolumeHapticStep {
            playerVolumeHapticStep = currentStep
            emitSelectionHaptic()
        }

        hideVolumeIndicatorTask?.cancel()
    }

    private func handlePlayerVolumeDragEnded(_ value: DragGesture.Value, viewportHeight: CGFloat) {
        if playerVolumeBaseLevel == nil {
            handlePlayerVolumeDragChanged(value, viewportHeight: viewportHeight)
        }
        scheduleVolumeIndicatorHide()
    }

    private func applySeekDelta(_ deltaSeconds: Double, in set: WebDJSet) {
        guard deltaSeconds != 0 else { return }
        let total = resolvedDuration(for: set)
        let upperBound = total > 0 ? total : Double.greatestFiniteMagnitude
        let target = min(max(playbackTime + deltaSeconds, 0), upperBound)
        seekToTime(target, in: set)
        emitSelectionHaptic()
    }

    private func seekToTime(_ target: Double, in set: WebDJSet) {
        playbackTime = target
        syncActiveTrack(for: set, at: target)
        if resolvedPlayableVideoURL(for: set) != nil {
            pendingSeekTime = target
        }
    }

    private func showControlsTemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
        }
        scheduleControlsAutoHide()
    }

    private func handleSingleTapControls() {
        if controlsVisible {
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible = false
            }
        } else {
            showControlsTemporarily()
        }
    }

    private func scheduleControlsAutoHide() {
        controlsAutoHideTask?.cancel()
        controlsAutoHideTask = nil

        controlsAutoHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controlsVisible = false
                }
            }
        }
    }

    private func emitSelectionHaptic() {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    private func scheduleSeekIndicatorHide() {
        hideSeekIndicatorTask?.cancel()
        hideSeekIndicatorTask = Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showPlayerSeekIndicator = false
            }
        }
    }

    private func scheduleVolumeIndicatorHide() {
        hideVolumeIndicatorTask?.cancel()
        hideVolumeIndicatorTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showPlayerVolumeIndicator = false
            }
        }
    }

    private func playerSeekIndicatorText(for set: WebDJSet) -> String {
        let total = resolvedDuration(for: set)
        let upperBound = total > 0 ? total : Double.greatestFiniteMagnitude
        let preview = min(max(playbackTime + playerSeekDeltaSeconds, 0), upperBound)
        let prefix = playerSeekDeltaSeconds >= 0 ? "+" : "-"
        return "\(prefix)\(Int(abs(playerSeekDeltaSeconds)))s  \(formatTrackTime(Int(preview)))"
    }

    private func togglePlayback() {
        isPlaybackPaused.toggle()
        showControlsTemporarily()
        emitSelectionHaptic()
    }

    private func forceLandscapeOrientation() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    }

    private func forcePortraitOrientation() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }

    @ViewBuilder
    private func landscapePlayerContent(for set: WebDJSet, in size: CGSize) -> some View {
        let wheelWidth = min(max(size.width * 0.34, 160), 320)
        let reservedWidth = isTracklistHidden ? 34.0 : wheelWidth
        ZStack(alignment: .topLeading) {
            playerViewport(for: set, isFullscreen: true, reservedTrailingWidth: reservedWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if isTracklistHidden {
                    collapsedTracklistOverlay(for: set, width: wheelWidth)
                } else {
                    trackWheelOverlay(for: set, width: wheelWidth)
                }
            }
            .ignoresSafeArea()

            if let playerError = nativePlayerError {
                VStack {
                    Spacer()
                    Text(playerError)
                        .font(.caption)
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.55))
                        .padding(.bottom, 14)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func trackWheelOverlay(for set: WebDJSet, width: CGFloat) -> some View {
        let tracks = sortedTracks(for: set)
        let activeIndex = resolvedActiveTrackIndex(in: tracks)
        let rawShift = tracks.count > 1 ? (-wheelDragTranslation / wheelStepHeight) : 0
        let minShift = CGFloat(-activeIndex)
        let maxShift = CGFloat(max(0, tracks.count - 1 - activeIndex))
        let clampedShift = min(max(rawShift, minShift), maxShift)

        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.36),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            if tracks.isEmpty {
                Text("暂无 Tracklist")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            } else {
                ZStack {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        let distance = CGFloat(index - activeIndex) - clampedShift
                        if abs(distance) <= 3.5 {
                            let prominence = max(0, 1 - min(abs(distance), 1))
                            let opacity = max(0.16, 1 - (abs(distance) * 0.24))
                            let scale = max(0.82, 1 - (abs(distance) * 0.09))

                            wheelTrackEntry(
                                track: track,
                                in: set,
                                prominence: prominence,
                                opacity: opacity
                            )
                                .frame(height: wheelStepHeight)
                                .scaleEffect(scale)
                                .rotation3DEffect(
                                    .degrees(Double(distance) * -12),
                                    axis: (x: 1, y: 0, z: 0),
                                    perspective: 0.65
                                )
                                .offset(y: distance * wheelStepHeight)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .clipped()
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    handleWheelDragChanged(value, tracks: tracks, activeIndex: activeIndex)
                }
                .onEnded { value in
                    handleWheelDragEnded(value, tracks: tracks, activeIndex: activeIndex, in: set)
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    guard value.translation.width > 56 else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isTracklistHidden = true
                    }
                }
        )
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isTracklistHidden = true
                }
            } label: {
                Image(systemName: "chevron.compact.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.34))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .onAppear {
            wheelDragTranslation = 0
            wheelLastHapticShift = 0
        }
    }

    @ViewBuilder
    private func collapsedTracklistOverlay(for set: WebDJSet, width: CGFloat) -> some View {
        let tracks = sortedTracks(for: set)
        let activeIndex = resolvedActiveTrackIndex(in: tracks)
        let activeTrack = tracks.indices.contains(activeIndex) ? tracks[activeIndex] : nil
        let title = activeTrack.map(wheelTrackTitle(for:)) ?? "Unknown Track"
        let djName = activeTrack.map { wheelDJInfo(for: $0, in: set).name } ?? (set.dj?.name ?? set.djId)

        ZStack(alignment: .trailing) {
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    AnimatedEqualizerIcon(color: .white)
                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(
                            text: title,
                            fontSize: 10,
                            fontWeight: .semibold,
                            color: Color.white.opacity(0.92)
                        )
                        .frame(width: 138, alignment: .leading)

                        Text(djName)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)
                            .frame(width: 138, alignment: .leading)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.trailing, 14)
                .padding(.bottom, 12)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isTracklistHidden = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 56)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 5)
        }
        .frame(width: width)
    }

    private var wheelStepHeight: CGFloat {
        62
    }

    @ViewBuilder
    private func wheelTrackEntry(
        track: WebDJSetTrack,
        in set: WebDJSet,
        prominence: CGFloat,
        opacity: CGFloat
    ) -> some View {
        let titleSize: CGFloat = 12 + (prominence * 3.5)
        let subtitleSize: CGFloat = max(10, titleSize - 2.8)
        let info = wheelDJInfo(for: track, in: set)
        let isActive = activeTrackID == track.id

        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 5) {
                Text(wheelTrackTitle(for: track))
                    .font(.system(size: titleSize, weight: prominence > 0.75 ? .semibold : .medium))
                    .foregroundStyle(Color.white.opacity(opacity))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.trailing)
                if isActive {
                    AnimatedEqualizerIcon(color: RaverTheme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 6) {
                wheelTrackSourceLinks(for: track)

                Group {
                    if let avatarURL = info.avatarURL {
                        AsyncImage(url: avatarURL) { phase in
                            switch phase {
                            case .empty:
                                Circle().fill(Color.white.opacity(0.18))
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Circle().fill(Color.white.opacity(0.18))
                            @unknown default:
                                Circle().fill(Color.white.opacity(0.18))
                            }
                        }
                    } else {
                        Circle().fill(Color.white.opacity(0.18))
                    }
                }
                .frame(width: 14, height: 14)
                .clipShape(Circle())

                Text(info.name)
                    .font(.system(size: subtitleSize, weight: .regular))
                    .foregroundStyle(Color.white.opacity(max(0.16, opacity * 0.85)))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func wheelTrackSourceLinks(for track: WebDJSetTrack) -> some View {
        HStack(spacing: 6) {
            if let spotify = resolvedExternalURL(track.spotifyUrl) {
                Button {
                    openURL(spotify)
                } label: {
                    Image("SpotifyIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
            }

            if let netease = resolvedExternalURL(track.neteaseUrl) {
                Button {
                    openURL(netease)
                } label: {
                    Image("NeteaseIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func wheelTrackTitle(for track: WebDJSetTrack) -> String {
        let title = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return artist.isEmpty ? "Unknown Track" : artist
    }

    private func wheelDJInfo(for track: WebDJSetTrack, in set: WebDJSet) -> (name: String, avatarURL: URL?) {
        let matchedDJ = artistDJ(for: track.artist, in: set)
        let fallbackDJ = set.dj
        let nameFromTrack = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = matchedDJ?.name
            ?? fallbackDJ?.name
            ?? (nameFromTrack.isEmpty ? set.djId : nameFromTrack)
        let avatarRaw = matchedDJ?.avatarUrl ?? fallbackDJ?.avatarUrl
        let avatarResolved = AppConfig.resolvedURLString(avatarRaw ?? "")
        let avatarURL = avatarResolved.flatMap { resolved in
            resolved.isEmpty ? nil : URL(string: resolved)
        }
        return (name, avatarURL)
    }

    private func resolvedActiveTrackIndex(in tracks: [WebDJSetTrack]) -> Int {
        guard !tracks.isEmpty else { return 0 }
        if let activeTrackID,
           let index = tracks.firstIndex(where: { $0.id == activeTrackID }) {
            return index
        }
        return 0
    }

    private func clampedWheelShift(rawShift: Int, activeIndex: Int, trackCount: Int) -> Int {
        guard trackCount > 0 else { return 0 }
        let minShift = -activeIndex
        let maxShift = (trackCount - 1) - activeIndex
        return min(max(rawShift, minShift), maxShift)
    }

    private func handleWheelDragChanged(
        _ value: DragGesture.Value,
        tracks: [WebDJSetTrack],
        activeIndex: Int
    ) {
        guard tracks.count > 1 else { return }
        wheelDragTranslation = value.translation.height
        let rawShift = Int((-wheelDragTranslation / wheelStepHeight).rounded())
        let shift = clampedWheelShift(rawShift: rawShift, activeIndex: activeIndex, trackCount: tracks.count)

        if shift != wheelLastHapticShift {
            wheelLastHapticShift = shift
            if shift != 0 {
                let feedback = UISelectionFeedbackGenerator()
                feedback.selectionChanged()
            }
        }
    }

    private func handleWheelDragEnded(
        _ value: DragGesture.Value,
        tracks: [WebDJSetTrack],
        activeIndex: Int,
        in set: WebDJSet
    ) {
        guard tracks.count > 1 else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                wheelDragTranslation = 0
            }
            wheelLastHapticShift = 0
            return
        }

        let rawShift = Int((-value.predictedEndTranslation.height / wheelStepHeight).rounded())
        let shift = clampedWheelShift(rawShift: rawShift, activeIndex: activeIndex, trackCount: tracks.count)

        if shift != 0 {
            let targetIndex = activeIndex + shift
            if tracks.indices.contains(targetIndex) {
                seekToTrack(tracks[targetIndex], in: set)
            }
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            wheelDragTranslation = 0
        }
        wheelLastHapticShift = 0
    }

    private func isMine(_ set: WebDJSet) -> Bool {
        set.uploadedById == appState.session?.user.id
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let setTask = service.fetchDJSet(id: setID)
            async let commentsTask = service.fetchSetComments(setID: setID)
            async let tracklistsTask = service.fetchTracklists(setID: setID)
            let loadedSet = try await setTask
            set = loadedSet
            comments = try await commentsTask
            tracklists = try await tracklistsTask
            selectedTracklistID = nil
            currentTracklistInfo = nil
            currentTracks = loadedSet.tracks
            playbackTime = 0
            pendingSeekTime = nil
            playbackDuration = Double(max(0, loadedSet.duration ?? 0))
            controlsVisible = true
            isPlaybackPaused = true
            isTracklistHidden = false
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
            nativePlayerError = nil
            syncActiveTrack(for: loadedSet, at: 0)
            nativePlayerSession.reset()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var tracklistDisplayName: String {
        if selectedTracklistID == nil {
            return "默认 Tracklist"
        }
        if let title = currentTracklistInfo?.title, !title.isEmpty {
            return title
        }
        if let contributor = currentTracklistInfo?.contributor {
            return "\(contributor.shownName) 的版本"
        }
        return "用户版本 Tracklist"
    }

    private func refreshTracklists() async {
        do {
            tracklists = try await service.fetchTracklists(setID: setID)
            if let selectedTracklistID,
               !tracklists.contains(where: { $0.id == selectedTracklistID }) {
                await switchTracklist(nil)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func switchTracklist(_ tracklistID: String?) async {
        guard let set else { return }

        if tracklistID == nil {
            selectedTracklistID = nil
            currentTracklistInfo = nil
            currentTracks = set.tracks
            syncActiveTrack(for: set, at: playbackTime)
            return
        }

        guard let targetID = tracklistID else { return }
        do {
            let detail = try await service.fetchTracklistDetail(setID: set.id, tracklistID: targetID)
            currentTracklistInfo = detail
            selectedTracklistID = targetID
            currentTracks = detail.tracks
            syncActiveTrack(for: set, at: playbackTime)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func playerSection(for set: WebDJSet) -> some View {
        if let playableURL = resolvedPlayableVideoURL(for: set) {
            EmbeddedNativeVideoPlayer(
                session: nativePlayerSession,
                videoURL: playableURL,
                currentTime: $playbackTime,
                duration: $playbackDuration,
                pendingSeekTime: $pendingSeekTime,
                isPaused: isPlaybackPaused,
                onReady: {},
                onPlaybackStateChanged: { paused in
                    if isPlaybackPaused != paused {
                        isPlaybackPaused = paused
                    }
                },
                onError: { message in
                    nativePlayerError = message
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("无法直接播放该视频地址", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
                Text("当前仅支持原生直连媒体地址（mp4/mov/webm/m3u8）。")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.black)
        }
    }

    @ViewBuilder
    private func currentTrackPinnedCard(for set: WebDJSet) -> some View {
        let tracks = sortedTracks(for: set)
        if tracks.isEmpty {
            EmptyView()
        } else {
            let track = tracks.first(where: { $0.id == activeTrackID }) ?? tracks[0]
            let trackIndex = tracks.firstIndex(where: { $0.id == track.id }) ?? 0

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.bordered)

                    Text(tracklistDisplayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button("选择版本") {
                        showTracklistSelector = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    if appState.session != nil {
                        Button("上传") {
                            showTracklistUpload = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    Button(isTracklistExpanded ? "收起" : "展开") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isTracklistExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }

                trackRow(track: track, index: trackIndex, in: set, emphasized: true)
            }
        }
    }

    @ViewBuilder
    private func expandedTracklistSection(for set: WebDJSet) -> some View {
        let tracks = sortedTracks(for: set)
        if tracks.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(track: track, index: index, in: set, emphasized: false)
                                .id(track.id)
                        }
                    }
                }
                .frame(height: 230)
                .onChange(of: activeTrackID) { _, activeID in
                    guard let activeID else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(activeID, anchor: .top)
                    }
                }
                .onAppear {
                    guard let activeID = activeTrackID else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(activeID, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private func trackRow(track: WebDJSetTrack, index: Int, in set: WebDJSet, emphasized: Bool) -> some View {
        let isActive = activeTrackID == track.id
        let artistMatchedDJ = artistDJ(for: track.artist, in: set)
        let endTime = resolvedTrackEndTime(for: track, at: index, in: set)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                playbackStateIcon(for: track, at: index, in: set)
                Text("\(formatTrackTime(track.startTime))")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                if let endTime {
                    Text("~ \(formatTrackTime(Int(endTime)))")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                Spacer()
                Text(track.status.uppercased())
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isActive ? Color.white : RaverTheme.primaryText)
                        .lineLimit(1)

                    if let artistMatchedDJ {
                        Button {
                            selectedArtistDJ = artistMatchedDJ
                        } label: {
                            HStack(spacing: 6) {
                                if let avatar = AppConfig.resolvedURLString(artistMatchedDJ.avatarUrl), !avatar.isEmpty {
                                    AsyncImage(url: URL(string: avatar)) { phase in
                                        switch phase {
                                        case .empty:
                                            Circle().fill(RaverTheme.card)
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure:
                                            Circle().fill(RaverTheme.card)
                                        @unknown default:
                                            Circle().fill(RaverTheme.card)
                                        }
                                    }
                                    .frame(width: 18, height: 18)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(RaverTheme.card)
                                        .frame(width: 18, height: 18)
                                }
                                Text(artistMatchedDJ.name)
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(RaverTheme.card)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Image(systemName: "music.mic")
                                        .font(.system(size: 8))
                                        .foregroundStyle(RaverTheme.secondaryText)
                                )
                            Text(track.artist)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }

                if hasSourceLinks(track) {
                    sourceLinksRow(for: track)
                        .padding(.bottom, 1)
                }
            }
        }
        .padding(.vertical, emphasized ? 8 : 10)
        .padding(.horizontal, emphasized ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.black.opacity(0.92) : RaverTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? RaverTheme.accent.opacity(0.65) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            seekToTrack(track, in: set)
        }
    }

    @ViewBuilder
    private func sourceLinksRow(for track: WebDJSetTrack) -> some View {
        HStack(spacing: 8) {
            if let spotify = resolvedExternalURL(track.spotifyUrl) {
                Button {
                    openURL(spotify)
                } label: {
                    Image("SpotifyIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }

            if let netease = resolvedExternalURL(track.neteaseUrl) {
                Button {
                    openURL(netease)
                } label: {
                    Image("NeteaseIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hasSourceLinks(_ track: WebDJSetTrack) -> Bool {
        resolvedExternalURL(track.spotifyUrl) != nil || resolvedExternalURL(track.neteaseUrl) != nil
    }

    private func resolvedExternalURL(_ raw: String?) -> URL? {
        guard let raw = raw, let resolved = AppConfig.resolvedURLString(raw), !resolved.isEmpty else {
            return nil
        }
        return URL(string: resolved)
    }

    @ViewBuilder
    private func playbackStateIcon(for track: WebDJSetTrack, at index: Int, in set: WebDJSet) -> some View {
        if activeTrackID == track.id {
            AnimatedEqualizerIcon(color: RaverTheme.accent)
        } else {
            Image(systemName: checklistSymbol(for: track, at: index, in: set))
                .foregroundStyle(checklistColor(for: track, at: index, in: set))
        }
    }

    @ViewBuilder
    private func contributorSection(for set: WebDJSet) -> some View {
        let effectiveTracklistContributor = currentTracklistInfo?.contributor ?? set.tracklistContributor
        if set.videoContributor != nil || effectiveTracklistContributor != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("贡献者")
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                if let video = set.videoContributor {
                    contributorRow(title: "视频贡献", contributor: video)
                }
                if let tracklist = effectiveTracklistContributor {
                    let title = selectedTracklistID == nil ? "Tracklist 贡献" : "当前版本 Tracklist 贡献"
                    contributorRow(title: title, contributor: tracklist)
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("评论")
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)

            if comments.isEmpty {
                Text("暂无评论")
                    .foregroundStyle(RaverTheme.secondaryText)
            } else {
                ForEach(comments) { comment in
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            selectedCommentUser = comment.user
                        } label: {
                            Image(
                                AppConfig.resolvedUserAvatarAssetName(
                                    userID: comment.user.id,
                                    username: comment.user.username,
                                    avatarURL: comment.user.avatarUrl
                                )
                            )
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .background(RaverTheme.card)
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.user.shownName)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(comment.content)
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(comment.createdAt.feedTimeText)
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            TextField("写评论...", text: $inputComment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button("发送评论") {
                Task { await sendComment() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func artistDJ(for artistName: String, in set: WebDJSet) -> WebDJ? {
        let target = normalizeName(artistName)
        if target.isEmpty {
            return nil
        }

        if let primary = set.dj {
            let normalizedPrimary = normalizeName(primary.name)
            if normalizedPrimary == target || target.contains(normalizedPrimary) || normalizedPrimary.contains(target) {
                return primary
            }
        }

        for item in set.lineupDjs {
            let normalized = normalizeName(item.name)
            if normalized == target || target.contains(normalized) || normalized.contains(target) {
                return item
            }
        }
        return nil
    }

    private func normalizeName(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "[^a-z0-9\\u4e00-\\u9fa5]+", with: "", options: .regularExpression)
    }

    private func sendComment() async {
        let content = inputComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        do {
            _ = try await service.addSetComment(setID: setID, input: CreateSetCommentInput(content: content, parentId: nil))
            inputComment = ""
            comments = try await service.fetchSetComments(setID: setID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSet() async {
        do {
            try await service.deleteDJSet(id: setID)
            errorMessage = "Set 已删除，请返回列表刷新"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatTrackTime(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let h = safe / 3600
        let m = (safe % 3600) / 60
        let s = safe % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func sortedTracks(for set: WebDJSet) -> [WebDJSetTrack] {
        let sourceTracks = currentTracks.isEmpty ? set.tracks : currentTracks
        return sourceTracks.sorted { lhs, rhs in
            if lhs.startTime == rhs.startTime {
                return lhs.position < rhs.position
            }
            return lhs.startTime < rhs.startTime
        }
    }

    private func resolvedDuration(for set: WebDJSet) -> Double {
        if playbackDuration > 0 {
            return playbackDuration
        }
        if let duration = set.duration, duration > 0 {
            return Double(duration)
        }
        let tracks = sortedTracks(for: set)
        guard let last = tracks.last else { return 0 }
        return Double(max(last.endTime ?? last.startTime, last.startTime))
    }

    private func progressValue(for set: WebDJSet) -> Double {
        let total = resolvedDuration(for: set)
        guard total > 0 else { return 0 }
        return min(max(playbackTime / total, 0), 1)
    }

    private func resolvedTrackEndTime(for track: WebDJSetTrack, at index: Int, in set: WebDJSet) -> Double? {
        let tracks = sortedTracks(for: set)
        if let explicit = track.endTime, explicit > track.startTime {
            return Double(explicit)
        }
        if index + 1 < tracks.count {
            return Double(tracks[index + 1].startTime)
        }
        let total = resolvedDuration(for: set)
        return total > 0 ? total : nil
    }

    private func syncActiveTrack(for set: WebDJSet, at time: Double) {
        let tracks = sortedTracks(for: set)
        for (index, track) in tracks.enumerated() {
            let start = Double(track.startTime)
            let end = resolvedTrackEndTime(for: track, at: index, in: set) ?? Double.greatestFiniteMagnitude
            if time >= start && time < end {
                if activeTrackID != track.id {
                    activeTrackID = track.id
                }
                return
            }
        }
        if activeTrackID != nil {
            activeTrackID = nil
        }
    }

    private func seekToTrack(_ track: WebDJSetTrack, in set: WebDJSet) {
        let target = Double(track.startTime)
        playbackTime = target
        syncActiveTrack(for: set, at: target)
        if resolvedPlayableVideoURL(for: set) != nil {
            pendingSeekTime = target
        }
    }

    private func checklistSymbol(for track: WebDJSetTrack, at index: Int, in set: WebDJSet) -> String {
        if activeTrackID == track.id {
            return "waveform.circle.fill"
        }
        let end = resolvedTrackEndTime(for: track, at: index, in: set) ?? Double.greatestFiniteMagnitude
        if playbackTime >= end {
            return "checkmark.circle.fill"
        }
        return "circle"
    }

    private func checklistColor(for track: WebDJSetTrack, at index: Int, in set: WebDJSet) -> Color {
        if activeTrackID == track.id {
            return RaverTheme.accent
        }
        let end = resolvedTrackEndTime(for: track, at: index, in: set) ?? Double.greatestFiniteMagnitude
        if playbackTime >= end {
            return .green
        }
        return RaverTheme.secondaryText
    }

    private func resolvedPlayableVideoURL(for set: WebDJSet) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(set.videoUrl), !resolved.isEmpty else { return nil }
        if let direct = URL(string: resolved) {
            return direct
        }
        let encoded = resolved.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        if let encoded, let url = URL(string: encoded) {
            return url
        }
        return nil
    }

    @ViewBuilder
    private func contributorRow(title: String, contributor: WebContributorProfile) -> some View {
        Button {
            selectedContributor = contributor
        } label: {
            HStack(spacing: 8) {
                Image(
                    AppConfig.resolvedUserAvatarAssetName(
                        userID: contributor.id,
                        username: contributor.username,
                        avatarURL: contributor.avatarUrl
                    )
                )
                .resizable()
                .scaledToFill()
                .frame(width: 26, height: 26)
                .background(RaverTheme.card)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(contributor.shownName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AnimatedEqualizerIcon: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(height: animate ? 11 : 5, duration: 0.42, delay: 0)
            bar(height: animate ? 7 : 12, duration: 0.36, delay: 0.08)
            bar(height: animate ? 12 : 6, duration: 0.48, delay: 0.16)
        }
        .frame(width: 14, height: 14, alignment: .bottom)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }

    private func bar(height: CGFloat, duration: Double, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 2, height: height)
            .animation(
                .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animate
            )
    }
}

private struct MarqueeText: View {
    let text: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let color: Color

    private let gap: CGFloat = 16
    private let speed: CGFloat = 22
    @State private var textWidth: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let containerWidth = proxy.size.width
            let shouldScroll = textWidth > containerWidth + 2

            TimelineView(.animation(minimumInterval: 1 / 30, paused: !shouldScroll)) { context in
                let travel = max(1, textWidth + gap)
                let elapsed = CGFloat(context.date.timeIntervalSinceReferenceDate)
                let x = shouldScroll
                    ? -((elapsed * speed).truncatingRemainder(dividingBy: travel))
                    : 0

                HStack(spacing: gap) {
                    textLabel
                    if shouldScroll {
                        textLabel
                    }
                }
                .offset(x: x)
            }
        }
        .frame(height: fontSize + 2)
        .clipped()
    }

    private var textLabel: some View {
        Text(text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MarqueeWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            )
            .onPreferenceChange(MarqueeWidthPreferenceKey.self) { value in
                textWidth = value
            }
    }
}

private struct MarqueeWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private final class NativeVideoSession: ObservableObject {
    let player: AVPlayer = AVPlayer()
    private(set) var currentURL: URL?

    func loadIfNeeded(url: URL) {
        guard currentURL?.absoluteString != url.absoluteString else { return }
        currentURL = url
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    func pause() {
        player.pause()
    }

    func reset() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentURL = nil
    }
}

private struct EmbeddedNativeVideoPlayer: UIViewControllerRepresentable {
    let session: NativeVideoSession
    let videoURL: URL
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var pendingSeekTime: Double?
    let isPaused: Bool
    let onReady: () -> Void
    let onPlaybackStateChanged: (Bool) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.player = session.player
        session.loadIfNeeded(url: videoURL)
        context.coordinator.attachPlayer(session.player)
        context.coordinator.bindCurrentItemObserver()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        context.coordinator.parent = self
        if uiViewController.player !== session.player {
            uiViewController.player = session.player
        }
        session.loadIfNeeded(url: videoURL)
        context.coordinator.attachPlayer(session.player)
        context.coordinator.bindCurrentItemObserver()
        context.coordinator.seekIfNeeded()
        context.coordinator.ensurePlaybackState()
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.cleanup()
        uiViewController.player = nil
    }

    final class Coordinator: NSObject {
        var parent: EmbeddedNativeVideoPlayer
        private weak var player: AVPlayer?
        private var timeObserverToken: Any?
        private var statusObserver: NSKeyValueObservation?
        private weak var observedItem: AVPlayerItem?
        private var lastAppliedPausedState: Bool?

        init(parent: EmbeddedNativeVideoPlayer) {
            self.parent = parent
            self.lastAppliedPausedState = nil
        }

        func attachPlayer(_ player: AVPlayer) {
            guard self.player !== player else { return }
            if let existingPlayer = self.player, let token = timeObserverToken {
                existingPlayer.removeTimeObserver(token)
                timeObserverToken = nil
            }
            self.player = player
            timeObserverToken = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.35, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self else { return }
                self.parent.currentTime = max(0, time.seconds)
                self.parent.onPlaybackStateChanged(player.timeControlStatus != .playing)
                if let item = player.currentItem {
                    let total = item.duration.seconds
                    if total.isFinite && total > 0 {
                        self.parent.duration = total
                    }
                }
            }
        }

        func bindCurrentItemObserver() {
            guard let item = player?.currentItem else {
                observedItem = nil
                statusObserver = nil
                return
            }
            guard observedItem !== item else { return }
            observedItem = item
            statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    switch observedItem.status {
                    case .readyToPlay:
                        self.parent.onReady()
                        let value = observedItem.duration.seconds
                        if value.isFinite && value > 0 {
                            self.parent.duration = value
                        }
                        self.ensurePlaybackState()
                    case .failed:
                        let message = observedItem.error?.localizedDescription ?? "视频加载失败，请检查链接或上传文件"
                        self.parent.onError(message)
                    default:
                        break
                    }
                }
            }
        }

        func seekIfNeeded() {
            guard let seconds = parent.pendingSeekTime else { return }
            let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
            player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            DispatchQueue.main.async {
                self.parent.pendingSeekTime = nil
            }
        }

        func ensurePlaybackState() {
            guard lastAppliedPausedState != parent.isPaused else { return }
            lastAppliedPausedState = parent.isPaused
            guard let player else { return }
            if parent.isPaused {
                player.pause()
            } else {
                player.play()
            }
        }

        func cleanup() {
            statusObserver = nil
            if let player, let token = timeObserverToken {
                player.removeTimeObserver(token)
            }
            timeObserverToken = nil
            observedItem = nil
            self.player = nil
        }
    }
}

private struct TracklistSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let set: WebDJSet
    let tracklists: [WebTracklistSummary]
    let selectedTracklistID: String?
    let onSelect: (String?) -> Void

    @State private var query = ""
    @State private var copiedID: String?

    private var filteredTracklists: [WebTracklistSummary] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return tracklists }
        return tracklists.filter { item in
            let title = (item.title ?? "").lowercased()
            let contributorName = item.contributor?.shownName.lowercased() ?? ""
            return title.contains(keyword)
                || contributorName.contains(keyword)
                || item.id.lowercased().contains(keyword)
        }
    }

    private func resolvedTracklistTitle(_ item: WebTracklistSummary) -> String {
        let trimmed = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return "\(item.contributor?.shownName ?? "匿名") 的版本"
    }

    private func copyTracklistID(_ id: String) {
        UIPasteboard.general.string = id
        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == id {
                copiedID = nil
            }
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("默认 Tracklist")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(set.tracklistContributor?.shownName ?? set.videoContributor?.shownName ?? "官方版本")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text("ID: default")
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        copyTracklistID("default")
                    } label: {
                        Image(systemName: copiedID == "default" ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    if selectedTracklistID == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(RaverTheme.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(nil)
                    dismiss()
                }
            }

            Section("用户上传版本") {
                if filteredTracklists.isEmpty {
                    Text(query.isEmpty ? "暂无用户上传版本" : "未找到匹配版本")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(filteredTracklists) { item in
                        HStack(spacing: 10) {
                            ContributorAvatar(
                                avatarURL: item.contributor?.avatarUrl,
                                fallback: item.contributor?.shownName ?? "?"
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resolvedTracklistTitle(item))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(1)
                                Text("\(item.trackCount) tracks · \(item.createdAt.feedTimeText)")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text("ID: \(item.id)")
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                copyTracklistID(item.id)
                            } label: {
                                Image(systemName: copiedID == item.id ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)

                            if selectedTracklistID == item.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(RaverTheme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(item.id)
                            dismiss()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "搜索 Tracklist / 用户 / ID")
        .navigationTitle("选择 Tracklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
}

private struct UploadTracklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let set: WebDJSet
    let onUploaded: (WebTracklistDetail) -> Void

    @State private var title = ""
    @State private var bulkText = ""
    @State private var parsedTracks: [CreateTrackInput] = []
    @State private var infoText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Tracklist 标题") {
                TextField("例如：我的版本", text: $title)
            }

            Section("批量粘贴") {
                Text("每行格式：`0:00 - 艺术家 - 歌曲名`")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                TextEditor(text: $bulkText)
                    .frame(minHeight: 200)
                    .font(.system(.footnote, design: .monospaced))
                Button("解析歌单") {
                    parseBulkTracklist()
                }
                .buttonStyle(.bordered)
            }

            if !parsedTracks.isEmpty {
                Section("解析结果（\(parsedTracks.count)）") {
                    ForEach(Array(parsedTracks.prefix(8).enumerated()), id: \.offset) { index, track in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(index + 1). \(track.artist) - \(track.title)")
                                .font(.subheadline)
                                .foregroundStyle(RaverTheme.primaryText)
                            Text("\(UploadTracklistSheet.formatTime(track.startTime)) · \(track.status.uppercased())")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                    if parsedTracks.count > 8 {
                        Text("... 还有 \(parsedTracks.count - 8) 首")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }

            if !infoText.isEmpty {
                Section {
                    Text(infoText)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
        .navigationTitle("上传我的 Tracklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "上传中..." : "上传") {
                    Task { await upload() }
                }
                .disabled(isSaving || parsedTracks.isEmpty)
            }
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func parseBulkTracklist() {
        let lines = bulkText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            infoText = "请先粘贴歌单文本"
            parsedTracks = []
            return
        }

        let parsed = lines
            .compactMap(parseLine)
            .sorted(by: { $0.startSeconds < $1.startSeconds })

        guard !parsed.isEmpty else {
            infoText = "未识别可用行，请使用“时间 - 艺术家 - 歌名”格式"
            parsedTracks = []
            return
        }

        parsedTracks = parsed.enumerated().map { index, row in
            let nextStart = index + 1 < parsed.count ? parsed[index + 1].startSeconds : nil
            return CreateTrackInput(
                position: index + 1,
                startTime: row.startSeconds,
                endTime: nextStart,
                title: row.title,
                artist: row.artist,
                status: row.status,
                spotifyUrl: nil,
                neteaseUrl: nil
            )
        }
        infoText = "解析成功：\(parsedTracks.count) 首"
    }

    private func parseLine(_ line: String) -> (startSeconds: Int, title: String, artist: String, status: String)? {
        let pattern = #"^(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let timeRange = Range(match.range(at: 1), in: line),
              let bodyRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        guard let seconds = UploadTracklistSheet.parseTime(String(line[timeRange])) else {
            return nil
        }

        let detail = String(line[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let splitToken = " - "
        let splitIndex = detail.range(of: splitToken)
        let artist = splitIndex.map { String(detail[..<$0.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? "Unknown"
        let title = splitIndex.map { String(detail[$0.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? detail

        guard !title.isEmpty else { return nil }
        let status = inferStatus(detail)
        return (seconds, title, artist.isEmpty ? "Unknown" : artist, status)
    }

    private func inferStatus(_ text: String) -> String {
        let normalized = text.lowercased()
        if normalized.contains("unreleased") || normalized.contains(" id ") || normalized.hasSuffix(" id") {
            return "id"
        }
        if normalized.contains(" remix") || normalized.contains("(remix") || normalized.contains(" flip") {
            return "remix"
        }
        if normalized.contains(" edit") || normalized.contains("(edit") {
            return "edit"
        }
        return "released"
    }

    private func upload() async {
        guard !parsedTracks.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let uploaded = try await service.createTracklist(
                setID: set.id,
                input: CreateTracklistInput(title: title.nilIfEmpty, tracks: parsedTracks)
            )
            onUploaded(uploaded)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func parseTime(_ value: String) -> Int? {
        let parts = value
            .split(separator: ":")
            .compactMap { Int($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return nil
    }

    private static func formatTime(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let h = safe / 3600
        let m = (safe % 3600) / 60
        let s = safe % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

private struct ContributorAvatar: View {
    let avatarURL: String?
    let fallback: String

    var body: some View {
        Group {
            if let avatarURL = AppConfig.resolvedURLString(avatarURL), !avatarURL.isEmpty {
                AsyncImage(url: URL(string: avatarURL)) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(RaverTheme.card)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(fallback.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            )
    }
}

struct DJSetEditorView: View {
    enum Mode {
        case create
        case edit(WebDJSet)

        var title: String {
            switch self {
            case .create: return "上传 Set"
            case .edit: return "编辑 Set"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let mode: Mode
    let onSaved: () -> Void

    @State private var djId = ""
    @State private var title = ""
    @State private var videoUrl = ""
    @State private var description = ""
    @State private var venue = ""
    @State private var eventName = ""
    @State private var thumbnailUrl = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var isSaving = false
    @State private var isUploadingVideo = false
    @State private var previewText = ""
    @State private var errorMessage: String?

    private let demoVideoURL = "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

    var body: some View {
        NavigationStack {
            Form {
                Section("基础") {
                    TextField("DJ ID", text: $djId)
                    TextField("标题", text: $title)
                    TextField("简介", text: $description, axis: .vertical)
                    TextField("场地", text: $venue)
                    TextField("活动名称", text: $eventName)
                }

                Section("视频资源") {
                    TextField("视频链接（可选）", text: $videoUrl)
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        Label("上传视频到资源库", systemImage: "video.badge.plus")
                    }
                    if isUploadingVideo {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("视频上传中...")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                    Button("填入 Demo 视频") {
                        videoUrl = demoVideoURL
                    }
                }

                Section("封面") {
                    TextField("封面 URL", text: $thumbnailUrl)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("上传封面", systemImage: "photo")
                    }
                }

                Section {
                    Button("预解析视频") {
                        Task { await preview() }
                    }
                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                prefillIfNeeded()
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func prefillIfNeeded() {
        guard case .edit(let set) = mode else { return }
        if !title.isEmpty { return }

        djId = set.djId
        title = set.title
        videoUrl = set.videoUrl
        description = set.description ?? ""
        venue = set.venue ?? ""
        eventName = set.eventName ?? ""
        thumbnailUrl = set.thumbnailUrl ?? ""
    }

    private func preview() async {
        let url = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            errorMessage = "请先输入视频链接，或直接上传视频后再保存"
            return
        }
        do {
            let data = try await service.previewVideo(videoURL: url)
            let title = data["title"] ?? ""
            let platform = data["platform"] ?? ""
            previewText = "\(platform) \(title)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDJID = djId.trimmingCharacters(in: .whitespacesAndNewlines)
        var finalVideo = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedDJID.isEmpty else {
            errorMessage = "请补全 DJ ID 和标题"
            return
        }
        if finalVideo.isEmpty, selectedVideo == nil {
            errorMessage = "请填写视频链接或上传视频文件"
            return
        }

        isSaving = true
        defer { isSaving = false }

        var finalThumb = thumbnailUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let selectedPhoto,
               let data = try await selectedPhoto.loadTransferable(type: Data.self) {
                let upload = try await service.uploadSetThumbnail(
                    imageData: data,
                    fileName: "set-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalThumb = upload.url
            }

            if let selectedVideo {
                isUploadingVideo = true
                defer { isUploadingVideo = false }
                guard let videoData = try await selectedVideo.loadTransferable(type: Data.self) else {
                    throw ServiceError.message("读取视频文件失败，请重新选择")
                }
                let upload = try await service.uploadSetVideo(
                    videoData: videoData,
                    fileName: "set-video-\(UUID().uuidString).mp4",
                    mimeType: "video/mp4"
                )
                finalVideo = upload.url
            }

            guard !finalVideo.isEmpty else {
                throw ServiceError.message("视频上传失败，请重试")
            }

            switch mode {
            case .create:
                _ = try await service.createDJSet(
                    input: CreateDJSetInput(
                        djId: trimmedDJID,
                        title: trimmedTitle,
                        videoUrl: finalVideo,
                        thumbnailUrl: finalThumb.nilIfEmpty,
                        description: description.nilIfEmpty,
                        venue: venue.nilIfEmpty,
                        eventName: eventName.nilIfEmpty,
                        recordedAt: nil
                    )
                )
            case .edit(let set):
                _ = try await service.updateDJSet(
                    id: set.id,
                    input: UpdateDJSetInput(
                        djId: trimmedDJID,
                        title: trimmedTitle,
                        videoUrl: finalVideo,
                        thumbnailUrl: finalThumb.nilIfEmpty,
                        description: description.nilIfEmpty,
                        venue: venue.nilIfEmpty,
                        eventName: eventName.nilIfEmpty,
                        recordedAt: set.recordedAt
                    )
                )
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TracklistEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let set: WebDJSet
    let onSaved: () -> Void

    @State private var rows: [TrackEditorRow] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach($rows) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("标题", text: $row.title)
                        TextField("艺术家", text: $row.artist)
                        HStack {
                            TextField("开始秒数", value: $row.startTime, format: .number)
                            TextField("结束秒数", value: $row.endTime, format: .number)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    rows.remove(atOffsets: indexSet)
                }

                Button {
                    rows.append(TrackEditorRow(position: rows.count + 1, title: "", artist: "", startTime: 0, endTime: 0))
                } label: {
                    Label("新增 Track", systemImage: "plus")
                }
            }
            .navigationTitle("编辑 Tracklist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("自动链接") {
                        Task { await autoLink() }
                    }
                }
            }
            .onAppear {
                if rows.isEmpty {
                    rows = set.tracks.map {
                        TrackEditorRow(
                            position: $0.position,
                            title: $0.title,
                            artist: $0.artist,
                            startTime: $0.startTime,
                            endTime: $0.endTime ?? 0
                        )
                    }
                    if rows.isEmpty {
                        rows = [TrackEditorRow(position: 1, title: "", artist: "", startTime: 0, endTime: 0)]
                    }
                }
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() async {
        let tracks = rows.enumerated().compactMap { index, row -> CreateTrackInput? in
            let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = row.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !artist.isEmpty else { return nil }
            return CreateTrackInput(
                position: index + 1,
                startTime: max(0, row.startTime),
                endTime: row.endTime > 0 ? row.endTime : nil,
                title: title,
                artist: artist,
                status: "released",
                spotifyUrl: nil,
                neteaseUrl: nil
            )
        }

        guard !tracks.isEmpty else {
            errorMessage = "至少保留 1 条有效 Track"
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await service.replaceTracks(setID: set.id, tracks: tracks)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func autoLink() async {
        do {
            try await service.autoLinkTracks(setID: set.id)
            errorMessage = "已触发自动链接"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TrackEditorRow: Identifiable {
    let id = UUID()
    var position: Int
    var title: String
    var artist: String
    var startTime: Int
    var endTime: Int
}

struct LearnModuleView: View {
    private let service = AppEnvironment.makeWebService()

    @State private var genres: [LearnGenreNode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && genres.isEmpty {
                    ProgressView("学习内容加载中...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !genres.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("流派树")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                    ForEach(genres) { node in
                                        GenreNodeView(node: node)
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(RaverTheme.card)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await load()
            }
            .refreshable {
                await load()
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            genres = try await service.fetchLearnGenres()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct GenreNodeView: View {
    let node: LearnGenreNode

    var body: some View {
        DisclosureGroup {
            if let children = node.children, !children.isEmpty {
                ForEach(children) { child in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name)
                            .font(.subheadline.weight(.medium))
                        Text(child.description)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(.vertical, 2)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .foregroundStyle(RaverTheme.primaryText)
                Text(node.description)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }
}

private struct RankingBoardDetailView: View {
    private let service = AppEnvironment.makeWebService()

    let board: RankingBoard

    @State private var selectedYear: Int
    @State private var detail: RankingBoardDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDJForDetail: WebDJ?

    init(board: RankingBoard) {
        self.board = board
        _selectedYear = State(initialValue: board.years.last ?? 2025)
    }

    var body: some View {
        ScrollView {
            Group {
                if isLoading, detail == nil {
                    ProgressView("加载榜单中...")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let detail {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(board.title)
                                .font(.title.weight(.black))
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(board.subtitle ?? board.defaultSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(RaverTheme.secondaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(board.years, id: \.self) { year in
                                        Button("\(year)") {
                                            selectedYear = year
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedYear == year ? RaverTheme.accent : RaverTheme.card)
                                        .foregroundStyle(selectedYear == year ? Color.white : RaverTheme.primaryText)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(detail.entries) { entry in
                                Button {
                                    if let dj = entry.dj {
                                        selectedDJForDetail = dj
                                    }
                                } label: {
                                    RankingEntryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .disabled(entry.dj?.id == nil)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                } else {
                    ContentUnavailableView("榜单为空", systemImage: "list.number")
                        .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
        }
        .background(RaverTheme.background)
        .navigationTitle(board.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .onChange(of: selectedYear) { _, _ in
            Task { await load() }
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .fullScreenCover(item: $selectedDJForDetail) { dj in
            NavigationStack {
                DJDetailView(djID: dj.id)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await service.fetchRankingBoardDetail(boardID: board.id, year: selectedYear)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

private struct RankingEntryCard: View {
    let entry: RankingEntry

    var body: some View {
        ZStack {
            GeometryReader { geo in
                entryImage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.22), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    Spacer()
                    Text(deltaLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(deltaColor.opacity(0.88))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                Spacer()
            }

            HStack {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text("\(entry.rank)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                        )
                }
                .padding(.leading, 8)
                .padding(.bottom, 8)
                Spacer()
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 10) {
                    Spacer(minLength: 46)

                    Text(entry.name.uppercased())
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.trailing, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var entryImage: some View {
        if let avatar = entry.dj?.avatarUrl, let url = URL(string: avatar) {
            AsyncImage(url: url, transaction: Transaction(animation: .none)) { phase in
                switch phase {
                case .empty:
                    fallbackImage
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackImage
                @unknown default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.10, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(entry.name.prefix(2)).uppercased())
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var deltaLabel: String {
        guard let delta = entry.delta else { return "—" }
        if delta > 0 { return "▲ \(delta)" }
        if delta < 0 { return "▼ \(abs(delta))" }
        return "• 0"
    }

    private var deltaColor: Color {
        guard let delta = entry.delta else { return Color.gray }
        if delta > 0 { return Color.green }
        if delta < 0 { return Color.red }
        return Color.gray
    }
}

private struct DJSearchResultCard: View {
    let dj: WebDJ

    var body: some View {
        ZStack {
            GeometryReader { geo in
                djImage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.22), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 10) {
                    Spacer(minLength: 10)

                    Text(dj.name.uppercased())
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.trailing, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var djImage: some View {
        if let avatar = AppConfig.resolvedURLString(dj.avatarUrl), let url = URL(string: highResAvatarURL(avatar)) {
            AsyncImage(url: url, transaction: Transaction(animation: .none)) { phase in
                switch phase {
                case .empty:
                    fallbackImage
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackImage
                @unknown default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.10, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(dj.name.prefix(2)).uppercased())
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private func highResAvatarURL(_ url: String) -> String {
        url
            .replacingOccurrences(of: "ab6761610000f178", with: "ab6761610000e5eb")
            .replacingOccurrences(of: "ab67616100005174", with: "ab6761610000e5eb")
            .replacingOccurrences(of: "ab67616d00004851", with: "ab67616d0000b273")
            .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273")
    }
}

private extension RankingBoard {
    var yearsText: String {
        guard let minYear = years.min(), let maxYear = years.max() else { return "—" }
        return minYear == maxYear ? "\(minYear)" : "\(minYear) - \(maxYear)"
    }

    var defaultSubtitle: String {
        switch id {
        case "djmag": return "全球电子音乐最有影响力榜单之一"
        case "dongye": return "中文圈 DJ 热度与影响力榜单"
        default: return "各大榜单年度排名与升降变化"
        }
    }

    var shortMark: String {
        switch id {
        case "djmag": return "TOP"
        case "dongye": return "东野"
        default: return String(title.prefix(3)).uppercased()
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
