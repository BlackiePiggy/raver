import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UIKit
import Photos
import CoreImage.CIFilterBuiltins
import MapKit
import CoreLocation
import CoreText

private struct EventDetailTabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [EventDetailView.EventDetailTab: CGRect] = [:]

    static func reduce(value: inout [EventDetailView.EventDetailTab: CGRect], nextValue: () -> [EventDetailView.EventDetailTab: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct EventDetailPageOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [EventDetailView.EventDetailTab: CGFloat] = [:]

    static func reduce(value: inout [EventDetailView.EventDetailTab: CGFloat], nextValue: () -> [EventDetailView.EventDetailTab: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    private var eventsRepository: DiscoverEventsRepository { appContainer.discoverEventsRepository }
    private var newsRepository: DiscoverNewsRepository { appContainer.discoverNewsRepository }

    let eventID: String

    private struct EventLineupDJEntry: Identifiable, Hashable {
        let id: String
        let act: EventLineupResolvedAct

        var name: String { act.displayName }
        var avatarUrl: String? { act.type == .solo ? act.performers.first?.avatarUrl : nil }
        var djID: String? { act.type == .solo ? act.performers.first?.djID : nil }
    }

    @State private var event: WebEvent?
    @State private var isLoading = false
    @State private var showEventCheckinSheet = false
    @State private var selectedEventCheckinDayIDs: Set<String> = []
    @State private var selectedEventCheckinDJIDsByDayID: [String: Set<String>] = [:]
    @State private var relatedEventCheckins: [WebCheckin] = []
    @State private var errorMessage: String?
    @State private var selectedTab: EventDetailTab = .info
    @State private var pageProgress: CGFloat = 0
    @State private var isTabSwitchingByTap = false
    @State private var tabSwitchUnlockWorkItem: DispatchWorkItem?
    @State private var tabFrames: [EventDetailTab: CGRect] = [:]
    @State private var pagerWidth: CGFloat = 1
    @State private var isPreparingEventCheckinSheet = false
    @State private var relatedRatingEvents: [WebRatingEvent] = []
    @State private var relatedEventSets: [WebDJSet] = []
    @State private var relatedArticles: [DiscoverNewsArticle] = []
    @State private var isLoadingRelatedArticles = false
    @State private var selectedRatingEventID: String?
    @State private var showExpandedLineupList = false
    @State private var venueMapContext: EventVenueMapContext?
    @State private var lineupImageAspectRatioByURL: [String: CGFloat] = [:]
    @State private var selectedLineupMedia: FullscreenMediaSelection?

    fileprivate enum EventDetailTab: String, CaseIterable, Identifiable {
        case info
        case posts
        case lineup
        case schedule
        case ratings
        case sets

        var id: String { rawValue }

        var title: String {
            switch self {
            case .info: return L("信息", "Info")
            case .posts: return L("动态", "Posts")
            case .lineup: return L("阵容", "Lineup")
            case .schedule: return L("时间表", "Timetable")
            case .ratings: return L("打分", "Ratings")
            case .sets: return "Sets"
            }
        }

        var themeColor: Color {
            switch self {
            case .info: return Color(red: 0.27, green: 0.85, blue: 0.82)
            case .posts: return Color(red: 0.95, green: 0.30, blue: 0.38)
            case .lineup: return Color(red: 0.30, green: 0.67, blue: 0.97)
            case .schedule: return Color(red: 0.56, green: 0.78, blue: 0.30)
            case .ratings: return Color(red: 0.98, green: 0.71, blue: 0.22)
            case .sets: return Color(red: 0.58, green: 0.43, blue: 0.95)
            }
        }
    }

    private struct EventVenueMapContext: Identifiable {
        let id = UUID()
        let eventName: String
        let venueDisplayText: String
        let summaryLocation: String
        let coordinate: CLLocationCoordinate2D?
        let queryText: String
        let mapURL: URL?
    }

    private struct EventVenueMapSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.openURL) private var openURL

        let context: EventVenueMapContext

        @State private var mapPosition: MapCameraPosition
        @State private var currentRegion: MKCoordinateRegion
        @State private var resolvedCoordinate: CLLocationCoordinate2D?
        @State private var isGeocoding = false
        @State private var availableMapApps: [ExternalMapApp] = []
        @State private var showMapAppPicker = false

        private enum ExternalMapApp: String, CaseIterable, Identifiable {
            case apple = "Apple Maps"
            case amap = "Amap"
            case baidu = "Baidu Maps"
            case tencent = "Tencent Maps"

            var id: String { rawValue }
        }

        init(context: EventVenueMapContext) {
            self.context = context
            let fallbackCenter = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
            let center = context.coordinate ?? fallbackCenter
            let initialRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            )
            _mapPosition = State(
                initialValue: .region(initialRegion)
            )
            _currentRegion = State(initialValue: initialRegion)
            _resolvedCoordinate = State(initialValue: context.coordinate)
        }

        var body: some View {
            NavigationStack {
                ZStack(alignment: .top) {
                    Map(position: $mapPosition, interactionModes: .all) {
                        if let markerCoordinate = resolvedCoordinate {
                            Marker(context.venueDisplayText, coordinate: markerCoordinate)
                                .tint(RaverTheme.accent)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .onMapCameraChange(frequency: .continuous) { camera in
                        currentRegion = camera.region
                    }

                    if isGeocoding {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LL("正在定位场地..."))
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.58))
                        )
                        .padding(.top, 12)
                    }

                    VStack(spacing: 10) {
                        mapZoomButton(systemName: "plus") {
                            adjustZoom(multiplier: 0.72)
                        }
                        mapZoomButton(systemName: "minus") {
                            adjustZoom(multiplier: 1.38)
                        }
                    }
                    .padding(.trailing, 14)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .raverSystemNavigation(title: L("活动场地", "Event Venue"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.eventName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(2)

                        Text(context.venueDisplayText)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if !context.summaryLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(context.summaryLocation)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                        }

                        if let coordinate = resolvedCoordinate {
                            Text(String(format: L("纬度 %.6f，经度 %.6f", "Lat %.6f, Lng %.6f"), coordinate.latitude, coordinate.longitude))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = context.venueDisplayText
                            } label: {
                                Label(LL("复制地址"), systemImage: "doc.on.doc")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)

                            Button {
                                refreshAvailableMapApps()
                                if !availableMapApps.isEmpty {
                                    showMapAppPicker = true
                                }
                            } label: {
                                Label(LL("打开地图App"), systemImage: "arrow.up.right.square")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(RaverTheme.accent)
                            .disabled(availableMapApps.isEmpty)
                            .opacity(availableMapApps.isEmpty ? 0.65 : 1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider().opacity(0.25)
                    }
                }
                .confirmationDialog(L("选择地图应用", "Choose Map App"), isPresented: $showMapAppPicker, titleVisibility: .visible) {
                    ForEach(availableMapApps) { app in
                        Button(app.rawValue) {
                            openExternalMap(app)
                        }
                    }
                    Button(L("取消", "Cancel"), role: .cancel) {}
                }
                .task {
                    refreshAvailableMapApps()
                    await geocodeIfNeeded()
                }
            }
        }

        @MainActor
        private func geocodeIfNeeded() async {
            guard resolvedCoordinate == nil else { return }
            let query = context.queryText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }

            isGeocoding = true
            defer { isGeocoding = false }
            do {
                guard let placemark = try await geocodeAddress(query) else { return }
                guard let location = placemark.location else { return }
                let coordinate = location.coordinate
                resolvedCoordinate = coordinate
                let geocodedRegion = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                )
                currentRegion = geocodedRegion
                mapPosition = .region(geocodedRegion)
            } catch {
                // Keep interactive map usable even if geocoding fails.
            }
        }

        private func mapZoomButton(systemName: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                    )
            }
            .buttonStyle(.plain)
        }

        private func adjustZoom(multiplier: Double) {
            var next = currentRegion
            let minDelta = 0.0004
            let maxDelta = 170.0
            next.span.latitudeDelta = min(max(next.span.latitudeDelta * multiplier, minDelta), maxDelta)
            next.span.longitudeDelta = min(max(next.span.longitudeDelta * multiplier, minDelta), maxDelta)
            currentRegion = next
            mapPosition = .region(next)
        }

        private func geocodeAddress(_ address: String) async throws -> CLPlacemark? {
            try await withCheckedThrowingContinuation { continuation in
                CLGeocoder().geocodeAddressString(address, in: nil, preferredLocale: Locale(identifier: "zh_CN")) { placemarks, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: placemarks?.first)
                }
            }
        }

        private func refreshAvailableMapApps() {
            let app = UIApplication.shared
            var result: [ExternalMapApp] = []
            if context.mapURL != nil {
                result.append(.apple)
            }
            if app.canOpenURL(URL(string: "iosamap://")!) {
                result.append(.amap)
            }
            if app.canOpenURL(URL(string: "baidumap://")!) {
                result.append(.baidu)
            }
            if app.canOpenURL(URL(string: "qqmap://")!) {
                result.append(.tencent)
            }
            availableMapApps = result
        }

        private func openExternalMap(_ app: ExternalMapApp) {
            guard let url = externalMapURL(for: app) else { return }
            openURL(url)
        }

        private func externalMapURL(for app: ExternalMapApp) -> URL? {
            let coordinate = resolvedCoordinate ?? context.coordinate
            let name = context.venueDisplayText
            let query = context.queryText.trimmingCharacters(in: .whitespacesAndNewlines)

            switch app {
            case .apple:
                return context.mapURL
            case .amap:
                if let coordinate {
                    var components = URLComponents()
                    components.scheme = "iosamap"
                    components.host = "viewMap"
                    components.queryItems = [
                        URLQueryItem(name: "sourceApplication", value: "RaveHub"),
                        URLQueryItem(name: "poiname", value: name),
                        URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
                        URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
                        URLQueryItem(name: "dev", value: "0"),
                        URLQueryItem(name: "zoom", value: "17")
                    ]
                    return components.url
                }
                guard !query.isEmpty else { return nil }
                var components = URLComponents()
                components.scheme = "iosamap"
                components.host = "poi"
                components.queryItems = [
                    URLQueryItem(name: "sourceApplication", value: "RaveHub"),
                    URLQueryItem(name: "keywords", value: query)
                ]
                return components.url
            case .baidu:
                if let coordinate {
                    var components = URLComponents()
                    components.scheme = "baidumap"
                    components.host = "map"
                    components.path = "/marker"
                    components.queryItems = [
                        URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
                        URLQueryItem(name: "title", value: name),
                        URLQueryItem(name: "content", value: query.isEmpty ? name : query),
                        URLQueryItem(name: "src", value: "RaveHub")
                    ]
                    return components.url
                }
                guard !query.isEmpty else { return nil }
                var components = URLComponents()
                components.scheme = "baidumap"
                components.host = "map"
                components.path = "/search"
                components.queryItems = [
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "src", value: "RaveHub")
                ]
                return components.url
            case .tencent:
                var components = URLComponents()
                components.scheme = "qqmap"
                components.host = "map"
                components.path = "/search"
                var items: [URLQueryItem] = [
                    URLQueryItem(name: "referer", value: "RaveHub")
                ]
                if !query.isEmpty {
                    items.append(URLQueryItem(name: "keyword", value: query))
                } else {
                    items.append(URLQueryItem(name: "keyword", value: name))
                }
                if let coordinate {
                    items.append(URLQueryItem(name: "center", value: "\(coordinate.latitude),\(coordinate.longitude)"))
                }
                components.queryItems = items
                return components.url
            }
        }
    }

    private struct EventVenueInlineMapPreview: View {
        let initialCoordinate: CLLocationCoordinate2D?
        let queryText: String
        let venueDisplayText: String

        @State private var resolvedCoordinate: CLLocationCoordinate2D?
        @State private var isResolving = false

        init(initialCoordinate: CLLocationCoordinate2D?, queryText: String, venueDisplayText: String) {
            self.initialCoordinate = initialCoordinate
            self.queryText = queryText
            self.venueDisplayText = venueDisplayText
            _resolvedCoordinate = State(initialValue: initialCoordinate)
        }

        var body: some View {
            Group {
                if let coordinate = resolvedCoordinate {
                    let camera = MapCameraPosition.region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                        )
                    )
                    Map(initialPosition: camera, interactionModes: []) {
                        Marker(venueDisplayText, coordinate: coordinate)
                            .tint(RaverTheme.accent)
                    }
                    .allowsHitTesting(false)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.12, blue: 0.18),
                                Color(red: 0.08, green: 0.10, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        if isResolving {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                                Text(LL("加载地图中..."))
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.82))
                            }
                        } else {
                            Image(systemName: "map")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.42))
                        }
                    }
                }
            }
            .task {
                await geocodeIfNeeded()
            }
        }

        @MainActor
        private func geocodeIfNeeded() async {
            guard resolvedCoordinate == nil else { return }
            let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }

            isResolving = true
            defer { isResolving = false }
            do {
                guard let placemark = try await geocodeAddress(query) else { return }
                guard let location = placemark.location else { return }
                resolvedCoordinate = location.coordinate
            } catch {
                // Keep placeholder visible if geocode fails.
            }
        }

        private func geocodeAddress(_ address: String) async throws -> CLPlacemark? {
            try await withCheckedThrowingContinuation { continuation in
                CLGeocoder().geocodeAddressString(address, in: nil, preferredLocale: Locale(identifier: "zh_CN")) { placemarks, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: placemarks?.first)
                }
            }
        }
    }

    var body: some View {
        Group {
            if isLoading, event == nil {
                ProgressView(L("加载活动详情...", "Loading event details..."))
            } else if let event {
                EventDetailRepresentable(
                    heroView: AnyView(heroSection(event)),
                    eventTitle: event.name,
                    tabTitles: EventDetailTab.allCases.map(\.title),
                    tabBarView: AnyView(tabBar),
                    tabPageViews: EventDetailTab.allCases.map { tab in
                        AnyView(
                            VStack(alignment: .leading, spacing: 14) {
                                eventTabContent(
                                    event,
                                    cardWidth: max(UIScreen.main.bounds.width - 32, 0),
                                    tab: tab
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 20)
                        )
                    },
                    selectedIndex: selectedIndex(for: selectedTab),
                    pageProgress: pageProgress,
                    onTabChange: { index in
                        guard !isTabSwitchingByTap else { return }
                        guard EventDetailTab.allCases.indices.contains(index) else { return }
                        selectEventDetailTab(EventDetailTab.allCases[index])
                    },
                    onPageProgress: { progress in
                        guard !isTabSwitchingByTap else { return }
                        let maxProgress = CGFloat(max(0, EventDetailTab.allCases.count - 1))
                        pageProgress = min(max(progress, 0), maxProgress)
                    }
                )
                .ignoresSafeArea(edges: .top)
                .sheet(isPresented: $showEventCheckinSheet) {
                    EventCheckinSelectionSheet(
                        eventName: event.name,
                        options: eventCheckinDayOptions(for: event),
                        djOptionsByDayID: Dictionary(
                            uniqueKeysWithValues: eventCheckinDayOptions(for: event).map { day in
                                (day.id, eventCheckinDJOptions(for: event, selectedDayIDs: [day.id]))
                            }
                        ),
                        initialSelectedDayIDs: selectedEventCheckinDayIDs,
                        initialSelectedDJIDsByDayID: selectedEventCheckinDJIDsByDayID,
                        confirmButtonTitle: activeAttendanceCheckin == nil ? L("确认打卡", "Confirm Check-in") : L("保存修改", "Save Changes"),
                        destructiveButtonTitle: activeAttendanceCheckin == nil ? nil : L("取消打卡", "Cancel Check-in"),
                        onDelete: activeAttendanceCheckin == nil ? nil : {
                            Task { await cancelEventCheckin() }
                        }
                    ) { selectionsByDayID in
                        selectedEventCheckinDayIDs = Set(selectionsByDayID.keys)
                        selectedEventCheckinDJIDsByDayID = selectionsByDayID
                        Task { await submitEventCheckinSelections(selectedDJIDsByDayID: selectionsByDayID) }
                    }
                    .presentationDetents([.fraction(0.78), .large])
                }
                .sheet(item: $venueMapContext) { context in
                    EventVenueMapSheet(context: context)
                }
            } else {
                ContentUnavailableView(LL("活动不存在"), systemImage: "calendar.badge.exclamationmark")
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .raverImmersiveFloatingNavigationChrome(
            trailing: immersiveTrailingAction
        ) {
            dismiss()
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedRatingEventID != nil },
                set: { if !$0 { selectedRatingEventID = nil } }
            )
        ) {
            if let ratingEventID = selectedRatingEventID {
                CircleRatingEventDetailView(
                    eventID: ratingEventID,
                    onClose: {
                        selectedRatingEventID = nil
                    },
                    onUpdated: {
                        Task { await reloadEventRatings() }
                    }
                )
            }
        }
        .task {
            if event == nil {
                await load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverEventDidSave)) { notification in
            let savedEventID = notification.object as? String
            guard savedEventID == nil || savedEventID == eventID else { return }
            Task { await load() }
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func isMine(_ event: WebEvent) -> Bool {
        event.organizer?.id == appState.session?.user.id
    }

    @ViewBuilder
    private var tabBar: some View {
        RaverScrollableTabBar(
            items: eventDetailTabItems,
            selection: $selectedTab,
            progress: pageProgress,
            onSelect: { tab in
                selectEventDetailTab(tab)
            },
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            activeTextColor: RaverTheme.primaryText,
            inactiveTextColor: RaverTheme.secondaryText,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 17, weight: .regular)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(RaverTheme.background)
    }

    private var eventDetailTabItems: [RaverScrollableTabItem<EventDetailTab>] {
        EventDetailTab.allCases.map { tab in
            RaverScrollableTabItem(id: tab, title: tab.title)
        }
    }

    @ViewBuilder
    private func tabPager(event: WebEvent, cardWidth: CGFloat) -> some View {
        GeometryReader { proxy in
            TabView(selection: $selectedTab) {
                eventTabPage(event, cardWidth: cardWidth, tab: .info)
                    .tag(EventDetailTab.info)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: EventDetailPageOffsetPreferenceKey.self,
                                value: [.info: geo.frame(in: .named("EventDetailPager")).minX]
                            )
                        }
                    )
                eventTabPage(event, cardWidth: cardWidth, tab: .posts)
                    .tag(EventDetailTab.posts)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: EventDetailPageOffsetPreferenceKey.self,
                                value: [.posts: geo.frame(in: .named("EventDetailPager")).minX]
                            )
                        }
                    )
                eventTabPage(event, cardWidth: cardWidth, tab: .lineup)
                    .tag(EventDetailTab.lineup)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: EventDetailPageOffsetPreferenceKey.self,
                                value: [.lineup: geo.frame(in: .named("EventDetailPager")).minX]
                            )
                        }
                    )
                eventTabPage(event, cardWidth: cardWidth, tab: .schedule)
                    .tag(EventDetailTab.schedule)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: EventDetailPageOffsetPreferenceKey.self,
                                value: [.schedule: geo.frame(in: .named("EventDetailPager")).minX]
                            )
                        }
                    )
                eventTabPage(event, cardWidth: cardWidth, tab: .ratings)
                    .tag(EventDetailTab.ratings)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: EventDetailPageOffsetPreferenceKey.self,
                                value: [.ratings: geo.frame(in: .named("EventDetailPager")).minX]
                            )
                        }
                    )
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .coordinateSpace(name: "EventDetailPager")
            .onAppear {
                pagerWidth = max(1, proxy.size.width)
                pageProgress = CGFloat(selectedIndex(for: selectedTab))
            }
            .onChange(of: proxy.size.width) { _, newValue in
                pagerWidth = max(1, newValue)
            }
            .onChange(of: selectedTab) { _, newValue in
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                    pageProgress = CGFloat(selectedIndex(for: newValue))
                }
            }
            .onPreferenceChange(EventDetailPageOffsetPreferenceKey.self) { values in
                updatePageProgress(with: values)
            }
        }
    }

    @ViewBuilder
    private func eventTabPage(_ event: WebEvent, cardWidth: CGFloat, tab: EventDetailTab) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                eventTabContent(event, cardWidth: cardWidth, tab: tab)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.always)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func eventTabContent(_ event: WebEvent, cardWidth: CGFloat, tab: EventDetailTab) -> some View {
        switch tab {
        case .info:
            eventInfoTabContent(event, cardWidth: cardWidth)
        case .posts:
            eventPostsTabContent
        case .lineup:
            eventLineupTabContent(event, cardWidth: cardWidth)
        case .schedule:
            eventScheduleTabContent(event)
        case .ratings:
            eventRatingsTabContent()
        case .sets:
            eventSetsTabContent()
        }
    }

    @ViewBuilder
    private var eventPostsTabContent: some View {
        if isLoadingRelatedArticles && relatedArticles.isEmpty {
            ProgressView(LL("正在加载相关资讯..."))
                .padding(.vertical, 8)
        } else if relatedArticles.isEmpty {
            Text(LL("暂无相关资讯"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            ForEach(Array(relatedArticles.enumerated()), id: \.element.id) { index, article in
                Button {
                    discoverPush(.newsDetail(articleID: article.id))
                } label: {
                    DiscoverNewsRow(article: article, showsSummary: false)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                if index < relatedArticles.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func eventInfoTabContent(_ event: WebEvent, cardWidth: CGFloat) -> some View {
        let status = EventVisualStatus.resolve(event: event)
        let eventType = EventTypeOption.displayText(for: event.eventType, fallbackWhenEmpty: false)
        let cityText = event.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let countryText = event.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cityCountryText = [cityText, countryText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let cityCountryDisplay = cityCountryText.isEmpty ? event.summaryLocation : cityCountryText

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    eventStatusPill(status.title, color: status.badgeBorder)
                    if !eventType.isEmpty {
                        eventStatusPill(eventType, color: RaverTheme.accent)
                    }
                }

                eventInfoRow(
                    icon: "calendar",
                    title: L("开始时间", "Start Time"),
                    value: eventInfoDateText(event.startDate)
                )
                eventInfoRow(
                    icon: "clock",
                    title: L("结束时间", "End Time"),
                    value: eventInfoDateText(event.endDate)
                )
                if !cityCountryDisplay.isEmpty {
                    eventInfoRow(icon: "mappin.and.ellipse", title: L("城市 / 国家", "City / Country"), value: cityCountryDisplay)
                }
                if hasEventVenueContent(event) {
                    eventVenueActionRow(event)
                    eventVenueInlineMapCard(event)
                }
                if let website = event.officialWebsite, !website.isEmpty {
                    if let websiteURL = normalizedEventURL(website) {
                        Link(destination: websiteURL) {
                            eventInfoRow(icon: "globe", title: L("官网", "Website"), value: website, linkStyle: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        eventInfoRow(icon: "globe", title: L("官网", "Website"), value: website)
                    }
                }
            }
        }
        .frame(width: cardWidth, alignment: .leading)

        let displayDescription = EventWeekScheduleMode.stripMarker(from: event.description)
        if !displayDescription.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LL("活动介绍"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(displayDescription)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }

        if !event.ticketTiers.isEmpty || ((event.ticketNotes ?? "").isEmpty == false) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LL("票档信息"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    ForEach(event.ticketTiers) { tier in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                            }
                            Spacer()
                            Text("\(tier.currency ?? event.ticketCurrency ?? "CNY") \(Int(tier.price ?? 0))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.accent)
                        }
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) {
                            Divider().opacity(0.28)
                        }
                    }
                    if let notes = event.ticketNotes, !notes.isEmpty {
                        Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }

        if let organizer = event.organizer {
            GlassCard {
                Button {
                    appPush(.userProfile(userID: organizer.id))
                } label: {
                    HStack(spacing: 10) {
                        ImageLoaderView(urlString: organizer.avatarUrl, resizingMode: .fill)
                            .background(organizerAvatarFallback(organizer))
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LL("发布方"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(organizer.displayName ?? organizer.username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: cardWidth, alignment: .leading)
        } else if let organizerName = event.organizerName, !organizerName.isEmpty {
            GlassCard {
                eventInfoRow(icon: "person.2", title: L("发布方", "Publisher"), value: organizerName)
            }
            .frame(width: cardWidth, alignment: .leading)
        }

        if isMine(event) {
            Button(role: .destructive) {
                Task { await deleteEvent() }
            } label: {
                Text(LL("删除活动"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func eventLineupTabContent(_ event: WebEvent, cardWidth: CGFloat) -> some View {
        let lineupImageURLs = event.lineupAssetURLs
        let timetableImageURLs = event.timetableAssetURLs
        let allLineupMediaURLs = lineupImageURLs + timetableImageURLs
        let lineupPreviewItems: [FullscreenMediaItem] = allLineupMediaURLs.enumerated().map { index, raw in
            FullscreenMediaItem(rawURL: raw.trimmingCharacters(in: .whitespacesAndNewlines), index: index)
        }
        let hasLineupDJs = !lineupDJEntries(for: event).isEmpty

        lineupDJsStrip(for: event)

        if !allLineupMediaURLs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(LL("活动阵容图"))
                    .font(.headline)

                ForEach(Array(allLineupMediaURLs.enumerated()), id: \.offset) { index, rawURL in
                    if allLineupMediaURLs.count > 1 {
                        if index < lineupImageURLs.count {
                            Text(lineupImageURLs.count > 1 ? "Lineup \(index + 1)" : "Lineup")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            Text(timetableImageURLs.count > 1 ? "Timetable \(index - lineupImageURLs.count + 1)" : "Timetable")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }

                    if let resolved = AppConfig.resolvedURLString(rawURL) {
                        Button {
                            selectedLineupMedia = FullscreenMediaSelection(id: index)
                        } label: {
                            ImageLoaderView(
                                urlString: resolved,
                                resizingMode: .fit,
                                onImageLoaded: { imageSize in
                                    guard imageSize.width > 0, imageSize.height > 0 else { return }
                                    let ratio = imageSize.width / imageSize.height
                                    let old = lineupImageAspectRatioByURL[resolved]
                                    if old == nil || abs((old ?? ratio) - ratio) > 0.001 {
                                        lineupImageAspectRatioByURL[resolved] = ratio
                                    }
                                }
                            )
                            .frame(width: cardWidth)
                            .frame(
                                height: cardWidth / max(lineupImageAspectRatioByURL[resolved] ?? 1, 0.0001)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(RaverTheme.card)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(RaverTheme.card)
                            .frame(width: cardWidth)
                            .frame(minHeight: 180)
                    }
                }
            }
            .frame(width: cardWidth, alignment: .leading)
            .fullScreenCover(item: $selectedLineupMedia) { selection in
                FullscreenMediaViewer(items: lineupPreviewItems, initialIndex: selection.id)
            }
        }

        if allLineupMediaURLs.isEmpty && !hasLineupDJs {
            Text(LL("暂无阵容信息"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func eventScheduleTabContent(_ event: WebEvent) -> some View {
        let scheduledSlots = event.lineupSlots
            .filter { $0.endTime > $0.startTime }
            .sorted(by: { $0.startTime < $1.startTime })

        if scheduledSlots.isEmpty {
            Text(LL("等待时间表发布"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            EventRoutineView(
                event: event,
                scheduledSlots: scheduledSlots,
                presentationStyle: .embedded
            )
        }
    }

    @ViewBuilder
    private func eventRatingsTabContent() -> some View {
        if relatedRatingEvents.isEmpty {
            Text(LL("暂无对应打分事件"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            ForEach(relatedRatingEvents) { ratingEvent in
                Button {
                    selectedRatingEventID = ratingEvent.id
                } label: {
                    HStack(spacing: 10) {
                        eventRatingThumb(urlString: ratingEvent.imageUrl, size: 52)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(ratingEvent.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(2)
                            Text(L("\(ratingEvent.units.count) 个打分对象", "\(ratingEvent.units.count) rating targets"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
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
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func eventSetsTabContent() -> some View {
        if relatedEventSets.isEmpty {
            Text(LL("暂无对应 Sets"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            ForEach(relatedEventSets) { set in
                Button {
                    discoverPush(.setDetail(setID: set.id))
                } label: {
                    HStack(spacing: 10) {
                        eventRatingThumb(urlString: set.thumbnailUrl, size: 52)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(2)
                            Text(set.dj?.name ?? set.djId)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                            if let recordedAt = set.recordedAt {
                                Text(recordedAt.appLocalizedYMDText())
                                    .font(.caption2)
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
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func eventRatingThumb(urlString: String?, size: CGFloat) -> some View {
        ImageLoaderView(urlString: urlString, resizingMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(RaverTheme.card)
                    .overlay(
                        Image(systemName: "star.leadinghalf.filled")
                            .font(.system(size: size * 0.32, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                    )
            )
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func eventSchedulePreviewRow(_ slot: WebEventLineupSlot) -> some View {
        let act = EventLineupActCodec.parse(slot: slot)
        let stageName = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(act.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)
                    if act.type != .solo {
                        lineupActTag(act.type)
                    }
                }

                if !stageName.isEmpty {
                    Text(stageName)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text("\(Self.eventSlotTimeFormatter.string(from: slot.startTime)) - \(Self.eventSlotTimeFormatter.string(from: slot.endTime))")
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    private func lineupActTag(_ type: EventLineupActType) -> some View {
        Text(type.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(RaverTheme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RaverTheme.accent.opacity(0.14), in: Capsule())
    }

    private func selectEventDetailTab(_ tab: EventDetailTab) {
        let targetProgress = CGFloat(selectedIndex(for: tab))
        if selectedTab == tab, abs(pageProgress - targetProgress) < 0.001 {
            return
        }

        isTabSwitchingByTap = true
        tabSwitchUnlockWorkItem?.cancel()

        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.84)) {
            selectedTab = tab
            pageProgress = targetProgress
        }

        let unlockWorkItem = DispatchWorkItem {
            isTabSwitchingByTap = false
            tabSwitchUnlockWorkItem = nil
        }
        tabSwitchUnlockWorkItem = unlockWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: unlockWorkItem)
    }

    private var indicatorRect: CGRect? {
        guard !tabFrames.isEmpty else { return nil }
        let count = EventDetailTab.allCases.count
        guard count > 0 else { return nil }

        let clamped = min(max(pageProgress, 0), CGFloat(count - 1))
        let leftIndex = Int(floor(clamped))
        let rightIndex = min(leftIndex + 1, count - 1)
        let t = clamped - CGFloat(leftIndex)

        let leftTab = EventDetailTab.allCases[leftIndex]
        let rightTab = EventDetailTab.allCases[rightIndex]
        guard let leftFrame = tabFrames[leftTab], let rightFrame = tabFrames[rightTab] else {
            return nil
        }

        let baseX = leftFrame.minX + (rightFrame.minX - leftFrame.minX) * t
        let baseWidth = leftFrame.width + (rightFrame.width - leftFrame.width) * t
        let elastic = (1 - abs(0.5 - t) * 2) * 16
        return CGRect(x: baseX - elastic * 0.2, y: 0, width: baseWidth + elastic, height: 3)
    }

    private func selectedIndex(for tab: EventDetailTab) -> Int {
        EventDetailTab.allCases.firstIndex(of: tab) ?? 0
    }

    private func tabVisualState(for tab: EventDetailTab) -> Bool {
        let index = CGFloat(selectedIndex(for: tab))
        return abs(pageProgress - index) < 0.5
    }

    private func updatePageProgress(with offsets: [EventDetailTab: CGFloat]) {
        guard pagerWidth > 1 else { return }
        let progressCandidates: [(progress: CGFloat, distance: CGFloat)] = EventDetailTab.allCases.enumerated().compactMap { index, item in
            guard let minX = offsets[item] else { return nil }
            let progress = CGFloat(index) - (minX / pagerWidth)
            return (progress, abs(minX))
        }

        guard let best = progressCandidates.min(by: { $0.distance < $1.distance }) else { return }
        let clamped = min(max(best.progress, 0), CGFloat(max(0, EventDetailTab.allCases.count - 1)))
        pageProgress = clamped
    }

    private func heroSection(_ event: WebEvent) -> some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                ZStack {
                    RaverTheme.card
                    if let cover = AppConfig.resolvedURLString(event.coverAssetURL) {
                        ImageLoaderView(urlString: cover)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .background(RaverTheme.card)
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
                colors: [
                    .clear,
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.78),
                    Color.black.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
            Spacer()   // 把内容推到底
            VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        Button {
                            Task { await beginEventCheckinFlow(for: event) }
                        } label: {
                            eventHeroActionButton(
                                title: activeAttendanceCheckin == nil ? L("打卡", "Check-in") : L("编辑打卡", "Edit Check-in"),
                                icon: "bookmark.fill",
                                fill: RaverTheme.accent
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isPreparingEventCheckinSheet)

                        if let ticketURL = event.ticketUrl, let url = normalizedEventURL(ticketURL) {
                            Link(destination: url) {
                                eventHeroActionButton(title: L("购票", "Tickets"), icon: "ticket", fill: Color(red: 0.2, green: 0.56, blue: 0.98))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 6)

                    Text(event.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
        .zIndex(1)
    }

    private func eventHeroActionButton(title: String, icon: String, fill: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(fill)
            )
    }

    private func hasEventVenueContent(_ event: WebEvent) -> Bool {
        let venue = event.venueName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let address = event.venueAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let summary = event.summaryLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        return !venue.isEmpty || !address.isEmpty || !summary.isEmpty || event.latitude != nil || event.longitude != nil
    }

    private func eventVenueDisplayText(_ event: WebEvent) -> String {
        let venue = event.venueName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let address = event.venueAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let manual = [venue, address].filter { !$0.isEmpty }.joined(separator: " · ")
        if !manual.isEmpty { return manual }
        if !event.summaryLocation.isEmpty { return event.summaryLocation }
        return L("未填写场地信息", "Venue not provided")
    }

    private func eventMapURL(for event: WebEvent) -> URL? {
        let queryText = eventVenueDisplayText(event)
        if let latitude = event.latitude, let longitude = event.longitude {
            var components = URLComponents(string: "http://maps.apple.com/")
            components?.queryItems = [
                URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "q", value: queryText)
            ]
            return components?.url
        }

        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: queryText)]
        return components?.url
    }

    private func eventVenueCoordinate(_ event: WebEvent) -> CLLocationCoordinate2D? {
        guard let latitude = event.latitude, let longitude = event.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func copyEventVenueText(_ event: WebEvent) {
        UIPasteboard.general.string = eventVenueDisplayText(event)
        errorMessage = L("场地信息已复制", "Venue information copied.")
    }

    private func openEventVenueInMap(_ event: WebEvent) {
        let venueText = eventVenueDisplayText(event)
        let summary = event.summaryLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackQuery = eventVenueFallbackQuery(event)
        let coordinate = eventVenueCoordinate(event)
        guard coordinate != nil || !fallbackQuery.isEmpty else {
            errorMessage = L("暂无场地定位信息", "No venue location information available.")
            return
        }

        venueMapContext = EventVenueMapContext(
            eventName: event.name,
            venueDisplayText: venueText,
            summaryLocation: summary,
            coordinate: coordinate,
            queryText: fallbackQuery,
            mapURL: eventMapURL(for: event)
        )
    }

    private func eventVenueActionRow(_ event: WebEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(RaverTheme.card.opacity(1))
                    .frame(width: 28, height: 28)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(LL("场地"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText.opacity(0.88))
                Text(eventVenueDisplayText(event))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func eventVenueInlineMapCard(_ event: WebEvent) -> some View {
        let queryText = eventVenueFallbackQuery(event)
        Button {
            openEventVenueInMap(event)
        } label: {
            ZStack(alignment: .bottomLeading) {
                EventVenueInlineMapPreview(
                    initialCoordinate: eventVenueCoordinate(event),
                    queryText: queryText,
                    venueDisplayText: eventVenueDisplayText(event)
                )

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(spacing: 6) {
                    Image(systemName: "location.viewfinder")
                    Text(LL("查看地图"))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.38))
                )
                .padding(10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 146)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private func eventVenueFallbackQuery(_ event: WebEvent) -> String {
        let venueText = eventVenueDisplayText(event)
        let summary = event.summaryLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        return (venueText == L("未填写场地信息", "Venue not provided") ? summary : venueText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedEventURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute
        }
        return URL(string: "https://\(trimmed)")
    }

    private static let eventSlotTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var immersiveTrailingAction: AnyView? {
        guard let event, isMine(event) else { return nil }
        return AnyView(
            RaverNavigationCircleIconButton(
                systemName: "square.and.pencil",
                style: .immersiveAdaptive
            ) {
                discoverPush(.eventEdit(eventID: event.id))
            }
        )
    }

    @ViewBuilder
    private func lineupDJsStrip(for event: WebEvent) -> some View {
        let djs = lineupDJEntries(for: event)
        let canExpand = djs.count > 8
        if !djs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(LL("参演 DJ"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer(minLength: 0)
                    if canExpand {
                        Button {
                            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.85)) {
                                showExpandedLineupList.toggle()
                            }
                        } label: {
                            Label(
                                showExpandedLineupList ? L("收起名单", "Collapse lineup") : L("下拉完整名单", "Expand full lineup"),
                                systemImage: showExpandedLineupList ? "chevron.up" : "chevron.down"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HorizontalAxisLockedScrollView(showsIndicators: false) {
                    HStack(alignment: .top, spacing: 7) {
                        ForEach(djs) { dj in
                            lineupDJAvatarItem(dj)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 82)

                if showExpandedLineupList {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 74), spacing: 10)],
                            alignment: .leading,
                            spacing: 12
                        ) {
                            ForEach(djs) { dj in
                                lineupDJAvatarItem(dj)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(RaverTheme.card.opacity(0.86))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                    )
                    .padding(.top, 4)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                        )
                    )
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showExpandedLineupList)
        }
    }

    @ViewBuilder
    private func lineupDJAvatarItem(_ dj: EventLineupDJEntry) -> some View {
        let itemWidth = lineupActItemWidth(dj.act)
        let content = VStack(spacing: 6) {
            lineupActAvatars(dj.act)

            Text(dj.name)
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(width: itemWidth, height: 30, alignment: .center)
        }
        .frame(width: itemWidth, alignment: .top)

        if dj.act.type == .solo,
           let primaryPerformer = dj.act.performers.first,
           let djID = resolvedPerformerDJID(primaryPerformer) {
            Button {
                appPush(.djDetail(djID: djID))
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private func lineupActAvatars(_ act: EventLineupResolvedAct) -> some View {
        let contentWidth = lineupActItemWidth(act)
        if act.type == .solo {
            lineupPerformerAvatar(act.performers.first, size: 44)
                .frame(width: contentWidth, height: 44, alignment: .center)
        } else {
            let performers = Array(act.performers.prefix(act.type.performerCount))
            let b2bColor = Color(red: 0.98, green: 0.52, blue: 0.20)
            let b3bColor = Color(red: 0.18, green: 0.74, blue: 0.92)
            let avatarSize: CGFloat = 44
            let avatarGap: CGFloat = 10
            let connectorSize: CGFloat = 14

            ZStack(alignment: .leading) {
                HStack(spacing: avatarGap) {
                    ForEach(Array(performers.enumerated()), id: \.offset) { _, performer in
                        lineupPerformerAvatarLink(performer, size: avatarSize)
                    }
                }
                ForEach(0..<max(0, performers.count - 1), id: \.self) { index in
                    lineupActConnectorLabel(
                        text: act.type == .b2b ? "B2B" : "B3B",
                        color: act.type == .b2b ? b2bColor : b3bColor,
                        vertical: true
                    )
                    .frame(width: connectorSize, height: connectorSize)
                    .offset(
                        x: avatarSize * CGFloat(index + 1) + avatarGap * CGFloat(index) + (avatarGap - connectorSize) / 2,
                        y: (avatarSize - connectorSize) / 2
                    )
                }
            }
            .frame(width: contentWidth, height: 44, alignment: .center)
        }
    }

    private func lineupActItemWidth(_ act: EventLineupResolvedAct) -> CGFloat {
        guard act.type != .solo else { return 74 }
        let performerCount = CGFloat(max(1, min(act.performers.count, act.type.performerCount)))
        let avatarSize: CGFloat = 44
        let spacing: CGFloat = 10
        let width = performerCount * avatarSize + (performerCount - 1) * spacing
        return max(74, width)
    }

    @ViewBuilder
    private func lineupPerformerAvatarLink(_ performer: EventLineupPerformer, size: CGFloat) -> some View {
        if let djID = resolvedPerformerDJID(performer) {
            Button {
                appPush(.djDetail(djID: djID))
            } label: {
                lineupPerformerAvatar(performer, size: size)
            }
            .buttonStyle(.plain)
        } else {
            lineupPerformerAvatar(performer, size: size)
        }
    }

    private func resolvedPerformerDJID(_ performer: EventLineupPerformer) -> String? {
        let inlineID = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return inlineID.isEmpty ? nil : inlineID
    }

    private func lineupActConnectorLabel(text: String, color: Color, vertical: Bool) -> some View {
        Circle()
            .fill(color.opacity(0.24))
            .overlay(
                Text(text)
                    .font(.system(size: 4.4, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            )
    }

    private func lineupDJEntries(for event: WebEvent) -> [EventLineupDJEntry] {
        var seen = Set<String>()
        var result: [EventLineupDJEntry] = []
        let avatarByName = performerAvatarMap(from: event)
        let followerByName = lineupFollowerMapByName(from: event)
        let followerByID = lineupFollowerMapByID(from: event)

        for slot in event.lineupSlots.sorted(by: { $0.startTime < $1.startTime }) {
            var act = EventLineupActCodec.parse(slot: slot)
            for index in act.performers.indices {
                if act.performers[index].avatarUrl == nil {
                    let key = normalizedPerformerNameKey(act.performers[index].name)
                    if let avatar = avatarByName[key] {
                        act.performers[index].avatarUrl = avatar
                    }
                }
            }
            let displayName = act.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else { continue }

            let key: String
            if act.type == .solo, let djID = act.performers.first?.djID, !djID.isEmpty {
                key = "dj-\(djID)"
            } else {
                key = "act-\(EventLineupActCodec.canonicalKey(for: act))"
            }
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(EventLineupDJEntry(id: key, act: act))
        }

        return result
            .enumerated()
            .sorted { lhs, rhs in
                shouldOrderLineupAct(
                    lhs.element.act,
                    before: rhs.element.act,
                    lhsIndex: lhs.offset,
                    rhsIndex: rhs.offset,
                    followerByID: followerByID,
                    followerByName: followerByName
                )
            }
            .map(\.element)
    }

    private func performerAvatarMap(from event: WebEvent) -> [String: String] {
        var map: [String: String] = [:]
        for slot in event.lineupSlots.sorted(by: { $0.startTime < $1.startTime }) {
            if let dj = slot.dj {
                let nameKey = normalizedPerformerNameKey(dj.name)
                let avatar = (dj.avatarSmallUrl ?? dj.avatarUrl)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !nameKey.isEmpty, !avatar.isEmpty, map[nameKey] == nil {
                    map[nameKey] = avatar
                }
            }
        }
        return map
    }

    private func lineupFollowerMapByName(from event: WebEvent) -> [String: Int] {
        var map: [String: Int] = [:]
        for slot in event.lineupSlots {
            guard let dj = slot.dj else { continue }
            let key = normalizedPerformerNameKey(dj.name)
            guard !key.isEmpty else { continue }
            guard let followers = dj.soundCloudFollowers else { continue }
            map[key] = max(map[key] ?? 0, followers)
        }

        return map
    }

    private func lineupFollowerMapByID(from event: WebEvent) -> [String: Int] {
        var map: [String: Int] = [:]
        for slot in event.lineupSlots {
            guard let dj = slot.dj else { continue }
            guard let followers = dj.soundCloudFollowers else { continue }
            map[dj.id] = max(map[dj.id] ?? 0, followers)
        }

        return map
    }

    private func lineupFollowers(
        for performer: EventLineupPerformer,
        followerByID: [String: Int],
        followerByName: [String: Int]
    ) -> Int? {
        if let djID = resolvedPerformerDJID(performer),
           let followers = followerByID[djID] {
            return followers
        }
        return followerByName[normalizedPerformerNameKey(performer.name)]
    }

    private func lineupMaxFollowers(
        for act: EventLineupResolvedAct,
        followerByID: [String: Int],
        followerByName: [String: Int]
    ) -> Int? {
        act.performers
            .compactMap { lineupFollowers(for: $0, followerByID: followerByID, followerByName: followerByName) }
            .max()
    }

    private func lineupSortName(for act: EventLineupResolvedAct) -> String {
        let raw = act.type == .solo ? (act.performers.first?.name ?? act.displayName) : act.displayName
        return normalizedPerformerNameKey(raw)
    }

    private func shouldOrderLineupAct(
        _ lhs: EventLineupResolvedAct,
        before rhs: EventLineupResolvedAct,
        lhsIndex: Int,
        rhsIndex: Int,
        followerByID: [String: Int],
        followerByName: [String: Int]
    ) -> Bool {
        let leftFollowers = lineupMaxFollowers(for: lhs, followerByID: followerByID, followerByName: followerByName)
        let rightFollowers = lineupMaxFollowers(for: rhs, followerByID: followerByID, followerByName: followerByName)

        switch (leftFollowers, rightFollowers) {
        case let (left?, right?):
            if left != right { return left > right }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }

        let leftName = lineupSortName(for: lhs)
        let rightName = lineupSortName(for: rhs)
        let nameCompare = leftName.localizedCaseInsensitiveCompare(rightName)
        if nameCompare != .orderedSame {
            return nameCompare == .orderedAscending
        }
        return lhsIndex < rhsIndex
    }

    private func normalizedPerformerNameKey(_ raw: String) -> String {
        normalizedDJLookupKey(raw)
    }

    @ViewBuilder
    private func lineupPerformerAvatar(_ performer: EventLineupPerformer?, size: CGFloat) -> some View {
        let performerName = performer?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ImageLoaderView(
            urlString: AppConfig.resolvedDJAvatarURLString(performer?.avatarUrl, size: .small),
            resizingMode: .fill
        )
        .background(
            Circle()
                .fill(RaverTheme.card)
                .overlay(
                    Text(String((performerName.isEmpty ? "?" : performerName).prefix(1)).uppercased())
                        .font(.system(size: max(10, size * 0.3), weight: .bold))
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        )
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func eventStatusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }

    private func eventInfoRow(icon: String, title: String, value: String, linkStyle: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill((linkStyle ? RaverTheme.accent : RaverTheme.card).opacity(linkStyle ? 0.18 : 1))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(linkStyle ? RaverTheme.accent : RaverTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText.opacity(0.88))
                Text(value)
                    .font(.subheadline.weight(linkStyle ? .semibold : .regular))
                    .foregroundStyle(linkStyle ? RaverTheme.accent : RaverTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            if linkStyle {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(RaverTheme.accent)
                    .padding(.top, 3)
            }
        }
    }

    private func eventInfoDateText(_ date: Date) -> String {
        switch AppLanguagePreference.current.effectiveLanguage {
        case .zh:
            return date.appLocalizedYMDText()
        case .en, .system:
            return date.formatted(date: .complete, time: .omitted)
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
            Text(L("状态：\(status.title)", "Status: \(status.title)"))
                .foregroundStyle(RaverTheme.secondaryText)
                .font(.subheadline)
        }
    }

    private var activeAttendanceCheckin: WebCheckin? {
        relatedEventCheckins
            .filter(\.isEventAttendanceCheckin)
            .sorted {
                if $0.attendedAt == $1.attendedAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.attendedAt > $1.attendedAt
            }
            .first
    }

    private var legacyRelatedDJCheckins: [WebCheckin] {
        relatedEventCheckins
            .filter { $0.type == "dj" && $0.eventId == eventID }
            .sorted {
                if $0.attendedAt == $1.attendedAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.attendedAt > $1.attendedAt
            }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let hasSession = await MainActor.run { appState.session != nil }
            await MainActor.run {
                isLoadingRelatedArticles = true
            }
            async let eventTask = eventsRepository.fetchEvent(id: eventID)
            async let checkinsTask: [WebCheckin] = {
                guard hasSession else { return [] }
                let page = try? await eventsRepository.fetchMyCheckins(
                    page: 1,
                    limit: 200,
                    type: nil,
                    eventID: eventID,
                    djID: nil
                )
                return page?.items ?? []
            }()
            async let ratingEventsTask = eventsRepository.fetchEventRatingEvents(eventID: eventID)
            async let relatedArticlesTask = fetchRelatedNewsArticlesForEvent(eventID: eventID)

            let loadedEvent = try await eventTask
            event = loadedEvent
            relatedEventCheckins = await checkinsTask
            relatedRatingEvents = (try? await ratingEventsTask) ?? []
            relatedEventSets = (try? await eventsRepository.fetchEventDJSets(eventName: loadedEvent.name)) ?? []
            relatedArticles = (try? await relatedArticlesTask) ?? []
            isLoadingRelatedArticles = false
        } catch {
            isLoadingRelatedArticles = false
            errorMessage = error.userFacingMessage
        }
    }

    private func fetchRelatedNewsArticlesForEvent(eventID: String) async throws -> [DiscoverNewsArticle] {
        try await newsRepository.fetchArticlesBoundToEvent(eventID: eventID, maxPages: 8)
    }

    private func reloadEventRatings() async {
        relatedRatingEvents = (try? await eventsRepository.fetchEventRatingEvents(eventID: eventID)) ?? []
    }

    private func reloadEventSets() async {
        guard let event else {
            relatedEventSets = []
            return
        }
        relatedEventSets = (try? await eventsRepository.fetchEventDJSets(eventName: event.name)) ?? []
    }

    @MainActor
    private func beginEventCheckinFlow(for event: WebEvent) async {
        let dayOptions = eventCheckinDayOptions(for: event)
        guard !dayOptions.isEmpty else { return }

        guard !isPreparingEventCheckinSheet else { return }
        isPreparingEventCheckinSheet = true
        defer { isPreparingEventCheckinSheet = false }

        do {
            let page = try await eventsRepository.fetchMyCheckins(
                page: 1,
                limit: 200,
                type: nil,
                eventID: eventID,
                djID: nil
            )
            relatedEventCheckins = page.items
        } catch {
            if relatedEventCheckins.isEmpty {
                errorMessage = L("打卡记录加载失败，请稍后重试", "Failed to load check-in records. Please try again later.")
                return
            }
        }

        if let activeAttendanceCheckin {
            let selections = preselectedDaySelections(for: activeAttendanceCheckin, in: event)
            selectedEventCheckinDayIDs = Set(selections.map(\.dayID))
            selectedEventCheckinDJIDsByDayID = Dictionary(
                uniqueKeysWithValues: selections.map { selection in
                    (selection.dayID, Set(selection.djSelections.map(\.id)))
                }
            )
        } else {
            selectedEventCheckinDayIDs = []
            selectedEventCheckinDJIDsByDayID = [:]
        }

        showEventCheckinSheet = true
    }

    private func eventCheckinDayOptions(for event: WebEvent) -> [EventCheckinDayOption] {
        let calendar = Calendar.current
        let usesWeekMode = EventWeekScheduleMode.isEnabled(in: event.description)
        let dayIndexes: [Int] = {
            let lineupDayIndexes = Array(
                Set(event.lineupSlots.map { slot in
                    EventLogicalDayResolver.dayIndex(
                        for: slot,
                        eventStartDate: event.startDate,
                        dayRolloverHour: event.dayRolloverHour
                    )
                })
            ).sorted()
            if !lineupDayIndexes.isEmpty {
                return lineupDayIndexes
            }

            let startDay = calendar.startOfDay(for: event.startDate)
            let normalizedEnd = max(event.endDate, event.startDate)
            let endDay = calendar.startOfDay(for: normalizedEnd)
            let span = max((calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1, 1)
            return Array(1...span)
        }()

        return dayIndexes.map { dayIndex in
            let dayDate = EventLogicalDayResolver.dayDate(for: dayIndex, anchorDate: event.startDate)
            let slotsOnDay = event.lineupSlots.filter { slot in
                EventLogicalDayResolver.dayIndex(
                    for: slot,
                    eventStartDate: event.startDate,
                    dayRolloverHour: event.dayRolloverHour
                ) == dayIndex
            }
            let fallback = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: dayDate) ?? dayDate
            let baseAttendedAt = slotsOnDay.map(\.startTime).min() ?? (dayIndex == 1 ? event.startDate : fallback)
            let attendedAt = min(baseAttendedAt, Date())
            let weekDay = usesWeekMode ? EventWeekScheduleMode.weekDayIndex(for: dayDate, anchorDate: event.startDate) : nil

            return EventCheckinDayOption(
                id: Self.eventCheckinDayKey(for: dayDate),
                dayIndex: dayIndex,
                dayDate: dayDate,
                attendedAt: attendedAt,
                weekIndex: weekDay?.week,
                dayInWeek: weekDay?.day
            )
        }
    }

    private func eventCheckinDJOptions(for event: WebEvent, selectedDayIDs: Set<String>) -> [EventCheckinDJOption] {
        guard !selectedDayIDs.isEmpty else { return [] }

        let avatarByName = performerAvatarMap(from: event)
        var firstStartByOptionID: [String: Date] = [:]
        var optionByOptionID: [String: EventCheckinDJOption] = [:]

        for slot in event.lineupSlots.sorted(by: { $0.startTime < $1.startTime }) {
            let dayIndex = EventLogicalDayResolver.dayIndex(
                for: slot,
                eventStartDate: event.startDate,
                dayRolloverHour: event.dayRolloverHour
            )
            let key = Self.eventCheckinDayKey(
                for: EventLogicalDayResolver.dayDate(for: dayIndex, anchorDate: event.startDate)
            )
            guard selectedDayIDs.contains(key) else { continue }

            var act = EventLineupActCodec.parse(slot: slot)
            for index in act.performers.indices {
                if act.performers[index].avatarUrl == nil {
                    let performerKey = normalizedPerformerNameKey(act.performers[index].name)
                    if let avatar = avatarByName[performerKey] {
                        act.performers[index].avatarUrl = avatar
                    }
                }
            }
            let displayName = act.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else { continue }

            let optionID: String = {
                if act.type == .solo,
                   let performer = act.performers.first,
                   let djID = performer.djID,
                   !djID.isEmpty {
                    return djID
                }
                let canonical = EventLineupActCodec.canonicalKey(for: act)
                if act.type == .solo {
                    return "solo-\(key)-\(canonical)"
                }
                return "act-\(key)-\(canonical)"
            }()

            let shouldReplace: Bool
            if let existingStart = firstStartByOptionID[optionID] {
                shouldReplace = slot.startTime < existingStart
            } else {
                shouldReplace = true
            }

            if shouldReplace {
                firstStartByOptionID[optionID] = slot.startTime
                optionByOptionID[optionID] = EventCheckinDJOption(
                    id: optionID,
                    djID: optionID,
                    name: displayName,
                    avatarUrl: act.type == .solo ? act.performers.first?.avatarUrl : nil,
                    actType: act.type,
                    performers: act.performers
                )
            }
        }

        return optionByOptionID.values.sorted {
            let lhsDate = firstStartByOptionID[$0.djID] ?? .distantFuture
            let rhsDate = firstStartByOptionID[$1.djID] ?? .distantFuture
            return lhsDate < rhsDate
        }
    }

    private func submitEventCheckinSelections(selectedDJIDsByDayID: [String: Set<String>]) async {
        guard let event else { return }
        let selectedDays = eventCheckinDayOptions(for: event)
            .filter { selectedEventCheckinDayIDs.contains($0.id) }
            .sorted { $0.dayIndex < $1.dayIndex }

        guard !selectedDays.isEmpty else {
            errorMessage = L("请至少选择一个参加日", "Please select at least one attended day.")
            return
        }

        do {
            let payloads = selectedDays.map { day in
                makeAttendanceSelectionPayload(
                    for: event,
                    day: day,
                    selectedDJIDs: selectedDJIDsByDayID[day.id] ?? []
                )
            }
            guard let note = WebCheckin.makeEventAttendanceNote(selections: payloads) else {
                errorMessage = L("打卡信息生成失败，请重试", "Failed to generate check-in payload. Please try again.")
                return
            }
            let attendedAt = selectedDays.map(\.attendedAt).max() ?? Date()

            let primaryCheckin: WebCheckin
            if let activeAttendanceCheckin {
                primaryCheckin = try await eventsRepository.updateCheckin(
                    id: activeAttendanceCheckin.id,
                    input: UpdateCheckinInput(
                        eventId: eventID,
                        djId: nil,
                        note: note,
                        rating: nil,
                        attendedAt: attendedAt
                    )
                )
                errorMessage = L("打卡信息已更新", "Check-in updated.")
            } else {
                primaryCheckin = try await eventsRepository.createCheckin(
                    input: CreateCheckinInput(
                        type: "event",
                        eventId: eventID,
                        djId: nil,
                        note: note,
                        rating: nil,
                        attendedAt: attendedAt
                    )
                )
                errorMessage = L("活动打卡成功", "Event check-in successful.")
            }

            await cleanupLegacyEventCheckins(keeping: primaryCheckin.id)
            relatedEventCheckins = ([primaryCheckin] + relatedEventCheckins.filter { $0.id != primaryCheckin.id })
                .filter { $0.id == primaryCheckin.id || !shouldCleanupEventCheckin($0, keeping: primaryCheckin.id) }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func cancelEventCheckin() async {
        guard let activeAttendanceCheckin else { return }

        do {
            try await eventsRepository.deleteCheckin(id: activeAttendanceCheckin.id)
            await cleanupLegacyEventCheckins(keeping: nil)
            relatedEventCheckins.removeAll { checkin in
                checkin.id == activeAttendanceCheckin.id || shouldCleanupEventCheckin(checkin, keeping: nil)
            }
            selectedEventCheckinDayIDs = []
            selectedEventCheckinDJIDsByDayID = [:]
            errorMessage = L("已取消活动打卡", "Event check-in canceled.")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func preselectedDaySelections(for checkin: WebCheckin, in event: WebEvent) -> [EventAttendanceDaySelectionPayload] {
        let existingSelections = checkin.eventAttendanceSelections.sorted { $0.dayIndex < $1.dayIndex }
        if !existingSelections.isEmpty {
            return existingSelections
        }

        guard let selectedDayID = dayID(for: checkin.attendedAt, in: event),
              let selectedDay = eventCheckinDayOptions(for: event).first(where: { $0.id == selectedDayID }) else {
            return []
        }

        let calendar = Calendar.current
        let selectedDJIDs = Set<String>(
            legacyRelatedDJCheckins.compactMap { item in
                guard let djID = item.djId, !djID.isEmpty else { return nil }
                let itemDay = dayID(for: item.attendedAt, in: event)
                guard itemDay == selectedDayID || calendar.isDate(item.attendedAt, inSameDayAs: checkin.attendedAt) else {
                    return nil
                }
                return djID
            }
        )
        return [makeAttendanceSelectionPayload(for: event, day: selectedDay, selectedDJIDs: selectedDJIDs)]
    }

    private func dayID(for date: Date, in event: WebEvent) -> String? {
        let options = eventCheckinDayOptions(for: event)
        guard !options.isEmpty else { return nil }

        let targetDayIndex = EventLogicalDayResolver.dayIndex(
            for: date,
            eventStartDate: event.startDate,
            dayRolloverHour: event.dayRolloverHour
        )
        if let exact = options.first(where: { $0.dayIndex == targetDayIndex }) {
            return exact.id
        }
        return options.first { Calendar.current.isDate($0.dayDate, inSameDayAs: date) }?.id
    }

    private func makeAttendanceSelectionPayload(
        for event: WebEvent,
        day: EventCheckinDayOption,
        selectedDJIDs: Set<String>
    ) -> EventAttendanceDaySelectionPayload {
        let snapshots = eventCheckinDJOptions(for: event, selectedDayIDs: [day.id])
            .filter { selectedDJIDs.contains($0.djID) }
            .map {
                EventAttendanceDJSelection(
                    id: $0.djID,
                    name: $0.name,
                    avatarUrl: $0.avatarUrl,
                    country: nil
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return EventAttendanceDaySelectionPayload(
            dayID: day.id,
            dayIndex: day.dayIndex,
            djSelections: snapshots
        )
    }

    private func cleanupLegacyEventCheckins(keeping keptID: String?) async {
        let cleanupTargets = relatedEventCheckins.filter { shouldCleanupEventCheckin($0, keeping: keptID) }
        for item in cleanupTargets {
            try? await eventsRepository.deleteCheckin(id: item.id)
        }
    }

    private func shouldCleanupEventCheckin(_ checkin: WebCheckin, keeping keptID: String?) -> Bool {
        if let keptID, checkin.id == keptID {
            return false
        }
        if checkin.type == "dj" && checkin.eventId == eventID {
            return true
        }
        return checkin.isEventAttendanceCheckin
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
            try await eventsRepository.deleteEvent(id: eventID)
            errorMessage = L("活动已删除，请返回列表刷新", "Event deleted. Please return to the list and refresh.")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let activities: [UIActivity]? = nil
    let completion: UIActivityViewController.CompletionWithItemsHandler?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: activities)
        controller.completionWithItemsHandler = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum EventLogicalDayResolver {
    static func normalizeDayRolloverHour(_ raw: Int?) -> Int {
        guard let raw, (0...23).contains(raw) else { return 6 }
        return raw
    }

    static func dayDate(for dayIndex: Int, anchorDate: Date) -> Date {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        guard dayIndex > 1 else { return anchorDay }
        return calendar.date(byAdding: .day, value: dayIndex - 1, to: anchorDay) ?? anchorDay
    }

    static func dayIndex(
        for date: Date,
        eventStartDate: Date,
        dayRolloverHour: Int?
    ) -> Int {
        let calendar = Calendar.current
        let rolloverHour = normalizeDayRolloverHour(dayRolloverHour)
        let anchorDay = calendar.startOfDay(for: eventStartDate)
        let targetDay = calendar.startOfDay(for: date)
        var dayOffset = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day ?? 0
        if dayOffset > 0 && calendar.component(.hour, from: date) < rolloverHour {
            dayOffset -= 1
        }
        return max(1, dayOffset + 1)
    }

    static func dayIndex(
        for slot: WebEventLineupSlot,
        eventStartDate: Date,
        dayRolloverHour: Int?
    ) -> Int {
        if let explicitDayIndex = slot.festivalDayIndex, explicitDayIndex > 0 {
            return explicitDayIndex
        }
        return dayIndex(for: slot.startTime, eventStartDate: eventStartDate, dayRolloverHour: dayRolloverHour)
    }
}

private struct EventScheduleDay: Identifiable, Hashable {
    let id: String
    let index: Int
    let weekIndex: Int?
    let dayInWeek: Int?
    let date: Date
    let slots: [WebEventLineupSlot]

    var title: String {
        if let weekIndex, let dayInWeek {
            return EventWeekScheduleMode.weekDayTitle(week: weekIndex, day: dayInWeek)
        }
        return "Day\(index)"
    }

    var subtitle: String { "\(title) · \(date.appLocalizedYMDText())" }

    static func build(
        from slots: [WebEventLineupSlot],
        anchorDate: Date,
        useWeekMode: Bool,
        dayRolloverHour: Int? = nil
    ) -> [EventScheduleDay] {
        guard !slots.isEmpty else { return [] }

        var grouped: [Int: [WebEventLineupSlot]] = [:]
        for slot in slots {
            let dayIndex = EventLogicalDayResolver.dayIndex(
                for: slot,
                eventStartDate: anchorDate,
                dayRolloverHour: dayRolloverHour
            )
            grouped[dayIndex, default: []].append(slot)
        }

        return grouped
            .keys
            .sorted()
            .map { dayIndex in
                let dayDate = EventLogicalDayResolver.dayDate(for: dayIndex, anchorDate: anchorDate)
                let items = (grouped[dayIndex] ?? [])
                    .sorted {
                        if $0.startTime == $1.startTime {
                            return $0.sortOrder < $1.sortOrder
                        }
                        return $0.startTime < $1.startTime
                    }
                let weekDay = useWeekMode
                    ? EventWeekScheduleMode.weekDayIndex(for: dayDate, anchorDate: anchorDate)
                    : nil
                return EventScheduleDay(
                    id: Self.dayKey(for: dayDate),
                    index: dayIndex,
                    weekIndex: weekDay?.week,
                    dayInWeek: weekDay?.day,
                    date: dayDate,
                    slots: items
                )
            }
    }

    private static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

}

private struct EventTimelineCardFrame: Identifiable {
    let id: String
    let slot: WebEventLineupSlot
    let top: CGFloat
    let height: CGFloat
}

private enum EventScheduleTypography {
    static func heavy(_ size: CGFloat) -> Font {
        font(primary: "AvenirNext-Bold", fallbackWeight: .bold, size: size)
    }

    static func semibold(_ size: CGFloat) -> Font {
        font(primary: "AvenirNext-DemiBold", fallbackWeight: .semibold, size: size)
    }

    static func medium(_ size: CGFloat) -> Font {
        font(primary: "AvenirNext-Medium", fallbackWeight: .medium, size: size)
    }

    private static func font(primary: String, fallbackWeight: Font.Weight, size: CGFloat) -> Font {
        if UIFont(name: primary, size: size) != nil {
            return .custom(primary, size: size)
        }
        return .system(size: size, weight: fallbackWeight, design: .rounded)
    }
}

private struct EventTimelineLayout {
    static let axisWidth: CGFloat = 54
    static let stageHeaderHeight: CGFloat = 74
    static let stageGap: CGFloat = 4
    static let timelineTopInset: CGFloat = 50
    static let timelineBottomInset: CGFloat = 40
    static let maxVisibleStageCount = 5
    static let minStageWidth: CGFloat = 92
    static let pixelsPerHour: CGFloat = 75

    let stageNames: [String]
    let slotsByStage: [String: [WebEventLineupSlot]]
    let stageColorByName: [String: Color]
    let stageWidth: CGFloat
    let stageViewportWidth: CGFloat
    let stageContentWidth: CGFloat
    let requiresHorizontalScroll: Bool
    let rangeStart: Date
    let rangeEnd: Date
    let timelineSpanHeight: CGFloat
    let bodyHeight: CGFloat
    let tickDates: [Date]

    init(
        slots: [WebEventLineupSlot],
        availableWidth: CGFloat,
        maxVisibleStages: Int = Self.maxVisibleStageCount
    ) {
        let normalizedSlots = slots.sorted {
            if $0.startTime == $1.startTime {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.startTime < $1.startTime
        }
        let grouped = Dictionary(grouping: normalizedSlots) { slot in
            let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "MAIN STAGE" : trimmed
        }
        let slotsOrderedBySort = normalizedSlots.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.startTime < $1.startTime
            }
            return $0.sortOrder < $1.sortOrder
        }
        var orderedStages: [String] = []
        var seenStages = Set<String>()
        for slot in slotsOrderedBySort {
            let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stage = trimmed.isEmpty ? "MAIN STAGE" : trimmed
            if seenStages.insert(stage).inserted {
                orderedStages.append(stage)
            }
        }
        for stage in grouped.keys where !seenStages.contains(stage) {
            orderedStages.append(stage)
        }

        var colorMap: [String: Color] = [:]
        for (idx, stage) in orderedStages.enumerated() {
            colorMap[stage] = Self.palette[idx % Self.palette.count]
        }

        let bounds = Self.timeBounds(for: normalizedSlots)
        rangeStart = bounds.start
        rangeEnd = bounds.end
        let totalHours = max(bounds.end.timeIntervalSince(bounds.start) / 3600, 1)
        timelineSpanHeight = max(760, CGFloat(totalHours) * Self.pixelsPerHour)
        bodyHeight = Self.timelineTopInset + timelineSpanHeight + Self.timelineBottomInset
        tickDates = Self.hourTicks(from: bounds.start, to: bounds.end)

        let stageCount = max(1, orderedStages.count)
        let stageViewport = max(availableWidth - Self.axisWidth, Self.minStageWidth)
        let resolvedVisibleCap = max(1, maxVisibleStages)
        let visibleCount = min(resolvedVisibleCap, stageCount)
        let visibleGapTotal = CGFloat(max(visibleCount - 1, 0)) * Self.stageGap
        let computedStageWidth = max((stageViewport - visibleGapTotal) / CGFloat(visibleCount), Self.minStageWidth)
        stageWidth = computedStageWidth
        stageViewportWidth = stageViewport
        stageContentWidth = CGFloat(stageCount) * computedStageWidth + CGFloat(max(stageCount - 1, 0)) * Self.stageGap
        requiresHorizontalScroll = stageCount > visibleCount

        stageNames = orderedStages
        slotsByStage = grouped
        stageColorByName = colorMap
    }

    func yPosition(for date: Date) -> CGFloat {
        let total = max(rangeEnd.timeIntervalSince(rangeStart), 1)
        let clamped = min(max(date.timeIntervalSince(rangeStart), 0), total)
        let progress = clamped / total
        return Self.timelineTopInset + CGFloat(progress) * timelineSpanHeight
    }

    func color(for stageName: String) -> Color {
        stageColorByName[stageName] ?? Self.palette[0]
    }

    static func estimatedHeight(for slots: [WebEventLineupSlot]) -> CGFloat {
        let bounds = timeBounds(for: slots)
        let totalHours = max(bounds.end.timeIntervalSince(bounds.start) / 3600, 1)
        let span = max(760, CGFloat(totalHours) * pixelsPerHour)
        return stageHeaderHeight + timelineTopInset + span + timelineBottomInset
    }

    static func stageCount(for slots: [WebEventLineupSlot]) -> Int {
        let names = Set(slots.map { slot -> String in
            let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "MAIN STAGE" : trimmed
        })
        return max(1, names.count)
    }

    private static func timeBounds(for slots: [WebEventLineupSlot]) -> (start: Date, end: Date) {
        let reference = slots.map(\.startTime).min() ?? Date()
        let earliest = slots.map(\.startTime).min() ?? reference
        let latest = slots.map(\.endTime).max() ?? earliest.addingTimeInterval(3600)
        let roundedStart = floorToHour(earliest)
        var roundedEnd = ceilToHour(latest)
        if roundedEnd <= roundedStart {
            roundedEnd = roundedStart.addingTimeInterval(3600)
        }
        return (roundedStart, roundedEnd)
    }

    private static func hourTicks(from start: Date, to end: Date) -> [Date] {
        var result: [Date] = []
        var cursor = start
        while cursor <= end {
            result.append(cursor)
            guard let next = Calendar.current.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }
        if result.isEmpty {
            result = [start, end]
        }
        return result
    }

    private static func floorToHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: parts) ?? date
    }

    private static func ceilToHour(_ date: Date) -> Date {
        let start = floorToHour(date)
        if start == date { return start }
        return Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? date
    }

    private static let palette: [Color] = [
        Color(red: 0.97, green: 0.54, blue: 0.89),
        Color(red: 0.50, green: 0.87, blue: 0.98),
        Color(red: 0.54, green: 0.95, blue: 0.62),
        Color(red: 0.99, green: 0.73, blue: 0.42),
        Color(red: 0.90, green: 0.96, blue: 0.50),
        Color(red: 0.56, green: 0.67, blue: 0.99),
        Color(red: 0.98, green: 0.57, blue: 0.63),
        Color(red: 0.93, green: 0.56, blue: 0.79),
        Color(red: 0.56, green: 0.86, blue: 0.94)
    ]
}

private struct EventTimelineBoardView: View {
    let event: WebEvent
    let day: EventScheduleDay
    let selectedSlotIDs: Set<String>
    let selectable: Bool
    let onToggleSlot: ((WebEventLineupSlot) -> Void)?
    var maxVisibleStages: Int = EventTimelineLayout.maxVisibleStageCount

    private var boardHeight: CGFloat {
        EventTimelineLayout.estimatedHeight(for: day.slots)
    }

    var body: some View {
        GeometryReader { geo in
            let layout = EventTimelineLayout(
                slots: day.slots,
                availableWidth: max(geo.size.width, EventTimelineLayout.axisWidth + EventTimelineLayout.minStageWidth),
                maxVisibleStages: maxVisibleStages
            )

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.09, green: 0.10, blue: 0.14),
                                Color(red: 0.06, green: 0.06, blue: 0.09)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                HStack(spacing: 0) {
                    timelineAxis(layout: layout)
                    stageMatrix(layout: layout)
                }
                .padding(.vertical, 10)
            }
        }
        .frame(height: boardHeight)
    }

    @ViewBuilder
    private func stageMatrix(layout: EventTimelineLayout) -> some View {
        let stageContent = VStack(spacing: 0) {
            stageHeaderRow(layout: layout)
            stageColumnsRow(layout: layout)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            stageContent
                .frame(width: layout.stageContentWidth, alignment: .leading)
        }
        .frame(width: layout.stageViewportWidth, alignment: .leading)
    }

    private func timelineAxis(layout: EventTimelineLayout) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(width: EventTimelineLayout.axisWidth, height: EventTimelineLayout.stageHeaderHeight)

            ZStack(alignment: .topTrailing) {
                ForEach(layout.tickDates, id: \.timeIntervalSinceReferenceDate) { tick in
                    Text(Self.axisTimeFormatter.string(from: tick))
                        .font(EventScheduleTypography.semibold(15))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .frame(width: EventTimelineLayout.axisWidth - 8, alignment: .trailing)
                        .offset(y: layout.yPosition(for: tick) - 12)
                }
            }
            .frame(width: EventTimelineLayout.axisWidth, height: layout.bodyHeight, alignment: .topTrailing)
        }
        .frame(width: EventTimelineLayout.axisWidth)
    }

    private func stageHeaderRow(layout: EventTimelineLayout) -> some View {
        HStack(spacing: EventTimelineLayout.stageGap) {
            ForEach(layout.stageNames, id: \.self) { stageName in
                let stageColor = layout.color(for: stageName)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                stageColor.opacity(0.98),
                                stageColor.opacity(0.78),
                                stageColor.opacity(0.56)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(0.36), lineWidth: 1)
                    )
                    .overlay(
                        Text(stageName)
                            .font(EventScheduleTypography.heavy(26))
                            .minimumScaleFactor(0.24)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.black.opacity(0.72))
                            .padding(.horizontal, 4)
                    )
                    .frame(width: layout.stageWidth, height: EventTimelineLayout.stageHeaderHeight)
            }
        }
    }

    private func stageColumnsRow(layout: EventTimelineLayout) -> some View {
        HStack(spacing: EventTimelineLayout.stageGap) {
            ForEach(layout.stageNames, id: \.self) { stageName in
                stageColumn(stageName: stageName, layout: layout)
            }
        }
        .frame(height: layout.bodyHeight)
    }

    private func stageColumn(stageName: String, layout: EventTimelineLayout) -> some View {
        let stageColor = layout.color(for: stageName)
        let frames = cardFrames(for: stageName, layout: layout)

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))

            ForEach(layout.tickDates, id: \.timeIntervalSinceReferenceDate) { tick in
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                    .offset(y: layout.yPosition(for: tick))
            }

            ForEach(frames) { frame in
                timelineCard(frame: frame, stageColor: stageColor)
                    .frame(width: layout.stageWidth, height: frame.height, alignment: .top)
                    .offset(y: frame.top)
            }
        }
        .frame(width: layout.stageWidth, height: layout.bodyHeight)
    }

    private func timelineCard(frame: EventTimelineCardFrame, stageColor: Color) -> some View {
        let isSelected = selectedSlotIDs.contains(frame.slot.id)
        let displayAct = EventLineupActCodec.parse(slot: frame.slot)
        let cardFill = isSelected ? Color.black.opacity(0.88) : stageColor.opacity(0.92)
        let textColor = isSelected ? stageColor : Color.black.opacity(0.84)
        let nameTimeSpacing: CGFloat = 1

        let content = RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isSelected ? stageColor.opacity(0.95) : Color.black.opacity(0.42),
                        lineWidth: isSelected ? 2.0 : 1.1
                    )
            )
            .shadow(color: stageColor.opacity(isSelected ? 0.58 : 0.30), radius: isSelected ? 12 : 8, x: 0, y: 2)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: nameTimeSpacing) {
                    Text(displayAct.displayName)
                        .font(EventScheduleTypography.heavy(28))
                        .minimumScaleFactor(0.21)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(Self.cardStartTimeText(for: frame.slot))
                        .font(EventScheduleTypography.semibold(12))
                        .monospacedDigit()
                        .foregroundStyle(textColor.opacity(0.95))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.top, 7)
                .padding(.bottom, 6)
            }

        return Group {
            if selectable, let onToggleSlot {
                Button {
                    onToggleSlot(frame.slot)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private func cardFrames(for stageName: String, layout: EventTimelineLayout) -> [EventTimelineCardFrame] {
        let stageSlots = (layout.slotsByStage[stageName] ?? []).sorted {
            if $0.startTime == $1.startTime {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.startTime < $1.startTime
        }

        var result: [EventTimelineCardFrame] = []

        for slot in stageSlots {
            let startY = layout.yPosition(for: slot.startTime)
            let endY = layout.yPosition(for: slot.endTime)
            let resolvedHeight = max(44, endY - startY)
            let frame = EventTimelineCardFrame(
                id: slot.id,
                slot: slot,
                top: startY,
                height: resolvedHeight
            )
            result.append(frame)
        }

        return result
    }

    private static func cardStartTimeText(for slot: WebEventLineupSlot) -> String {
        cardTimeFormatter.string(from: slot.startTime)
    }

    private static let axisTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "h a"
        return formatter
    }()

    private static let cardTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "h:mma"
        return formatter
    }()
}

private struct EventRouteSharePosterView: View {
    let event: WebEvent
    let day: EventScheduleDay
    let selectedSlotIDs: Set<String>
    let username: String
    let coverImage: UIImage?

    var body: some View {
        ZStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.70))
                    .blur(radius: 12)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.14),
                        Color(red: 0.11, green: 0.05, blue: 0.20),
                        Color(red: 0.04, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(L("\(username)的\(event.name)电音节行程", "\(username)'s \(event.name) festival route"))
                    .font(EventScheduleTypography.heavy(42))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(day.subtitle)
                    .font(EventScheduleTypography.semibold(26))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.14)))

                EventTimelineBoardView(
                    event: event,
                    day: day,
                    selectedSlotIDs: selectedSlotIDs,
                    selectable: false,
                    onToggleSlot: nil,
                    maxVisibleStages: Int.max
                )
                .frame(height: EventTimelineLayout.estimatedHeight(for: day.slots))

                HStack {
                    Spacer()
                    Text("RaveHub")
                        .font(EventScheduleTypography.heavy(26))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.42))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 40)
            .padding(.bottom, 28)
        }
    }
}

private struct EventRoutePlannerView: View {
    let event: WebEvent
    let days: [EventScheduleDay]
    let initialDayID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var selectedDayID: String
    @State private var selectedSlotIDs: Set<String> = []
    @State private var isGeneratingShare = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var feedbackMessage: String?
    @State private var coverImage: UIImage?

    init(event: WebEvent, days: [EventScheduleDay], initialDayID: String) {
        self.event = event
        self.days = days
        self.initialDayID = initialDayID
        _selectedDayID = State(initialValue: initialDayID)
    }

    private var selectedDay: EventScheduleDay? {
        days.first(where: { $0.id == selectedDayID }) ?? days.first
    }

    private var displayNameForShare: String {
        let trimmed = appState.session?.user.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return appState.session?.user.username ?? "Raver"
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.11),
                        Color(red: 0.03, green: 0.03, blue: 0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if days.count > 1 {
                            daySelector
                        }

                        if let selectedDay {
                            EventTimelineBoardView(
                                event: event,
                                day: selectedDay,
                                selectedSlotIDs: selectedSlotIDs,
                                selectable: true,
                                onToggleSlot: { slot in
                                    if selectedSlotIDs.contains(slot.id) {
                                        selectedSlotIDs.remove(slot.id)
                                    } else {
                                        selectedSlotIDs.insert(slot.id)
                                    }
                                }
                            )
                            .frame(height: EventTimelineLayout.estimatedHeight(for: selectedDay.slots))
                        } else {
                            ContentUnavailableView(LL("等待时间表发布"), systemImage: "calendar.badge.exclamationmark")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .raverSystemNavigation(title: LL("定制路线"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await exportSharePoster() }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isGeneratingShare)
                    .opacity(isGeneratingShare ? 0.6 : 1)
                }
            }
            .onAppear {
                if selectedDayID.isEmpty {
                    selectedDayID = days.first?.id ?? ""
                }
            }
            .task {
                await loadCoverImageIfNeeded()
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ActivityShareSheet(items: [shareImage], completion: nil)
                }
            }
            .alert(L("提示", "Notice"), isPresented: Binding(
                get: { feedbackMessage != nil },
                set: { if !$0 { feedbackMessage = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(feedbackMessage ?? "")
            }
        }
    }

    private var daySelector: some View {
        //HorizontalAxisLockedScrollView(showsIndicators: false) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    let selected = day.id == selectedDayID
                    Button {
                        selectedDayID = day.id
                    } label: {
                        Text(day.subtitle)
                            .font(EventScheduleTypography.semibold(15))
                            .foregroundStyle(selected ? Color.black.opacity(0.85) : Color.white.opacity(0.88))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected ? Color.white.opacity(0.92) : Color.white.opacity(0.13))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @MainActor
    private func exportSharePoster() async {
        guard !isGeneratingShare else { return }
        guard let selectedDay else {
            feedbackMessage = L("暂无可分享的时间表", "No timetable available to share.")
            return
        }

        isGeneratingShare = true
        defer { isGeneratingShare = false }

        let stageCount = EventTimelineLayout.stageCount(for: selectedDay.slots)
        let stageRegionWidth =
            CGFloat(stageCount) * EventTimelineLayout.minStageWidth +
            CGFloat(max(stageCount - 1, 0)) * EventTimelineLayout.stageGap
        let boardWidth = EventTimelineLayout.axisWidth + stageRegionWidth
        let horizontalPadding: CGFloat = 72
        let posterWidth = max(1080, boardWidth + horizontalPadding)
        let boardHeight = EventTimelineLayout.estimatedHeight(for: selectedDay.slots)
        let posterHeight = max(1920, boardHeight + 280)

        let poster = EventRouteSharePosterView(
            event: event,
            day: selectedDay,
            selectedSlotIDs: selectedSlotIDs,
            username: displayNameForShare,
            coverImage: coverImage
        )
        .frame(width: posterWidth, height: posterHeight)

        let renderer = ImageRenderer(content: poster)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else {
            feedbackMessage = L("行程图生成失败，请重试", "Failed to generate route image. Please try again.")
            return
        }

        shareImage = image
        showShareSheet = true
        await savePosterToPhotos(image)
    }

    @MainActor
    private func savePosterToPhotos(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            feedbackMessage = L("未获得相册权限，可先通过分享面板手动保存", "Photo permission denied. You can save manually from the share panel.")
            return
        }

        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        feedbackMessage = L("已保存到相册", "Saved to Photos.")
                    } else if let error {
                        feedbackMessage = L("保存失败：\(error.userFacingMessage ?? "")", "Save failed: \(error.userFacingMessage ?? "")")
                    } else {
                        feedbackMessage = L("保存失败，请重试", "Save failed. Please try again.")
                    }
                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    private func loadCoverImageIfNeeded() async {
        guard coverImage == nil,
              let urlString = AppConfig.resolvedURLString(event.coverImageUrl),
              let url = URL(string: urlString) else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                coverImage = image
            }
        } catch {
            // Keep gradient fallback for poster background.
        }
    }
}

private struct EventRoutineView: View {
    enum PresentationStyle {
        case pushed
        case embedded
    }

    let event: WebEvent
    let scheduledSlots: [WebEventLineupSlot]
    var presentationStyle: PresentationStyle = .pushed

    @State private var selectedDayID: String = ""
    @State private var showRoutePlanner = false

    private var isEmbedded: Bool {
        presentationStyle == .embedded
    }

    private var days: [EventScheduleDay] {
        EventScheduleDay.build(
            from: scheduledSlots,
            anchorDate: event.startDate,
            useWeekMode: EventWeekScheduleMode.isEnabled(in: event.description),
            dayRolloverHour: event.dayRolloverHour
        )
    }

    private var selectedDay: EventScheduleDay? {
        days.first(where: { $0.id == selectedDayID }) ?? days.first
    }

    var body: some View {
        Group {
            if days.isEmpty {
                ContentUnavailableView(LL("等待时间表发布"), systemImage: "calendar.badge.exclamationmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else if isEmbedded {
                embeddedContent
            } else {
                standaloneContent
            }
        }
        .onAppear {
            if selectedDayID.isEmpty {
                selectedDayID = days.first?.id ?? ""
            }
        }
        .navigationDestination(isPresented: $showRoutePlanner) {
            EventRoutePlannerView(
                event: event,
                days: days,
                initialDayID: selectedDayID
            )
        }
    }

    private var embeddedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button(LL("定制路线")) {
                    showRoutePlanner = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.accent)
            }

            if days.count > 1 {
                daySelector
            }

            timelineBoard
        }
    }

    private var standaloneContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if days.count > 1 {
                    daySelector
                }

                timelineBoard
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.11),
                    RaverTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .raverSystemNavigation(title: L("活动日程", "Event Schedule"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("定制路线", "Custom Route")) {
                    showRoutePlanner = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.accent)
            }
        }
    }

    @ViewBuilder
    private var timelineBoard: some View {
        if let selectedDay {
            EventTimelineBoardView(
                event: event,
                day: selectedDay,
                selectedSlotIDs: [],
                selectable: false,
                onToggleSlot: nil
            )
            .frame(height: EventTimelineLayout.estimatedHeight(for: selectedDay.slots))
        } else {
            ContentUnavailableView(LL("等待时间表发布"), systemImage: "calendar.badge.exclamationmark")
        }
    }

    private var daySelector: some View {
        //HorizontalAxisLockedScrollView(showsIndicators: false) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    let selected = day.id == selectedDayID
                    Button {
                        selectedDayID = day.id
                    } label: {
                        Text(day.subtitle)
                            .font(EventScheduleTypography.semibold(15))
                            .foregroundStyle(selected ? Color.black.opacity(0.85) : Color.white.opacity(0.88))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected ? Color.white.opacity(0.92) : Color.white.opacity(0.13))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
