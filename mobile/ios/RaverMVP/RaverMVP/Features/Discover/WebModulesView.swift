import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UIKit
import CoreImage.CIFilterBuiltins

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
    @State private var ongoingEvents: [WebEvent] = []
    @State private var endedEvents: [WebEvent] = []
    @State private var markedCheckinIDsByEventID: [String: String] = [:]
    @State private var plannedCheckinIDsByEventID: [String: String] = [:]
    @State private var page = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var selectedScope: EventScope = .all
    @State private var selectedEventType = ""
    @State private var searchText = ""
    @State private var isInlineSearchExpanded = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
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
                    HStack(spacing: 8) {
                        HorizontalAxisLockedScrollView(showsIndicators: false) {
                            HStack(spacing: 8) {
                                myEventsScopeChip
                                eventTypeChip(title: "全部活动", value: "")
                                ForEach(eventTypeTabs, id: \.self) { type in
                                    eventTypeChip(title: type, value: type)
                                }
                            }
                            .padding(.leading, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)

                        eventTopIconButton(systemName: "magnifyingglass") {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                isInlineSearchExpanded.toggle()
                            }
                            if isInlineSearchExpanded {
                                DispatchQueue.main.async {
                                    isSearchFieldFocused = true
                                }
                            } else {
                                isSearchFieldFocused = false
                                if !searchText.isEmpty {
                                    searchText = ""
                                }
                            }
                        }

                        eventTopIconButton(systemName: "calendar") {
                            showCalendar = true
                        }

                        eventTopIconButton(systemName: "plus") {
                            showCreate = true
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    if isInlineSearchExpanded {
                        HStack(spacing: 8) {
                            inlineEventSearchField

                            Button("取消") {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    isInlineSearchExpanded = false
                                }
                                isSearchFieldFocused = false
                                if !searchText.isEmpty {
                                    searchText = ""
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(RaverTheme.accent)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
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
            .onChange(of: searchText) { _, _ in
                guard selectedScope == .all else { return }
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    while await MainActor.run(body: { isLoading }) {
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        guard !Task.isCancelled else { return }
                    }
                    await reload()
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
        ongoingEvents = []
        endedEvents = []
        myPublishedEvents = []
        await loadPersonalEventCheckins()
        if selectedScope == .all {
            await loadStatusBuckets(reset: true)
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
                eventType: selectedEventType.nilIfEmpty,
                status: "upcoming"
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

    private func loadStatusBuckets(reset: Bool = false) async {
        guard selectedScope == .all else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let ongoingPage = service.fetchEvents(
                page: 1,
                limit: 12,
                search: searchText,
                eventType: selectedEventType.nilIfEmpty,
                status: "ongoing"
            )
            async let upcomingPage = service.fetchEvents(
                page: 1,
                limit: 20,
                search: searchText,
                eventType: selectedEventType.nilIfEmpty,
                status: "upcoming"
            )
            async let endedPage = service.fetchEvents(
                page: 1,
                limit: 12,
                search: searchText,
                eventType: selectedEventType.nilIfEmpty,
                status: "ended"
            )

            let (ongoingResult, upcomingResult, endedResult) = try await (ongoingPage, upcomingPage, endedPage)
            ongoingEvents = ongoingResult.items.sorted(by: { $0.startDate < $1.startDate })
            events = mergeUnique(upcomingResult.items, excluding: ongoingEvents)
            endedEvents = endedResult.items.sorted(by: { $0.startDate > $1.startDate })
            totalPages = upcomingResult.pagination?.totalPages ?? 1
            page = reset ? 2 : page
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
            return events.isEmpty && ongoingEvents.isEmpty && endedEvents.isEmpty
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
        let dynamic = Set((events + ongoingEvents + endedEvents + myPublishedEvents + markedEvents + plannedEvents).compactMap { event in
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
        for event in events + ongoingEvents + endedEvents + myPublishedEvents + markedEvents + plannedEvents {
            lookup[event.id] = event
        }
        return lookup.values.sorted(by: { $0.startDate < $1.startDate })
    }

    private func mergeUnique(_ source: [WebEvent], excluding other: [WebEvent]) -> [WebEvent] {
        let excluded = Set(other.map(\.id))
        return source.filter { !excluded.contains($0.id) }
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
        if events.isEmpty && ongoingEvents.isEmpty && endedEvents.isEmpty {
            ContentUnavailableView("暂无活动", systemImage: "calendar.badge.plus")
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if !ongoingEvents.isEmpty {
                        sectionHeader("正在进行")
                        ForEach(ongoingEvents) { event in
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

                    if !events.isEmpty {
                        sectionHeader("即将开始")
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
                    }

                    if page <= totalPages && !events.isEmpty {
                        Button("加载更多即将开始") {
                            Task {
                                await loadMore()
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }

                    if !endedEvents.isEmpty {
                        sectionHeader("已结束活动")
                        ForEach(endedEvents) { event in
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

    private var inlineEventSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)

            TextField("搜索活动", text: $searchText)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isSearchFieldFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 32, alignment: .leading)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(RaverTheme.secondaryText.opacity(0.12), lineWidth: 1)
        )
    }

    private func eventTopIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .frame(width: 32, height: 32)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(RaverTheme.secondaryText.opacity(0.12), lineWidth: 1)
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

private enum EventVisualStatus: String {
    case upcoming
    case ongoing
    case ended

    var title: String {
        switch self {
        case .upcoming: return "即将开始"
        case .ongoing: return "进行中"
        case .ended: return "已结束"
        }
    }

    var apiValue: String { rawValue }

    var badgeBackground: Color {
        switch self {
        case .upcoming: return Color.orange.opacity(0.68)
        case .ongoing: return Color.green.opacity(0.68)
        case .ended: return Color.black.opacity(0.58)
        }
    }

    var badgeBorder: Color {
        switch self {
        case .upcoming: return Color.orange.opacity(0.82)
        case .ongoing: return Color.green.opacity(0.84)
        case .ended: return Color.white.opacity(0.24)
        }
    }

    static func resolve(startDate: Date, endDate: Date, fallbackStatus: String? = nil, now: Date = Date()) -> EventVisualStatus {
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
        default:
            return nil
        }
    }
}

private struct OngoingStatusBars: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 5.8

            HStack(alignment: .bottom, spacing: 2) {
                bar(height: animatedHeight(phase: phase))
                bar(height: animatedHeight(phase: phase + 0.8))
                bar(height: animatedHeight(phase: phase + 1.6))
            }
            .frame(height: 10)
        }
        .frame(width: 13, height: 10)
    }

    private func animatedHeight(phase: TimeInterval) -> CGFloat {
        let base: CGFloat = 3
        let amplitude: CGFloat = 6
        return base + abs(CGFloat(sin(phase))) * amplitude
    }

    private func bar(height: CGFloat) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.98))
            .frame(width: 2.6, height: max(3, min(10, height)))
    }
}

private struct EventRow: View {
    let event: WebEvent

    var body: some View {
        let visualStatus = EventVisualStatus.resolve(event: event)
        let coverShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        HStack(alignment: .top, spacing: 12) {
            eventCoverLayer
            .frame(width: 132, height: 150)
            .clipShape(coverShape)
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

                Text((event.eventType?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty) ?? "未分类")
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

    @ViewBuilder
    private var eventCoverLayer: some View {
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
    }

    private var eventDateBadge: some View {
        VStack(spacing: 0) {
            Text(event.startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(RaverTheme.primaryText)
            Text(event.startDate.formatted(.dateTime.day()))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(RaverTheme.primaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var eventDateRangeText: String {
        let calendar = Calendar.current
        let start = event.startDate
        let end = event.endDate

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

private struct EventCheckinDayOption: Identifiable, Hashable {
    let id: String
    let dayIndex: Int
    let dayDate: Date
    let attendedAt: Date

    var title: String { "Day\(dayIndex)" }
    var subtitle: String { dayDate.formatted(date: .abbreviated, time: .omitted) }
}

private struct EventCheckinDJOption: Identifiable, Hashable {
    let id: String
    let djID: String
    let name: String
    let avatarUrl: String?
}

private struct EventCheckinDayPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let eventName: String
    let options: [EventCheckinDayOption]
    let onConfirm: (Set<String>) -> Void

    @State private var selectedAll: Bool
    @State private var selectedDayID: String

    init(eventName: String, options: [EventCheckinDayOption], onConfirm: @escaping (Set<String>) -> Void) {
        self.eventName = eventName
        self.options = options
        self.onConfirm = onConfirm
        let firstID = options.first?.id ?? ""
        _selectedAll = State(initialValue: options.count > 1)
        _selectedDayID = State(initialValue: firstID)
    }

    var body: some View {
        NavigationStack {
            List {
                if options.count > 1 {
                    Button {
                        selectedAll = true
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("全部参加")
                                    .font(.headline)
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text("一次打卡覆盖全部 Day")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer()
                            if selectedAll {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(RaverTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("选择参加日") {
                    ForEach(options) { option in
                        Button {
                            selectedAll = false
                            selectedDayID = option.id
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.title)
                                        .font(.headline)
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Text(option.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                                Spacer()
                                if !selectedAll && selectedDayID == option.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(RaverTheme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("活动打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("下一步") {
                        let selectedIDs: Set<String>
                        if selectedAll {
                            selectedIDs = Set(options.map(\.id))
                        } else {
                            selectedIDs = selectedDayID.isEmpty ? [] : [selectedDayID]
                        }
                        onConfirm(selectedIDs)
                        dismiss()
                    }
                    .disabled(!selectedAll && selectedDayID.isEmpty)
                }
            }
        }
    }
}

private struct EventCheckinDJPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let eventName: String
    let selectedDayTitles: [String]
    let options: [EventCheckinDJOption]
    let onConfirm: (Set<String>) -> Void

    @State private var selectedDJIDs: Set<String> = []

    private var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(eventName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    if !selectedDayTitles.isEmpty {
                        Text("已选择：\(selectedDayTitles.joined(separator: " · "))")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if options.isEmpty {
                        Text("该活动暂未配置可打卡的 DJ，点击确认将仅记录活动打卡。")
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .padding(.top, 6)
                    } else {
                        Text("选择这次你看了哪些 DJ（可多选）")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                            ForEach(options) { option in
                                let isSelected = selectedDJIDs.contains(option.djID)
                                Button {
                                    if isSelected {
                                        selectedDJIDs.remove(option.djID)
                                    } else {
                                        selectedDJIDs.insert(option.djID)
                                    }
                                } label: {
                                    VStack(spacing: 7) {
                                        djAvatar(option)
                                            .frame(width: 56, height: 56)
                                            .overlay(
                                                Circle()
                                                    .stroke(isSelected ? RaverTheme.accent : Color.white.opacity(0.18), lineWidth: isSelected ? 2.2 : 1)
                                            )
                                            .shadow(
                                                color: isSelected ? RaverTheme.accent.opacity(0.72) : .clear,
                                                radius: isSelected ? 10 : 0
                                            )

                                        Text(option.name)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(RaverTheme.primaryText)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .navigationTitle("选择 DJ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(options.isEmpty ? "确认打卡" : "确认打卡(\(selectedDJIDs.count))") {
                        onConfirm(selectedDJIDs)
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func djAvatar(_ option: EventCheckinDJOption) -> some View {
        if let avatar = AppConfig.resolvedURLString(option.avatarUrl), let url = URL(string: avatar) {
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
            .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.card)
                .overlay(
                    Text(String(option.name.prefix(1)).uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        }
    }
}

private enum DJCheckinSubmission {
    case eventBinding(eventID: String, attendedAt: Date)
    case manual(eventName: String, attendedAt: Date)
}

private struct DJCheckinEventBindingOption: Identifiable, Hashable {
    let id: String
    let name: String
    let city: String?
    let country: String?
    let attendedAt: Date?
    let startDate: Date?
}

private struct DJCheckinBindingSheet: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case bindEvent
        case manual

        var id: String { rawValue }
        var title: String {
            switch self {
            case .bindEvent: return "绑定活动"
            case .manual: return "手动填写"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let djName: String
    let onConfirm: (DJCheckinSubmission) -> Void

    @State private var mode: Mode = .bindEvent
    @State private var eventSearchText = ""
    @State private var historyOptions: [DJCheckinEventBindingOption] = []
    @State private var remoteOptions: [DJCheckinEventBindingOption] = []
    @State private var selectedEventID: String?
    @State private var manualEventName = ""
    @State private var manualAttendedAt = Date()
    @State private var isLoadingHistory = false
    @State private var isSearchingEvents = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("打卡方式", selection: $mode) {
                        ForEach(Mode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .bindEvent {
                    Section("绑定到活动（优先）") {
                        TextField("搜索活动名称", text: $eventSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        if isLoadingHistory && historyOptions.isEmpty {
                            ProgressView("读取你的活动历史...")
                        }

                        if !filteredHistoryOptions.isEmpty {
                            Text("我的活动历史")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)

                            ForEach(filteredHistoryOptions) { option in
                                eventOptionRow(option)
                            }
                        }

                        if !eventSearchKeyword.isEmpty {
                            Text("搜索结果")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)

                            if isSearchingEvents {
                                ProgressView("搜索活动中...")
                            } else if remoteOptions.isEmpty {
                                Text("没有更多匹配活动")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
                                ForEach(remoteOptions) { option in
                                    eventOptionRow(option)
                                }
                            }
                        }

                        if let selectedOption {
                            Text("将自动按活动时间记录打卡：\(autoAttendedAt(for: selectedOption).formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            Text("请在搜索或历史中选择一场活动。")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                } else {
                    Section("手动填写") {
                        TextField("活动名称", text: $manualEventName)
                        DatePicker(
                            "观演时间",
                            selection: $manualAttendedAt,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle("\(djName) 打卡")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadHistory()
            }
            .onChange(of: eventSearchText) { _, _ in
                guard mode == .bindEvent else { return }
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled else { return }
                    await searchEvents()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认打卡") {
                        switch mode {
                        case .bindEvent:
                            guard let selectedOption else { return }
                            onConfirm(
                                .eventBinding(
                                    eventID: selectedOption.id,
                                    attendedAt: autoAttendedAt(for: selectedOption)
                                )
                            )
                        case .manual:
                            let trimmed = manualEventName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            onConfirm(.manual(eventName: trimmed, attendedAt: manualAttendedAt))
                        }
                        dismiss()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    @ViewBuilder
    private func eventOptionRow(_ option: DJCheckinEventBindingOption) -> some View {
        Button {
            selectedEventID = option.id
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)

                    Text(eventOptionSubtitle(option))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                if selectedEventID == option.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(RaverTheme.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var canConfirm: Bool {
        switch mode {
        case .bindEvent:
            return selectedOption != nil
        case .manual:
            return !manualEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var eventSearchKeyword: String {
        eventSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredHistoryOptions: [DJCheckinEventBindingOption] {
        guard !eventSearchKeyword.isEmpty else { return historyOptions }
        let keyword = eventSearchKeyword.lowercased()
        return historyOptions.filter { option in
            option.name.lowercased().contains(keyword)
                || (option.city?.lowercased().contains(keyword) ?? false)
                || (option.country?.lowercased().contains(keyword) ?? false)
        }
    }

    private var selectedOption: DJCheckinEventBindingOption? {
        guard let selectedEventID else { return nil }
        return (historyOptions + remoteOptions).first(where: { $0.id == selectedEventID })
    }

    private func autoAttendedAt(for option: DJCheckinEventBindingOption) -> Date {
        if let attendedAt = option.attendedAt {
            return min(attendedAt, Date())
        }
        if let startDate = option.startDate {
            return min(startDate, Date())
        }
        return Date()
    }

    private func eventOptionSubtitle(_ option: DJCheckinEventBindingOption) -> String {
        let location = [option.city, option.country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")

        if let attendedAt = option.attendedAt {
            let attendedText = attendedAt.formatted(date: .abbreviated, time: .shortened)
            return location.isEmpty ? "我参加于 \(attendedText)" : "\(location) · 我参加于 \(attendedText)"
        }

        if let startDate = option.startDate {
            let startText = startDate.formatted(date: .abbreviated, time: .shortened)
            return location.isEmpty ? "开始于 \(startText)" : "\(location) · 开始于 \(startText)"
        }

        return location.isEmpty ? "活动信息" : location
    }

    private func loadHistory() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let page = try await service.fetchMyCheckins(page: 1, limit: 200, type: nil)
            var latestByEventID: [String: DJCheckinEventBindingOption] = [:]

            for item in page.items {
                let normalizedNote = item.note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normalizedNote == "planned" {
                    continue
                }
                guard let event = item.event else { continue }
                let candidate = DJCheckinEventBindingOption(
                    id: event.id,
                    name: event.name,
                    city: event.city,
                    country: event.country,
                    attendedAt: item.attendedAt,
                    startDate: event.startDate
                )

                if let existing = latestByEventID[event.id] {
                    if item.attendedAt > (existing.attendedAt ?? .distantPast) {
                        latestByEventID[event.id] = candidate
                    }
                } else {
                    latestByEventID[event.id] = candidate
                }
            }

            historyOptions = latestByEventID.values.sorted {
                ($0.attendedAt ?? $0.startDate ?? .distantPast) > ($1.attendedAt ?? $1.startDate ?? .distantPast)
            }

            if selectedEventID == nil {
                selectedEventID = historyOptions.first?.id
            }
        } catch {
            // Keep sheet usable even if history loading fails.
            historyOptions = []
        }
    }

    private func searchEvents() async {
        let keyword = eventSearchKeyword
        guard !keyword.isEmpty else {
            remoteOptions = []
            isSearchingEvents = false
            return
        }

        isSearchingEvents = true
        defer { isSearchingEvents = false }

        do {
            let page = try await service.fetchEvents(
                page: 1,
                limit: 20,
                search: keyword,
                eventType: nil,
                status: "all"
            )

            if Task.isCancelled || keyword != eventSearchKeyword {
                return
            }

            let historyIDs = Set(historyOptions.map(\.id))
            remoteOptions = page.items
                .filter { !historyIDs.contains($0.id) }
                .map {
                    DJCheckinEventBindingOption(
                        id: $0.id,
                        name: $0.name,
                        city: $0.city,
                        country: $0.country,
                        attendedAt: nil,
                        startDate: $0.startDate
                    )
                }
        } catch {
            if keyword == eventSearchKeyword {
                remoteOptions = []
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
    @State private var showEventCheckinDaySheet = false
    @State private var showEventCheckinDJSheet = false
    @State private var selectedEventCheckinDayIDs: Set<String> = []
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
                                    beginEventCheckinFlow(for: event)
                                } label: {
                                    Label("活动打卡", systemImage: "bookmark.fill")
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

                                    eventStatusLine(EventVisualStatus.resolve(event: event))

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
                                        if let avatar = AppConfig.resolvedURLString(organizer.avatarUrl),
                                           let url = URL(string: avatar),
                                           avatar.hasPrefix("http://") || avatar.hasPrefix("https://") {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    Circle().fill(RaverTheme.card)
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                case .failure:
                                                    organizerAvatarFallback(organizer)
                                                @unknown default:
                                                    organizerAvatarFallback(organizer)
                                                }
                                            }
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                        } else {
                                            organizerAvatarFallback(organizer)
                                        }
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
                .sheet(isPresented: $showEventCheckinDaySheet) {
                    EventCheckinDayPickerSheet(
                        eventName: event.name,
                        options: eventCheckinDayOptions(for: event)
                    ) { selectedIDs in
                        selectedEventCheckinDayIDs = selectedIDs
                        showEventCheckinDJSheet = true
                    }
                    .presentationDetents([.fraction(0.48), .medium])
                }
                .sheet(isPresented: $showEventCheckinDJSheet) {
                    EventCheckinDJPickerSheet(
                        eventName: event.name,
                        selectedDayTitles: selectedDayTitles(for: event, selectedDayIDs: selectedEventCheckinDayIDs),
                        options: eventCheckinDJOptions(for: event, selectedDayIDs: selectedEventCheckinDayIDs)
                    ) { selectedDJIDs in
                        Task { await submitEventCheckins(selectedDJIDs: selectedDJIDs) }
                    }
                    .presentationDetents([.fraction(0.66), .large])
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
        //.padding(.top, max(topSafeAreaInset() - 6, 0))
        .padding(.top, 0)
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

    private func organizerAvatarFallback(_ organizer: WebUserLite) -> some View {
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
    }

    @ViewBuilder
    private func eventStatusLine(_ status: EventVisualStatus) -> some View {
        HStack(spacing: 8) {
            if status == .ongoing {
                OngoingStatusBars()
            } else {
                Circle()
                    .fill(status.badgeBorder.opacity(0.95))
                    .frame(width: 7, height: 7)
            }
            Text("状态：\(status.title)")
                .foregroundStyle(RaverTheme.secondaryText)
                .font(.subheadline)
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

    private func beginEventCheckinFlow(for event: WebEvent) {
        let dayOptions = eventCheckinDayOptions(for: event)
        guard !dayOptions.isEmpty else { return }

        if dayOptions.count == 1 {
            selectedEventCheckinDayIDs = [dayOptions[0].id]
            showEventCheckinDJSheet = true
        } else {
            selectedEventCheckinDayIDs = Set(dayOptions.map(\.id))
            showEventCheckinDaySheet = true
        }
    }

    private func eventCheckinDayOptions(for event: WebEvent) -> [EventCheckinDayOption] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: event.startDate)
        let normalizedEnd = max(event.endDate, event.startDate)
        let endDay = calendar.startOfDay(for: normalizedEnd)

        var dayDates: [Date] = []
        var cursor = startDay
        while cursor <= endDay {
            dayDates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        if dayDates.isEmpty {
            dayDates = [startDay]
        }

        return dayDates.enumerated().map { index, dayDate in
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayDate) ?? dayDate
            let slotsOnDay = event.lineupSlots.filter { slot in
                slot.startTime >= dayDate && slot.startTime < dayEnd
            }
            let fallback = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: dayDate) ?? dayDate
            let baseAttendedAt = slotsOnDay.map(\.startTime).min() ?? (index == 0 ? event.startDate : fallback)
            let attendedAt = min(baseAttendedAt, Date())

            return EventCheckinDayOption(
                id: Self.eventCheckinDayKey(for: dayDate),
                dayIndex: index + 1,
                dayDate: dayDate,
                attendedAt: attendedAt
            )
        }
    }

    private func selectedDayTitles(for event: WebEvent, selectedDayIDs: Set<String>) -> [String] {
        eventCheckinDayOptions(for: event)
            .filter { selectedDayIDs.contains($0.id) }
            .map(\.title)
    }

    private func eventCheckinDJOptions(for event: WebEvent, selectedDayIDs: Set<String>) -> [EventCheckinDJOption] {
        guard !selectedDayIDs.isEmpty else { return [] }

        var firstStartByDJID: [String: Date] = [:]
        var optionByDJID: [String: EventCheckinDJOption] = [:]

        for slot in event.lineupSlots.sorted(by: { $0.startTime < $1.startTime }) {
            let key = Self.eventCheckinDayKey(for: slot.startTime)
            guard selectedDayIDs.contains(key) else { continue }

            let resolvedDJID: String? = {
                if let id = slot.dj?.id, !id.isEmpty { return id }
                let fallback = slot.djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return fallback.isEmpty ? nil : fallback
            }()

            guard let djID = resolvedDJID else { continue }
            let djName = (slot.dj?.name ?? slot.djName).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !djName.isEmpty else { continue }

            let shouldReplace: Bool
            if let existingStart = firstStartByDJID[djID] {
                shouldReplace = slot.startTime < existingStart
            } else {
                shouldReplace = true
            }

            if shouldReplace {
                firstStartByDJID[djID] = slot.startTime
                optionByDJID[djID] = EventCheckinDJOption(
                    id: djID,
                    djID: djID,
                    name: djName,
                    avatarUrl: slot.dj?.avatarUrl
                )
            }
        }

        return optionByDJID.values.sorted {
            let lhsDate = firstStartByDJID[$0.djID] ?? .distantFuture
            let rhsDate = firstStartByDJID[$1.djID] ?? .distantFuture
            return lhsDate < rhsDate
        }
    }

    private func submitEventCheckins(selectedDJIDs: Set<String>) async {
        guard let event else { return }
        let dayOptions = eventCheckinDayOptions(for: event).filter { selectedEventCheckinDayIDs.contains($0.id) }
        guard !dayOptions.isEmpty else {
            errorMessage = "请先选择活动参加日"
            return
        }

        do {
            var createdDJCheckins = 0
            for day in dayOptions {
                _ = try await service.createCheckin(
                    input: CreateCheckinInput(
                        type: "event",
                        eventId: eventID,
                        djId: nil,
                        note: nil,
                        rating: nil,
                        attendedAt: day.attendedAt
                    )
                )

                for djID in selectedDJIDs.sorted() {
                    _ = try await service.createCheckin(
                        input: CreateCheckinInput(
                            type: "dj",
                            eventId: eventID,
                            djId: djID,
                            note: nil,
                            rating: nil,
                            attendedAt: day.attendedAt
                        )
                    )
                    createdDJCheckins += 1
                }
            }

            if createdDJCheckins > 0 {
                errorMessage = "已完成活动打卡，并新增 \(createdDJCheckins) 条 DJ 打卡"
            } else {
                errorMessage = "活动打卡成功"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func eventCheckinDayKey(for date: Date) -> String {
        eventCheckinDayFormatter.string(from: date)
    }

    private static let eventCheckinDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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

    private static let eventTypeOptions = ["电音节", "酒吧活动", "露天活动", "俱乐部派对", "仓库派对", "巡演专场", "其他"]

    private enum LineupInputMode: String, CaseIterable, Identifiable {
        case search
        case batch

        var id: String { rawValue }

        var title: String {
            switch self {
            case .search: return "逐个搜索添加"
            case .batch: return "批量导入"
            }
        }
    }

    private struct EditableLineupSlot: Identifiable, Hashable {
        let id: UUID
        var djId: String?
        var djName: String
        var stageName: String
        var hasTimetable: Bool
        var startTime: Date
        var endTime: Date

        init(
            id: UUID = UUID(),
            djId: String?,
            djName: String,
            stageName: String = "",
            hasTimetable: Bool = false,
            startTime: Date,
            endTime: Date
        ) {
            self.id = id
            self.djId = djId
            self.djName = djName
            self.stageName = stageName
            self.hasTimetable = hasTimetable
            self.startTime = startTime
            self.endTime = endTime
        }
    }

    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let mode: Mode
    let onSaved: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var eventType = ""
    @State private var city = ""
    @State private var country = ""
    @State private var venueName = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7200)
    @State private var coverImageUrl = ""
    @State private var lineupImageUrl = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedLineupPhoto: PhotosPickerItem?
    @State private var lineupInputMode: LineupInputMode = .search
    @State private var lineupEntries: [EditableLineupSlot] = []
    @State private var djSearchKeyword = ""
    @State private var djSearchResults: [WebDJ] = []
    @State private var isSearchingDJs = false
    @State private var batchLineupText = ""
    @State private var batchImportFeedback: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("活动名称", text: $name)
                    TextField("简介", text: $description, axis: .vertical)
                    Picker("活动性质", selection: $eventType) {
                        Text("请选择活动性质").tag("")
                        ForEach(Self.eventTypeOptions, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                    TextField("城市", text: $city)
                    TextField("国家", text: $country)
                    TextField("场地", text: $venueName)
                }

                Section("时间") {
                    DatePicker("开始时间", selection: $startDate)
                    DatePicker("结束时间", selection: $endDate)
                }

                Section("图片") {
                    TextField("封面 URL（选填）", text: $coverImageUrl)
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label("上传封面图", systemImage: "photo")
                    }
                    if selectedCoverPhoto != nil {
                        Text("已选择本地封面图，保存时会自动上传并作为活动封面。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    TextField("活动阵容图 URL（选填）", text: $lineupImageUrl)
                    PhotosPicker(selection: $selectedLineupPhoto, matching: .images) {
                        Label("上传活动阵容图", systemImage: "photo.on.rectangle")
                    }
                    if selectedLineupPhoto != nil {
                        Text("已选择本地阵容图，保存时会自动上传并应用。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                Section("DJ 阵容与 Timetable") {
                    Picker("录入方式", selection: $lineupInputMode) {
                        ForEach(LineupInputMode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch lineupInputMode {
                    case .search:
                        TextField("从 DJ 库搜索名字", text: $djSearchKeyword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        if isSearchingDJs {
                            ProgressView("搜索 DJ 中...")
                        } else if !djSearchResults.isEmpty {
                            ForEach(djSearchResults.prefix(8)) { dj in
                                HStack(spacing: 10) {
                                    AsyncImage(url: URL(string: AppConfig.resolvedURLString(dj.avatarUrl) ?? "")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            Circle()
                                                .fill(RaverTheme.card)
                                                .overlay(
                                                    Text(String(dj.name.prefix(1)).uppercased())
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(RaverTheme.secondaryText)
                                                )
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(dj.name)
                                            .font(.subheadline.weight(.semibold))
                                        if let country = dj.country, !country.isEmpty {
                                            Text(country)
                                                .font(.caption)
                                                .foregroundStyle(RaverTheme.secondaryText)
                                        }
                                    }

                                    Spacer()

                                    Button("添加") {
                                        addDJFromLibrary(dj)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 2)
                            }
                        } else if !trimmedDJSearchKeyword.isEmpty {
                            Text("未搜索到匹配 DJ")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    case .batch:
                        Text("批量格式：每行一条，`DJ 名称 | 开始时间(可选) | 结束时间(可选) | 舞台(可选)`")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text("示例：`Amelie Lens | 2026-04-18 21:00 | 2026-04-18 22:30 | Main Stage`")
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)

                        TextEditor(text: $batchLineupText)
                            .frame(minHeight: 120, maxHeight: 180)

                        Button("解析并追加到阵容") {
                            importBatchLineup()
                        }

                        if let batchImportFeedback, !batchImportFeedback.isEmpty {
                            Text(batchImportFeedback)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }

                Section("已添加阵容（可继续编辑时间）") {
                    if lineupEntries.isEmpty {
                        Text("尚未添加 DJ。你可以搜索逐个添加，或用批量文本一次导入。")
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        ForEach($lineupEntries) { $slot in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    TextField("DJ 名称", text: $slot.djName)
                                        .font(.subheadline.weight(.semibold))
                                    if slot.djId != nil {
                                        Text("DJ 库")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(RaverTheme.accent.opacity(0.15))
                                            .foregroundStyle(RaverTheme.accent)
                                            .clipShape(Capsule())
                                    }
                                }

                                TextField("舞台（可选）", text: $slot.stageName)

                                Toggle("填写表演时间（可选）", isOn: $slot.hasTimetable.animation(.easeInOut(duration: 0.2)))
                                    .font(.subheadline)

                                if slot.hasTimetable {
                                    DatePicker("开始表演", selection: $slot.startTime)
                                    DatePicker("结束表演", selection: $slot.endTime)
                                }

                                Button(role: .destructive) {
                                    removeLineupSlot(slot.id)
                                } label: {
                                    Label("移除这个 DJ", systemImage: "trash")
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
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
            .task(id: lineupSearchTaskKey) {
                await searchDJsIfNeeded()
            }
            .onChange(of: startDate) { _, newValue in
                guard case .create = mode else { return }
                if endDate != newValue {
                    endDate = newValue
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

    private func prefillIfNeeded() {
        guard case .edit(let event) = mode else { return }
        if !name.isEmpty { return }

        name = event.name
        description = event.description ?? ""
        eventType = event.eventType ?? ""
        city = event.city ?? ""
        country = event.country ?? ""
        venueName = event.venueName ?? ""
        startDate = event.startDate
        endDate = event.endDate
        coverImageUrl = event.coverImageUrl ?? ""
        lineupImageUrl = event.lineupImageUrl ?? ""
        lineupEntries = event.lineupSlots
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.startTime < $1.startTime
                }
                return $0.sortOrder < $1.sortOrder
            }
            .map { slot in
                let hasExplicitTimetable = abs(slot.endTime.timeIntervalSince(slot.startTime)) >= 1
                return EditableLineupSlot(
                    djId: slot.djId,
                    djName: slot.dj?.name ?? slot.djName,
                    stageName: slot.stageName ?? "",
                    hasTimetable: hasExplicitTimetable,
                    startTime: slot.startTime,
                    endTime: slot.endTime
                )
            }
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

        guard let lineupSlotsInput = buildLineupSlotsInput() else {
            return
        }

        let resolvedEventType = eventType.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedStatus = EventVisualStatus.resolve(startDate: startDate, endDate: endDate).apiValue

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
                        eventType: resolvedEventType,
                        city: city.nilIfEmpty,
                        country: country.nilIfEmpty,
                        venueName: venueName.nilIfEmpty,
                        startDate: startDate,
                        endDate: endDate,
                        coverImageUrl: finalCover.nilIfEmpty,
                        lineupImageUrl: finalLineup.nilIfEmpty,
                        lineupSlots: lineupSlotsInput,
                        status: resolvedStatus
                    )
                )
            case .edit(let event):
                _ = try await service.updateEvent(
                    id: event.id,
                    input: UpdateEventInput(
                        name: trimmedName,
                        description: description.nilIfEmpty,
                        eventType: resolvedEventType,
                        city: city.nilIfEmpty,
                        country: country.nilIfEmpty,
                        venueName: venueName.nilIfEmpty,
                        startDate: startDate,
                        endDate: endDate,
                        coverImageUrl: finalCover.nilIfEmpty,
                        lineupImageUrl: finalLineup.nilIfEmpty,
                        lineupSlots: lineupSlotsInput,
                        status: resolvedStatus
                    )
                )
            }

            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var trimmedDJSearchKeyword: String {
        djSearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var lineupSearchTaskKey: String {
        guard lineupInputMode == .search else { return "" }
        return trimmedDJSearchKeyword
    }

    private func searchDJsIfNeeded() async {
        guard lineupInputMode == .search else {
            djSearchResults = []
            isSearchingDJs = false
            return
        }

        let keyword = trimmedDJSearchKeyword
        guard !keyword.isEmpty else {
            djSearchResults = []
            isSearchingDJs = false
            return
        }

        isSearchingDJs = true
        defer { isSearchingDJs = false }

        do {
            try await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            let page = try await service.fetchDJs(page: 1, limit: 20, search: keyword, sortBy: "name")
            if Task.isCancelled || keyword != trimmedDJSearchKeyword {
                return
            }
            djSearchResults = page.items
        } catch is CancellationError {
            return
        } catch {
            if keyword == trimmedDJSearchKeyword {
                errorMessage = "DJ 搜索失败：\(error.localizedDescription)"
            }
        }
    }

    private func addDJFromLibrary(_ dj: WebDJ) {
        let defaultStart = startDate
        let defaultEnd = startDate.addingTimeInterval(3600)
        lineupEntries.append(
            EditableLineupSlot(
                djId: dj.id,
                djName: dj.name,
                stageName: "",
                hasTimetable: false,
                startTime: defaultStart,
                endTime: defaultEnd
            )
        )
    }

    private func removeLineupSlot(_ id: UUID) {
        lineupEntries.removeAll { $0.id == id }
    }

    private func buildLineupSlotsInput() -> [EventLineupSlotInput]? {
        var result: [EventLineupSlotInput] = []

        for (index, item) in lineupEntries.enumerated() {
            let djName = item.djName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !djName.isEmpty else {
                errorMessage = "第 \(index + 1) 个 DJ 名称为空，请补全或删除后再保存"
                return nil
            }

            if item.hasTimetable && item.endTime < item.startTime {
                errorMessage = "第 \(index + 1) 个 DJ 的结束时间不能早于开始时间"
                return nil
            }

            result.append(
                EventLineupSlotInput(
                    djId: item.djId,
                    djName: djName,
                    stageName: item.stageName.nilIfEmpty,
                    sortOrder: index + 1,
                    startTime: item.hasTimetable ? item.startTime : nil,
                    endTime: item.hasTimetable ? item.endTime : nil
                )
            )
        }

        return result
    }

    private func importBatchLineup() {
        let lines = batchLineupText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            errorMessage = "请先粘贴 name+timetable 列表"
            return
        }

        var imported: [EditableLineupSlot] = []
        var errors: [String] = []

        for (index, line) in lines.enumerated() {
            let columns = line
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            let djName = columns.first ?? ""
            if djName.isEmpty {
                errors.append("第 \(index + 1) 行缺少 DJ 名称")
                continue
            }

            let startText = columns.count > 1 ? columns[1] : ""
            let endText = columns.count > 2 ? columns[2] : ""
            let stageText = columns.count > 3 ? columns[3...].joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines) : ""

            let parsedStart = parseBatchDate(startText, referenceDate: startDate)
            let parsedEnd = parseBatchDate(endText, referenceDate: startDate)

            if !startText.isEmpty && parsedStart == nil {
                errors.append("第 \(index + 1) 行开始时间格式错误")
                continue
            }
            if !endText.isEmpty && parsedEnd == nil {
                errors.append("第 \(index + 1) 行结束时间格式错误")
                continue
            }

            var hasTimetable = false
            var slotStart = startDate
            var slotEnd = startDate.addingTimeInterval(3600)

            if let parsedStart, let parsedEnd {
                hasTimetable = true
                slotStart = parsedStart
                slotEnd = parsedEnd
            } else if let parsedStart {
                hasTimetable = true
                slotStart = parsedStart
                slotEnd = parsedStart.addingTimeInterval(3600)
            } else if let parsedEnd {
                hasTimetable = true
                slotStart = parsedEnd.addingTimeInterval(-3600)
                slotEnd = parsedEnd
            }

            if hasTimetable && slotEnd < slotStart {
                errors.append("第 \(index + 1) 行结束时间早于开始时间")
                continue
            }

            imported.append(
                EditableLineupSlot(
                    djId: nil,
                    djName: djName,
                    stageName: stageText,
                    hasTimetable: hasTimetable,
                    startTime: slotStart,
                    endTime: slotEnd
                )
            )
        }

        guard !imported.isEmpty else {
            errorMessage = errors.first ?? "没有可导入的数据，请检查格式"
            return
        }

        lineupEntries.append(contentsOf: imported)
        batchLineupText = ""

        if errors.isEmpty {
            batchImportFeedback = "已成功导入 \(imported.count) 条阵容"
        } else {
            batchImportFeedback = "已导入 \(imported.count) 条，另有 \(errors.count) 条未导入"
        }
    }

    private func parseBatchDate(_ value: String, referenceDate: Date) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for formatter in Self.batchDateParsers {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        guard let timeOnly = Self.batchTimeParser.date(from: trimmed) else {
            return nil
        }

        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: timeOnly)
        var base = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        base.hour = time.hour
        base.minute = time.minute
        base.second = 0
        return calendar.date(from: base)
    }

    private static let batchDateParsers: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd HH:mm",
            "yyyy.MM.dd HH:mm",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            return formatter
        }
    }()

    private static let batchTimeParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private enum DiscoverNewsCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case festival = "电音节"
    case scene = "现场观察"
    case gear = "设备玩法"
    case industry = "行业动态"
    case community = "社区话题"

    var id: String { rawValue }

    var badgeColor: Color {
        switch self {
        case .all: return RaverTheme.secondaryText
        case .festival: return Color(red: 0.96, green: 0.52, blue: 0.20)
        case .scene: return Color(red: 0.35, green: 0.67, blue: 0.96)
        case .gear: return Color(red: 0.40, green: 0.79, blue: 0.38)
        case .industry: return Color(red: 0.87, green: 0.53, blue: 0.29)
        case .community: return Color(red: 0.70, green: 0.55, blue: 0.92)
        }
    }

    static func mapFromRaw(_ raw: String) -> DiscoverNewsCategory {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = DiscoverNewsCategory.allCases.first(where: { $0.rawValue == normalized }) {
            return exact
        }
        if normalized.contains("电音") || normalized.contains("活动") {
            return .festival
        }
        if normalized.contains("现场") || normalized.contains("演出") {
            return .scene
        }
        if normalized.contains("设备") || normalized.contains("插件") {
            return .gear
        }
        if normalized.contains("行业") || normalized.contains("厂牌") {
            return .industry
        }
        return .community
    }
}

private struct DiscoverNewsDraft {
    var category: DiscoverNewsCategory
    var source: String
    var title: String
    var summary: String
    var body: String
    var link: String?
    var coverImageURL: String?
}

private struct DiscoverNewsArticle: Identifiable, Hashable {
    let id: String
    let category: DiscoverNewsCategory
    let source: String
    let title: String
    let summary: String
    let body: String
    let link: String?
    let coverImageURL: String?
    let publishedAt: Date
    let replyCount: Int
    let authorID: String
    let authorUsername: String
    let authorName: String
    let authorAvatarURL: String?
}

private enum DiscoverNewsCodec {
    static let marker = Post.raverNewsMarker

    static func encode(_ draft: DiscoverNewsDraft) -> String {
        let lines: [String?] = [
            marker,
            "标题：\(singleLine(draft.title))",
            "分类：\(draft.category.rawValue)",
            "来源：\(singleLine(draft.source))",
            "摘要：\(singleLine(draft.summary))",
            draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "正文：\(singleLine(draft.body))",
            draft.link?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? "链接：\(singleLine(draft.link ?? ""))"
                : nil
        ]
        return lines.compactMap { $0 }.joined(separator: "\n")
    }

    static func decode(post: Post) -> DiscoverNewsArticle? {
        let lines = post.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.contains(marker) else { return nil }

        let title = value(for: ["标题", "title"], in: lines) ?? "未命名资讯"
        let summary = value(for: ["摘要", "summary"], in: lines) ?? "暂无摘要"
        let source = value(for: ["来源", "source"], in: lines) ?? "社区投稿"
        let rawCategory = value(for: ["分类", "category"], in: lines) ?? DiscoverNewsCategory.community.rawValue
        let body = value(for: ["正文", "content", "body"], in: lines) ?? ""
        let link = value(for: ["链接", "url", "link"], in: lines)

        let trimmedDisplayName = post.author.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorName = trimmedDisplayName.isEmpty ? post.author.username : trimmedDisplayName

        return DiscoverNewsArticle(
            id: post.id,
            category: DiscoverNewsCategory.mapFromRaw(rawCategory),
            source: source,
            title: title,
            summary: summary,
            body: body,
            link: link,
            coverImageURL: post.images.first,
            publishedAt: post.createdAt,
            replyCount: post.commentCount,
            authorID: post.author.id,
            authorUsername: post.author.username,
            authorName: authorName,
            authorAvatarURL: post.author.avatarURL
        )
    }

    private static func value(for keys: [String], in lines: [String]) -> String? {
        for line in lines {
            for key in keys {
                if let found = valueAfter(key: key, in: line) {
                    return found
                }
            }
        }
        return nil
    }

    private static func valueAfter(key: String, in line: String) -> String? {
        let pairs = ["\(key)：", "\(key):", "\(key.uppercased())：", "\(key.uppercased()):"]
        for prefix in pairs where line.hasPrefix(prefix) {
            let raw = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }
        return nil
    }

    private static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NewsModuleView: View {
    private let socialService = AppEnvironment.makeService()

    @State private var articles: [DiscoverNewsArticle] = []
    @State private var nextCursor: String?
    @State private var selectedCategory: DiscoverNewsCategory = .all
    @State private var isLoading = false
    @State private var isPresentingPublish = false
    @State private var selectedArticleForDetail: DiscoverNewsArticle?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && articles.isEmpty {
                    ProgressView("资讯加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if displayedArticles.isEmpty {
                    VStack(spacing: 12) {
                        ContentUnavailableView("暂无资讯", systemImage: "newspaper")
                        Text("点击右上角“发布资讯”发布图文内容后会显示在这里。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(displayedArticles.enumerated()), id: \.element.id) { index, article in
                                Button {
                                    selectedArticleForDetail = article
                                } label: {
                                    DiscoverNewsRow(article: article)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())

                                if index < displayedArticles.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }

                            if nextCursor != nil {
                                Button("加载更多资讯") {
                                    Task { await loadMore() }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        HorizontalAxisLockedScrollView(showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DiscoverNewsCategory.allCases) { category in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedCategory = category
                                        }
                                    } label: {
                                        Text(category.rawValue)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(selectedCategory == category ? .white : RaverTheme.primaryText)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                    .fill(selectedCategory == category ? category.badgeColor : RaverTheme.card)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 16)
                        }
                        .frame(height: 34)

                        Button {
                            isPresentingPublish = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(red: 0.96, green: 0.51, blue: 0.18))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(RaverTheme.background)
            }
            .sheet(isPresented: $isPresentingPublish) {
                DiscoverNewsPublishSheet { draft in
                    try await publish(draft)
                }
            }
            .fullScreenCover(item: $selectedArticleForDetail) { article in
                NavigationStack {
                    DiscoverNewsDetailView(article: article)
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

    private var displayedArticles: [DiscoverNewsArticle] {
        if selectedCategory == .all {
            return articles
        }
        return articles.filter { $0.category == selectedCategory }
    }

    @MainActor
    private func reload() async {
        articles = []
        nextCursor = nil
        await loadMore()
    }

    @MainActor
    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var cursor = nextCursor
            var parsed: [DiscoverNewsArticle] = []
            var fetchedPageCursor: String?
            var fetchCount = 0

            repeat {
                let page = try await socialService.fetchFeed(cursor: cursor)
                fetchedPageCursor = page.nextCursor
                parsed.append(contentsOf: page.posts.compactMap { DiscoverNewsCodec.decode(post: $0) })
                cursor = fetchedPageCursor
                fetchCount += 1
            } while parsed.isEmpty && fetchedPageCursor != nil && fetchCount < 3

            let existingIDs = Set(articles.map(\.id))
            let merged = parsed.filter { !existingIDs.contains($0.id) }
            articles.append(contentsOf: merged)
            nextCursor = fetchedPageCursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func publish(_ draft: DiscoverNewsDraft) async throws {
        let content = DiscoverNewsCodec.encode(draft)
        let imageURLs = draft.coverImageURL.flatMap { $0.isEmpty ? nil : [$0] } ?? []
        let created = try await socialService.createPost(
            input: CreatePostInput(content: content, images: imageURLs)
        )
        if let article = DiscoverNewsCodec.decode(post: created) {
            articles.insert(article, at: 0)
        } else {
            await reload()
        }
    }
}

private struct DiscoverNewsRow: View {
    let article: DiscoverNewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(article.category.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(article.category.badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(article.category.badgeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(article.source)
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Text(article.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                Text(article.summary)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Text(article.publishedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                    Label("\(article.replyCount)", systemImage: "bubble.left")
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .labelStyle(.titleAndIcon)
                }
            }

            Spacer(minLength: 0)

            newsCover
                .frame(width: 122, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var newsCover: some View {
        if let resolved = AppConfig.resolvedURLString(article.coverImageURL),
           let url = URL(string: resolved) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RaverTheme.card
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackCover
                @unknown default:
                    fallbackCover
                }
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        LinearGradient(
            colors: [Color(red: 0.14, green: 0.17, blue: 0.21), Color(red: 0.11, green: 0.13, blue: 0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "newspaper.fill")
                .font(.title3)
                .foregroundStyle(RaverTheme.secondaryText.opacity(0.8))
        )
    }
}

private struct DiscoverNewsDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let article: DiscoverNewsArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                newsCover
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(article.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)

                HStack(spacing: 8) {
                    Text(article.category.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(article.category.badgeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(article.category.badgeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Text(article.source)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    Spacer(minLength: 8)

                    Label("\(article.replyCount) 回复", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                HStack(spacing: 6) {
                    Text(article.publishedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text("回复 \(article.replyCount)")
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                NavigationLink {
                    UserProfileView(userID: article.authorID)
                } label: {
                    HStack(spacing: 10) {
                        authorAvatar
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.authorName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                            Text("@\(article.authorUsername)")
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Divider()

                Text(article.summary)
                    .font(.body)
                    .foregroundStyle(RaverTheme.primaryText)

                if !article.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(article.body)
                        .font(.callout)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineSpacing(4)
                }

                if let link = article.link,
                   let url = URL(string: link) {
                    Link(destination: url) {
                        Label("查看原文链接", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(RaverTheme.accent)
                    .padding(.top, 6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RaverTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.36))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("资讯详情")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)

                Spacer()

                // 占位，保持标题居中
                Color.clear
                    .frame(width: 34, height: 34)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var newsCover: some View {
        if let resolved = AppConfig.resolvedURLString(article.coverImageURL),
           let url = URL(string: resolved) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RaverTheme.card
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackCover
                @unknown default:
                    fallbackCover
                }
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        LinearGradient(
            colors: [Color(red: 0.14, green: 0.17, blue: 0.21), Color(red: 0.11, green: 0.13, blue: 0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "newspaper.fill")
                .font(.title2)
                .foregroundStyle(RaverTheme.secondaryText.opacity(0.8))
        )
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let resolved = AppConfig.resolvedURLString(article.authorAvatarURL),
           let url = URL(string: resolved) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle().fill(RaverTheme.card)
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    avatarFallback
                @unknown default:
                    avatarFallback
                }
            }
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        Circle()
            .fill(RaverTheme.card)
            .overlay(
                Text(String(article.authorName.prefix(1)).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            )
    }
}

private struct DiscoverNewsPublishSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let webService = AppEnvironment.makeWebService()

    let onSubmit: (DiscoverNewsDraft) async throws -> Void

    @State private var category: DiscoverNewsCategory = .festival
    @State private var sourceName = ""
    @State private var title = ""
    @State private var summary = ""
    @State private var bodyText = ""
    @State private var linkText = ""
    @State private var coverURL = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var isSubmitting = false
    @State private var isUploadingCover = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    Picker("分类", selection: $category) {
                        ForEach(DiscoverNewsCategory.allCases.filter { $0 != .all }) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    TextField("来源名称", text: $sourceName)
                    TextField("资讯标题", text: $title)
                    TextField("资讯摘要", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("正文（选填）", text: $bodyText, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("封面图") {
                    TextField("封面图 URL（选填）", text: $coverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? "从相册上传封面图" : "更换封面图", systemImage: "photo")
                    }

                    if let selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Section("外链（选填）") {
                    TextField("原文链接", text: $linkText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
            }
            .navigationTitle("发布资讯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSubmitting ? "发布中..." : "发布") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
            && !isUploadingCover
    }

    @MainActor
    private func submit() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedSummary.isEmpty, !trimmedSource.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            var finalCoverURL = coverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let uploaded = try await webService.uploadEventImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "news-cover-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalCoverURL = uploaded.url
            }

            try await onSubmit(
                DiscoverNewsDraft(
                    category: category,
                    source: trimmedSource,
                    title: trimmedTitle,
                    summary: trimmedSummary,
                    body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    link: linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkText.trimmingCharacters(in: .whitespacesAndNewlines),
                    coverImageURL: finalCoverURL.isEmpty ? nil : finalCoverURL
                )
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            selectedCoverData = nil
            return
        }
        do {
            selectedCoverData = try await item.loadTransferable(type: Data.self)
        } catch {
            selectedCoverData = nil
            errorMessage = "读取图片失败，请重试"
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
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
                || (item.aliases?.contains(where: { $0.lowercased().contains(keyword) }) ?? false)
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

struct DJDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    private let service = AppEnvironment.makeWebService()

    let djID: String

    @State private var dj: WebDJ?
    @State private var sets: [WebDJSet] = []
    @State private var djEvents: [WebEvent] = []
    @State private var watchedSetCount = 0
    @State private var isLoading = false
    @State private var showDJCheckinSheet = false
    @State private var selectedEventIDForDetail: String?
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
                            if let aliases = dj.aliases?.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                               !aliases.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(aliases, id: \.self) { alias in
                                            Text(alias)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color(red: 0.25, green: 0.54, blue: 0.96))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(Color(red: 0.25, green: 0.54, blue: 0.96).opacity(0.14))
                                                )
                                        }
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                Button((dj.isFollowing ?? false) ? "已关注" : "关注") {
                                    Task { await toggleFollow(dj) }
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    showDJCheckinSheet = true
                                } label: {
                                    Label("DJ 打卡", systemImage: "checkmark.seal")
                                }
                                .buttonStyle(.bordered)
                            }

                            HStack(spacing: 14) {
                                infoPill(icon: "person.2", text: "\(dj.followerCount ?? 0) 粉丝")
                                infoPill(icon: "headphones", text: "已看 \(watchedSetCount) 场")
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

                            Text("历史活动")
                                .font(.title3.bold())
                                .padding(.top, 4)

                            if djEvents.isEmpty {
                                Text("暂无历史活动")
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .padding(.vertical, 6)
                            } else {
                                ForEach(djEvents) { event in
                                    Button {
                                        selectedEventIDForDetail = event.id
                                    } label: {
                                        historyEventRow(event)
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
                .sheet(isPresented: $showDJCheckinSheet) {
                    DJCheckinBindingSheet(djName: dj.name) { submission in
                        Task { await checkin(using: submission) }
                    }
                    .presentationDetents([.fraction(0.66), .large])
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
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedEventIDForDetail != nil },
                set: { if !$0 { selectedEventIDForDetail = nil } }
            )
        ) {
            if let eventID = selectedEventIDForDetail {
                NavigationStack {
                    EventDetailView(eventID: eventID)
                }
            }
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
            async let eventsTask = service.fetchDJEvents(djID: djID)
            async let watchedCountTask = service.fetchMyDJCheckinCount(djID: djID)
            dj = try await djTask
            sets = try await setsTask
            djEvents = (try? await eventsTask) ?? []
            watchedSetCount = (try? await watchedCountTask) ?? 0
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

    private func checkin(using submission: DJCheckinSubmission) async {
        do {
            switch submission {
            case .eventBinding(let eventID, let attendedAt):
                _ = try await service.createCheckin(
                    input: CreateCheckinInput(
                        type: "dj",
                        eventId: eventID,
                        djId: djID,
                        note: nil,
                        rating: nil,
                        attendedAt: attendedAt
                    )
                )
            case .manual(let eventName, let attendedAt):
                _ = try await service.createCheckin(
                    input: CreateCheckinInput(
                        type: "dj",
                        eventId: nil,
                        djId: djID,
                        note: "manual_event:\(eventName)",
                        rating: nil,
                        attendedAt: attendedAt
                    )
                )
            }
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
        //.padding(.top, max(topSafeAreaInset() - 6, 0))
        .padding(.top, 0)
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

    private func historyEventRow(_ event: WebEvent) -> some View {
        let locationText = [event.city, event.country, event.venueName]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 4) {
            Text(event.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(2)

            Text(djHistoryEventDateText(event))
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)

            Text(locationText.isEmpty ? "地点待补充" : locationText)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    private func djHistoryEventDateText(_ event: WebEvent) -> String {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: event.startDate)
        let endDay = calendar.startOfDay(for: event.endDate)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        if startDay == endDay {
            return formatter.string(from: event.startDate)
        }
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
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
            
            // 1. 用底板作为主布局，严格锁定 16:9 的比例
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(RaverTheme.card)
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                // 2. 将异步加载的图片逻辑全部放入 overlay 中
                .overlay {
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
                // 3. 裁剪掉 overlay 中超出 16:9 底板的视觉部分
                .clipped()

            Text(set.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

            HStack(spacing: 6) {
                // ... 你原来的头像和 DJ 名称代码保持不变即可 ...
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
    @State private var wheelManualShift = 0
    @State private var wheelLastHapticShift = 0
    @State private var wheelAutoRecenterTask: Task<Void, Never>?
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
                    TracklistEditorView(
                        set: set,
                        currentTracklist: currentTracklistInfo,
                        selectedTracklistID: selectedTracklistID
                    ) {
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
                    wheelAutoRecenterTask?.cancel()
                    wheelAutoRecenterTask = nil
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
        let clampedShift = CGFloat(currentWheelShift(activeIndex: activeIndex, trackCount: tracks.count))

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
        .onTapGesture {
            handleWheelTap(tracks: tracks, activeIndex: activeIndex, in: set)
        }
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
            wheelManualShift = 0
            wheelLastHapticShift = 0
            wheelAutoRecenterTask?.cancel()
            wheelAutoRecenterTask = nil
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
        wheelAutoRecenterTask?.cancel()
        wheelAutoRecenterTask = nil
        wheelDragTranslation = value.translation.height
        let shift = currentWheelShift(activeIndex: activeIndex, trackCount: tracks.count)

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
        in _: WebDJSet
    ) {
        guard tracks.count > 1 else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                wheelDragTranslation = 0
            }
            wheelLastHapticShift = 0
            return
        }

        let predictedRawShift = wheelManualShift + Int((-value.predictedEndTranslation.height / wheelStepHeight).rounded())
        let shift = clampedWheelShift(rawShift: predictedRawShift, activeIndex: activeIndex, trackCount: tracks.count)
        wheelManualShift = shift

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            wheelDragTranslation = 0
        }
        wheelLastHapticShift = 0
        scheduleWheelAutoRecenter(activeIndex: activeIndex, trackCount: tracks.count)
    }

    private func handleWheelTap(
        tracks: [WebDJSetTrack],
        activeIndex: Int,
        in set: WebDJSet
    ) {
        guard !tracks.isEmpty else { return }
        let shift = currentWheelShift(activeIndex: activeIndex, trackCount: tracks.count)
        let targetIndex = activeIndex + shift
        guard tracks.indices.contains(targetIndex) else { return }
        let targetTrack = tracks[targetIndex]
        guard shift != 0 || targetTrack.id != activeTrackID else { return }

        wheelAutoRecenterTask?.cancel()
        wheelAutoRecenterTask = nil
        seekToTrack(targetTrack, in: set)
        wheelManualShift = 0
        wheelLastHapticShift = 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            wheelDragTranslation = 0
        }
    }

    private func currentWheelShift(activeIndex: Int, trackCount: Int) -> Int {
        let rawShift = wheelManualShift + Int((-wheelDragTranslation / wheelStepHeight).rounded())
        return clampedWheelShift(rawShift: rawShift, activeIndex: activeIndex, trackCount: trackCount)
    }

    private func scheduleWheelAutoRecenter(activeIndex: Int, trackCount: Int) {
        wheelAutoRecenterTask?.cancel()
        wheelAutoRecenterTask = nil

        let shift = currentWheelShift(activeIndex: activeIndex, trackCount: trackCount)
        guard shift != 0 else { return }

        wheelAutoRecenterTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    wheelManualShift = 0
                    wheelDragTranslation = 0
                }
                wheelLastHapticShift = 0
            }
        }
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
            isPlaybackPaused = false
            isTracklistHidden = false
            wheelManualShift = 0
            wheelDragTranslation = 0
            wheelLastHapticShift = 0
            wheelAutoRecenterTask?.cancel()
            wheelAutoRecenterTask = nil
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
            wheelManualShift = 0
            wheelDragTranslation = 0
            wheelLastHapticShift = 0
            wheelAutoRecenterTask?.cancel()
            wheelAutoRecenterTask = nil
            syncActiveTrack(for: set, at: playbackTime)
            return
        }

        guard let targetID = tracklistID else { return }
        do {
            let detail = try await service.fetchTracklistDetail(setID: set.id, tracklistID: targetID)
            currentTracklistInfo = detail
            selectedTracklistID = targetID
            currentTracks = detail.tracks
            wheelManualShift = 0
            wheelDragTranslation = 0
            wheelLastHapticShift = 0
            wheelAutoRecenterTask?.cancel()
            wheelAutoRecenterTask = nil
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
                Spacer(minLength: 8)

                if hasSourceLinks(track) {
                    sourceLinksRow(for: track)
                        .frame(width: 52, alignment: .trailing)
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
                            webUserAvatar(comment.user, size: 28)
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
                contributorAvatar(contributor, size: 26)

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

    @ViewBuilder
    private func webUserAvatar(_ user: WebUserLite, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarUrl),
           let remoteURL = URL(string: resolved),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    Circle().fill(RaverTheme.card)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    webUserAvatarFallback(user, size: size)
                @unknown default:
                    webUserAvatarFallback(user, size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            webUserAvatarFallback(user, size: size)
        }
    }

    private func webUserAvatarFallback(_ user: WebUserLite, size: CGFloat) -> some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: user.avatarUrl
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }

    @ViewBuilder
    private func contributorAvatar(_ user: WebContributorProfile, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarUrl),
           let remoteURL = URL(string: resolved),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    Circle().fill(RaverTheme.card)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    contributorAvatarFallback(user, size: size)
                @unknown default:
                    contributorAvatarFallback(user, size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            contributorAvatarFallback(user, size: size)
        }
    }

    private func contributorAvatarFallback(_ user: WebContributorProfile, size: CGFloat) -> some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: user.avatarUrl
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .background(RaverTheme.card)
        .clipShape(Circle())
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
                    ContributorAvatar(
                        avatarURL: (set.tracklistContributor ?? set.videoContributor)?.avatarUrl,
                        fallback: (set.tracklistContributor ?? set.videoContributor)?.shownName ?? "官方"
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
    private enum ParseMode {
        case replace
        case append
    }

    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let set: WebDJSet
    let onUploaded: (WebTracklistDetail) -> Void

    @State private var title = ""
    @State private var bulkText = ""
    @State private var rows: [TrackDraftRow] = []
    @State private var infoText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("当前 Set 信息") {
                LabeledContent("Set 标题", value: set.title)
                LabeledContent("Set ID", value: set.id)
                LabeledContent("当前默认歌曲数", value: "\(set.trackCount)")
            }

            Section("Tracklist 标题") {
                TextField("例如：我的版本", text: $title)
            }

            Section("批量粘贴") {
                Text("每行格式：`0:00~3:30 - 艺术家 - 歌曲名 | Spotify链接(可选) | 网易云链接(可选)`")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                TextEditor(text: $bulkText)
                    .frame(minHeight: 200)
                    .font(.system(.footnote, design: .monospaced))
                HStack {
                    Button("解析并替换") {
                        parseBulkTracklist(.replace)
                    }
                    .buttonStyle(.bordered)

                    Button("解析并追加") {
                        parseBulkTracklist(.append)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("从可视化生成文本") {
                        bulkText = TracklistDraftCodec.makeBulkText(from: rows)
                        infoText = "已用当前可视化内容刷新文本"
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }

            Section("可视化编辑（\(rows.count)）") {
                if rows.isEmpty {
                    Text("先粘贴文本并解析，或手动新增 Track。")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach($rows) { $row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(row.position)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Spacer()
                                Text(row.status.uppercased())
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }

                            TextField("歌曲名", text: $row.title)
                            TextField("歌手", text: $row.artist)
                            HStack {
                                TextField("开始时间（如 0:00）", text: $row.startText)
                                TextField("结束时间（可选）", text: $row.endText)
                            }
                            TextField("Spotify 链接（可选）", text: $row.spotifyUrl)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("网易云链接（可选）", text: $row.neteaseUrl)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.vertical, 4)
                    }

                    .onDelete { indexSet in
                        rows.remove(atOffsets: indexSet)
                        rows = TracklistDraftCodec.reindex(rows)
                    }
                }

                Button {
                    rows.append(
                        TrackDraftRow(
                            position: rows.count + 1,
                            title: "",
                            artist: "",
                            startText: "0:00",
                            endText: "",
                            status: "released",
                            spotifyUrl: "",
                            neteaseUrl: ""
                        )
                    )
                } label: {
                    Label("新增 Track", systemImage: "plus")
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
                .disabled(isSaving || rows.isEmpty)
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

    private func parseBulkTracklist(_ mode: ParseMode) {
        let parsedRows = TracklistDraftCodec.parseBulkRows(from: bulkText)
        guard !parsedRows.isEmpty else {
            infoText = "请先粘贴歌单文本"
            return
        }

        switch mode {
        case .replace:
            rows = TracklistDraftCodec.reindex(parsedRows)
            infoText = "解析成功并替换：\(rows.count) 首"
        case .append:
            let merged = rows + parsedRows
            rows = TracklistDraftCodec.reindex(merged)
            infoText = "解析成功并追加：共 \(rows.count) 首"
        }
    }

    private func upload() async {
        let tracks = TracklistDraftCodec.buildCreateTracks(from: rows)
        guard !tracks.isEmpty else {
            errorMessage = "至少保留 1 首有效歌曲（需有歌曲名、歌手、开始时间）"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let uploaded = try await service.createTracklist(
                setID: set.id,
                input: CreateTracklistInput(title: title.nilIfEmpty, tracks: tracks)
            )
            onUploaded(uploaded)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
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
    private enum ParseMode {
        case replace
        case append
    }

    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let set: WebDJSet
    let currentTracklist: WebTracklistDetail?
    let selectedTracklistID: String?
    let onSaved: () -> Void

    @State private var rows: [TrackDraftRow] = []
    @State private var bulkText = ""
    @State private var bulkParseMessage = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("当前 Tracklist 信息") {
                    LabeledContent("名称", value: resolvedTracklistTitle)
                    LabeledContent("Tracklist ID", value: selectedTracklistID ?? "default")
                    LabeledContent("歌曲数量", value: "\(rows.count)")
                    LabeledContent("贡献者", value: resolvedTracklistContributor)
                }

                Section("当前歌单文本（已填充）") {
                    Text("每行格式：`0:00~3:30 - 艺术家 - 歌曲名 | Spotify链接(可选) | 网易云链接(可选)`")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextEditor(text: $bulkText)
                        .frame(minHeight: 200)
                        .font(.system(.footnote, design: .monospaced))

                    HStack {
                        Button("解析并替换") {
                            parseBulkTracklist(.replace)
                        }
                        .buttonStyle(.bordered)

                        Button("解析并追加") {
                            parseBulkTracklist(.append)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("从可视化生成文本") {
                            bulkText = TracklistDraftCodec.makeBulkText(from: rows)
                            bulkParseMessage = "已用当前可视化内容刷新文本"
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    }
                }

                if !bulkParseMessage.isEmpty {
                    Section {
                        Text(bulkParseMessage)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                Section("可视化编辑（\(rows.count)）") {
                    ForEach($rows) { $row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(row.position)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Spacer()
                                Text(row.status.uppercased())
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            TextField("歌曲名", text: $row.title)
                            TextField("歌手", text: $row.artist)
                            HStack {
                                TextField("开始时间（如 0:00）", text: $row.startText)
                                TextField("结束时间（可选）", text: $row.endText)
                            }
                            TextField("Spotify 链接（可选）", text: $row.spotifyUrl)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("网易云链接（可选）", text: $row.neteaseUrl)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        rows.remove(atOffsets: indexSet)
                        rows = TracklistDraftCodec.reindex(rows)
                    }

                    Button {
                        rows.append(
                            TrackDraftRow(
                                position: rows.count + 1,
                                title: "",
                                artist: "",
                                startText: "0:00",
                                endText: "",
                                status: "released",
                                spotifyUrl: "",
                                neteaseUrl: ""
                            )
                        )
                    } label: {
                        Label("新增 Track", systemImage: "plus")
                    }
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
                    .disabled(isSaving || rows.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("自动链接") {
                        Task { await autoLink() }
                    }
                }
            }
            .onAppear {
                initializeRowsIfNeeded()
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

    private var resolvedTracklistTitle: String {
        if let title = currentTracklist?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if selectedTracklistID == nil {
            return "默认 Tracklist"
        }
        return "用户版本 Tracklist"
    }

    private var resolvedTracklistContributor: String {
        if let contributor = currentTracklist?.contributor?.shownName, !contributor.isEmpty {
            return contributor
        }
        if let contributor = set.tracklistContributor?.shownName, !contributor.isEmpty {
            return contributor
        }
        return "官方"
    }

    private func initializeRowsIfNeeded() {
        guard rows.isEmpty else { return }
        let sourceTracks = currentTracklist?.tracks ?? set.tracks
        rows = sourceTracks.enumerated().map { index, track in
            TrackDraftRow(
                position: track.position > 0 ? track.position : index + 1,
                title: track.title,
                artist: track.artist,
                startText: TracklistDraftCodec.formatTime(max(0, track.startTime)),
                endText: track.endTime.map { TracklistDraftCodec.formatTime(max(0, $0)) } ?? "",
                status: track.status,
                spotifyUrl: track.spotifyUrl ?? "",
                neteaseUrl: track.neteaseUrl ?? ""
            )
        }
        if rows.isEmpty {
            rows = [
                TrackDraftRow(
                    position: 1,
                    title: "",
                    artist: "",
                    startText: "0:00",
                    endText: "",
                    status: "released",
                    spotifyUrl: "",
                    neteaseUrl: ""
                )
            ]
        }
        rows = TracklistDraftCodec.reindex(rows)
        bulkText = TracklistDraftCodec.makeBulkText(from: rows)
    }

    private func parseBulkTracklist(_ mode: ParseMode) {
        let parsedRows = TracklistDraftCodec.parseBulkRows(from: bulkText)
        guard !parsedRows.isEmpty else {
            bulkParseMessage = "未识别可用行，请检查格式后重试"
            return
        }
        switch mode {
        case .replace:
            rows = TracklistDraftCodec.reindex(parsedRows)
            bulkParseMessage = "解析成功并替换：\(rows.count) 首"
        case .append:
            rows = TracklistDraftCodec.reindex(rows + parsedRows)
            bulkParseMessage = "解析成功并追加：共 \(rows.count) 首"
        }
    }

    private func save() async {
        let tracks = TracklistDraftCodec.buildCreateTracks(from: rows)

        guard !tracks.isEmpty else {
            errorMessage = "至少保留 1 条有效 Track（需有歌曲名、歌手、开始时间）"
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

private struct TrackDraftRow: Identifiable {
    let id = UUID()
    var position: Int
    var title: String
    var artist: String
    var startText: String
    var endText: String
    var status: String
    var spotifyUrl: String
    var neteaseUrl: String
}

private enum TracklistDraftCodec {
    private struct ParsedTrackLine {
        var startSeconds: Int
        var endSeconds: Int?
        var title: String
        var artist: String
        var status: String
        var spotifyUrl: String?
        var neteaseUrl: String?
    }

    static func parseBulkRows(from bulkText: String) -> [TrackDraftRow] {
        let lines = bulkText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let parsed = lines
            .compactMap(parseLine)
            .sorted(by: { $0.startSeconds < $1.startSeconds })

        guard !parsed.isEmpty else { return [] }

        let rows = parsed.enumerated().map { index, item in
            let fallbackEnd = index + 1 < parsed.count ? parsed[index + 1].startSeconds : nil
            let effectiveEnd = item.endSeconds ?? fallbackEnd
            return TrackDraftRow(
                position: index + 1,
                title: item.title,
                artist: item.artist,
                startText: formatTime(item.startSeconds),
                endText: effectiveEnd.map(formatTime) ?? "",
                status: normalizedStatus(item.status),
                spotifyUrl: item.spotifyUrl ?? "",
                neteaseUrl: item.neteaseUrl ?? ""
            )
        }
        return reindex(rows)
    }

    static func buildCreateTracks(from rows: [TrackDraftRow]) -> [CreateTrackInput] {
        struct ValidTrack {
            var title: String
            var artist: String
            var startTime: Int
            var endTime: Int?
            var status: String
            var spotifyUrl: String?
            var neteaseUrl: String?
        }

        let validRows: [ValidTrack] = rows.compactMap { row in
            let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = row.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !artist.isEmpty else { return nil }
            guard let start = parseTime(row.startText) else { return nil }
            return ValidTrack(
                title: title,
                artist: artist,
                startTime: max(0, start),
                endTime: parseTime(row.endText),
                status: normalizedStatus(row.status),
                spotifyUrl: normalizeURL(row.spotifyUrl),
                neteaseUrl: normalizeURL(row.neteaseUrl)
            )
        }

        guard !validRows.isEmpty else { return [] }

        return validRows.enumerated().map { index, row in
            let nextStart = index + 1 < validRows.count ? validRows[index + 1].startTime : nil
            let fallbackEnd = nextStart.flatMap { $0 > row.startTime ? $0 : nil }
            let finalEnd = row.endTime ?? fallbackEnd
            return CreateTrackInput(
                position: index + 1,
                startTime: row.startTime,
                endTime: finalEnd,
                title: row.title,
                artist: row.artist,
                status: row.status,
                spotifyUrl: row.spotifyUrl,
                neteaseUrl: row.neteaseUrl
            )
        }
    }

    static func reindex(_ rows: [TrackDraftRow]) -> [TrackDraftRow] {
        rows.enumerated().map { index, row in
            var next = row
            next.position = index + 1
            return next
        }
    }

    static func makeBulkText(from rows: [TrackDraftRow]) -> String {
        reindex(rows).map { row in
            let start = row.startText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0:00" : row.startText.trimmingCharacters(in: .whitespacesAndNewlines)
            let end = row.endText.trimmingCharacters(in: .whitespacesAndNewlines)
            let endPart = end.isEmpty ? "" : "~\(end)"
            let artist = row.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : row.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            var parts: [String] = ["\(start)\(endPart) - \(artist) - \(title)"]
            if let spotify = normalizeURL(row.spotifyUrl) {
                parts.append(spotify)
            }
            if let netease = normalizeURL(row.neteaseUrl) {
                parts.append(netease)
            }
            return parts.joined(separator: " | ")
        }
        .joined(separator: "\n")
    }

    static func parseTime(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed
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

    static func formatTime(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let h = safe / 3600
        let m = (safe % 3600) / 60
        let s = safe % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private static func parseLine(_ line: String) -> ParsedTrackLine? {
        let pattern = #"^(\d{1,2}:\d{2}(?::\d{2})?)(?:\s*~\s*(\d{1,2}:\d{2}(?::\d{2})?))?\s*[-–]\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let startRange = Range(match.range(at: 1), in: line),
              let bodyRange = Range(match.range(at: 3), in: line) else {
            return nil
        }

        guard let startSeconds = parseTime(String(line[startRange])) else { return nil }
        let endRaw = Range(match.range(at: 2), in: line).map { String(line[$0]) }
        let endSeconds = endRaw.flatMap(parseTime)

        let body = String(line[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = body
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let mainRaw = segments.first else { return nil }

        let urlsInMain = extractURLs(from: mainRaw)
        var main = mainRaw
        for url in urlsInMain {
            main = main.replacingOccurrences(of: url, with: "")
        }
        main = main.trimmingCharacters(in: .whitespacesAndNewlines)

        let splitToken = " - "
        let splitIndex = main.range(of: splitToken)
        let rawArtist = splitIndex.map { String(main[..<$0.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? "Unknown"
        let rawTitle = splitIndex.map { String(main[$0.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? main
        guard !rawTitle.isEmpty else { return nil }

        let links = detectLinks(in: Array(segments.dropFirst()), fallbackSource: body)
        return ParsedTrackLine(
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            title: rawTitle,
            artist: rawArtist.isEmpty ? "Unknown" : rawArtist,
            status: inferStatus(main),
            spotifyUrl: links.spotify,
            neteaseUrl: links.netease
        )
    }

    private static func detectLinks(in segments: [String], fallbackSource: String) -> (spotify: String?, netease: String?) {
        var spotify: String?
        var netease: String?

        func apply(_ candidate: String) {
            let classified = classifyURL(candidate)
            if spotify == nil, let value = classified.spotify {
                spotify = value
            }
            if netease == nil, let value = classified.netease {
                netease = value
            }
        }

        for segment in segments {
            apply(segment)
        }

        for url in extractURLs(from: fallbackSource) {
            apply(url)
        }

        return (spotify, netease)
    }

    private static func classifyURL(_ raw: String) -> (spotify: String?, netease: String?) {
        let lower = raw.lowercased()
        var candidate = raw
        if lower.hasPrefix("spotify:") || lower.hasPrefix("netease:") || lower.hasPrefix("music163:") {
            if let idx = raw.firstIndex(of: ":") {
                candidate = String(raw[raw.index(after: idx)...])
            }
        } else if lower.hasPrefix("spotify=") || lower.hasPrefix("netease=") || lower.hasPrefix("music163=") {
            if let idx = raw.firstIndex(of: "=") {
                candidate = String(raw[raw.index(after: idx)...])
            }
        }

        guard let normalized = normalizeURL(candidate) else { return (nil, nil) }
        let normalizedLower = normalized.lowercased()
        if normalizedLower.contains("spotify.com") || normalizedLower.contains("spotify.link") {
            return (normalized, nil)
        }
        if normalizedLower.contains("music.163.com") || normalizedLower.contains("163cn.tv") || normalizedLower.contains("netease") {
            return (nil, normalized)
        }
        return (nil, nil)
    }

    private static func extractURLs(from text: String) -> [String] {
        let pattern = #"https?://[^\s|]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsrange).compactMap {
            guard let range = Range($0.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func normalizeURL(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"'(),;"))
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return trimmed
        }
        if trimmed.contains("open.spotify.com") || trimmed.contains("spotify.link")
            || trimmed.contains("music.163.com") || trimmed.contains("163cn.tv") {
            return "https://\(trimmed)"
        }
        return trimmed
    }

    private static func normalizedStatus(_ raw: String) -> String {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["released", "id", "remix", "edit"].contains(lowered) {
            return lowered
        }
        return "released"
    }

    private static func inferStatus(_ text: String) -> String {
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
}

struct LearnModuleView: View {
    private let service = AppEnvironment.makeWebService()

    @State private var genres: [LearnGenreNode] = []
    @State private var allLabels: [LearnLabel] = []
    @State private var labels: [LearnLabel] = []
    @State private var labelsPagination: BFFPagination?
    @State private var selectedSection: LearnModuleSection = .genres
    @State private var selectedSort: LearnLabelSortOption = .soundcloudFollowers
    @State private var sortOrder: LearnLabelSortOrder = .desc
    @State private var searchText = ""
    @State private var committedSearch = ""
    @State private var selectedGenreFilters: Set<String> = []
    @State private var selectedNationFilters: Set<String> = []
    @State private var activeFilterPanel: LearnLabelFilterPanelType?
    @State private var searchTask: Task<Void, Never>?
    @State private var isLoadingGenres = false
    @State private var isLoadingLabels = false
    @State private var selectedLabelForDetail: LearnLabel?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerTabs
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if selectedSection == .labels {
                    labelsToolbar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }

                Group {
                    if selectedSection == .genres {
                        genresContent
                    } else {
                        labelsContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadInitial()
            }
            .refreshable {
                await refreshAll()
            }
            .onChange(of: selectedSort) { _, next in
                sortOrder = next.defaultOrder
                Task { await loadLabels() }
            }
            .onChange(of: sortOrder) { _, _ in
                Task { await loadLabels() }
            }
            .onChange(of: committedSearch) { _, _ in
                Task { await loadLabels() }
            }
            .onChange(of: selectedGenreFilters) { _, _ in
                applyLabelFilters()
            }
            .onChange(of: selectedNationFilters) { _, _ in
                applyLabelFilters()
            }
            .onChange(of: searchText) { _, next in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    await MainActor.run {
                        committedSearch = next.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            .onDisappear {
                searchTask?.cancel()
            }
            .fullScreenCover(item: $selectedLabelForDetail) { label in
                NavigationStack {
                    LearnLabelDetailView(label: label)
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

    @ViewBuilder
    private var headerTabs: some View {
        HStack(spacing: 8) {
            ForEach(LearnModuleSection.allCases) { item in
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
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var labelsToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField("搜索厂牌名 / 简介", text: $searchText)
                        .font(.subheadline)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Menu {
                    ForEach(LearnLabelSortOption.allCases) { option in
                        Button {
                            selectedSort = option
                        } label: {
                            if option == selectedSort {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedSort.title)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button {
                    sortOrder = sortOrder == .desc ? .asc : .desc
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sortOrder == .desc ? "arrow.down" : "arrow.up")
                        Text(sortOrder == .desc ? "降序" : "升序")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        activeFilterPanel = activeFilterPanel == .genres ? nil : .genres
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: activeFilterPanel == .genres ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        Text(selectedGenreFilters.isEmpty ? "筛选风格" : "风格 \(selectedGenreFilters.count)")
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        activeFilterPanel = activeFilterPanel == .nations ? nil : .nations
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: activeFilterPanel == .nations ? "flag.fill" : "flag")
                        Text(selectedNationFilters.isEmpty ? "筛选国家" : "国家 \(selectedNationFilters.count)")
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                if !selectedGenreFilters.isEmpty || !selectedNationFilters.isEmpty {
                    Button("清空全部") {
                        selectedGenreFilters.removeAll()
                        selectedNationFilters.removeAll()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                }

                Spacer(minLength: 0)
            }

            if activeFilterPanel == .genres {
                LearnLabelMultiSelectPanel(
                    title: "筛选风格",
                    options: availableGenreFilters,
                    selectedValues: selectedGenreFilters,
                    emptyText: "暂无可筛选风格",
                    onToggle: toggleGenreFilter,
                    onClear: {
                        selectedGenreFilters.removeAll()
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = nil
                        }
                    }
                )
            } else if activeFilterPanel == .nations {
                LearnLabelMultiSelectPanel(
                    title: "筛选国家",
                    options: availableNationFilters,
                    selectedValues: selectedNationFilters,
                    emptyText: "暂无可筛选国家",
                    onToggle: toggleNationFilter,
                    onClear: {
                        selectedNationFilters.removeAll()
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = nil
                        }
                    }
                )
            }

            if let total = labelsPagination?.total {
                Text("筛选后 \(labels.count) / 共 \(total) 个厂牌")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var genresContent: some View {
        if isLoadingGenres && genres.isEmpty {
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

    @ViewBuilder
    private var labelsContent: some View {
        if isLoadingLabels && labels.isEmpty {
            ProgressView("厂牌加载中...")
        } else if labels.isEmpty {
            ContentUnavailableView("暂无厂牌", systemImage: "building.2")
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(labels) { label in
                        LearnLabelCard(label: label)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture {
                                selectedLabelForDetail = label
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    if activeFilterPanel != nil {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = nil
                        }
                    }
                }
            )
        }
    }

    private func loadInitial() async {
        async let genresTask: Void = loadGenres()
        async let labelsTask: Void = loadLabels()
        _ = await (genresTask, labelsTask)
    }

    private func refreshAll() async {
        async let genresTask: Void = loadGenres()
        async let labelsTask: Void = loadLabels()
        _ = await (genresTask, labelsTask)
    }

    private func loadGenres() async {
        isLoadingGenres = true
        defer { isLoadingGenres = false }
        do {
            genres = try await service.fetchLearnGenres()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadLabels() async {
        isLoadingLabels = true
        defer { isLoadingLabels = false }

        do {
            let page = try await service.fetchLearnLabels(
                page: 1,
                limit: 500,
                sortBy: selectedSort.apiValue,
                order: sortOrder.rawValue,
                search: committedSearch,
                nation: nil,
                genre: nil
            )
            allLabels = page.items
            applyLabelFilters()
            labelsPagination = page.pagination
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var availableGenreFilters: [String] {
        let genres = allLabels.flatMap { labelGenres(for: $0) }
        return Array(Set(genres)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var availableNationFilters: [String] {
        let nations = allLabels.compactMap { label -> String? in
            let trimmed = label.nation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        return Array(Set(nations)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func applyLabelFilters() {
        let normalizedGenreFilters = Set(selectedGenreFilters.map(normalizeFilterToken))
        let normalizedNationFilters = Set(selectedNationFilters.map(normalizeFilterToken))

        labels = allLabels.filter { label in
            let nationPass: Bool = {
                guard !normalizedNationFilters.isEmpty else { return true }
                let nation = normalizeFilterToken(label.nation ?? "")
                return normalizedNationFilters.contains(nation)
            }()

            guard nationPass else { return false }

            guard !normalizedGenreFilters.isEmpty else { return true }
            let genrePool = Set(labelGenres(for: label).map(normalizeFilterToken))
            return normalizedGenreFilters.allSatisfy { genrePool.contains($0) }
        }
    }

    private func labelGenres(for label: LearnLabel) -> [String] {
        if !label.genres.isEmpty {
            return label.genres.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return (label.genresPreview ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func toggleGenreFilter(_ genre: String) {
        if selectedGenreFilters.contains(genre) {
            selectedGenreFilters.remove(genre)
        } else {
            selectedGenreFilters.insert(genre)
        }
    }

    private func toggleNationFilter(_ nation: String) {
        if selectedNationFilters.contains(nation) {
            selectedNationFilters.remove(nation)
        } else {
            selectedNationFilters.insert(nation)
        }
    }

    private func normalizeFilterToken(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

private enum LearnModuleSection: String, CaseIterable, Identifiable {
    case genres
    case labels

    var id: String { rawValue }

    var title: String {
        switch self {
        case .genres: return "流派树"
        case .labels: return "厂牌"
        }
    }
}

private enum LearnLabelFilterPanelType {
    case genres
    case nations
}

private struct LearnLabelMultiSelectPanel: View {
    let title: String
    let options: [String]
    let selectedValues: Set<String>
    let emptyText: String
    let onToggle: (String) -> Void
    let onClear: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer(minLength: 0)
                if !selectedValues.isEmpty {
                    Button("清空") {
                        onClear()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                }
                Button("完成") {
                    onClose()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            }

            if options.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(options, id: \.self) { item in
                            Button {
                                onToggle(item)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedValues.contains(item) ? "checkmark.square.fill" : "square")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedValues.contains(item) ? RaverTheme.accent : RaverTheme.secondaryText)
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(RaverTheme.background.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum LearnLabelSortOrder: String {
    case asc
    case desc
}

private enum LearnLabelSortOption: String, CaseIterable, Identifiable {
    case soundcloudFollowers
    case likes
    case name
    case nation
    case latestRelease
    case createdAt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soundcloudFollowers: return "热度"
        case .likes: return "Likes"
        case .name: return "名称"
        case .nation: return "国家"
        case .latestRelease: return "发布时间文本"
        case .createdAt: return "入库时间"
        }
    }

    var defaultOrder: LearnLabelSortOrder {
        switch self {
        case .name, .nation, .latestRelease:
            return .asc
        case .soundcloudFollowers, .likes, .createdAt:
            return .desc
        }
    }

    var apiValue: String {
        rawValue
    }
}

private struct LearnLabelCard: View {
    let label: LearnLabel
    @State private var avatarLuminance: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    bannerView
                        .allowsHitTesting(false)
                }
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 66)
                        .overlay {
                            avatarView
                                .allowsHitTesting(false)
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(LearnLabelAvatarStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                        )
                        .offset(y: -22)
                        .padding(.bottom, -22)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(label.name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(2)

                        Text(metaLine)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }

                if !displayGenres.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(displayGenres, id: \.self) { genre in
                                Text(genre)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(RaverTheme.background)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let intro = introLine {
                    Text(intro)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: label.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let url = destinationURL(label.backgroundUrl) {
            fallbackBanner
                .overlay {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.clear
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Color.clear
                        @unknown default:
                            Color.clear
                        }
                    }
                }
        } else {
            fallbackBanner
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = destinationURL(label.avatarUrl) {
            fallbackAvatar
                .overlay {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.clear
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Color.clear
                        @unknown default:
                            Color.clear
                        }
                    }
                }
        } else {
            fallbackAvatar
        }
    }

    private var fallbackBanner: some View {
        LinearGradient(
            colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackAvatar: some View {
        ZStack {
            fallbackBanner
            Text(String(label.name.prefix(2)).uppercased())
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var displayGenres: [String] {
        if !label.genres.isEmpty {
            return Array(label.genres.prefix(5))
        }
        let raw = label.genresPreview?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        return Array(raw.filter { !$0.isEmpty }.prefix(5))
    }

    private var introLine: String? {
        let trimmed = label.introduction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var metaLine: String {
        let nation = label.nation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nation.isEmpty ? "厂牌信息" : nation
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(label.avatarUrl) else {
            await MainActor.run {
                avatarLuminance = nil
            }
            return
        }
        let luminance = await LearnLabelAvatarStyling.luminance(for: avatarURL)
        await MainActor.run {
            avatarLuminance = luminance
        }
    }
}

private struct LearnLabelDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let label: LearnLabel

    @State private var previewImage: LearnLabelPreviewImage?
    @State private var avatarLuminance: CGFloat?
    @State private var selectedFounderDJ: LearnLabelFounderTarget?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Button {
                            openPreview(urlString: label.backgroundUrl, title: "\(label.name) 背景图")
                        } label: {
                            headerBanner
                        }
                        .buttonStyle(.plain)
                    }
                    .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        Button {
                            openPreview(urlString: label.avatarUrl, title: "\(label.name) 头像")
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: 98)
                                .overlay {
                                    headerAvatar
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(LearnLabelAvatarStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(y: -50)
                        .padding(.bottom, -50)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(label.name)
                                .font(.title3.weight(.black))
                                .foregroundStyle(RaverTheme.primaryText)
                            if let intro = label.introduction?.trimmingCharacters(in: .whitespacesAndNewlines), !intro.isEmpty {
                                LearnLabelExpandableText(text: intro, collapsedLineLimit: 4)
                            }
                        }
                    }

                    if !displayGenres.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Genres")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            WrapFlowLayout(items: displayGenres) { genre in
                                Text(genre)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(RaverTheme.background)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if hasFounderDisplay {
                            founderSection
                        }
                        LearnLabelInfoRow(title: "国家", value: label.nation)
                        LearnLabelInfoRow(title: "地区/时期", value: label.locationPeriod)
                        LearnLabelInfoRow(title: "联系邮箱", value: label.generalContactEmail)
                        LearnLabelInfoRow(title: "Demo 提交", value: label.demoSubmissionDisplay ?? label.demoSubmissionUrl)
                        if hasFoundedAtDisplay {
                            LearnLabelInfoRow(title: "创始时间", value: foundedAtDisplay)
                        }
                    }

                    linksSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(RaverTheme.background)
        .navigationTitle("厂牌详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") {
                    dismiss()
                }
                .foregroundStyle(RaverTheme.primaryText)
            }
        }
        .fullScreenCover(item: $previewImage) { item in
            LearnLabelImagePreviewView(item: item)
        }
        .fullScreenCover(item: $selectedFounderDJ) { dj in
            NavigationStack {
                DJDetailView(djID: dj.id)
            }
        }
        .task(id: label.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
    }

    @ViewBuilder
    private var headerBanner: some View {
        if let url = destinationURL(label.backgroundUrl) {
            fallbackBanner
                .overlay {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.clear
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Color.clear
                        @unknown default:
                            Color.clear
                        }
                    }
                }
                .overlay {
                    bannerEdgeGradient
                }
        } else {
            fallbackBanner
                .overlay {
                    bannerEdgeGradient
                }
        }
    }

    @ViewBuilder
    private var headerAvatar: some View {
        if let url = destinationURL(label.avatarUrl) {
            fallbackAvatar
                .overlay {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.clear
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Color.clear
                        @unknown default:
                            Color.clear
                        }
                    }
                }
        } else {
            fallbackAvatar
        }
    }

    private var fallbackBanner: some View {
        LinearGradient(
            colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackAvatar: some View {
        ZStack {
            fallbackBanner
            Text(String(label.name.prefix(2)).uppercased())
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var displayGenres: [String] {
        if !label.genres.isEmpty {
            return label.genres
        }
        return label.genresPreview?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    @ViewBuilder
    private var founderSection: some View {
        HStack(alignment: .center, spacing: 10) {
            if let founderDj = label.founderDj {
                Button {
                    selectedFounderDJ = LearnLabelFounderTarget(id: founderDj.id)
                } label: {
                    HStack(spacing: 10) {
                        LearnLabelFounderAvatar(urlString: founderDj.avatarUrl)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("创始人")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(founderDisplayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    LearnLabelFounderAvatar(urlString: nil)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("创始人")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(founderDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var founderDisplayName: String {
        if let founderDj = label.founderDj {
            return founderDj.name
        }
        return (label.founderName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    private var foundedAtDisplay: String {
        label.foundedAt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasFounderDisplay: Bool {
        if label.founderDj != nil { return true }
        return !founderDisplayName.isEmpty
    }

    private var hasFoundedAtDisplay: Bool {
        !foundedAtDisplay.isEmpty
    }

    @ViewBuilder
    private var linksSection: some View {
        let hasLinks = destinationURL(label.facebookUrl) != nil
            || destinationURL(label.soundcloudUrl) != nil
            || destinationURL(label.musicPurchaseUrl) != nil
            || destinationURL(label.officialWebsiteUrl) != nil
            || destinationURL(label.demoSubmissionUrl) != nil
        if hasLinks {
            VStack(alignment: .leading, spacing: 10) {
                Text("Links")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                if let url = destinationURL(label.facebookUrl) {
                    LearnLabelExternalLinkRow(icon: "person.2.fill", title: "Facebook", url: url)
                }
                if let url = destinationURL(label.soundcloudUrl) {
                    LearnLabelExternalLinkRow(icon: "waveform", title: "SoundCloud", url: url)
                }
                if let url = destinationURL(label.musicPurchaseUrl) {
                    LearnLabelExternalLinkRow(icon: "cart.fill", title: "音乐资产购买", url: url)
                }
                if let url = destinationURL(label.officialWebsiteUrl) {
                    LearnLabelExternalLinkRow(icon: "globe", title: "官网", url: url)
                }
                if let url = destinationURL(label.demoSubmissionUrl) {
                    LearnLabelExternalLinkRow(icon: "paperplane.fill", title: "Demo 提交", url: url)
                }
            }
        }
    }

    private var bannerEdgeGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.76), location: 0),
                .init(color: Color.clear, location: 0.28),
                .init(color: Color.clear, location: 0.66),
                .init(color: Color.black.opacity(0.82), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(label.avatarUrl) else {
            await MainActor.run {
                avatarLuminance = nil
            }
            return
        }
        let luminance = await LearnLabelAvatarStyling.luminance(for: avatarURL)
        await MainActor.run {
            avatarLuminance = luminance
        }
    }

    private func openPreview(urlString: String?, title: String) {
        guard let url = destinationURL(urlString) else { return }
        previewImage = LearnLabelPreviewImage(title: title, url: url)
    }
}

private struct LearnLabelExpandableText: View {
    let text: String
    let collapsedLineLimit: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)

            if shouldShowToggle {
                Button(isExpanded ? "收起" : "展开全文") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.accent)
            }
        }
    }

    private var shouldShowToggle: Bool {
        text.count > 80 || text.contains("\n")
    }
}

private struct LearnLabelFounderAvatar: View {
    let urlString: String?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(width: 42)
            .overlay {
                if let url = destinationURL(urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholder
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .clipped()
            .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.1)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }
}

private struct LearnLabelExternalLinkRow: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .frame(width: 16)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)

                Spacer(minLength: 8)

                Text(url.host ?? url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3)
        }
    }
}

private enum LearnLabelAvatarStyling {
    private static let ciContext = CIContext()
    private static let luminanceCache = NSCache<NSURL, NSNumber>()

    static func borderColor(for luminance: CGFloat?) -> Color {
        guard let luminance else {
            return Color.white.opacity(0.55)
        }
        if luminance >= 0.67 {
            return Color.black.opacity(0.78)
        }
        return Color.white.opacity(0.82)
    }

    static func luminance(for url: URL) async -> CGFloat? {
        if let cached = luminanceCache.object(forKey: url as NSURL) {
            return CGFloat(truncating: cached)
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            guard let image = UIImage(data: data), let luminance = averageLuminance(for: image) else {
                return nil
            }
            luminanceCache.setObject(NSNumber(value: Double(luminance)), forKey: url as NSURL)
            return luminance
        } catch {
            return nil
        }
    }

    private static func averageLuminance(for image: UIImage) -> CGFloat? {
        guard let cgImage = image.cgImage else { return nil }
        let inputImage = CIImage(cgImage: cgImage)
        guard !inputImage.extent.isEmpty else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = inputImage.extent
        guard let outputImage = filter.outputImage else { return nil }

        var rgba = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &rgba,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let red = CGFloat(rgba[0]) / 255.0
        let green = CGFloat(rgba[1]) / 255.0
        let blue = CGFloat(rgba[2]) / 255.0
        return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }
}

private struct LearnLabelInfoRow: View {
    let title: String
    let value: String?

    var body: some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(width: 78, alignment: .leading)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct LearnLabelPreviewImage: Identifiable {
    let id = UUID().uuidString
    let title: String
    let url: URL
}

private struct LearnLabelFounderTarget: Identifiable {
    let id: String
}

private struct LearnLabelImagePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let item: LearnLabelPreviewImage

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: item.url) { phase in
                switch phase {
                case .empty:
                    ProgressView("加载中...")
                        .tint(.white)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    Text("图片加载失败")
                        .foregroundStyle(Color.white.opacity(0.85))
                @unknown default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 44)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .overlay(alignment: .topLeading) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.top, 18)
                .padding(.leading, 16)
        }
    }
}

private struct WrapFlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        let rows = buildRows()
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func buildRows() -> [[Item]] {
        // Keep a deterministic, lightweight wrap in the absence of runtime width measurement.
        // This is good enough for short tag strings and keeps implementation simple.
        var rows: [[Item]] = []
        var current: [Item] = []
        for (index, item) in items.enumerated() {
            current.append(item)
            if current.count == 4 || index == items.count - 1 {
                rows.append(current)
                current = []
            }
        }
        return rows
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
