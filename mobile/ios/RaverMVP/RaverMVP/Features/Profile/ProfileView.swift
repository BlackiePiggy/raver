import SwiftUI
import Photos

enum PersonalitySubmissionErrorMapper {
    static func userFacingMessage(code: String?, rawMessage: String) -> String {
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCode = (code ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        switch normalizedCode {
        case "PERSONALITY_SESSION_INCOMPLETE":
            return LT(
                "还有题目没有作答，请先完成所有题目再查看结果。",
                "Some questions are still unanswered. Complete them all before seeing your result.",
                "未回答の問題があります。すべて回答してから結果を表示してください。"
            )
        case "PERSONALITY_SESSION_IN_PROGRESS":
            return LT(
                "你有一个未完成的测试，本次已为你自动刷新为新的测试场次。",
                "You had an unfinished session. A fresh test session has been prepared for you.",
                "未完了のテストがあったため、新しいセッションに切り替えました。"
            )
        case "PERSONALITY_SESSION_NOT_ACTIVE":
            return LT(
                "当前测试已经失效，请重新开始。",
                "This test session is no longer active. Please start again.",
                "このテストセッションはすでに無効です。もう一度開始してください。"
            )
        case "PERSONALITY_ALREADY_COMPLETED":
            return LT(
                "正式测试你已经做完了，可以直接查看结果。",
                "You have already completed the formal test and can view the result directly.",
                "正式テストはすでに完了しているため、結果を直接確認できます。"
            )
        case "PERSONALITY_DISABLED":
            return LT(
                "当前 EDMTI 测试暂未开启。",
                "EDMTI is currently disabled.",
                "現在 EDMTI は無効です。"
            )
        default:
            break
        }

        return trimmed.isEmpty
            ? LT("测试请求失败，请稍后重试。", "Test request failed. Please try again later.", "テストのリクエストに失敗しました。後でもう一度お試しください。")
            : trimmed
    }
}

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @Environment(\.profilePush) private var profilePush
    @ObservedObject private var viewModel: ProfileViewModel
    @Namespace private var profilePostTabNamespace
    @State private var isShowingRealNameSheet = false
    @State private var selectedAvatarMedia: FullscreenMediaSelection?
    @State private var selectedBackgroundMedia: FullscreenMediaSelection?

    private var resolvedAppearance: UserAssetAppearance? {
        AppConfig.virtualAssetsEnabled ? viewModel.appearance : nil
    }

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    init(viewModel: ProfileViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 12) {
            if appState.accountEnforcementStatus.enforcementStatus.isLimited {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LT("账号当前受限", "Account restricted", "アカウントが制限中"))
                            .font(.subheadline.weight(.semibold))
                        Text(appState.accountEnforcementStatus.restrictionSummary)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 16)
            }

            if viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
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
                            LT("离线模式", "Offline Mode", "オフラインモード"),
                            systemImage: "wifi.slash",
                            description: Text(LT("网络不可用，已切换离线入口。你仍可进入我的行程和小工具。", "Network unavailable. Switched to offline entry. You can still access My Routes and Tools.", "ネットワークを利用できません。オフライン入口に切り替えました。マイルートとツールは引き続き利用できます。"))
                        )

                        profileQuickActions
                    }
                    .padding(16)
                }
            case .success:
                if let profile = viewModel.profile {
                    ScrollView {
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 14) {
                            ProfileHeaderCard(
                                profile: profile,
                                appearance: resolvedAppearance,
                                realNameStatus: profileRealNameStatus,
                                onAvatarTap: {
                                    selectedAvatarMedia = FullscreenMediaSelection(id: 0)
                                },
                                onBackgroundTap: {
                                    selectedBackgroundMedia = FullscreenMediaSelection(id: 0)
                                },
                                onQRCodeTap: {
                                    Task { await openMyProfileQRCode(profile) }
                                },
                                onRealNameTap: profileRealNameTapAction,
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

                                VStack(spacing: 14) {
                            ProfileRecentCheckinsCard(
                                title: LT("我的近期打卡", "My Recent Check-ins", "最近のチェックイン"),
                                checkins: viewModel.recentCheckinPreviews,
                                emptyText: LT("去发现页完成活动或 DJ 打卡，记录会显示在这里。", "Complete event or DJ check-ins from Discover. Records will appear here.", "発見ページでイベントまたはDJチェックインを完了すると、記録がここに表示されます。")
                            ) {
                                profilePush(.myCheckins(
                                    targetUserID: nil,
                                    title: LT("我的打卡", "My Check-ins", "自分のチェックイン"),
                                    ownerDisplayName: viewModel.profile?.displayName
                                ))
                            }

                            profileQuickActions

                            sectionContent
                                }
                                .padding(.horizontal, 16)
                        }

                            profileTopActions
                                .padding(.top, 50)
                                .padding(.trailing, 16)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
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
        .onChange(of: viewModel.selectedSection) { _, _ in
            Task { await viewModel.loadSelectedSectionIfNeeded() }
        }
        .sheet(isPresented: $isShowingRealNameSheet) {
            if appState.shouldPresentRealNameVerificationUI {
                RealNameVerificationSheet()
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
        .fullScreenCover(item: $selectedAvatarMedia) { selection in
            if let profile = viewModel.profile,
               let avatarURL = profile.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !avatarURL.isEmpty {
                FullscreenMediaViewer(
                    items: [FullscreenMediaItem(rawURL: avatarURL, index: 0)],
                    initialIndex: selection.id
                )
            }
        }
        .fullScreenCover(item: $selectedBackgroundMedia) { selection in
            if let profile = viewModel.profile,
               let backgroundURL = profile.backgroundURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !backgroundURL.isEmpty {
                FullscreenMediaViewer(
                    items: [FullscreenMediaItem(rawURL: backgroundURL, index: 0)],
                    initialIndex: selection.id
                )
            }
        }
    }

    @ViewBuilder
    private var profileTopActions: some View {
        if viewModel.profile != nil {
            HStack {
                Spacer()

                profileTopIconButton(
                    systemName: "ellipsis",
                    accessibilityLabel: LT("更多", "More", "その他")
                ) {
                    profilePush(.settings)
                }
            }
            .frame(height: 36)
        }
    }

    private var profileRealNameStatus: RealNameVerificationStatus? {
        appState.shouldPresentRealNameVerificationUI ? appState.realNameVerificationStatus : nil
    }

    private var profileRealNameTapAction: (() -> Void)? {
        guard appState.shouldPresentRealNameVerificationUI else { return nil }
        return {
            isShowingRealNameSheet = true
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
            viewModel.error = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "Failed to open QR code. Please try again later.")
        }
    }

    private var profileQuickActions: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(LT("快捷入口", "Quick Actions", "クイックアクション"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top), count: 4),
                    spacing: 14
                ) {
                    quickActionTile(title: LT("我的发布", "My Posts", "自分の投稿"), icon: "square.stack.3d.up") {
                        profilePush(.myPublishes)
                    }
                    quickActionTile(title: LT("贡献中心", "Contributions", "貢献センター"), icon: "person.3.fill") {
                        ContributionModuleTelemetry.contributionCenterEntryTapped()
                        profilePush(.contributionCenter)
                    }
                    quickActionTile(title: LT("答题系统", "Quiz", "クイズ"), icon: "checklist") {
                        profilePush(.quiz)
                    }
                    quickActionTile(title: "EDMTI", icon: "brain") {
                        profilePush(.personality)
                    }
                    quickActionTile(title: LT("我的收藏", "My Saves", "保存済み"), icon: "star.fill") {
                        profilePush(.mySaves)
                    }
                    quickActionTile(title: LT("我的路线", "My Routes", "マイルート"), icon: "point.topleft.down.curvedto.point.bottomright.up") {
                        profilePush(.myRoutes)
                    }
                    if AppConfig.virtualAssetsEnabled {
                        quickActionTile(title: LT("装扮中心", "Style Center", "スタイルセンター"), icon: "sparkles") {
                            profilePush(.virtualAssetCenter)
                        }
                    }
                    quickActionTile(title: LT("小工具", "Tools", "ツール"), icon: "wand.and.stars") {
                        profilePush(.tools)
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
                publishedSectionContent
            case .saves:
                if !viewModel.hasLoadedSection(.saves) && viewModel.savedItems.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if viewModel.savedItems.isEmpty {
                    ContentUnavailableView(LT("暂无收藏帖子", "No saved posts yet", "保存済み投稿はまだありません"), systemImage: "star")
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
                if !viewModel.hasLoadedSection(.likes) && viewModel.likedItems.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if viewModel.likedItems.isEmpty {
                    ContentUnavailableView(LT("暂无 Like 过的帖子", "No liked posts yet", "いいねした投稿はまだありません"), systemImage: "heart")
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
    private var publishedSectionContent: some View {
        Group {
            if viewModel.loadingSection == .published || (!viewModel.hasLoadedSection(.published) && viewModel.recentPosts.isEmpty) {
                ProfileSkeletonView()
            } else if viewModel.recentPosts.isEmpty {
                ContentUnavailableView(LT("还没有动态", "No posts yet", "投稿はまだありません"), systemImage: "square.and.pencil")
            } else {
                feedList(viewModel.recentPosts, actionAt: nil)
            }
        }
        .onAppear {
            Task { await viewModel.loadSectionIfNeeded(.published) }
        }
    }

    @ViewBuilder
    private func feedList(_ posts: [Post], actionAt: [String: Date]?) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(posts) { post in
                VStack(alignment: .leading, spacing: 8) {
                    if let actionAt,
                       let at = actionAt[post.id] {
                        Text(LT("操作于 \(at.feedTimeText)", "Action at \(at.feedTimeText)", "操作日時 \(at.feedTimeText)"))
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
                .task {
                    await viewModel.loadMorePublishedPostsIfNeeded(currentPostID: post.id)
                }
            }

            if viewModel.selectedSection == .published && viewModel.isLoadingMorePublishedPosts {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
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
            errorMessage = error.userFacingMessage ?? LT("收藏内容加载失败，请稍后重试", "Failed to load saves. Please try again later.", "保存内容を読み込めませんでした。時間をおいて再試行してください。")
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
            case .events: return LT("收藏活动", "Events", "Events")
            case .djs: return LT("关注的DJ", "DJs", "DJ")
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
        .raverSystemNavigation(title: LT("我的收藏", "My Saves", "保存済み"))
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load(force: true)
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var savedEventsSection: some View {
        if viewModel.markedEvents.isEmpty, !viewModel.isLoading {
            ContentUnavailableView(LT("暂无收藏活动", "No favorite events yet", "お気に入りイベントはまだありません"), systemImage: "star")
                .listRowBackground(Color.clear)
        }

        ForEach(viewModel.markedEvents) { event in
            Button {
                appPush(.eventDetail(eventID: event.id))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                    Text(event.startDate.appLocalizedYMDText(in: event.eventTimeZone))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    let addressText = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(addressText.isEmpty ? LT("地点待补充", "Location pending", "場所は未設定") : addressText)
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
            ContentUnavailableView(LT("暂无关注的 DJ", "No followed DJs yet", "フォロー中のDJはまだありません"), systemImage: "headphones")
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
                            Text(LT("\(followerCount) 位关注者", "\(followerCount) followers", "\(followerCount)人のフォロワー"))
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
                .background(DefaultDJAvatarPlaceholderView(size: 46, backgroundColor: RaverTheme.card))
                .frame(width: 46, height: 46)
                .clipShape(Circle())
        } else {
            DefaultDJAvatarPlaceholderView(size: 46, backgroundColor: RaverTheme.card)
        }
    }
}

struct ProfileHeaderCard<Actions: View>: View {
    let profile: UserProfile
    let appearance: UserAssetAppearance?
    let realNameStatus: RealNameVerificationStatus?
    let onAvatarTap: (() -> Void)?
    let onBackgroundTap: (() -> Void)?
    let onQRCodeTap: (() -> Void)?
    let onRealNameTap: (() -> Void)?
    let onFollowersTap: (() -> Void)?
    let onFollowingTap: (() -> Void)?
    let onFriendsTap: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isBioExpanded = false
    @ViewBuilder let actions: () -> Actions

    init(
        profile: UserProfile,
        appearance: UserAssetAppearance? = nil,
        realNameStatus: RealNameVerificationStatus? = nil,
        onAvatarTap: (() -> Void)? = nil,
        onBackgroundTap: (() -> Void)? = nil,
        onQRCodeTap: (() -> Void)? = nil,
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
        self.onBackgroundTap = onBackgroundTap
        self.onQRCodeTap = onQRCodeTap
        self.onRealNameTap = onRealNameTap
        self.onFollowersTap = onFollowersTap
        self.onFollowingTap = onFollowingTap
        self.onFriendsTap = onFriendsTap
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 12) {
            heroBackground

            VStack(alignment: .leading, spacing: 12) {
                if !profile.bio.isEmpty {
                    bioView
                }

                if !profile.tags.isEmpty {
                    tagsFlow(profile.tags)
                }

                actions()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var heroBackground: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                ZStack {
                    RaverTheme.card
                    heroImageView
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.38),
                    Color.black.opacity(0.76),
                    RaverTheme.background.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 14) {
                        avatarView

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 7) {
                                Text(profile.displayName)
                                    .font(.title3.bold())
                                    .foregroundStyle(heroPrimaryTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)

                                if let onQRCodeTap {
                                    Button(action: onQRCodeTap) {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(heroPrimaryTextColor)
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(LT("查看个人二维码", "View profile QR code", "プロフィールのQRコードを見る"))
                                }

                                if let titleMedal = appearance?.titleMedal {
                                    VirtualAssetTitleMedalView(asset: titleMedal, compact: true, maxWidth: 138)
                                }
                            }

                            if let badges = appearance?.profileBadges, !badges.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(badges.prefix(5)) { badge in
                                            VirtualAssetBadgeView(asset: badge, compact: true, showTitle: true)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            HStack(spacing: 6) {
                                if let locationText = profileLocationText {
                                    metaPill(text: locationText)
                                }
                                if let joinedDaysText = profileJoinedDaysText {
                                    metaPill(text: joinedDaysText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let realNameStatus {
                                realNameBadge(status: realNameStatus)
                            }

                            statsRow(
                                valueColor: heroPrimaryTextColor,
                                titleColor: heroSecondaryTextColor,
                                spacing: 18
                            )
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(height: 250)
    }

    @ViewBuilder
    private var heroImageView: some View {
        if let onBackgroundTap {
            Button(action: onBackgroundTap) {
                heroImageContent
            }
            .buttonStyle(.plain)
        } else {
            heroImageContent
        }
    }

    @ViewBuilder
    private var heroImageContent: some View {
        if let resolved = AppConfig.resolvedURLString(profile.backgroundURL),
           let url = URL(string: resolved),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") || url.isFileURL {
            if url.isFileURL {
                localHeroImage(url: url)
            } else {
                ImageLoaderView(urlString: resolved)
                    .background(RaverTheme.card)
            }
        } else {
            LinearGradient(
                colors: [
                    RaverTheme.accent.opacity(0.55),
                    Color(red: 0.11, green: 0.14, blue: 0.22),
                    RaverTheme.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 240
                )
            )
        }
    }

    @ViewBuilder
    private func localHeroImage(url: URL) -> some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    RaverTheme.accent.opacity(0.55),
                    Color(red: 0.11, green: 0.14, blue: 0.22),
                    RaverTheme.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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

    private var profileLocationText: String? {
        let raw = profile.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return RegistrationRegionCatalog.load().displayText(for: raw)
    }

    private var profileJoinedDaysText: String? {
        guard let createdAt = profile.createdAt else { return nil }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: createdAt)
        let today = calendar.startOfDay(for: Date())
        let joinedDays = max((calendar.dateComponents([.day], from: startDay, to: today).day ?? 0) + 1, 1)
        return LT("加入\(joinedDays)天", "Joined \(joinedDays) days", "\(joinedDays)日参加")
    }

    private var hasCustomHeroBackground: Bool {
        guard let resolved = AppConfig.resolvedURLString(profile.backgroundURL),
              let url = URL(string: resolved) else {
            return false
        }
        return resolved.hasPrefix("http://") || resolved.hasPrefix("https://") || url.isFileURL
    }

    private var shouldUseLightHeroText: Bool {
        hasCustomHeroBackground || colorScheme == .dark
    }

    private var heroPrimaryTextColor: Color {
        shouldUseLightHeroText ? Color.white : RaverTheme.primaryText
    }

    private var heroSecondaryTextColor: Color {
        shouldUseLightHeroText ? Color.white.opacity(0.72) : RaverTheme.secondaryText
    }

    private var heroPillTextColor: Color {
        shouldUseLightHeroText ? Color.white.opacity(0.9) : RaverTheme.primaryText.opacity(0.86)
    }

    private var heroPillBackgroundColor: Color {
        shouldUseLightHeroText ? Color.white.opacity(0.13) : RaverTheme.card.opacity(0.72)
    }

    private func metaPill(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(heroPillTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(heroPillBackgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func tagsFlow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tags.prefix(12).enumerated()), id: \.offset) { _, tag in
                    Text(formattedTagText(tag))
                        .font(.caption)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RaverTheme.card)
                        .clipShape(Rectangle())
                }

                if tags.count > 12 {
                    Text("+\(tags.count - 12)")
                        .font(.caption.bold())
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RaverTheme.card)
                        .clipShape(Rectangle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var bioView: some View {
        if isBioExpanded {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBioExpanded = false
                }
            } label: {
                Text(profile.bio)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBioExpanded = true
                }
            } label: {
                HStack(spacing: 6) {
                    Text(profile.bio)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func formattedTagText(_ tag: String) -> String {
        tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .replacingOccurrences(of: "-", with: " ")
    }

    private func stat(_ title: String, value: Int, onTap: (() -> Void)? = nil) -> some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    statBody(title: title, value: value, valueColor: RaverTheme.primaryText, titleColor: RaverTheme.secondaryText)
                }
                .buttonStyle(.plain)
            } else {
                statBody(title: title, value: value, valueColor: RaverTheme.primaryText, titleColor: RaverTheme.secondaryText)
            }
        }
    }

    private func statsRow(valueColor: Color, titleColor: Color, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            statForHero(LT("动态", "Posts", "投稿"), value: profile.postsCount, valueColor: valueColor, titleColor: titleColor)
            statForHero(LT("粉丝", "Followers", "フォロワー"), value: profile.followersCount, valueColor: valueColor, titleColor: titleColor, onTap: onFollowersTap)
            statForHero(LT("关注", "Following", "フォロー中"), value: profile.followingCount, valueColor: valueColor, titleColor: titleColor, onTap: onFollowingTap)
            statForHero(LT("好友", "Friends", "友達"), value: profile.friendsCount, valueColor: valueColor, titleColor: titleColor, onTap: onFriendsTap)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statForHero(_ title: String, value: Int, valueColor: Color, titleColor: Color, onTap: (() -> Void)? = nil) -> some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    statBody(title: title, value: value, valueColor: valueColor, titleColor: titleColor)
                }
                .buttonStyle(.plain)
            } else {
                statBody(title: title, value: value, valueColor: valueColor, titleColor: titleColor)
            }
        }
    }

    private func statBody(title: String, value: Int, valueColor: Color, titleColor: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(valueColor)
            Text(title)
                .font(.caption)
                .foregroundStyle(titleColor)
        }
    }
}

struct ProfileRecentCheckinsCard: View {
    let title: String
    let checkins: [ProfileRecentCheckinPreview]
    let emptyText: String
    let onShowAll: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 6) {
                        Image("Check")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(RaverTheme.accent)
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)
                    }
                    Spacer()
                    Button(LT("查看全部", "View all", "すべて表示")) {
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
                    ForEach(Array(checkins.enumerated()), id: \.element.id) { index, item in
                        checkinPreviewRow(item, showsConnector: index < checkins.count - 1)
                    }
                }
            }
        }
    }

    private func checkinPreviewRow(_ item: ProfileRecentCheckinPreview, showsConnector: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(RaverTheme.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)

                if showsConnector {
                    Rectangle()
                        .fill(RaverTheme.accent.opacity(0.28))
                        .frame(width: 2, height: 28)
                        .padding(.top, 5)
                }
            }
            .frame(width: 12)

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

    private func checkinTitle(_ item: ProfileRecentCheckinPreview) -> String {
        item.title
    }

    private func checkinSubtitle(_ item: ProfileRecentCheckinPreview) -> String {
        let location = item.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLocation = location.isEmpty ? LT("现场记录", "Live Record", "ライブ記録") : location

        if let startDate = item.startDate {
            return "\(startDate.appLocalizedYMDText(in: item.eventTimeZone)) · \(fallbackLocation)"
        }
        return fallbackLocation
    }
}

private struct ProfileAvatarImage: View {
    let profile: UserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let avatarURL = profile.avatarURL,
               let url = URL(string: avatarURL),
               url.isFileURL,
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .background(fallbackAvatar)
            } else
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
            if let avatarURL = profile.avatarURL,
               let url = URL(string: avatarURL),
               url.isFileURL,
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .background(fallbackAvatar)
            } else
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
                        LT("暂无我的行程", "No Saved Routes", "保存済みルートはまだありません"),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        description: Text(LT("在活动时间表中定制并保存路线，或在活动详情缓存后，会显示在这里。", "Saved routes and cached events will appear here.", "イベントタイムテーブルでカスタム保存したルートや、イベント詳細のキャッシュがここに表示されます。"))
                    )
                    .padding(.top, 80)
                }

                if !routeStore.routes.isEmpty {
                    sectionHeader(
                        title: LT("我的路线", "My Saved Routes", "マイルート"),
                        subtitle: LT("按你在时间表中的选择生成", "Built from your timetable selections", "タイムテーブルでの選択から生成")
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
                                Label(LT("删除", "Delete", "削除"), systemImage: "trash")
                            }
                        }
                    }
                }

                if !cachedSnapshots.isEmpty || isLoadingCachedSnapshots {
                    sectionHeader(
                        title: LT("离线缓存活动", "Offline Cached Events", "オフラインキャッシュイベント"),
                        subtitle: LT("弱网或离线时可直接打开", "Open directly in weak-network or offline mode", "弱いネットワークやオフライン時も直接開けます")
                    )

                    if isLoadingCachedSnapshots, cachedSnapshots.isEmpty {
                        ProgressView(LT("加载缓存中...", "Loading cache...", "キャッシュを読み込み中..."))
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
                                    Label(LT("删除缓存", "Delete Cache", "キャッシュを削除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("我的行程", "My Routes", "マイルート"))
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
                        LT("\(route.selectedSlotIDs.count) 个已选演出", "\(route.selectedSlotIDs.count) selected sets", "選択済み出演 \(route.selectedSlotIDs.count)件"),
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
                        LT("缓存于 \(Self.dateTimeText(snapshot.cachedAt))", "Cached at \(Self.dateTimeText(snapshot.cachedAt))", "キャッシュ日時 \(Self.dateTimeText(snapshot.cachedAt))"),
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
        let start = route.startDate.appLocalizedYMDText(in: route.eventTimeZone)
        let end = route.endDate.appLocalizedYMDText(in: route.eventTimeZone)
        return start == end ? start : "\(start) - \(end)"
    }

    private func eventDateText(_ event: WebEvent) -> String {
        let start = event.startDate.appLocalizedYMDText(in: event.eventTimeZone)
        let end = event.endDate.appLocalizedYMDText(in: event.eventTimeZone)
        return start == end ? start : "\(start) - \(end)"
    }

    @MainActor
    private func loadCachedSnapshots() async {
        isLoadingCachedSnapshots = true
        defer { isLoadingCachedSnapshots = false }
        cachedSnapshots = await EventManualCacheStore.shared.allSnapshots()
    }

    private static func dateTimeText(_ date: Date) -> String {
        date.appLocalizedYMDHMText()
    }
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
                        title: LT("桌面倒计时管理", "Widget Countdown", "ウィジェットカウントダウン"),
                        subtitle: LT("集中管理已加入桌面小组件的活动。", "Manage events added to your home screen widget.", "ホーム画面ウィジェットに追加したイベントをまとめて管理します。"),
                        systemImage: "apps.iphone",
                        accent: Color(red: 0.38, green: 0.54, blue: 0.96)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    profilePush(.movieBanner)
                } label: {
                    ProfileToolFeatureCard(
                        title: LT("Movie Banner 弹幕", "Movie Banner", "Movie Banner"),
                        subtitle: LT("超大字体全屏弹幕，支持静态与跑马灯。", "Huge full-screen banner with static and marquee modes.", "超大文字のフルスクリーンバナー。静止表示とマーキーに対応します。"),
                        systemImage: "textformat.size.larger",
                        accent: Color(red: 0.93, green: 0.36, blue: 0.52)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("小工具", "Tools", "ツール"))
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
                        LT("还没有已添加的小组件活动", "No widget events yet", "追加済みウィジェットイベントはまだありません"),
                        systemImage: "apps.iphone",
                        description: Text(
                            LT("去活动详情页点击“添加到桌面倒计时”，这里就会集中显示。", "Add events from the event detail page and they will appear here.", "イベント詳細で「ウィジェットカウントダウンに追加」を押すと、ここにまとめて表示されます。")
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
                                    Label(LT("命名", "Rename", "名前変更"), systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    remove(event)
                                } label: {
                                    Label(LT("移除", "Remove", "削除"), systemImage: "trash")
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
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $editingEvent) { event in
            widgetRenameSheet(for: event)
        }
        .raverSystemNavigation(title: LT("桌面倒计时", "Widget Countdown", "ウィジェットカウントダウン"))
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
            errorMessage = LT("读取桌面倒计时列表失败，请稍后重试。", "Failed to load widget countdown events. Please try again later.", "ウィジェットカウントダウン一覧を読み込めませんでした。時間をおいて再試行してください。")
        }
    }

    private func selectLayoutStyle(_ layoutStyle: WidgetCountdownLayoutStyle) {
        guard selectedLayoutStyle != layoutStyle else { return }
        do {
            try WidgetSelectableEventsSyncService.shared.updateLayoutStyle(layoutStyle)
            selectedLayoutStyle = layoutStyle
        } catch {
            errorMessage = LT("切换文字排版方案失败，请稍后重试。", "Failed to switch the widget text layout. Please try again later.", "文字レイアウトを切り替えられませんでした。時間をおいて再試行してください。")
        }
    }

    private func remove(_ event: WidgetSelectableEvent) {
        do {
            _ = try WidgetSelectableEventsSyncService.shared.remove(eventID: event.id)
            events.removeAll { $0.id == event.id }
        } catch {
            errorMessage = LT("移除桌面倒计时活动失败，请稍后重试。", "Failed to remove widget countdown event. Please try again later.", "ウィジェットカウントダウンイベントを削除できませんでした。時間をおいて再試行してください。")
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
                    venueDisplayAddress: current.venueDisplayAddress,
                    startDate: current.startDate,
                    endDate: current.endDate,
                    dateRanges: current.dateRanges,
                    preferredBackgroundURL: current.preferredBackgroundURL,
                    cachedBackgroundImageRelativePath: current.cachedBackgroundImageRelativePath,
                    addedAt: current.addedAt
                )
            }
            editingEvent = nil
        } catch {
            errorMessage = LT("保存自定义名称失败，请稍后重试。", "Failed to save the custom widget name. Please try again later.", "カスタム名を保存できませんでした。時間をおいて再試行してください。")
        }
    }

    private func widgetEventMetaText(_ event: WidgetSelectableEvent) -> String? {
        var parts: [String] = []
        if event.customDisplayName != nil {
            parts.append(event.name)
        }
        if let nextDate = widgetNextRelevantDateText(event) {
            parts.append(nextDate)
        }
        if let venue = widgetTrimmed(event.venueDisplayAddress) {
            parts.append(venue)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func widgetNextRelevantDateText(_ event: WidgetSelectableEvent) -> String? {
        let today = Calendar.current.startOfDay(for: Date())
        let selectedRange = event.normalizedDateRanges.first {
            Calendar.current.startOfDay(for: max($0.endDate, $0.startDate)) >= today
        } ?? event.normalizedDateRanges.last
        guard let selectedRange else { return nil }
        return selectedRange.startDate.appLocalizedDateRangeText(
            to: selectedRange.endDate,
            timeZone: .current
        )
    }

    @ViewBuilder
    private func widgetRenameSheet(for event: WidgetSelectableEvent) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        LT("输入小组件名称", "Enter widget name", "ウィジェット名を入力"),
                        text: $customNameDraft
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                } footer: {
                    Text(
                        LT("仅保存在当前设备，用于小组件展示和选择，不会同步到线上或其他设备。留空则恢复活动原名。", "Saved only on this device for widget display and selection. It will not sync online or to other devices. Leave blank to restore the original event name.", "この端末にのみ保存され、ウィジェット表示と選択に使われます。オンラインや他の端末には同期されません。空欄にすると元のイベント名に戻ります。")
                    )
                }

                Section(LT("原活动名称", "Original Event Name", "元のイベント名")) {
                    Text(event.name)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RaverTheme.background)
            .navigationTitle(LT("自定义名称", "Custom Name", "カスタム名"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LT("取消", "Cancel", "キャンセル")) {
                        editingEvent = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LT("保存", "Save", "保存")) {
                        saveCustomName(for: event)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var widgetLayoutStyleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LT("文字排版方案", "Text Layout Styles", "Text Layout Styles"))
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

                    Text(LT("还有 5 天", "5 days left", "あと5日"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
                .padding(10)
            case .distance:
                VStack(alignment: .leading, spacing: 0) {
                    (
                        Text(LT("距离", "Until ", "あと"))
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

                        Text(LT("天", "days", "日"))
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
    @State private var inlinePreviewStarted = false
    @State private var inlinePreviewRevision = 0
    @State private var displayPreparedLandscapeLock = false
    @State private var prepareDisplayTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool

    private var canStart: Bool {
        !configuration.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var editorFontSizeRange: ClosedRange<Double> {
        MovieBannerConfiguration.fontSizeRange(
            for: MovieBannerConfiguration.referenceLandscapeCanvasSize,
            mode: configuration.mode
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LT("弹幕内容", "Banner Message", "バナーメッセージ"))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)

                        TextField(
                            LT("例如：XXX看这里 / 前排求互动", "For example: Look here / Front row says hi", "例: XXXこっち見て / 最前列からリアクション希望"),
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

                        HStack(spacing: 10) {
                            Button {
                                isInputFocused = false
                                inlinePreviewStarted = true
                                inlinePreviewRevision += 1
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles.tv")
                                    Text(LT("预览效果", "Preview", "プレビュー"))
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canStart)

                            Button {
                                isInputFocused = false
                                prepareDisplayTask?.cancel()
                                prepareDisplayTask = Task {
                                    await prepareLandscapeDisplay()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text(LT("开始展示", "Start", "表示開始"))
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!canStart)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(LT("横屏预览", "Landscape Preview", "横向きプレビュー"))
                                .font(.headline)
                                .foregroundStyle(RaverTheme.primaryText)
                            Spacer(minLength: 12)
                            Text(LT("竖屏内先调效果", "Tune It Before Fullscreen", "全画面前に調整"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Text(LT(
                            "这里模拟手机横屏全屏区域。先点一次预览，再在竖屏里快速微调参数。",
                            "This simulates the landscape fullscreen area. Tap preview once, then fine-tune here in portrait.",
                            "ここで横向き全画面エリアを再現します。先にプレビューしてから縦画面で微調整できます。"
                        ))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                        MovieBannerInlinePreviewView(
                            configuration: configuration,
                            isActive: inlinePreviewStarted,
                            revision: inlinePreviewRevision
                        )
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LT("展示设置", "Display Settings", "表示設定"))
                                    .font(.headline)
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(LT(
                                    "在竖屏里快速调准视觉效果，再一键进入横屏全屏。",
                                    "Tune the visual feel in portrait, then jump into fullscreen.",
                                    "縦画面で見た目を整えてから、そのまま全画面へ。"
                                ))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            }

                            Spacer(minLength: 8)

                            Text(configuration.mode.shortTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(RaverTheme.accent.opacity(0.16))
                                )
                        }

                        settingsPanel(
                            title: LT("版式与字号", "Layout & Size", "レイアウトと文字サイズ"),
                            icon: "textformat.size"
                        ) {
                            Picker(
                                LT("展示模式", "Display Mode", "表示モード"),
                                selection: $configuration.mode
                            ) {
                                ForEach(MovieBannerMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            settingSliderRow(
                                title: LT("字体大小", "Font Size", "文字サイズ"),
                                valueText: "\(Int(configuration.fontSize))",
                                value: $configuration.fontSize,
                                range: editorFontSizeRange,
                                step: 2
                            )
                        }

                        settingsPanel(
                            title: LT("滚动与节奏", "Motion & Rhythm", "動きとリズム"),
                            icon: "waveform.path.ecg"
                        ) {
                            Toggle(LT("自动滚动", "Auto Scroll", "自動スクロール"), isOn: $configuration.autoScroll)
                                .tint(RaverTheme.accent)
                                .foregroundStyle(RaverTheme.primaryText)

                            settingSliderRow(
                                title: LT("滚动速度", "Scroll Speed", "スクロール速度"),
                                valueText: "\(Int(configuration.scrollSpeed))",
                                value: $configuration.scrollSpeed,
                                range: MovieBannerConfiguration.scrollSpeedRange,
                                step: 5
                            )

                            if configuration.mode == .scrolling {
                                settingSliderRow(
                                    title: LT("短文循环间距", "Short Loop Gap", "短文ループ間隔"),
                                    valueText: "\(Int(configuration.shortLoopGap))",
                                    value: $configuration.shortLoopGap,
                                    range: MovieBannerConfiguration.shortLoopGapRange,
                                    step: 2
                                )
                            }
                        }

                        settingsPanel(
                            title: LT("闪烁效果", "Blink Effect", "点滅効果"),
                            icon: "bolt"
                        ) {
                            Toggle(LT("启用闪烁", "Enable Blink", "点滅を有効化"), isOn: $configuration.isBlinkEnabled)
                                .tint(RaverTheme.accent)
                                .foregroundStyle(RaverTheme.primaryText)

                            if configuration.isBlinkEnabled {
                                settingSliderRow(
                                    title: LT("闪烁速度", "Blink Speed", "点滅速度"),
                                    valueText: "\(Int(configuration.blinkSpeed))",
                                    value: $configuration.blinkSpeed,
                                    range: MovieBannerConfiguration.blinkSpeedRange,
                                    step: 1
                                )

                                settingSliderRow(
                                    title: LT("熄灭亮度", "Dim Brightness", "消灯亮度"),
                                    valueText: "\(Int(configuration.blinkMinOpacity * 100))%",
                                    value: $configuration.blinkMinOpacity,
                                    range: MovieBannerConfiguration.blinkMinOpacityRange,
                                    step: 0.05
                                )
                            }
                        }

                        settingsPanel(
                            title: LT("颜色与氛围", "Color & Mood", "色とムード"),
                            icon: "paintpalette"
                        ) {
                            MovieBannerColorPickerRow(
                                title: LT("文字颜色", "Text Color", "Text Color"),
                                selection: $configuration.textColor
                            )

                            MovieBannerColorPickerRow(
                                title: LT("背景颜色", "Background", "背景色"),
                                selection: $configuration.backgroundColor
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("Movie Banner", "Movie Banner", "Movie Banner"))
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
        .onAppear {
            clampEditorFontSize()
        }
        .onChange(of: configuration.mode) { _, _ in
            clampEditorFontSize()
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

    @ViewBuilder
    private func settingsPanel<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
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

    private func clampEditorFontSize() {
        configuration.fontSize = min(
            max(configuration.fontSize, editorFontSizeRange.lowerBound),
            editorFontSizeRange.upperBound
        )
    }
}

private struct MovieBannerInlinePreviewView: View {
    let configuration: MovieBannerConfiguration
    let isActive: Bool
    let revision: Int

    @State private var scrollStartDate = Date()
    @State private var marqueeLayout = MovieBannerMarqueeLayout()

    private var hasContent: Bool {
        !configuration.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var simulatedLandscapeCanvasSize: CGSize {
        let bounds = UIScreen.main.bounds.size
        let longEdge = max(bounds.width, bounds.height)
        let shortEdge = min(bounds.width, bounds.height)
        return CGSize(width: longEdge, height: shortEdge)
    }

    private var simulatedAspectRatio: CGFloat {
        simulatedLandscapeCanvasSize.width / max(simulatedLandscapeCanvasSize.height, 1)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(configuration.backgroundColor.color)
                .padding(8)
                .overlay {
                    if isActive, hasContent {
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                            GeometryReader { proxy in
                                let canvasSize = simulatedLandscapeCanvasSize
                                let scale = min(
                                    proxy.size.width / max(canvasSize.width, 1),
                                    proxy.size.height / max(canvasSize.height, 1)
                                )

                                bannerContent(in: context.date, size: canvasSize)
                                    .frame(width: canvasSize.width, height: canvasSize.height)
                                    .scaleEffect(scale, anchor: .topLeading)
                                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(8)
                    } else {
                        previewPlaceholder
                            .padding(8)
                    }
                }

            previewBadge
        }
        .aspectRatio(simulatedAspectRatio, contentMode: .fit)
        .onAppear {
            resetScrollProgress()
        }
        .onChange(of: revision) { _, _ in
            resetScrollProgress()
        }
        .onChange(of: configuration.mode) { _, _ in
            resetScrollProgress()
        }
        .onChange(of: configuration.autoScroll) { _, _ in
            resetScrollProgress()
        }
        .onChange(of: configuration.message) { _, _ in
            resetScrollProgress()
        }
        .onChange(of: configuration.fontSize) { _, _ in
            resetScrollProgress()
        }
        .onChange(of: configuration.scrollSpeed) { _, _ in
            resetScrollProgress()
        }
        .onChange(of: configuration.shortLoopGap) { _, _ in
            resetScrollProgress()
        }
    }

    private var previewBadge: some View {
        VStack {
            HStack {
                Label(
                    LT("横屏模拟预览", "Landscape Mock Preview", "横向き模擬プレビュー"),
                    systemImage: "iphone.landscape"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.78))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.42))
                )

                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .allowsHitTesting(false)
    }

    private var previewPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(configuration.backgroundColor.color)
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: hasContent ? "play.rectangle" : "text.cursor")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))

                    Text(
                        hasContent
                            ? LT("点击上方“预览效果”后，这里会模拟全屏展示。", "Tap Preview above to simulate fullscreen here.", "上のプレビューを押すと、ここで全画面表示を再現します。")
                            : LT("先输入文案，再点击“预览效果”。", "Enter a message, then tap Preview.", "先に文言を入力してからプレビューしてください。")
                    )
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func bannerContent(in renderDate: Date, size: CGSize) -> some View {
        if configuration.mode == .staticCentered || !configuration.autoScroll {
            centeredTextView(renderDate: renderDate, size: size)
                .frame(width: size.width, height: size.height)
        } else {
            scrollingTextView(renderDate: renderDate, size: size)
                .frame(width: size.width, height: size.height)
        }
    }

    private func centeredTextView(renderDate: Date, size: CGSize) -> some View {
        bannerText(layout: resolvedMarqueeLayout(for: size), text: resolvedMessage)
            .lineLimit(1)
            .minimumScaleFactor(0.12)
            .padding(.horizontal, 20)
            .opacity(blinkOpacity(at: renderDate))
            .task(id: marqueeLayoutKey(for: size)) {
                updateMarqueeLayout(for: size)
            }
    }

    private func scrollingTextView(renderDate: Date, size: CGSize) -> some View {
        let layout = resolvedMarqueeLayout(for: size)
        let elapsed = max(0, renderDate.timeIntervalSince(scrollStartDate))
        let effectiveSpeed = configuration.scrollSpeed * layout.speedCompensation
        let travel = CGFloat((elapsed * effectiveSpeed).truncatingRemainder(dividingBy: Double(layout.cycleWidth)))

        return marqueeLoopContent(layout: layout)
        .offset(x: layout.leadingOffset - travel)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipped()
        .opacity(blinkOpacity(at: renderDate))
        .task(id: marqueeLayoutKey(for: size)) {
            updateMarqueeLayout(for: size)
        }
    }

    @ViewBuilder
    private func marqueeLoopContent(layout: MovieBannerMarqueeLayout) -> some View {
        if layout.usesUnitCycling {
            marqueeTrack(layout: layout)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
        } else {
            HStack(spacing: layout.seamSpacing) {
                marqueeTrack(layout: layout)
                marqueeTrack(layout: layout)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
        }
    }

    private func bannerText(layout: MovieBannerMarqueeLayout, text: String) -> some View {
        Text(text)
            .font(.system(size: layout.effectiveFontSize, weight: .bold))
            .foregroundStyle(configuration.textColor.color)
            .shadow(
                color: configuration.textColor.color.opacity(0.24),
                radius: layout.shadowRadius,
                x: 0,
                y: 0
            )
    }

    private var resolvedMessage: String {
        let trimmed = configuration.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LT("请输入内容", "Type Something", "内容を入力") : trimmed
    }

    private func blinkOpacity(at date: Date) -> Double {
        guard configuration.isBlinkEnabled else { return 1.0 }
        let phase = sin(date.timeIntervalSinceReferenceDate * configuration.blinkSpeed)
        return phase > 0 ? 1.0 : configuration.blinkMinOpacity
    }

    private func marqueeLayoutKey(for size: CGSize) -> MovieBannerMarqueeLayoutKey {
        MovieBannerMarqueeLayoutKey(
            message: resolvedMessage,
            mode: configuration.mode,
            requestedFontSize: configuration.fontSize,
            shortLoopGap: configuration.shortLoopGap,
            size: size
        )
    }

    private func resolvedMarqueeLayout(for size: CGSize) -> MovieBannerMarqueeLayout {
        let key = marqueeLayoutKey(for: size)
        if marqueeLayout.cacheKey == key {
            return marqueeLayout
        }
        return MovieBannerMarqueeLayout.build(
            key: key,
            size: size
        )
    }

    private func updateMarqueeLayout(for size: CGSize) {
        marqueeLayout = MovieBannerMarqueeLayout.build(
            key: marqueeLayoutKey(for: size),
            size: size
        )
    }

    @ViewBuilder
    private func marqueeTrack(layout: MovieBannerMarqueeLayout) -> some View {
        if layout.usesRepeatedItems {
            HStack(spacing: layout.itemSpacing) {
                ForEach(0 ..< layout.repeatedItemCount, id: \.self) { _ in
                    bannerText(layout: layout, text: resolvedMessage)
                }
            }
        } else {
            bannerText(layout: layout, text: layout.segmentText)
        }
    }

    private func resetScrollProgress() {
        scrollStartDate = Date()
        marqueeLayout = MovieBannerMarqueeLayout()
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
    @State private var marqueeLayout = MovieBannerMarqueeLayout()
    @State private var temporaryPauseDate: Date?
    @State private var temporaryPauseTask: Task<Void, Never>?

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
            temporaryPauseTask?.cancel()
            temporaryPauseTask = nil
            temporaryPauseDate = nil
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
        .onChange(of: configuration.message) { _, _ in
            resetScrollProgress()
        }
    }

    @ViewBuilder
    private func bannerContent(in renderDate: Date) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            if configuration.mode == .staticCentered {
                centeredTextView(renderDate: renderDate, size: size)
                    .frame(width: size.width, height: size.height)
            } else if configuration.autoScroll {
                scrollingTextView(renderDate: renderDate, size: size)
                    .frame(width: size.width, height: size.height)
            } else {
                centeredTextView(renderDate: renderDate, size: size)
                    .frame(width: size.width, height: size.height)
            }
        }
    }

    private func centeredTextView(renderDate: Date, size: CGSize) -> some View {
        bannerText(layout: resolvedMarqueeLayout(for: size), text: resolvedMessage)
            .lineLimit(1)
            .minimumScaleFactor(0.12)
            .padding(.horizontal, 20)
            .opacity(blinkOpacity(at: renderDate))
            .task(id: marqueeLayoutKey(for: size)) {
                updateMarqueeLayout(for: size)
            }
    }

    private func scrollingTextView(renderDate: Date, size: CGSize) -> some View {
        let layout = resolvedMarqueeLayout(for: size)
        let timelineDate = frozenDate(for: renderDate)
        let elapsed = max(0, timelineDate.timeIntervalSince(scrollStartDate) - pausedDuration)
        let effectiveSpeed = configuration.scrollSpeed * layout.speedCompensation
        let travel = CGFloat((elapsed * effectiveSpeed).truncatingRemainder(dividingBy: Double(layout.cycleWidth)))

        return marqueeLoopContent(layout: layout)
        .offset(x: layout.leadingOffset - travel)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipped()
        .opacity(blinkOpacity(at: timelineDate))
        .task(id: marqueeLayoutKey(for: size)) {
            updateMarqueeLayout(for: size)
        }
    }

    @ViewBuilder
    private func marqueeLoopContent(layout: MovieBannerMarqueeLayout) -> some View {
        if layout.usesUnitCycling {
            marqueeTrack(layout: layout)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
        } else {
            HStack(spacing: layout.seamSpacing) {
                marqueeTrack(layout: layout)
                marqueeTrack(layout: layout)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var controlsLayer: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                topControlsRow
                modePickerControl

                if configuration.mode == .scrolling {
                    scrollSpeedControl
                    shortGapControl
                }

                if configuration.isBlinkEnabled {
                    blinkSpeedControl
                    blinkBrightnessControl
                }

                fontSizeControl
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

    private var topControlsRow: some View {
        HStack(spacing: 10) {
            Button {
                isPresented = false
            } label: {
                Label(LT("返回", "Back", "戻る"), systemImage: "chevron.backward")
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
                            ? (isPaused ? LT("继续", "Resume", "再開") : LT("暂停", "Pause", "Pause"))
                            : LT("开始滚动", "Start Scroll", "スクロール開始"),
                        systemImage: configuration.autoScroll
                            ? (isPaused ? "play.fill" : "pause.fill")
                            : "play.fill"
                    )
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)

            Button {
                configuration.textColor = configuration.textColor.nextPreset
                keepControlsVisible()
            } label: {
                Label(LT("文字色", "Text", "Text"), systemImage: "paintpalette")
            }
            .buttonStyle(.bordered)

            Button {
                configuration.backgroundColor = configuration.backgroundColor.nextPreset
                keepControlsVisible()
            } label: {
                Label(LT("背景色", "BG", "BG"), systemImage: "circle.lefthalf.filled")
            }
            .buttonStyle(.bordered)

            Button {
                configuration.isBlinkEnabled.toggle()
                keepControlsVisible()
            } label: {
                Label(
                    LT("闪烁", "Blink", "点滅"),
                    systemImage: configuration.isBlinkEnabled ? "bolt.fill" : "bolt.slash"
                )
            }
            .buttonStyle(.bordered)
        }
    }

    private var modePickerControl: some View {
        Picker(
            LT("模式", "Mode", "モード"),
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
    }

    private var scrollSpeedControl: some View {
        controlsSliderSection(
            title: LT("速度", "Speed", "速度"),
            valueText: "\(Int(configuration.scrollSpeed))",
            value: $configuration.scrollSpeed,
            range: MovieBannerConfiguration.scrollSpeedRange,
            step: 5,
            minimumLabel: LT("慢", "Slow", "遅い"),
            maximumLabel: LT("快", "Fast", "速い")
        )
    }

    private var shortGapControl: some View {
        controlsSliderSection(
            title: LT("短文间距", "Short Gap", "短文間隔"),
            valueText: "\(Int(configuration.shortLoopGap))",
            value: $configuration.shortLoopGap,
            range: MovieBannerConfiguration.shortLoopGapRange,
            step: 2,
            minimumLabel: LT("近", "Tight", "狭い"),
            maximumLabel: LT("远", "Wide", "広い")
        )
    }

    private var blinkSpeedControl: some View {
        controlsSliderSection(
            title: LT("闪烁速度", "Blink Speed", "点滅速度"),
            valueText: "\(Int(configuration.blinkSpeed))",
            value: $configuration.blinkSpeed,
            range: MovieBannerConfiguration.blinkSpeedRange,
            step: 1,
            minimumLabel: LT("慢", "Slow", "遅い"),
            maximumLabel: LT("快", "Fast", "速い")
        )
    }

    private var blinkBrightnessControl: some View {
        controlsSliderSection(
            title: LT("熄灭亮度", "Dim Brightness", "消灯亮度"),
            valueText: "\(Int(configuration.blinkMinOpacity * 100))%",
            value: $configuration.blinkMinOpacity,
            range: MovieBannerConfiguration.blinkMinOpacityRange,
            step: 0.05,
            minimumLabel: LT("灭", "Off", "消灯"),
            maximumLabel: LT("透", "Dim", "薄い")
        )
    }

    private var fontSizeControl: some View {
        controlsSliderSection(
            title: LT("字号", "Size", "文字サイズ"),
            valueText: "\(Int(configuration.fontSize))",
            value: $configuration.fontSize,
            range: MovieBannerConfiguration.fontSizeRange(
                for: MovieBannerConfiguration.referenceLandscapeCanvasSize,
                mode: configuration.mode
            ),
            step: 2,
            minimumLabel: LT("小", "Small", "小"),
            maximumLabel: LT("大", "Large", "大")
        )
    }

    @ViewBuilder
    private func controlsSliderSection(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        minimumLabel: String,
        maximumLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer(minLength: 8)
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            Slider(
                value: value,
                in: range,
                step: step
            ) {
                Text(title)
            } minimumValueLabel: {
                Text(minimumLabel)
                    .font(.caption2)
            } maximumValueLabel: {
                Text(maximumLabel)
                    .font(.caption2)
            } onEditingChanged: { _ in
                keepControlsVisible()
            }
            .tint(.white)
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
        bannerText(layout: marqueeLayout, text: resolvedMessage)
    }

    private func bannerText(layout: MovieBannerMarqueeLayout, text: String) -> some View {
        Text(text)
            .font(.system(size: layout.effectiveFontSize, weight: .bold))
            .foregroundStyle(configuration.textColor.color)
            .shadow(
                color: configuration.textColor.color.opacity(0.24),
                radius: layout.shadowRadius,
                x: 0,
                y: 0
            )
    }

    private var resolvedMessage: String {
        let trimmed = configuration.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LT("请输入内容", "Type Something", "内容を入力") : trimmed
    }

    private func blinkOpacity(at date: Date) -> Double {
        guard configuration.isBlinkEnabled else { return 1.0 }
        let phase = sin(date.timeIntervalSinceReferenceDate * configuration.blinkSpeed)
        return phase > 0 ? 1.0 : configuration.blinkMinOpacity
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
        freezeMarqueeForControlsAnimation()
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
                freezeMarqueeForControlsAnimation()
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
        temporaryPauseTask?.cancel()
        temporaryPauseTask = nil
        temporaryPauseDate = nil
    }

    private func frozenDate(for date: Date) -> Date {
        guard configuration.mode == .scrolling, configuration.autoScroll else {
            return date
        }
        if let temporaryPauseDate {
            return temporaryPauseDate
        }
        if isPaused, let pausedDate {
            return pausedDate
        }
        return date
    }

    private func marqueeLayoutKey(for size: CGSize) -> MovieBannerMarqueeLayoutKey {
        MovieBannerMarqueeLayoutKey(
            message: resolvedMessage,
            mode: configuration.mode,
            requestedFontSize: configuration.fontSize,
            shortLoopGap: configuration.shortLoopGap,
            size: size
        )
    }

    private func resolvedMarqueeLayout(for size: CGSize) -> MovieBannerMarqueeLayout {
        let key = marqueeLayoutKey(for: size)
        if marqueeLayout.cacheKey == key {
            return marqueeLayout
        }
        return MovieBannerMarqueeLayout.build(
            key: key,
            size: size
        )
    }

    private func updateMarqueeLayout(for size: CGSize) {
        marqueeLayout = MovieBannerMarqueeLayout.build(
            key: marqueeLayoutKey(for: size),
            size: size
        )
    }

    @ViewBuilder
    private func marqueeTrack(layout: MovieBannerMarqueeLayout) -> some View {
        if layout.usesRepeatedItems {
            HStack(spacing: layout.itemSpacing) {
                ForEach(0 ..< layout.repeatedItemCount, id: \.self) { _ in
                    bannerText(layout: layout, text: resolvedMessage)
                }
            }
        } else {
            bannerText(layout: layout, text: layout.segmentText)
        }
    }

    private func freezeMarqueeForControlsAnimation() {
        guard configuration.mode == .scrolling, configuration.autoScroll, !isPaused else { return }
        let pauseAnchor = temporaryPauseDate ?? Date()
        temporaryPauseDate = pauseAnchor
        temporaryPauseTask?.cancel()
        temporaryPauseTask = Task {
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                pausedDuration += Date().timeIntervalSince(pauseAnchor)
                temporaryPauseDate = nil
                temporaryPauseTask = nil
            }
        }
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
    @Binding var selection: MovieBannerColorValue

    private var colorBinding: Binding<Color> {
        Binding(
            get: { selection.color },
            set: { selection = MovieBannerColorValue(color: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(title)
                    .foregroundStyle(RaverTheme.primaryText)

                Spacer(minLength: 12)

                Text(selection.hexDescription)
                    .font(.caption.monospaced())
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )

                ColorPicker("", selection: colorBinding, supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 30, height: 30)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MovieBannerColorSwatch.allCases) { swatch in
                        let isSelected = selection.matches(swatch.value)
                        Button {
                            selection = swatch.value
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(swatch.value.color)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.45), lineWidth: 1)
                                    )
                                Text(swatch.title)
                                    .font(.caption)
                            }
                            .foregroundStyle(isSelected ? RaverTheme.primaryText : RaverTheme.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
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

private struct MovieBannerMarqueeLayoutKey: Equatable, Hashable {
    let message: String
    let mode: MovieBannerMode
    let requestedFontSize: Int
    let shortLoopGap: Int
    let width: Int
    let height: Int

    init(message: String, mode: MovieBannerMode, requestedFontSize: Double, shortLoopGap: Double, size: CGSize) {
        self.message = message
        self.mode = mode
        self.requestedFontSize = Int(requestedFontSize.rounded())
        self.shortLoopGap = Int(shortLoopGap.rounded())
        width = Int(size.width.rounded())
        height = Int(size.height.rounded())
    }
}

private struct MovieBannerMarqueeLayout {
    var cacheKey = MovieBannerMarqueeLayoutKey(
        message: "",
        mode: .scrolling,
        requestedFontSize: MovieBannerConfiguration.minimumFontSize,
        shortLoopGap: 40,
        size: .zero
    )
    var effectiveFontSize: CGFloat = CGFloat(MovieBannerConfiguration.minimumFontSize)
    var segmentText: String = ""
    var usesRepeatedItems = false
    var usesUnitCycling = false
    var repeatedItemCount = 1
    var itemSpacing: CGFloat = 24
    var seamSpacing: CGFloat = 24
    var leadingOffset: CGFloat = 0
    var cycleWidth: CGFloat = 1
    var speedCompensation: Double = 1.0
    var shadowRadius: CGFloat = 4

    static func build(key: MovieBannerMarqueeLayoutKey, size: CGSize) -> MovieBannerMarqueeLayout {
        let effectiveFontSize = CGFloat(
            min(
                max(MovieBannerConfiguration.minimumFontSize, Double(key.requestedFontSize)),
                MovieBannerConfiguration.maximumFontSize(for: size, mode: key.mode)
            )
        )
        let font = UIFont.systemFont(ofSize: effectiveFontSize, weight: .bold)
        let baseMessage = key.message
        let baseWidth = measureWidth(of: baseMessage, font: font)
        let shortTrackThreshold = max(1, size.width * 0.6)
        let targetTrackWidth = max(size.width * 1.35, shortTrackThreshold)
        let segmentText = baseMessage
        var usesRepeatedItems = false
        var usesUnitCycling = false
        var repeatedItemCount = 1
        var trackWidth = baseWidth
        let shortLoopGap = CGFloat(max(Int(MovieBannerConfiguration.shortLoopGapRange.lowerBound), key.shortLoopGap))
        var itemSpacing = shortLoopGap
        var seamSpacing = max(24, min(72, effectiveFontSize * 0.35))
        var leadingOffset: CGFloat = 0
        var cycleWidth = max(1, baseWidth + seamSpacing)

        if key.mode == .scrolling, baseWidth < shortTrackThreshold {
            usesRepeatedItems = true
            usesUnitCycling = true
            seamSpacing = shortLoopGap
            itemSpacing = shortLoopGap
            while trackWidth < targetTrackWidth, repeatedItemCount < 16 {
                repeatedItemCount += 1
                trackWidth = baseWidth * CGFloat(repeatedItemCount) + itemSpacing * CGFloat(repeatedItemCount - 1)
            }
            cycleWidth = max(1, baseWidth + itemSpacing)
            leadingOffset = -cycleWidth
        } else {
            cycleWidth = max(1, trackWidth + seamSpacing)
        }

        let widthRatio = max(1.0, Double(trackWidth / max(size.width, 1)))
        let speedCompensation = min(1.8, max(1.0, sqrt(widthRatio)))
        let shadowRadius: CGFloat = key.mode == .scrolling
            ? max(3, min(6, effectiveFontSize * 0.024))
            : max(4, min(10, effectiveFontSize * 0.036))

        var layout = MovieBannerMarqueeLayout()
        layout.cacheKey = key
        layout.effectiveFontSize = effectiveFontSize
        layout.segmentText = segmentText
        layout.usesRepeatedItems = usesRepeatedItems
        layout.usesUnitCycling = usesUnitCycling
        layout.repeatedItemCount = repeatedItemCount
        layout.itemSpacing = itemSpacing
        layout.seamSpacing = seamSpacing
        layout.leadingOffset = leadingOffset
        layout.cycleWidth = cycleWidth
        layout.speedCompensation = speedCompensation
        layout.shadowRadius = shadowRadius
        return layout
    }

    private static func measureWidth(of text: String, font: UIFont) -> CGFloat {
        max(1, ceil(NSString(string: text).size(withAttributes: [.font: font]).width))
    }
}

private struct MovieBannerConfiguration {
    static let minimumFontSize: Double = 64
    static let scrollSpeedRange: ClosedRange<Double> = 40 ... 520
    static let blinkSpeedRange: ClosedRange<Double> = 1 ... 20
    static let blinkMinOpacityRange: ClosedRange<Double> = 0 ... 0.75
    static let shortLoopGapRange: ClosedRange<Double> = 12 ... 220
    static let defaultScrollSpeed: Double = 140
    static var referenceLandscapeCanvasSize: CGSize {
        let bounds = UIScreen.main.bounds.size
        let longEdge = max(bounds.width, bounds.height)
        let shortEdge = min(bounds.width, bounds.height)
        return CGSize(width: longEdge, height: shortEdge)
    }

    static func fontSizeRange(for size: CGSize, mode: MovieBannerMode) -> ClosedRange<Double> {
        minimumFontSize ... maximumFontSize(for: size, mode: mode)
    }

    static func maximumFontSize(for size: CGSize, mode: MovieBannerMode) -> Double {
        let shortEdge = max(1, min(size.width, size.height))
        let ratio = mode == .staticCentered ? 0.9 : 0.8
        return max(minimumFontSize, floor(shortEdge * ratio))
    }

    var message: String = ""
    var fontSize: Double = 120
    var scrollSpeed: Double = defaultScrollSpeed
    var isBlinkEnabled: Bool = false
    var blinkSpeed: Double = 8
    var blinkMinOpacity: Double = 0.28
    var autoScroll: Bool = true
    var shortLoopGap: Double = 40
    var mode: MovieBannerMode = .scrolling
    var textColor: MovieBannerColorValue = .white
    var backgroundColor: MovieBannerColorValue = .black
}

private enum MovieBannerMode: String, CaseIterable, Identifiable {
    case staticCentered
    case scrolling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .staticCentered:
            return LT("静态居中", "Static Center", "中央固定")
        case .scrolling:
            return LT("横向滚动", "Scrolling", "横スクロール")
        }
    }

    var shortTitle: String {
        switch self {
        case .staticCentered:
            return LT("静态", "Static", "静止")
        case .scrolling:
            return LT("滚动", "Scroll", "スクロール")
        }
    }
}

private struct MovieBannerColorValue: Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        } else {
            self = .white
        }
    }

    static let white = MovieBannerColorValue(red: 1, green: 1, blue: 1)
    static let black = MovieBannerColorValue(red: 0, green: 0, blue: 0)

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var hexDescription: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        let a = Int((alpha * 255).rounded())
        if a < 255 {
            return String(format: "#%02X%02X%02X %02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    func matches(_ other: MovieBannerColorValue, tolerance: Double = 0.01) -> Bool {
        abs(red - other.red) <= tolerance &&
            abs(green - other.green) <= tolerance &&
            abs(blue - other.blue) <= tolerance &&
            abs(alpha - other.alpha) <= tolerance
    }

    var nextPreset: MovieBannerColorValue {
        let all = MovieBannerColorSwatch.allCases
        if let index = all.firstIndex(where: { matches($0.value) }) {
            let nextIndex = all.index(after: index)
            return nextIndex == all.endIndex ? all[all.startIndex].value : all[nextIndex].value
        }
        return all.first?.value ?? self
    }
}

private enum MovieBannerColorSwatch: String, CaseIterable, Identifiable {
    case white
    case black
    case red
    case yellow
    case lime
    case cyan
    case pink
    case violet
    case orange
    case blue
    case mint
    case gold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white:
            return LT("白", "White", "白")
        case .black:
            return LT("黑", "Black", "黒")
        case .red:
            return LT("红", "Red", "赤")
        case .yellow:
            return LT("黄", "Yellow", "黄")
        case .lime:
            return LT("荧绿", "Lime", "ライム")
        case .cyan:
            return LT("青", "Cyan", "シアン")
        case .pink:
            return LT("粉", "Pink", "ピンク")
        case .violet:
            return LT("紫", "Violet", "バイオレット")
        case .orange:
            return LT("橙", "Orange", "オレンジ")
        case .blue:
            return LT("蓝", "Blue", "青")
        case .mint:
            return LT("薄荷", "Mint", "ミント")
        case .gold:
            return LT("金", "Gold", "ゴールド")
        }
    }

    var value: MovieBannerColorValue {
        switch self {
        case .white:
            return .white
        case .black:
            return .black
        case .red:
            return MovieBannerColorValue(red: 1.0, green: 0.23, blue: 0.19)
        case .yellow:
            return MovieBannerColorValue(red: 1.0, green: 0.88, blue: 0.16)
        case .lime:
            return MovieBannerColorValue(red: 0.62, green: 1.0, blue: 0.23)
        case .cyan:
            return MovieBannerColorValue(red: 0.17, green: 0.93, blue: 1.0)
        case .pink:
            return MovieBannerColorValue(red: 1.0, green: 0.35, blue: 0.73)
        case .violet:
            return MovieBannerColorValue(red: 0.58, green: 0.36, blue: 1.0)
        case .orange:
            return MovieBannerColorValue(red: 1.0, green: 0.54, blue: 0.15)
        case .blue:
            return MovieBannerColorValue(red: 0.21, green: 0.56, blue: 1.0)
        case .mint:
            return MovieBannerColorValue(red: 0.53, green: 0.97, blue: 0.78)
        case .gold:
            return MovieBannerColorValue(red: 0.98, green: 0.76, blue: 0.22)
        }
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
        .raverSystemNavigation(title: LT("分享二维码", "Share QR Code", "QRコードを共有"))
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
                Text(LT("短链", "Short Link", "短縮リンク"))
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
                        OperationBannerCenter.shared.success(LT("已复制短链", "Short link copied", "短縮リンクをコピーしました"))
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text(LT("复制短链", "Copy short link", "短縮リンクをコピー")))
                }
            }
        }
    }

    private var qrCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                qrImage

                Text(LT("扫码后可在 iPhone 中打开对应页面", "Scan to open the related page on iPhone", "スキャンするとiPhoneで関連ページを開けます"))
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
                Text(LT("当前说明", "Notes", "説明"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                Text(LT("此二维码由系统自动生成，与短链保持一致。后续切换分享域名时，历史二维码仍应继续可用。", "This QR code is generated by the system and stays aligned with the share short link. Historical QR codes should remain valid even after future share-domain migrations.", "このQRコードはシステムで自動生成され、短縮リンクと同期されます。今後共有ドメインを切り替えても過去のQRコードは引き続き利用できる必要があります。"))
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
                        Text(LT("二维码生成中", "QR code is loading", "QRコードを生成中"))
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

    @State private var currentAssetURL: String?

    @State private var feedbackMessage: String?
    @State private var assetImageSize: CGSize?
    @State private var assetDidFailToLoad = false
    @State private var loadedAssetImage: UIImage?
    @State private var isAssetLoading = false
    @State private var isRegenerating = false
    @State private var fullscreenSelection: FullscreenMediaSelection?

    init(
        navigationTitle: String,
        title: String,
        subtitle: String?,
        imageURL: String?,
        assetURL: String?,
        emptyTitle: String,
        emptyMessage: String,
        hintText: String,
        saveButtonTitle: String?
    ) {
        self.navigationTitle = navigationTitle
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.assetURL = assetURL
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.hintText = hintText
        self.saveButtonTitle = saveButtonTitle
        _currentAssetURL = State(initialValue: Self.localizedPosterURL(assetURL))
    }

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
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
        .onAppear {
            print("[share-poster-ios] detail-appear title=\(title) assetURL=\(currentAssetURL ?? "nil")")
        }
        .task(id: AppConfig.resolvedURLString(currentAssetURL) ?? "") {
            await loadAssetPreview()
        }
        .fullScreenCover(item: $fullscreenSelection) { selection in
            if let resolved = AppConfig.resolvedURLString(currentAssetURL) {
                FullscreenMediaViewer(
                    items: [FullscreenMediaItem(rawURL: resolved, index: 0)],
                    initialIndex: selection.id
                )
            }
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
                    HStack(spacing: 12) {
                        if let regenerateButtonTitle {
                            Button {
                                Task { await regeneratePoster() }
                            } label: {
                                if isRegenerating {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                        Text(regenerateButtonTitle)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Label(regenerateButtonTitle, systemImage: "arrow.clockwise")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(RaverTheme.accent)
                            .disabled(isRegenerating || isAssetLoading)
                        }

                        Button {
                            Task { await saveAssetToPhotos() }
                        } label: {
                            Label(saveButtonTitle, systemImage: "photo.badge.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RaverTheme.accent)
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var hintCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(LT("当前说明", "Notes", "説明"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                Text(hintText)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private var hasValidAssetURL: Bool {
        let resolved = AppConfig.resolvedURLString(currentAssetURL)
        guard let resolved, !resolved.isEmpty else { return false }
        return URL(string: resolved) != nil
    }

    private static func localizedPosterURL(_ value: String?) -> String? {
        guard let resolved = AppConfig.resolvedURLString(value),
              var components = URLComponents(string: resolved) else {
            return value
        }
        let locale = AppLanguagePreference.current.effectiveLanguage == .zh ? "zh" : "en"
        var items = components.queryItems ?? []
        items.removeAll(where: { $0.name == "locale" })
        items.append(URLQueryItem(name: "locale", value: locale))
        components.queryItems = items
        return components.string
    }

    private var regenerateButtonTitle: String? {
        guard sharePosterCode != nil else { return nil }
        return LT("重新生成海报", "Regenerate", "海報を再生成")
    }

    private var sharePosterCode: String? {
        guard let resolved = AppConfig.resolvedURLString(currentAssetURL),
              let url = URL(string: resolved) else {
            return nil
        }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard parts.count >= 2,
              parts[0] == "poster",
              parts[1].hasSuffix(".png") else {
            return nil
        }
        let code = String(parts[1].dropLast(4))
        return code.isEmpty ? nil : code
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
        let resolved = AppConfig.resolvedURLString(currentAssetURL)
        if let resolved,
           !resolved.isEmpty,
           URL(string: resolved) != nil {
            GeometryReader { proxy in
                let horizontalInset: CGFloat = 24
                let availableWidth = max(proxy.size.width - horizontalInset, 1)
                let resolvedHeight = assetPreviewHeight(for: availableWidth)

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(RaverTheme.card)

                    if let loadedAssetImage {
                        Button {
                            fullscreenSelection = FullscreenMediaSelection(id: 0)
                        } label: {
                            ZStack {
                                Image(uiImage: loadedAssetImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: availableWidth, height: resolvedHeight)
                                    .clipped()

                                VStack(spacing: 0) {
                                    LinearGradient(
                                        colors: [
                                            RaverTheme.background.opacity(0.88),
                                            RaverTheme.background.opacity(0.38),
                                            .clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: min(104, resolvedHeight * 0.24))

                                    Spacer(minLength: 0)

                                    LinearGradient(
                                        colors: [
                                            .clear,
                                            RaverTheme.background.opacity(0.38),
                                            RaverTheme.background.opacity(0.88)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: min(104, resolvedHeight * 0.24))
                                }
                                .allowsHitTesting(false)

                                Image(uiImage: loadedAssetImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: availableWidth, height: resolvedHeight)
                            }
                        }
                        .buttonStyle(.plain)
                    } else if assetDidFailToLoad {
                        shareAssetEmptyState
                    } else {
                        ProgressView()
                            .tint(RaverTheme.primaryText)
                    }
                }
                .frame(width: availableWidth, height: resolvedHeight)
                .frame(maxWidth: .infinity)
            }
            .frame(height: assetPreviewHeight(for: UIScreen.main.bounds.width - 56))
        } else {
            shareAssetEmptyContainer
        }
    }

    private var shareAssetEmptyContainer: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(RaverTheme.card)
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .overlay {
                shareAssetEmptyState
            }
    }

    private var shareAssetEmptyState: some View {
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

    private func assetPreviewHeight(for width: CGFloat) -> CGFloat {
        guard let assetImageSize,
              assetImageSize.width > 0,
              assetImageSize.height > 0 else {
            return 420
        }
        let ratio = assetImageSize.height / assetImageSize.width
        return max(280, width * ratio)
    }

    @MainActor
    private func loadAssetPreview() async {
        let resolved = AppConfig.resolvedURLString(currentAssetURL)
        guard let resolved,
              !resolved.isEmpty,
              let url = URL(string: resolved) else {
            loadedAssetImage = nil
            assetDidFailToLoad = false
            assetImageSize = nil
            return
        }
        if isAssetLoading { return }
        if loadedAssetImage != nil && !assetDidFailToLoad { return }

        isAssetLoading = true
        assetDidFailToLoad = false
        loadedAssetImage = nil
        assetImageSize = nil
        let start = Date()
        print("[share-poster-ios] poster-fetch-start assetURL=\(resolved)")

        defer { isAssetLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[share-poster-ios] poster-fetch-response assetURL=\(resolved) status=\(statusCode) bytes=\(data.count) elapsedMs=\(elapsedMs)")

            guard let image = UIImage(data: data) else {
                assetDidFailToLoad = true
                print("[share-poster-ios] poster-decode-failed assetURL=\(resolved)")
                return
            }

            loadedAssetImage = image
            assetImageSize = image.size
            assetDidFailToLoad = false
            let decodeElapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            print("[share-poster-ios] poster-image-ready assetURL=\(resolved) size=\(image.size.width)x\(image.size.height) elapsedMs=\(decodeElapsedMs)")
        } catch {
            assetDidFailToLoad = true
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            print("[share-poster-ios] poster-fetch-failed assetURL=\(resolved) elapsedMs=\(elapsedMs) error=\(String(describing: error))")
        }
    }

    @MainActor
    private func saveAssetToPhotos() async {
        do {
            try await ShareAssetPhotoSaver.saveRemoteImage(from: currentAssetURL)
            feedbackMessage = LT("已保存到相册", "Saved to Photos.", "写真に保存しました。")
        } catch {
            feedbackMessage = error.userFacingMessage ?? emptyMessage
        }
    }

    @MainActor
    private func regeneratePoster() async {
        guard let code = sharePosterCode, !isRegenerating else { return }
        isRegenerating = true
        defer { isRegenerating = false }

        do {
            print("[share-poster-ios] regenerate-start code=\(code)")
            let payload = try await AppEnvironment.makeShareLinkService().regeneratePoster(code: code)
            currentAssetURL = Self.localizedPosterURL(payload.posterURL)
            loadedAssetImage = nil
            assetImageSize = nil
            assetDidFailToLoad = false
            print("[share-poster-ios] regenerate-success code=\(code) posterURL=\(payload.posterURL ?? "nil")")
            feedbackMessage = LT("海报已重新生成", "Poster regenerated.", "海報を再生成しました。")
        } catch {
            print("[share-poster-ios] regenerate-failed code=\(code) error=\(String(describing: error))")
            feedbackMessage = error.userFacingMessage ?? LT("重新生成海报失败，请稍后再试。", "Failed to regenerate poster. Please try again later.", "海報の再生成に失敗しました。時間をおいて再試行してください。")
        }
    }
}

@MainActor
final class QuizFlowViewModel: ObservableObject {
    typealias MediaPreloader = @Sendable ([URL]) async throws -> Void

    enum Phase {
        case loading
        case ready(QuizConfigSummary)
        case inSession
        case result(QuizSessionSubmitResponse)
        case failure(String)
    }

    enum SessionExitReason {
        case backgrounded
        case mediaLoadFailed
        case completed
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var summary: QuizConfigSummary?
    @Published private(set) var session: QuizSessionCreateResponse?
    @Published var answers: [String: String] = [:]
    @Published var currentQuestionIndex: Int = 0
    @Published var isSubmitting = false
    @Published private(set) var isPreparingSession = false
    @Published private(set) var sessionPreparationCompletedCount = 0
    @Published private(set) var sessionPreparationTargetCount = 0
    @Published private(set) var sessionPreparationMessage: String?
    @Published private(set) var isPreparingQuestion = false
    @Published private(set) var preparationAttempt = 0
    @Published private(set) var preparationMessage: String?
    @Published private(set) var mediaLoadFailedQuestionIndex: Int?
    @Published private(set) var secondsRemaining = 0
    @Published private(set) var countdownProgress = 0.0
    @Published var feedbackMessage: String?
    @Published var activeAlert: QuizAlert?

    private let service: WebFeatureService
    private let maxMediaRetryCount = 3
    private let prefetchQuestionCount = 2
    private let countdownTickNanoseconds: UInt64
    private let mediaRetryDelayNanoseconds: UInt64
    private let mediaPreloader: MediaPreloader
    private var countdownTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var questionRunToken = UUID()
    private var preloadedMediaURLs = Set<String>()

    init(
        service: WebFeatureService,
        countdownTickNanoseconds: UInt64 = 1_000_000_000,
        mediaRetryDelayNanoseconds: UInt64 = 500_000_000,
        mediaPreloader: @escaping MediaPreloader = QuizFlowViewModel.defaultMediaPreloader
    ) {
        self.service = service
        self.countdownTickNanoseconds = countdownTickNanoseconds
        self.mediaRetryDelayNanoseconds = mediaRetryDelayNanoseconds
        self.mediaPreloader = mediaPreloader
    }

    deinit {
        countdownTask?.cancel()
        prefetchTask?.cancel()
    }

    var currentQuestion: QuizQuestionPayload? {
        guard let session, session.questions.indices.contains(currentQuestionIndex) else { return nil }
        return session.questions[currentQuestionIndex]
    }

    var progressText: String {
        guard let session else { return "0/0" }
        return "第\(min(currentQuestionIndex + 1, session.questions.count))/\(session.questions.count)题"
    }

    var isSessionLocked: Bool {
        session != nil && !isSubmitting
    }

    var sessionPreparationProgressText: String {
        guard sessionPreparationTargetCount > 0 else { return "0/0" }
        return "第\(min(sessionPreparationCompletedCount, sessionPreparationTargetCount))/\(sessionPreparationTargetCount)题"
    }

    func load() async {
        cancelQuestionTasks()
        feedbackMessage = nil
        mediaLoadFailedQuestionIndex = nil
        resetSessionPreparationState()
        do {
            phase = .loading
            let summary = try await service.fetchQuizStatus()
            self.summary = summary
            phase = .ready(summary)
        } catch {
            phase = .failure(error.userFacingMessage ?? LT("答题信息加载失败，请稍后重试。", "Failed to load quiz info. Please try again later.", "クイズ情報を読み込めませんでした。時間をおいて再試行してください。"))
        }
    }

    func startQuiz(mode: QuizSessionMode = .standard) async {
        do {
            cancelQuestionTasks()
            mediaLoadFailedQuestionIndex = nil
            resetSessionPreparationState()
            let createdSession = try await service.createQuizSession(mode: mode)
            self.session = createdSession
            self.answers = [:]
            self.currentQuestionIndex = 0
            self.feedbackMessage = nil
            self.preloadedMediaURLs = []
            phase = .inSession
            let preparedSession = try await prepareSessionForPlayback(createdSession)
            self.session = preparedSession
            await prepareQuestion(at: 0)
        } catch {
            if let currentSession = session {
                await abandonSessionForPreflightFailure(currentSession.sessionId)
            }
            feedbackMessage = error.userFacingMessage ?? LT("开始答题失败，请稍后重试。", "Failed to start quiz. Please try again later.", "クイズを開始できませんでした。時間をおいて再試行してください。")
            if let summary = try? await service.fetchQuizStatus() {
                self.summary = summary
                phase = .ready(summary)
            } else if let summary {
                phase = .ready(summary)
            } else {
                phase = .failure(error.userFacingMessage ?? LT("答题信息加载失败，请稍后重试。", "Failed to load quiz info. Please try again later.", "クイズ情報を読み込めませんでした。時間をおいて再試行してください。"))
            }
        }
    }

    func selectOption(_ optionId: String) {
        guard let question = currentQuestion else { return }
        answers[question.questionId] = optionId
    }

    func goNext() {
        guard session != nil, !isPreparingSession, !isPreparingQuestion, !isSubmitting else { return }
        if mediaLoadFailedQuestionIndex == currentQuestionIndex {
            questionRunToken = UUID()
            Task {
                await prepareQuestion(at: currentQuestionIndex)
            }
            return
        }
        questionRunToken = UUID()
        Task {
            await advanceFromCurrentQuestion()
        }
    }

    func requestRestart() {
        activeAlert = .restart
    }

    func requestAbandon() {
        activeAlert = .abandon
    }

    func confirmAlert(_ alert: QuizAlert) async {
        activeAlert = nil
        switch alert {
        case .restart:
            let restartMode = session?.mode ?? .standard
            await abandonCurrentSessionSilently()
            await startQuiz(mode: restartMode)
        case .abandon:
            abandonCurrentSessionLocallyAndReportInBackground()
            feedbackMessage = nil
            mediaLoadFailedQuestionIndex = nil
            resetSessionPreparationState()
            if let summary {
                phase = .ready(summary)
            } else {
                phase = .loading
            }
            await load()
        }
    }

    func submitQuiz() async {
        guard let session, !isSubmitting else { return }
        questionRunToken = UUID()
        cancelQuestionTasks()
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let payload = session.questions.map { question in
                QuizSubmitAnswerPayload(questionId: question.questionId, optionId: answers[question.questionId])
            }
            let result = try await service.submitQuizSession(
                sessionId: session.sessionId,
                answers: payload,
                presentedQuestionIds: session.questions.map(\.questionId)
            )
            self.session = nil
            self.feedbackMessage = nil
            self.mediaLoadFailedQuestionIndex = nil
            self.resetSessionPreparationState()
            self.isPreparingQuestion = false
            self.preparationAttempt = 0
            self.preparationMessage = nil
            self.secondsRemaining = 0
            phase = .result(result)
            summary = try? await service.fetchQuizStatus()
        } catch {
            feedbackMessage = error.userFacingMessage ?? LT("提交答题失败，请稍后重试。", "Failed to submit quiz. Please try again later.", "クイズ提出に失敗しました。時間をおいて再試行してください。")
        }
    }

    func handleScenePhaseChange(_ scenePhase: ScenePhase) async {
        guard scenePhase == .background else { return }
        await terminateCurrentSession(reason: .backgrounded)
    }

    private func prepareQuestion(at index: Int) async {
        guard let session, session.questions.indices.contains(index) else { return }

        cancelQuestionTasks()
        let token = UUID()
        questionRunToken = token
        mediaLoadFailedQuestionIndex = nil
        withAnimation(.easeInOut(duration: 0.24)) {
            currentQuestionIndex = index
        }
        isPreparingQuestion = true
        preparationAttempt = 0
        preparationMessage = LT("正在准备本题资源…", "Preparing question media…", "問題のメディアを準備中…")
        feedbackMessage = nil

        let question = session.questions[index]
        let mediaURLs = questionMediaURLs(question)

        guard !mediaURLs.isEmpty else {
            finishPreparingQuestion(question, token: token)
            startPrefetchingUpcomingQuestions(from: index, token: token)
            return
        }

        for attempt in 1...maxMediaRetryCount {
            guard questionRunToken == token else { return }
            preparationAttempt = attempt
            preparationMessage = LT(
                "正在加载第 \(index + 1) 题资源（第 \(attempt)/\(maxMediaRetryCount) 次）",
                "Loading media for question \(index + 1) (\(attempt)/\(maxMediaRetryCount))",
                "第 \(index + 1) 問のメディアを読み込み中（\(attempt)/\(maxMediaRetryCount) 回目）"
            )

            do {
                try await preloadMediaAssets(mediaURLs)
                guard questionRunToken == token else { return }
                finishPreparingQuestion(question, token: token)
                startPrefetchingUpcomingQuestions(from: index, token: token)
                return
            } catch {
                guard questionRunToken == token else { return }
                if attempt == maxMediaRetryCount {
                    isPreparingQuestion = false
                    mediaLoadFailedQuestionIndex = index
                    preparationMessage = nil
                    feedbackMessage = LT(
                        "第 \(index + 1) 题媒体资源连续加载失败，请重试当前题目或重新开始。",
                        "Question \(index + 1) media failed to load repeatedly. Please retry the current question or restart.",
                        "第 \(index + 1) 問のメディア読み込みに連続で失敗しました。現在の問題を再試行するか、再開始してください。"
                    )
                    return
                }
                try? await Task.sleep(nanoseconds: mediaRetryDelayNanoseconds)
            }
        }
    }

    private func prepareSessionForPlayback(_ session: QuizSessionCreateResponse) async throws -> QuizSessionCreateResponse {
        isPreparingSession = true
        sessionPreparationCompletedCount = 0
        sessionPreparationTargetCount = session.questions.count
        sessionPreparationMessage = LT("正在准备本场题目资源…", "Preparing quiz media…", "今回の問題メディアを準備中…")

        var resolvedQuestions: [QuizQuestionPayload] = []
        var reserveQuestions = session.reserveQuestions

        defer {
            isPreparingSession = false
            sessionPreparationMessage = nil
        }

        for (index, primaryQuestion) in session.questions.enumerated() {
            let playableQuestion = try await resolvePlayableQuestionForSlot(
                slotIndex: index,
                primaryQuestion: primaryQuestion,
                reserveQuestions: &reserveQuestions,
                mode: session.mode
            )
            resolvedQuestions.append(playableQuestion)
            sessionPreparationCompletedCount = resolvedQuestions.count
        }

        return QuizSessionCreateResponse(
            mode: session.mode,
            sessionId: session.sessionId,
            questionCount: session.questionCount,
            passCorrectCount: session.passCorrectCount,
            dailyAttemptLimit: session.dailyAttemptLimit,
            dailyRemainingAttemptsAfterStart: session.dailyRemainingAttemptsAfterStart,
            timeZone: session.timeZone,
            questions: resolvedQuestions,
            reserveQuestions: [],
            startedAt: session.startedAt,
            expiresAt: session.expiresAt
        )
    }

    private func resolvePlayableQuestionForSlot(
        slotIndex: Int,
        primaryQuestion: QuizQuestionPayload,
        reserveQuestions: inout [QuizQuestionPayload],
        mode: QuizSessionMode
    ) async throws -> QuizQuestionPayload {
        var candidate = primaryQuestion
        var replacementAttempt = 0

        while true {
            let isReplacement = replacementAttempt > 0
            sessionPreparationMessage = isReplacement
                ? LT(
                    "第 \(slotIndex + 1) 题资源异常，正在替换候补题…",
                    "Question \(slotIndex + 1) media failed. Replacing with a reserve question…",
                    "第 \(slotIndex + 1) 問のメディアに失敗したため、予備問題へ差し替えています…"
                )
                : LT(
                    "正在出第 \(slotIndex + 1) 题…",
                    "Preparing question \(slotIndex + 1)…",
                    "第 \(slotIndex + 1) 問を準備中…"
                )

            do {
                try await preloadQuestionMedia(candidate, displayIndex: slotIndex)
                return candidate
            } catch {
                guard mode == .standard, !reserveQuestions.isEmpty else {
                    throw QuizSessionPreparationError.insufficientPlayableQuestions
                }
                candidate = reserveQuestions.removeFirst()
                replacementAttempt += 1
            }
        }
    }

    private func preloadQuestionMedia(_ question: QuizQuestionPayload, displayIndex: Int) async throws {
        let mediaURLs = questionMediaURLs(question)
        guard !mediaURLs.isEmpty else { return }

        for attempt in 1...maxMediaRetryCount {
            preparationAttempt = attempt
            do {
                try await preloadMediaAssets(mediaURLs)
                preparationAttempt = 0
                return
            } catch {
                if attempt == maxMediaRetryCount {
                    preparationAttempt = 0
                    throw QuizSessionPreparationError.questionMediaFailed(index: displayIndex)
                }
                sessionPreparationMessage = LT(
                    "第 \(displayIndex + 1) 题媒体加载重试（\(attempt)/\(maxMediaRetryCount)）",
                    "Retrying media for question \(displayIndex + 1) (\(attempt)/\(maxMediaRetryCount))",
                    "第 \(displayIndex + 1) 問のメディアを再試行中（\(attempt)/\(maxMediaRetryCount)）"
                )
                try? await Task.sleep(nanoseconds: mediaRetryDelayNanoseconds)
            }
        }
    }

    private func finishPreparingQuestion(_ question: QuizQuestionPayload, token: UUID) {
        guard questionRunToken == token else { return }
        isPreparingQuestion = false
        preparationAttempt = 0
        preparationMessage = nil
        mediaLoadFailedQuestionIndex = nil
        startCountdown(for: question, token: token)
    }

    private func startCountdown(for question: QuizQuestionPayload, token: UUID) {
        countdownTask?.cancel()
        let totalSeconds = max(1, question.timeLimitSec)
        secondsRemaining = totalSeconds
        countdownProgress = 1
        withAnimation(.linear(duration: Double(totalSeconds))) {
            countdownProgress = 0
        }
        countdownTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: countdownTickNanoseconds)
                await self.handleCountdownTick(token: token)
            }
        }
    }

    private func handleCountdownTick(token: UUID) async {
        guard questionRunToken == token, session != nil, !isPreparingQuestion else { return }
        if secondsRemaining > 1 {
            secondsRemaining -= 1
            return
        }

        secondsRemaining = 0
        feedbackMessage = nil
        countdownTask?.cancel()
        countdownTask = nil
        questionRunToken = UUID()
        Task {
            await advanceFromCurrentQuestion()
        }
    }

    private func advanceFromCurrentQuestion(afterMediaFailure: Bool = false) async {
        cancelQuestionTasks()
        guard let session else { return }
        let nextIndex = currentQuestionIndex + 1
        if nextIndex < session.questions.count {
            await prepareQuestion(at: nextIndex)
        } else if afterMediaFailure {
            await submitQuiz()
        } else {
            await submitQuiz()
        }
    }

    private func terminateCurrentSession(reason: SessionExitReason) async {
        guard session != nil else { return }
        cancelQuestionTasks()
        await abandonCurrentSessionSilently()
        switch reason {
        case .backgrounded:
            feedbackMessage = LT(
                "答题过程中切到后台，本次答题已自动作废，需要重新开始。",
                "The quiz was sent to the background and has been abandoned. Please restart.",
                "クイズ中にアプリがバックグラウンドへ移動したため、この回は破棄されました。再度開始してください。"
            )
            if let summary = try? await service.fetchQuizStatus() {
                self.summary = summary
                phase = .ready(summary)
            } else if let summary {
                phase = .ready(summary)
            } else {
                phase = .failure(LT("答题状态同步失败，请稍后重试。", "Failed to sync quiz state. Please try again later.", "クイズ状態の同期に失敗しました。時間をおいて再試行してください。"))
            }
        case .mediaLoadFailed:
            feedbackMessage = LT("题目资源加载失败，本次答题已结束。", "Question media failed to load. The quiz has ended.", "問題メディアの読み込みに失敗したため、クイズを終了しました。")
        case .completed:
            break
        }
    }

    private func clearLocalSessionState() -> String? {
        let sessionId = session?.sessionId
        cancelQuestionTasks()
        session = nil
        isPreparingSession = false
        sessionPreparationCompletedCount = 0
        sessionPreparationTargetCount = 0
        sessionPreparationMessage = nil
        isPreparingQuestion = false
        preparationAttempt = 0
        preparationMessage = nil
        mediaLoadFailedQuestionIndex = nil
        secondsRemaining = 0
        countdownProgress = 0
        return sessionId
    }

    private func abandonCurrentSessionSilently() async {
        guard let sessionId = clearLocalSessionState() else { return }
        _ = try? await service.abandonQuizSession(sessionId: sessionId)
    }

    private func abandonCurrentSessionLocallyAndReportInBackground() {
        guard let sessionId = clearLocalSessionState() else { return }
        Task {
            _ = try? await service.abandonQuizSession(sessionId: sessionId)
        }
    }

    private func abandonSessionForPreflightFailure(_ sessionId: String) async {
        _ = clearLocalSessionState()
        _ = try? await service.abandonQuizSession(sessionId: sessionId, reason: .preflightFailed)
    }

    private func resetSessionPreparationState() {
        isPreparingSession = false
        sessionPreparationCompletedCount = 0
        sessionPreparationTargetCount = 0
        sessionPreparationMessage = nil
        preparationAttempt = 0
    }

    private func cancelQuestionTasks() {
        countdownTask?.cancel()
        countdownTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
        secondsRemaining = 0
        countdownProgress = 0
    }

    private func startPrefetchingUpcomingQuestions(from index: Int, token: UUID) {
        prefetchTask?.cancel()
        guard let session else { return }
        let questionBatch = Array(session.questions.dropFirst(index + 1).prefix(prefetchQuestionCount))
        guard !questionBatch.isEmpty else { return }
        prefetchTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            for question in questionBatch {
                guard !Task.isCancelled else { return }
                await self.preloadQuestionIfNeeded(question, token: token)
            }
        }
    }

    private func preloadQuestionIfNeeded(_ question: QuizQuestionPayload, token: UUID) async {
        guard questionRunToken == token else { return }
        let mediaURLs = questionMediaURLs(question)
        guard !mediaURLs.isEmpty else { return }
        try? await preloadMediaAssets(mediaURLs)
    }

    private func preloadMediaAssets(_ urls: [URL]) async throws {
        let pending = urls.filter { !preloadedMediaURLs.contains($0.absoluteString) }
        guard !pending.isEmpty else { return }

        try await mediaPreloader(pending)
        for url in pending {
            preloadedMediaURLs.insert(url.absoluteString)
        }
    }

    static func defaultMediaPreloader(_ urls: [URL]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    let request = URLRequest(
                        url: url,
                        cachePolicy: .returnCacheDataElseLoad,
                        timeoutInterval: 20
                    )
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode),
                          !data.isEmpty else {
                        throw URLError(.badServerResponse)
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    private func questionMediaURLs(_ question: QuizQuestionPayload) -> [URL] {
        var seen = Set<String>()
        let candidates = ([question.stemImageUrl] + question.options.map(\.imageUrl))
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return candidates.compactMap { raw in
            guard seen.insert(raw).inserted else { return nil }
            return URL(string: raw)
        }
    }
}

private enum QuizSessionPreparationError: LocalizedError {
    case questionMediaFailed(index: Int)
    case insufficientPlayableQuestions

    var errorDescription: String? {
        switch self {
        case .questionMediaFailed(let index):
            return LT(
                "第 \(index + 1) 题媒体资源加载失败，请稍后重试。",
                "Question \(index + 1) media failed to load. Please try again later.",
                "第 \(index + 1) 問のメディア読み込みに失敗しました。時間をおいて再試行してください。"
            )
        case .insufficientPlayableQuestions:
            return LT(
                "题目资源准备失败，本次未开始作答，请稍后重试。",
                "Quiz media preparation failed before the session started. Please try again later.",
                "セッション開始前のメディア準備に失敗しました。時間をおいて再試行してください。"
            )
        }
    }
}

enum QuizAlert: Identifiable {
    case restart
    case abandon

    var id: String {
        switch self {
        case .restart: return "restart"
        case .abandon: return "abandon"
        }
    }
}

struct QuizFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: QuizFlowViewModel
    private let optionLetters = ["A", "B", "C", "D", "E", "F"]

    init(service: WebFeatureService) {
        _viewModel = StateObject(wrappedValue: QuizFlowViewModel(service: service))
    }

    private var canAdvanceToNextQuestion: Bool {
        !viewModel.isSubmitting
    }

    private func bottomActionBar(
        secondaryTitle: String,
        primaryTitle: String,
        isPrimaryBusy: Bool = false,
        isPrimaryDisabled: Bool = false,
        onSecondary: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: onSecondary) {
                Text(secondaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RaverTheme.background)
            )
            .foregroundStyle(RaverTheme.secondaryText)

            Button(action: onPrimary) {
                if isPrimaryBusy {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .background(
                LinearGradient(
                    colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
            .disabled(isPrimaryDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            RaverTheme.card
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func countdownBadge(for question: QuizQuestionPayload) -> some View {
        let remainingSeconds = max(0, viewModel.secondsRemaining)
        let progress = CGFloat(max(0, min(1, viewModel.countdownProgress)))

        return ZStack {
            Circle()
                .stroke(RaverTheme.cardBorder, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    RaverTheme.accent,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(remainingSeconds)")
                .font(.caption.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)
        }
        .frame(width: 40, height: 40)
    }

    private func normalizedOptionText(_ option: QuizQuestionOptionPayload) -> String? {
        let trimmed = option.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func hasOptionImage(_ option: QuizQuestionOptionPayload) -> Bool {
        let trimmed = option.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }

    private func usesImageGridLayout(for question: QuizQuestionPayload) -> Bool {
        question.options.count == 4 && question.options.allSatisfy { normalizedOptionText($0) == nil && hasOptionImage($0) }
    }

    private func optionSelectionBorder(
        questionId: String,
        optionId: String
    ) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                viewModel.answers[questionId] == optionId ? RaverTheme.accent : RaverTheme.cardBorder,
                lineWidth: viewModel.answers[questionId] == optionId ? 2 : 1
            )
    }

    private func imageOptionGrid(question: QuizQuestionPayload) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                Button {
                    viewModel.selectOption(option.optionId)
                } label: {
                    GeometryReader { geometry in
                        let size = geometry.size.width

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(RaverTheme.card)

                            if let imageUrl = option.imageUrl,
                               !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: size, height: size)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: size, height: size)
                                            .clipped()
                                    case .failure:
                                        Color(RaverTheme.background)
                                            .frame(width: size, height: size)
                                            .overlay(
                                                Text(LT("图片加载失败", "Image failed to load", "画像を読み込めませんでした"))
                                                    .font(.caption2)
                                                    .foregroundStyle(RaverTheme.secondaryText)
                                                    .padding(.horizontal, 10)
                                            )
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }

                            Text(optionLetters.indices.contains(index) ? optionLetters[index] : "\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.black.opacity(0.52))
                                )
                                .padding(10)
                        }
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(optionSelectionBorder(questionId: question.questionId, optionId: option.optionId))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func listOptionCard(question: QuizQuestionPayload, option: QuizQuestionOptionPayload) -> some View {
        Button {
            viewModel.selectOption(option.optionId)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .stroke(viewModel.answers[question.questionId] == option.optionId ? RaverTheme.accent : RaverTheme.secondaryText, lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .overlay {
                            if viewModel.answers[question.questionId] == option.optionId {
                                Circle()
                                    .fill(RaverTheme.accent)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    Text(normalizedOptionText(option) ?? LT("图片选项", "Image Option", "画像オプション"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                }
                if let imageUrl = option.imageUrl,
                   !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 140)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        case .failure:
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(RaverTheme.card)
                                .frame(maxWidth: .infinity, minHeight: 140)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(RaverTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(viewModel.answers[question.questionId] == option.optionId ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView(LT("正在加载答题系统", "Loading quiz", "クイズを読み込み中"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            case .failure(let message):
                VStack(spacing: 16) {
                    ScreenErrorCard(message: message) {
                        Task { await viewModel.load() }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            case .ready(let summary):
                quizStartView(summary)
            case .inSession:
                quizQuestionView
            case .result(let result):
                quizResultView(result)
            }
        }
        .navigationTitle(LT("答题系统", "Quiz", "クイズ"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.summary == nil && viewModel.session == nil {
                await viewModel.load()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            Task {
                await viewModel.handleScenePhaseChange(newValue)
            }
        }
        .navigationBarBackButtonHidden(viewModel.isSessionLocked)
        .alert(item: $viewModel.activeAlert) { alert in
            switch alert {
            case .restart:
                return Alert(
                    title: Text(LT("重新开始答题", "Restart Quiz", "クイズを再開始")),
                    message: Text(LT("当前答题会被放弃，并立即重新抽取一套新题。", "The current session will be abandoned and a new set of questions will be created immediately.", "現在のセッションは破棄され、新しい問題セットがすぐに生成されます。")),
                    primaryButton: .destructive(Text(LT("确认重启", "Restart", "再開始"))) {
                        Task { await viewModel.confirmAlert(.restart) }
                    },
                    secondaryButton: .cancel()
                )
            case .abandon:
                return Alert(
                    title: Text(LT("放弃本次答题", "Abandon Quiz", "今回のクイズを放棄")),
                    message: Text(LT("退出后不会保留进度，需要重新开始整场答题。", "Progress will not be preserved. You will need to restart the whole quiz next time.", "進捗は保存されず、次回は最初からやり直しになります。")),
                    primaryButton: .destructive(Text(LT("确认放弃", "Abandon", "放棄する"))) {
                        Task { await viewModel.confirmAlert(.abandon) }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func quizStartView(_ summary: QuizConfigSummary) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LT("答题说明", "Quiz Rules", "クイズ説明"))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(
                            LT(
                                "每次随机抽取 \(summary.questionCount) 道单选题，只展示最终答对数量与是否通过。答对至少 \(summary.passCorrectCount) 题算通过。",
                                "\(summary.questionCount) single-choice questions will be drawn randomly. Only the final correct count and pass result are shown. You need at least \(summary.passCorrectCount) correct answers to pass.",
                                "毎回 \(summary.questionCount) 問の単一選択問題がランダムに出題されます。最終的な正答数と合否のみが表示されます。合格には少なくとも \(summary.passCorrectCount) 問の正解が必要です。"
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)

                        VStack(alignment: .leading, spacing: 8) {
                            summaryRow(LT("今日已用次数", "Attempts Used Today", "本日の使用回数"), "\(summary.todayAttemptCount)")
                            summaryRow(
                                LT("今日剩余次数", "Remaining Today", "本日の残り回数"),
                                summary.todayRemainingAttempts < 0 ? LT("无限次", "Unlimited", "無制限") : "\(summary.todayRemainingAttempts)"
                            )
                            summaryRow(LT("当前状态", "Current Status", "現在の状態"), statusText(summary))
                            if summary.canUseDebugQuestionSet {
                                summaryRow(
                                    LT("调试套题题数", "Debug Set Count", "デバッグ問題数"),
                                    "\(summary.debugQuestionSetCount)"
                                )
                            }
                        }
                    }
                }

                if let feedbackMessage = viewModel.feedbackMessage, !feedbackMessage.isEmpty {
                    ScreenStatusBanner(message: feedbackMessage, style: .error)
                }

                if summary.hasPermanentPass {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LT("你已通过该答题", "You Have Passed", "すでに合格しています"))
                                .font(.headline)
                            if let passedAt = summary.passedAt {
                                Text("\(LT("通过时间", "Passed At", "合格日時")): \(formatTime(passedAt))")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                }

                Button {
                    Task { await viewModel.startQuiz(mode: .standard) }
                } label: {
                    Text(LT("开始答题", "Start Quiz", "クイズを開始"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(RaverTheme.accent)
                .disabled(!summary.canStart)

                if summary.canUseDebugQuestionSet {
                    Button {
                        Task { await viewModel.startQuiz(mode: .debugSet) }
                    } label: {
                        Text(LT("进入调试套题", "Open Debug Set", "デバッグ問題を開始"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(RaverTheme.accent)
                    .disabled(!summary.canStartDebugQuestionSet)
                }

                if !summary.canStart {
                    Text(disabledReasonText(summary.disabledReason))
                        .font(.footnote)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                if summary.canUseDebugQuestionSet && !summary.canStartDebugQuestionSet {
                    Text(LT("当前还没有可用的调试套题。请先在 Web 后台配置。", "No debug question set is configured yet. Please configure it in web admin first.", "利用可能なデバッグ問題セットがまだありません。先に Web 管理画面で設定してください。"))
                        .font(.footnote)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
    }

    private var quizQuestionView: some View {
        VStack(spacing: 0) {
            if viewModel.isPreparingSession || viewModel.isPreparingQuestion {
                if viewModel.session?.mode == .debugSet {
                    VStack(spacing: 0) {
                        VStack(spacing: 18) {
                            Spacer()
                            ProgressView()
                                .controlSize(.large)
                            Text(
                                viewModel.isPreparingSession
                                    ? LT("正在出题", "Preparing Quiz", "出題を準備中")
                                    : LT("正在准备题目", "Preparing Question", "問題を準備中")
                            )
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(viewModel.isPreparingSession ? viewModel.sessionPreparationProgressText : viewModel.progressText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.accent)
                            if let preparationMessage = viewModel.isPreparingSession
                                ? viewModel.sessionPreparationMessage
                                : viewModel.preparationMessage {
                                Text(preparationMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            if viewModel.preparationAttempt > 0 {
                                Text(
                                    LT(
                                        "媒体加载重试：\(viewModel.preparationAttempt)/3",
                                        "Media retry: \(viewModel.preparationAttempt)/3",
                                        "メディア再試行：\(viewModel.preparationAttempt)/3"
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(16)

                        bottomActionBar(
                            secondaryTitle: LT("放弃", "Abandon", "放棄"),
                            primaryTitle: viewModel.isPreparingSession
                                ? LT("重新出题", "Restart", "再開始")
                                : LT("重新开始", "Restart", "再開始"),
                            onSecondary: { viewModel.requestAbandon() },
                            onPrimary: { viewModel.requestRestart() }
                        )
                    }
                } else {
                    VStack(spacing: 18) {
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                        Text(LT("正在出题", "Preparing Quiz", "出題を準備中"))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
                }
            } else if let question = viewModel.currentQuestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let feedbackMessage = viewModel.feedbackMessage, !feedbackMessage.isEmpty {
                            ScreenStatusBanner(message: feedbackMessage, style: .error)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(viewModel.progressText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.accent)
                                Spacer()
                                countdownBadge(for: question)
                            }
                            Text(question.stemText)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                            if let imageUrl = question.stemImageUrl,
                               !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity, minHeight: 180)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(RaverTheme.card)
                                            .frame(maxWidth: .infinity, minHeight: 180)
                                            .overlay(
                                                Text(LT("题干图片加载失败", "Failed to load image", "画像を読み込めませんでした"))
                                                    .font(.footnote)
                                                    .foregroundStyle(RaverTheme.secondaryText)
                                            )
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }

                        Group {
                            if usesImageGridLayout(for: question) {
                                imageOptionGrid(question: question)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(question.options) { option in
                                        listOptionCard(question: question, option: option)
                                    }
                                }
                            }
                        }

                        if let feedbackMessage = viewModel.feedbackMessage, !feedbackMessage.isEmpty {
                            ScreenStatusBanner(message: feedbackMessage, style: .error)
                        }
                    }
                    .padding(16)
                    .id(question.questionId)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
                .animation(.easeInOut(duration: 0.24), value: viewModel.currentQuestionIndex)

                let primaryTitle = viewModel.mediaLoadFailedQuestionIndex == viewModel.currentQuestionIndex
                    ? LT("重试", "Retry", "再試行")
                    : LT("下一步", "Next", "次へ")

                bottomActionBar(
                    secondaryTitle: LT("放弃", "Abandon", "放棄"),
                    primaryTitle: primaryTitle,
                    isPrimaryBusy: viewModel.isSubmitting,
                    isPrimaryDisabled: !canAdvanceToNextQuestion,
                    onSecondary: { viewModel.requestAbandon() },
                    onPrimary: { viewModel.goNext() }
                )
            }
        }
        .background(RaverTheme.background)
    }

    private func quizResultView(_ result: QuizSessionSubmitResponse) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: result.passed ? "checkmark.seal.fill" : "xmark.seal")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(result.passed ? RaverTheme.accent : Color.red)
                Text(result.passed ? LT("答题通过", "Passed", "合格") : LT("未通过", "Not Passed", "不合格"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Text(
                    LT(
                        "本次答对 \(result.correctCount) / \(result.totalCount) 题",
                        "You answered \(result.correctCount) / \(result.totalCount) correctly",
                        "\(result.totalCount)問中 \(result.correctCount) 問正解"
                    )
                )
                .font(.title3)
                .foregroundStyle(RaverTheme.secondaryText)
                Spacer()
            }
            .padding(16)

            bottomActionBar(
                secondaryTitle: LT("完成", "Done", "完了"),
                primaryTitle: LT("返回答题首页", "Back to Quiz Home", "クイズホームへ戻る"),
                onSecondary: { dismiss() },
                onPrimary: {
                    Task { await viewModel.load() }
                }
            )
        }
        .background(RaverTheme.background)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(RaverTheme.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(RaverTheme.primaryText)
        }
        .font(.subheadline)
    }

    private func statusText(_ summary: QuizConfigSummary) -> String {
        if summary.hasPermanentPass {
            return LT("已通过", "Passed", "合格済み")
        }
        if summary.canStart {
            return LT("可开始", "Ready", "開始可能")
        }
        return disabledReasonText(summary.disabledReason)
    }

    private func disabledReasonText(_ code: String?) -> String {
        switch code {
        case "quiz_disabled":
            return LT("当前答题系统未开启。", "Quiz is currently disabled.", "現在クイズは無効です。")
        case "already_passed":
            return LT("你已经通过本次答题。", "You have already passed this quiz.", "このクイズはすでに合格しています。")
        case "daily_limit_reached":
            return LT("今日答题次数已用完。", "Daily attempt limit reached.", "本日の挑戦回数を使い切りました。")
        case "session_in_progress":
            return LT("当前已有进行中的答题。", "A quiz session is already in progress.", "進行中のクイズセッションがあります。")
        default:
            return LT("当前暂时无法开始答题。", "Unable to start quiz right now.", "現在クイズを開始できません。")
        }
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

@MainActor
final class PersonalityFlowViewModel: ObservableObject {
    typealias MediaPreloader = @Sendable ([URL]) async throws -> Void

    enum Phase {
        case loading
        case ready(PersonalityStatusSummary)
        case inSession
        case result(PersonalitySessionSubmitResponse)
        case failure(String)
    }

    enum SessionExitReason {
        case backgrounded
        case completed
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var summary: PersonalityStatusSummary?
    @Published private(set) var session: PersonalitySessionCreateResponse?
    @Published var answers: [String: String] = [:]
    @Published var currentQuestionIndex: Int = 0
    @Published var isSubmitting = false
    @Published private(set) var isPreparingSession = false
    @Published private(set) var sessionPreparationCompletedCount = 0
    @Published private(set) var sessionPreparationTargetCount = 0
    @Published private(set) var sessionPreparationMessage: String?
    @Published var feedbackMessage: String?
    @Published var activeAlert: QuizAlert?
    @Published private(set) var isAbandoningSession = false

    private let service: WebFeatureService
    private let mediaPreloader: MediaPreloader
    private var preloadedMediaURLs = Set<String>()
    private var hasExplicitlyExitedSession = false

    init(
        service: WebFeatureService,
        mediaPreloader: @escaping MediaPreloader = QuizFlowViewModel.defaultMediaPreloader
    ) {
        self.service = service
        self.mediaPreloader = mediaPreloader
    }

    var currentQuestion: PersonalityQuestionPayload? {
        guard let session, session.questions.indices.contains(currentQuestionIndex) else { return nil }
        return session.questions[currentQuestionIndex]
    }

    var progressText: String {
        guard let session else { return "第0/0题" }
        return "第\(min(currentQuestionIndex + 1, session.questions.count))/\(session.questions.count)题"
    }

    var isSessionLocked: Bool {
        session != nil && !isSubmitting
    }

    var canAdvanceFromCurrentQuestion: Bool {
        guard let question = currentQuestion else { return false }
        return answers[question.questionId] != nil
    }

    var shouldAutoAbandonOnDisappear: Bool {
        session != nil && !isSubmitting && !isAbandoningSession && !hasExplicitlyExitedSession
    }

    func showExistingResult(_ result: PersonalityResultPayload, questionCount: Int) {
        let synthetic = PersonalitySessionSubmitResponse(
            mode: .standard,
            sessionId: "personality-result-view",
            questionCount: questionCount,
            answeredCount: questionCount,
            axisScores: [:],
            result: result
        )
        phase = .result(synthetic)
    }

    func load() async {
        feedbackMessage = nil
        do {
            phase = .loading
            let summary = try await service.fetchPersonalityStatus()
            self.summary = summary
            phase = .ready(summary)
        } catch {
            phase = .failure(
                error.userFacingMessage
                    ?? LT("人格测试信息加载失败，请稍后重试。", "Failed to load personality test info. Please try again later.", "人格テスト情報の読み込みに失敗しました。時間をおいて再試行してください。")
            )
        }
    }

    func startSession(mode: PersonalitySessionMode = .standard) async {
        do {
            feedbackMessage = nil
            let createdSession = try await service.createPersonalitySession(mode: mode)
            self.session = createdSession
            self.answers = [:]
            self.currentQuestionIndex = 0
            self.preloadedMediaURLs = []
            self.hasExplicitlyExitedSession = false
            phase = .inSession
            let prepared = try await prepareSessionForPlayback(createdSession)
            self.session = prepared
        } catch {
            feedbackMessage = error.userFacingMessage ?? LT("开始测试失败，请稍后重试。", "Failed to start test. Please try again later.", "テストを開始できませんでした。時間をおいて再試行してください。")
            if let summary = try? await service.fetchPersonalityStatus() {
                self.summary = summary
                phase = .ready(summary)
            } else {
                phase = .failure(
                    error.userFacingMessage
                        ?? LT("人格测试信息加载失败，请稍后重试。", "Failed to load personality test info. Please try again later.", "人格テスト情報の読み込みに失敗しました。時間をおいて再試行してください。")
                )
            }
        }
    }

    func selectOption(_ optionId: String) {
        guard let question = currentQuestion else { return }
        answers[question.questionId] = optionId
        Task {
            await persistAnswers()
        }
    }

    func goPrevious() {
        guard currentQuestionIndex > 0, !isSubmitting else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            currentQuestionIndex -= 1
        }
        Task {
            await persistAnswers()
        }
    }

    func goNext() {
        guard let session, !isSubmitting else { return }
        guard canAdvanceFromCurrentQuestion else {
            feedbackMessage = LT(
                "请先选择一个答案，再继续下一题。",
                "Choose an answer before moving on.",
                "先に回答を選択してから次へ進んでください。"
            )
            return
        }
        feedbackMessage = nil
        if currentQuestionIndex < session.questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.24)) {
                currentQuestionIndex += 1
            }
            Task {
                await persistAnswers()
            }
        } else {
            Task {
                await submitSession()
            }
        }
    }

    func requestAbandon() {
        activeAlert = .abandon
    }

    func requestRestart() {
        activeAlert = .restart
    }

    func confirmAlert(_ alert: QuizAlert) async {
        activeAlert = nil
        switch alert {
        case .restart:
            let mode = session?.mode ?? .standard
            await abandonCurrentSessionSilently()
            await startSession(mode: mode)
        case .abandon:
            await abandonCurrentSessionSilently()
            await load()
        }
    }

    func submitSession() async {
        guard let session, !isSubmitting else { return }
        guard canAdvanceFromCurrentQuestion else {
            feedbackMessage = LT(
                "最后一题还没有作答，选择答案后才能查看结果。",
                "Answer the last question before seeing your result.",
                "最後の問題に回答してから結果を表示してください。"
            )
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let payload = session.questions.map { question in
                PersonalityAnswerPayload(questionId: question.questionId, optionId: answers[question.questionId])
            }
            let result = try await service.submitPersonalitySession(
                sessionId: session.sessionId,
                answers: payload
            )
            hasExplicitlyExitedSession = true
            self.session = nil
            phase = .result(result)
            summary = try? await service.fetchPersonalityStatus()
        } catch {
            feedbackMessage = error.userFacingMessage ?? LT("提交测试失败，请稍后重试。", "Failed to submit test. Please try again later.", "テストの送信に失敗しました。時間をおいて再試行してください。")
        }
    }

    func handleScenePhaseChange(_ scenePhase: ScenePhase) async {
        guard scenePhase == .background else { return }
        await terminateCurrentSession(reason: .backgrounded)
    }

    private func prepareSessionForPlayback(_ session: PersonalitySessionCreateResponse) async throws -> PersonalitySessionCreateResponse {
        isPreparingSession = true
        sessionPreparationCompletedCount = 0
        sessionPreparationTargetCount = session.questions.count
        sessionPreparationMessage = LT("正在准备题目资源…", "Preparing media…", "問題メディアを準備中…")
        defer {
            isPreparingSession = false
            sessionPreparationMessage = nil
        }

        for question in session.questions {
            let mediaURLs = questionMediaURLs(question)
            if !mediaURLs.isEmpty {
                try await preloadMediaAssets(mediaURLs)
            }
            sessionPreparationCompletedCount += 1
        }
        return session
    }

    private func persistAnswers() async {
        guard let session else { return }
        let payload = session.questions.map { question in
            PersonalityAnswerPayload(questionId: question.questionId, optionId: answers[question.questionId])
        }
        _ = try? await service.savePersonalitySessionAnswer(
            sessionId: session.sessionId,
            answers: payload,
            currentQuestionIndex: currentQuestionIndex
        )
    }

    private func terminateCurrentSession(reason: SessionExitReason) async {
        guard session != nil else { return }
        await abandonCurrentSessionSilently()
        switch reason {
        case .backgrounded:
            feedbackMessage = LT(
                "测试过程中切到后台，本次测试已自动作废，需要重新开始。",
                "The test was sent to the background and has been abandoned. Please restart.",
                "テスト中にアプリがバックグラウンドへ移動したため、この回は破棄されました。再度開始してください。"
            )
            await load()
        case .completed:
            break
        }
    }

    private func abandonCurrentSessionSilently() async {
        guard let sessionId = session?.sessionId else { return }
        hasExplicitlyExitedSession = true
        isAbandoningSession = true
        session = nil
        isPreparingSession = false
        sessionPreparationCompletedCount = 0
        sessionPreparationTargetCount = 0
        sessionPreparationMessage = nil
        _ = try? await service.abandonPersonalitySession(sessionId: sessionId)
        isAbandoningSession = false
    }

    func handleViewDisappear() {
        guard shouldAutoAbandonOnDisappear else { return }
        hasExplicitlyExitedSession = true
        Task {
            await abandonCurrentSessionSilently()
        }
    }

    private func preloadMediaAssets(_ urls: [URL]) async throws {
        let pending = urls.filter { !preloadedMediaURLs.contains($0.absoluteString) }
        guard !pending.isEmpty else { return }
        try await mediaPreloader(pending)
        for url in pending {
            preloadedMediaURLs.insert(url.absoluteString)
        }
    }

    private static func defaultMediaPreloader(_ urls: [URL]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    let request = URLRequest(
                        url: url,
                        cachePolicy: .returnCacheDataElseLoad,
                        timeoutInterval: 20
                    )
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode),
                          !data.isEmpty else {
                        throw URLError(.badServerResponse)
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    private func questionMediaURLs(_ question: PersonalityQuestionPayload) -> [URL] {
        var seen = Set<String>()
        let candidates = ([question.stemImageUrl] + question.options.map(\.imageUrl))
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return candidates.compactMap { raw in
            guard seen.insert(raw).inserted else { return nil }
            return URL(string: raw)
        }
    }
}

struct PersonalityFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: PersonalityFlowViewModel
    private let optionLetters = ["A", "B", "C", "D", "E", "F"]

    init(service: WebFeatureService) {
        _viewModel = StateObject(wrappedValue: PersonalityFlowViewModel(service: service))
    }

    private func bottomActionBar(
        tertiaryTitle: String? = nil,
        secondaryTitle: String,
        primaryTitle: String,
        isPrimaryBusy: Bool = false,
        isPrimaryDisabled: Bool = false,
        isSecondaryDisabled: Bool = false,
        onTertiary: (() -> Void)? = nil,
        onSecondary: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            if let tertiaryTitle, let onTertiary {
                Button(action: onTertiary) {
                    Text(tertiaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(RaverTheme.card)
                )
                .foregroundStyle(RaverTheme.secondaryText)
            }

            Button(action: onSecondary) {
                Text(secondaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RaverTheme.background)
            )
            .foregroundStyle(RaverTheme.secondaryText)
            .disabled(isSecondaryDisabled)

            Button(action: onPrimary) {
                if isPrimaryBusy {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .background(
                LinearGradient(
                    colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
            .disabled(isPrimaryDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            RaverTheme.card
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func normalizedOptionText(_ option: PersonalityQuestionOptionPayload) -> String? {
        let trimmed = option.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func hasOptionImage(_ option: PersonalityQuestionOptionPayload) -> Bool {
        let trimmed = option.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }

    private func usesImageGridLayout(for question: PersonalityQuestionPayload) -> Bool {
        question.options.count == 4 && question.options.allSatisfy { normalizedOptionText($0) == nil && hasOptionImage($0) }
    }

    @ViewBuilder
    private func personalityFeedbackBanner() -> some View {
        if let feedbackMessage = viewModel.feedbackMessage, !feedbackMessage.isEmpty {
            ScreenStatusBanner(message: feedbackMessage, style: .error)
        }
    }

    private func optionSelectionBorder(
        questionId: String,
        optionId: String
    ) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                viewModel.answers[questionId] == optionId ? RaverTheme.accent : RaverTheme.cardBorder,
                lineWidth: viewModel.answers[questionId] == optionId ? 2 : 1
            )
    }

    private func imageOptionGrid(question: PersonalityQuestionPayload) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                Button {
                    viewModel.selectOption(option.optionId)
                } label: {
                    GeometryReader { geometry in
                        let size = geometry.size.width
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(RaverTheme.card)

                            if let imageUrl = option.imageUrl,
                               !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: size, height: size)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: size, height: size)
                                            .clipped()
                                    case .failure:
                                        Color(RaverTheme.background)
                                            .frame(width: size, height: size)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }

                            Text(optionLetters.indices.contains(index) ? optionLetters[index] : "\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.black.opacity(0.52))
                                )
                                .padding(10)
                        }
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(optionSelectionBorder(questionId: question.questionId, optionId: option.optionId))
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func listOptionCard(question: PersonalityQuestionPayload, option: PersonalityQuestionOptionPayload) -> some View {
        Button {
            viewModel.selectOption(option.optionId)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .stroke(viewModel.answers[question.questionId] == option.optionId ? RaverTheme.accent : RaverTheme.secondaryText, lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .overlay {
                            if viewModel.answers[question.questionId] == option.optionId {
                                Circle()
                                    .fill(RaverTheme.accent)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    Text(normalizedOptionText(option) ?? LT("图片选项", "Image Option", "画像オプション"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                }
                if let imageUrl = option.imageUrl,
                   !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 140)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        case .failure:
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(RaverTheme.card)
                                .frame(maxWidth: .infinity, minHeight: 140)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(RaverTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(viewModel.answers[question.questionId] == option.optionId ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView(LT("正在加载 EDMTI", "Loading EDMTI", "EDMTI を読み込み中"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            case .failure(let message):
                VStack(spacing: 16) {
                    ScreenErrorCard(message: message) {
                        Task { await viewModel.load() }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            case .ready(let summary):
                personalityStartView(summary)
            case .inSession:
                personalityQuestionView
            case .result(let result):
                personalityResultView(result)
            }
        }
        .navigationTitle("EDMTI")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.summary == nil && viewModel.session == nil {
                await viewModel.load()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            Task {
                await viewModel.handleScenePhaseChange(newValue)
            }
        }
        .onDisappear {
            viewModel.handleViewDisappear()
        }
        .navigationBarBackButtonHidden(viewModel.isSessionLocked)
        .alert(item: $viewModel.activeAlert) { alert in
            switch alert {
            case .restart:
                return Alert(
                    title: Text(LT("重新开始测试", "Restart Test", "テストを再開始")),
                    message: Text(LT("当前作答会被放弃，并立即重新开始。", "The current session will be abandoned and restarted immediately.", "現在のセッションは破棄され、すぐに再開始されます。")),
                    primaryButton: .destructive(Text(LT("确认重启", "Restart", "再開始"))) {
                        Task { await viewModel.confirmAlert(.restart) }
                    },
                    secondaryButton: .cancel()
                )
            case .abandon:
                return Alert(
                    title: Text(LT("放弃本次测试", "Abandon Test", "今回のテストを放棄")),
                    message: Text(LT("退出后不会保留本次进度，需要重新开始整场测试。", "Progress will not be preserved. You will need to restart the whole test next time.", "進捗は保存されず、次回は最初からやり直しになります。")),
                    primaryButton: .destructive(Text(LT("确认放弃", "Abandon", "放棄する"))) {
                        Task { await viewModel.confirmAlert(.abandon) }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(RaverTheme.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(RaverTheme.primaryText)
        }
        .font(.subheadline)
    }

    private func personalityStartView(_ summary: PersonalityStatusSummary) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EDMTI")
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(
                            LT(
                                "16 道题，约 3 分钟。没有心理学依据，主打一个离谱但精准。正式测试只能完成一次，但完成后可以随时回来查看结果。",
                                "16 questions in about 3 minutes. Purely for fun, wildly inaccurate but weirdly precise. The formal test can only be completed once, but you can come back anytime to view your result.",
                                "16問で約3分。心理学的根拠はなく、ネタ寄りだけど妙に当たるテストです。正式テストは1回だけですが、結果はいつでも見返せます。"
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)

                        VStack(alignment: .leading, spacing: 8) {
                            summaryRow(LT("正式题数", "Question Count", "問題数"), "\(summary.questionCount)")
                            summaryRow(LT("人格容量", "Result Capacity", "結果容量"), "\(summary.resultTypeCapacity)")
                            summaryRow(LT("调试套题题数", "Debug Set Count", "デバッグ問題数"), "\(summary.debugQuestionSetCount)")
                        }
                    }
                }

                if let feedbackMessage = viewModel.feedbackMessage, !feedbackMessage.isEmpty {
                    ScreenStatusBanner(message: feedbackMessage, style: .error)
                }

                if summary.hasCompleted, let result = summary.result {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LT("你的人格结果", "Your Result", "あなたの結果"))
                                .font(.headline)
                            Text("\(result.code) · \(result.title)")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                            if let slang = result.slangTagline, !slang.isEmpty {
                                Text(slang)
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            if let completedAt = summary.completedAt {
                                Text("\(LT("完成时间", "Completed At", "完了日時")): \(formatTime(completedAt))")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                }

                if summary.hasCompleted {
                    Button {
                        if let result = summary.result {
                            viewModel.showExistingResult(result, questionCount: summary.questionCount)
                        }
                    } label: {
                        Text(LT("查看结果", "View Result", "結果を見る"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RaverTheme.accent)
                } else {
                    Button {
                        Task { await viewModel.startSession(mode: .standard) }
                    } label: {
                        Text(LT("开始测试", "Start Test", "テストを開始"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RaverTheme.accent)
                    .disabled(!summary.canStart)
                }

                if summary.canUseDebugQuestionSet {
                    Button {
                        Task { await viewModel.startSession(mode: .debugSet) }
                    } label: {
                        Text(LT("进入调试模式", "Open Debug Mode", "デバッグモードを開始"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(RaverTheme.accent)
                    .disabled(!summary.canStartDebugQuestionSet)
                }

                if !summary.canStart && !summary.hasCompleted {
                    Text(disabledReasonText(summary.disabledReason))
                        .font(.footnote)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
    }

    private var personalityQuestionView: some View {
        VStack(spacing: 0) {
            if viewModel.isPreparingSession {
                VStack(spacing: 18) {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Text(LT("正在准备测试", "Preparing Test", "テストを準備中"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text("第\(viewModel.sessionPreparationCompletedCount)/\(viewModel.sessionPreparationTargetCount)题")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                    if let message = viewModel.sessionPreparationMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            } else if let question = viewModel.currentQuestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        personalityFeedbackBanner()
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(viewModel.progressText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.accent)
                                Spacer()
                                if question.isEasterEgg {
                                    Text(LT("彩蛋题", "Bonus", "ボーナス"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                            }
                            Text(question.stemText)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                            if let imageUrl = question.stemImageUrl,
                               !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity, minHeight: 180)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(RaverTheme.card)
                                            .frame(maxWidth: .infinity, minHeight: 180)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }

                        Group {
                            if usesImageGridLayout(for: question) {
                                imageOptionGrid(question: question)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(question.options) { option in
                                        listOptionCard(question: question, option: option)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .id(question.questionId)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
                .animation(.easeInOut(duration: 0.24), value: viewModel.currentQuestionIndex)

                bottomActionBar(
                    tertiaryTitle: LT("放弃", "Abandon", "放棄"),
                    secondaryTitle: LT("上一步", "Previous", "前へ"),
                    primaryTitle: viewModel.currentQuestionIndex == (viewModel.session?.questions.count ?? 1) - 1
                        ? LT("查看结果", "See Result", "結果を見る")
                        : LT("下一步", "Next", "次へ"),
                    isPrimaryBusy: viewModel.isSubmitting,
                    isPrimaryDisabled: !viewModel.canAdvanceFromCurrentQuestion,
                    isSecondaryDisabled: viewModel.currentQuestionIndex == 0,
                    onTertiary: { viewModel.requestAbandon() },
                    onSecondary: { viewModel.goPrevious() },
                    onPrimary: { viewModel.goNext() }
                )
            }
        }
        .background(RaverTheme.background)
    }

    private func personalityResultView(_ result: PersonalitySessionSubmitResponse) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部角色图
                    if let imageUrl = result.result.imageUrl,
                    !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: UIScreen.main.bounds.width * 0.45)
                            default:
                                Color.clear.frame(height: 0)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    }

                    // 英文 code 在上，中文标题在下
                    VStack(spacing: 4) {
                        Text(result.result.code)
                            .font(.system(size: 20, weight: .bold))
                            .tracking(1.8)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.72, green: 0.52, blue: 1.0),
                                        Color(red: 0.56, green: 0.38, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(result.result.title)
                            .font(.system(size: 34, weight: .heavy))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.72, green: 0.52, blue: 1.0),
                                        Color(red: 0.56, green: 0.38, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)

                    // subtitle
                    if let subtitle = result.result.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 10)
                    }

                    // 一句话总结，保留引用块样式，但放在当前上方位置
                    if let slang = result.result.slangTagline, !slang.isEmpty {
                        HStack(spacing: 0) {
                            Image(systemName: "quote.opening")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(RaverTheme.accent)
                                .padding(.trailing, 10)
                            Text(slang)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(RaverTheme.primaryText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                            Image(systemName: "quote.closing")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(RaverTheme.accent)
                                .padding(.leading, 10)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(RaverTheme.accent.opacity(0.22), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }

                    VStack(spacing: 14) {
                        // 专属曲风卡片（genre 拆成 chip tags）
                        if let genre = result.result.genreMapping, !genre.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(LT("你的专属曲风", "Your Genre Match", "あなたのジャンル"), systemImage: "music.note")
                                    .font(.headline)
                                    .foregroundStyle(RaverTheme.accent)

                                let genreTags = genre
                                    .components(separatedBy: CharacterSet(charactersIn: ",，、/"))
                                    .map { $0.trimmingCharacters(in: .whitespaces) }
                                    .filter { !$0.isEmpty }

                                genreChipsFlow(genreTags)
                            }
                        }

                        // 人格解读卡片
                        VStack(alignment: .leading, spacing: 10) {
                            Label(LT("人格解读", "Description", "解説"), systemImage: "person.fill")
                                .font(.headline)
                                .foregroundStyle(RaverTheme.accent)
                            Text(result.result.description)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }

            // 底部双按钮
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label(LT("再测一次", "Retake", "再テスト"), systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(RaverTheme.card)
                )
                .foregroundStyle(RaverTheme.primaryText)

                Button {
                    dismiss()
                } label: {
                    Label(LT("分享结果", "Share", "シェア"), systemImage: "paperplane.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.62, green: 0.42, blue: 1.0),
                            RaverTheme.accent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(
                RaverTheme.card
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .background(RaverTheme.background)
    }

    @ViewBuilder
    private func genreChipsFlow(_ tags: [String]) -> some View {
        // 简单的自动换行 flow layout（使用 LazyVStack + HStack 模拟）
        let rows = buildRows(tags: tags, containerWidth: UIScreen.main.bounds.width - 80, font: UIFont.systemFont(ofSize: 13, weight: .semibold), spacing: 8)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(RaverTheme.accent.opacity(0.16))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(RaverTheme.accent.opacity(0.32), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildRows(tags: [String], containerWidth: CGFloat, font: UIFont, spacing: CGFloat) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentWidth: CGFloat = 0
        let paddingH: CGFloat = 24 + 8 // horizontal padding inside chip + spacing

        for tag in tags {
            let tagWidth = (tag as NSString).size(withAttributes: [.font: font]).width + paddingH
            if currentWidth + tagWidth + spacing > containerWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [tag]
                currentWidth = tagWidth
            } else {
                currentRow.append(tag)
                currentWidth += tagWidth + spacing
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }
        return rows
    }

    private func disabledReasonText(_ code: String?) -> String {
        switch code {
        case "personality_disabled":
            return LT("当前 EDMTI 测试暂未开启。", "EDMTI is currently disabled.", "現在 EDMTI は無効です。")
        case "already_completed":
            return LT("你已经完成正式测试，可以直接查看结果。", "You have already completed the formal test and can view your result directly.", "正式テストはすでに完了しており、結果を直接確認できます。")
        case "session_in_progress":
            return LT("当前已有进行中的测试。", "A personality session is already in progress.", "進行中のテストセッションがあります。")
        default:
            return LT("当前暂时无法开始测试。", "Unable to start the test right now.", "現在テストを開始できません。")
        }
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

@MainActor
private final class ContributionCenterViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case event
        case dj

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return LT("全部", "All", "すべて")
            case .event:
                return "Event"
            case .dj:
                return "DJ"
            }
        }
    }

    @Published var summary: WebContributionCenterSummary?
    @Published var items: [WebContributionHistoryItem] = []
    @Published var selectedFilter: Filter = .all
    @Published var currentPage = 1
    @Published var requestedPageText = "1"
    @Published var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var bannerMessage: String?
    @Published var bannerStyle: ScreenStatusBannerStyle = .info
    @Published var bannerAllowsRetry = false
    @Published var loadMoreErrorMessage: String?
    @Published var errorMessage: String?

    private let contentRepository: ProfileContentRepository
    private let pageSize = 10
    private let offlineSnapshotStorageKey = "raver.profile.contributionCenter.offlineSnapshot.v2"
    private var loadedInitial = false
    private var loadedPages: [Int: ContributionCenterLoadedPage] = [:]
    private var pendingPageRequest: Int?

    init(contentRepository: ProfileContentRepository) {
        self.contentRepository = contentRepository
    }

    var hasVisibleContent: Bool {
        summary != nil || !loadedPages.isEmpty || !items.isEmpty
    }

    var canGoToPreviousPage: Bool {
        currentPage > 1
    }

    var canGoToNextPage: Bool {
        guard let page = loadedPages[currentPage] else { return false }
        return currentPage < maxLoadedPage || page.hasMore
    }

    var pageIndicatorText: String {
        if let totalPages {
            return LT(
                "第 \(currentPage) / \(totalPages) 页",
                "Page \(currentPage) / \(totalPages)",
                "\(currentPage) / \(totalPages) ページ"
            )
        }
        return LT(
            "第 \(currentPage) 页",
            "Page \(currentPage)",
            "\(currentPage) ページ"
        )
    }

    var pageSizeText: String {
        LT("每页 10 条", "10 items per page", "1ページ 10 件")
    }

    private var maxLoadedPage: Int {
        loadedPages.keys.max() ?? 0
    }

    private var totalPages: Int? {
        guard let lastPage = loadedPages[maxLoadedPage], !lastPage.hasMore else {
            return nil
        }
        return maxLoadedPage
    }

    func loadIfNeeded() async {
        guard !loadedInitial else { return }
        await reload()
    }

    func reload() async {
        guard !isLoading else { return }
        let restoredFromSnapshot = !hasVisibleContent && restoreOfflineSnapshot(for: selectedFilter)
        let hadContent = hasVisibleContent
        isLoading = true
        loadMoreErrorMessage = nil
        if hadContent || restoredFromSnapshot {
            phase = .success
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }

        do {
            async let summaryTask = contentRepository.fetchMyContributionCenterSummary()
            async let pageTask = contentRepository.fetchMyContributionHistory(
                entityType: selectedFilter.rawValue,
                cursor: nil,
                limit: pageSize
            )
            let (loadedSummary, page) = try await (summaryTask, pageTask)
            summary = loadedSummary
            loadedPages = [1: ContributionCenterLoadedPage(page: 1, payload: page)]
            applyLoadedPage(1)
            pendingPageRequest = nil
            loadedInitial = true
            phase = .success
            bannerMessage = nil
            bannerAllowsRetry = false
            loadMoreErrorMessage = nil
            errorMessage = nil
            persistOfflineSnapshot(for: selectedFilter)
        } catch {
            guard !error.isUserInitiatedCancellation else { return }
            loadedInitial = true

            if restoreOfflineSnapshot(for: selectedFilter) {
                phase = .success
                bannerAllowsRetry = false
                bannerStyle = .warning
                bannerMessage = isRequestTimeoutError(error)
                    ? LT(
                        "请求超时，已展示最近一次同步的贡献记录。",
                        "Request timed out. Showing your latest synced contributions.",
                        "リクエストがタイムアウトしたため、最後に同期した貢献履歴を表示しています。"
                    )
                    : LT(
                        "当前离线，已展示最近一次同步的贡献记录。",
                        "You're offline. Showing your latest synced contributions.",
                        "現在オフラインのため、最後に同期した貢献履歴を表示しています。"
                    )
                errorMessage = nil
            } else if hadContent || restoredFromSnapshot {
                phase = .success
                bannerMessage = error.userFacingMessage ?? LT(
                    "贡献记录刷新失败，请稍后重试。",
                    "Failed to refresh contributions. Please try again later.",
                    "貢献履歴を更新できませんでした。時間をおいて再試行してください。"
                )
                bannerStyle = .error
                bannerAllowsRetry = true
                errorMessage = nil
            } else {
                let message = error.userFacingMessage ?? LT(
                    "贡献记录加载失败，请稍后重试。",
                    "Failed to load contributions. Please try again later.",
                    "貢献履歴を読み込めませんでした。時間をおいて再試行してください。"
                )
                phase = isOfflineRecoverableError(error) ? .offline(message: message) : .failure(message: message)
            }
        }
    }

    func selectFilter(_ filter: Filter) async {
        guard selectedFilter != filter else { return }
        ContributionModuleTelemetry.contributionCenterFilterTapped(filter: filter.rawValue)
        selectedFilter = filter
        applyCachedPageIfAvailable(for: filter)
        await reload()
    }

    func goToPreviousPage() {
        guard canGoToPreviousPage else { return }
        applyLoadedPage(currentPage - 1)
    }

    func goToNextPage() async {
        guard canGoToNextPage else { return }
        await goToPage(currentPage + 1)
    }

    func jumpToRequestedPage() async {
        let trimmed = requestedPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let targetPage = Int(trimmed), targetPage > 0 else {
            errorMessage = LT(
                "请输入大于 0 的页码。",
                "Enter a page number greater than 0.",
                "0 より大きいページ番号を入力してください。"
            )
            requestedPageText = "\(currentPage)"
            return
        }
        await goToPage(targetPage)
    }

    func retryLoadMore() async {
        if let pendingPageRequest {
            await goToPage(pendingPageRequest)
        } else if canGoToNextPage {
            await goToNextPage()
        }
    }

    func dismissBanner() {
        bannerMessage = nil
        bannerAllowsRetry = false
    }

    private func applyCachedPageIfAvailable(for filter: Filter) {
        guard let snapshot = loadOfflineSnapshot(),
              let cachedFilter = snapshot.filters.first(where: { $0.filter == filter.rawValue }) else {
            resetPaginationState()
            return
        }

        summary = snapshot.summary ?? summary
        loadedPages = Dictionary(uniqueKeysWithValues: cachedFilter.pages.map {
            ($0.page, ContributionCenterLoadedPage(page: $0.page, items: $0.items, nextCursor: $0.nextCursor, hasMore: $0.hasMore))
        })
        let fallbackPage = cachedFilter.pages.map(\.page).max() ?? 1
        applyLoadedPage(min(max(cachedFilter.currentPage, 1), fallbackPage))
        phase = .success
    }

    private func persistOfflineSnapshot(for filter: Filter) {
        guard !loadedPages.isEmpty || summary != nil else { return }

        var snapshot = loadOfflineSnapshot() ?? ContributionCenterOfflineSnapshot(summary: nil, filters: [], cachedAt: Date())
        snapshot.summary = summary
        snapshot.cachedAt = Date()
        let filterSnapshot = ContributionCenterOfflineFilterSnapshot(
            filter: filter.rawValue,
            currentPage: currentPage,
            pages: loadedPages.keys.sorted().compactMap { page in
                guard let payload = loadedPages[page] else { return nil }
                return ContributionCenterOfflinePageSnapshot(
                    page: page,
                    items: payload.items,
                    nextCursor: payload.nextCursor,
                    hasMore: payload.hasMore
                )
            }
        )
        snapshot.filters.removeAll { $0.filter == filter.rawValue }
        snapshot.filters.append(filterSnapshot)

        do {
            let data = try JSONEncoder.raver.encode(snapshot)
            UserDefaults.standard.set(data, forKey: offlineSnapshotStorageKey)
        } catch {
            assertionFailure("Failed to persist contribution center offline snapshot: \(error)")
        }
    }

    private func loadOfflineSnapshot() -> ContributionCenterOfflineSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: offlineSnapshotStorageKey) else {
            return nil
        }
        return try? JSONDecoder.raver.decode(ContributionCenterOfflineSnapshot.self, from: data)
    }

    private func restoreOfflineSnapshot(for filter: Filter) -> Bool {
        guard let snapshot = loadOfflineSnapshot(),
              let cachedFilter = snapshot.filters.first(where: { $0.filter == filter.rawValue }) else {
            return false
        }

        summary = snapshot.summary
        loadedPages = Dictionary(uniqueKeysWithValues: cachedFilter.pages.map {
            ($0.page, ContributionCenterLoadedPage(page: $0.page, items: $0.items, nextCursor: $0.nextCursor, hasMore: $0.hasMore))
        })
        let fallbackPage = cachedFilter.pages.map(\.page).max() ?? 1
        applyLoadedPage(min(max(cachedFilter.currentPage, 1), fallbackPage))
        phase = .success
        loadMoreErrorMessage = nil
        return true
    }

    private func resetPaginationState() {
        loadedPages = [:]
        items = []
        currentPage = 1
        requestedPageText = "1"
        pendingPageRequest = nil
        loadMoreErrorMessage = nil
    }

    private func applyLoadedPage(_ page: Int) {
        guard let payload = loadedPages[page] else {
            return
        }
        currentPage = page
        requestedPageText = "\(page)"
        items = payload.items
        pendingPageRequest = nil
        loadMoreErrorMessage = nil
        persistOfflineSnapshot(for: selectedFilter)
    }

    private func goToPage(_ targetPage: Int) async {
        guard targetPage > 0 else { return }
        if loadedPages[targetPage] != nil {
            applyLoadedPage(targetPage)
            return
        }
        guard !isLoadingMore, !isLoading else { return }

        isLoadingMore = true
        loadMoreErrorMessage = nil
        pendingPageRequest = targetPage
        defer { isLoadingMore = false }

        do {
            let resolution = try await ensurePageLoaded(targetPage)
            applyLoadedPage(resolution.page)
            if resolution.exact {
                errorMessage = nil
            } else {
                errorMessage = LT(
                    "当前只有 \(resolution.page) 页。",
                    "Only \(resolution.page) pages are available.",
                    "現在利用できるのは \(resolution.page) ページまでです。"
                )
            }
        } catch {
            guard !error.isUserInitiatedCancellation else { return }
            loadMoreErrorMessage = error.userFacingMessage ?? LT(
                "指定页加载失败，请稍后重试。",
                "Failed to load the requested page. Please try again later.",
                "指定したページを読み込めませんでした。時間をおいて再試行してください。"
            )
        }
    }

    private func ensurePageLoaded(_ targetPage: Int) async throws -> ContributionCenterPageResolution {
        if loadedPages[targetPage] != nil {
            return ContributionCenterPageResolution(page: targetPage, exact: true)
        }

        var pageToLoad = maxLoadedPage + 1
        if pageToLoad <= 0 {
            pageToLoad = 1
        }

        while pageToLoad <= targetPage {
            let cursor: String?
            if pageToLoad == 1 {
                cursor = nil
            } else {
                guard let previousPage = loadedPages[pageToLoad - 1] else {
                    break
                }
                guard previousPage.hasMore, let nextCursor = previousPage.nextCursor, !nextCursor.isEmpty else {
                    return ContributionCenterPageResolution(page: previousPage.page, exact: false)
                }
                cursor = nextCursor
            }

            let page = try await contentRepository.fetchMyContributionHistory(
                entityType: selectedFilter.rawValue,
                cursor: cursor,
                limit: pageSize
            )
            loadedPages[pageToLoad] = ContributionCenterLoadedPage(page: pageToLoad, payload: page)
            persistOfflineSnapshot(for: selectedFilter)

            if pageToLoad == targetPage {
                return ContributionCenterPageResolution(page: pageToLoad, exact: true)
            }

            if !page.pageInfo.hasMore {
                return ContributionCenterPageResolution(page: pageToLoad, exact: false)
            }

            pageToLoad += 1
        }

        let resolvedPage = min(maxLoadedPage, max(1, targetPage))
        return ContributionCenterPageResolution(page: resolvedPage, exact: loadedPages[resolvedPage] != nil && resolvedPage == targetPage)
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

    private struct ContributionCenterOfflineSnapshot: Codable {
        var summary: WebContributionCenterSummary?
        var filters: [ContributionCenterOfflineFilterSnapshot]
        var cachedAt: Date
    }

    private struct ContributionCenterOfflineFilterSnapshot: Codable {
        var filter: String
        var currentPage: Int
        var pages: [ContributionCenterOfflinePageSnapshot]
    }

    private struct ContributionCenterOfflinePageSnapshot: Codable {
        var page: Int
        var items: [WebContributionHistoryItem]
        var nextCursor: String?
        var hasMore: Bool
    }

    private struct ContributionCenterLoadedPage {
        var page: Int
        var items: [WebContributionHistoryItem]
        var nextCursor: String?
        var hasMore: Bool

        init(page: Int, payload: WebContributionHistoryPage) {
            self.page = page
            self.items = payload.items
            self.nextCursor = payload.pageInfo.nextCursor
            self.hasMore = payload.pageInfo.hasMore
        }

        init(page: Int, items: [WebContributionHistoryItem], nextCursor: String?, hasMore: Bool) {
            self.page = page
            self.items = items
            self.nextCursor = nextCursor
            self.hasMore = hasMore
        }
    }

    private struct ContributionCenterPageResolution {
        var page: Int
        var exact: Bool
    }
}

struct ContributionCenterView: View {
    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: ContributionCenterViewModel
    @State private var hasTrackedExposure = false

    init(contentRepository: ProfileContentRepository) {
        _viewModel = StateObject(wrappedValue: ContributionCenterViewModel(contentRepository: contentRepository))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .initialLoading:
                ScrollView {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                }
            case .failure(let message):
                ScrollView {
                    ScreenErrorCard(
                        title: LT("贡献中心加载失败", "Failed to load contributions", "貢献センターを読み込めませんでした"),
                        message: message,
                        retryAction: {
                        Task { await viewModel.reload() }
                        }
                    )
                    .padding(16)
                    .padding(.top, 40)
                }
            case .offline(let message):
                ScrollView {
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message,
                        retryAction: {
                        Task { await viewModel.reload() }
                        }
                    )
                    .padding(16)
                    .padding(.top, 40)
                }
            case .empty, .success:
                ScrollView {
                    VStack(spacing: 16) {
                        if viewModel.isLoading && viewModel.hasVisibleContent {
                            InlineLoadingBadge(title: LT("正在更新贡献记录", "Updating contributions", "貢献履歴を更新中"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let bannerMessage = viewModel.bannerMessage {
                            ScreenStatusBanner(
                                message: bannerMessage,
                                style: viewModel.bannerStyle,
                                actionTitle: viewModel.bannerAllowsRetry ? LT("重试", "Retry", "再試行") : nil,
                                onDismiss: viewModel.dismissBanner,
                                action: {
                                    Task { await viewModel.reload() }
                                }
                            )
                        }
                        summaryCard
                        filterBar
                        historySection
                    }
                    .padding(16)
                }
            }
        }
        .background(RaverTheme.background.ignoresSafeArea())
        .raverSystemNavigation(title: LT("贡献中心", "Contributions", "貢献センター"))
        .task {
            if !hasTrackedExposure {
                ContributionModuleTelemetry.contributionCenterExposure(filter: viewModel.selectedFilter.rawValue)
                hasTrackedExposure = true
            }
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(LT("历史贡献总览", "Contribution Summary", "貢献サマリー"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                if let summary = viewModel.summary {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                        spacing: 10
                    ) {
                        summaryMetric(
                            title: LT("全部贡献", "Total", "総貢献"),
                            value: "\(summary.totalContributionCount)"
                        )
                        summaryMetric(
                            title: LT("贡献过的活动", "Events", "イベント"),
                            value: "\(summary.contributedEventCount)"
                        )
                        summaryMetric(
                            title: LT("贡献过的 DJ", "DJs", "DJ"),
                            value: "\(summary.contributedDJCount)"
                        )
                        summaryMetric(
                            title: LT("最近贡献", "Latest", "最新"),
                            value: summary.lastContributionAt.map(Self.utcTimestampText) ?? "-"
                        )
                    }

                    if !summary.recentItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LT("最近 3 条", "Recent 3", "最近3件"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                            ForEach(summary.recentItems) { item in
                                Button {
                                    openContributionTarget(item)
                                } label: {
                                    contributionCompactRow(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    Text(LT("暂无贡献记录", "No contributions yet", "貢献履歴はまだありません"))
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ContributionCenterViewModel.Filter.allCases) { filter in
                    Button {
                        Task { await viewModel.selectFilter(filter) }
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.selectedFilter == filter ? RaverTheme.background : RaverTheme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(viewModel.selectedFilter == filter ? RaverTheme.accent : RaverTheme.card)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LT("历史列表", "History", "履歴"))
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)

            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView(
                    LT("暂无贡献记录", "No contributions yet", "貢献履歴はまだありません"),
                    systemImage: "person.crop.circle.badge.checkmark",
                    description: Text(LT(
                        "通过审核并成功生效的 Event / DJ 修改，会出现在这里。",
                        "Approved Event and DJ changes that successfully go live will appear here.",
                        "承認されて反映された Event / DJ の変更履歴がここに表示されます。"
                    ))
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.items) { item in
                        Button {
                            openContributionTarget(item)
                        } label: {
                            contributionHistoryRow(item)
                        }
                        .buttonStyle(.plain)
                    }

                    historyPaginationControls
                }
            }
        }
    }

    private var historyPaginationControls: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.pageIndicatorText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(viewModel.pageSizeText)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.goToPreviousPage()
                    } label: {
                        Text(LT("上一页", "Previous", "前へ"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.canGoToPreviousPage ? RaverTheme.primaryText : RaverTheme.secondaryText.opacity(0.55))
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(RaverTheme.card)
                    )
                    .disabled(!viewModel.canGoToPreviousPage || viewModel.isLoadingMore || viewModel.isLoading)

                    Button {
                        Task { await viewModel.goToNextPage() }
                    } label: {
                        Text(LT("下一页", "Next", "次へ"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.canGoToNextPage ? .white : .white.opacity(0.7))
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(viewModel.canGoToNextPage ? RaverTheme.accent : RaverTheme.accent.opacity(0.45))
                    )
                    .disabled(!viewModel.canGoToNextPage || viewModel.isLoadingMore || viewModel.isLoading)
                }

                HStack(spacing: 10) {
                    TextField(LT("页码", "Page", "ページ"), text: $viewModel.requestedPageText)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(RaverTheme.card)
                        )

                    Button {
                        Task { await viewModel.jumpToRequestedPage() }
                    } label: {
                        Text(LT("跳转", "Go", "移動"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RaverTheme.primaryText)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(RaverTheme.card)
                    )
                    .disabled(viewModel.isLoadingMore || viewModel.isLoading)
                }

                if let loadMoreErrorMessage = viewModel.loadMoreErrorMessage {
                    ScreenStatusBanner(
                        message: loadMoreErrorMessage,
                        style: .error,
                        actionTitle: LT("重试", "Retry", "再試行"),
                        action: {
                            Task { await viewModel.retryLoadMore() }
                        }
                    )
                }
            }
        }
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    private func contributionCompactRow(_ item: WebContributionHistoryItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(RaverTheme.accent.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: item.entity.type == "event" ? "calendar" : "music.mic")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.entity.title ?? fallbackTitle(for: item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Text(Self.historyMetaText(for: item))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    private func contributionHistoryRow(_ item: WebContributionHistoryItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            contributionCover(item)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.entity.title ?? fallbackTitle(for: item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .multilineTextAlignment(.leading)

                Text(Self.historyMetaText(for: item))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)

                if let summary = item.changeSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !summary.isEmpty {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(RaverTheme.primaryText)
                        .multilineTextAlignment(.leading)
                }

                Text(Self.utcTimestampText(item.occurredAt))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            Spacer(minLength: 8)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    private func contributionCover(_ item: WebContributionHistoryItem) -> some View {
        let resolved = AppConfig.resolvedURLString(item.entity.coverImageUrl)
        return Group {
            if let resolved, let url = URL(string: resolved) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        coverFallback(item)
                    }
                }
            } else {
                coverFallback(item)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func coverFallback(_ item: WebContributionHistoryItem) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(RaverTheme.accent.opacity(0.14))
            .overlay {
                Image(systemName: item.entity.type == "event" ? "calendar" : "music.mic")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(RaverTheme.accent)
            }
    }

    private func openContributionTarget(_ item: WebContributionHistoryItem) {
        if item.entity.type == "event" {
            appPush(.eventDetail(eventID: item.entity.id))
            return
        }
        if item.entity.type == "dj" {
            appPush(.djDetail(djID: item.entity.id))
        }
    }

    private func fallbackTitle(for item: WebContributionHistoryItem) -> String {
        item.entity.type == "event"
            ? LT("未命名活动", "Untitled Event", "名称未設定のイベント")
            : LT("未命名 DJ", "Untitled DJ", "名称未設定のDJ")
    }

    private static func historyMetaText(for item: WebContributionHistoryItem) -> String {
        let typeText = item.entity.type == "event" ? "Event" : "DJ"
        let roleText = item.role == "creator"
            ? LT("创建者", "Creator", "作成者")
            : LT("贡献者", "Contributor", "貢献者")
        let actionText = item.actionType == "create"
            ? LT("创建", "Create", "作成")
            : LT("修改", "Edit", "編集")
        return "\(typeText) · \(roleText) · \(actionText)"
    }

    private static func utcTimestampText(_ date: Date) -> String {
        utcFormatter.string(from: date)
    }

    private static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        return formatter
    }()
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
            return LT("海报地址无效，请稍后重试。", "Poster URL is invalid. Please try again later.", "海報URLが無効です。時間をおいて再試行してください。")
        case .permissionDenied:
            return LT("未获得相册权限，可稍后重新授权后再试。", "Photo permission denied. Please grant access and try again.", "写真へのアクセスが拒否されています。許可してからもう一度お試しください。")
        case .imageDecodeFailed:
            return LT("图片读取失败，请稍后重试。", "Failed to read image. Please try again later.", "画像を読み込めませんでした。時間をおいて再試行してください。")
        case .saveFailed:
            return LT("保存失败，请重试。", "Save failed. Please try again.", "保存に失敗しました。もう一度お試しください。")
        }
    }
}
