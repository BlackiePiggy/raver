import SwiftUI
import Photos

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @Environment(\.profilePush) private var profilePush
    @ObservedObject private var viewModel: ProfileViewModel
    @Namespace private var profilePostTabNamespace
    @State private var isShowingRealNameSheet = false

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    init(viewModel: ProfileViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: L("重试", "Retry")
                        ) {
                            Task { await viewModel.load() }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            switch viewModel.phase {
            case .idle, .initialLoading:
                ProfileSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    VStack(spacing: 14) {
                        profileTopActions
                        ScreenErrorCard(message: message) {
                            Task { await viewModel.load() }
                        }
                        profileQuickActions
                    }
                    .padding(16)
                }
            case .empty:
                ScrollView {
                    VStack(spacing: 14) {
                        profileTopActions
                        ContentUnavailableView(
                            L("离线模式", "Offline Mode"),
                            systemImage: "wifi.slash",
                            description: Text(L("网络不可用，已切换离线入口。你仍可进入我的行程和小工具。", "Network unavailable. Switched to offline entry. You can still access My Routes and Tools."))
                        )

                        profileQuickActions
                    }
                    .padding(16)
                }
            case .success:
                if let profile = viewModel.profile {
                    ScrollView {
                        VStack(spacing: 14) {
                            profileTopActions

                            ProfileHeaderCard(
                                profile: profile,
                                appearance: viewModel.appearance,
                                realNameStatus: appState.realNameVerificationStatus,
                                onAvatarTap: {
                                    profilePush(.avatarFullscreen)
                                },
                                onRealNameTap: {
                                    isShowingRealNameSheet = true
                                },
                                onFollowersTap: {
                                    profilePush(.followList(userID: currentUserID, kind: .followers))
                                },
                                onFollowingTap: {
                                    profilePush(.followList(userID: currentUserID, kind: .following))
                                },
                                onFriendsTap: {
                                    profilePush(.followList(userID: currentUserID, kind: .friends))
                                }
                            )

                            ProfileRecentCheckinsCard(
                                title: L("我的近期打卡", "My Recent Check-ins"),
                                checkins: viewModel.recentCheckins,
                                emptyText: L("去发现页完成活动或 DJ 打卡，记录会显示在这里。", "Complete event or DJ check-ins from Discover. Records will appear here.")
                            ) {
                                profilePush(.myCheckins(
                                    targetUserID: nil,
                                    title: L("我的打卡", "My Check-ins"),
                                    ownerDisplayName: viewModel.profile?.displayName
                                ))
                            }

                            profileQuickActions

                            sectionContent
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await viewModel.refreshSection()
                    }
                } else {
                    ProfileSkeletonView()
                }
            }
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $isShowingRealNameSheet) {
            RealNameVerificationSheet()
                .environmentObject(appState)
                .presentationDetents([.large])
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @ViewBuilder
    private var profileTopActions: some View {
        if viewModel.profile != nil {
            HStack {
                profileTopIconButton(
                    systemName: "square.and.pencil",
                    accessibilityLabel: L("编辑", "Edit")
                ) {
                    profilePush(.editProfile)
                }

                Spacer()

                profileTopIconButton(
                    systemName: "ellipsis",
                    accessibilityLabel: L("更多", "More")
                ) {
                    profilePush(.settings)
                }
            }
            .frame(height: 36)
        }
    }

    private func profileTopIconButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @MainActor
    private func openMyProfileQRCode(_ profile: UserProfile) async {
        let subtitle = profile.bio.isEmpty ? nil : profile.bio
        let target = ShareTarget(
            type: .userCard,
            id: profile.id,
            title: profile.displayName,
            subtitle: subtitle,
            imageURL: profile.avatarURL
        )

        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: target, channel: "view_qr")
            profilePush(
                .shareQRCode(
                    title: resolved.payload.title,
                    subtitle: resolved.payload.subtitle,
                    imageURL: resolved.payload.imageURL,
                    shortURL: resolved.payload.shortURL,
                    qrCodeURL: resolved.payload.qrCodeURL
                )
            )
        } catch {
            viewModel.error = error.userFacingMessage ?? L("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.")
        }
    }

    private var profileQuickActions: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("快捷入口", "Quick Actions"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top), count: 4),
                    spacing: 14
                ) {
                    quickActionTile(title: L("我的发布", "My Posts"), icon: "square.stack.3d.up") {
                        profilePush(.myPublishes)
                    }
                    quickActionTile(title: L("我的收藏", "My Saves"), icon: "star.fill") {
                        profilePush(.mySaves)
                    }
                    quickActionTile(title: L("我的路线", "My Routes"), icon: "point.topleft.down.curvedto.point.bottomright.up") {
                        profilePush(.myRoutes)
                    }
                    if AppConfig.virtualAssetsEnabled {
                        quickActionTile(title: L("装扮中心", "Style Center"), icon: "sparkles") {
                            profilePush(.virtualAssetCenter)
                        }
                    }
                    quickActionTile(title: L("小工具", "Tools"), icon: "wand.and.stars") {
                        profilePush(.tools)
                    }
                    quickActionTile(title: L("二维码", "QR Code"), icon: "qrcode") {
                        guard let profile = viewModel.profile else { return }
                        Task { await openMyProfileQRCode(profile) }
                    }
                }
            }
        }
    }

    private func quickActionTile(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RaverTheme.accent)
                    .frame(width: 34, height: 30)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 62, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sectionContent: some View {
        VStack(spacing: 12) {
            RaverProfileSegmentedControl(
                items: ProfileViewModel.Section.allCases,
                selection: $viewModel.selectedSection,
                namespace: profilePostTabNamespace,
                title: { $0.title },
                iconName: { $0.iconName }
            )

            switch viewModel.selectedSection {
            case .published:
                if viewModel.recentPosts.isEmpty {
                    ContentUnavailableView(LL("还没有动态"), systemImage: "square.and.pencil")
                } else {
                    feedList(viewModel.recentPosts, actionAt: nil)
                }
            case .saves:
                if viewModel.savedItems.isEmpty {
                    ContentUnavailableView(L("暂无收藏帖子", "No saved posts yet"), systemImage: "star")
                } else {
                    feedList(
                        viewModel.savedItems.map(\.post),
                        actionAt: Dictionary(
                            viewModel.savedItems.map { ($0.post.id, $0.actionAt) },
                            uniquingKeysWith: { first, _ in first }
                        )
                    )
                }
            case .likes:
                if viewModel.likedItems.isEmpty {
                    ContentUnavailableView(L("暂无 Like 过的帖子", "No liked posts yet"), systemImage: "heart")
                } else {
                    feedList(
                        viewModel.likedItems.map(\.post),
                        actionAt: Dictionary(
                            viewModel.likedItems.map { ($0.post.id, $0.actionAt) },
                            uniquingKeysWith: { first, _ in first }
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func feedList(_ posts: [Post], actionAt: [String: Date]?) -> some View {
        VStack(spacing: 12) {
            ForEach(posts) { post in
                VStack(alignment: .leading, spacing: 8) {
                    if let actionAt,
                       let at = actionAt[post.id] {
                        Text(L("操作于 \(at.feedTimeText)", "Action at \(at.feedTimeText)"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .padding(.horizontal, 4)
                    }

                    PostCardView(
                        post: post,
                        currentUserId: appState.session?.user.id,
                        showsFollowButton: false,
                        onLikeTap: {
                            Task { await viewModel.toggleLike(post: post) }
                        },
                        onRepostTap: {
                            Task { await viewModel.toggleRepost(post: post) }
                        },
                        onSaveTap: {
                            Task { await viewModel.toggleSave(post: post) }
                        },
                        onFollowTap: nil,
                        onMessageTap: nil,
                        onAuthorTap: {
                            if post.author.id != appState.session?.user.id {
                                appPush(.userProfile(userID: post.author.id))
                            }
                        },
                        onSquadTap: nil
                    )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appPush(.postDetail(postID: post.id))
                }
            }
        }
    }

    private var currentUserID: String {
        appState.session?.user.id ?? ""
    }
}

private struct RaverProfileSegmentedControl<ID: Hashable>: View {
    let items: [ID]
    @Binding var selection: ID
    let namespace: Namespace.ID
    let title: (ID) -> String
    let iconName: (ID) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        selection = item
                    }
                } label: {
                    segmentContent(for: item)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RaverTheme.card.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder.opacity(0.78), lineWidth: 1)
        )
    }

    private func segmentContent(for item: ID) -> some View {
        let isSelected = selection == item

        return HStack(spacing: 6) {
            Image(systemName: iconName(item))
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(title(item))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(isSelected ? Color.white : RaverTheme.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.horizontal, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RaverTheme.tabBarSelectionStart,
                                RaverTheme.accent,
                                RaverTheme.tabBarSelectionEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(RaverTheme.tabBarSelectionStroke, lineWidth: 1)
                    )
                    .matchedGeometryEffect(id: "profile-segment-\(String(describing: ID.self))", in: namespace)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

@MainActor
final class MySavesViewModel: ObservableObject {
    @Published var markedEvents: [WebEvent] = []
    @Published var followedDJs: [WebDJ] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private let contentRepository: ProfileContentRepository
    private let checkinRepository: ProfileCheckinRepository

    init(
        contentRepository: ProfileContentRepository,
        checkinRepository: ProfileCheckinRepository
    ) {
        self.contentRepository = contentRepository
        self.checkinRepository = checkinRepository
    }

    func load(force: Bool = false) async {
        guard force || (!isLoading && markedEvents.isEmpty && followedDJs.isEmpty) else { return }

        isLoading = true
        isRefreshing = force
        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            async let eventsTask = loadMarkedEvents()
            async let djsTask = contentRepository.fetchFollowedDJs(page: 1, limit: 100).items

            markedEvents = try await eventsTask
            followedDJs = try await djsTask
            errorMessage = nil
        } catch {
            guard !error.isUserInitiatedCancellation else { return }
            errorMessage = error.userFacingMessage ?? L("收藏内容加载失败，请稍后重试", "Failed to load saves. Please try again later.")
        }
    }

    private func loadMarkedEvents() async throws -> [WebEvent] {
        let page = try await checkinRepository.fetchMyCheckins(page: 1, limit: 200, type: "event")
        let eventIDs = page.items
            .filter { $0.type.lowercased() == "event" && $0.eventId != nil && $0.isMarkedCheckin }
            .compactMap(\.eventId)

        var eventsByID: [String: WebEvent] = [:]
        try await withThrowingTaskGroup(of: WebEvent.self) { group in
            for eventID in Set(eventIDs) {
                group.addTask {
                    try await self.contentRepository.fetchEvent(id: eventID)
                }
            }
            for try await event in group {
                eventsByID[event.id] = event
            }
        }

        return eventIDs.compactMap { eventsByID[$0] }
    }
}

struct MySavesView: View {
    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: MySavesViewModel
    @State private var selectedTab: SaveTab = .events
    @Namespace private var saveTabNamespace

    private enum SaveTab: String, CaseIterable, Identifiable {
        case events
        case djs

        var id: String { rawValue }

        var title: String {
            switch self {
            case .events: return L("收藏活动", "Events")
            case .djs: return L("关注的DJ", "DJs")
            }
        }

        var iconName: String {
            switch self {
            case .events: return "star"
            case .djs: return "headphones"
            }
        }
    }

    init(
        contentRepository: ProfileContentRepository,
        checkinRepository: ProfileCheckinRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: MySavesViewModel(
                contentRepository: contentRepository,
                checkinRepository: checkinRepository
            )
        )
    }

    var body: some View {
        List {
            RaverProfileSegmentedControl(
                items: SaveTab.allCases,
                selection: $selectedTab,
                namespace: saveTabNamespace,
                title: { $0.title },
                iconName: { $0.iconName }
            )
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            switch selectedTab {
            case .events:
                savedEventsSection
            case .djs:
                followedDJsSection
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 52)
        .listSectionSpacing(.compact)
        .raverSystemNavigation(title: L("我的收藏", "My Saves"))
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load(force: true)
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

    @ViewBuilder
    private var savedEventsSection: some View {
        if viewModel.markedEvents.isEmpty, !viewModel.isLoading {
            ContentUnavailableView(L("暂无收藏活动", "No favorite events yet"), systemImage: "star")
                .listRowBackground(Color.clear)
        }

        ForEach(viewModel.markedEvents) { event in
            Button {
                appPush(.eventDetail(eventID: event.id))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                    Text(event.startDate.appLocalizedYMDText())
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    let addressText = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(addressText.isEmpty ? L("地点待补充", "Location pending") : addressText)
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
    }

    @ViewBuilder
    private var followedDJsSection: some View {
        if viewModel.followedDJs.isEmpty, !viewModel.isLoading {
            ContentUnavailableView(L("暂无关注的 DJ", "No followed DJs yet"), systemImage: "headphones")
                .listRowBackground(Color.clear)
        }

        ForEach(viewModel.followedDJs) { dj in
            Button {
                appPush(.djDetail(djID: dj.id))
            } label: {
                HStack(spacing: 12) {
                    djAvatar(dj)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(dj.name)
                            .font(.headline)
                        if let country = dj.country?.nilIfBlank {
                            Text(country)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        if let followerCount = dj.followerCount {
                            Text(L("\(followerCount) 位关注者", "\(followerCount) followers"))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }

                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        }
    }

    @ViewBuilder
    private func djAvatar(_ dj: WebDJ) -> some View {
        if let avatar = dj.avatarSmallUrl ?? dj.avatarMediumUrl ?? dj.avatarUrl,
           let resolved = AppConfig.resolvedURLString(avatar),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .frame(width: 46, height: 46)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.card)
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: "headphones")
                        .foregroundStyle(RaverTheme.secondaryText)
                }
        }
    }
}

struct ProfileHeaderCard<Actions: View>: View {
    let profile: UserProfile
    let appearance: UserAssetAppearance?
    let realNameStatus: RealNameVerificationStatus?
    let onAvatarTap: (() -> Void)?
    let onRealNameTap: (() -> Void)?
    let onFollowersTap: (() -> Void)?
    let onFollowingTap: (() -> Void)?
    let onFriendsTap: (() -> Void)?
    @ViewBuilder let actions: () -> Actions

    init(
        profile: UserProfile,
        appearance: UserAssetAppearance? = nil,
        realNameStatus: RealNameVerificationStatus? = nil,
        onAvatarTap: (() -> Void)? = nil,
        onRealNameTap: (() -> Void)? = nil,
        onFollowersTap: (() -> Void)? = nil,
        onFollowingTap: (() -> Void)? = nil,
        onFriendsTap: (() -> Void)? = nil,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.profile = profile
        self.appearance = appearance
        self.realNameStatus = realNameStatus
        self.onAvatarTap = onAvatarTap
        self.onRealNameTap = onRealNameTap
        self.onFollowersTap = onFollowersTap
        self.onFollowingTap = onFollowingTap
        self.onFriendsTap = onFriendsTap
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 12) {
            avatarView

            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    Text(profile.displayName)
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let titleMedal = appearance?.titleMedal {
                        VirtualAssetTitleMedalView(asset: titleMedal, compact: true, maxWidth: 138)
                    }
                }
                .frame(maxWidth: .infinity)

                if let badges = appearance?.profileBadges, !badges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(badges.prefix(5)) { badge in
                                VirtualAssetBadgeView(asset: badge, compact: true, showTitle: true)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if let realNameStatus {
                realNameBadge(status: realNameStatus)
            }

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            if !profile.tags.isEmpty {
                tagsFlow(profile.tags)
            }

            HStack(spacing: 24) {
                stat(L("动态", "Posts"), value: profile.postsCount)
                stat(L("粉丝", "Followers"), value: profile.followersCount, onTap: onFollowersTap)
                stat(L("关注", "Following"), value: profile.followingCount, onTap: onFollowingTap)
                stat(L("好友", "Friends"), value: profile.friendsCount, onTap: onFriendsTap)
            }

            actions()
        }
        .padding(16)
    }

    @ViewBuilder
    private func realNameBadge(status: RealNameVerificationStatus) -> some View {
        if let onRealNameTap {
            Button(action: onRealNameTap) {
                realNameBadgeContent(status: status)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(status.title)
        } else {
            realNameBadgeContent(status: status)
        }
    }

    private func realNameBadgeContent(status: RealNameVerificationStatus) -> some View {
        HStack(spacing: 6) {
            Image(systemName: status.badgeIconName)
                .font(.system(size: 12, weight: .semibold))
            Text(status.title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(realNameBadgeTextColor(status))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(realNameBadgeBackgroundColor(status))
        )
        .overlay(
            Capsule()
                .stroke(realNameBadgeStrokeColor(status), lineWidth: 1)
        )
    }

    private func realNameBadgeTextColor(_ status: RealNameVerificationStatus) -> Color {
        switch status {
        case .verified:
            return Color(red: 0.18, green: 0.70, blue: 0.46)
        case .pending:
            return Color(red: 0.85, green: 0.48, blue: 0.12)
        case .rejected:
            return Color(red: 0.90, green: 0.22, blue: 0.30)
        case .unverified:
            return RaverTheme.secondaryText
        }
    }

    private func realNameBadgeBackgroundColor(_ status: RealNameVerificationStatus) -> Color {
        switch status {
        case .verified:
            return Color(red: 0.18, green: 0.70, blue: 0.46).opacity(0.14)
        case .pending:
            return Color(red: 0.95, green: 0.60, blue: 0.18).opacity(0.16)
        case .rejected:
            return Color(red: 0.90, green: 0.22, blue: 0.30).opacity(0.14)
        case .unverified:
            return RaverTheme.card
        }
    }

    private func realNameBadgeStrokeColor(_ status: RealNameVerificationStatus) -> Color {
        switch status {
        case .verified:
            return Color(red: 0.18, green: 0.70, blue: 0.46).opacity(0.28)
        case .pending:
            return Color(red: 0.95, green: 0.60, blue: 0.18).opacity(0.30)
        case .rejected:
            return Color(red: 0.90, green: 0.22, blue: 0.30).opacity(0.28)
        case .unverified:
            return RaverTheme.cardBorder
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let onAvatarTap {
            Button(action: onAvatarTap) {
                profileAvatarWithFrame
            }
            .buttonStyle(.plain)
        } else {
            profileAvatarWithFrame
        }
    }

    private var profileAvatarWithFrame: some View {
        VirtualAssetAvatarView(size: 84, avatarFrame: appearance?.avatarFrame) {
            ProfileAvatarImage(profile: profile, size: 84)
        }
    }

    @ViewBuilder
    private func tagsFlow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tags.prefix(12).enumerated()), id: \.offset) { _, tag in
                    Text(formattedTagText(tag))
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RaverTheme.card)
                        .clipShape(Capsule())
                }

                if tags.count > 12 {
                    Text("+\(tags.count - 12)")
                        .font(.caption.bold())
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RaverTheme.card)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedTagText(_ tag: String) -> String {
        let words = normalizedTagWords(from: tag)
        guard !words.isEmpty else { return "#\(tag)" }

        if words.count == 1 {
            return "#\(words[0])"
        }

        if words.count == 2 {
            return "#\(words[0])\n\(words[1])"
        }

        if words.count == 3 {
            let lengths = words.enumerated().map { ($0.offset, $0.element.count) }
            guard let longest = lengths.max(by: { $0.1 < $1.1 })?.0 else {
                return "#\(words[0])\n\(words[1]) \(words[2])"
            }

            let others = words.enumerated()
                .filter { $0.offset != longest }
                .map(\.element)
                .joined(separator: " ")

            if longest == 2 {
                return "#\(others)\n\(words[2])"
            }
            return "#\(words[longest])\n\(others)"
        }

        return "#\(words.joined(separator: " "))"
    }

    private func normalizedTagWords(from tag: String) -> [String] {
        tag
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func stat(_ title: String, value: Int, onTap: (() -> Void)? = nil) -> some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    statBody(title: title, value: value)
                }
                .buttonStyle(.plain)
            } else {
                statBody(title: title, value: value)
            }
        }
    }

    private func statBody(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }
}

struct ProfileRecentCheckinsCard: View {
    let title: String
    let checkins: [WebCheckin]
    let emptyText: String
    let onShowAll: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Button(LL("查看全部")) {
                        onShowAll()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .buttonStyle(.plain)
                }

                if checkins.isEmpty {
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(checkins.prefix(3))) { item in
                        checkinPreviewRow(item)
                    }
                }
            }
        }
    }

    private func checkinPreviewRow(_ item: WebCheckin) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "postage.stamp.fill")
                .font(.title3)
                .foregroundStyle(RaverTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(checkinTitle(item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)

                Text(checkinSubtitle(item))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func checkinTitle(_ item: WebCheckin) -> String {
        if item.type == "event" {
            if let event = item.event {
                if let nameI18n = event.nameI18n {
                    let localized = nameI18n.text(for: AppLanguagePreference.current.effectiveLanguage)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !localized.isEmpty { return localized }
                }
                let fallback = event.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !fallback.isEmpty { return fallback }
            }
            return L("活动打卡", "Event Check-in")
        }
        return item.dj?.name ?? L("DJ 打卡", "DJ Check-in")
    }

    private func checkinSubtitle(_ item: WebCheckin) -> String {
        let location: String = {
            if let event = item.event {
                let unified = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                return unified.isEmpty ? L("现场记录", "Live Record") : unified
            }
            if let country = item.dj?.country, !country.isEmpty {
                return country
            }
            return L("现场记录", "Live Record")
        }()
        return "\(item.attendedAt.appLocalizedYMDText()) · \(location)"
    }
}

private struct ProfileAvatarImage: View {
    let profile: UserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let resolved = AppConfig.resolvedURLString(profile.avatarURL),
               URL(string: resolved) != nil,
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                ImageLoaderView(urlString: resolved)
                    .background(fallbackAvatar)
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }

    private var fallbackAvatar: some View {
        AvatarPlaceholderView(size: size, backgroundColor: RaverTheme.card)
    }
}

struct AvatarFullscreenView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    var onClose: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                let size = min(proxy.size.width - 48, proxy.size.height * 0.62)
                VStack {
                    Spacer()
                    ProfileAvatarSquareImage(profile: profile, size: size)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                    Spacer()
                }
                .padding(.horizontal, 24)

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            if let onClose {
                                onClose()
                            } else {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.white.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.top, 14)
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct ProfileAvatarSquareImage: View {
    let profile: UserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let resolved = AppConfig.resolvedURLString(profile.avatarURL),
               URL(string: resolved) != nil,
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                ImageLoaderView(urlString: resolved)
                    .background(fallbackAvatar)
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fallbackAvatar: some View {
        AvatarPlaceholderView(size: size, backgroundColor: Color(hex: "AFB3B8"))
    }
}

struct MyRoutesView: View {
    @Environment(\.appPush) private var appPush
    @ObservedObject private var routeStore = EventRouteStore.shared
    @State private var cachedSnapshots: [EventManualCacheSnapshot] = []
    @State private var isLoadingCachedSnapshots = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if routeStore.routes.isEmpty, cachedSnapshots.isEmpty {
                    ContentUnavailableView(
                        L("暂无我的行程", "No Saved Routes"),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        description: Text(L("在活动时间表中定制并保存路线，或在活动详情缓存后，会显示在这里。", "Saved routes and cached events will appear here."))
                    )
                    .padding(.top, 80)
                }

                if !routeStore.routes.isEmpty {
                    sectionHeader(
                        title: L("我的路线", "My Saved Routes"),
                        subtitle: L("按你在时间表中的选择生成", "Built from your timetable selections")
                    )

                    ForEach(routeStore.routes) { route in
                        Button {
                            appPush(
                                .eventRoute(
                                    eventID: route.eventID,
                                    ownerUserID: nil,
                                    ownerDisplayName: nil,
                                    selectedDayID: nil,
                                    selectedSlotIDs: nil
                                )
                            )
                        } label: {
                            savedRouteRow(route)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                routeStore.delete(eventID: route.eventID)
                            } label: {
                                Label(L("删除", "Delete"), systemImage: "trash")
                            }
                        }
                    }
                }

                if !cachedSnapshots.isEmpty || isLoadingCachedSnapshots {
                    sectionHeader(
                        title: L("离线缓存活动", "Offline Cached Events"),
                        subtitle: L("弱网或离线时可直接打开", "Open directly in weak-network or offline mode")
                    )

                    if isLoadingCachedSnapshots, cachedSnapshots.isEmpty {
                        ProgressView(L("加载缓存中...", "Loading cache..."))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(cachedSnapshots) { snapshot in
                            Button {
                                appPush(.eventSchedule(eventID: snapshot.eventID))
                            } label: {
                                cachedSnapshotRow(snapshot)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await EventManualCacheStore.shared.removeSnapshot(eventID: snapshot.eventID)
                                        await loadCachedSnapshots()
                                    }
                                } label: {
                                    Label(L("删除缓存", "Delete Cache"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("我的行程", "My Routes"))
        .task {
            await loadCachedSnapshots()
        }
    }

    private func savedRouteRow(_ route: SavedEventRoute) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                ImageLoaderView(urlString: route.coverImageUrl, resizingMode: .fill)
                    .frame(width: 72, height: 72)
                    .background(
                        LinearGradient(
                            colors: [RaverTheme.accent.opacity(0.28), Color.black.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(route.eventName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    Label(eventDateText(route), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    Label(
                        L("\(route.selectedSlotIDs.count) 个已选演出", "\(route.selectedSlotIDs.count) selected sets"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private func cachedSnapshotRow(_ snapshot: EventManualCacheSnapshot) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                ImageLoaderView(
                    urlString: AppConfig.resolvedURLString(snapshot.event.coverAssetURL),
                    resizingMode: .fill
                )
                .frame(width: 72, height: 72)
                .background(
                    LinearGradient(
                        colors: [RaverTheme.accent.opacity(0.28), Color.black.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(snapshot.event.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    Label(eventDateText(snapshot.event), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    Label(
                        L("缓存于 \(Self.dateTimeFormatter.string(from: snapshot.cachedAt))", "Cached at \(Self.dateTimeFormatter.string(from: snapshot.cachedAt))"),
                        systemImage: "externaldrive.fill.badge.checkmark"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func eventDateText(_ route: SavedEventRoute) -> String {
        let start = Self.dateFormatter.string(from: route.startDate)
        let end = Self.dateFormatter.string(from: route.endDate)
        return start == end ? start : "\(start) - \(end)"
    }

    private func eventDateText(_ event: WebEvent) -> String {
        let start = Self.dateFormatter.string(from: event.startDate)
        let end = Self.dateFormatter.string(from: event.endDate)
        return start == end ? start : "\(start) - \(end)"
    }

    @MainActor
    private func loadCachedSnapshots() async {
        isLoadingCachedSnapshots = true
        defer { isLoadingCachedSnapshots = false }
        cachedSnapshots = await EventManualCacheStore.shared.allSnapshots()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguagePreference.current.effectiveLanguage == .zh ? "zh_Hans_CN" : "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguagePreference.current.effectiveLanguage == .zh ? "zh_Hans_CN" : "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ProfileToolsHubView: View {
    @Environment(\.profilePush) private var profilePush

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    profilePush(.widgetManager)
                } label: {
                    ProfileToolFeatureCard(
                        title: L("桌面倒计时管理", "Widget Countdown"),
                        subtitle: L("集中管理已加入桌面小组件的活动。", "Manage events added to your home screen widget."),
                        systemImage: "apps.iphone",
                        accent: Color(red: 0.38, green: 0.54, blue: 0.96)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    profilePush(.movieBanner)
                } label: {
                    ProfileToolFeatureCard(
                        title: L("Movie Banner 弹幕", "Movie Banner"),
                        subtitle: L("超大字体全屏弹幕，支持静态与跑马灯。", "Huge full-screen banner with static and marquee modes."),
                        systemImage: "textformat.size.larger",
                        accent: Color(red: 0.93, green: 0.36, blue: 0.52)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("小工具", "Tools"))
    }
}

private struct ProfileToolFeatureCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.95),
                                RaverTheme.accent.opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RaverTheme.card.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(RaverTheme.cardBorder.opacity(0.76), lineWidth: 1)
        )
    }
}

struct WidgetEventManagerView: View {
    @Environment(\.appPush) private var appPush

    @State private var events: [WidgetSelectableEvent] = []
    @State private var selectedLayoutStyle: WidgetCountdownLayoutStyle = .original
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingEvent: WidgetSelectableEvent?
    @State private var customNameDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            widgetLayoutStyleSection

            Group {
                if isLoading && events.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RaverTheme.background)
                } else if events.isEmpty {
                    ContentUnavailableView(
                        L("还没有已添加的小组件活动", "No widget events yet"),
                        systemImage: "apps.iphone",
                        description: Text(
                            L(
                                "去活动详情页点击“添加到桌面倒计时”，这里就会集中显示。",
                                "Add events from the event detail page and they will appear here."
                            )
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
                } else {
                    List {
                        ForEach(events) { event in
                            Button {
                                appPush(.eventDetail(eventID: event.id))
                            } label: {
                                HStack(spacing: 12) {
                                    WidgetManagedEventThumbnail(event: event)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(event.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(RaverTheme.primaryText)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)

                                        if let meta = widgetEventMetaText(event), !meta.isEmpty {
                                            Text(meta)
                                                .font(.caption)
                                                .foregroundStyle(RaverTheme.secondaryText)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer(minLength: 8)

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    startRenaming(event)
                                } label: {
                                    Label(L("命名", "Rename"), systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    remove(event)
                                } label: {
                                    Label(L("移除", "Remove"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .refreshable {
                        await load()
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(RaverTheme.background)
                }
            }
        }
        .background(RaverTheme.background)
        .task {
            await load()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $editingEvent) { event in
            widgetRenameSheet(for: event)
        }
        .raverSystemNavigation(title: L("桌面倒计时", "Widget Countdown"))
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try WidgetSelectableEventsStore.shared.loadSnapshot()
            events = snapshot.events
            selectedLayoutStyle = snapshot.selectedLayoutStyle
        } catch {
            errorMessage = L(
                "读取桌面倒计时列表失败，请稍后重试。",
                "Failed to load widget countdown events. Please try again later."
            )
        }
    }

    private func selectLayoutStyle(_ layoutStyle: WidgetCountdownLayoutStyle) {
        guard selectedLayoutStyle != layoutStyle else { return }
        do {
            try WidgetSelectableEventsSyncService.shared.updateLayoutStyle(layoutStyle)
            selectedLayoutStyle = layoutStyle
        } catch {
            errorMessage = L(
                "切换文字排版方案失败，请稍后重试。",
                "Failed to switch the widget text layout. Please try again later."
            )
        }
    }

    private func remove(_ event: WidgetSelectableEvent) {
        do {
            _ = try WidgetSelectableEventsSyncService.shared.remove(eventID: event.id)
            events.removeAll { $0.id == event.id }
        } catch {
            errorMessage = L(
                "移除桌面倒计时活动失败，请稍后重试。",
                "Failed to remove widget countdown event. Please try again later."
            )
        }
    }

    private func startRenaming(_ event: WidgetSelectableEvent) {
        customNameDraft = event.customDisplayName ?? ""
        editingEvent = event
    }

    private func saveCustomName(for event: WidgetSelectableEvent) {
        do {
            let trimmed = customNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = trimmed.isEmpty ? nil : trimmed
            try WidgetSelectableEventsSyncService.shared.updateCustomDisplayName(
                eventID: event.id,
                customDisplayName: value
            )

            events = events.map { current in
                guard current.id == event.id else { return current }
                return WidgetSelectableEvent(
                    id: current.id,
                    name: current.name,
                    customDisplayName: value,
                    city: current.city,
                    venueName: current.venueName,
                    startDate: current.startDate,
                    endDate: current.endDate,
                    preferredBackgroundURL: current.preferredBackgroundURL,
                    cachedBackgroundImageRelativePath: current.cachedBackgroundImageRelativePath,
                    addedAt: current.addedAt
                )
            }
            editingEvent = nil
        } catch {
            errorMessage = L(
                "保存自定义名称失败，请稍后重试。",
                "Failed to save the custom widget name. Please try again later."
            )
        }
    }

    private func widgetEventMetaText(_ event: WidgetSelectableEvent) -> String? {
        var parts: [String] = []
        if event.customDisplayName != nil {
            parts.append(event.name)
        }
        parts.append(contentsOf: [event.city, event.venueName].compactMap(widgetTrimmed))
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func widgetRenameSheet(for event: WidgetSelectableEvent) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        L("输入小组件名称", "Enter widget name"),
                        text: $customNameDraft
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                } footer: {
                    Text(
                        L(
                            "仅保存在当前设备，用于小组件展示和选择，不会同步到线上或其他设备。留空则恢复活动原名。",
                            "Saved only on this device for widget display and selection. It will not sync online or to other devices. Leave blank to restore the original event name."
                        )
                    )
                }

                Section(L("原活动名称", "Original Event Name")) {
                    Text(event.name)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RaverTheme.background)
            .navigationTitle(L("自定义名称", "Custom Name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("取消", "Cancel")) {
                        editingEvent = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("保存", "Save")) {
                        saveCustomName(for: event)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var widgetLayoutStyleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("文字排版方案", "Text Layout Styles"))
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(WidgetCountdownLayoutStyle.allCases) { layoutStyle in
                        Button {
                            selectLayoutStyle(layoutStyle)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                WidgetLayoutStylePreviewCard(
                                    layoutStyle: layoutStyle,
                                    isSelected: selectedLayoutStyle == layoutStyle
                                )

                                Text(layoutStyle.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(
                                        selectedLayoutStyle == layoutStyle
                                        ? RaverTheme.primaryText
                                        : RaverTheme.secondaryText
                                    )
                                    .lineLimit(1)
                            }
                            .frame(width: 128, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .background(RaverTheme.background)
    }
}

private struct WidgetManagedEventThumbnail: View {
    let event: WidgetSelectableEvent

    var body: some View {
        Group {
            if let image = WidgetBackgroundImageCache.loadDisplayImage(
                relativePath: event.cachedBackgroundImageRelativePath,
                maxPixelSize: 180
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ImageLoaderView(urlString: event.preferredBackgroundURL, resizingMode: .fill)
            }
        }
        .frame(width: 58, height: 58)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RaverTheme.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WidgetLayoutStylePreviewCard: View {
    let layoutStyle: WidgetCountdownLayoutStyle
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.12),
                    Color(red: 0.45, green: 0.12, blue: 0.28),
                    Color(red: 0.95, green: 0.46, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.08), location: 0),
                    .init(color: .black.opacity(0.24), location: 0.45),
                    .init(color: .black.opacity(0.76), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            switch layoutStyle {
            case .original:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rave City")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("还有 5 天")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
                .padding(10)
            case .distance:
                VStack(alignment: .leading, spacing: 0) {
                    (
                        Text("距离")
                            .font(.system(size: 10, weight: .regular))
                        + Text("Rave City")
                            .font(.system(size: 10, weight: .bold))
                    )
                    .foregroundStyle(.white)
                    .lineLimit(2)

                    Spacer(minLength: 0)

                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("5")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("天")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }
                }
                .padding(.top, 10)
                .padding(.leading, 10)
                .padding(.trailing, 10)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 128, height: 128, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? RaverTheme.accent : Color.white.opacity(0.10),
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }
}

struct MovieBannerEditorView: View {
    @State private var configuration = MovieBannerConfiguration()
    @State private var showDisplay = false
    @State private var displayPreparedLandscapeLock = false
    @State private var prepareDisplayTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool

    private var canStart: Bool {
        !configuration.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("弹幕内容", "Banner Message"))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)

                        TextField(
                            L("例如：XXX看这里 / 前排求互动", "For example: Look here / Front row says hi"),
                            text: $configuration.message,
                            axis: .vertical
                        )
                        .focused($isInputFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1 ... 4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )

                        Button {
                            isInputFocused = false
                            prepareDisplayTask?.cancel()
                            prepareDisplayTask = Task {
                                await prepareLandscapeDisplay()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(L("开始展示", "Start"))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canStart)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L("展示设置", "Display Settings"))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)

                        Picker(
                            L("展示模式", "Display Mode"),
                            selection: $configuration.mode
                        ) {
                            ForEach(MovieBannerMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        settingSliderRow(
                            title: L("字体大小", "Font Size"),
                            valueText: "\(Int(configuration.fontSize))",
                            value: $configuration.fontSize,
                            range: MovieBannerConfiguration.fontSizeRange,
                            step: 2
                        )

                        settingSliderRow(
                            title: L("滚动速度", "Scroll Speed"),
                            valueText: "\(Int(configuration.scrollSpeed))",
                            value: $configuration.scrollSpeed,
                            range: 20 ... 280,
                            step: 5
                        )

                        Toggle(L("闪烁效果", "Blink"), isOn: $configuration.isBlinkEnabled)
                            .tint(RaverTheme.accent)
                            .foregroundStyle(RaverTheme.primaryText)

                        Toggle(L("自动滚动", "Auto Scroll"), isOn: $configuration.autoScroll)
                            .tint(RaverTheme.accent)
                            .foregroundStyle(RaverTheme.primaryText)

                        MovieBannerColorPickerRow(
                            title: L("文字颜色", "Text Color"),
                            selection: $configuration.textColor
                        )

                        MovieBannerColorPickerRow(
                            title: L("背景颜色", "Background"),
                            selection: $configuration.backgroundColor
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("Movie Banner", "Movie Banner"))
        .fullScreenCover(isPresented: $showDisplay) {
            MovieBannerDisplayView(
                configuration: $configuration,
                isPresented: $showDisplay,
                hasLandscapeLock: $displayPreparedLandscapeLock
            )
        }
        .onDisappear {
            prepareDisplayTask?.cancel()
            prepareDisplayTask = nil
            if displayPreparedLandscapeLock, !showDisplay {
                AppOrientationLock.shared.unlockLandscapeOnly(forcePortrait: true)
                displayPreparedLandscapeLock = false
            }
        }
    }

    @ViewBuilder
    private func settingSliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer(minLength: 8)
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            Slider(
                value: value,
                in: range,
                step: step
            )
            .tint(RaverTheme.accent)
        }
    }

    @MainActor
    private func prepareLandscapeDisplay() async {
        AppOrientationLock.shared.lockLandscapeOnly(forceRotate: true)
        displayPreparedLandscapeLock = true

        for _ in 0 ..< 8 {
            if isLandscapeInterface() { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
        }

        guard !Task.isCancelled else { return }
        showDisplay = true
    }

    private func isLandscapeInterface() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .interfaceOrientation
            .isLandscape ?? false
    }
}

private struct MovieBannerDisplayView: View {
    @Binding var configuration: MovieBannerConfiguration
    @Binding var isPresented: Bool
    @Binding var hasLandscapeLock: Bool

    @State private var controlsVisible = false
    @State private var isPaused = false
    @State private var scrollStartDate = Date()
    @State private var pausedDate: Date?
    @State private var pausedDuration: TimeInterval = 0
    @State private var controlsAutoHideTask: Task<Void, Never>?
    @State private var isInteractionLocked = false
    @State private var lockButtonOpacity: Double = 1.0
    @State private var lockButtonFadeTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            configuration.backgroundColor.color
                .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                bannerContent(in: context.date)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleScreenTap()
            }

            if controlsVisible {
                controlsLayer
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            lockButtonLayer
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBar(hidden: true)
        .onAppear {
            if !hasLandscapeLock {
                AppOrientationLock.shared.lockLandscapeOnly(forceRotate: true)
                hasLandscapeLock = true
            }
            resetScrollProgress()
            isPaused = !configuration.autoScroll
            showLockButtonTemporarily()
        }
        .onDisappear {
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
            lockButtonFadeTask?.cancel()
            lockButtonFadeTask = nil
            if hasLandscapeLock {
                AppOrientationLock.shared.unlockLandscapeOnly(forcePortrait: true)
                hasLandscapeLock = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            if !isLandscapeInterface() {
                forceLandscapeOrientation()
            }
        }
        .onChange(of: configuration.mode) { _, mode in
            if mode == .staticCentered {
                isPaused = true
            } else if configuration.autoScroll {
                isPaused = false
            }
            resetScrollProgress()
        }
        .onChange(of: configuration.autoScroll) { _, enabled in
            if configuration.mode == .scrolling {
                isPaused = !enabled
                resetScrollProgress()
            }
        }
        .onChange(of: configuration.fontSize) { _, _ in
            resetScrollProgress()
        }
    }

    @ViewBuilder
    private func bannerContent(in renderDate: Date) -> some View {
        GeometryReader { proxy in
            if configuration.mode == .staticCentered {
                centeredTextView(renderDate: renderDate)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else if configuration.autoScroll {
                scrollingTextView(renderDate: renderDate, size: proxy.size)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                centeredTextView(renderDate: renderDate)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private func centeredTextView(renderDate: Date) -> some View {
        bannerText
            .lineLimit(1)
            .minimumScaleFactor(0.12)
            .padding(.horizontal, 20)
            .opacity(blinkOpacity(at: renderDate))
    }

    private func scrollingTextView(renderDate: Date, size: CGSize) -> some View {
        let message = resolvedMessage
        let font = UIFont.systemFont(ofSize: CGFloat(configuration.fontSize), weight: .bold)
        let textWidth = max(1, NSString(string: message).size(withAttributes: [.font: font]).width)
        let cycle = max(1, size.width + textWidth)
        let timelineDate = frozenDate(for: renderDate)
        let elapsed = max(0, timelineDate.timeIntervalSince(scrollStartDate) - pausedDuration)
        let travel = CGFloat((elapsed * configuration.scrollSpeed).truncatingRemainder(dividingBy: Double(cycle)))
        let leadingOffset = size.width - travel

        return bannerText
            .opacity(blinkOpacity(at: timelineDate))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: true)
        .offset(x: leadingOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var controlsLayer: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        isPresented = false
                    } label: {
                        Label(L("返回", "Back"), systemImage: "chevron.backward")
                    }
                    .buttonStyle(.borderedProminent)

                    if configuration.mode == .scrolling {
                        Button {
                            if configuration.autoScroll {
                                togglePause()
                            } else {
                                configuration.autoScroll = true
                                isPaused = false
                                resetScrollProgress()
                            }
                        } label: {
                            Label(
                                configuration.autoScroll
                                    ? (isPaused ? L("继续", "Resume") : L("暂停", "Pause"))
                                    : L("开始滚动", "Start Scroll"),
                                systemImage: configuration.autoScroll
                                    ? (isPaused ? "play.fill" : "pause.fill")
                                    : "play.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer(minLength: 0)

                    Button {
                        configuration.textColor = configuration.textColor.next
                        keepControlsVisible()
                    } label: {
                        Label(L("文字色", "Text"), systemImage: "paintpalette")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        configuration.backgroundColor = configuration.backgroundColor.next
                        keepControlsVisible()
                    } label: {
                        Label(L("背景色", "BG"), systemImage: "circle.lefthalf.filled")
                    }
                    .buttonStyle(.bordered)
                }

                Picker(
                    L("模式", "Mode"),
                    selection: $configuration.mode
                ) {
                    ForEach(MovieBannerMode.allCases) { mode in
                        Text(mode.shortTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: configuration.mode) { _, _ in
                    keepControlsVisible()
                }

                if configuration.mode == .scrolling {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L("速度", "Speed"))
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.85))
                            Spacer(minLength: 8)
                            Text("\(Int(configuration.scrollSpeed))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                        Slider(
                            value: $configuration.scrollSpeed,
                            in: 20 ... 280,
                            step: 5
                        ) {
                            Text(L("速度", "Speed"))
                        } minimumValueLabel: {
                            Text(L("慢", "Slow"))
                                .font(.caption2)
                        } maximumValueLabel: {
                            Text(L("快", "Fast"))
                                .font(.caption2)
                        } onEditingChanged: { _ in
                            keepControlsVisible()
                        }
                        .tint(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L("字号", "Size"))
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.85))
                        Spacer(minLength: 8)
                        Text("\(Int(configuration.fontSize))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    Slider(
                        value: $configuration.fontSize,
                        in: MovieBannerConfiguration.fontSizeRange,
                        step: 2
                    ) {
                        Text(L("字号", "Size"))
                    } minimumValueLabel: {
                        Text(L("小", "Small"))
                            .font(.caption2)
                    } maximumValueLabel: {
                        Text(L("大", "Large"))
                            .font(.caption2)
                    } onEditingChanged: { _ in
                        keepControlsVisible()
                    }
                    .tint(.white)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.66))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var lockButtonLayer: some View {
        HStack {
            Button {
                toggleInteractionLock()
            } label: {
                Image(systemName: isInteractionLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.58))
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .opacity(lockButtonOpacity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .allowsHitTesting(true)
    }

    private var bannerText: some View {
        Text(resolvedMessage)
            .font(.system(size: configuration.fontSize, weight: .bold))
            .foregroundStyle(configuration.textColor.color)
            .shadow(color: configuration.textColor.color.opacity(0.30), radius: 8, x: 0, y: 0)
    }

    private var resolvedMessage: String {
        let trimmed = configuration.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L("请输入内容", "Type Something") : trimmed
    }

    private func blinkOpacity(at date: Date) -> Double {
        guard configuration.isBlinkEnabled else { return 1.0 }
        let phase = sin(date.timeIntervalSinceReferenceDate * 8.0)
        return phase > 0 ? 1.0 : 0.28
    }

    private func togglePause() {
        if isPaused {
            if let pausedDate {
                pausedDuration += Date().timeIntervalSince(pausedDate)
            }
            self.pausedDate = nil
            isPaused = false
        } else {
            pausedDate = Date()
            isPaused = true
        }
        keepControlsVisible()
    }

    private func handleScreenTap() {
        showLockButtonTemporarily()
        guard !isInteractionLocked else { return }
        toggleControlsVisibility()
    }

    private func toggleInteractionLock() {
        isInteractionLocked.toggle()
        if isInteractionLocked {
            controlsVisible = false
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
        }
        showLockButtonTemporarily()
    }

    private func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
        if controlsVisible {
            scheduleControlsAutoHide()
        } else {
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
        }
    }

    private func keepControlsVisible() {
        guard controlsVisible else { return }
        scheduleControlsAutoHide()
    }

    private func scheduleControlsAutoHide() {
        controlsAutoHideTask?.cancel()
        controlsAutoHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controlsVisible = false
                }
            }
        }
    }

    private func showLockButtonTemporarily() {
        withAnimation(.easeOut(duration: 0.12)) {
            lockButtonOpacity = 1.0
        }
        scheduleLockButtonFadeOut()
    }

    private func scheduleLockButtonFadeOut() {
        lockButtonFadeTask?.cancel()
        lockButtonFadeTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.45)) {
                    lockButtonOpacity = 0
                }
            }
        }
    }

    private func resetScrollProgress() {
        scrollStartDate = Date()
        pausedDuration = 0
        pausedDate = isPaused ? Date() : nil
    }

    private func frozenDate(for date: Date) -> Date {
        guard configuration.mode == .scrolling, configuration.autoScroll else {
            return date
        }
        if isPaused, let pausedDate {
            return pausedDate
        }
        return date
    }

    private func forceLandscapeOrientation() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    }

    private func isLandscapeInterface() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .interfaceOrientation
            .isLandscape ?? false
    }
}

private struct MovieBannerColorPickerRow: View {
    let title: String
    @Binding var selection: MovieBannerColorPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(RaverTheme.primaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MovieBannerColorPreset.allCases) { preset in
                        Button {
                            selection = preset
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.45), lineWidth: 1)
                                    )
                                Text(preset.title)
                                    .font(.caption)
                            }
                            .foregroundStyle(selection == preset ? RaverTheme.primaryText : RaverTheme.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selection == preset ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct MovieBannerConfiguration {
    static let fontSizeRange: ClosedRange<Double> = 64 ... 1200

    var message: String = ""
    var fontSize: Double = 120
    var scrollSpeed: Double = 90
    var isBlinkEnabled: Bool = false
    var autoScroll: Bool = true
    var mode: MovieBannerMode = .scrolling
    var textColor: MovieBannerColorPreset = .white
    var backgroundColor: MovieBannerColorPreset = .black
}

private enum MovieBannerMode: String, CaseIterable, Identifiable {
    case staticCentered
    case scrolling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .staticCentered:
            return L("静态居中", "Static Center")
        case .scrolling:
            return L("横向滚动", "Scrolling")
        }
    }

    var shortTitle: String {
        switch self {
        case .staticCentered:
            return L("静态", "Static")
        case .scrolling:
            return L("滚动", "Scroll")
        }
    }
}

private enum MovieBannerColorPreset: String, CaseIterable, Identifiable {
    case white
    case black
    case red
    case yellow
    case green
    case cyan
    case pink
    case purple
    case orange
    case blue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white:
            return L("白", "White")
        case .black:
            return L("黑", "Black")
        case .red:
            return L("红", "Red")
        case .yellow:
            return L("黄", "Yellow")
        case .green:
            return L("绿", "Green")
        case .cyan:
            return L("青", "Cyan")
        case .pink:
            return L("粉", "Pink")
        case .purple:
            return L("紫", "Purple")
        case .orange:
            return L("橙", "Orange")
        case .blue:
            return L("蓝", "Blue")
        }
    }

    var color: Color {
        switch self {
        case .white:
            return .white
        case .black:
            return .black
        case .red:
            return .red
        case .yellow:
            return .yellow
        case .green:
            return .green
        case .cyan:
            return .cyan
        case .pink:
            return .pink
        case .purple:
            return .purple
        case .orange:
            return .orange
        case .blue:
            return .blue
        }
    }

    var next: MovieBannerColorPreset {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        let nextIndex = all.index(after: index)
        return nextIndex == all.endIndex ? all[all.startIndex] : all[nextIndex]
    }
}

struct ShareQRCodeDetailView: View {
    let title: String
    let subtitle: String?
    let imageURL: String?
    let shortURL: String?
    let qrCodeURL: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                shareSubjectCard
                if resolvedShortURL != nil {
                    shortLinkCard
                }
                qrCard
                hintCard
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("分享二维码", "Share QR Code"))
    }

    private var resolvedShortURL: String? {
        let trimmed = shortURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var shareSubjectCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                subjectImage

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var shortLinkCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("短链", "Short Link"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                HStack(spacing: 10) {
                    Text(resolvedShortURL ?? "")
                        .font(.footnote.monospaced())
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer(minLength: 0)

                    Button {
                        guard let resolvedShortURL else { return }
                        UIPasteboard.general.string = resolvedShortURL
                        OperationBannerCenter.shared.success(L("已复制短链", "Short link copied"))
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text(L("复制短链", "Copy short link")))
                }
            }
        }
    }

    private var qrCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                qrImage

                Text(L("扫码后可在 iPhone 中打开对应页面", "Scan to open the related page on iPhone"))
                    .font(.footnote)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var hintCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("当前说明", "Notes"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                Text(L("此二维码由系统自动生成，与短链保持一致。后续切换分享域名时，历史二维码仍应继续可用。", "This QR code is generated by the system and stays aligned with the share short link. Historical QR codes should remain valid even after future share-domain migrations."))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var subjectImage: some View {
        if let resolved = AppConfig.resolvedURLString(imageURL),
           URL(string: resolved) != nil,
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RaverTheme.card)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "sparkles.rectangle.stack")
                        .foregroundStyle(RaverTheme.secondaryText)
                }
        }
    }

    @ViewBuilder
    private var qrImage: some View {
        let resolved = AppConfig.resolvedURLString(qrCodeURL)
        if let resolved,
           !resolved.isEmpty,
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved, resizingMode: .fit)
                .frame(width: 240, height: 240)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RaverTheme.card)
                .frame(width: 240, height: 240)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 56, weight: .medium))
                        Text(L("二维码生成中", "QR code is loading"))
                            .font(.footnote)
                    }
                    .foregroundStyle(RaverTheme.secondaryText)
                }
        }
    }
}

struct ShareAssetDetailView: View {
    let navigationTitle: String
    let title: String
    let subtitle: String?
    let imageURL: String?
    let assetURL: String?
    let emptyTitle: String
    let emptyMessage: String
    let hintText: String
    let saveButtonTitle: String?

    @State private var feedbackMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                shareSubjectCard
                assetCard
                hintCard
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: navigationTitle)
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    private var shareSubjectCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                subjectImage

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var assetCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                assetPreview

                if let saveButtonTitle, hasValidAssetURL {
                    Button {
                        Task { await saveAssetToPhotos() }
                    } label: {
                        Label(saveButtonTitle, systemImage: "photo.badge.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var hintCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("当前说明", "Notes"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                Text(hintText)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private var hasValidAssetURL: Bool {
        let resolved = AppConfig.resolvedURLString(assetURL)
        guard let resolved, !resolved.isEmpty else { return false }
        return URL(string: resolved) != nil
    }

    @ViewBuilder
    private var subjectImage: some View {
        if let resolved = AppConfig.resolvedURLString(imageURL),
           URL(string: resolved) != nil,
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RaverTheme.card)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(RaverTheme.secondaryText)
                }
        }
    }

    @ViewBuilder
    private var assetPreview: some View {
        let resolved = AppConfig.resolvedURLString(assetURL)
        if let resolved,
           !resolved.isEmpty,
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved, resizingMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 280)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RaverTheme.card)
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 56, weight: .medium))
                        Text(emptyTitle)
                            .font(.headline)
                        Text(emptyMessage)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.horizontal, 28)
                }
        }
    }

    @MainActor
    private func saveAssetToPhotos() async {
        do {
            try await ShareAssetPhotoSaver.saveRemoteImage(from: assetURL)
            feedbackMessage = L("已保存到相册", "Saved to Photos.")
        } catch {
            feedbackMessage = error.userFacingMessage ?? emptyMessage
        }
    }
}

enum ShareAssetPhotoSaver {
    @MainActor
    static func saveRemoteImage(from urlString: String?) async throws {
        guard let resolved = AppConfig.resolvedURLString(urlString),
              !resolved.isEmpty,
              let url = URL(string: resolved) else {
            throw ShareAssetPhotoSaverError.invalidURL
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ShareAssetPhotoSaverError.permissionDenied
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ShareAssetPhotoSaverError.imageDecodeFailed
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        continuation.resume()
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: ShareAssetPhotoSaverError.saveFailed)
                    }
                }
            }
        }
    }
}

enum ShareAssetPhotoSaverError: LocalizedError {
    case invalidURL
    case permissionDenied
    case imageDecodeFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L("海报地址无效，请稍后重试。", "Poster URL is invalid. Please try again later.")
        case .permissionDenied:
            return L("未获得相册权限，可稍后重新授权后再试。", "Photo permission denied. Please grant access and try again.")
        case .imageDecodeFailed:
            return L("图片读取失败，请稍后重试。", "Failed to read image. Please try again later.")
        case .saveFailed:
            return L("保存失败，请重试。", "Save failed. Please try again.")
        }
    }
}
