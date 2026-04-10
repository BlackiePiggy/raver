import SwiftUI

struct DiscoverEventsRootView: View {
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        EventsModuleView(
            viewModel: EventsModuleViewModel(repository: appContainer.discoverEventsRepository)
        )
    }
}

struct EventsModuleView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.discoverPush) private var discoverPush
    @StateObject private var viewModel: EventsModuleViewModel

    private static let predefinedEventTypeKeys = EventTypeOption.allCases.map(\.rawValue)

    private enum EventScope: String, CaseIterable, Identifiable {
        case all
        case mine

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return L("全部活动", "All Events")
            case .mine: return L("收藏活动", "Favorites")
            }
        }
    }

    enum CountryAreaBucket: String, CaseIterable, Identifiable {
        case domestic
        case foreign

        var id: String { rawValue }

        var title: String {
            switch self {
            case .domestic: return L("国内", "Domestic")
            case .foreign: return L("国外", "International")
            }
        }
    }

    enum ContinentBucket: String, CaseIterable, Identifiable {
        case asia
        case europe
        case americas
        case oceania
        case africa

        var id: String { rawValue }

        var title: String {
            switch self {
            case .asia: return L("亚洲", "Asia")
            case .europe: return L("欧洲", "Europe")
            case .americas: return L("美洲", "Americas")
            case .oceania: return L("大洋洲", "Oceania")
            case .africa: return L("非洲", "Africa")
            }
        }
    }

    init(viewModel: EventsModuleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @State private var selectedScope: EventScope = .all
    @State private var selectedEventType = ""
    @State private var searchText = ""
    @State private var appliedSearchText = ""
    @State private var showCalendar = false
    @State private var showCountryFilter = false
    @State private var calendarSelectedDate = Date()
    @State private var calendarFilters: Set<EventCalendarViewFilter> = [.all]
    @State private var selectedAreaBuckets: Set<CountryAreaBucket> = []
    @State private var selectedContinentBuckets: Set<ContinentBucket> = []
    @State private var selectedCountries: Set<String> = []
    @State private var searchDebounceTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isShowingFullScreenLoading {
                loadingStateView
            } else if visibleEvents.isEmpty {
                emptyStateView
            } else {
                eventsListView
            }
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            headerView
        }
        .sheet(isPresented: $showCalendar) {
            EventCalendarSheet(
                events: calendarSourceEvents,
                markedEventIDs: Set(viewModel.markedCheckinIDsByEventID.keys),
                selectedDate: $calendarSelectedDate,
                selectedFilters: $calendarFilters,
                onEventSelected: { event in
                    showCalendar = false
                    discoverPush(.eventDetail(eventID: event.id))
                }
            )
            .presentationDetents([.fraction(0.8), .large])
        }
        .sheet(isPresented: $showCountryFilter) {
            EventCountryFilterSheet(
                selectedAreaBuckets: $selectedAreaBuckets,
                selectedContinentBuckets: $selectedContinentBuckets,
                selectedCountries: $selectedCountries,
                availableContinents: availableContinentBuckets,
                availableCountries: availableCountryOptions
            )
            .presentationDetents([.medium, .large])
        }
        .task(id: appState.session != nil) {
            await viewModel.reloadMarkedState(isLoggedIn: appState.session != nil, force: true)
        }
        .task(id: allQueryTaskKey) {
            guard selectedScope == .all else { return }
            await viewModel.reloadAll(query: allQuery)
        }
        .refreshable {
            await refreshCurrentScope()
        }
        .onChange(of: searchText) { _, newValue in
            scheduleSearchCommit(for: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverEventDidSave)) { _ in
            Task { await refreshAfterCreate() }
        }
        .onDisappear {
            searchDebounceTask?.cancel()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var allQuery: EventsModuleViewModel.AllQuery {
        EventsModuleViewModel.AllQuery(search: appliedSearchText, eventTypeKey: selectedEventType)
    }

    private var allQueryTaskKey: EventsModuleViewModel.AllQuery? {
        selectedScope == .all ? allQuery : nil
    }

    private var rawSourceEvents: [WebEvent] {
        selectedScope == .all ? viewModel.allEvents : viewModel.markedEvents
    }

    private var sourceEvents: [WebEvent] {
        rawSourceEvents
            .filter(eventMatchesSearch)
            .filter(eventMatchesSelectedType)
    }

    private var visibleEvents: [WebEvent] {
        sourceEvents.filter(eventMatchesCountryFilter)
    }

    private var isCountryFilterActive: Bool {
        !selectedAreaBuckets.isEmpty || !selectedContinentBuckets.isEmpty || !selectedCountries.isEmpty
    }

    private var isLoadingCurrentScope: Bool {
        selectedScope == .all ? viewModel.isLoadingAll : viewModel.isLoadingMarked
    }

    private var isShowingFullScreenLoading: Bool {
        isLoadingCurrentScope && visibleEvents.isEmpty
    }

    private var calendarSourceEvents: [WebEvent] {
        visibleEvents.sorted(by: { $0.startDate < $1.startDate })
    }

    private var eventTypeTabs: [String] {
        let dynamic = Set((viewModel.allEvents + viewModel.markedEvents).compactMap { event in
            let key = EventTypeOption.key(for: event.eventType)
            return key.isEmpty ? nil : key
        })
        var ordered = Self.predefinedEventTypeKeys
        for value in dynamic.sorted() where !ordered.contains(value) {
            ordered.append(value)
        }
        return ordered
    }

    private var availableCountryOptions: [String] {
        Array(
            Set(
                sourceEvents.compactMap { event in
                    event.country?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .nilIfEmpty
                }
            )
        )
        .sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private var availableContinentBuckets: [ContinentBucket] {
        let buckets = Set(availableCountryOptions.compactMap(continentBucket(for:)))
        return ContinentBucket.allCases.filter { buckets.contains($0) }
    }

    private var activeFilterLabels: [String] {
        var labels = selectedAreaBuckets.map(\.title).sorted()
        labels.append(contentsOf: selectedContinentBuckets.map(\.title).sorted())
        labels.append(contentsOf: selectedCountries.sorted())
        return labels
    }

    private var filterButtonTitle: String {
        if activeFilterLabels.isEmpty {
            return L("筛选", "Filter")
        }
        return L("筛选 (\(activeFilterLabels.count))", "Filter (\(activeFilterLabels.count))")
    }

    private var resultCountText: String {
        L("共 \(visibleEvents.count) 场活动", "\(visibleEvents.count) events")
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                searchField
                eventTopIconButton(systemName: "plus") {
                    discoverPush(.eventCreate)
                }
            }

            Picker("", selection: $selectedScope) {
                ForEach(EventScope.allCases) { scope in
                    Text(scope.title)
                        .tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                utilityChipButton(
                    systemName: isCountryFilterActive
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle",
                    title: filterButtonTitle,
                    isActive: isCountryFilterActive
                ) {
                    showCountryFilter = true
                }

                utilityChipButton(systemName: "calendar", title: L("日历", "Calendar")) {
                    showCalendar = true
                }

                Spacer(minLength: 8)

                Text(resultCountText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            eventTypeSelector

            if !activeFilterLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeFilterLabels, id: \.self) { label in
                            activeFilterChip(label)
                        }

                        Button {
                            clearCountryFilters()
                        } label: {
                            Text(L("清空筛选", "Clear Filters"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(RaverTheme.accent.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
//        .background(RaverTheme.background)
        .background(Color.red)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RaverTheme.secondaryText)

            TextField(
                L("搜索活动 / 城市 / 国家", "Search event / city / country"),
                text: $searchText
            )
            .font(.subheadline)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit {
                commitSearchImmediately()
            }

            if !searchText.isEmpty {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RaverTheme.secondaryText.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    private var eventTypeSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    eventTypeChip(title: EventTypeOption.allEventsTitle, value: "")
                        .id(typeChipID(for: ""))

                    ForEach(eventTypeTabs, id: \.self) { key in
                        eventTypeChip(title: EventTypeOption.displayTitle(for: key), value: key)
                            .id(typeChipID(for: key))
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear {
                proxy.scrollTo(typeChipID(for: selectedEventType), anchor: .center)
            }
            .onChange(of: selectedEventType) { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(typeChipID(for: newValue), anchor: .center)
                }
            }
        }
        .frame(height: 34)
    }

    private var loadingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(
                selectedScope == .all
                    ? L("正在加载活动", "Loading events")
                    : L("正在加载收藏活动", "Loading favorite events")
            )
            .font(.subheadline)
            .foregroundStyle(RaverTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(RaverTheme.secondaryText)

            Text(emptyStateTitle)
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateTitle: String {
        if selectedScope == .mine && appState.session == nil {
            return L("登录后查看收藏活动", "Sign in to view favorite events")
        }
        if selectedScope == .mine {
            return L("暂无收藏活动", "No favorite events yet")
        }
        return L("没有匹配的活动", "No matching events")
    }

    private var emptyStateMessage: String {
        if selectedScope == .mine && appState.session == nil {
            return L("你标记过的活动会集中显示在这里。", "Events you mark will appear here.")
        }
        if isCountryFilterActive || !selectedEventType.isEmpty || !appliedSearchText.isEmpty {
            return L("试试清空搜索词或筛选条件。", "Try clearing the search or filters.")
        }
        if selectedScope == .mine {
            return L("在活动列表里点亮星标后，这里就会出现内容。", "Mark events with the star button and they will show up here.")
        }
        return L("当前没有可展示的活动。", "There are no events to show right now.")
    }

    private var emptyStateIcon: String {
        if selectedScope == .mine && appState.session == nil {
            return "person.crop.circle.badge.exclamationmark"
        }
        return selectedScope == .mine ? "star.circle" : "calendar.badge.plus"
    }

    private var eventsListView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if isLoadingCurrentScope {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 4)
                        Spacer()
                    }
                }

                ForEach(visibleEvents) { event in
                    eventListRow(event)
                }

                if selectedScope == .all && viewModel.canLoadMoreAll {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 10)
                        Spacer()
                    }
                    .onAppear {
                        Task { await viewModel.loadMoreAllIfNeeded(query: allQuery) }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func eventListRow(_ event: WebEvent) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                presentEventDetail(event)
            } label: {
                EventRow(event: event)
            }
            .buttonStyle(.plain)

            eventActionButton(for: event)
                .padding(.bottom, 10)
                .padding(.trailing, 10)
        }
    }

    private func eventTypeChip(title: String, value: String) -> some View {
        let isSelected = selectedEventType == value
        return Button {
            selectedEventType = value
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
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

    private func utilityChipButton(
        systemName: String,
        title: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isActive ? RaverTheme.accent : RaverTheme.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(RaverTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isActive ? RaverTheme.accent.opacity(0.4) : RaverTheme.secondaryText.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func eventTopIconButton(systemName: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? RaverTheme.accent : RaverTheme.primaryText)
                .frame(width: 38, height: 38)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isActive ? RaverTheme.accent.opacity(0.45) : RaverTheme.secondaryText.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func activeFilterChip(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RaverTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(RaverTheme.card)
            )
    }

    @MainActor
    private func refreshCurrentScope() async {
        if selectedScope == .all {
            await viewModel.reloadAll(query: allQuery, force: true)
        }
        await viewModel.reloadMarkedState(isLoggedIn: appState.session != nil, force: true)
    }

    @MainActor
    private func refreshAfterCreate() async {
        await viewModel.reloadAll(query: allQuery, force: true)
        await viewModel.reloadMarkedState(isLoggedIn: appState.session != nil, force: true)
    }

    private func scheduleSearchCommit(for rawValue: String) {
        searchDebounceTask?.cancel()
        let candidate = rawValue
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                appliedSearchText = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private func commitSearchImmediately() {
        searchDebounceTask?.cancel()
        appliedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clearSearch() {
        searchDebounceTask?.cancel()
        searchText = ""
        appliedSearchText = ""
    }

    private func clearCountryFilters() {
        selectedAreaBuckets.removeAll()
        selectedContinentBuckets.removeAll()
        selectedCountries.removeAll()
    }

    private func typeChipID(for value: String) -> String {
        value.isEmpty ? "__all__" : value
    }

    private func eventMatchesSearch(_ event: WebEvent) -> Bool {
        guard let normalizedQuery = normalizedSearchToken(appliedSearchText) else {
            return true
        }

        let searchableValues: [String?] = [
            event.name,
            event.nameI18n?.en,
            event.nameI18n?.zh,
            event.city,
            event.country,
            event.venueName,
            event.venueAddress,
            event.organizerName,
            event.summaryLocation,
            EventTypeOption.displayText(for: event.eventType)
        ]

        return searchableValues.contains { value in
            guard let token = normalizedSearchToken(value) else { return false }
            return token.contains(normalizedQuery)
        }
    }

    private func eventMatchesSelectedType(_ event: WebEvent) -> Bool {
        guard !selectedEventType.isEmpty else { return true }
        return EventTypeOption.matches(rawValue: event.eventType, selectedKey: selectedEventType)
    }

    private func eventMatchesCountryFilter(_ event: WebEvent) -> Bool {
        guard isCountryFilterActive else { return true }

        let normalizedCountry = normalizedSearchToken(event.country)

        if !selectedAreaBuckets.isEmpty {
            guard let normalizedCountry else { return false }
            let isDomestic = Self.chinaCountryTokens.contains(normalizedCountry)
            let selectedDomestic = selectedAreaBuckets.contains(.domestic)
            let selectedForeign = selectedAreaBuckets.contains(.foreign)

            if !(selectedDomestic && selectedForeign) {
                if selectedDomestic && !isDomestic {
                    return false
                }
                if selectedForeign && isDomestic {
                    return false
                }
            }
        }

        if !selectedContinentBuckets.isEmpty {
            guard let continent = continentBucket(for: event.country),
                  selectedContinentBuckets.contains(continent) else {
                return false
            }
        }

        if !selectedCountries.isEmpty {
            let selectedCountryTokens = Set(selectedCountries.compactMap(normalizedSearchToken))
            guard let normalizedCountry, selectedCountryTokens.contains(normalizedCountry) else {
                return false
            }
        }

        return true
    }

    private func continentBucket(for country: String?) -> ContinentBucket? {
        guard let token = normalizedSearchToken(country) else { return nil }
        return Self.continentBucketByCountryToken[token]
    }

    private func normalizedSearchToken(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let folded = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let lowercased = folded.lowercased()
        let normalized = lowercased.replacingOccurrences(
            of: "[^a-z0-9\\u4e00-\\u9fff]",
            with: "",
            options: .regularExpression
        )

        return normalized.isEmpty ? nil : normalized
    }

    @MainActor
    private func presentEventDetail(_ event: WebEvent) {
        guard !showCalendar, !showCountryFilter else { return }
        discoverPush(.eventDetail(eventID: event.id))
    }

    private func eventActionButton(for event: WebEvent) -> some View {
        let starYellow = Color(red: 0.99, green: 0.82, blue: 0.22)
        let isMarked = viewModel.markedCheckinIDsByEventID[event.id] != nil

        return Button {
            Task {
                await viewModel.toggleMarked(event: event, isLoggedIn: appState.session != nil)
            }
        } label: {
            Image(systemName: isMarked ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isMarked ? .white : RaverTheme.secondaryText)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isMarked ? starYellow : RaverTheme.card.opacity(0.92))
                )
        }
        .buttonStyle(.plain)
    }

    private static let chinaCountryTokens: Set<String> = [
        "china", "cn", "prc", "中国", "中国大陆", "中华人民共和国"
    ]

    private static let continentBucketByCountryToken: [String: ContinentBucket] = [
        "中国": .asia, "中国大陆": .asia, "中华人民共和国": .asia, "china": .asia, "cn": .asia, "prc": .asia,
        "日本": .asia, "japan": .asia, "jp": .asia,
        "韩国": .asia, "southkorea": .asia, "korea": .asia, "kr": .asia,
        "泰国": .asia, "thailand": .asia,
        "新加坡": .asia, "singapore": .asia,
        "印度尼西亚": .asia, "indonesia": .asia,
        "马来西亚": .asia, "malaysia": .asia,
        "越南": .asia, "vietnam": .asia,
        "菲律宾": .asia, "philippines": .asia,
        "印度": .asia, "india": .asia,
        "阿联酋": .asia, "uae": .asia, "unitedarabemirates": .asia,
        "沙特阿拉伯": .asia, "saudiarabia": .asia,
        "土耳其": .asia, "turkey": .asia,

        "英国": .europe, "uk": .europe, "unitedkingdom": .europe, "greatbritain": .europe,
        "法国": .europe, "france": .europe,
        "德国": .europe, "germany": .europe,
        "荷兰": .europe, "netherlands": .europe,
        "比利时": .europe, "belgium": .europe,
        "西班牙": .europe, "spain": .europe,
        "意大利": .europe, "italy": .europe,
        "葡萄牙": .europe, "portugal": .europe,
        "瑞士": .europe, "switzerland": .europe,
        "奥地利": .europe, "austria": .europe,
        "瑞典": .europe, "sweden": .europe,
        "挪威": .europe, "norway": .europe,
        "丹麦": .europe, "denmark": .europe,
        "芬兰": .europe, "finland": .europe,
        "波兰": .europe, "poland": .europe,
        "捷克": .europe, "czechrepublic": .europe, "czechia": .europe,
        "匈牙利": .europe, "hungary": .europe,
        "克罗地亚": .europe, "croatia": .europe,
        "希腊": .europe, "greece": .europe,
        "爱尔兰": .europe, "ireland": .europe,
        "冰岛": .europe, "iceland": .europe,

        "美国": .americas, "usa": .americas, "us": .americas, "unitedstates": .americas, "unitedstatesofamerica": .americas,
        "加拿大": .americas, "canada": .americas,
        "墨西哥": .americas, "mexico": .americas,
        "巴西": .americas, "brazil": .americas,
        "阿根廷": .americas, "argentina": .americas,
        "智利": .americas, "chile": .americas,
        "哥伦比亚": .americas, "colombia": .americas,
        "秘鲁": .americas, "peru": .americas,

        "澳大利亚": .oceania, "australia": .oceania,
        "新西兰": .oceania, "newzealand": .oceania,

        "南非": .africa, "southafrica": .africa,
        "摩洛哥": .africa, "morocco": .africa,
        "埃及": .africa, "egypt": .africa,
        "肯尼亚": .africa, "kenya": .africa,
        "尼日利亚": .africa, "nigeria": .africa
    ]
}

private struct EventCountryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedAreaBuckets: Set<EventsModuleView.CountryAreaBucket>
    @Binding var selectedContinentBuckets: Set<EventsModuleView.ContinentBucket>
    @Binding var selectedCountries: Set<String>
    let availableContinents: [EventsModuleView.ContinentBucket]
    let availableCountries: [String]

    private var hasSelection: Bool {
        !selectedAreaBuckets.isEmpty || !selectedContinentBuckets.isEmpty || !selectedCountries.isEmpty
    }

    private let chipColumns = [
        GridItem(.adaptive(minimum: 88), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        chipSection(title: L("国家范围", "Area")) {
                            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                                ForEach(EventsModuleView.CountryAreaBucket.allCases) { bucket in
                                    filterChip(
                                        title: bucket.title,
                                        isSelected: selectedAreaBuckets.contains(bucket)
                                    ) {
                                        toggle(bucket, in: &selectedAreaBuckets)
                                    }
                                }
                            }
                        }

                        chipSection(title: L("大洲", "Continent")) {
                            if availableContinents.isEmpty {
                                Text(L("暂无可筛选大洲", "No continent options"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
                                LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                                    ForEach(availableContinents) { continent in
                                        filterChip(
                                            title: continent.title,
                                            isSelected: selectedContinentBuckets.contains(continent)
                                        ) {
                                            toggle(continent, in: &selectedContinentBuckets)
                                        }
                                    }
                                }
                            }
                        }

                        chipSection(title: L("国家", "Country")) {
                            if availableCountries.isEmpty {
                                Text(L("暂无可筛选国家", "No country options"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
                                LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                                    ForEach(availableCountries, id: \.self) { country in
                                        filterChip(
                                            title: country,
                                            isSelected: selectedCountries.contains(country)
                                        ) {
                                            toggle(country, in: &selectedCountries)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                }

                HStack(spacing: 10) {
                    if hasSelection {
                        Button {
                            selectedAreaBuckets.removeAll()
                            selectedContinentBuckets.removeAll()
                            selectedCountries.removeAll()
                        } label: {
                            Text(L("重置", "Reset"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(L("完成", "Done"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(RaverTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(RaverTheme.background)
            .navigationTitle(L("筛选活动", "Filter Events"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func chipSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
            }
            .foregroundStyle(isSelected ? Color.white : RaverTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                Capsule()
                    .fill(isSelected ? RaverTheme.accent : RaverTheme.background.opacity(0.9))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? RaverTheme.accent : RaverTheme.secondaryText.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}
