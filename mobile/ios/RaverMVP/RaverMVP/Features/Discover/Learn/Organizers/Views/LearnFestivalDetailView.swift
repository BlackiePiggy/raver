import SwiftUI
import UIKit

private struct BrandCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: BrandShareCardPayload
}

private struct BrandSharePreviewCard: View {
    let payload: BrandShareCardPayload

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

                Text(payload.brandName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                Text([payload.country, payload.city].compactMap { $0?.nilIfBlank }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
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
            Image(systemName: "sparkles.tv")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }
}

struct LearnFestivalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    let onFestivalUpdated: ((LearnFestival) -> Void)?

    private var wikiRepository: DiscoverWikiRepository {
        appContainer.discoverWikiRepository
    }

    private var eventListRepository: EventListRepository {
        appContainer.eventListRepository
    }

    private var newsRepository: DiscoverNewsRepository {
        appContainer.discoverNewsRepository
    }

    @State private var currentFestival: LearnFestival
    @State private var previewImage: LearnImagePreviewItem?
    @State private var selectedHeroMedia: FullscreenMediaSelection?
    @State private var avatarLuminance: CGFloat?
    @State private var selectedTab: LearnFestivalDetailTab = .basic
    @State private var pageProgress: CGFloat = 0
    @State private var isTabSwitchingByTap = false
    @State private var tabSwitchUnlockWorkItem: DispatchWorkItem?
    @State private var upcomingRelatedEvents: [WebEvent] = []
    @State private var endedRelatedEvents: [WebEvent] = []
    @State private var relatedArticles: [DiscoverNewsArticle] = []
    @State private var isLoadingRelatedContent = false
    @State private var isLoadingRelatedEvents = false
    @State private var isLoadingRelatedArticles = false
    @State private var isLoadingMoreUpcomingRelatedEvents = false
    @State private var isLoadingMoreEndedRelatedEvents = false
    @State private var didLoadRelatedEvents = false
    @State private var didLoadRelatedArticles = false
    @State private var relatedEventsLoadFailed = false
    @State private var relatedArticlesLoadFailed = false
    @State private var upcomingRelatedEventsPage = 0
    @State private var upcomingRelatedEventsTotalPages = 1
    @State private var endedRelatedEventsPage = 0
    @State private var endedRelatedEventsTotalPages = 1
    @State private var visibleRelatedArticleCount = 5
    @State private var errorMessage: String?
    @State private var followedBrandUpdatePreference = FollowedBrandUpdatePreference.empty
    @State private var isLoadingFollowedBrandPreference = false
    @State private var isTogglingBrandFollow = false
    @State private var shareMorePresentation: BrandCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: BrandCardSharePresentation?
    @State private var reportTarget: ReportSheetTarget?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    init(festival: LearnFestival, onFestivalUpdated: ((LearnFestival) -> Void)? = nil) {
        self.onFestivalUpdated = onFestivalUpdated
        _currentFestival = State(initialValue: festival)
    }

    fileprivate enum LearnFestivalDetailTab: String, CaseIterable, Identifiable {
        case basic
        case events
        case posts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .basic: return LT("信息", "Info", "情報")
            case .events: return LT("活动", "Events", "イベント")
            case .posts: return LT("动态", "Posts", "投稿")
            }
        }

        var themeColor: Color {
            switch self {
            case .basic: return Color(red: 0.27, green: 0.85, blue: 0.82)
            case .events: return Color(red: 0.98, green: 0.71, blue: 0.22)
            case .posts: return Color(red: 0.95, green: 0.30, blue: 0.38)
            }
        }
    }

    var body: some View {
        RaverImmersiveDetailPagerChrome(
            title: currentFestival.name,
            tabs: LearnFestivalDetailTab.allCases,
            selectedTab: selectedTab,
            pageProgress: $pageProgress,
            namespace: "festival-detail",
            configuration: detailChromeConfiguration
        ) {
            heroSection
        } tabBar: {
            tabBar
        } content: { chrome in
            tabPager(chrome: chrome)
        }
        .raverImmersiveFloatingNavigationChrome(
            trailing: immersiveTrailingAction
        ) {
            dismiss()
        }
        .navigationDestination(item: $previewImage) { item in
            LearnImagePreviewView(item: item)
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
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                BrandSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, _ in
                showWidgetStatusBanner(message: LT("举报已提交", "Report submitted", "報告を送信しました"))
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .fullScreenCover(item: $selectedHeroMedia) { selection in
            if let url = destinationURL(currentFestival.backgroundUrl) {
                FullscreenMediaViewer(items: [FullscreenMediaItem(rawURL: url.absoluteString, index: 0)], initialIndex: selection.id)
            }
        }
        .task(id: currentFestival.id) {
            await hydrateFestivalContributorsIfNeeded()
        }
        .task(id: currentFestival.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
        .onChange(of: selectedTab) { _, tab in
            resetFestivalVisibleCounts(for: tab)
            Task { await loadFestivalTabContentIfNeeded(for: tab) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverEventDidSave)) { _ in
            guard selectedTab == .events else { return }
            Task { await loadRelatedEventsIfNeeded(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverOrganizerDidSave)) { notification in
            let savedFestivalID = notification.object as? String
            guard savedFestivalID == nil || savedFestivalID == currentFestival.id else { return }
            if let brand = notification.userInfo?["brand"] as? WebLearnFestival,
               brand.id == currentFestival.id {
                let hydrated = LearnFestival(web: brand)
                currentFestival = hydrated
                onFestivalUpdated?(hydrated)
            }
            Task { await refreshCurrentFestivalAfterSave() }
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
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
                        quickActions: shareMoreQuickActions(for: currentFestival),
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
        .operationBannerHost()
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
    }

    private var immersiveTrailingAction: AnyView? {
        AnyView(
            Button {
                shareMorePresentation = BrandCardSharePresentation(
                    payload: makeBrandShareCardPayload(from: currentFestival)
                )
                isShareMorePanelVisible = false
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

    private var festivalHeaderPrimaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black.opacity(0.88)
    }

    private var festivalHeaderSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.78)
    }

    private var festivalHeaderTertiaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.76)
    }

    private func openFestivalCacheEntry() {
        errorMessage = LT("该页面缓存能力正在建设中。", "Caching for this page is under construction.", "このページのキャッシュ機能は現在構築中です。")
    }

    private func openFestivalFeedbackEntry() {
        errorMessage = LT("贡献信息入口即将开放，当前已记录该需求。", "Incorrect info entry is coming soon. We have recorded this request.", "情報修正の入口は近日公開予定です。この要望は記録しました。")
    }

    private func openFestivalReportEntry() {
        reportTarget = ReportSheetTarget(
            id: currentFestival.id,
            type: .festival,
            title: currentFestival.name,
            preview: currentFestival.introduction.nilIfBlank ?? currentFestival.tagline.nilIfBlank,
            targetUserID: nil,
            targetUserDisplayName: nil
        )
    }

    private var isFollowingCurrentFestivalBrand: Bool {
        currentFestival.isFollowing ?? followedBrandUpdatePreference.watchedBrandIds.contains(currentFestival.id)
    }

    @MainActor
    private func refreshFollowedBrandUpdatePreference() async {
        guard appState.session != nil else {
            followedBrandUpdatePreference = .empty
            isLoadingFollowedBrandPreference = false
            return
        }

        isLoadingFollowedBrandPreference = true
        defer { isLoadingFollowedBrandPreference = false }

        do {
            followedBrandUpdatePreference = try await wikiRepository.fetchFollowedBrandUpdatePreference()
            currentFestival.isFollowing = followedBrandUpdatePreference.watchedBrandIds.contains(currentFestival.id)
        } catch {
            followedBrandUpdatePreference = .empty
        }
    }

    @MainActor
    private func toggleFestivalBrandFollow() async {
        guard appState.session != nil else {
            errorMessage = LT("请先登录后再关注电音节。", "Please log in before following this festival.", "フェスをフォローするにはログインしてください。")
            return
        }
        guard !isTogglingBrandFollow else { return }

        isTogglingBrandFollow = true
        defer { isTogglingBrandFollow = false }

        do {
            let currentPreference: FollowedBrandUpdatePreference
            if isLoadingFollowedBrandPreference {
                currentPreference = followedBrandUpdatePreference
            } else if followedBrandUpdatePreference == .empty {
                currentPreference = try await wikiRepository.fetchFollowedBrandUpdatePreference()
            } else {
                currentPreference = followedBrandUpdatePreference
            }

            var watchedBrandIDs = currentPreference.watchedBrandIds
            if let index = watchedBrandIDs.firstIndex(of: currentFestival.id) {
                watchedBrandIDs.remove(at: index)
            } else {
                watchedBrandIDs.append(currentFestival.id)
            }

            let normalizedBrandIDs = Array(
                NSOrderedSet(array: watchedBrandIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            ) as? [String] ?? watchedBrandIDs

            let shouldEnable = normalizedBrandIDs.contains(currentFestival.id) ? true : currentPreference.enabled
            followedBrandUpdatePreference = try await wikiRepository.updateFollowedBrandUpdatePreference(
                FollowedBrandUpdatePreferenceInput(
                    enabled: shouldEnable,
                    reminderHours: nil,
                    timezone: nil,
                    channels: nil,
                    watchedBrandIds: normalizedBrandIDs,
                    includeInfos: nil,
                    includeEvents: nil
                )
            )
            currentFestival.isFollowing = followedBrandUpdatePreference.watchedBrandIds.contains(currentFestival.id)
        } catch {
            errorMessage = error.userFacingMessage ?? LT("关注状态更新失败，请稍后重试。", "Failed to update follow status. Please try again later.", "フォロー状態を更新できませんでした。時間をおいて再試行してください。")
        }
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
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func makeBrandShareCardPayload(from festival: LearnFestival) -> BrandShareCardPayload {
        let coverImageURL = AppConfig.resolvedURLString(festival.backgroundUrl)
            ?? AppConfig.resolvedURLString(festival.avatarUrl)
        return BrandShareCardPayload(
            brandID: festival.id,
            brandName: festival.name,
            country: festival.country.nilIfBlank,
            city: festival.city.nilIfBlank,
            tagline: festival.tagline.nilIfBlank,
            coverImageURL: coverImageURL,
            badgeText: LT("品牌", "Brand", "ブランド")
        )
    }

    private func shareTarget(for festival: LearnFestival) -> ShareTarget {
        let canonicalURL = "https://ravehub.top/festival/\(festival.id)"
        let imageURL = AppConfig.resolvedURLString(festival.backgroundUrl)
            ?? AppConfig.resolvedURLString(festival.avatarUrl)
        let subtitle = [
            festival.country.nilIfBlank,
            festival.city.nilIfBlank,
            festival.tagline.nilIfBlank
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
        return ShareTarget(
            type: .festival,
            id: festival.id,
            title: festival.name,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            imageURL: imageURL,
            canonicalURL: canonicalURL,
            deepLink: "raver://festival/\(festival.id)",
            fallbackURL: canonicalURL,
            previewType: "content_card",
            visibility: "public"
        )
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = appContainer.shareMessageRepository.fetchConversations(type: .direct)
        async let groups = appContainer.shareMessageRepository.fetchConversations(type: .group)
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
        _ payload: BrandShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.shareMessageRepository.sendBrandCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await appContainer.shareMessageRepository.sendMessage(
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
                errorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "Instagram",
                systemImage: "camera.circle.fill",
                accentColor: Color(red: 0.91, green: 0.30, blue: 0.48)
            ) {
                errorMessage = LT("Instagram 分享接口待接入。", "Instagram share hook is not connected yet.", "Instagram共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "复制链接",
                systemImage: "link.circle.fill",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                Task { await copyFestivalShareLink(currentFestival) }
            }
        ]
    }

    private func shareMoreQuickActions(for festival: LearnFestival?) -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = []

        if let festival {
            actions.append(
                SharePanelQuickAction(
                    title: LT("查看海报", "View Poster", "海報を見る"),
                    systemImage: "photo.on.rectangle",
                    accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
                ) {
                    Task { await openFestivalPoster(festival) }
                }
            )
        }

        if canEditFestival {
            actions.append(
                SharePanelQuickAction(
                    title: LT("编辑", "Edit", "編集"),
                    systemImage: "square.and.pencil",
                    accentColor: RaverTheme.accent
                ) {
                    discoverPush(.organizerEdit(brandID: currentFestival.id))
                }
            )
        }

        actions.append(
            SharePanelQuickAction(
                title: LT("缓存", "Cache", "キャッシュ"),
                systemImage: "arrow.down.circle",
                accentColor: Color(red: 0.38, green: 0.73, blue: 0.98)
            ) {
                openFestivalCacheEntry()
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("贡献信息", "Incorrect Info", "情報を修正"),
                systemImage: "info.circle",
                accentColor: Color(red: 0.96, green: 0.69, blue: 0.25)
            ) {
                openFestivalFeedbackEntry()
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.93, green: 0.32, blue: 0.36)
            ) {
                openFestivalReportEntry()
            }
        )

        if festival?.links.first?.url != nil {
            actions.append(
                SharePanelQuickAction(
                    title: LT("官网", "Official", "公式サイト"),
                    systemImage: "globe",
                    accentColor: Color(red: 0.53, green: 0.45, blue: 0.96)
                ) {
                    if let url = destinationURL(festival?.links.first?.url) {
                        UIApplication.shared.open(url)
                    }
                }
            )
        }

        return actions
    }

    @MainActor
    private func copyFestivalShareLink(_ festival: LearnFestival) async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: shareTarget(for: festival))
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
    private func openFestivalQRCode(_ festival: LearnFestival) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: festival), channel: "view_qr")
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
    private func openFestivalPoster(_ festival: LearnFestival) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: festival), channel: "view_poster")
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
                        hintText: LT("Festival 海报由分享系统统一生成，名称、摘要和二维码都会跟随短链保持一致。", "Festival posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "Festival海報は共有システムで生成され、名称、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        RaverScrollableTabBar(
            items: festivalDetailTabItems,
            selection: $selectedTab,
            progress: pageProgress,
            onSelect: { tab in
                resetFestivalVisibleCounts(for: tab)
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                    selectedTab = tab
                }
                Task { await loadFestivalTabContentIfNeeded(for: tab) }
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

    private var festivalDetailTabItems: [RaverScrollableTabItem<LearnFestivalDetailTab>] {
        LearnFestivalDetailTab.allCases.map { tab in
            RaverScrollableTabItem(id: tab, title: tab.title)
        }
    }

    @ViewBuilder
    private func tabPager(
        chrome: RaverImmersiveDetailPagerContext<LearnFestivalDetailTab>
    ) -> some View {
        RaverScrollableTabPager(
            items: festivalDetailTabItems,
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
            ScrollView {
                VStack(spacing: 0) {
                    RaverImmersiveDetailOffsetMarker(
                        tabID: tab,
                        coordinateSpaceName: chrome.coordinateSpaceName(tab)
                    )
                    Color.clear
                        .frame(height: chrome.detailTopInset)

                    VStack(alignment: .leading, spacing: 14) {
                        tabContent(tab)
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
            .background(RaverTheme.background)
        }
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
    private var heroSection: some View {
        let backgroundURL = destinationURL(currentFestival.backgroundUrl)

        ZStack(alignment: .top) {
            GeometryReader { geo in
                if let url = backgroundURL {
                    Button {
                        selectedHeroMedia = FullscreenMediaSelection(id: 0)
                    } label: {
                        ImageLoaderView(urlString: url.absoluteString)
                            .background(fallbackBanner)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                } else {
                    fallbackBanner
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.26),
                    RaverTheme.background.opacity(0.84),
                    RaverTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        openPreview(
                            urlString: currentFestival.avatarUrl,
                            title: LT("\(currentFestival.name) Logo", "\(currentFestival.name) Logo", "\(currentFestival.name) のロゴ")
                        )
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 88)
                            .overlay { headerAvatar }
                            .clipped()
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(LearnAvatarLuminanceStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentFestival.name)
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(festivalHeaderPrimaryTextColor)
                                    .lineLimit(2)

                                if !currentFestival.aliases.isEmpty {
                                    Text(currentFestival.aliases.joined(separator: " / "))
                                        .font(.caption)
                                        .foregroundStyle(festivalHeaderSecondaryTextColor)
                                        .lineLimit(2)
                                }

                                Text(LT("\(currentFestival.country) \(currentFestival.city) · Since \(currentFestival.foundedYear)", "\(currentFestival.country) \(currentFestival.city) · Since \(currentFestival.foundedYear)", "\(currentFestival.country) \(currentFestival.city) · \(currentFestival.foundedYear)年開始"))
                                    .font(.caption)
                                    .foregroundStyle(festivalHeaderTertiaryTextColor)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                Task { await toggleFestivalBrandFollow() }
                            } label: {
                                Group {
                                    if isLoadingFollowedBrandPreference || isTogglingBrandFollow {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.white)
                                            .frame(minWidth: 48)
                                    } else {
                                        Text(isFollowingCurrentFestivalBrand ? LT("已关注", "Following", "フォロー中") : LT("关注", "Follow", "フォロー"))
                                            .lineLimit(1)
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(
                                            isFollowingCurrentFestivalBrand
                                            ? Color(red: 0.2, green: 0.56, blue: 0.98).opacity(0.45)
                                            : Color(red: 0.2, green: 0.56, blue: 0.98)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingFollowedBrandPreference || isTogglingBrandFollow)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(height: 360)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            guard backgroundURL != nil else { return }
            selectedHeroMedia = FullscreenMediaSelection(id: 0)
        }
        .zIndex(1)
    }

    @ViewBuilder
    private func tabContent(_ tab: LearnFestivalDetailTab) -> some View {
        switch tab {
        case .basic:
            basicInfoTabContent
        case .events:
            eventsTabContent
        case .posts:
            postsTabContent
        }
    }

    private func festivalTabLoadPlaceholder(
        title: String,
        didFail: Bool,
        retry: @escaping () async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if didFail {
                Text(LT("加载失败，请稍后重试", "Load failed. Please try again.", "読み込みに失敗しました。再試行してください"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                Button {
                    Task { await retry() }
                } label: {
                    Text(LT("重试", "Retry", "再試行"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(RaverTheme.card)
                        )
                }
                .buttonStyle(.plain)
            } else {
                ProgressView(title)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var basicInfoTabContent: some View {
        LearnExpandableText(text: currentFestival.introduction, collapsedLineLimit: 6)

        VStack(alignment: .leading, spacing: 10) {
            LearnMetadataInfoRow(title: LT("国家", "Country", "国"), value: currentFestival.country)
            LearnMetadataInfoRow(title: LT("城市", "City", "都市"), value: currentFestival.city)
            LearnMetadataInfoRow(title: LT("首办时间", "Founded Year", "初開催年"), value: currentFestival.foundedYear)
            LearnMetadataInfoRow(title: LT("举办频次", "Frequency", "開催頻度"), value: currentFestival.frequency)
            LearnMetadataInfoRow(title: LT("定位", "Tagline", "タグライン"), value: currentFestival.tagline)
        }

        linksSection
        contributorSection
    }

    @ViewBuilder
    private var eventsTabContent: some View {
        DiscoverStandardEventFeedTab(
            primaryActionTitle: LT("发布新活动", "发布新活动", "新しいイベントを公開"),
            primaryActionAction: { discoverPush(.eventCreate) },
            isLoading: isLoadingRelatedContent && upcomingRelatedEvents.isEmpty && endedRelatedEvents.isEmpty,
            didLoad: didLoadRelatedEvents,
            didFail: relatedEventsLoadFailed,
            loadingTitle: LT("正在加载关联活动...", "正在加载关联活动...", "関連イベントを読み込み中..."),
            emptyTitle: LT("暂无关联活动", "暂无关联活动", "関連イベントはまだありません"),
            retry: { await loadRelatedEventsIfNeeded(force: true) },
            sections: [
                DiscoverEventFeedSectionConfig(
                    title: LT("即将开始", "Upcoming", "近日開催"),
                    events: upcomingRelatedEvents,
                    hasMore: hasMoreUpcomingRelatedEvents,
                    isLoadingMore: isLoadingMoreUpcomingRelatedEvents,
                    onLoadMore: { await loadMoreRelatedEvents(section: .upcoming) }
                ),
                DiscoverEventFeedSectionConfig(
                    title: LT("已结束活动", "Ended", "終了済み"),
                    events: endedRelatedEvents,
                    hasMore: hasMoreEndedRelatedEvents,
                    isLoadingMore: isLoadingMoreEndedRelatedEvents,
                    onLoadMore: { await loadMoreRelatedEvents(section: .ended) }
                )
            ],
            onOpenEvent: { event in
                appPush(.eventDetail(eventID: event.id))
            }
        )
    }

    @ViewBuilder
    private var postsTabContent: some View {
        if (isLoadingRelatedContent || isLoadingRelatedArticles) && relatedArticles.isEmpty {
            ProgressView(LT("正在加载品牌动态...", "正在加载品牌动态...", "ブランド投稿を読み込み中..."))
                .padding(.vertical, 8)
        } else if relatedArticles.isEmpty && !didLoadRelatedArticles {
            festivalTabLoadPlaceholder(
                title: LT("正在加载品牌动态...", "正在加载品牌动态...", "ブランド投稿を読み込み中..."),
                didFail: relatedArticlesLoadFailed,
                retry: { await loadRelatedArticlesIfNeeded(force: true) }
            )
        } else if relatedArticles.isEmpty {
            Text(LT("暂无相关动态", "暂无相关动态", "関連投稿はまだありません"))
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            let visibleArticles = Array(relatedArticles.prefix(visibleRelatedArticleCount))
            ForEach(Array(visibleArticles.enumerated()), id: \.element.id) { index, article in
                Button {
                    discoverPush(.newsDetail(articleID: article.id))
                } label: {
                    DiscoverNewsRow(article: article, showsSummary: false)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                if index < visibleArticles.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }

            festivalLoadMoreButton(
                hasMore: visibleArticles.count < relatedArticles.count,
                isLoadingMore: false,
                title: LT("加载更多动态", "Load More Posts", "投稿をさらに表示")
            ) {
                visibleRelatedArticleCount += 5
            }
        }
    }

    @ViewBuilder
    private func festivalLoadMoreButton(
        hasMore: Bool,
        isLoadingMore: Bool,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        DiscoverSectionLoadMoreButton(
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
            title: title,
            action: action
        )
    }

    @ViewBuilder
    private var headerAvatar: some View {
        if let url = destinationURL(currentFestival.avatarUrl) {
            fallbackAvatar
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackAvatar
        }
    }

    @ViewBuilder
    private var linksSection: some View {
        let validLinks = currentFestival.links.compactMap { link -> (String, String, URL)? in
            guard let url = destinationURL(link.url) else { return nil }
            return (link.icon, link.title, url)
        }
        if !validLinks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(LT("Links", "Links", "リンク"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                ForEach(validLinks, id: \.2.absoluteString) { item in
                    LearnExternalLinkRow(icon: item.0, title: item.1, url: item.2)
                }
            }
        }
    }

    @ViewBuilder
    private var contributorSection: some View {
        let users = currentFestival.contributors.filter { !$0.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !users.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(LT("贡献者", "贡献者", "コントリビューター"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(users) { user in
                        Button {
                            Task { await openContributorProfile(user) }
                        } label: {
                            HStack(spacing: 10) {
                                contributorUserAvatar(user, size: 30)
                                Text(contributorDisplayName(user))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contributorUserAvatar(_ user: WebUserLite, size: CGFloat) -> some View {
        if let avatar = AppConfig.resolvedURLString(user.avatarUrl) {
            ImageLoaderView(urlString: avatar)
                .background(Circle().fill(RaverTheme.card))
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.card)
                .frame(width: size, height: size)
                .overlay(
                    Text(initials(of: contributorDisplayName(user)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        }
    }

    private func contributorDisplayName(_ user: WebUserLite) -> String {
        let trimmed = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? LT("未设置昵称", "No nickname set", "ニックネーム未設定") : trimmed
    }

    @MainActor
    private func openContributorProfile(_ contributor: WebUserLite) async {
        if let resolved = await resolveFestivalContributorUser(contributor) {
            if let index = currentFestival.contributors.firstIndex(where: {
                $0.id == contributor.id && $0.username.caseInsensitiveCompare(contributor.username) == .orderedSame
            }) {
                currentFestival.contributors[index] = resolved
                onFestivalUpdated?(currentFestival)
            }
            appPush(.userProfile(userID: resolved.id))
            return
        }
        errorMessage = LT("未找到对应用户主页", "Matched user profile not found.", "対応するユーザープロフィールが見つかりません。")
    }

    @MainActor
    private func hydrateFestivalContributorsIfNeeded() async {
        guard !currentFestival.contributors.isEmpty else { return }

        var updated = currentFestival
        var didChange = false

        for index in updated.contributors.indices {
            let contributor = updated.contributors[index]
            guard shouldResolveFestivalContributor(contributor) else { continue }
            guard let resolved = await resolveFestivalContributorUser(contributor) else { continue }
            if resolved != contributor {
                updated.contributors[index] = resolved
                didChange = true
            }
        }

        guard didChange else { return }
        currentFestival = updated
        onFestivalUpdated?(updated)
    }

    private func shouldResolveFestivalContributor(_ contributor: WebUserLite) -> Bool {
        let trimmedID = contributor.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = contributor.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedDisplayName.isEmpty { return true }
        if trimmedID.isEmpty { return true }
        if trimmedID.caseInsensitiveCompare(contributor.username) == .orderedSame { return true }
        return !looksLikeUUID(trimmedID)
    }

    private func looksLikeUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    private func resolveFestivalContributorUser(_ contributor: WebUserLite) async -> WebUserLite? {
        let contributorID = contributor.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !contributorID.isEmpty, let profile = try? await newsRepository.fetchUserProfile(userID: contributorID) {
            return WebUserLite(
                id: profile.id,
                username: profile.username,
                displayName: profile.displayName,
                avatarUrl: profile.avatarURL ?? contributor.avatarUrl
            )
        }

        let queryCandidates = [
            contributor.username.trimmingCharacters(in: .whitespacesAndNewlines),
            contributor.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ]
        .filter { !$0.isEmpty }

        for query in queryCandidates {
            guard let matched = await searchFestivalContributorMatch(
                query: query,
                expectedUsername: contributor.username,
                expectedDisplayName: contributor.displayName
            ) else { continue }
            return WebUserLite(
                id: matched.id,
                username: matched.username,
                displayName: matched.displayName,
                avatarUrl: matched.avatarURL ?? contributor.avatarUrl
            )
        }
        return nil
    }

    private func searchFestivalContributorMatch(
        query: String,
        expectedUsername: String,
        expectedDisplayName: String?
    ) async -> UserSummary? {
        guard let users = try? await newsRepository.searchUsers(query: query), !users.isEmpty else {
            return nil
        }

        let normalizedUsername = expectedUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedUsername.isEmpty,
           let exactUsername = users.first(where: { $0.username.lowercased() == normalizedUsername }) {
            return exactUsername
        }

        let normalizedDisplayName = expectedDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if !normalizedDisplayName.isEmpty,
           let exactDisplayName = users.first(where: { $0.displayName.lowercased() == normalizedDisplayName }) {
            return exactDisplayName
        }

        if users.count == 1 {
            return users[0]
        }
        return nil
    }

    private var canEditFestival: Bool {
        if let canEdit = currentFestival.canEdit {
            return canEdit
        }
        guard let currentUser = currentSessionContributor else { return false }
        return currentFestival.contributors.contains { contributor in
            contributor.id == currentUser.id
                || contributor.username.caseInsensitiveCompare(currentUser.username) == .orderedSame
        }
    }

    private var currentSessionContributor: WebUserLite? {
        guard let user = appState.session?.user else { return nil }
        return WebUserLite(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            avatarUrl: user.avatarURL
        )
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
            Text(String(currentFestival.name.prefix(2)).uppercased())
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private func selectedIndex(for tab: LearnFestivalDetailTab) -> Int {
        LearnFestivalDetailTab.allCases.firstIndex(of: tab) ?? 0
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(currentFestival.avatarUrl) else {
            await MainActor.run {
                avatarLuminance = nil
            }
            return
        }
        let luminance = await LearnAvatarLuminanceStyling.luminance(for: avatarURL)
        await MainActor.run {
            avatarLuminance = luminance
        }
    }

    private func openPreview(urlString: String?, title: String) {
        guard let url = destinationURL(urlString) else { return }
        previewImage = LearnImagePreviewItem(title: title, url: url)
    }

    @MainActor
    private func loadFestivalTabContentIfNeeded(for tab: LearnFestivalDetailTab) async {
        switch tab {
        case .basic:
            return
        case .events:
            await loadRelatedEventsIfNeeded(force: false)
        case .posts:
            await loadRelatedArticlesIfNeeded(force: false)
        }
    }

    private func resetFestivalVisibleCounts(for tab: LearnFestivalDetailTab) {
        switch tab {
        case .basic, .events:
            return
        case .posts:
            visibleRelatedArticleCount = 5
        }
    }

    @MainActor
    private func loadRelatedEventsIfNeeded(force: Bool) async {
        if isLoadingRelatedEvents || (!force && didLoadRelatedEvents) { return }
        isLoadingRelatedEvents = true
        isLoadingRelatedContent = true
        relatedEventsLoadFailed = false
        if force {
            upcomingRelatedEvents = []
            endedRelatedEvents = []
            upcomingRelatedEventsPage = 0
            upcomingRelatedEventsTotalPages = 1
            endedRelatedEventsPage = 0
            endedRelatedEventsTotalPages = 1
            didLoadRelatedEvents = false
        }
        defer {
            isLoadingRelatedEvents = false
            isLoadingRelatedContent = isLoadingRelatedArticles || isLoadingRelatedEvents
        }

        do {
            let feed = try await fetchFestivalEventFeed(upcomingPage: 1, endedPage: 1)
            upcomingRelatedEvents = feed.upcoming.items
            endedRelatedEvents = feed.ended.items
            upcomingRelatedEventsPage = feed.upcoming.pagination?.page ?? 1
            upcomingRelatedEventsTotalPages = max(feed.upcoming.pagination?.totalPages ?? 1, 1)
            endedRelatedEventsPage = feed.ended.pagination?.page ?? 1
            endedRelatedEventsTotalPages = max(feed.ended.pagination?.totalPages ?? 1, 1)
            didLoadRelatedEvents = true
        } catch is CancellationError {
            return
        } catch {
            relatedEventsLoadFailed = true
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func loadRelatedArticlesIfNeeded(force: Bool) async {
        if isLoadingRelatedArticles || (!force && didLoadRelatedArticles) { return }
        isLoadingRelatedArticles = true
        isLoadingRelatedContent = true
        relatedArticlesLoadFailed = false
        defer {
            isLoadingRelatedArticles = false
            isLoadingRelatedContent = isLoadingRelatedArticles || isLoadingRelatedEvents
        }

        do {
            relatedArticles = try await fetchRelatedPosts()
            didLoadRelatedArticles = true
        } catch is CancellationError {
            return
        } catch {
            relatedArticlesLoadFailed = true
            errorMessage = error.userFacingMessage
        }
    }

    private enum FestivalRelatedEventSection {
        case upcoming
        case ended
    }

    @MainActor
    private func loadMoreRelatedEvents(section: FestivalRelatedEventSection) async {
        guard didLoadRelatedEvents else { return }
        guard !isLoadingRelatedEvents else { return }

        switch section {
        case .upcoming:
            guard !isLoadingMoreUpcomingRelatedEvents, hasMoreUpcomingRelatedEvents else { return }
            isLoadingMoreUpcomingRelatedEvents = true
        case .ended:
            guard !isLoadingMoreEndedRelatedEvents, hasMoreEndedRelatedEvents else { return }
            isLoadingMoreEndedRelatedEvents = true
        }
        defer {
            switch section {
            case .upcoming:
                isLoadingMoreUpcomingRelatedEvents = false
            case .ended:
                isLoadingMoreEndedRelatedEvents = false
            }
        }

        do {
            let nextPage: Int
            let status: String
            switch section {
            case .upcoming:
                nextPage = max(upcomingRelatedEventsPage, 0) + 1
                status = "upcoming"
            case .ended:
                nextPage = max(endedRelatedEventsPage, 0) + 1
                status = "ended"
            }

            let page = try await fetchRelatedEvents(page: nextPage, status: status)
            switch section {
            case .upcoming:
                let existingIds = Set(upcomingRelatedEvents.map(\.id))
                upcomingRelatedEvents.append(contentsOf: page.items.filter { !existingIds.contains($0.id) })
                upcomingRelatedEventsPage = page.pagination?.page ?? nextPage
                upcomingRelatedEventsTotalPages = max(page.pagination?.totalPages ?? upcomingRelatedEventsTotalPages, 1)
            case .ended:
                let existingIds = Set(endedRelatedEvents.map(\.id))
                endedRelatedEvents.append(contentsOf: page.items.filter { !existingIds.contains($0.id) })
                endedRelatedEventsPage = page.pagination?.page ?? nextPage
                endedRelatedEventsTotalPages = max(page.pagination?.totalPages ?? endedRelatedEventsTotalPages, 1)
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private var hasMoreUpcomingRelatedEvents: Bool {
        upcomingRelatedEventsPage < upcomingRelatedEventsTotalPages
    }

    private var hasMoreEndedRelatedEvents: Bool {
        endedRelatedEventsPage < endedRelatedEventsTotalPages
    }

    private func fetchFestivalEventFeed(upcomingPage: Int, endedPage: Int) async throws -> FestivalEventFeedResponse {
        let brandID = currentFestival.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brandID.isEmpty else {
            return FestivalEventFeedResponse(
                upcoming: FestivalEventFeedPage(items: [], pagination: nil),
                ended: FestivalEventFeedPage(items: [], pagination: nil)
            )
        }
        return try await eventListRepository.fetchFestivalEventFeed(
            wikiFestivalId: brandID,
            upcomingPage: max(upcomingPage, 1),
            upcomingLimit: 10,
            endedPage: max(endedPage, 1),
            endedLimit: 10
        )
    }

    private func fetchRelatedEvents(page: Int, status: String) async throws -> EventListPage {
        let brandID = currentFestival.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brandID.isEmpty else { return EventListPage(items: [], pagination: nil) }
        let response = try await eventListRepository.fetchEvents(
            request: DiscoverEventsPageRequest(
                page: max(page, 1),
                limit: 10,
                search: nil,
                eventType: nil,
                status: status,
                wikiFestivalId: brandID
            )
        )
        let filtered = response.items.filter(eventMatchesFestival)
        return EventListPage(items: filtered, pagination: response.pagination)
    }

    private func fetchRelatedPosts() async throws -> [DiscoverNewsArticle] {
        let brandID = currentFestival.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brandID.isEmpty else { return [] }
        return try await newsRepository.fetchArticlesBoundToFestival(festivalID: brandID, maxPages: 8)
    }

    private func eventMatchesFestival(_ event: WebEvent) -> Bool {
        let targetBrandID = currentFestival.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetBrandID.isEmpty else { return false }

        if let boundBrandID = event.wikiFestivalId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !boundBrandID.isEmpty,
           boundBrandID == targetBrandID {
            return true
        }
        if let boundBrandID = event.wikiFestival?.id.trimmingCharacters(in: .whitespacesAndNewlines),
           !boundBrandID.isEmpty,
           boundBrandID == targetBrandID {
            return true
        }
        return false
    }

    @MainActor
    private func refreshCurrentFestivalAfterSave() async {
        do {
            let latest = try await wikiRepository.fetchLearnFestival(id: currentFestival.id)
            let hydrated = LearnFestival(web: latest)
            currentFestival = hydrated
            onFestivalUpdated?(hydrated)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
