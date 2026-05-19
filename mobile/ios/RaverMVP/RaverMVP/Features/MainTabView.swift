import SwiftUI
import PhotosUI
import UIKit
import AVKit

private struct MainGlobalSearchFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var router: AppRouter
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.requestLoginGate) private var requestLoginGate
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var tabBarIndicatorNamespace
    private let tabs: [MainTab] = [.discover, .circle, .messages, .profile]
    @State private var loadedTabs: Set<MainTab> = [.discover]
    @StateObject private var guidanceCenter = AppGuidanceCenter.shared
    @StateObject private var recentSearchStore = RecentSearchStore()
    @StateObject private var appLocationProvider = AppLocationProvider()
    @State private var isGlobalSearchPresented = false
    @State private var showGlobalSearchGuide = false
    @State private var globalSearchFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContentContainer
                .zIndex(1)

            if !isTabBarHidden {
                customTabBar
                    .zIndex(2)
            }

            if isGlobalSearchPresented {
                GlobalSearchOverlayView(
                    recentStore: recentSearchStore,
                    onDismiss: {
                        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88)) {
                            isGlobalSearchPresented = false
                        }
                    },
                    onSearch: { keyword in
                        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88)) {
                            isGlobalSearchPresented = false
                        }
                        router.push(.globalSearchResults(query: keyword))
                    }
                )
                .zIndex(3)
            }

            if showGlobalSearchGuide {
                AppGuidanceSpotlightOverlay(
                    step: globalSearchSpotlightStep,
                    onPrimary: openGlobalSearchFromGuide,
                    onDismiss: dismissGlobalSearchGuide
                )
                .transition(.opacity)
                .zIndex(4)
            }
        }
        .background(RaverTheme.background.ignoresSafeArea(.all))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(appLocationProvider)
        .task {
            await appState.refreshUnreadMessages()
            appLocationProvider.requestOnAppEntryIfNeeded()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await appState.refreshUnreadMessages() }
        }
        .onAppear {
            loadedTabs.insert(currentTab)
            presentGlobalSearchGuideIfNeeded()
        }
        .onChange(of: currentTab) { _, newTab in
            loadedTabs.insert(newTab)
        }
        .onChange(of: appState.session?.user.id) { oldUserID, newUserID in
            guard oldUserID != newUserID else { return }
            loadedTabs = [.discover]
            isGlobalSearchPresented = false
        }
    }

    private var currentTab: MainTab {
        router.selectedTab
    }

    private var isTabBarHidden: Bool {
        false
    }

    private var bottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    private var tabBarReservedHeight: CGFloat {
        guard !isTabBarHidden else { return 0 }
        let barVisualHeight: CGFloat = 66
        let legacyBottomPadding: CGFloat = bottomSafeAreaInset == 0 ? 4 : 0
        return barVisualHeight + legacyBottomPadding
    }

    private var tabContentContainer: some View {
        ZStack {
            ForEach(tabs, id: \.self) { tab in
                if loadedTabs.contains(tab) {
                    tabContent(for: tab)
                        .opacity(currentTab == tab ? 1 : 0)
                        .allowsHitTesting(currentTab == tab)
                        .zIndex(currentTab == tab ? 1 : 0)
                }
            }
        }
        .environment(\.raverTabBarReservedHeight, tabBarReservedHeight)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: max(0, tabBarReservedHeight))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func tabContent(for tab: MainTab) -> some View {
        switch tab {
        case .discover:
            DiscoverCoordinatorView(push: discoverPush) {
                DiscoverHomeView()
            }
        case .circle:
            CircleHomeView()
        case .messages:
            MessagesCoordinatorView(
                conversationRepository: appContainer.conversationRepository,
                notificationRepository: appContainer.messageNotificationRepository
            )
        case .profile:
            ProfileCoordinatorView(
                userRepository: appContainer.profileUserRepository,
                contentRepository: appContainer.profileContentRepository,
                checkinRepository: appContainer.profileCheckinRepository,
                virtualAssetRepository: appContainer.virtualAssetRepository
            )
            .id(appState.session?.user.id ?? "anonymous-profile")
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    switchTab(tab)
                } label: {
                    VStack(spacing: 3) {
                        tabIcon(for: tab)
                        Text(tab.title)
                            .font(.system(size: 11, weight: currentTab == tab ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(currentTab == tab ? .white : RaverTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if currentTab == tab {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            RaverTheme.tabBarSelectionStart,
                                            RaverTheme.tabBarSelectionEnd
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(RaverTheme.tabBarSelectionStroke, lineWidth: 1)
                                )
                                .matchedGeometryEffect(
                                    id: "main-tab-indicator",
                                    in: tabBarIndicatorNamespace
                                )
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(tab.accessibilityIdentifier)

                if tab == .circle {
                    globalSearchButton
                }
            }
        }
        .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.86), value: currentTab)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            RaverTheme.tabBarChromeStart,
                            RaverTheme.tabBarChromeEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            RaverTheme.tabBarStrokeLeading,
                            RaverTheme.tabBarStrokeTrailing
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: RaverTheme.tabBarShadowPrimary, radius: 18, x: 0, y: 10)
        .shadow(color: RaverTheme.tabBarShadowAccent, radius: 12, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.bottom, bottomSafeAreaInset == 0 ? 4 : -14)
        .accessibilityIdentifier("mainTab.tabBar")
    }

    private var globalSearchButton: some View {
        Button {
            guard appState.isLoggedIn else {
                requestLoginGate()
                return
            }
            GlobalSearchTelemetry.overlayOpened(source: "main_tab")
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                isGlobalSearchPresented = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            RaverTheme.accent,
                            Color(red: 0.31, green: 0.22, blue: 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: RaverTheme.accent.opacity(0.36), radius: 14, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .frame(width: 52, height: 52)
        .accessibilityIdentifier("mainTab.action.globalSearch")
        .accessibilityLabel(LT("搜索", "Search", "検索"))
        .accessibilityHint(LT("打开全局聚合搜索", "Opens global aggregated search", "グローバル統合検索を開きます"))
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: MainGlobalSearchFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
            }
        }
        .onPreferenceChange(MainGlobalSearchFramePreferenceKey.self) { frame in
            globalSearchFrame = frame
            presentGlobalSearchGuideIfNeeded()
        }
    }

    private func presentGlobalSearchGuideIfNeeded() {
        guard globalSearchFrame != .zero else { return }
        guard !showGlobalSearchGuide, !isGlobalSearchPresented else { return }
        guard guidanceCenter.shouldPresent(
            .mainGlobalSearchFirstRun,
            policy: AppGuidanceRuntime.mainGlobalSearchFirstRunPolicy,
            userID: appState.session?.user.id
        ) else { return }
        guidanceCenter.markPresented(
            .mainGlobalSearchFirstRun,
            policy: AppGuidanceRuntime.mainGlobalSearchFirstRunPolicy,
            userID: appState.session?.user.id
        )
        withAnimation(.easeInOut(duration: 0.22)) {
            showGlobalSearchGuide = true
        }
    }

    private func dismissGlobalSearchGuide() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showGlobalSearchGuide = false
        }
    }

    private func openGlobalSearchFromGuide() {
        dismissGlobalSearchGuide()
        guard appState.isLoggedIn else {
            requestLoginGate()
            return
        }
        GlobalSearchTelemetry.overlayOpened(source: "main_tab_guidance")
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
            isGlobalSearchPresented = true
        }
    }

    private var globalSearchSpotlightStep: AppGuidanceSpotlightStep {
        AppGuidanceSpotlightStep(
            title: LT("全站搜索入口", "Global search", "グローバル検索"),
            message: LT("点击这里可以搜索历史活动，以及活动相关的 DJ、资讯、Sets、榜单、打分、动态、品牌和厂牌信息。", "Tap here to search historical events plus related DJs, news, sets, rankings, ratings, posts, brands, and labels.", "ここから過去のイベント、関連DJ、ニュース、Sets、ランキング、評価、投稿、ブランド、レーベルを検索できます。"),
            buttonTitle: LT("开始搜索", "Start searching", "検索する"),
            targetFrame: globalSearchFrame == .zero ? globalSearchFallbackFrame : globalSearchFrame,
            cornerRadius: 30,
            placement: .above
        )
    }

    private var globalSearchFallbackFrame: CGRect {
        let screen = UIScreen.main.bounds
        return CGRect(
            x: screen.midX - 28,
            y: screen.height - max(104, bottomSafeAreaInset + 76),
            width: 56,
            height: 56
        )
    }

    private func tabIcon(for tab: MainTab) -> some View {
        ZStack(alignment: .top) {
            Image(systemName: currentTab == tab ? tab.selectedIcon : tab.icon)
                .renderingMode(.template)
                .font(.system(size: 16, weight: .semibold))

            if tab == .messages {
                TabUnreadBadge(
                    count: appState.unreadMessagesCount,
                    color: .red
                )
                .offset(x: 15, y: -8)
            }
        }
        .frame(width: 48, height: 22)
    }

    private func switchTab(_ tab: MainTab) {
        switch tab {
        case .discover:
            router.switchTab(tab)
        case .circle, .messages, .profile:
            guard appState.isLoggedIn else {
                requestLoginGate()
                return
            }
            router.switchTab(tab)
        }
    }
}

private struct TabUnreadBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        Group {
            if count > 0 {
                Text(displayText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, displayText.count > 1 ? 5 : 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(color, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.86), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 1)
                    .accessibilityLabel(LT("未读消息 \(displayText)", "\(displayText) unread messages", "未読メッセージ \(displayText) 件"))
            }
        }
        .frame(width: 24, height: 16)
    }

    private var displayText: String {
        count > 99 ? "99+" : "\(count)"
    }
}

private extension MainTab {
    var accessibilityIdentifier: String {
        switch self {
        case .discover: return "mainTab.tab.discover"
        case .circle: return "mainTab.tab.circle"
        case .messages: return "mainTab.tab.messages"
        case .profile: return "mainTab.tab.profile"
        }
    }

    var title: String {
        switch self {
        case .discover: return LT("发现", "Discover", "発見")
        case .circle: return LT("圈子", "Circle", "サークル")
        case .messages: return LT("收件箱", "Inbox", "受信箱")
        case .profile: return LT("我的", "Me", "マイページ")
        }
    }

    var icon: String {
        switch self {
        case .discover: return "safari"
        case .circle: return "person.3"
        case .messages: return "bubble.left.and.bubble.right"
        case .profile: return "person.crop.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .discover: return "safari.fill"
        case .circle: return "person.3.fill"
        case .messages: return "bubble.left.and.bubble.right.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

private struct CircleHomeView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case feed
        case squads
        case ids
        case ratings

        var id: String { rawValue }
        var title: String {
            switch self {
            case .feed: return LT("动态", "Feed", "フィード")
            case .squads: return LT("小队", "Squads", "Squad")
            case .ids: return "ID"
            case .ratings: return LT("打分", "Ratings", "評価")
            }
        }

        var themeColor: Color {
            switch self {
            case .feed: return Color(red: 0.95, green: 0.30, blue: 0.38)
            case .squads: return Color(red: 0.30, green: 0.67, blue: 0.97)
            case .ids: return Color(red: 0.58, green: 0.43, blue: 0.95)
            case .ratings: return Color(red: 0.98, green: 0.71, blue: 0.22)
            }
        }
    }

    @State private var section: Section = .feed

    var body: some View {
        RaverScrollableTabPager(
            items: tabItems,
            selection: $section,
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 18, weight: .regular)
        ) { tab in
            pageView(for: tab)
        }
        .background(RaverTheme.background)
        .ignoresSafeArea(edges: .bottom)
    }

    private var tabItems: [RaverScrollableTabItem<Section>] {
        Section.allCases.map { item in
            RaverScrollableTabItem(id: item, title: item.title)
        }
    }

    @ViewBuilder
    private func pageView(for section: Section) -> some View {
        switch section {
        case .feed:
            FeedView()
        case .squads:
            SquadHallView()
        case .ids:
            CircleIDHubView()
        case .ratings:
            CircleRatingHubView()
        }
    }

}

struct CircleIDUserSnapshot: Identifiable, Codable, Hashable {
    var id: String
    var username: String
    var displayName: String
    var avatarURL: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case avatarURL
        case avatarUrl
    }

    init(id: String, username: String, displayName: String, avatarURL: String?) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
            ?? container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
    }

    var shownName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return username
    }
}

struct CircleIDEventSnapshot: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var startDate: Date
    var endDate: Date
    var coverImageUrl: String?
}

struct CircleIDDJSnapshot: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var avatarUrl: String?
    var avatarSmallUrl: String?
}

struct CircleIDComment: Identifiable, Codable, Hashable {
    var id: String
    var author: CircleIDUserSnapshot
    var content: String
    var createdAt: Date
}

struct CircleIDEntry: Identifiable, Codable, Hashable {
    var id: String
    var songName: String
    var event: CircleIDEventSnapshot?
    var djs: [CircleIDDJSnapshot]
    var audioUrl: String?
    var videoUrl: String?
    var contributor: CircleIDUserSnapshot
    var createdAt: Date
    var likedUserIDs: [String]
    var favoritedUserIDs: [String]
    var repostedUserIDs: [String]
    var comments: [CircleIDComment]
}

private extension CircleIDEntry {
    init?(approvedPost post: Post) {
        guard post.content
            .split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .contains("#RAVER_ID") else {
            return nil
        }

        let fields = Self.fields(from: post.content)
        let songName = fields["标题"] ?? fields["Title"] ?? fields["title"]
        let normalizedSongName = songName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedSongName, !normalizedSongName.isEmpty else { return nil }

        let artistNames = (fields["艺人"] ?? fields["Artist"] ?? fields["artist"])
            .map(Self.commaSeparatedValues(from:)) ?? []
        let eventName = fields["活动"] ?? fields["Event"] ?? fields["event"]
        let audioUrl = fields["音频"] ?? fields["Audio"] ?? fields["audioUrl"]
        let videoUrl = fields["视频"] ?? fields["Video"] ?? fields["videoUrl"]

        self.init(
            id: post.id,
            songName: normalizedSongName,
            event: eventName.flatMap { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return CircleIDEventSnapshot(
                    id: post.boundEventIDs.first ?? post.eventID ?? "event-\(post.id)",
                    name: trimmed,
                    startDate: post.displayPublishedAt ?? post.createdAt,
                    endDate: post.displayPublishedAt ?? post.createdAt,
                    coverImageUrl: post.images.first
                )
            },
            djs: zip(post.boundDjIDs, artistNames).map { id, name in
                CircleIDDJSnapshot(id: id, name: name, avatarUrl: nil, avatarSmallUrl: nil)
            } + artistNames.dropFirst(post.boundDjIDs.count).map { name in
                CircleIDDJSnapshot(id: "artist-\(name)", name: name, avatarUrl: nil, avatarSmallUrl: nil)
            },
            audioUrl: audioUrl?.nilIfBlank,
            videoUrl: videoUrl?.nilIfBlank,
            contributor: CircleIDUserSnapshot(
                id: post.author.id,
                username: post.author.username,
                displayName: post.author.displayName,
                avatarURL: post.author.avatarURL
            ),
            createdAt: post.displayPublishedAt ?? post.createdAt,
            likedUserIDs: [],
            favoritedUserIDs: [],
            repostedUserIDs: [],
            comments: []
        )
    }

    private static func fields(from content: String) -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = line.firstIndex(of: "：") ?? line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty {
                result[key] = value
            }
        }
        return result
    }

    private static func commaSeparatedValues(from value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private enum CircleIDReaction {
    case like
    case favorite
    case repost
}

private struct CircleIDDetailRoute: Identifiable, Hashable {
    let id: String
}

private enum CircleIDStorage {
    static let entriesKey = "circle.id.entries.v1"
}

private struct CircleIDShareCardPresentation: Identifiable, Hashable {
    let id = UUID()
    let payload: CircleIDShareCardPayload
}

struct CircleIDDetailLoaderView: View {
    @EnvironmentObject private var appState: AppState
    let entryID: String

    @State private var entry: CircleIDEntry?

    var body: some View {
        Group {
            if let entry {
                CircleIDDetailView(
                    entry: Binding(
                        get: { entry },
                        set: { newValue in
                            self.entry = newValue
                            persistUpdatedEntry(newValue)
                        }
                    ),
                    onPersist: {
                        if let currentEntry = self.entry {
                            persistUpdatedEntry(currentEntry)
                        }
                    }
                )
                .environmentObject(appState)
            } else {
                ContentUnavailableView(
                    LT("该 ID 已不存在", "This ID no longer exists", "このIDは存在しません"),
                    systemImage: "music.note.slash"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
                .raverSystemNavigation(title: LT("ID详情", "ID Detail", "ID詳細"))
            }
        }
        .task {
            entry = loadEntry()
        }
    }

    private func loadEntry() -> CircleIDEntry? {
        guard let data = UserDefaults.standard.data(forKey: CircleIDStorage.entriesKey),
              let entries = try? JSONDecoder.raver.decode([CircleIDEntry].self, from: data) else {
            return nil
        }
        return entries.first(where: { $0.id == entryID })
    }

    private func persistUpdatedEntry(_ updated: CircleIDEntry) {
        guard let data = UserDefaults.standard.data(forKey: CircleIDStorage.entriesKey),
              var entries = try? JSONDecoder.raver.decode([CircleIDEntry].self, from: data),
              let index = entries.firstIndex(where: { $0.id == updated.id }) else {
            return
        }
        entries[index] = updated
        if let encoded = try? JSONEncoder.raver.encode(entries) {
            UserDefaults.standard.set(encoded, forKey: CircleIDStorage.entriesKey)
        }
    }
}

private struct CircleIDHubView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.appPush) private var appPush
    @Environment(\.circlePush) private var circlePush

    @State private var entries: [CircleIDEntry] = []
    @State private var hasLoaded = false
    @State private var selectedDetailRoute: CircleIDDetailRoute?
    @State private var errorMessage: String?
    @State private var shareMorePresentation: CircleIDShareCardPresentation?
    @State private var fullChatSharePresentation: CircleIDShareCardPresentation?
    @State private var reportTarget: ReportSheetTarget?
    @State private var isShareMorePanelVisible = false

    private var shareMessageRepository: ShareMessageRepository { appContainer.shareMessageRepository }
    private var shareLinkCoordinator: ShareLinkCoordinator { ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository()) }
    private var feedStreamRepository: FeedStreamRepository { appContainer.feedStreamRepository }

    private var sortedEntries: [CircleIDEntry] {
        entries.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LT("ID（未发行）", "ID (Unreleased)", "ID（未リリース）"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Button {
                    circlePush(.idCreate)
                } label: {
                    Label(LT("发布 ID", "Post ID", "IDを投稿"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RaverTheme.card)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if sortedEntries.isEmpty {
                Spacer()
                ContentUnavailableView(
                    LT("还没有 ID 讨论", "No ID Discussion Yet", "IDディスカッションはまだありません"),
                    systemImage: "music.note.list",
                    description: Text(LT("点击右上角“发布 ID”，记录一首未发行歌曲。", "Tap “Post ID” to record an unreleased track.", "右上の「IDを投稿」をタップして未リリース曲を記録しましょう。"))
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedEntries) { entry in
                            idEntryCard(entry)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(RaverTheme.background)
        .operationBannerHost(horizontalPadding: 14)
        .task {
            await loadEntriesIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .circleIDDidCreate)) { notification in
            guard let entry = notification.object as? CircleIDEntry else { return }
            entries.insert(entry, at: 0)
            persistEntries()
        }
        .navigationDestination(item: $selectedDetailRoute) { route in
            if let entryBinding = bindingForEntry(id: route.id) {
                CircleIDDetailView(
                    entry: entryBinding,
                    onPersist: {
                        persistEntries()
                    }
                )
                .environmentObject(appState)
                .environmentObject(appContainer)
            } else {
                VStack(spacing: 12) {
                    Text(LT("该 ID 已不存在", "This ID no longer exists", "このIDは存在しません"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    Button(LT("返回", "Back", "戻る")) {
                        selectedDetailRoute = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            }
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadCircleIDSharePanelConversations(using: shareMessageRepository)
                },
                onShareToConversation: { conversation in
                    try await sendCircleIDSharePayload(
                        presentation.payload,
                        using: shareMessageRepository,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                errorMessage = nil
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                CircleIDSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, blocked in
                showWidgetStatusBanner(
                    message: blocked
                        ? LT("举报已提交，并已拉黑该用户", "Report submitted and user blocked", "報告を送信し、このユーザーをブロックしました")
                        : LT("举报已提交", "Report submitted", "報告を送信しました")
                )
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(for: presentation.payload),
                        loadConversations: {
                            try await loadCircleIDSharePanelConversations(using: shareMessageRepository)
                        },
                        onSendToConversation: { conversation, note in
                            try await sendCircleIDSharePayload(
                                presentation.payload,
                                using: shareMessageRepository,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        errorMessage = nil
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
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
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func idEntryCard(_ entry: CircleIDEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text(entry.songName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                Spacer(minLength: 0)

                Button {
                    selectedDetailRoute = CircleIDDetailRoute(id: entry.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            CircleIDCardPlayerView(
                songName: entry.songName,
                audioURLString: entry.audioUrl,
                videoURLString: entry.videoUrl
            )

            if let event = entry.event {
                Button {
                    appPush(.eventDetail(eventID: event.id))
                } label: {
                    HStack(spacing: 10) {
                        circleIDEventCover(event)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(2)
                            Text(circleIDEventScheduleText(event))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if !entry.djs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.djs) { dj in
                        Button {
                            appPush(.djDetail(djID: dj.id))
                        } label: {
                            HStack(spacing: 8) {
                                circleIDDJAvatar(dj, size: 24)
                                Text(dj.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                circleIDActionButton(
                    icon: reactionContainsUser(entry.likedUserIDs) ? "heart.fill" : "heart",
                    count: entry.likedUserIDs.count,
                    isActive: reactionContainsUser(entry.likedUserIDs)
                ) {
                    toggleReaction(for: entry.id, reaction: .like)
                }

                circleIDActionButton(
                    icon: reactionContainsUser(entry.favoritedUserIDs) ? "star.fill" : "star",
                    count: entry.favoritedUserIDs.count,
                    isActive: reactionContainsUser(entry.favoritedUserIDs)
                ) {
                    toggleReaction(for: entry.id, reaction: .favorite)
                }

                circleIDActionButton(
                    icon: reactionContainsUser(entry.repostedUserIDs) ? "arrow.2.squarepath.circle.fill" : "arrow.2.squarepath.circle",
                    count: entry.repostedUserIDs.count,
                    isActive: reactionContainsUser(entry.repostedUserIDs)
                ) {
                    toggleReaction(for: entry.id, reaction: .repost)
                }

                circleIDActionButton(
                    icon: "text.bubble",
                    count: entry.comments.count,
                    isActive: false
                ) {
                    selectedDetailRoute = CircleIDDetailRoute(id: entry.id)
                }
            }

            HStack(spacing: 8) {
                Button {
                    appPush(.userProfile(userID: entry.contributor.id))
                } label: {
                    HStack(spacing: 8) {
                        circleIDUserAvatar(entry.contributor, size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.contributor.shownName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                            Text(LT("贡献者", "Contributor", "投稿者"))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text(entry.createdAt.feedTimeText)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDetailRoute = CircleIDDetailRoute(id: entry.id)
        }
    }

    private func circleIDActionButton(
        icon: String,
        count: Int,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isActive ? RaverTheme.accent : RaverTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background((isActive ? RaverTheme.accent.opacity(0.14) : RaverTheme.cardBorder.opacity(0.42)))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func circleIDUserAvatar(_ user: CircleIDUserSnapshot, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(resolvedCircleIDAvatarURL(for: user)),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(circleIDUserAvatarFallback(user: user, size: size))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            circleIDUserAvatarFallback(user: user, size: size)
        }
    }

    private func circleIDUserAvatarFallback(user: CircleIDUserSnapshot, size: CGFloat) -> some View {
        AvatarPlaceholderView(size: size)
    }

    private func resolvedCircleIDAvatarURL(for user: CircleIDUserSnapshot) -> String? {
        let snapshotAvatar = user.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !snapshotAvatar.isEmpty {
            return snapshotAvatar
        }
        guard let sessionUser = appState.session?.user, sessionUser.id == user.id else {
            return nil
        }
        let sessionAvatar = sessionUser.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return sessionAvatar.isEmpty ? nil : sessionAvatar
    }

    @ViewBuilder
    private func circleIDDJAvatar(_ dj: CircleIDDJSnapshot, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedDJAvatarURLString(dj.avatarSmallUrl ?? dj.avatarUrl, size: .small),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(circleIDDJAvatarFallback(dj: dj, size: size))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            circleIDDJAvatarFallback(dj: dj, size: size)
        }
    }

    private func circleIDDJAvatarFallback(dj: CircleIDDJSnapshot, size: CGFloat) -> some View {
        DefaultDJAvatarPlaceholderView(size: size, backgroundColor: RaverTheme.cardBorder)
    }

    @ViewBuilder
    private func circleIDEventCover(_ event: CircleIDEventSnapshot) -> some View {
        if let resolved = AppConfig.resolvedURLString(event.coverImageUrl),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RaverTheme.cardBorder))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RaverTheme.cardBorder)
        }
    }

    private func circleIDEventScheduleText(_ event: CircleIDEventSnapshot) -> String {
        event.startDate.appLocalizedDateRangeText(to: event.endDate)
    }

    private func reactionContainsUser(_ userIDs: [String]) -> Bool {
        userIDs.contains(currentUserSnapshot().id)
    }

    private func toggleReaction(for entryID: String, reaction: CircleIDReaction) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let userID = currentUserSnapshot().id
        switch reaction {
        case .like:
            toggleUserID(userID, in: &entries[index].likedUserIDs)
        case .favorite:
            toggleUserID(userID, in: &entries[index].favoritedUserIDs)
        case .repost:
            toggleUserID(userID, in: &entries[index].repostedUserIDs)
        }
        persistEntries()
    }

    private func toggleUserID(_ userID: String, in userIDs: inout [String]) {
        if let index = userIDs.firstIndex(of: userID) {
            userIDs.remove(at: index)
        } else {
            userIDs.append(userID)
        }
    }

    private func loadEntriesIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadEntries()
        await loadApprovedEntriesFromServer()
    }

    @MainActor
    private func loadApprovedEntriesFromServer() async {
        do {
            let page = try await feedStreamRepository.fetchFeed(cursor: nil, mode: .latest, eventID: nil)
            let remoteEntries = page.posts.compactMap(CircleIDEntry.init(approvedPost:))
            guard !remoteEntries.isEmpty else { return }

            var mergedByID: [String: CircleIDEntry] = [:]
            for entry in entries {
                mergedByID[entry.id] = entry
            }
            for remote in remoteEntries {
                mergedByID[remote.id] = remote
            }
            entries = Array(mergedByID.values).sorted { $0.createdAt > $1.createdAt }
            persistEntries()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: CircleIDStorage.entriesKey) else {
            entries = []
            return
        }
        do {
            let decoded = try JSONDecoder.raver.decode([CircleIDEntry].self, from: data)
            let hydrated = hydrateEntriesForCurrentUser(decoded)
            entries = hydrated
            if hydrated != decoded {
                persistEntries()
            }
        } catch {
            entries = []
            errorMessage = error.userFacingMessage
        }
    }

    private func persistEntries() {
        do {
            let data = try JSONEncoder.raver.encode(entries)
            UserDefaults.standard.set(data, forKey: CircleIDStorage.entriesKey)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func currentUserSnapshot() -> CircleIDUserSnapshot {
        if let user = appState.session?.user {
            return CircleIDUserSnapshot(
                id: user.id,
                username: user.username,
                displayName: user.displayName,
                avatarURL: user.avatarURL
            )
        }
        let fallbackName = LT("游客", "Guest", "ゲスト")
        return CircleIDUserSnapshot(
            id: "local-guest",
            username: fallbackName,
            displayName: fallbackName,
            avatarURL: nil
        )
    }

    private func hydrateEntriesForCurrentUser(_ source: [CircleIDEntry]) -> [CircleIDEntry] {
        guard let sessionUser = appState.session?.user else { return source }
        let latest = CircleIDUserSnapshot(
            id: sessionUser.id,
            username: sessionUser.username,
            displayName: sessionUser.displayName,
            avatarURL: sessionUser.avatarURL
        )

        return source.map { entry in
            var copy = entry
            if copy.contributor.id == latest.id {
                copy.contributor = latest
            }
            copy.comments = copy.comments.map { comment in
                guard comment.author.id == latest.id else { return comment }
                var updated = comment
                updated.author = latest
                return updated
            }
            return copy
        }
    }

    private func bindingForEntry(id: String) -> Binding<CircleIDEntry>? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return $entries[index]
    }

    private func presentShareMorePanel(for entry: CircleIDEntry) {
        shareMorePresentation = CircleIDShareCardPresentation(payload: circleIDSharePayload(from: entry))
        isShareMorePanelVisible = false
    }

    private func dismissShareMorePanel(after completion: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            completion?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                errorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat 共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                errorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ 共有連携は未接続です。")
            }
        ]
    }

    private func shareMoreQuickActions(for payload: CircleIDShareCardPayload) -> [SharePanelQuickAction] {
        [
            SharePanelQuickAction(
                title: LT("复制链接", "Copy link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.26, green: 0.57, blue: 0.96)
            ) {
                Task { await copyCircleIDShareLink(payload) }
            },
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                Task { await openCircleIDQRCode(payload) }
            },
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openCircleIDPoster(payload) }
            },
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "海報を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                Task { await saveCircleIDPoster(payload) }
            },
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                reportTarget = ReportSheetTarget(
                    id: payload.entryID,
                    type: .circleID,
                    title: payload.songName,
                    preview: [payload.contributorName, payload.djNames.joined(separator: " · "), payload.eventName].compactMap { $0?.nilIfBlank }.joined(separator: " · "),
                    targetUserID: nil,
                    targetUserDisplayName: nil
                )
            }
        ]
    }

    @MainActor
    private func copyCircleIDShareLink(_ payload: CircleIDShareCardPayload) async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: circleIDShareTarget(from: payload))
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("已复制链接", "Link copied", "リンクをコピーしました")
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openCircleIDQRCode(_ payload: CircleIDShareCardPayload) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: circleIDShareTarget(from: payload), channel: "view_qr")
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openCircleIDPoster(_ payload: CircleIDShareCardPayload) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: circleIDShareTarget(from: payload), channel: "view_poster")
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("ID 海报由分享系统统一生成，标题、摘要和二维码都会跟随短链保持一致。", "ID posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "ID海報は共有システムで生成され、タイトル、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveCircleIDPoster(_ payload: CircleIDShareCardPayload) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: circleIDShareTarget(from: payload), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            errorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }
}

private struct CircleIDDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    @Binding var entry: CircleIDEntry
    let onPersist: () -> Void

    @State private var commentDraft = ""
    @State private var actionErrorMessage: String?
    @State private var shareMorePresentation: CircleIDShareCardPresentation?
    @State private var fullChatSharePresentation: CircleIDShareCardPresentation?
    @State private var reportTarget: ReportSheetTarget?
    @State private var isShareMorePanelVisible = false

    private var shareMessageRepository: ShareMessageRepository { appContainer.shareMessageRepository }
    private var shareLinkCoordinator: ShareLinkCoordinator { ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                CircleIDCardPlayerView(
                    songName: entry.songName,
                    audioURLString: entry.audioUrl,
                    videoURLString: entry.videoUrl
                )

                if !entry.djs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.djs) { dj in
                            Button {
                                dismissAndPush(.djDetail(djID: dj.id))
                            } label: {
                                HStack(spacing: 8) {
                                    circleIDDJAvatar(dj, size: 24)
                                    Text(dj.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let event = entry.event {
                    Button {
                        dismissAndPush(.eventDetail(eventID: event.id))
                    } label: {
                        HStack(spacing: 10) {
                            circleIDEventCover(event)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(2)
                                Text(circleIDEventScheduleText(event))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(10)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    reactionButton(
                        icon: reactionContainsCurrentUser(entry.likedUserIDs) ? "heart.fill" : "heart",
                        count: entry.likedUserIDs.count,
                        isActive: reactionContainsCurrentUser(entry.likedUserIDs)
                    ) {
                        toggleReaction(.like)
                    }

                    reactionButton(
                        icon: reactionContainsCurrentUser(entry.favoritedUserIDs) ? "star.fill" : "star",
                        count: entry.favoritedUserIDs.count,
                        isActive: reactionContainsCurrentUser(entry.favoritedUserIDs)
                    ) {
                        toggleReaction(.favorite)
                    }

                    reactionButton(
                        icon: reactionContainsCurrentUser(entry.repostedUserIDs) ? "arrow.2.squarepath.circle.fill" : "arrow.2.squarepath.circle",
                        count: entry.repostedUserIDs.count,
                        isActive: reactionContainsCurrentUser(entry.repostedUserIDs)
                    ) {
                        toggleReaction(.repost)
                    }

                    reactionButton(
                        icon: "text.bubble",
                        count: entry.comments.count,
                        isActive: false
                    ) {}
                }

                HStack(spacing: 8) {
                    Button {
                        dismissAndPush(.userProfile(userID: entry.contributor.id))
                    } label: {
                        HStack(spacing: 8) {
                            circleIDUserAvatar(entry.contributor, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.contributor.shownName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(1)
                                Text(LT("贡献者", "Contributor", "投稿者"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Text(entry.createdAt.feedTimeText)
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(LT("评论区", "Comments", "コメント欄"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)

                    if entry.comments.isEmpty {
                        Text(LT("还没有评论，来抢沙发吧。", "No comments yet. Be the first to write one.", "コメントはまだありません。最初のコメントを書きましょう。"))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        ForEach(entry.comments) { comment in
                            Button {
                                dismissAndPush(.userProfile(userID: comment.author.id))
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    circleIDUserAvatar(comment.author, size: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(comment.author.shownName)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(RaverTheme.primaryText)
                                        Text(comment.content)
                                            .font(.body)
                                            .foregroundStyle(RaverTheme.primaryText)
                                        Text(comment.createdAt.feedTimeText)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField(LT("说点什么...", "Say something...", "何か書いてください..."), text: $commentDraft)
                            .padding(12)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button(LT("发送", "Send", "送信")) {
                            addComment()
                        }
                        .buttonStyle(CompactPrimaryButtonStyle())
                        .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let actionErrorMessage {
                        Text(actionErrorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .padding(12)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(14)
            .padding(.bottom, 20)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("ID详情", "ID Detail", "ID詳細"))
        .operationBannerHost()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentShareMorePanel()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadCircleIDSharePanelConversations(using: shareMessageRepository)
                },
                onShareToConversation: { conversation in
                    try await sendCircleIDSharePayload(
                        presentation.payload,
                        using: shareMessageRepository,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                actionErrorMessage = nil
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                CircleIDSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, blocked in
                showWidgetStatusBanner(
                    message: blocked
                        ? LT("举报已提交，并已拉黑该用户", "Report submitted and user blocked", "報告を送信し、このユーザーをブロックしました")
                        : LT("举报已提交", "Report submitted", "報告を送信しました")
                )
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(for: presentation.payload),
                        loadConversations: {
                            try await loadCircleIDSharePanelConversations(using: shareMessageRepository)
                        },
                        onSendToConversation: { conversation, note in
                            try await sendCircleIDSharePayload(
                                presentation.payload,
                                using: shareMessageRepository,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        actionErrorMessage = nil
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
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
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    private func reactionButton(icon: String, count: Int, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isActive ? RaverTheme.accent : RaverTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background((isActive ? RaverTheme.accent.opacity(0.14) : RaverTheme.cardBorder.opacity(0.42)))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func toggleReaction(_ reaction: CircleIDReaction) {
        let userID = currentUserSnapshot().id
        switch reaction {
        case .like:
            toggleUserID(userID, in: &entry.likedUserIDs)
        case .favorite:
            toggleUserID(userID, in: &entry.favoritedUserIDs)
        case .repost:
            toggleUserID(userID, in: &entry.repostedUserIDs)
        }
        onPersist()
    }

    private func toggleUserID(_ userID: String, in userIDs: inout [String]) {
        if let index = userIDs.firstIndex(of: userID) {
            userIDs.remove(at: index)
        } else {
            userIDs.append(userID)
        }
    }

    private func reactionContainsCurrentUser(_ userIDs: [String]) -> Bool {
        userIDs.contains(currentUserSnapshot().id)
    }

    private func addComment() {
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = CircleIDComment(
            id: UUID().uuidString,
            author: currentUserSnapshot(),
            content: trimmed,
            createdAt: Date()
        )
        entry.comments.append(comment)
        commentDraft = ""
        onPersist()
    }

    private func dismissAndPush(_ route: AppRoute) {
        dismiss()
        DispatchQueue.main.async {
            appPush(route)
        }
    }

    private func currentUserSnapshot() -> CircleIDUserSnapshot {
        if let user = appState.session?.user {
            return CircleIDUserSnapshot(
                id: user.id,
                username: user.username,
                displayName: user.displayName,
                avatarURL: user.avatarURL
            )
        }
        let fallbackName = LT("游客", "Guest", "ゲスト")
        return CircleIDUserSnapshot(
            id: "local-guest",
            username: fallbackName,
            displayName: fallbackName,
            avatarURL: nil
        )
    }

    private func circleIDEventScheduleText(_ event: CircleIDEventSnapshot) -> String {
        event.startDate.appLocalizedDateRangeText(to: event.endDate)
    }

    @ViewBuilder
    private func circleIDEventCover(_ event: CircleIDEventSnapshot) -> some View {
        if let resolved = AppConfig.resolvedURLString(event.coverImageUrl),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RaverTheme.cardBorder))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RaverTheme.cardBorder)
        }
    }

    @ViewBuilder
    private func circleIDDJAvatar(_ dj: CircleIDDJSnapshot, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedDJAvatarURLString(dj.avatarSmallUrl ?? dj.avatarUrl, size: .small),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(circleIDDJAvatarFallback(dj: dj, size: size))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            circleIDDJAvatarFallback(dj: dj, size: size)
        }
    }

    private func circleIDDJAvatarFallback(dj: CircleIDDJSnapshot, size: CGFloat) -> some View {
        DefaultDJAvatarPlaceholderView(size: size, backgroundColor: RaverTheme.cardBorder)
    }

    @ViewBuilder
    private func circleIDUserAvatar(_ user: CircleIDUserSnapshot, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(resolvedCircleIDAvatarURL(for: user)),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(circleIDUserAvatarFallback(user: user, size: size))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            circleIDUserAvatarFallback(user: user, size: size)
        }
    }

    private func circleIDUserAvatarFallback(user: CircleIDUserSnapshot, size: CGFloat) -> some View {
        AvatarPlaceholderView(size: size)
    }

    private func resolvedCircleIDAvatarURL(for user: CircleIDUserSnapshot) -> String? {
        let snapshotAvatar = user.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !snapshotAvatar.isEmpty {
            return snapshotAvatar
        }
        guard let sessionUser = appState.session?.user, sessionUser.id == user.id else {
            return nil
        }
        let sessionAvatar = sessionUser.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return sessionAvatar.isEmpty ? nil : sessionAvatar
    }

    private func presentShareMorePanel() {
        shareMorePresentation = CircleIDShareCardPresentation(payload: circleIDSharePayload(from: entry))
        isShareMorePanelVisible = false
    }

    private func dismissShareMorePanel(after completion: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            completion?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { conversation in
                .custom(title: LT("点击跳转", "Open chat", "タップしてチャットを開く")) {
                    dismissAndPush(.conversation(target: .fromConversation(conversation)))
                }
            } ?? .none
        )
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                actionErrorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat 共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                actionErrorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ 共有連携は未接続です。")
            }
        ]
    }

    private func shareMoreQuickActions(for payload: CircleIDShareCardPayload) -> [SharePanelQuickAction] {
        [
            SharePanelQuickAction(
                title: LT("复制链接", "Copy link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.26, green: 0.57, blue: 0.96)
            ) {
                Task { await copyCircleIDShareLink(payload) }
            },
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                Task { await openCircleIDQRCode(payload) }
            },
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openCircleIDPoster(payload) }
            },
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "海報を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                Task { await saveCircleIDPoster(payload) }
            },
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                reportTarget = ReportSheetTarget(
                    id: payload.entryID,
                    type: .circleID,
                    title: payload.songName,
                    preview: [payload.contributorName, payload.djNames.joined(separator: " · "), payload.eventName].compactMap { $0?.nilIfBlank }.joined(separator: " · "),
                    targetUserID: entry.contributor.id,
                    targetUserDisplayName: entry.contributor.shownName
                )
            }
        ]
    }

    @MainActor
    private func copyCircleIDShareLink(_ payload: CircleIDShareCardPayload) async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: circleIDShareTarget(from: payload))
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("已复制链接", "Link copied", "リンクをコピーしました")
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openCircleIDQRCode(_ payload: CircleIDShareCardPayload) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: circleIDShareTarget(from: payload), channel: "view_qr")
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openCircleIDPoster(_ payload: CircleIDShareCardPayload) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: circleIDShareTarget(from: payload), channel: "view_poster")
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("ID 海报由分享系统统一生成，标题、摘要和二维码都会跟随短链保持一致。", "ID posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "ID海報は共有システムで生成され、タイトル、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveCircleIDPoster(_ payload: CircleIDShareCardPayload) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: circleIDShareTarget(from: payload), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }
}

private struct CircleIDSharePreviewCard: View {
    let payload: CircleIDShareCardPayload

    var body: some View {
        ChatCircleIDSharePreviewContent(payload: payload)
    }
}

private struct CircleIDCardPlayerView: View {
    let songName: String
    let audioURLString: String?
    let videoURLString: String?

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var currentSeconds: Double = 0
    @State private var durationSeconds: Double = 0
    @State private var timeObserverToken: Any?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                    .background(RaverTheme.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(playbackURL == nil)

            VStack(alignment: .leading, spacing: 6) {
                Text(songName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)

                ProgressView(value: progress, total: 1)
                    .progressViewStyle(.linear)
                    .tint(RaverTheme.accent)

                Text(timeText(currentSeconds) + " / " + timeText(durationSeconds))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            preparePlayerIfNeeded()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    private var playbackURL: URL? {
        if let audio = validatedURL(from: audioURLString) { return audio }
        if let video = validatedURL(from: videoURLString) { return video }
        return nil
    }

    private func validatedURL(from raw: String?) -> URL? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let url = URL(string: raw), let scheme = url.scheme, !scheme.isEmpty else { return nil }
        return url
    }

    private func preparePlayerIfNeeded() {
        guard player == nil, let playbackURL else { return }
        let avPlayer = AVPlayer(url: playbackURL)
        player = avPlayer
        attachTimeObserver(to: avPlayer)
        updateDuration(from: avPlayer)
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }
        player.play()
        isPlaying = true
        updateDuration(from: player)
    }

    private func attachTimeObserver(to player: AVPlayer) {
        guard timeObserverToken == nil else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard let player else { return }
            currentSeconds = max(0, time.seconds)
            let duration = max(0, player.currentItem?.duration.seconds ?? 0)
            durationSeconds = duration
            if duration > 0 {
                progress = min(max(currentSeconds / duration, 0), 1)
            } else {
                progress = 0
            }
            isPlaying = player.timeControlStatus == .playing
        }
    }

    private func updateDuration(from player: AVPlayer) {
        durationSeconds = max(0, player.currentItem?.duration.seconds ?? 0)
        if durationSeconds <= 0 {
            progress = 0
            currentSeconds = 0
        }
    }

    private func cleanupPlayer() {
        player?.pause()
        isPlaying = false
        if let token = timeObserverToken, let player {
            player.removeTimeObserver(token)
        }
        timeObserverToken = nil
        player = nil
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "00:00" }
        let total = Int(seconds.rounded(.down))
        let minute = total / 60
        let second = total % 60
        return String(format: "%02d:%02d", minute, second)
    }
}

struct CircleIDComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    let onCreated: (CircleIDEntry) -> Void

    @State private var songName = ""
    @State private var audioUrl = ""
    @State private var videoUrl = ""
    @State private var selectedEvent: WebEvent?
    @State private var selectedDJs: [CircleIDDJSnapshot] = []
    @State private var showEventPicker = false
    @State private var showDJPicker = false
    @State private var errorMessage: String?
    @State private var rightsConfirmed = false

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LT("歌曲名", "Song Name", "曲名"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                        TextField(LT("例如：ID - Intro Edit", "e.g. ID - Intro Edit", "例: ID - Intro Edit"), text: $songName)
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LT("音频链接（可选）", "Audio URL (optional)", "音声URL（任意）"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                        TextField("https://", text: $audioUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LT("视频链接（可选）", "Video URL (optional)", "動画URL（任意）"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                        TextField("https://", text: $videoUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Toggle(isOn: $rightsConfirmed) {
                        Text(LT("我确认拥有发布该音乐/视频链接的权利，或确认链接来源合法且可公开引用。", "I confirm I have the right to post this music/video link, or that the link source is lawful and publicly referenceable.", "この音楽/動画リンクを投稿する権利がある、またはリンク元が合法で公開参照可能であることを確認します。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(LT("关联活动", "Linked Event", "関連イベント"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            Spacer()
                            Button(selectedEvent == nil ? LT("选择活动", "Select Event", "イベントを選択") : LT("更换活动", "Change Event", "イベントを変更")) {
                                showEventPicker = true
                            }
                            .buttonStyle(.bordered)
                        }

                        if let event = selectedEvent {
                            HStack(spacing: 8) {
                                Text(event.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(2)
                                Spacer()
                                Button(role: .destructive) {
                                    selectedEvent = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(LT("关联 DJ（可多选）", "Linked DJs (multi-select)", "関連DJ（複数選択可）"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            Spacer()
                            Button(LT("选择 DJ", "Select DJs", "DJを選択")) {
                                showDJPicker = true
                            }
                            .buttonStyle(.bordered)
                        }

                        if selectedDJs.isEmpty {
                            Text(LT("尚未选择 DJ", "No DJ selected", "DJが選択されていません"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(minimum: 0), spacing: 8, alignment: .leading),
                                    GridItem(.flexible(minimum: 0), spacing: 8, alignment: .leading)
                                ],
                                spacing: 8
                            ) {
                                ForEach(selectedDJs) { dj in
                                    HStack(spacing: 8) {
                                        DefaultDJAvatarPlaceholderView(size: 22, backgroundColor: RaverTheme.cardBorder)
                                        Text(dj.name)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(RaverTheme.primaryText)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                        Button(role: .destructive) {
                                            selectedDJs.removeAll { $0.id == dj.id }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 7)
                                    .background(RaverTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(RaverTheme.background)
            .raverSystemNavigation(title: LT("发布 ID", "Post ID", "IDを投稿"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("发布", "Post", "投稿")) {
                        createEntry()
                    }
                }
            }
            .navigationDestination(isPresented: $showEventPicker) {
                CircleIDEventPickerSheet { event in
                    selectedEvent = event
                }
            }
            .navigationDestination(isPresented: $showDJPicker) {
                CircleIDDJPickerSheet(selected: selectedDJs) { picked in
                    selectedDJs = picked
                }
            }
            .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(LT("确定", "OK", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private func createEntry() {
        let trimmedSongName = songName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAudioURL = audioUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVideoURL = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSongName.isEmpty else {
            errorMessage = LT("请填写歌曲名", "Please enter the song name", "曲名を入力してください")
            return
        }
        guard selectedEvent != nil else {
            errorMessage = LT("请先选择活动", "Please select an event", "先にイベントを選択してください")
            return
        }
        guard !selectedDJs.isEmpty else {
            errorMessage = LT("请至少选择一位 DJ", "Please select at least one DJ", "DJを少なくとも1人選択してください")
            return
        }
        guard !trimmedAudioURL.isEmpty || !trimmedVideoURL.isEmpty else {
            errorMessage = LT("请至少填写音频或视频链接", "Please provide at least one audio or video URL", "音声または動画URLを少なくとも1つ入力してください")
            return
        }
        guard rightsConfirmed else {
            errorMessage = LT("请先确认你拥有发布权利，或链接来源合法且可公开引用。", "Please confirm you have posting rights, or that the link source is lawful and publicly referenceable.", "投稿権利がある、またはリンク元が合法で公開参照可能であることを確認してください。")
            return
        }

        Task {
            await submitIDEntry(
                songName: trimmedSongName,
                audioURL: trimmedAudioURL,
                videoURL: trimmedVideoURL
            )
        }
    }

    @MainActor
    private func submitIDEntry(songName: String, audioURL: String, videoURL: String) async {
        let contributor = currentUserSnapshot()
        let eventSnapshot: CircleIDEventSnapshot?
        if let selectedEvent {
            eventSnapshot = CircleIDEventSnapshot(
                id: selectedEvent.id,
                name: selectedEvent.name,
                startDate: selectedEvent.startDate,
                endDate: selectedEvent.endDate,
                coverImageUrl: selectedEvent.coverImageUrl
            )
        } else {
            eventSnapshot = nil
        }

        let entry = CircleIDEntry(
            id: UUID().uuidString,
            songName: songName,
            event: eventSnapshot,
            djs: selectedDJs,
            audioUrl: audioURL.isEmpty ? nil : audioURL,
            videoUrl: videoURL.isEmpty ? nil : videoURL,
            contributor: contributor,
            createdAt: Date(),
            likedUserIDs: [],
            favoritedUserIDs: [],
            repostedUserIDs: [],
            comments: []
        )

        do {
            let payload: [String: ContentSubmissionJSONValue] = [
                "title": .string(songName),
                "songName": .string(songName),
                "audioUrl": audioURL.isEmpty ? .null : .string(audioURL),
                "videoUrl": videoURL.isEmpty ? .null : .string(videoURL),
                "images": .array([videoURL, eventSnapshot?.coverImageUrl ?? ""].compactMap { value -> ContentSubmissionJSONValue? in
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : .string(trimmed)
                }),
                "eventId": eventSnapshot.map { .string($0.id) } ?? .null,
                "eventName": eventSnapshot.map { .string($0.name) } ?? .null,
                "boundEventIDs": eventSnapshot.map { .array([.string($0.id)]) } ?? .array([]),
                "djIds": .array(selectedDJs.map { .string($0.id) }),
                "boundDjIDs": .array(selectedDJs.map { .string($0.id) }),
                "djNames": .array(selectedDJs.map { .string($0.name) }),
                "rightsConfirmed": .bool(true)
            ]
            _ = try await appContainer.webService.createContentSubmission(
                entityType: "id",
                payload: payload
            )
            OperationBannerCenter.shared.success(LT("ID 已提交审核", "ID submitted for review", "IDを審査に送信しました"))
        } catch {
            errorMessage = error.userFacingMessage
            return
        }

        onCreated(entry)
        dismiss()
    }

    private func currentUserSnapshot() -> CircleIDUserSnapshot {
        if let user = appState.session?.user {
            return CircleIDUserSnapshot(
                id: user.id,
                username: user.username,
                displayName: user.displayName,
                avatarURL: user.avatarURL
            )
        }
        let fallbackName = LT("游客", "Guest", "ゲスト")
        return CircleIDUserSnapshot(
            id: "local-guest",
            username: fallbackName,
            displayName: fallbackName,
            avatarURL: nil
        )
    }
}

private struct CircleIDEventPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var eventListRepository: EventListRepository { appContainer.eventListRepository }

    let onSelect: (WebEvent) -> Void

    @State private var events: [WebEvent] = []
    @State private var searchText = ""
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filteredEvents: [WebEvent] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return events
        }
        return events.filter { event in
            event.name.localizedCaseInsensitiveContains(keyword)
                || (event.city?.localizedCaseInsensitiveContains(keyword) ?? false)
                || (event.country?.localizedCaseInsensitiveContains(keyword) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
                TextField(LT("搜索活动名/城市/国家", "Search event/city/country", "イベント名/都市/国を検索"), text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                if phase == .idle || phase == .initialLoading {
                    Spacer()
                    SearchResultsSkeletonView()
                    Spacer()
                } else if case .failure(let message) = phase {
                    Spacer()
                    ScreenErrorCard(
                        title: LT("活动加载失败", "Events Failed to Load", "イベントの読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await loadEvents() }
                    }
                    .padding(.horizontal, 14)
                    Spacer()
                } else if case .offline(let message) = phase {
                    Spacer()
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message
                    ) {
                        Task { await loadEvents() }
                    }
                    .padding(.horizontal, 14)
                    Spacer()
                } else if filteredEvents.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        LT("没有匹配活动", "No Matching Events", "一致するイベントがありません"),
                        systemImage: "calendar.badge.exclamationmark"
                    )
                    Spacer()
                } else {
                    List(filteredEvents) { event in
                        Button {
                            onSelect(event)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(circleIDEventDateText(event))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .background(RaverTheme.background)
            .raverSystemNavigation(title: LT("选择活动", "Select Event", "イベントを選択"))
            .task {
                await loadEvents()
            }
    }

    private func circleIDEventDateText(_ event: WebEvent) -> String {
        "\(event.startDate.appLocalizedYMDHMText()) - \(event.endDate.appLocalizedYMDHMText())"
    }

    @MainActor
    private func loadEvents() async {
        if isLoading { return }
        isLoading = true
        phase = .initialLoading
        defer { isLoading = false }

        do {
            var page = 1
            var merged: [WebEvent] = []
            while page <= 6 {
                let result = try await eventListRepository.fetchEvents(
                    request: DiscoverEventsPageRequest(
                        page: page,
                        limit: 50,
                        search: nil,
                        eventType: nil,
                        status: nil
                    )
                )
                merged.append(contentsOf: result.items)
                let totalPages = result.pagination?.totalPages ?? page
                if result.items.isEmpty || page >= totalPages {
                    break
                }
                page += 1
            }

            let unique = Dictionary(merged.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            events = unique.values.sorted { lhs, rhs in
                lhs.startDate > rhs.startDate
            }
            phase = events.isEmpty ? .empty : .success
            errorMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("活动加载失败，请稍后重试", "Failed to load events. Please try again later.", "イベントを読み込めませんでした。時間をおいて再試行してください。")
            phase = .failure(message: message)
            errorMessage = message
        }
    }
}

private struct CircleIDDJPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var djListRepository: DJListRepository { appContainer.djListRepository }

    let selected: [CircleIDDJSnapshot]
    let onDone: ([CircleIDDJSnapshot]) -> Void

    @State private var djs: [WebDJ] = []
    @State private var selectedIDs: Set<String> = []
    @State private var searchText = ""
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filteredDJs: [WebDJ] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return djs
        }
        return djs.filter { dj in
            dj.name.localizedCaseInsensitiveContains(keyword)
                || (dj.aliases?.contains(where: { $0.localizedCaseInsensitiveContains(keyword) }) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
                TextField(LT("搜索 DJ 名称或别名", "Search DJ name or alias", "DJ名または別名を検索"), text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                if phase == .idle || phase == .initialLoading {
                    Spacer()
                    SearchResultsSkeletonView()
                    Spacer()
                } else if case .failure(let message) = phase {
                    Spacer()
                    ScreenErrorCard(
                        title: LT("DJ 加载失败", "DJs Failed to Load", "DJの読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await loadDJs() }
                    }
                    .padding(.horizontal, 14)
                    Spacer()
                } else if case .offline(let message) = phase {
                    Spacer()
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message
                    ) {
                        Task { await loadDJs() }
                    }
                    .padding(.horizontal, 14)
                    Spacer()
                } else if filteredDJs.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        LT("没有匹配 DJ", "No Matching DJs", "一致するDJがありません"),
                        systemImage: "person.crop.circle.badge.questionmark"
                    )
                    Spacer()
                } else {
                    List(filteredDJs) { dj in
                        Button {
                            toggleDJSelection(djID: dj.id)
                        } label: {
                            HStack(spacing: 10) {
                                circleIDDJAvatar(dj: dj, size: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dj.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    if let aliases = dj.aliases, !aliases.isEmpty {
                                        Text(aliases.prefix(2).joined(separator: " · "))
                                            .font(.caption2)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: selectedIDs.contains(dj.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(dj.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .background(RaverTheme.background)
            .raverSystemNavigation(title: LT("选择 DJ", "Select DJs", "DJを選択"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("完成", "Done", "完了")) {
                        finishSelection()
                    }
                }
            }
            .task {
                selectedIDs = Set(selected.map(\.id))
                await loadDJs()
            }
    }

    private func toggleDJSelection(djID: String) {
        if selectedIDs.contains(djID) {
            selectedIDs.remove(djID)
        } else {
            selectedIDs.insert(djID)
        }
    }

    private func finishSelection() {
        let fetchedByID = Dictionary(djs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let selectedByID = Dictionary(selected.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let snapshots = selectedIDs.compactMap { id -> CircleIDDJSnapshot? in
            if let dj = fetchedByID[id] {
                return CircleIDDJSnapshot(
                    id: dj.id,
                    name: dj.name,
                    avatarUrl: dj.avatarUrl,
                    avatarSmallUrl: dj.avatarSmallUrl
                )
            }
            return selectedByID[id]
        }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        onDone(snapshots)
        dismiss()
    }

    @ViewBuilder
    private func circleIDDJAvatar(dj: WebDJ, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedDJAvatarURLString(dj.avatarSmallUrl ?? dj.avatarUrl, size: .small),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(DefaultDJAvatarPlaceholderView(size: size, backgroundColor: RaverTheme.cardBorder))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            DefaultDJAvatarPlaceholderView(size: size, backgroundColor: RaverTheme.cardBorder)
        }
    }

    @MainActor
    private func loadDJs() async {
        if isLoading { return }
        isLoading = true
        phase = .initialLoading
        defer { isLoading = false }

        do {
            var page = 1
            var merged: [WebDJ] = []
            while page <= 6 {
                let result = try await djListRepository.fetchDJs(
                    page: page,
                    limit: 50,
                    search: nil,
                    sortBy: "name"
                )
                merged.append(contentsOf: result.items)
                let totalPages = result.pagination?.totalPages ?? page
                if result.items.isEmpty || page >= totalPages {
                    break
                }
                page += 1
            }

            let unique = Dictionary(merged.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            djs = unique.values.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            phase = djs.isEmpty ? .empty : .success
            errorMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("DJ 加载失败，请稍后重试", "Failed to load DJs. Please try again later.", "DJを読み込めませんでした。時間をおいて再試行してください。")
            phase = .failure(message: message)
            errorMessage = message
        }
    }
}

private struct SquadHallSnapshot {
    let squads: [SquadSummary]
    let mySquads: [SquadSummary]
    let squadProfilesByID: [String: SquadProfile]
}

private struct LoadSquadHallDataUseCase {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func execute(existingProfilesByID: [String: SquadProfile]) async throws -> SquadHallSnapshot {
        let loadedSquads = try await service.fetchRecommendedSquads()
            .sorted(by: { lhs, rhs in
                if lhs.isMember != rhs.isMember {
                    return lhs.isMember && !rhs.isMember
                }
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.id < rhs.id
            })
        let loadedMySquads = try await service.fetchMySquads()
            .sorted(by: { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.id < rhs.id
            })

        var mergedProfiles = existingProfilesByID
        let combinedByID = Dictionary(
            (loadedSquads + loadedMySquads).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for squad in combinedByID.values {
            if mergedProfiles[squad.id] != nil { continue }
            if let profile = try? await service.fetchSquadProfile(squadID: squad.id) {
                mergedProfiles[squad.id] = profile
            }
        }

        return SquadHallSnapshot(
            squads: loadedSquads,
            mySquads: loadedMySquads,
            squadProfilesByID: mergedProfiles
        )
    }
}

private struct SquadHallView: View {
    private enum SquadListMode: String, CaseIterable, Identifiable {
        case plaza
        case mine

        var id: String { rawValue }

        var title: String {
            switch self {
            case .plaza: return LT("小队广场", "Squad Plaza", "Squad 広場")
            case .mine: return LT("我的小队", "My Squads", "自分のSquad")
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.appPush) private var appPush

    @State private var squads: [SquadSummary] = []
    @State private var mySquads: [SquadSummary] = []
    @State private var squadProfilesByID: [String: SquadProfile] = [:]
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var showCreateSquad = false
    @State private var selectedMode: SquadListMode = .plaza
    @State private var bannerMessage: String?
    @State private var errorMessage: String?
    private let cardColumns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LT("小队广场", "Squad Plaza", "Squad 広場"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Button {
                    showCreateSquad = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline.weight(.bold))
                        Text(LT("创建小队", "Create Squad", "Squadを作成"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RaverTheme.card)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            HStack(spacing: 8) {
                ForEach(SquadListMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedMode = mode
                        }
                    } label: {
                        Text(mode.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedMode == mode ? Color.white : RaverTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(selectedMode == mode ? RaverTheme.accent : RaverTheme.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(selectedMode == mode ? Color.clear : RaverTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            if isRefreshing || bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新小队", "Updating squads", "Squadを更新中"))
                    }
                    if let bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
                        ) {
                            Task { await loadSquads() }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            switch phase {
            case .idle, .initialLoading:
                DiscoverGridSkeletonView()
            case .failure(let message), .offline(let message):
                Spacer()
                ScreenErrorCard(
                    title: LT("小队加载失败", "Squads Failed to Load", "Squadの読み込みに失敗しました"),
                    message: message
                ) {
                    Task { await loadSquads() }
                }
                .padding(.horizontal, 16)
                Spacer()
            case .empty:
                Spacer()
                ContentUnavailableView(
                    selectedMode == .mine ? LT("还没有加入小队", "Not Joined Any Squad Yet", "参加中のSquadはまだありません") : LT("暂无小队", "No Squads Yet", "Squadはまだありません"),
                    systemImage: "flag.2.crossed",
                    description: Text(selectedMode == .mine ? LT("去小队广场逛逛，加入你感兴趣的小队。", "Visit the squad square and join squads you like.", "Squad広場で気になるSquadに参加しましょう。") : LT("创建一个小队，和朋友一起记录活动。", "Create a squad and record events with friends.", "Squadを作成して、友達と一緒にイベントを記録しましょう。"))
                )
                Spacer()
            case .success:
                ScrollView {
                    LazyVGrid(columns: cardColumns, spacing: 14) {
                        ForEach(displayedSquads) { squad in
                            Button {
                                appPush(.squadProfile(squadID: squad.id))
                            } label: {
                                squadFlagCard(squad)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await loadSquads()
                }
            }
        }
        .background(RaverTheme.background)
        .task {
            await loadSquads()
        }
        .onAppear {
            Task { await loadSquads() }
        }
        .navigationDestination(isPresented: $showCreateSquad) {
            CreateSquadView(service: appContainer.socialService) { conversation in
                showCreateSquad = false
                appPush(.squadProfile(squadID: conversation.id))
                Task { await loadSquads() }
            }
            .environmentObject(appState)
        }
        .alert(LT("加载失败", "Load Failed", "読み込みに失敗しました"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("重试", "Retry", "再試行")) {
                Task { await loadSquads() }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var displayedSquads: [SquadSummary] {
        switch selectedMode {
        case .plaza:
            return squads
        case .mine:
            return mySquads
        }
    }

    @ViewBuilder
    private func squadBackgroundImage(_ squad: SquadSummary) -> some View {
        let bannerURL = AppConfig.resolvedURLString(squad.bannerURL)
        if let bannerURL,
           bannerURL.hasPrefix("http://") || bannerURL.hasPrefix("https://"),
           URL(string: bannerURL) != nil {
            ImageLoaderView(urlString: bannerURL)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.63, blue: 0.32), Color(red: 0.87, green: 0.34, blue: 0.29)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.63, blue: 0.32), Color(red: 0.87, green: 0.34, blue: 0.29)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func leaderUserSummary(for squad: SquadSummary) -> UserSummary? {
        squadProfilesByID[squad.id]?.leader
    }

    @ViewBuilder
    private func leaderAvatar(_ squad: SquadSummary) -> some View {
        if let leader = leaderUserSummary(for: squad) {
            if let resolved = AppConfig.resolvedURLString(leader.avatarURL),
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
               URL(string: resolved) != nil {
                ImageLoaderView(urlString: resolved)
                    .background(leaderAvatarFallback(leader))
                .clipShape(Circle())
            } else {
                leaderAvatarFallback(leader)
            }
        } else {
            Circle()
                .fill(Color.white.opacity(0.22))
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.white.opacity(0.9))
                )
        }
    }

    private func leaderAvatarFallback(_ leader: UserSummary) -> some View {
        AvatarPlaceholderView(size: 32, backgroundColor: Color.white.opacity(0.2))
    }

    private func squadIPText(_ squad: SquadSummary) -> String {
        // 当前数据模型暂未提供地区字段，先保留展示位以满足卡片结构。
        LT("IP地区：暂未公开", "IP region: not disclosed", "IP地域: 未公開")
    }

    private func squadFlagCard(_ squad: SquadSummary) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: 0, style: .continuous)

        return cardShape
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.63, blue: 0.32), Color(red: 0.87, green: 0.34, blue: 0.29)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(3 / 2, contentMode: .fit)
            .overlay {
                squadBackgroundImage(squad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.46),
                        Color.black.opacity(0.70),
                        Color.black.opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(squad.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        leaderAvatar(squad)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
                            )
                        Text(leaderLabelText(for: squad))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Text(squadIPText(squad))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)

                        Text("·")
                            .foregroundStyle(Color.white.opacity(0.72))

                        Text(LT("\(squad.memberCount) 人", "\(squad.memberCount) members", "\(squad.memberCount)人"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
            .clipShape(cardShape)
    }

    private func leaderLabelText(for squad: SquadSummary) -> String {
        if let name = leaderUserSummary(for: squad)?.displayName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return LT("队长 \(name)", "Leader \(name)", "リーダー \(name)")
        }
        return LT("队长", "Leader", "リーダー")
    }

    @MainActor
    private func loadSquads() async {
        if isLoading { return }
        let hadContent = !displayedSquads.isEmpty
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            let snapshot = try await LoadSquadHallDataUseCase(service: appContainer.socialService)
                .execute(existingProfilesByID: squadProfilesByID)

            squads = snapshot.squads
            mySquads = snapshot.mySquads
            squadProfilesByID = snapshot.squadProfilesByID
            phase = displayedSquads.isEmpty ? .empty : .success
            bannerMessage = nil
            errorMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("小队加载失败，请稍后重试", "Failed to load squads. Please try again later.", "Squadを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }
}

private struct SquadFlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 14
        var path = Path()

        path.move(to: CGPoint(x: radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius - 18, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 18, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX - 18, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius - 18, y: rect.maxY),
            control: CGPoint(x: rect.maxX - 18, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct TriangleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CircleRatingHubView: View {
    @Environment(\.circlePush) private var circlePush
    @EnvironmentObject private var appContainer: AppContainer
    private var ratingRepository: RatingRepository { appContainer.ratingRepository }

    @State private var events: [WebRatingEvent] = []
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var bannerMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(LT("事件驱动打分", "Event-driven ratings", "イベント連動評価"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Button {
                        circlePush(.ratingEventImportFromEvent)
                    } label: {
                        Label(LT("从活动导入", "Import from Event", "イベントから取り込む"), systemImage: "square.and.arrow.down")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RaverTheme.card)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        circlePush(.ratingEventCreate)
                    } label: {
                        Label(LT("发布事件", "Publish Event", "イベントを公開"), systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RaverTheme.card)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if isRefreshing || bannerMessage != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if isRefreshing {
                            InlineLoadingBadge(title: LT("正在更新打分事件", "Updating rating events", "評価イベントを更新中"))
                        }
                        if let bannerMessage {
                            ScreenStatusBanner(
                                message: bannerMessage,
                                style: .error,
                                actionTitle: LT("重试", "Retry", "再試行")
                            ) {
                                Task { await loadEvents() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if phase == .idle || phase == .initialLoading {
                    FeedSkeletonView(count: 3)
                        .padding(.top, 8)
                } else if case .failure(let message) = phase {
                    ScreenErrorCard(
                        title: LT("打分事件加载失败", "Rating Events Failed to Load", "評価イベントの読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await loadEvents() }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                } else if case .offline(let message) = phase {
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message
                    ) {
                        Task { await loadEvents() }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                } else if events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LT("还没有打分事件", "No rating events yet", "評価イベントはまだありません"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(LT("点击右上角“发布事件”，先创建一个事件，再在事件内添加打分单位。", "Tap “Publish Event” in the top-right corner to create an event first, then add rating units inside it.", "右上の「イベントを公開」から先にイベントを作成し、その中に評価ユニットを追加してください。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 14)
                } else {
                    ForEach(events) { event in
                        Button {
                            circlePush(.ratingEventDetail(event.id))
                        } label: {
                            eventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .raverTabBarBottomPadding(16)
        }
        .background(RaverTheme.background)
        .task {
            await loadEvents()
        }
        .onAppear {
            Task { await loadEvents() }
        }
        .refreshable {
            await loadEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .circleRatingEventDidCreate)) { notification in
            guard let created = notification.object as? WebRatingEvent else { return }
            if let index = events.firstIndex(where: { $0.id == created.id }) {
                events[index] = created
            } else {
                events.insert(created, at: 0)
            }
        }
    }

    private func eventCard(event: WebRatingEvent) -> some View {
        let ratedUnits = event.units.filter { $0.ratingCount > 0 }
        let average = ratedUnits.isEmpty
            ? 0
            : ratedUnits.map(\.rating).reduce(0, +) / Double(ratedUnits.count)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                RatingSquareImage(
                    imageURL: event.imageUrl,
                    fallbackSymbol: "sparkles.rectangle.stack.fill",
                    size: 72
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                    Text((event.description?.isEmpty == false ? event.description : LT("暂无事件描述", "No event description", "イベント説明はまだありません")) ?? LT("暂无事件描述", "No event description", "イベント説明はまだありません"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(3)
                    Text(LT("发布者：\(event.createdBy?.shownName ?? "匿名用户")", "Publisher: \(event.createdBy?.shownName ?? "Anonymous")", "投稿者: \(event.createdBy?.shownName ?? "匿名ユーザー")"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 2)
            }

            HStack(spacing: 8) {
                Label(LT("\(event.units.count) 个单位", "\(event.units.count) units", "\(event.units.count) 件のユニット"), systemImage: "square.grid.2x2")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text("·")
                    .foregroundStyle(RaverTheme.secondaryText.opacity(0.7))
                Text(
                    LT(
                        "均分 \(String(format: "%.1f", average))/10",
                        "Average \(String(format: "%.1f", average))/10",
                        "平均 \(String(format: "%.1f", average))/10"
                    )
                )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Spacer()
                HalfStarRatingReadOnlyView(score: average, maxScore: 10, starSize: 12, spacing: 2)
                    .allowsHitTesting(false)
            }
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 14)
    }

    @MainActor
    private func loadEvents() async {
        if isLoading { return }
        let hadContent = !events.isEmpty
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }
        do {
            events = try await ratingRepository.fetchRatingEvents()
            phase = events.isEmpty ? .empty : .success
            bannerMessage = nil
            errorMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("打分事件加载失败，请稍后重试", "Failed to load rating events. Please try again later.", "評価イベントを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }
}

struct CircleRatingEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @Environment(\.circlePush) private var circlePush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    private var ratingRepository: RatingRepository { appContainer.ratingRepository }

    let eventID: String
    let onClose: () -> Void
    let onUpdated: () -> Void

    @State private var event: WebRatingEvent?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var bannerMessage: String?
    @State private var shareMorePresentation: RatingDetailSharePresentation?
    @State private var fullChatSharePresentation: RatingDetailSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var actionErrorMessage: String?
    @State private var resolvedEventID: String?
    @State private var reportTarget: ReportSheetTarget?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    var body: some View {
        let _ = {
#if DEBUG
            let currentEventID = event?.id ?? "nil"
            let currentPhaseDescription: String
            switch phase {
            case .idle:
                currentPhaseDescription = "idle"
            case .initialLoading:
                currentPhaseDescription = "initialLoading"
            case .success:
                currentPhaseDescription = "success"
            case .empty:
                currentPhaseDescription = "empty"
            case .failure(let message):
                currentPhaseDescription = "failure(\(message))"
            case .offline(let message):
                currentPhaseDescription = "offline(\(message))"
            }
            print("[RatingEventResolve] render phase=\(currentPhaseDescription) eventNil=\(event == nil) eventID=\(currentEventID)")
#endif
        }()

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isRefreshing || bannerMessage != nil || actionErrorMessage != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if isRefreshing {
                            InlineLoadingBadge(title: LT("正在更新事件详情", "Updating event details", "イベント詳細を更新中"))
                        }
                        if let bannerMessage {
                            ScreenStatusBanner(
                                message: bannerMessage,
                                style: .error,
                                actionTitle: LT("重试", "Retry", "再試行")
                            ) {
                                Task { await loadEvent() }
                            }
                        }
                        if let actionErrorMessage {
                            ScreenStatusBanner(
                                message: actionErrorMessage,
                                style: .error,
                                actionTitle: nil
                            ) {}
                        }
                    }
                }

                if let event, phase == .success {
                    ratingEventHeaderCard(event)

                    if event.units.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LT("还没有打分单位", "No rating units yet", "評価ユニットはまだありません"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(LT("点击右上角更多，在这个事件下发布第一个打分单位。", "Use the top-right menu to publish the first rating unit for this event.", "右上のその他から、このイベントに最初の評価ユニットを公開してください。"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        ForEach(event.units) { unit in
                            Button {
                                appPush(.ratingUnitDetail(unitID: unit.id))
                            } label: {
                                ratingUnitRow(unit: unit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if phase == .idle || phase == .initialLoading {
                    EventDetailSkeletonView()
                } else if case .failure(let message) = phase {
                    ScreenErrorCard(
                        title: LT("事件加载失败", "Event Failed to Load", "イベントの読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await loadEvent() }
                    }
                } else if case .offline(let message) = phase {
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message
                    ) {
                        Task { await loadEvent() }
                    }
                } else if phase == .empty {
                    ContentUnavailableView(
                        LT("事件不存在", "Event Not Found", "イベントが見つかりません"),
                        systemImage: "sparkles.rectangle.stack"
                    )
                } else {
                    EventDetailSkeletonView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .raverTabBarBottomPadding(16)
        }
        .background(RaverTheme.background)
        .raverGradientNavigationChrome(
            title: LT("打分事件详情", "Rating Event Details", "評価イベント詳細"),
            trailing: RaverNavigationCircleIconButton(
                systemName: "ellipsis",
                style: .dimmed,
                action: {
                    presentShareMorePanel()
                },
                frameSize: 34,
                font: .headline.weight(.semibold)
            )
            .eraseToAnyView(),
            onBack: {
                onClose()
                dismiss()
            }
        )
        .operationBannerHost()
        .task {
            await loadEvent()
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadRatingSharePanelConversations(using: appContainer.shareMessageRepository)
                },
                onShareToConversation: { conversation in
                    try await sendRatingSharePayload(
                        presentation.payload,
                        using: appContainer.shareMessageRepository,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                actionErrorMessage = nil
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                RatingDetailSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, blocked in
                showWidgetStatusBanner(
                    message: blocked
                        ? LT("举报已提交，并已拉黑该用户", "Report submitted and user blocked", "報告を送信し、このユーザーをブロックしました")
                        : LT("举报已提交", "Report submitted", "報告を送信しました")
                )
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(),
                        loadConversations: {
                            try await loadRatingSharePanelConversations(using: appContainer.shareMessageRepository)
                        },
                        onSendToConversation: { conversation, note in
                            try await sendRatingSharePayload(
                                presentation.payload,
                                using: appContainer.shareMessageRepository,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        actionErrorMessage = nil
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
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
        .onDisappear {
            onUpdated()
        }
        .onReceive(NotificationCenter.default.publisher(for: .circleRatingUnitDidCreate)) { notification in
            guard
                let created = notification.object as? WebRatingUnit,
                let createdEventID = notification.userInfo?["eventID"] as? String,
                createdEventID == eventID
            else {
                return
            }
            guard event != nil else { return }
            if let index = event?.units.firstIndex(where: { $0.id == created.id }) {
                event?.units[index] = created
            } else {
                event?.units.append(created)
            }
            event?.updatedAt = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverRatingUnitDidUpdate)) { notification in
            guard let updatedUnitID = notification.object as? String else { return }
            guard event?.units.contains(where: { $0.id == updatedUnitID }) == true else { return }
            Task {
                await loadEvent()
                onUpdated()
            }
        }
    }

    @ViewBuilder
    private func ratingEventHeaderCard(_ event: WebRatingEvent) -> some View {
        let sourceEventID = event.sourceEventId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ratingEventHeaderCardContent(
            event,
            linkedEventID: sourceEventID.isEmpty ? nil : sourceEventID
        )
    }

    private func ratingEventHeaderCardContent(_ event: WebRatingEvent, linkedEventID: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                RatingSquareImage(
                    imageURL: event.imageUrl,
                    fallbackSymbol: "sparkles.rectangle.stack.fill",
                    size: 72
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text((event.description?.isEmpty == false ? event.description : LT("暂无事件描述", "No event description", "イベント説明はまだありません")) ?? LT("暂无事件描述", "No event description", "イベント説明はまだありません"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(4)
                    Text(LT("发布者：\(event.createdBy?.shownName ?? "匿名用户")", "Publisher: \(event.createdBy?.shownName ?? "Anonymous")", "投稿者: \(event.createdBy?.shownName ?? "匿名ユーザー")"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                if linkedEventID != nil {
                    Spacer(minLength: 0)
                    Button {
                        guard let linkedEventID else { return }
#if DEBUG
                        print("[RatingEventResolve] header-jump route=.eventDetail(\(linkedEventID)) sourceEventId=\(event.sourceEventId ?? "nil") ratingEventID=\(event.id)")
#endif
                        appPush(.eventDetail(eventID: linkedEventID))
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            if let linkedEventID {
                Button {
#if DEBUG
                    print("[RatingEventResolve] header-jump-banner route=.eventDetail(\(linkedEventID)) sourceEventId=\(event.sourceEventId ?? "nil") ratingEventID=\(event.id)")
#endif
                    appPush(.eventDetail(eventID: linkedEventID))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2.weight(.semibold))
                        Text(LT("进入对应电音节活动详情", "Open related festival event details", "対応する電子音楽フェスのイベント詳細へ"))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(RaverTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func ratingUnitRow(unit: WebRatingUnit) -> some View {
        HStack(alignment: .center, spacing: 10) {
            RatingSquareImage(
                imageURL: unit.imageUrl,
                fallbackSymbol: "music.mic",
                size: 50
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(unit.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Text((unit.description?.isEmpty == false ? unit.description : LT("暂无单位描述", "No unit description", "ユニット説明はまだありません")) ?? LT("暂无单位描述", "No unit description", "ユニット説明はまだありません"))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
                Text(LT("发布者：\(unit.createdBy?.shownName ?? "匿名用户")", "Publisher: \(unit.createdBy?.shownName ?? "Anonymous")", "投稿者: \(unit.createdBy?.shownName ?? "匿名ユーザー")"))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(unit.rating, specifier: "%.1f")")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Text(LT("\(unit.ratingCount) 人评分", "\(unit.ratingCount) ratings", "\(unit.ratingCount)件の評価"))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(10)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func loadEvent() async {
        if isLoading { return }
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
            let loadedEvent = try await resolveRatingEvent(for: eventID)
#if DEBUG
            print("[RatingEventResolve] load-success requestedID=\(eventID) loadedID=\(loadedEvent.id) name=\(loadedEvent.name) phase-before=\(phase)")
#endif
            event = loadedEvent
            resolvedEventID = loadedEvent.id
            phase = event == nil ? .empty : .success
            bannerMessage = nil
        } catch {
#if DEBUG
            print("[RatingEventResolve] load-failure requestedID=\(eventID) error=\(error)")
#endif
            let message = error.userFacingMessage ?? LT("事件加载失败，请稍后重试", "Failed to load event. Please try again later.", "イベントを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    private func resolveRatingEvent(for requestedID: String) async throws -> WebRatingEvent {
        do {
            let direct = try await ratingRepository.fetchRatingEvent(id: requestedID)
#if DEBUG
            print("[RatingEventResolve] direct-hit requestedID=\(requestedID) resolvedID=\(direct.id) sourceEventId=\(direct.sourceEventId ?? "nil")")
#endif
            return direct
        } catch {
#if DEBUG
            print("[RatingEventResolve] direct-miss requestedID=\(requestedID) error=\(error)")
#endif
        }

        let related = try await ratingRepository.fetchEventRatingEvents(eventID: requestedID)
        if let exactSourceMatch = related.first(where: {
            ($0.sourceEventId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") == requestedID
        }) {
#if DEBUG
            print("[RatingEventResolve] source-event-fallback requestedID=\(requestedID) resolvedID=\(exactSourceMatch.id)")
#endif
            return exactSourceMatch
        }
        if related.count == 1, let first = related.first {
#if DEBUG
            print("[RatingEventResolve] single-related-fallback requestedID=\(requestedID) resolvedID=\(first.id)")
#endif
            return first
        }

        throw ServiceError.message(
            LT("未找到对应的打分事件（请求 ID：\(requestedID)）", "Rating event not found (requested ID: \(requestedID))", "該当する評価イベントが見つかりません（リクエストID: \(requestedID)）")
        )
    }

    private func makeSharePayload() -> RatingDetailSharePayload {
        let current = event
        let shareID = current?.id ?? resolvedEventID ?? eventID
        return RatingDetailSharePayload(
            kind: .event,
            entityID: shareID,
            title: current?.name ?? LT("打分事件", "Rating Event", "評価イベント"),
            subtitle: current?.description?.nilIfBlank,
            coverImageURL: current?.imageUrl?.nilIfBlank,
            rating: nil,
            ratingCount: nil,
            deepLink: "raver://circle/rating-event/\(shareID)"
        )
    }

    private func presentShareMorePanel() {
        shareMorePresentation = RatingDetailSharePresentation(payload: makeSharePayload())
        isShareMorePanelVisible = false
    }

    private func dismissShareMorePanel(after completion: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            completion?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                actionErrorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat 共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                actionErrorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ 共有連携は未接続です。")
            }
        ]
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        [
            SharePanelQuickAction(
                title: LT("复制链接", "Copy Link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                Task { await copyRatingEventShareLink() }
            },
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                Task { await openRatingEventQRCode() }
            },
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openRatingEventPoster() }
            },
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "海報を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                Task { await saveRatingEventPoster() }
            },
            SharePanelQuickAction(
                title: LT("新增打分单位", "Add Rating Unit", "評価ユニットを追加"),
                systemImage: "plus.circle",
                accentColor: Color(red: 0.99, green: 0.65, blue: 0.20)
            ) {
                circlePush(.ratingUnitCreate(eventID: eventID))
            },
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                let payload = makeSharePayload()
                reportTarget = ReportSheetTarget(
                    id: payload.entityID,
                    type: .ratingEvent,
                    title: payload.title,
                    preview: payload.subtitle,
                    targetUserID: event?.createdBy?.id,
                    targetUserDisplayName: event?.createdBy?.shownName
                )
            }
        ]
    }

    @MainActor
    private func copyRatingEventShareLink() async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: ratingShareTarget(from: makeSharePayload()))
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("已复制链接", "Link copied", "リンクをコピーしました")
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openRatingEventQRCode() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: ratingShareTarget(from: makeSharePayload()), channel: "view_qr")
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openRatingEventPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: ratingShareTarget(from: makeSharePayload()), channel: "view_poster")
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("打分事件海报由分享系统统一生成，标题、摘要和二维码都会跟随短链保持一致。", "Rating event posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "評価イベント海報は共有システムで生成され、タイトル、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveRatingEventPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: ratingShareTarget(from: makeSharePayload()), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }
}

struct CircleRatingUnitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    private var socialService: SocialService { appContainer.socialService }
    private var ratingRepository: RatingRepository { appContainer.ratingRepository }

    let unitID: String
    let onSubmitted: () -> Void

    @State private var unit: WebRatingUnit?
    @State private var phase: LoadPhase = .idle
    @State private var commentDraft = ""
    @State private var draftScore: Double = 0
    @State private var myProfile: UserProfile?
    @State private var loadBannerMessage: String?
    @State private var actionErrorMessage: String?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var isSubmitting = false
    @State private var shareMorePresentation: RatingDetailSharePresentation?
    @State private var fullChatSharePresentation: RatingDetailSharePresentation?
    @State private var reportTarget: ReportSheetTarget?
    @State private var isShareMorePanelVisible = false

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isRefreshing || loadBannerMessage != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if isRefreshing {
                            InlineLoadingBadge(title: LT("正在更新评分单位", "Updating rating unit", "評価ユニットを更新中"))
                        }
                        if let loadBannerMessage {
                            ScreenStatusBanner(
                                message: loadBannerMessage,
                                style: .error,
                                actionTitle: LT("重试", "Retry", "再試行")
                            ) {
                                Task { await loadUnit() }
                            }
                        }
                    }
                }

                if let unit, phase == .success {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 10) {
                            RatingSquareImage(
                                imageURL: unit.imageUrl,
                                fallbackSymbol: "music.mic",
                                size: 72
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(unit.name)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text((unit.description?.isEmpty == false ? unit.description : LT("暂无单位描述", "No unit description", "ユニット説明はまだありません")) ?? LT("暂无单位描述", "No unit description", "ユニット説明はまだありません"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(3)
                                Text(LT("发布者：\(unit.createdBy?.shownName ?? "匿名用户")", "Publisher: \(unit.createdBy?.shownName ?? "Anonymous")", "投稿者: \(unit.createdBy?.shownName ?? "匿名ユーザー")"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        if let linkedDJs = unit.linkedDJs, !linkedDJs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LT("相关 DJ", "Related DJs", "関連DJ"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(linkedDJs) { dj in
                                            Button {
                                                appPush(.djDetail(djID: dj.id))
                                            } label: {
                                                VStack(spacing: 4) {
                                                    Group {
                                                        if let imageURL = AppConfig.resolvedDJAvatarURLString(dj.avatarSmallUrl ?? dj.avatarUrl, size: .small),
                                                           imageURL.hasPrefix("http://") || imageURL.hasPrefix("https://"),
                                                           URL(string: imageURL) != nil {
                                                            ImageLoaderView(urlString: imageURL)
                                                                .background(DefaultDJAvatarPlaceholderView(size: 34, backgroundColor: RaverTheme.cardBorder))
                                                        } else {
                                                            DefaultDJAvatarPlaceholderView(size: 34, backgroundColor: RaverTheme.cardBorder)
                                                        }
                                                    }
                                                    .frame(width: 34, height: 34)
                                                    .clipShape(Circle())

                                                    Text(dj.name)
                                                        .font(.caption2)
                                                        .foregroundStyle(RaverTheme.secondaryText)
                                                        .lineLimit(1)
                                                        .frame(maxWidth: 64)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LT("评分", "Rating", "評価"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        HalfStarDragRatingControl(
                            score: $draftScore,
                            maxScore: 10,
                            expandsToFullWidth: true
                        )
                    }
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LT("评论", "Comments", "コメント"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)

                        if unit.comments.isEmpty {
                            Text(LT("还没有评论，来写第一条吧", "No comments yet. Write the first one.", "コメントはまだありません。最初のコメントを書きましょう"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(unit.comments) { comment in
                                let author = resolvedAuthor(comment: comment)
                                HStack(alignment: .top, spacing: 10) {
                                    Button {
                                        appPush(.userProfile(userID: author.userID))
                                    } label: {
                                        ratingCommentAvatar(
                                            userID: author.userID,
                                            username: author.username,
                                            avatarURL: author.avatarURL
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(author.displayName)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(RaverTheme.secondaryText)
                                            HalfStarRatingReadOnlyView(
                                                score: comment.score,
                                                maxScore: 10,
                                                starSize: 10,
                                                spacing: 1.5
                                            )
                                        }
                                        Text(comment.content)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.primaryText)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                        }

                        HStack(spacing: 8) {
                            TextField(LT("写评论…", "Write a comment...", "コメントを書く…"), text: $commentDraft)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RaverTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Button(LT("发送", "Send", "送信")) {
                                Task {
                                    await addComment()
                                }
                            }
                            .buttonStyle(
                                CompactPrimaryButtonStyle(
                                    horizontalPadding: 12,
                                    verticalPadding: 7,
                                    cornerRadius: 10
                                )
                            )
                            .disabled(!canSendComment)
                        }

                        if let actionErrorMessage {
                            Text(actionErrorMessage)
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.9))
                        }
                    }
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if phase == .idle || phase == .initialLoading {
                    VStack(spacing: 12) {
                        EventDetailSkeletonView()
                        CommentSectionSkeletonView(count: 3)
                    }
                } else if case .failure(let message) = phase {
                    ScreenErrorCard(
                        title: LT("评分单位加载失败", "Rating Unit Failed to Load", "評価ユニットの読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await loadUnit() }
                    }
                } else if case .offline(let message) = phase {
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message
                    ) {
                        Task { await loadUnit() }
                    }
                } else if phase == .empty {
                    ContentUnavailableView(
                        LT("评分单位不存在", "Rating Unit Not Found", "評価ユニットが見つかりません"),
                        systemImage: "music.mic"
                    )
                } else {
                    VStack(spacing: 12) {
                        EventDetailSkeletonView()
                        CommentSectionSkeletonView(count: 3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .raverTabBarBottomPadding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("评论列表", "Comments", "コメント一覧"))
        .operationBannerHost()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentShareMorePanel()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .task {
            await loadUnit()
            await refreshMyProfile()
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadRatingSharePanelConversations(using: appContainer.shareMessageRepository)
                },
                onShareToConversation: { conversation in
                    try await sendRatingSharePayload(
                        presentation.payload,
                        using: appContainer.shareMessageRepository,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                actionErrorMessage = nil
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                RatingDetailSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, blocked in
                showWidgetStatusBanner(
                    message: blocked
                        ? LT("举报已提交，并已拉黑该用户", "Report submitted and user blocked", "報告を送信し、このユーザーをブロックしました")
                        : LT("举报已提交", "Report submitted", "報告を送信しました")
                )
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(),
                        loadConversations: {
                            try await loadRatingSharePanelConversations(using: appContainer.shareMessageRepository)
                        },
                        onSendToConversation: { conversation, note in
                            try await sendRatingSharePayload(
                                presentation.payload,
                                using: appContainer.shareMessageRepository,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        actionErrorMessage = nil
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
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

    private var canSendComment: Bool {
        !isSubmitting
            && !commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draftScore >= 1
    }

    private func resolvedAuthor(comment: WebRatingComment) -> (userID: String, username: String, displayName: String, avatarURL: String?) {
        if let user = comment.user {
            return (
                userID: user.id,
                username: user.username,
                displayName: user.shownName,
                avatarURL: user.avatarUrl
            )
        }
        if let myID = appState.session?.user.id, comment.userId == myID {
            return (
                userID: myID,
                username: myProfile?.username ?? appState.session?.user.username ?? "me",
                displayName: myProfile?.displayName ?? appState.session?.user.displayName ?? LT("我", "Me", "自分"),
                avatarURL: myProfile?.avatarURL ?? appState.session?.user.avatarURL
            )
        }
        return (
            userID: comment.userId,
            username: "user",
            displayName: LT("用户", "User", "ユーザー"),
            avatarURL: nil
        )
    }

    @ViewBuilder
    private func ratingCommentAvatar(userID: String, username: String, avatarURL: String?) -> some View {
        if let resolved = AppConfig.resolvedURLString(avatarURL),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(ratingCommentAvatarFallback(userID: userID, username: username, avatarURL: avatarURL))
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            ratingCommentAvatarFallback(userID: userID, username: username, avatarURL: avatarURL)
        }
    }

    private func ratingCommentAvatarFallback(userID: String, username: String, avatarURL: String?) -> some View {
        AvatarPlaceholderView(size: 34)
    }

    @MainActor
    private func refreshMyProfile() async {
        if let loaded = try? await socialService.fetchMyProfile() {
            myProfile = loaded
        }
    }

    @MainActor
    private func loadUnit() async {
        if isLoading { return }
        let hadContent = unit != nil
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }
        do {
            unit = try await ratingRepository.fetchRatingUnit(id: unitID)
            phase = unit == nil ? .empty : .success
            loadBannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("评分单位加载失败，请稍后重试", "Failed to load rating unit. Please try again later.", "評価ユニットを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                loadBannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    @MainActor
    private func addComment() async {
        guard canSendComment else { return }
        guard var unit else { return }

        let content = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let score = min(10, max(1, draftScore.rounded()))
        guard !content.isEmpty else { return }
        guard score >= 1 else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let created = try await ratingRepository.addRatingComment(
                unitID: unitID,
                input: CreateRatingCommentInput(score: score, content: content)
            )
            unit.comments.insert(created, at: 0)
            let scores = unit.comments.map(\.score)
            unit.ratingCount = scores.count
            unit.rating = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            self.unit = unit

            commentDraft = ""
            draftScore = 0
            actionErrorMessage = nil
            onSubmitted()
        } catch {
            actionErrorMessage = error.userFacingMessage
        }
    }

    private func makeSharePayload() -> RatingDetailSharePayload {
        let current = unit
        return RatingDetailSharePayload(
            kind: .unit,
            entityID: unitID,
            title: current?.name ?? LT("打分单位", "Rating Unit", "評価ユニット"),
            subtitle: current?.event?.name ?? current?.description?.nilIfBlank,
            coverImageURL: current?.imageUrl?.nilIfBlank,
            rating: current?.rating,
            ratingCount: current?.ratingCount,
            deepLink: "raver://rating-unit/\(unitID)"
        )
    }

    private func presentShareMorePanel() {
        shareMorePresentation = RatingDetailSharePresentation(payload: makeSharePayload())
        isShareMorePanelVisible = false
    }

    private func dismissShareMorePanel(after completion: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            completion?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                actionErrorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat 共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                actionErrorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ 共有連携は未接続です。")
            }
        ]
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        [
            SharePanelQuickAction(
                title: LT("复制链接", "Copy Link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                Task { await copyRatingUnitShareLink() }
            },
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                Task { await openRatingUnitQRCode() }
            },
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openRatingUnitPoster() }
            },
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "海報を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                Task { await saveRatingUnitPoster() }
            },
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                let payload = makeSharePayload()
                reportTarget = ReportSheetTarget(
                    id: payload.entityID,
                    type: .ratingUnit,
                    title: payload.title,
                    preview: payload.subtitle,
                    targetUserID: unit?.createdBy?.id,
                    targetUserDisplayName: unit?.createdBy?.shownName
                )
            }
        ]
    }

    @MainActor
    private func copyRatingUnitShareLink() async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: ratingShareTarget(from: makeSharePayload()))
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("已复制链接", "Link copied", "リンクをコピーしました")
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openRatingUnitQRCode() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: ratingShareTarget(from: makeSharePayload()), channel: "view_qr")
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openRatingUnitPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: ratingShareTarget(from: makeSharePayload()), channel: "view_poster")
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("打分单位海报由分享系统统一生成，标题、摘要和二维码都会跟随短链保持一致。", "Rating unit posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "評価ユニット海報は共有システムで生成され、タイトル、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveRatingUnitPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: ratingShareTarget(from: makeSharePayload()), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            actionErrorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }
}

private struct RatingDetailSharePayload: Identifiable {
    enum Kind {
        case event
        case unit
    }

    let id = UUID()
    let kind: Kind
    let entityID: String
    let title: String
    let subtitle: String?
    let coverImageURL: String?
    let rating: Double?
    let ratingCount: Int?
    let deepLink: String

    var tagTitle: String {
        switch kind {
        case .event:
            return LT("Rating Event", "Rating Event", "評価イベント")
        case .unit:
            return LT("Rating Unit", "Rating Unit", "評価ユニット")
        }
    }

    var iconName: String {
        switch kind {
        case .event:
            return "sparkles.rectangle.stack.fill"
        case .unit:
            return "music.mic"
        }
    }

    var summaryText: String {
        var lines = ["[\(tagTitle)] \(title)"]
        if let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !subtitle.isEmpty {
            lines.append(subtitle)
        }
        lines.append(deepLink)
        return lines.joined(separator: "\n")
    }

    var ratingEventCardPayload: RatingEventShareCardPayload? {
        guard kind == .event else { return nil }
        return RatingEventShareCardPayload(
            eventID: entityID,
            eventName: title,
            description: subtitle,
            coverImageURL: coverImageURL,
            badgeText: LT("Rating Event", "Rating Event", "評価イベント")
        )
    }

    var ratingUnitCardPayload: RatingUnitShareCardPayload? {
        guard kind == .unit else { return nil }
        return RatingUnitShareCardPayload(
            unitID: entityID,
            unitName: title,
            eventID: nil,
            eventName: subtitle,
            description: subtitle,
            coverImageURL: coverImageURL,
            rating: rating,
            ratingCount: ratingCount,
            badgeText: LT("Rating Unit", "Rating Unit", "評価ユニット")
        )
    }
}

private struct RatingDetailSharePresentation: Identifiable {
    let id = UUID()
    let payload: RatingDetailSharePayload
}

private struct RatingDetailSharePreviewCard: View {
    let payload: RatingDetailSharePayload

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.58, blue: 0.19),
                            Color(red: 0.84, green: 0.34, blue: 0.29)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: payload.iconName)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                )
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(payload.tagTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text(payload.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                if let subtitle = payload.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private func circleIDSharePayload(from entry: CircleIDEntry) -> CircleIDShareCardPayload {
    CircleIDShareCardPayload(
        entryID: entry.id,
        songName: entry.songName,
        contributorName: entry.contributor.shownName,
        djNames: entry.djs.map(\.name),
        eventName: entry.event?.name,
        coverImageURL: entry.event?.coverImageUrl?.nilIfBlank,
        hasVideo: entry.videoUrl?.nilIfBlank != nil,
        badgeText: "ID"
    )
}

private func loadCircleIDSharePanelConversations(using repository: ShareMessageRepository) async throws -> [Conversation] {
    async let directs = repository.fetchConversations(type: .direct)
    async let groups = repository.fetchConversations(type: .group)
    let merged = try await directs + groups
    let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
        partialResult[conversation.id] = conversation
    }
    return deduped.values.sorted {
        if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
        return $0.updatedAt > $1.updatedAt
    }
}

private func sendCircleIDSharePayload(
    _ payload: CircleIDShareCardPayload,
    using repository: ShareMessageRepository,
    to conversation: Conversation,
    note: String?
) async throws {
    _ = try await repository.sendCircleIDCardMessage(
        conversationID: conversation.id,
        payload: payload
    )

    let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedNote.isEmpty {
        _ = try await repository.sendMessage(
            conversationID: conversation.id,
            content: trimmedNote
        )
    }
}

private func circleIDShareTarget(from payload: CircleIDShareCardPayload) -> ShareTarget {
    let subtitle = ([payload.contributorName] + payload.djNames + [payload.eventName])
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .prefix(3)
        .joined(separator: " · ")
    let canonicalURL = "https://ravehub.top/circle/id/\(payload.entryID)"
    return ShareTarget(
        type: .circleID,
        id: payload.entryID,
        title: payload.songName,
        subtitle: subtitle.isEmpty ? nil : subtitle,
        imageURL: payload.coverImageURL,
        canonicalURL: canonicalURL,
        deepLink: "raver://circle/id/\(payload.entryID)",
        fallbackURL: canonicalURL,
        previewType: "content_card",
        visibility: "public"
    )
}

private func ratingShareTarget(from payload: RatingDetailSharePayload) -> ShareTarget {
    let canonicalPath: String
    let type: ShareTargetType
    switch payload.kind {
    case .event:
        canonicalPath = "rating-event/\(payload.entityID)"
        type = .ratingEvent
    case .unit:
        canonicalPath = "rating-unit/\(payload.entityID)"
        type = .ratingUnit
    }
    let canonicalURL = "https://ravehub.top/\(canonicalPath)"
    return ShareTarget(
        type: type,
        id: payload.entityID,
        title: payload.title,
        subtitle: payload.subtitle,
        imageURL: payload.coverImageURL,
        canonicalURL: canonicalURL,
        deepLink: payload.deepLink,
        fallbackURL: canonicalURL,
        previewType: "content_card",
        visibility: "public"
    )
}

private struct ChatCircleIDSharePreviewContent: View {
    let payload: CircleIDShareCardPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverImageURL = payload.coverImageURL?.nilIfBlank {
                ZStack(alignment: .bottomLeading) {
                    ImageLoaderView(urlString: coverImageURL)
                        .frame(height: 142)
                        .clipped()

                    LinearGradient(
                        colors: [Color.black.opacity(0.06), Color.black.opacity(0.48)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    if let badgeText = payload.badgeText?.nilIfBlank {
                        Text(badgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.24), in: Capsule())
                            .padding(12)
                    }

                    if payload.hasVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if payload.coverImageURL?.nilIfBlank == nil,
                   let badgeText = payload.badgeText?.nilIfBlank {
                    Text(badgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.songName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(3)

                Text(circleIDSharePreviewSubtitle(payload))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RaverTheme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RaverTheme.cardBorder.opacity(0.45), lineWidth: 1)
        )
    }
}

private func circleIDSharePreviewSubtitle(_ payload: CircleIDShareCardPayload) -> String {
    let joinedDJs = payload.djNames.joined(separator: " · ").nilIfBlank
    let parts = [
        joinedDJs,
        payload.eventName?.nilIfBlank,
        payload.contributorName.nilIfBlank
    ].compactMap { $0 }
    return parts.isEmpty ? LT("未发行歌曲分享", "Unreleased track share", "未リリース曲の共有") : parts.joined(separator: " · ")
}

private func loadRatingSharePanelConversations(using repository: ShareMessageRepository) async throws -> [Conversation] {
    async let directs = repository.fetchConversations(type: .direct)
    async let groups = repository.fetchConversations(type: .group)
    let merged = try await directs + groups
    let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
        partialResult[conversation.id] = conversation
    }
    return deduped.values.sorted {
        if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
        return $0.updatedAt > $1.updatedAt
    }
}

private func sendRatingSharePayload(
    _ payload: RatingDetailSharePayload,
    using repository: ShareMessageRepository,
    to conversation: Conversation,
    note: String?
) async throws {
    if let eventPayload = payload.ratingEventCardPayload {
        _ = try await repository.sendRatingEventCardMessage(
            conversationID: conversation.id,
            payload: eventPayload
        )
    } else if let unitPayload = payload.ratingUnitCardPayload {
        _ = try await repository.sendRatingUnitCardMessage(
            conversationID: conversation.id,
            payload: unitPayload
        )
    } else {
        _ = try await repository.sendMessage(
            conversationID: conversation.id,
            content: payload.summaryText
        )
    }

    let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedNote.isEmpty {
        _ = try await repository.sendMessage(
            conversationID: conversation.id,
            content: trimmedNote
        )
    }
}

struct CreateRatingEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var ratingRepository: RatingRepository { appContainer.ratingRepository }
    let onSubmit: (CreateRatingEventInput) async throws -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var imageURL = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var isSubmitting = false
    @State private var isUploadingCover = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
                Section(LT("基础信息", "Basic Info", "基本情報")) {
                    TextField(LT("事件名称", "Event Name", "イベント名"), text: $name)
                    TextField(LT("事件描述（选填）", "Event Description (optional)", "イベント説明（任意）"), text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(LT("封面图 URL（选填）", "Cover Image URL (optional)", "カバー画像URL（任意）"), text: $imageURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? LT("上传封面图", "Upload Cover", "カバー画像をアップロード") : LT("更换封面图", "Replace Cover", "カバー画像を変更"), systemImage: "photo")
                    }
                    if let selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if selectedCoverData != nil {
                        Text(LT("已选择本地封面图，发布时会自动上传并使用该图片。", "A local cover image is selected. It will be uploaded and used when publishing.", "ローカルカバー画像を選択済みです。公開時に自動アップロードして使用します。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                if let errorMessage {
                    Section {
                        FormStatusMessage(message: errorMessage)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .raverSystemNavigation(title: LT("发布打分事件", "Publish Rating Event", "評価イベントを公開"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("发布", "Publish", "公開")) {
                        Task { await submit() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || isUploadingCover)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
    }

    @MainActor
    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            var finalImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await ratingRepository.uploadRatingImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-event-cover-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    ratingEventID: nil,
                    ratingUnitID: nil,
                    usage: "event-cover"
                )
                finalImageURL = upload.url
            }

            try await onSubmit(
                CreateRatingEventInput(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: finalImageURL.isEmpty ? nil : finalImageURL
                )
            )
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
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
            errorMessage = LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像を読み込めませんでした。もう一度お試しください。")
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

struct CreateRatingEventFromEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var eventListRepository: EventListRepository { appContainer.eventListRepository }
    let onSubmit: (String) async throws -> Void

    @State private var searchKeyword = ""
    @State private var events: [WebEvent] = []
    @State private var selectedEventID: String?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        List {
                if phase == .idle || phase == .initialLoading {
                    HStack {
                        Spacer()
                        SearchResultsSkeletonView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if case .failure(let message) = phase {
                    ScreenErrorCard(
                        title: LT("活动加载失败", "Events Failed to Load", "イベントの読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await loadEvents() }
                    }
                    .listRowBackground(Color.clear)
                } else if case .offline(let message) = phase {
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message
                    ) {
                        Task { await loadEvents() }
                    }
                    .listRowBackground(Color.clear)
                } else if events.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LT("没有找到可导入活动", "No importable events found", "取り込めるイベントが見つかりません"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(LT("请尝试修改关键词，或先创建活动。", "Try a different keyword, or create an event first.", "キーワードを変更するか、先にイベントを作成してください。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(events) { event in
                        Button {
                            selectedEventID = event.id
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                RatingSquareImage(
                                    imageURL: event.coverImageUrl,
                                    fallbackSymbol: "sparkles.rectangle.stack.fill",
                                    size: 48
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Text("\(event.startDate.appLocalizedYMDHMText()) - \(event.endDate.appLocalizedYMDHMText())")
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(1)
                                    let addressText = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                                    Text(addressText.isEmpty ? LT("地点待补充", "Location pending", "場所は未設定") : addressText)
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: selectedEventID == event.id ? "checkmark.circle.fill" : "circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(selectedEventID == event.id ? RaverTheme.accent : RaverTheme.secondaryText.opacity(0.8))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    FormStatusMessage(message: errorMessage)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RaverTheme.background)
            .searchable(text: $searchKeyword, prompt: LT("搜索活动名称", "Search event name", "イベント名を検索"))
            .onSubmit(of: .search) {
                Task { await loadEvents() }
            }
            .raverSystemNavigation(title: LT("从活动导入打分", "Import Ratings from Event", "イベントから評価を取り込む"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSubmitting ? LT("导入中...", "Importing...", "取り込み中...") : LT("导入", "Import", "取り込む")) {
                        Task { await submit() }
                    }
                    .disabled(selectedEventID == nil || isSubmitting || isLoading)
                }
            }
            .task {
                await loadEvents()
            }
    }

    @MainActor
    private func loadEvents() async {
        if isLoading { return }
        isLoading = true
        phase = .initialLoading
        defer { isLoading = false }
        do {
            let response = try await eventListRepository.fetchEvents(
                request: DiscoverEventsPageRequest(
                    page: 1,
                    limit: 100,
                    search: searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines),
                    eventType: nil,
                    status: "all"
                )
            )
            events = response.items.sorted(by: { $0.startDate < $1.startDate })
            if let selectedEventID, !events.contains(where: { $0.id == selectedEventID }) {
                self.selectedEventID = nil
            }
            phase = events.isEmpty ? .empty : .success
            errorMessage = nil
        } catch {
            events = []
            let message = error.userFacingMessage ?? LT("活动加载失败，请稍后重试", "Failed to load events. Please try again later.", "イベントを読み込めませんでした。時間をおいて再試行してください。")
            phase = .failure(message: message)
            errorMessage = message
        }
    }

    @MainActor
    private func submit() async {
        guard let selectedEventID else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await onSubmit(selectedEventID)
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

struct CreateRatingUnitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var ratingRepository: RatingRepository { appContainer.ratingRepository }
    let eventID: String?
    let onSubmit: (CreateRatingUnitInput) async throws -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var imageURL = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var isSubmitting = false
    @State private var isUploadingCover = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
                Section(LT("单位信息", "Unit Info", "ユニット情報")) {
                    TextField(LT("单位名称", "Unit Name", "ユニット名"), text: $name)
                    TextField(LT("单位描述（选填）", "Unit Description (optional)", "ユニット説明（任意）"), text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(LT("图片 URL（选填）", "Image URL (optional)", "画像URL（任意）"), text: $imageURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? LT("上传单位图片", "Upload Unit Image", "ユニット画像をアップロード") : LT("更换单位图片", "Replace Unit Image", "ユニット画像を変更"), systemImage: "photo")
                    }
                    if let selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if selectedCoverData != nil {
                        Text(LT("已选择本地图片，发布时会自动上传并作为打分单位封面。", "A local image is selected. It will be uploaded and used as the rating unit cover.", "ローカル画像を選択済みです。公開時に自動アップロードして評価ユニットのカバーに使用します。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                if let errorMessage {
                    Section {
                        FormStatusMessage(message: errorMessage)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .raverSystemNavigation(title: LT("发布打分单位", "Publish Rating Unit", "評価ユニットを公開"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("发布", "Publish", "公開")) {
                        Task { await submit() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || isUploadingCover)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
    }

    @MainActor
    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            var finalImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await ratingRepository.uploadRatingImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-unit-cover-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    ratingEventID: eventID,
                    ratingUnitID: nil,
                    usage: "unit-cover"
                )
                finalImageURL = upload.url
            }

            try await onSubmit(
                CreateRatingUnitInput(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: finalImageURL.isEmpty ? nil : finalImageURL
                )
            )
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
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
            errorMessage = LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像を読み込めませんでした。もう一度お試しください。")
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

private struct HalfStarRatingReadOnlyView: View {
    let score: Double
    let maxScore: Double
    let starSize: CGFloat
    let spacing: CGFloat
    var expandsToFullWidth: Bool = false

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: symbolName(for: index))
                    .resizable()
                    .scaledToFit()
                    .frame(width: starSize, height: starSize)
                    .foregroundStyle(color(for: index))
                    .frame(maxWidth: expandsToFullWidth ? .infinity : nil)
            }
        }
    }

    private func symbolName(for index: Int) -> String {
        let normalized = normalizedScore
        if normalized >= Double(index) {
            return "star.fill"
        }
        if normalized >= Double(index) - 0.5 {
            return "star.leadinghalf.filled"
        }
        return "star"
    }

    private func color(for index: Int) -> Color {
        if normalizedScore >= Double(index) - 0.5 {
            return Color(red: 1.0, green: 0.73, blue: 0.20)
        }
        return Color.gray.opacity(0.45)
    }

    private var normalizedScore: Double {
        let safeMax = max(1, maxScore)
        let clamped = min(max(score, 0), safeMax)
        return clamped / 2
    }
}

private struct HalfStarDragRatingControl: View {
    @Binding var score: Double
    let maxScore: Double
    var expandsToFullWidth: Bool = false

    private let starSize: CGFloat = 24
    private let spacing: CGFloat = 6

    var body: some View {
        Group {
            if expandsToFullWidth {
                GeometryReader { proxy in
                    HalfStarRatingReadOnlyView(
                        score: score,
                        maxScore: maxScore,
                        starSize: starSize,
                        spacing: spacing,
                        expandsToFullWidth: true
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateScore(at: value.location.x, totalWidth: max(proxy.size.width, 1))
                            }
                    )
                }
                .frame(height: starSize)
            } else {
                HalfStarRatingReadOnlyView(
                    score: score,
                    maxScore: maxScore,
                    starSize: starSize,
                    spacing: spacing
                )
                .frame(width: controlWidth, height: starSize, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateScore(at: value.location.x, totalWidth: controlWidth)
                        }
                )
            }
        }
        .accessibilityLabel(LT("星级评分", "Star Rating", "星評価"))
        .accessibilityValue(LT("\(Int(score))/10 分", "\(Int(score))/10 points", "\(Int(score))/10 点"))
    }

    private var controlWidth: CGFloat {
        CGFloat(5) * starSize + CGFloat(4) * spacing
    }

    private func updateScore(at x: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        let clampedX = min(max(x, 0), totalWidth)
        let raw = Double(clampedX / totalWidth) * maxScore
        score = min(maxScore, max(0, raw.rounded()))
    }
}

private struct RatingSquareImage: View {
    let imageURL: String?
    let fallbackSymbol: String
    let size: CGFloat

    var body: some View {
        Group {
            if let imageURL = AppConfig.resolvedURLString(imageURL),
               imageURL.hasPrefix("http://") || imageURL.hasPrefix("https://"),
               URL(string: imageURL) != nil {
                ImageLoaderView(urlString: imageURL)
                    .background(placeholder)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(red: 0.24, green: 0.26, blue: 0.38), Color(red: 0.17, green: 0.55, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: fallbackSymbol)
                .font(.system(size: size * 0.33, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }
}
