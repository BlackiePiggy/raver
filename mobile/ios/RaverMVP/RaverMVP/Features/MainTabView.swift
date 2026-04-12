import SwiftUI
import PhotosUI
import UIKit
import AVKit

private struct RaverTabBarReservedHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var raverTabBarReservedHeight: CGFloat {
        get { self[RaverTabBarReservedHeightKey.self] }
        set { self[RaverTabBarReservedHeightKey.self] = newValue }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var router: AppRouter
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var tabBarIndicatorNamespace
    private let tabs: [MainTab] = [.discover, .circle, .messages, .profile]
    @State private var loadedTabs: Set<MainTab> = [.discover]

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContentContainer
                .zIndex(1)

            if !isTabBarHidden {
                customTabBar
                    .zIndex(2)
            }
        }
        .background(Color.black.opacity(0.05).ignoresSafeArea(.all))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            await appState.refreshUnreadMessages()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await appState.refreshUnreadMessages() }
        }
        .onAppear {
            loadedTabs.insert(currentTab)
        }
        .onChange(of: currentTab) { _, newTab in
            loadedTabs.insert(newTab)
        }
    }

    private var currentTab: MainTab {
        router.selectedTab
    }

    private var isTabBarHidden: Bool {
        guard currentTab != .discover else { return false }
        guard let topRoute = router.path.last else { return false }
        return topRoute.hidesTabBar
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
            MessagesCoordinatorView(repository: appContainer.messagesRepository)
        case .profile:
            ProfileCoordinatorView(repository: appContainer.profileSocialRepository)
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    router.switchTab(tab)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: currentTab == tab ? tab.selectedIcon : tab.icon)
                            .renderingMode(.template)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: currentTab == tab ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(currentTab == tab ? .white : .white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if currentTab == tab {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.52, green: 0.40, blue: 0.98).opacity(0.62),
                                            Color(red: 0.42, green: 0.29, blue: 0.90).opacity(0.56)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
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
                            Color(red: 0.10, green: 0.08, blue: 0.16).opacity(0.20),
                            Color(red: 0.15, green: 0.10, blue: 0.25).opacity(0.20)
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
                            Color.white.opacity(0.24),
                            Color(red: 0.72, green: 0.62, blue: 1.0).opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.46), radius: 18, x: 0, y: 10)
        .shadow(color: Color(red: 0.43, green: 0.30, blue: 0.92).opacity(0.24), radius: 12, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.bottom, bottomSafeAreaInset == 0 ? 4 : -14)
    }

}

private extension MainTab {
    var title: String {
        switch self {
        case .discover: return L("发现", "Discover")
        case .circle: return L("圈子", "Circle")
        case .messages: return L("消息", "Messages")
        case .profile: return L("我的", "Me")
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
            case .feed: return L("动态", "Feed")
            case .squads: return L("小队", "Squads")
            case .ids: return "ID"
            case .ratings: return L("打分", "Ratings")
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

private enum CircleIDReaction {
    case like
    case favorite
    case repost
}

private struct CircleIDDetailRoute: Identifiable, Hashable {
    let id: String
}

private struct CircleIDHubView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @Environment(\.circlePush) private var circlePush

    @State private var entries: [CircleIDEntry] = []
    @State private var hasLoaded = false
    @State private var selectedDetailRoute: CircleIDDetailRoute?
    @State private var errorMessage: String?

    private let storageKey = "circle.id.entries.v1"

    private var sortedEntries: [CircleIDEntry] {
        entries.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L("ID（未发行）", "ID (Unreleased)"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Button {
                    circlePush(.idCreate)
                } label: {
                    Label(L("发布 ID", "Post ID"), systemImage: "plus.circle.fill")
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
                    L("还没有 ID 讨论", "No ID Discussion Yet"),
                    systemImage: "music.note.list",
                    description: Text(L("点击右上角“发布 ID”，记录一首未发行歌曲。", "Tap “Post ID” to record an unreleased track."))
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
            } else {
                VStack(spacing: 12) {
                    Text(L("该 ID 已不存在", "This ID no longer exists"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    Button(L("返回", "Back")) {
                        selectedDetailRoute = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            }
        }
        .alert(LL("提示"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func idEntryCard(_ entry: CircleIDEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                            Text(L("贡献者", "Contributor"))
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
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: resolvedCircleIDAvatarURL(for: user)
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .background(RaverTheme.cardBorder)
        .clipShape(Circle())
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
        Circle()
            .fill(RaverTheme.cardBorder)
            .frame(width: size, height: size)
            .overlay(
                Text(String(dj.name.prefix(1)).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            )
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
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
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
            UserDefaults.standard.set(data, forKey: storageKey)
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
        let fallbackName = L("游客", "Guest")
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
}

private struct CircleIDDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState

    @Binding var entry: CircleIDEntry
    let onPersist: () -> Void

    @State private var commentDraft = ""

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
                                Text(L("贡献者", "Contributor"))
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
                    Text(LL("评论区"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)

                    if entry.comments.isEmpty {
                        Text(LL("还没有评论，来抢沙发吧。"))
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
                        TextField(L("说点什么...", "Say something..."), text: $commentDraft)
                            .padding(12)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button(L("发送", "Send")) {
                            addComment()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        .raverSystemNavigation(title: L("ID详情", "ID Detail"))
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
        let fallbackName = L("游客", "Guest")
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
        Circle()
            .fill(RaverTheme.cardBorder)
            .frame(width: size, height: size)
            .overlay(
                Text(String(dj.name.prefix(1)).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            )
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
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: resolvedCircleIDAvatarURL(for: user)
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .background(RaverTheme.cardBorder)
        .clipShape(Circle())
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

    let onCreated: (CircleIDEntry) -> Void

    @State private var songName = ""
    @State private var audioUrl = ""
    @State private var videoUrl = ""
    @State private var selectedEvent: WebEvent?
    @State private var selectedDJs: [CircleIDDJSnapshot] = []
    @State private var showEventPicker = false
    @State private var showDJPicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("歌曲名", "Song Name"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                        TextField(L("例如：ID - Intro Edit", "e.g. ID - Intro Edit"), text: $songName)
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("音频链接（可选）", "Audio URL (optional)"))
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
                        Text(L("视频链接（可选）", "Video URL (optional)"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                        TextField("https://", text: $videoUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L("关联活动", "Linked Event"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            Spacer()
                            Button(selectedEvent == nil ? L("选择活动", "Select Event") : L("更换活动", "Change Event")) {
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
                            Text(L("关联 DJ（可多选）", "Linked DJs (multi-select)"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            Spacer()
                            Button(L("选择 DJ", "Select DJs")) {
                                showDJPicker = true
                            }
                            .buttonStyle(.bordered)
                        }

                        if selectedDJs.isEmpty {
                            Text(L("尚未选择 DJ", "No DJ selected"))
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
                                        Circle()
                                            .fill(RaverTheme.cardBorder)
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                Text(String(dj.name.prefix(1)).uppercased())
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(RaverTheme.secondaryText)
                                            )
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
            .raverSystemNavigation(title: L("发布 ID", "Post ID"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("发布", "Post")) {
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
            .alert(LL("提示"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func createEntry() {
        let trimmedSongName = songName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAudioURL = audioUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVideoURL = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSongName.isEmpty else {
            errorMessage = L("请填写歌曲名", "Please enter the song name")
            return
        }
        guard selectedEvent != nil else {
            errorMessage = L("请先选择活动", "Please select an event")
            return
        }
        guard !selectedDJs.isEmpty else {
            errorMessage = L("请至少选择一位 DJ", "Please select at least one DJ")
            return
        }
        guard !trimmedAudioURL.isEmpty || !trimmedVideoURL.isEmpty else {
            errorMessage = L("请至少填写音频或视频链接", "Please provide at least one audio or video URL")
            return
        }

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
            songName: trimmedSongName,
            event: eventSnapshot,
            djs: selectedDJs,
            audioUrl: trimmedAudioURL.isEmpty ? nil : trimmedAudioURL,
            videoUrl: trimmedVideoURL.isEmpty ? nil : trimmedVideoURL,
            contributor: contributor,
            createdAt: Date(),
            likedUserIDs: [],
            favoritedUserIDs: [],
            repostedUserIDs: [],
            comments: []
        )

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
        let fallbackName = L("游客", "Guest")
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
    private var webService: WebFeatureService { appContainer.webService }

    let onSelect: (WebEvent) -> Void

    @State private var events: [WebEvent] = []
    @State private var searchText = ""
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
                TextField(L("搜索活动名/城市/国家", "Search event/city/country"), text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                if isLoading && events.isEmpty {
                    Spacer()
                    ProgressView(LL("加载活动中..."))
                    Spacer()
                } else if let errorMessage, events.isEmpty {
                    Spacer()
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                    Spacer()
                } else if filteredEvents.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        L("没有匹配活动", "No Matching Events"),
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
            .raverSystemNavigation(title: L("选择活动", "Select Event"))
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
        defer { isLoading = false }

        do {
            var page = 1
            var merged: [WebEvent] = []
            while page <= 6 {
                let result = try await webService.fetchEvents(
                    page: page,
                    limit: 50,
                    search: nil,
                    eventType: nil,
                    status: nil
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
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct CircleIDDJPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var webService: WebFeatureService { appContainer.webService }

    let selected: [CircleIDDJSnapshot]
    let onDone: ([CircleIDDJSnapshot]) -> Void

    @State private var djs: [WebDJ] = []
    @State private var selectedIDs: Set<String> = []
    @State private var searchText = ""
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
                TextField(L("搜索 DJ 名称或别名", "Search DJ name or alias"), text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                if isLoading && djs.isEmpty {
                    Spacer()
                    ProgressView(LL("加载 DJ 中..."))
                    Spacer()
                } else if let errorMessage, djs.isEmpty {
                    Spacer()
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                    Spacer()
                } else if filteredDJs.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        L("没有匹配 DJ", "No Matching DJs"),
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
            .raverSystemNavigation(title: L("选择 DJ", "Select DJs"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("完成", "Done")) {
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
                .background(
                    Circle()
                        .fill(RaverTheme.cardBorder)
                        .overlay(
                            Text(String(dj.name.prefix(1)).uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        )
                )
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.cardBorder)
                .frame(width: size, height: size)
                .overlay(
                    Text(String(dj.name.prefix(1)).uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        }
    }

    @MainActor
    private func loadDJs() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var page = 1
            var merged: [WebDJ] = []
            while page <= 6 {
                let result = try await webService.fetchDJs(
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
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
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
            case .plaza: return L("小队广场", "Squad Plaza")
            case .mine: return L("我的小队", "My Squads")
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.appPush) private var appPush

    @State private var squads: [SquadSummary] = []
    @State private var mySquads: [SquadSummary] = []
    @State private var squadProfilesByID: [String: SquadProfile] = [:]
    @State private var isLoading = false
    @State private var showCreateSquad = false
    @State private var selectedMode: SquadListMode = .plaza
    @State private var errorMessage: String?
    private let cardColumns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L("小队广场", "Squad Plaza"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Button {
                    showCreateSquad = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline.weight(.bold))
                        Text(L("创建小队", "Create Squad"))
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

            if isLoading && displayedSquads.isEmpty {
                Spacer()
                ProgressView(L("加载小队中...", "Loading squads..."))
                Spacer()
            } else if displayedSquads.isEmpty {
                Spacer()
                ContentUnavailableView(
                    selectedMode == .mine ? L("还没有加入小队", "Not Joined Any Squad Yet") : L("暂无小队", "No Squads Yet"),
                    systemImage: "flag.2.crossed",
                    description: Text(selectedMode == .mine ? L("去小队广场逛逛，加入你感兴趣的小队。", "Visit the squad square and join squads you like.") : L("创建一个小队，和朋友一起记录活动。", "Create a squad and record events with friends."))
                )
                Spacer()
            } else {
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
        .alert(L("加载失败", "Load Failed"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("重试", "Retry")) {
                Task { await loadSquads() }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
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
        let asset = AppConfig.resolvedUserAvatarAssetName(
            userID: leader.id,
            username: leader.username,
            avatarURL: leader.avatarURL
        )
        return Image(asset)
            .resizable()
            .scaledToFill()
            .background(Color.white.opacity(0.2))
            .clipShape(Circle())
    }

    private func squadIPText(_ squad: SquadSummary) -> String {
        // 当前数据模型暂未提供地区字段，先保留展示位以满足卡片结构。
        L("IP地区：暂未公开", "IP region: not disclosed")
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

                        Text(L("\(squad.memberCount) 人", "\(squad.memberCount) members"))
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
            return L("队长 \(name)", "Leader \(name)")
        }
        return L("队长", "Leader")
    }

    @MainActor
    private func loadSquads() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await LoadSquadHallDataUseCase(service: appContainer.socialService)
                .execute(existingProfilesByID: squadProfilesByID)

            squads = snapshot.squads
            mySquads = snapshot.mySquads
            squadProfilesByID = snapshot.squadProfilesByID
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
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
    private var service: WebFeatureService { appContainer.webService }

    @State private var events: [WebRatingEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(LL("事件驱动打分"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Button {
                        circlePush(.ratingEventImportFromEvent)
                    } label: {
                        Label(L("从活动导入", "Import from Event"), systemImage: "square.and.arrow.down")
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
                        Label(L("发布事件", "Publish Event"), systemImage: "plus")
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

                if isLoading && events.isEmpty {
                    ProgressView(LL("正在加载打分事件…"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if let errorMessage, events.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                } else if events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LL("还没有打分事件"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(LL("点击右上角“发布事件”，先创建一个事件，再在事件内添加打分单位。"))
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
            .padding(.bottom, 20)
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
                    Text((event.description?.isEmpty == false ? event.description : L("暂无事件描述", "No event description")) ?? L("暂无事件描述", "No event description"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(3)
                    Text(L("发布者：\(event.createdBy?.shownName ?? "匿名用户")", "Publisher: \(event.createdBy?.shownName ?? L("匿名用户", "Anonymous"))"))
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
                Label(L("\(event.units.count) 个单位", "\(event.units.count) units"), systemImage: "square.grid.2x2")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text("·")
                    .foregroundStyle(RaverTheme.secondaryText.opacity(0.7))
                Text(
                    L(
                        "均分 \(String(format: "%.1f", average))/10",
                        "Average \(String(format: "%.1f", average))/10"
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
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await service.fetchRatingEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

struct CircleRatingEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @Environment(\.circlePush) private var circlePush
    @EnvironmentObject private var appContainer: AppContainer
    private var service: WebFeatureService { appContainer.webService }

    let eventID: String
    let onClose: () -> Void
    let onUpdated: () -> Void

    @State private var event: WebRatingEvent?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let event {
                    ratingEventHeaderCard(event)

                    if event.units.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LL("还没有打分单位"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(LL("点击右上角 +，在这个事件下发布第一个打分单位。"))
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
                } else if isLoading {
                    ProgressView(LL("正在加载事件…"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    Text(errorMessage ?? L("事件不存在", "Event not found"))
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(RaverTheme.background)
        .raverGradientNavigationChrome(
            title: LL("打分事件详情"),
            trailing: Button {
                circlePush(.ratingUnitCreate(eventID: eventID))
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.36))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .eraseToAnyView(),
            onBack: {
                onClose()
                dismiss()
            }
        )
        .task {
            await loadEvent()
        }
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
        if !sourceEventID.isEmpty {
            Button {
                appPush(.eventDetail(eventID: sourceEventID))
            } label: {
                ratingEventHeaderCardContent(event, isLinkedToEvent: true)
            }
            .buttonStyle(.plain)
        } else {
            ratingEventHeaderCardContent(event, isLinkedToEvent: false)
        }
    }

    private func ratingEventHeaderCardContent(_ event: WebRatingEvent, isLinkedToEvent: Bool) -> some View {
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
                    Text((event.description?.isEmpty == false ? event.description : L("暂无事件描述", "No event description")) ?? L("暂无事件描述", "No event description"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(4)
                    Text(L("发布者：\(event.createdBy?.shownName ?? "匿名用户")", "Publisher: \(event.createdBy?.shownName ?? L("匿名用户", "Anonymous"))"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                if isLinkedToEvent {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.top, 2)
                }
            }

            if isLinkedToEvent {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2.weight(.semibold))
                    Text(LL("进入对应电音节活动详情"))
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(RaverTheme.accent)
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
                Text((unit.description?.isEmpty == false ? unit.description : L("暂无单位描述", "No unit description")) ?? L("暂无单位描述", "No unit description"))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
                Text(L("发布者：\(unit.createdBy?.shownName ?? "匿名用户")", "Publisher: \(unit.createdBy?.shownName ?? L("匿名用户", "Anonymous"))"))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(unit.rating, specifier: "%.1f")")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Text(L("\(unit.ratingCount) 人评分", "\(unit.ratingCount) ratings"))
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
        isLoading = true
        defer { isLoading = false }
        do {
            event = try await service.fetchRatingEvent(id: eventID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

struct CircleRatingUnitDetailView: View {
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    private var socialService: SocialService { appContainer.socialService }
    private var webService: WebFeatureService { appContainer.webService }

    let unitID: String
    let onSubmitted: () -> Void

    @State private var unit: WebRatingUnit?
    @State private var commentDraft = ""
    @State private var draftScore: Double = 0
    @State private var myProfile: UserProfile?
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let unit {
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
                                Text((unit.description?.isEmpty == false ? unit.description : L("暂无单位描述", "No unit description")) ?? L("暂无单位描述", "No unit description"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(3)
                                Text(L("发布者：\(unit.createdBy?.shownName ?? "匿名用户")", "Publisher: \(unit.createdBy?.shownName ?? L("匿名用户", "Anonymous"))"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        if let linkedDJs = unit.linkedDJs, !linkedDJs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LL("相关 DJ"))
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
                                                                .background(Circle().fill(RaverTheme.cardBorder))
                                                        } else {
                                                            Circle().fill(RaverTheme.cardBorder)
                                                                .overlay(
                                                                    Text(String(dj.name.prefix(1)).uppercased())
                                                                        .font(.caption.weight(.semibold))
                                                                        .foregroundStyle(RaverTheme.secondaryText)
                                                                )
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
                        Text(LL("评分"))
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
                        Text(LL("评论"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)

                        if unit.comments.isEmpty {
                            Text(LL("还没有评论，来写第一条吧"))
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
                            TextField(LL("写评论…"), text: $commentDraft)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RaverTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Button(L("发送", "Send")) {
                                Task {
                                    await addComment()
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(canSendComment ? RaverTheme.accent : RaverTheme.secondaryText)
                            .buttonStyle(.plain)
                            .disabled(!canSendComment)
                            .opacity(canSendComment ? 1 : 0.45)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.9))
                        }
                    }
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView(LL("正在加载评分单位…"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .padding(.bottom, 20)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LL("评论列表"))
        .toolbar(.visible, for: .navigationBar)
        .task {
            await loadUnit()
            await refreshMyProfile()
        }
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
                displayName: myProfile?.displayName ?? appState.session?.user.displayName ?? L("我", "Me"),
                avatarURL: myProfile?.avatarURL ?? appState.session?.user.avatarURL
            )
        }
        return (
            userID: comment.userId,
            username: "user",
            displayName: L("用户", "User"),
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
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: userID,
                username: username,
                avatarURL: avatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: 34, height: 34)
        .background(RaverTheme.cardBorder)
        .clipShape(Circle())
    }

    @MainActor
    private func refreshMyProfile() async {
        if let loaded = try? await socialService.fetchMyProfile() {
            myProfile = loaded
        }
    }

    @MainActor
    private func loadUnit() async {
        do {
            unit = try await webService.fetchRatingUnit(id: unitID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
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
            let created = try await webService.addRatingComment(
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
            errorMessage = nil
            onSubmitted()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

struct CreateRatingEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var webService: WebFeatureService { appContainer.webService }
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
        NavigationStack {
            Form {
                Section(LL("基础信息")) {
                    TextField(LL("事件名称"), text: $name)
                    TextField(LL("事件描述（选填）"), text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(LL("封面图 URL（选填）"), text: $imageURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? L("上传封面图", "Upload Cover") : L("更换封面图", "Replace Cover"), systemImage: "photo")
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
                        Text(LL("已选择本地封面图，发布时会自动上传并使用该图片。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
            }
            .raverSystemNavigation(title: L("发布打分事件", "Publish Rating Event"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("发布", "Publish")) {
                        Task { await submit() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || isUploadingCover)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
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
                let upload = try await webService.uploadRatingImage(
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
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
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
    private var webService: WebFeatureService { appContainer.webService }
    let onSubmit: (String) async throws -> Void

    @State private var searchKeyword = ""
    @State private var events: [WebEvent] = []
    @State private var selectedEventID: String?
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView(L("正在加载活动…", "Loading events..."))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if events.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LL("没有找到可导入活动"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(LL("请尝试修改关键词，或先创建活动。"))
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
                                    Text("\(event.city ?? L("未知城市", "Unknown City")) · \(event.country ?? L("未知国家", "Unknown Country"))")
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
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RaverTheme.background)
            .searchable(text: $searchKeyword, prompt: L("搜索活动名称", "Search event name"))
            .onSubmit(of: .search) {
                Task { await loadEvents() }
            }
            .raverSystemNavigation(title: L("从活动导入打分", "Import Ratings from Event"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSubmitting ? L("导入中...", "Importing...") : L("导入", "Import")) {
                        Task { await submit() }
                    }
                    .disabled(selectedEventID == nil || isSubmitting || isLoading)
                }
            }
            .task {
                await loadEvents()
            }
        }
    }

    @MainActor
    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await webService.fetchEvents(
                page: 1,
                limit: 100,
                search: searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines),
                eventType: nil,
                status: "all"
            )
            events = response.items.sorted(by: { $0.startDate < $1.startDate })
            if let selectedEventID, !events.contains(where: { $0.id == selectedEventID }) {
                self.selectedEventID = nil
            }
            errorMessage = nil
        } catch {
            events = []
            errorMessage = error.userFacingMessage
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
    private var webService: WebFeatureService { appContainer.webService }
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
        NavigationStack {
            Form {
                Section(LL("单位信息")) {
                    TextField(LL("单位名称"), text: $name)
                    TextField(LL("单位描述（选填）"), text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(LL("图片 URL（选填）"), text: $imageURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? L("上传单位图片", "Upload Unit Image") : L("更换单位图片", "Replace Unit Image"), systemImage: "photo")
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
                        Text(LL("已选择本地图片，发布时会自动上传并作为打分单位封面。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
            }
            .raverSystemNavigation(title: L("发布打分单位", "Publish Rating Unit"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("发布", "Publish")) {
                        Task { await submit() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || isUploadingCover)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
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
                let upload = try await webService.uploadRatingImage(
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
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
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
        .accessibilityLabel(L("星级评分", "Star Rating"))
        .accessibilityValue(L("\(Int(score))/10 分", "\(Int(score))/10 points"))
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
