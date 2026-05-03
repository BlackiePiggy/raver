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
import SDWebImageSwiftUI
import SDWebImage

private struct EventDetailTabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [EventDetailView.EventDetailTab: CGRect] = [:]

    static func reduce(value: inout [EventDetailView.EventDetailTab: CGRect], nextValue: () -> [EventDetailView.EventDetailTab: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct EventCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: EventShareCardPayload
}

private struct EventSharePreviewCard: View {
    let payload: EventShareCardPayload

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewImage
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if let badge = payload.badgeText?.nilIfBlank {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.eventName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if let venue = payload.venueName?.nilIfBlank {
                    Text(venue)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var previewImage: some View {
        if let raw = payload.coverImageURL,
           let url = URL(string: raw),
           !raw.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        LinearGradient(
            colors: [RaverTheme.accent.opacity(0.95), Color(red: 0.19, green: 0.18, blue: 0.26)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "ticket.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
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

    private enum LineupSortMode: String {
        case alphabetical
        case popularity

        var toggleTitle: String {
            switch self {
            case .alphabetical:
                return L("按热度", "By popularity")
            case .popularity:
                return L("按字母", "A-Z")
            }
        }

        var activeTitle: String {
            switch self {
            case .alphabetical:
                return "A-Z"
            case .popularity:
                return L("热度", "Hot")
            }
        }

        var iconName: String {
            switch self {
            case .alphabetical:
                return "chart.line.uptrend.xyaxis"
            case .popularity:
                return "arrow.up.arrow.down"
            }
        }
    }

    @State private var event: WebEvent?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var showEventCheckinSheet = false
    @State private var selectedEventCheckinDayIDs: Set<String> = []
    @State private var selectedEventCheckinDJIDsByDayID: [String: Set<String>] = [:]
    @State private var relatedEventCheckins: [WebCheckin] = []
    @State private var bannerMessage: String?
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
    @State private var lineupSortMode: LineupSortMode = .alphabetical
    @State private var expandedLineupPage = 0
    @State private var venueMapContext: EventVenueMapContext?
    @State private var selectedLineupMedia: FullscreenMediaSelection?
    @State private var isCachingManualSnapshot = false
    @State private var manualCachedAt: Date?
    @State private var widgetStatusMessage: String?
    @State private var widgetStatusConversation: Conversation?
    @State private var widgetStatusDismissToken = UUID()
    @State private var bannerDismissToken = UUID()
    @State private var isInWidgetCountdownPool = false
    @State private var shareMorePresentation: EventCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: EventCardSharePresentation?

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

    init(eventID: String, initialTabRawValue: String? = nil) {
        self.eventID = eventID
        let initialTab = initialTabRawValue.flatMap(EventDetailTab.init(rawValue:)) ?? .info
        _selectedTab = State(initialValue: initialTab)
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
            .raverEnableCustomSwipeBack(edgeRatio: 0.2)
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
            switch phase {
            case .idle, .initialLoading:
                EventDetailSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(message: message) {
                        Task { await load() }
                    }
                }
                .padding(16)
                .padding(.top, 96)
            case .empty:
                ContentUnavailableView(LL("活动不存在"), systemImage: "calendar.badge.exclamationmark")
            case .success:
                if let event {
                    ZStack(alignment: .top) {
                        GeometryReader { proxy in
                            let cardWidth = max(proxy.size.width - 32, 0)
                            RaverImmersiveDetailPagerChrome(
                                title: event.name,
                                tabs: EventDetailTab.allCases,
                                selectedTab: selectedTab,
                                pageProgress: $pageProgress,
                                namespace: "event-detail",
                                configuration: detailChromeConfiguration
                            ) {
                                heroSection(event)
                            } tabBar: {
                                tabBar
                            } content: { chrome in
                                tabPager(event: event, cardWidth: cardWidth, chrome: chrome)
                            }
                        }

                        if isRefreshing || bannerMessage != nil || widgetStatusMessage != nil {
                            VStack(alignment: .leading, spacing: 10) {
                                if isRefreshing {
                                    InlineLoadingBadge(title: L("正在更新活动详情", "Updating event details"))
                                }
                                if let widgetStatusMessage {
                                    ScreenStatusBanner(
                                        message: widgetStatusMessage,
                                        style: .info,
                                        actionTitle: widgetStatusConversation == nil ? nil : L("点击跳转", "Open chat")
                                    ) {
                                        if let widgetStatusConversation {
                                            appPush(.conversation(target: .fromConversation(widgetStatusConversation)))
                                        }
                                    }
                                    .transition(.opacity)
                                }
                                if let bannerMessage {
                                    ScreenStatusBanner(
                                        message: bannerMessage,
                                        style: .error,
                                        actionTitle: L("重试", "Retry")
                                    ) {
                                        Task { await load() }
                                    }
                                    .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 100)
                            .animation(.easeOut(duration: 0.25), value: widgetStatusMessage != nil)
                            .animation(.easeOut(duration: 0.25), value: bannerMessage != nil)
                        }
                    }
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
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try await sendSharePayload(
                        presentation.payload,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                showWidgetStatusBanner(
                    message: L(
                    "已分享到 \(conversation.title)",
                    "Shared to \(conversation.title)"
                    ),
                    conversation: conversation
                )
            } preview: {
                EventSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .task {
            await refreshManualCacheState()
            await refreshWidgetCountdownState()
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
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(for: event),
                        loadConversations: {
                            try await loadSharePanelConversations()
                        },
                        onSendToConversation: { conversation, note in
                            try await sendSharePayload(
                                presentation.payload,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        showWidgetStatusBanner(
                            message: L(
                            "已分享到 \(conversation.title)",
                            "Shared to \(conversation.title)"
                            ),
                            conversation: conversation
                        )
                    } onMoreChats: {
                        dismissShareMorePanel {
                            fullChatSharePresentation = presentation
                        }
                    }
                }
                .onAppear {
                    withAnimation(.sharePanelPresentSpring) {
                        isShareMorePanelVisible = true
                    }
                }
            }
        }
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
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
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                    selectedTab = tab
                }
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
    private func tabPager(
        event: WebEvent,
        cardWidth: CGFloat,
        chrome: RaverImmersiveDetailPagerContext<EventDetailTab>
    ) -> some View {
        RaverScrollableTabPager(
            items: eventDetailTabItems,
            selection: $selectedTab,
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            showsTabBar: false,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 17, weight: .regular),
            progress: $pageProgress
        ) { tab in
            eventTabPage(event, cardWidth: cardWidth, tab: tab, chrome: chrome)
                .background(RaverTheme.background)
        }
    }

    @ViewBuilder
    private func eventTabPage(
        _ event: WebEvent,
        cardWidth: CGFloat,
        tab: EventDetailTab,
        chrome: RaverImmersiveDetailPagerContext<EventDetailTab>
    ) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                RaverImmersiveDetailOffsetMarker(
                    tabID: tab,
                    coordinateSpaceName: chrome.coordinateSpaceName(tab)
                )
                Color.clear
                    .frame(height: chrome.detailTopInset)

                VStack(alignment: .leading, spacing: 14) {
                    eventTabContent(event, cardWidth: cardWidth, tab: tab)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .coordinateSpace(name: chrome.coordinateSpaceName(tab))
        .scrollBounceBehavior(.always)
        .contentShape(Rectangle())
    }

    private var detailChromeConfiguration: RaverImmersiveDetailPagerConfiguration {
        RaverImmersiveDetailPagerConfiguration(
            heroHeight: 360,
            tabBarOverlayHeight: 52,
            pinnedTopBarHeight: 44,
            titleRevealLead: 8,
            titleRevealDistance: 20,
            backgroundColor: RaverTheme.background
        )
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
        let unifiedAddress = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)

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
                if !unifiedAddress.isEmpty {
                    eventInfoRow(icon: "mappin.and.ellipse", title: L("活动地址", "Address"), value: unifiedAddress)
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
        let lineupImageWidth = cardWidth + 2
        let lineupImageCornerRadius: CGFloat = 8
        let lineupPreviewItems: [FullscreenMediaItem] = allLineupMediaURLs.enumerated().map { index, raw in
            FullscreenMediaItem(rawURL: raw.trimmingCharacters(in: .whitespacesAndNewlines), index: index)
        }
        let hasLineupDJs = !lineupDJEntries(for: event, sortMode: lineupSortMode).isEmpty

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

                    if let resolved = AppConfig.resolvedURLString(rawURL),
                       let url = URL(string: resolved) {
                        Button {
                            selectedLineupMedia = FullscreenMediaSelection(id: index)
                        } label: {
                            WebImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: lineupImageWidth)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: lineupImageCornerRadius, style: .continuous)
                                    .fill(RaverTheme.card)
                                    .frame(width: lineupImageWidth, height: lineupImageWidth * 0.75)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                            .clipShape(
                                RoundedRectangle(cornerRadius: lineupImageCornerRadius, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, -1)
                    } else {
                        RoundedRectangle(cornerRadius: lineupImageCornerRadius, style: .continuous)
                            .fill(RaverTheme.card)
                            .frame(width: lineupImageWidth)
                            .frame(minHeight: 180)
                            .padding(.horizontal, -1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func eventBoundLocationPoint(_ event: WebEvent) -> WebEventLocationPoint? {
        guard let point = event.locationPoint,
              let location = point.location,
              location.lat.isFinite,
              location.lng.isFinite else {
            return nil
        }
        return point
    }

    private func localizedPointText(_ value: WebBiText?) -> String {
        let language = AppLanguagePreference.current.effectiveLanguage
        let localized = value?.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !localized.isEmpty { return localized }
        let zh = value?.zh.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !zh.isEmpty { return zh }
        let en = value?.en.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return en
    }

    private func hasEventVenueContent(_ event: WebEvent) -> Bool {
        return eventBoundLocationPoint(event) != nil
    }

    private func eventVenueDisplayText(_ event: WebEvent) -> String {
        guard let point = eventBoundLocationPoint(event) else {
            return L("未填写场地信息", "Venue not provided")
        }
        let formatted = localizedPointText(point.formattedAddressI18n).trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.isEmpty { return formatted }
        let unified = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !unified.isEmpty { return unified }
        return L("未填写场地信息", "Venue not provided")
    }

    private func eventMapURL(for event: WebEvent) -> URL? {
        guard let coordinate = eventVenueCoordinate(event) else { return nil }
        let queryText = eventVenueDisplayText(event)
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: queryText)
        ]
        return components?.url
    }

    private func makeEventShareCardPayload(from event: WebEvent) -> EventShareCardPayload {
        let eventType = EventTypeOption.displayText(for: event.eventType, fallbackWhenEmpty: false)
        let badgeText = eventType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? L("活动", "Event")
            : eventType
        let cityText = localizedPointText(event.cityI18n).nilIfBlank ?? event.city?.nilIfBlank
        let venueText = hasEventVenueContent(event) ? eventVenueDisplayText(event).nilIfBlank : nil
        let coverURL = AppConfig.resolvedURLString(event.coverAssetURL)

        return EventShareCardPayload(
            eventID: event.id,
            eventName: event.name,
            venueName: venueText,
            city: cityText,
            startAtISO8601: Self.eventCardISO8601Formatter.string(from: event.startDate),
            coverImageURL: coverURL,
            badgeText: badgeText
        )
    }

    private static let eventCardISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func eventVenueCoordinate(_ event: WebEvent) -> CLLocationCoordinate2D? {
        guard let point = eventBoundLocationPoint(event),
              let location = point.location else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
    }

    private func copyEventVenueText(_ event: WebEvent) {
        UIPasteboard.general.string = eventVenueDisplayText(event)
        errorMessage = L("场地信息已复制", "Venue information copied.")
    }

    private func openEventVenueInMap(_ event: WebEvent) {
        let venueText = eventVenueDisplayText(event)
        let fallbackQuery = eventVenueFallbackQuery(event)
        let coordinate = eventVenueCoordinate(event)
        guard coordinate != nil || !fallbackQuery.isEmpty else {
            errorMessage = L("暂无场地定位信息", "No venue location information available.")
            return
        }

        venueMapContext = EventVenueMapContext(
            eventName: event.name,
            venueDisplayText: venueText,
            summaryLocation: venueText,
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
                .allowsHitTesting(false)

                HStack(spacing: 6) {
                    Image(systemName: "location.viewfinder")
                    Text(LL("查看地图"))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .padding(10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 146)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 2)
    }

    private func eventVenueFallbackQuery(_ event: WebEvent) -> String {
        let text = eventVenueDisplayText(event).trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        guard let point = eventBoundLocationPoint(event) else { return "" }
        let fallback = [
            localizedPointText(point.nameI18n),
            localizedPointText(point.addressI18n),
            (point.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return fallback
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
        guard event != nil else { return nil }
        return AnyView(
            Button {
                if let event {
                    shareMorePresentation = EventCardSharePresentation(
                        payload: makeEventShareCardPayload(from: event)
                    )
                    isShareMorePanelVisible = false
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        )
    }

    private func dismissShareMorePanel(after: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            after?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        widgetStatusConversation = conversation
        widgetStatusMessage = message
        let token = UUID()
        widgetStatusDismissToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard widgetStatusDismissToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                widgetStatusMessage = nil
                widgetStatusConversation = nil
            }
        }
    }

    private func showBannerMessageAutoDismiss(_ message: String) {
        bannerMessage = message
        let token = UUID()
        bannerDismissToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard bannerDismissToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                bannerMessage = nil
            }
        }
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = appContainer.socialService.fetchConversations(type: .direct)
        async let groups = appContainer.socialService.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendSharePayload(
        _ payload: EventShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.socialService.sendEventCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await appContainer.socialService.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                errorMessage = L("微信分享接口待接入。", "WeChat share hook is not connected yet.")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                errorMessage = L("QQ 分享接口待接入。", "QQ share hook is not connected yet.")
            }
        ]
    }

    private func shareMoreQuickActions(for event: WebEvent?) -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = []

        if let event, isMine(event) {
            actions.append(
                SharePanelQuickAction(
                    title: L("编辑", "Edit"),
                    systemImage: "square.and.pencil",
                    accentColor: Color(red: 0.99, green: 0.65, blue: 0.20)
                ) {
                    discoverPush(.eventEdit(eventID: event.id))
                }
            )
        }

        actions.append(
            SharePanelQuickAction(
                title: isCachingManualSnapshot ? L("缓存中", "Caching") : L("缓存", "Cache"),
                systemImage: "arrow.down.circle",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                Task { await cacheEventManually() }
            }
        )

        if let event {
            actions.append(
                SharePanelQuickAction(
                    title: isInWidgetCountdownPool ? L("移出倒计时", "Remove Countdown") : L("桌面倒计时", "Widget Countdown"),
                    systemImage: isInWidgetCountdownPool ? "minus.circle" : "apps.iphone",
                    accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
                ) {
                    Task { await toggleSelectedEventInWidgetPool(event) }
                }
            )
        }

        actions.append(
            SharePanelQuickAction(
                title: L("贡献信息", "Incorrect Info"),
                systemImage: "info.circle",
                accentColor: Color(red: 0.96, green: 0.47, blue: 0.26)
            ) {
                openEventFeedbackEntry()
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: L("举报", "Report"),
                systemImage: "flag",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                openEventReportEntry()
            }
        )

        return actions
    }

    private func openEventFeedbackEntry() {
        // TODO: Wire to dedicated feedback route/page when available.
        errorMessage = L("贡献信息入口即将开放，当前已记录该需求。", "Incorrect info entry is coming soon. We have recorded this request.")
    }

    @MainActor
    private func toggleSelectedEventInWidgetPool(_ event: WebEvent) async {
        do {
            if isInWidgetCountdownPool {
                let result = try WidgetSelectableEventsSyncService.shared.remove(eventID: event.id)
                switch result {
                case .removed:
                    isInWidgetCountdownPool = false
                    showWidgetStatusBanner(message: L(
                        "已从桌面倒计时候选活动移除。",
                        "Removed from widget countdown candidates."
                    ))
                case .notFound:
                    isInWidgetCountdownPool = false
                    showWidgetStatusBanner(message: L(
                        "该活动已不在桌面倒计时候选列表中。",
                        "This event is no longer in widget countdown candidates."
                    ))
                }
            } else {
                let result = try await WidgetSelectableEventsSyncService.shared.add(event: event)
                isInWidgetCountdownPool = true
                switch result {
                case .added:
                    showWidgetStatusBanner(message: L(
                        "已加入桌面倒计时候选活动，长按组件即可选择。",
                        "Added to widget countdown candidates. Long-press the widget to choose it."
                    ))
                case .refreshed:
                    showWidgetStatusBanner(message: L(
                        "已更新桌面倒计时候选活动。",
                        "Updated in widget countdown candidates."
                    ))
                }
            }
        } catch {
            errorMessage = error.userFacingMessage ?? L(
                "加入桌面倒计时失败，请稍后重试。",
                "Failed to add to widget countdown. Please try again later."
            )
        }
    }

    @MainActor
    private func refreshWidgetCountdownState() async {
        isInWidgetCountdownPool = WidgetSelectableEventsSyncService.shared.contains(eventID: eventID)
    }

    private func openEventReportEntry() {
        // TODO: Wire to dedicated report route/page when available.
        errorMessage = L("举报入口即将开放，当前已记录该需求。", "Report entry is coming soon. We have recorded this request.")
    }

    @ViewBuilder
    private func lineupDJsStrip(for event: WebEvent) -> some View {
        let djs = lineupDJEntries(for: event, sortMode: lineupSortMode)
        let canExpand = djs.count > 8
        if !djs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(LL("参演 DJ"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(lineupSortMode.activeTitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(RaverTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RaverTheme.accent.opacity(0.12), in: Capsule())
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) {
                            lineupSortMode = lineupSortMode == .alphabetical ? .popularity : .alphabetical
                            expandedLineupPage = 0
                        }
                    } label: {
                        Label(lineupSortMode.toggleTitle, systemImage: lineupSortMode.iconName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(lineupSortMode == .alphabetical ? Color(red: 0.98, green: 0.45, blue: 0.27) : RaverTheme.accent)
                    }
                    .buttonStyle(.plain)
                    if canExpand {
                        Button {
                            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.85)) {
                                showExpandedLineupList.toggle()
                                expandedLineupPage = 0
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
                    lineupExpandedPager(djs)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showExpandedLineupList)
            .animation(.spring(response: 0.26, dampingFraction: 0.88), value: lineupSortMode)
        }
    }

    private func lineupExpandedPager(_ djs: [EventLineupDJEntry]) -> some View {
        let pages = lineupDJPages(djs)
        let pageCount = max(pages.count, 1)

        return VStack(spacing: 10) {
            TabView(selection: $expandedLineupPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageItems in
                    lineupExpandedGrid(pageItems)
                        .tag(pageIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 368)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        expandedLineupPage = max(0, expandedLineupPage - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(expandedLineupPage <= 0 ? RaverTheme.secondaryText.opacity(0.35) : RaverTheme.accent)
                .disabled(expandedLineupPage <= 0)

                Spacer(minLength: 0)

                Text("\(min(expandedLineupPage + 1, pageCount)) / \(pageCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RaverTheme.background.opacity(0.42), in: Capsule())

                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        expandedLineupPage = min(pageCount - 1, expandedLineupPage + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(expandedLineupPage >= pageCount - 1 ? RaverTheme.secondaryText.opacity(0.35) : RaverTheme.accent)
                .disabled(expandedLineupPage >= pageCount - 1)
            }
            .padding(.horizontal, 6)
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

    private func lineupExpandedGrid(_ djs: [EventLineupDJEntry]) -> some View {
        let columns = [
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top)
        ]

        return LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
            ForEach(djs) { dj in
                lineupDJAvatarItem(dj)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 356, maxHeight: 356, alignment: .top)
        .padding(.top, 2)
    }

    private func lineupDJPages(_ djs: [EventLineupDJEntry]) -> [[EventLineupDJEntry]] {
        let pageSize = 16
        guard !djs.isEmpty else { return [[]] }
        return stride(from: 0, to: djs.count, by: pageSize).map { start in
            Array(djs[start..<min(start + pageSize, djs.count)])
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

    private func lineupDJEntries(for event: WebEvent, sortMode: LineupSortMode) -> [EventLineupDJEntry] {
        var seen = Set<String>()
        var result: [EventLineupDJEntry] = []
        let avatarByName = performerAvatarMap(from: event)

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

        if sortMode == .alphabetical {
            return result
                .enumerated()
                .sorted { lhs, rhs in
                    shouldOrderLineupActAlphabetically(lhs.element.act, before: rhs.element.act, lhsIndex: lhs.offset, rhsIndex: rhs.offset)
                }
                .map(\.element)
        }

        let followerByName = lineupFollowerMapByName(from: event)
        let followerByID = lineupFollowerMapByID(from: event)
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

    private func shouldOrderLineupActAlphabetically(
        _ lhs: EventLineupResolvedAct,
        before rhs: EventLineupResolvedAct,
        lhsIndex: Int,
        rhsIndex: Int
    ) -> Bool {
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
        guard !isLoading else { return }

        let hadContent = event != nil
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

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
            let loadedCheckins = await checkinsTask
            let loadedRatingEvents = (try? await ratingEventsTask) ?? []
            let loadedEventSets = (try? await eventsRepository.fetchEventDJSets(eventName: loadedEvent.name)) ?? []
            let loadedArticles = (try? await relatedArticlesTask) ?? []

            event = loadedEvent
            relatedEventCheckins = loadedCheckins
            relatedRatingEvents = loadedRatingEvents
            relatedEventSets = loadedEventSets
            relatedArticles = loadedArticles
            isLoadingRelatedArticles = false
            phase = .success
            bannerMessage = nil

            let snapshot = makeManualCacheSnapshot(
                event: loadedEvent,
                relatedRatingEvents: loadedRatingEvents,
                relatedEventSets: loadedEventSets,
                relatedArticles: loadedArticles
            )
            await persistManualCacheSnapshot(snapshot, prefetchImages: false)
        } catch {
            let canFallback = isOfflineRecoverableError(error) || event == nil
            if canFallback, let snapshot = await EventManualCacheStore.shared.loadSnapshot(eventID: eventID) {
                applyManualCacheSnapshot(snapshot)
                phase = .success
                if isRequestTimeoutError(error) {
                    showBannerMessageAutoDismiss(L("请求超时，已展示最新离线缓存版本。", "Request timed out. Showing latest offline cache version."))
                } else {
                    showBannerMessageAutoDismiss(L("网络较弱，已展示活动缓存数据。", "Network is weak. Showing cached event data."))
                }
            } else if hadContent {
                isLoadingRelatedArticles = false
                showBannerMessageAutoDismiss(error.userFacingMessage ?? L("活动详情更新失败，请稍后重试", "Failed to refresh event details. Please try again later."))
                phase = .success
            } else {
                isLoadingRelatedArticles = false
                let message = error.userFacingMessage ?? L("活动详情加载失败，请稍后重试", "Failed to load event details. Please try again later.")
                phase = isOfflineRecoverableError(error)
                    ? .offline(message: message)
                    : .failure(message: message)
            }
        }
    }

    private func fetchRelatedNewsArticlesForEvent(eventID: String) async throws -> [DiscoverNewsArticle] {
        try await newsRepository.fetchArticlesBoundToEvent(eventID: eventID, maxPages: 8)
    }

    private func reloadEventRatings() async {
        relatedRatingEvents = (try? await eventsRepository.fetchEventRatingEvents(eventID: eventID)) ?? []
        await persistCurrentManualCacheSnapshotIfPossible()
    }

    private func reloadEventSets() async {
        guard let event else {
            relatedEventSets = []
            return
        }
        relatedEventSets = (try? await eventsRepository.fetchEventDJSets(eventName: event.name)) ?? []
        await persistCurrentManualCacheSnapshotIfPossible()
    }

    @MainActor
    private func refreshManualCacheState() async {
        try? await EventManualCacheStore.shared.clearExpiredSnapshots()
        manualCachedAt = await EventManualCacheStore.shared.loadSnapshot(eventID: eventID)?.cachedAt
    }

    @MainActor
    private func cacheEventManually() async {
        guard !isCachingManualSnapshot else { return }

        isCachingManualSnapshot = true
        defer { isCachingManualSnapshot = false }

        do {
            let eventForCache = try await resolveEventForManualCache()
            async let ratingsTask = eventsRepository.fetchEventRatingEvents(eventID: eventID)
            async let setsTask = eventsRepository.fetchEventDJSets(eventName: eventForCache.name)
            async let articlesTask = fetchRelatedNewsArticlesForEvent(eventID: eventID)

            let snapshot = EventManualCacheSnapshot(
                eventID: eventID,
                event: eventForCache,
                relatedRatingEvents: (try? await ratingsTask) ?? relatedRatingEvents,
                relatedEventSets: (try? await setsTask) ?? relatedEventSets,
                relatedArticles: ((try? await articlesTask) ?? relatedArticles).map(CachedDiscoverNewsArticle.init),
                cachedAt: Date()
            )

            await persistManualCacheSnapshot(snapshot, prefetchImages: true)
            applyManualCacheSnapshot(snapshot)
            errorMessage = L("活动已缓存，弱网环境也可查看。", "Event cached. You can view it in weak-network conditions.")
        } catch {
            errorMessage = L("缓存失败，请稍后重试。", "Caching failed. Please try again later.")
        }
    }

    @MainActor
    private func applyManualCacheSnapshot(_ snapshot: EventManualCacheSnapshot) {
        event = snapshot.event
        relatedRatingEvents = snapshot.relatedRatingEvents
        relatedEventSets = snapshot.relatedEventSets
        relatedArticles = snapshot.relatedNewsArticles
        isLoadingRelatedArticles = false
        manualCachedAt = snapshot.cachedAt
    }

    @MainActor
    private func resolveEventForManualCache() async throws -> WebEvent {
        if let latest = try? await eventsRepository.fetchEvent(id: eventID) {
            return latest
        }
        if let event {
            return event
        }
        throw ServiceError.message(L("活动详情加载失败，请稍后重试。", "Failed to load event details. Please try again later."))
    }

    private func prefetchManualCacheImages(from snapshot: EventManualCacheSnapshot) {
        let event = snapshot.event
        let rawURLs = [event.coverAssetURL]
            + event.lineupAssetURLs
            + event.timetableAssetURLs
            + snapshot.relatedEventSets.compactMap(\.thumbnailUrl)
            + snapshot.relatedArticles.compactMap(\.coverImageURL)

        let urls = rawURLs
            .compactMap(AppConfig.resolvedURLString)
            .compactMap(URL.init(string:))

        guard !urls.isEmpty else { return }
        SDWebImagePrefetcher.shared.prefetchURLs(urls)
    }

    private func makeManualCacheSnapshot(
        event: WebEvent,
        relatedRatingEvents: [WebRatingEvent],
        relatedEventSets: [WebDJSet],
        relatedArticles: [DiscoverNewsArticle]
    ) -> EventManualCacheSnapshot {
        EventManualCacheSnapshot(
            eventID: event.id,
            event: event,
            relatedRatingEvents: relatedRatingEvents,
            relatedEventSets: relatedEventSets,
            relatedArticles: relatedArticles.map(CachedDiscoverNewsArticle.init),
            cachedAt: Date()
        )
    }

    @MainActor
    private func persistManualCacheSnapshot(_ snapshot: EventManualCacheSnapshot, prefetchImages: Bool) async {
        await EventManualCacheStore.shared.saveSnapshot(snapshot)
        manualCachedAt = snapshot.cachedAt
        if prefetchImages {
            prefetchManualCacheImages(from: snapshot)
        }
    }

    @MainActor
    private func persistCurrentManualCacheSnapshotIfPossible() async {
        guard let event else { return }
        let snapshot = makeManualCacheSnapshot(
            event: event,
            relatedRatingEvents: relatedRatingEvents,
            relatedEventSets: relatedEventSets,
            relatedArticles: relatedArticles
        )
        await persistManualCacheSnapshot(snapshot, prefetchImages: false)
    }

    private func isRequestTimeoutError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }

    private func isOfflineRecoverableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed:
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let recoverableCodes: Set<Int> = [
                NSURLErrorTimedOut,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorDNSLookupFailed,
            ]
            if recoverableCodes.contains(nsError.code) {
                return true
            }
        }

        return false
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
    static let stageHeaderFadeHeight: CGFloat = 20
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
        stageOrder: [String] = [],
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
        var groupedStageByKey: [String: String] = [:]
        for stage in grouped.keys {
            groupedStageByKey[stage.localizedLowercase] = stage
        }
        let slotsOrderedBySort = normalizedSlots.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.startTime < $1.startTime
            }
            return $0.sortOrder < $1.sortOrder
        }
        let configuredStageOrder = Self.normalizedStageOrder(stageOrder)
        var orderedStages: [String] = []
        var seenStages = Set<String>()
        for stage in configuredStageOrder {
            guard let canonicalStage = groupedStageByKey[stage.localizedLowercase] else { continue }
            if seenStages.insert(canonicalStage).inserted {
                orderedStages.append(canonicalStage)
            }
        }
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

    private static func normalizedStageOrder(_ stageOrder: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for raw in stageOrder {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = text.localizedLowercase
            guard seen.insert(key).inserted else { continue }
            result.append(text)
        }
        return result
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
    @Environment(\.colorScheme) private var colorScheme

    let event: WebEvent
    let day: EventScheduleDay
    let selectedSlotIDs: Set<String>
    let selectable: Bool
    let onToggleSlot: ((WebEventLineupSlot) -> Void)?
    var onSelectSlot: ((WebEventLineupSlot) -> Void)? = nil
    var maxVisibleStages: Int = EventTimelineLayout.maxVisibleStageCount
    var stickyTopInset: CGFloat = 0

    private var boardHeight: CGFloat {
        EventTimelineLayout.estimatedHeight(for: day.slots)
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var boardGradientColors: [Color] {
        if isDarkMode {
            return [
                Color(red: 0.09, green: 0.10, blue: 0.14),
                Color(red: 0.06, green: 0.06, blue: 0.09)
            ]
        }
        return [
            Color.white,
            Color(red: 0.94, green: 0.94, blue: 0.985)
        ]
    }

    private var boardStrokeColor: Color {
        isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var headerBackdropColor: Color {
        isDarkMode ? Color(red: 0.08, green: 0.09, blue: 0.13) : Color(red: 0.965, green: 0.965, blue: 0.99)
    }

    private var axisHeaderTextColor: Color {
        isDarkMode ? Color.white.opacity(0.72) : Color.black.opacity(0.54)
    }

    private var axisTextColor: Color {
        isDarkMode ? Color.white.opacity(0.92) : Color.black.opacity(0.62)
    }

    private var stageHeaderStrokeColor: Color {
        isDarkMode ? Color.white.opacity(0.36) : Color.white.opacity(0.72)
    }

    private var stageHeaderTextColor: Color {
        Color.black.opacity(0.78)
    }

    private var columnFillColor: Color {
        isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.035)
    }

    private var gridLineColor: Color {
        isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var normalCardTextColor: Color {
        Color.black.opacity(isDarkMode ? 0.84 : 0.78)
    }

    private var selectedCardFillColor: Color {
        isDarkMode ? Color.black.opacity(0.88) : Color.white.opacity(0.94)
    }

    var body: some View {
        GeometryReader { geo in
            let layout = EventTimelineLayout(
                slots: day.slots,
                stageOrder: event.stageOrder ?? [],
                availableWidth: max(geo.size.width, EventTimelineLayout.axisWidth + EventTimelineLayout.minStageWidth),
                maxVisibleStages: maxVisibleStages
            )
            let stickyHeaderOffset = stickyHeaderOffset(containerMinY: geo.frame(in: .global).minY, layout: layout)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: boardGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(boardStrokeColor, lineWidth: 1)
                    )

                HStack(spacing: 0) {
                    timelineAxis(layout: layout, stickyHeaderOffset: stickyHeaderOffset)
                    stageMatrix(layout: layout, stickyHeaderOffset: stickyHeaderOffset)
                }
                .padding(.vertical, 10)
            }
        }
        .frame(height: boardHeight)
    }

    private func stickyHeaderOffset(containerMinY: CGFloat, layout: EventTimelineLayout) -> CGFloat {
        let rawOffset = max(0, stickyTopInset - containerMinY)
        return min(rawOffset, max(0, layout.bodyHeight - 1))
    }

    @ViewBuilder
    private func stageMatrix(layout: EventTimelineLayout, stickyHeaderOffset: CGFloat) -> some View {
        let stageContent = VStack(spacing: 0) {
            stageHeaderRow(layout: layout, stickyHeaderOffset: stickyHeaderOffset)
                .offset(y: stickyHeaderOffset)
                .zIndex(3)
            stageColumnsRow(layout: layout)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            stageContent
                .frame(width: layout.stageContentWidth, alignment: .leading)
        }
        .frame(width: layout.stageViewportWidth, alignment: .leading)
    }

    private func timelineAxis(layout: EventTimelineLayout, stickyHeaderOffset: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                headerBackdrop(width: EventTimelineLayout.axisWidth, topExtension: stickyHeaderOffset)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(headerBackdropColor.opacity(stickyHeaderOffset > 0 ? 1.0 : 0.0))
                    .overlay(
                        Text("TIME")
                            .font(EventScheduleTypography.semibold(12))
                            .tracking(1.2)
                            .foregroundStyle(axisHeaderTextColor.opacity(stickyHeaderOffset > 0 ? 1.0 : 0.0))
                    )
                    .frame(width: EventTimelineLayout.axisWidth, height: EventTimelineLayout.stageHeaderHeight)
            }
            .frame(width: EventTimelineLayout.axisWidth, height: EventTimelineLayout.stageHeaderHeight, alignment: .top)
            .offset(y: stickyHeaderOffset)
            .zIndex(3)

            ZStack(alignment: .topTrailing) {
                ForEach(layout.tickDates, id: \.timeIntervalSinceReferenceDate) { tick in
                    Text(Self.axisTimeFormatter.string(from: tick))
                        .font(EventScheduleTypography.heavy(12))
                        .foregroundStyle(axisTextColor)
                        .frame(width: EventTimelineLayout.axisWidth - 8, alignment: .trailing)
                        .offset(y: layout.yPosition(for: tick) - 12)
                }
            }
            .frame(width: EventTimelineLayout.axisWidth, height: layout.bodyHeight, alignment: .topTrailing)
        }
        .frame(width: EventTimelineLayout.axisWidth)
    }

    private func stageHeaderRow(layout: EventTimelineLayout, stickyHeaderOffset: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            headerBackdrop(width: layout.stageContentWidth, topExtension: stickyHeaderOffset)

            HStack(spacing: EventTimelineLayout.stageGap) {
                ForEach(layout.stageNames, id: \.self) { stageName in
                    let stageColor = layout.color(for: stageName)
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    stageColor.opacity(0.98),
                                    stageColor.opacity(0.93),
                                    stageColor.opacity(0.86)
                                ],
                                startPoint: .top,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.92), lineWidth: 1.4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                                .inset(by: 2)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                        )
                        .overlay(
                            Text(stageName)
                                .font(EventScheduleTypography.heavy(26))
                                .minimumScaleFactor(0.24)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(stageHeaderTextColor)
                                .padding(.horizontal, 4)
                        )
                        .shadow(color: stageColor.opacity(0.72), radius: 14, x: 0, y: 0)
                        .shadow(color: stageColor.opacity(0.34), radius: 28, x: 0, y: 0)
                        .frame(width: layout.stageWidth, height: EventTimelineLayout.stageHeaderHeight)
                }
            }
        }
        .frame(width: layout.stageContentWidth, height: EventTimelineLayout.stageHeaderHeight, alignment: .topLeading)
    }

    private func headerBackdrop(width: CGFloat, topExtension: CGFloat = 0) -> some View {
        let resolvedTopExtension = max(0, topExtension)

        return VStack(spacing: 0) {
            headerBackdropColor
                .frame(
                    width: width,
                    height: resolvedTopExtension + EventTimelineLayout.stageHeaderHeight
                )
                .offset(y: -resolvedTopExtension)

            LinearGradient(
                colors: [
                    headerBackdropColor.opacity(isDarkMode ? 0.86 : 0.92),
                    headerBackdropColor.opacity(isDarkMode ? 0.34 : 0.46),
                    headerBackdropColor.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: EventTimelineLayout.stageHeaderFadeHeight)
            .offset(y: -resolvedTopExtension)
        }
        .allowsHitTesting(false)
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
                .fill(columnFillColor)

            ForEach(layout.tickDates, id: \.timeIntervalSinceReferenceDate) { tick in
                Rectangle()
                    .fill(gridLineColor)
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
        let cardFill = isSelected ? selectedCardFillColor : stageColor.opacity(0.95)
        let textColor = isSelected ? stageColor.opacity(0.98) : normalCardTextColor
        let nameTimeSpacing: CGFloat = 0.2

        let content = RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? [
                            Color.black.opacity(0.92),
                            stageColor.opacity(0.10),
                            Color.black.opacity(0.95)
                        ]
                        : [
                            cardFill,
                            stageColor.opacity(0.90),
                            stageColor.opacity(0.82)
                        ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isSelected ? stageColor.opacity(0.98) : Color.white.opacity(0.92),
                        lineWidth: isSelected ? 2.2 : 1.4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .inset(by: 2)
                    .stroke(
                        isSelected
                            ? Color.white.opacity(0.10)
                            : Color.white.opacity(0.24),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: stageColor.opacity(isSelected ? 0.82 : 0.58), radius: isSelected ? 16 : 13, x: 0, y: 0)
            .shadow(color: stageColor.opacity(isSelected ? 0.36 : 0.24), radius: isSelected ? 28 : 22, x: 0, y: 0)
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: nameTimeSpacing) {
                    Text(displayAct.displayName)
                        .font(EventScheduleTypography.heavy(28))
                        .lineSpacing(-4)
                        .minimumScaleFactor(0.21)
                        .lineLimit(3)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(textColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(Self.cardTimeRangeText(for: frame.slot))
                        .font(EventScheduleTypography.heavy(12))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? stageColor.opacity(0.88) : textColor.opacity(0.95))
                        .lineLimit(1)
                }
                .padding(.horizontal, 3)
                .padding(.top, 3)
                .padding(.bottom, 3)
            }

        return Group {
            if selectable, let onToggleSlot {
                Button {
                    onToggleSlot(frame.slot)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else if let onSelectSlot {
                Button {
                    onSelectSlot(frame.slot)
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

    private static func cardTimeRangeText(for slot: WebEventLineupSlot) -> String {
        "\(cardTimeFormatter.string(from: slot.startTime))-\(cardTimeFormatter.string(from: slot.endTime))"
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
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct EventRoutePlannerShareSnapshotView: View {
    let event: WebEvent
    let days: [EventScheduleDay]
    let selectedDayID: String
    let selectedSlotIDs: Set<String>
    let contentWidth: CGFloat

    private var selectedDay: EventScheduleDay? {
        days.first(where: { $0.id == selectedDayID }) ?? days.first
    }

    @Environment(\.colorScheme) private var colorScheme

    private var selectedDayTextColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.97)
    }

    private var selectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : RaverTheme.accent.opacity(0.92)
    }

    private var unselectedDayTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : RaverTheme.primaryText.opacity(0.86)
    }

    private var unselectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.08)
    }

    private var unselectedDayStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private var plannerBackgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.06, blue: 0.11),
                Color(red: 0.03, green: 0.03, blue: 0.04)
            ]
        }
        return [
            Color.white,
            RaverTheme.background
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: plannerBackgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                if days.count > 1 {
                    daySelector
                }

                if let selectedDay {
                    EventTimelineBoardView(
                        event: event,
                        day: selectedDay,
                        selectedSlotIDs: selectedSlotIDs,
                        selectable: false,
                        onToggleSlot: nil,
                        maxVisibleStages: Int.max,
                        stickyTopInset: 0
                    )
                    .frame(width: contentWidth, height: EventTimelineLayout.estimatedHeight(for: selectedDay.slots), alignment: .leading)
                } else {
                    ContentUnavailableView(LL("等待时间表发布"), systemImage: "calendar.badge.exclamationmark")
                        .frame(width: contentWidth, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(width: contentWidth + 20, alignment: .leading)
        }
        .frame(width: contentWidth + 20)
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    let selected = day.id == selectedDayID
                    Text(day.subtitle)
                        .font(EventScheduleTypography.semibold(15))
                        .foregroundStyle(selected ? selectedDayTextColor : unselectedDayTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selected ? selectedDayBackgroundColor : unselectedDayBackgroundColor)
                                .overlay(
                                    Capsule()
                                        .stroke(unselectedDayStrokeColor, lineWidth: selected ? 0 : 1)
                                )
                        )
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(width: contentWidth, alignment: .leading)
    }
}

private struct EventRoutePlannerView: View {
    let event: WebEvent
    let days: [EventScheduleDay]
    let initialDayID: String

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var routeStore = EventRouteStore.shared

    @State private var selectedDayID: String
    @State private var selectedSlotIDs: Set<String> = []
    @State private var isGeneratingShare = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var feedbackMessage: String?
    @State private var showRouteSavedToast = false

    init(event: WebEvent, days: [EventScheduleDay], initialDayID: String) {
        self.event = event
        self.days = days
        self.initialDayID = initialDayID
        _selectedDayID = State(initialValue: initialDayID)
        _selectedSlotIDs = State(initialValue: EventRouteStore.shared.route(for: event.id)?.selectedSlotIDSet ?? [])
    }

    private var selectedDay: EventScheduleDay? {
        days.first(where: { $0.id == selectedDayID }) ?? days.first
    }

    private var selectedDayTextColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.97)
    }

    private var selectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : RaverTheme.accent.opacity(0.92)
    }

    private var unselectedDayTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : RaverTheme.primaryText.opacity(0.86)
    }

    private var unselectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.08)
    }

    private var unselectedDayStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private var plannerBackgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.06, blue: 0.11),
                Color(red: 0.03, green: 0.03, blue: 0.04)
            ]
        }
        return [
            Color.white,
            RaverTheme.background
        ]
    }

    private var routePlannerTimelineStickyTopInset: CGFloat {
        topSafeAreaInset() + 44
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: plannerBackgroundGradientColors,
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
                            },
                            stickyTopInset: routePlannerTimelineStickyTopInset
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
        .overlay {
            if showRouteSavedToast {
                Text(LL("在个人主页-我的行程可以快速查看路线"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.82))
                            .overlay(
                                Capsule()
                                    .stroke(RaverTheme.accent.opacity(0.55), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 8)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.86), value: showRouteSavedToast)
        .raverSystemNavigation(title: LL("定制路线"), backgroundColor: RaverTheme.background)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    saveCurrentRoute()
                } label: {
                    Label(LL("保存"), systemImage: "square.and.arrow.down")
                }

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

    private func saveCurrentRoute() {
        routeStore.save(event: event, selectedSlotIDs: selectedSlotIDs)
        showRouteSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            showRouteSavedToast = false
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
                            .foregroundStyle(selected ? selectedDayTextColor : unselectedDayTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected ? selectedDayBackgroundColor : unselectedDayBackgroundColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(unselectedDayStrokeColor, lineWidth: selected ? 0 : 1)
                                    )
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
        let fullBoardWidth = EventTimelineLayout.axisWidth + stageRegionWidth
        let viewportContentWidth = max(UIScreen.main.bounds.width - 20, EventTimelineLayout.axisWidth + EventTimelineLayout.minStageWidth)
        let snapshotContentWidth = max(fullBoardWidth, viewportContentWidth)

        let snapshotView = EventRoutePlannerShareSnapshotView(
            event: event,
            days: days,
            selectedDayID: selectedDay.id,
            selectedSlotIDs: selectedSlotIDs,
            contentWidth: snapshotContentWidth
        )
        .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: snapshotContentWidth + 20, height: nil)

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

}

private struct EventRoutineView: View {
    enum PresentationStyle {
        case pushed
        case embedded
    }

    private struct EventScheduleDJSelectionOption: Identifiable, Hashable {
        let id: String
        let name: String
    }

    let event: WebEvent
    let scheduledSlots: [WebEventLineupSlot]
    var presentationStyle: PresentationStyle = .pushed

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appPush) private var appPush
    @ObservedObject private var routeStore = EventRouteStore.shared
    @State private var selectedDayID: String = ""
    @State private var showRoutePlanner = false
    @State private var showsSavedRouteOverlay = true
    @State private var pendingDJSelectionOptions: [EventScheduleDJSelectionOption] = []
    @State private var showDJSelectionDialog = false

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

    private var savedRoute: SavedEventRoute? {
        routeStore.route(for: event.id)
    }

    private var displayedRouteSlotIDs: Set<String> {
        guard showsSavedRouteOverlay else { return [] }
        return savedRoute?.selectedSlotIDSet ?? []
    }

    private var selectedDayTextColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.97)
    }

    private var selectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : RaverTheme.accent.opacity(0.92)
    }

    private var unselectedDayTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : RaverTheme.primaryText.opacity(0.86)
    }

    private var unselectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.06)
    }

    private var unselectedDayStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private var scheduleBackgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.06, blue: 0.11),
                RaverTheme.background
            ]
        }
        return [
            Color.white,
            RaverTheme.background
        ]
    }

    private var routeActionIdleFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.035)
    }

    private var routeActionIdleStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var timelineStickyTopInset: CGFloat {
        switch presentationStyle {
        case .embedded:
            return topSafeAreaInset() + 44 + 52
        case .pushed:
            return topSafeAreaInset() + 44
        }
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
        .confirmationDialog(
            "",
            isPresented: $showDJSelectionDialog,
            titleVisibility: .hidden
        ) {
            ForEach(pendingDJSelectionOptions) { option in
                Button(option.name) {
                    appPush(.djDetail(djID: option.id))
                    clearPendingDJSelection()
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {
                clearPendingDJSelection()
            }
        }
    }

    private var embeddedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            routeControlRow

            if days.count > 1 {
                daySelector
            }

            timelineBoard
        }
    }

    private var standaloneContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                routeControlRow

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
                colors: scheduleBackgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .raverSystemNavigation(title: L("活动日程", "Event Schedule"))
    }

    private var routeControlRow: some View {
        HStack(spacing: 10) {
            Spacer()

            if savedRoute != nil {
                Button {
                    showsSavedRouteOverlay.toggle()
                } label: {
                    Label(
                        showsSavedRouteOverlay ? LL("隐藏路线") : LL("显示路线"),
                        systemImage: showsSavedRouteOverlay ? "eye.slash.fill" : "eye.fill"
                    )
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(showsSavedRouteOverlay ? RaverTheme.accent : RaverTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(routeActionBackground(isHighlighted: showsSavedRouteOverlay))
            }

            Button {
                showRoutePlanner = true
            } label: {
                Label(LL("定制路线"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RaverTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(routeActionBackground(isHighlighted: true))
        }
    }

    private func routeActionBackground(isHighlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isHighlighted ? RaverTheme.accent.opacity(0.13) : routeActionIdleFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isHighlighted ? RaverTheme.accent.opacity(0.42) : routeActionIdleStrokeColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var timelineBoard: some View {
        if let selectedDay {
            EventTimelineBoardView(
                event: event,
                day: selectedDay,
                selectedSlotIDs: displayedRouteSlotIDs,
                selectable: false,
                onToggleSlot: nil,
                onSelectSlot: { slot in
                    handleTimelineSlotTap(slot)
                },
                stickyTopInset: timelineStickyTopInset
            )
            .frame(height: EventTimelineLayout.estimatedHeight(for: selectedDay.slots))
        } else {
            ContentUnavailableView(LL("等待时间表发布"), systemImage: "calendar.badge.exclamationmark")
        }
    }

    private func handleTimelineSlotTap(_ slot: WebEventLineupSlot) {
        let act = EventLineupActCodec.parse(slot: slot)
        let options = djSelectionOptions(for: slot, act: act)
        if act.isCollaborative, options.count > 1 {
            pendingDJSelectionOptions = options
            showDJSelectionDialog = true
            return
        }

        let djID = options.first?.id ?? preferredDJID(for: slot)
        guard let djID else { return }
        appPush(.djDetail(djID: djID))
    }

    private func djSelectionOptions(
        for slot: WebEventLineupSlot,
        act: EventLineupResolvedAct
    ) -> [EventScheduleDJSelectionOption] {
        var options: [EventScheduleDJSelectionOption] = []
        var seenIDs = Set<String>()

        let appendOption: (_ djID: String, _ name: String) -> Void = { djID, name in
            let normalizedID = djID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedID.isEmpty, seenIDs.insert(normalizedID).inserted else { return }
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = trimmedName.isEmpty ? normalizedID : trimmedName
            options.append(EventScheduleDJSelectionOption(id: normalizedID, name: resolvedName))
        }

        for performer in act.performers {
            let djID = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            appendOption(djID, performer.name)
        }

        let fallbackIDs = (slot.djIds ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for (index, djID) in fallbackIDs.enumerated() {
            let fallbackName: String
            if index < act.performers.count {
                fallbackName = act.performers[index].name
            } else {
                fallbackName = "DJ \(index + 1)"
            }
            appendOption(djID, fallbackName)
        }

        let primaryID = slot.djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primaryID.isEmpty {
            appendOption(primaryID, act.performers.first?.name ?? "")
        }

        return options
    }

    private func preferredDJID(for slot: WebEventLineupSlot) -> String? {
        let primary = slot.djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primary.isEmpty { return primary }

        if let fallback = (slot.djIds ?? [])
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return fallback
        }

        let act = EventLineupActCodec.parse(slot: slot)
        for performer in act.performers {
            let inline = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !inline.isEmpty { return inline }
        }

        return nil
    }

    private func clearPendingDJSelection() {
        pendingDJSelectionOptions = []
    }

    private var daySelector: some View {
        //HorizontalAxisLockedScrollView(showsIndicators: false) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                ForEach(days) { day in
                    let selected = day.id == selectedDayID
                    Button {
                        selectedDayID = day.id
                    } label: {
                        Text(day.subtitle)
                            .font(EventScheduleTypography.semibold(15))
                            .foregroundStyle(selected ? selectedDayTextColor : unselectedDayTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected ? selectedDayBackgroundColor : unselectedDayBackgroundColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(unselectedDayStrokeColor, lineWidth: selected ? 0 : 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
