import AVFoundation
import AVKit
import LinkPresentation
import MapKit
import SwiftUI
import UIKit

struct PostCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState

    let post: Post
    let currentUserId: String?
    let showsFollowButton: Bool
    let showsMoreButton: Bool
    let onLikeTap: () -> Void
    let onRepostTap: (() -> Void)?
    let onSaveTap: (() -> Void)?
    let onHideTap: (() -> Void)?
    let onFollowTap: (() -> Void)?
    let onMessageTap: (() -> Void)?
    let onAuthorTap: (() -> Void)?
    let onSquadTap: (() -> Void)?
    let onEditTap: (() -> Void)?
    let authorAppearance: UserAssetAppearance?
    @State private var isShowingLocationMap = false
    @State private var isSharePanelVisible = false
    @State private var isShowingMoreChatsSheet = false
    @State private var isShowingRealNameSheet = false
    @State private var shareErrorMessage: String?
    @State private var reportTarget: ReportSheetTarget?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    private var postInteractionRepository: PostInteractionRepository {
        appContainer.postInteractionRepository
    }

    private var shareMessageRepository: ShareMessageRepository {
        appContainer.shareMessageRepository
    }

    init(
        post: Post,
        currentUserId: String?,
        showsFollowButton: Bool,
        showsMoreButton: Bool = true,
        onLikeTap: @escaping () -> Void,
        onRepostTap: (() -> Void)?,
        onSaveTap: (() -> Void)? = nil,
        onHideTap: (() -> Void)? = nil,
        onFollowTap: (() -> Void)?,
        onMessageTap: (() -> Void)?,
        onAuthorTap: (() -> Void)?,
        onSquadTap: (() -> Void)?,
        onEditTap: (() -> Void)? = nil,
        authorAppearance: UserAssetAppearance? = nil
    ) {
        self.post = post
        self.currentUserId = currentUserId
        self.showsFollowButton = showsFollowButton
        self.showsMoreButton = showsMoreButton
        self.onLikeTap = onLikeTap
        self.onRepostTap = onRepostTap
        self.onSaveTap = onSaveTap
        self.onHideTap = onHideTap
        self.onFollowTap = onFollowTap
        self.onMessageTap = onMessageTap
        self.onAuthorTap = onAuthorTap
        self.onSquadTap = onSquadTap
        self.onEditTap = onEditTap
        self.authorAppearance = authorAppearance
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Group {
                        if let onAuthorTap {
                            Button(action: onAuthorTap) {
                                authorMeta
                            }
                            .buttonStyle(.plain)
                        } else {
                            authorMeta
                        }
                    }

                    Spacer()

                    if post.author.id == currentUserId, let onEditTap {
                        Button(action: onEditTap) {
                            Image(systemName: "square.and.pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(RaverTheme.card.opacity(0.9))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(LT("编辑动态", "Edit Post", "投稿を編集"))
                    } else if showsFollowButton, let onFollowTap {
                        Button(post.author.isFollowing ? LT("已关注", "Following", "フォロー中") : LT("关注", "Follow", "フォロー"), action: onFollowTap)
                            .font(.caption.bold())
                            .foregroundStyle(post.author.isFollowing ? RaverTheme.secondaryText : Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(post.author.isFollowing ? RaverTheme.card : RaverTheme.accent)
                            .clipShape(Capsule())
                    }
                }

                Text(post.content)
                    .foregroundStyle(RaverTheme.primaryText)
                    .font(.body)

                if let reason = normalizedRecommendationReason {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                        Text(reason)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(RaverTheme.secondaryText)
                }

                if !post.images.isEmpty {
                    PostMediaGridView(mediaURLs: post.images)
                }

                if let locationText = normalizedLocationText {
                    Button {
                        isShowingLocationMap = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption.weight(.semibold))
                            Text(locationText)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(locationLabelTextColor)
                        .frame(maxWidth: locationLabelMaxWidth, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(locationLabelBackgroundColor)
                        .overlay(
                            Capsule()
                                .stroke(locationLabelStrokeColor, lineWidth: 0.8)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 18) {
                    Button(action: onLikeTap) {
                        Label("\(post.likeCount)", systemImage: post.isLiked ? "heart.fill" : "heart")
                    }
                    .foregroundStyle(post.isLiked ? Color.pink : RaverTheme.secondaryText)

                    /*
                    Repost entry is temporarily hidden from post lists and detail cards.
                    Keep this UI code ready because repost icon/data may be enabled again at any time.
                    if let onRepostTap {
                        Button(action: onRepostTap) {
                            Label("\(post.repostCount)", systemImage: post.isReposted ? "arrowshape.turn.up.right.fill" : "arrowshape.turn.up.right")
                        }
                        .foregroundStyle(post.isReposted ? RaverTheme.accent : RaverTheme.secondaryText)
                    }
                    */

                    Label("\(post.commentCount)", systemImage: "text.bubble")
                        .foregroundStyle(RaverTheme.secondaryText)

                    if let onSaveTap {
                        Button(action: onSaveTap) {
                            Label("\(post.saveCount)", systemImage: post.isSaved ? "star.fill" : "star")
                        }
                        .foregroundStyle(post.isSaved ? Color.yellow : RaverTheme.secondaryText)
                    }

                    if post.author.id != currentUserId, let onMessageTap {
                        Button(action: onMessageTap) {
                            Label(LT("私信", "私信", "DM"), systemImage: "paperplane")
                        }
                        .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if post.squad != nil, let onSquadTap {
                        Button(action: onSquadTap) {
                            Label(LT("进小队", "进小队", "Squadへ"), systemImage: "person.3")
                        }
                        .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if showsMoreButton {
                        Button {
                            guard requireRealNameForSocialAction() else { return }
                            withAnimation(.sharePanelPresentSpring) {
                                isSharePanelVisible = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(RaverTheme.card.opacity(0.001)))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(RaverTheme.secondaryText)
                    }

                    Spacer()
                }
                .font(.subheadline)

                if let squad = post.squad {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                            .font(.caption)
                        Text(squad.name)
                            .font(.caption)
                    }
                    .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingLocationMap) {
            if let locationText = normalizedLocationText {
                PostLocationMapView(locationText: locationText)
            }
        }
        .overlay {
            if isSharePanelVisible {
                SharePanelOverlay(
                    isVisible: isSharePanelVisible,
                    onBackdropTap: dismissSharePanel,
                    bottomPadding: 12,
                    hiddenOffset: 340
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareQuickActions(),
                        loadConversations: {
                            try requireRealNameForThrowingSocialAction()
                            return try await loadSharePanelConversations()
                        },
                        onSendToConversation: { conversation, note in
                            try requireRealNameForThrowingSocialAction()
                            try await sendPostSharePayload(to: conversation, note: note)
                        },
                        onDismiss: dismissSharePanel,
                        onConversationShared: { _ in },
                        onMoreChats: {
                            isShowingMoreChatsSheet = true
                        }
                    )
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingMoreChatsSheet) {
            ChatShareSheet(
                loadConversations: {
                    try requireRealNameForThrowingSocialAction()
                    return try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try requireRealNameForThrowingSocialAction()
                    try await sendPostSharePayload(to: conversation, note: nil)
                }
            ) { _ in
                isShowingMoreChatsSheet = false
            } preview: {
                PostSharePreviewCard(payload: PostSharePayload(post: post))
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(isPresented: $isShowingRealNameSheet) {
            RealNameVerificationSheet()
                .presentationDetents([.medium])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, blocked in
                OperationBannerCenter.shared.success(
                    blocked
                        ? LT("举报已提交，并已拉黑该用户", "Report submitted and user blocked", "報告を送信し、このユーザーをブロックしました")
                        : LT("举报已提交", "Report submitted", "報告を送信しました")
                )
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { shareErrorMessage != nil },
            set: { if !$0 { shareErrorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    private var normalizedLocationText: String? {
        let trimmed = post.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var normalizedRecommendationReason: String? {
        let trimmed = post.recommendationReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var locationLabelMaxWidth: CGFloat {
        max(150, min(UIScreen.main.bounds.width * 0.48, 210))
    }

    private var locationLabelBackgroundColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.36)
            : Color(red: 0.90, green: 0.94, blue: 0.98)
    }

    private var locationLabelTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.94)
            : Color.black.opacity(0.78)
    }

    private var locationLabelStrokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.08)
    }

    private var authorMeta: some View {
        HStack(alignment: .center, spacing: 10) {
            // 头像
            authorAvatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(post.author.displayName)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    if let titleMedal = authorAppearance?.titleMedal {
                        VirtualAssetTitleMedalView(asset: titleMedal, compact: true, maxWidth: 92)
                    } else if let badge = authorAppearance?.profileBadges.first {
                        VirtualAssetBadgeView(asset: badge, compact: true, showTitle: false)
                    }
                }
                Text(post.createdAt.feedTimeText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var authorAvatar: some View {
        VirtualAssetAvatarView(size: 34, avatarFrame: authorAppearance?.avatarFrame) {
            if let resolved = AppConfig.resolvedURLString(post.author.avatarURL),
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
               URL(string: resolved) != nil {
                ImageLoaderView(urlString: resolved)
                    .background(authorAvatarFallback)
                    .frame(width: 34, height: 34)
            } else {
                authorAvatarFallback
            }
        }
    }

    private var authorAvatarFallback: some View {
        AvatarPlaceholderView(size: 34, backgroundColor: RaverTheme.card)
    }

    private func dismissSharePanel() {
        withAnimation(.sharePanelDismissSpring) {
            isSharePanelVisible = false
        }
    }

    private func requireRealNameForSocialAction() -> Bool {
        guard appState.canUseSocialFeatures else {
            shareErrorMessage = appState.socialFeatureUnavailableMessage
            if appState.session != nil {
                isShowingRealNameSheet = true
            }
            return false
        }
        return true
    }

    private func requireRealNameForThrowingSocialAction() throws {
        guard appState.canUseSocialFeatures else {
            if appState.session != nil {
                isShowingRealNameSheet = true
            }
            throw ServiceError.message(appState.socialFeatureUnavailableMessage)
        }
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = shareMessageRepository.fetchConversations(type: .direct)
        async let groups = shareMessageRepository.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendPostSharePayload(to conversation: Conversation, note: String?) async throws {
        _ = try await shareMessageRepository.sendPostCardMessage(
            conversationID: conversation.id,
            payload: PostSharePayload(post: post).cardPayload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await shareMessageRepository.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }

        _ = try? await postInteractionRepository.recordShare(postID: post.id, channel: "in_app_chat", status: "completed")
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                shareErrorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                shareErrorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ共有連携は未接続です。")
            }
        ]
    }

    private func shareQuickActions() -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = [
            SharePanelQuickAction(
                title: LT("复制链接", "Copy Link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                Task { await copyPostShareLink() }
            },
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                Task { await openPostQRCode() }
            },
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openPostPoster() }
            },
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "海報を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                Task { await savePostPoster() }
            }
        ]

        if let onHideTap {
            actions.append(
                SharePanelQuickAction(
                    title: LT("不感兴趣", "Not Interested", "興味なし"),
                    systemImage: "eye.slash",
                    accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
                ) {
                    onHideTap()
                }
            )
        }
        actions.append(
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.93, green: 0.39, blue: 0.24)
            ) {
                reportTarget = ReportSheetTarget(
                    id: post.id,
                    type: .post,
                    title: post.author.displayName,
                    preview: post.content,
                    targetUserID: post.author.id,
                    targetUserDisplayName: post.author.displayName
                )
            }
        )
        return actions
    }

    @MainActor
    private func copyPostShareLink() async {
        do {
            let result = try await shareLinkCoordinator.copyLink(
                target: ShareTarget(
                    type: .post,
                    id: post.id,
                    title: PostSharePayload(post: post).shareTitle,
                    subtitle: PostSharePayload(post: post).shareSummary,
                    imageURL: post.images.first
                )
            )

            if result.usedDeepLinkFallback {
                shareErrorMessage = LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
            } else {
                OperationBannerCenter.shared.success(LT("已复制链接", "Link copied", "リンクをコピーしました"))
            }
        } catch {
            shareErrorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openPostQRCode() async {
        let payload = PostSharePayload(post: post)
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(
                target: ShareTarget(
                    type: .post,
                    id: post.id,
                    title: payload.shareTitle,
                    subtitle: payload.shareSummary,
                    imageURL: post.images.first
                ),
                channel: "view_qr"
            )
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
            shareErrorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openPostPoster() async {
        let payload = PostSharePayload(post: post)
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(
                target: ShareTarget(
                    type: .post,
                    id: post.id,
                    title: payload.shareTitle,
                    subtitle: payload.shareSummary,
                    imageURL: post.images.first
                ),
                channel: "view_poster"
            )
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
                        hintText: LT("动态海报由分享系统统一生成，内容封面、摘要和二维码都会跟随短链一起更新。", "Post posters are generated by the share system, so the cover, summary, and QR code stay aligned with the short link.", "投稿海報は共有システムで生成され、カバー、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            shareErrorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func savePostPoster() async {
        let payload = PostSharePayload(post: post)
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(
                target: ShareTarget(
                    type: .post,
                    id: post.id,
                    title: payload.shareTitle,
                    subtitle: payload.shareSummary,
                    imageURL: post.images.first
                ),
                channel: "poster_save"
            )
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            OperationBannerCenter.shared.success(LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            shareErrorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }
}

private struct PostLocationMapView: View {
    @Environment(\.dismiss) private var dismiss

    let locationText: String

    @State private var mapPosition: MapCameraPosition
    @State private var resolvedCoordinate: CLLocationCoordinate2D?
    @State private var isResolving = false
    @State private var resolveFailed = false
    @State private var availableMapApps: [ExternalMapApp] = []
    @State private var showMapAppPicker = false

    private enum ExternalMapApp: String, CaseIterable, Identifiable {
        case apple
        case amap
        case baidu
        case tencent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .apple: return LT("Apple 地图", "Apple Maps", "Appleマップ")
            case .amap: return LT("高德地图", "Amap", "高徳地図")
            case .baidu: return LT("百度地图", "Baidu Maps", "Baiduマップ")
            case .tencent: return LT("腾讯地图", "Tencent Maps", "Tencentマップ")
            }
        }
    }

    init(locationText: String) {
        self.locationText = locationText
        let fallback = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        _mapPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: fallback,
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $mapPosition, interactionModes: .all) {
                    if let resolvedCoordinate {
                        Marker(locationText, coordinate: resolvedCoordinate)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .bottom)

                VStack(alignment: .leading, spacing: 8) {
                    Text(LT("定位信息", "定位信息", "位置情報"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(locationText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    if isResolving {
                        ProgressView(LT("正在解析位置…", "正在解析位置…", "位置を解析中…"))
                            .font(.caption)
                            .tint(RaverTheme.secondaryText)
                    } else if resolveFailed {
                        Text(LT("未能精确定位，仍可在地图中拖动查看区域。", "未能精确定位，仍可在地图中拖动查看区域。", "正確な位置を特定できませんでした。地図をドラッグしてエリアを確認できます。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    Button {
                        refreshAvailableMapApps()
                        if !availableMapApps.isEmpty {
                            showMapAppPicker = true
                        }
                    } label: {
                        Label(LT("打开地图App", "打开地图App", "地図アプリを開く"), systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RaverTheme.accent)
                    .disabled(availableMapApps.isEmpty)
                    .opacity(availableMapApps.isEmpty ? 0.65 : 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .raverSystemNavigation(title: LT("位置地图", "位置地图", "位置地図"))
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
            .confirmationDialog(LT("选择地图应用", "Choose Map App", "地図アプリを選択"), isPresented: $showMapAppPicker, titleVisibility: .visible) {
                ForEach(availableMapApps) { app in
                    Button(app.title) {
                        openExternalMap(app)
                    }
                }
                Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
            }
            .task {
                refreshAvailableMapApps()
                await resolveLocation()
            }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
    }

    @MainActor
    private func resolveLocation() async {
        guard !isResolving else { return }
        isResolving = true
        defer { isResolving = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationText
        request.resultTypes = [.address, .pointOfInterest]
        do {
            let response = try await MKLocalSearch(request: request).start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                resolvedCoordinate = coordinate
                resolveFailed = false
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                )
                refreshAvailableMapApps()
                return
            }
            resolveFailed = true
            refreshAvailableMapApps()
        } catch {
            resolveFailed = true
            refreshAvailableMapApps()
        }
    }

    private func refreshAvailableMapApps() {
        let app = UIApplication.shared
        var result: [ExternalMapApp] = [.apple]
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
        UIApplication.shared.open(url)
    }

    private func externalMapURL(for app: ExternalMapApp) -> URL? {
        let query = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch app {
        case .apple:
            if let resolvedCoordinate {
                let placemark = MKPlacemark(coordinate: resolvedCoordinate)
                let item = MKMapItem(placemark: placemark)
                item.name = locationText
                return item.url
            }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            return URL(string: "http://maps.apple.com/?q=\(encoded)")
        case .amap:
            if let resolvedCoordinate {
                var components = URLComponents()
                components.scheme = "iosamap"
                components.host = "viewMap"
                components.queryItems = [
                    URLQueryItem(name: "sourceApplication", value: "RaveHub"),
                    URLQueryItem(name: "poiname", value: locationText),
                    URLQueryItem(name: "lat", value: "\(resolvedCoordinate.latitude)"),
                    URLQueryItem(name: "lon", value: "\(resolvedCoordinate.longitude)"),
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
            if let resolvedCoordinate {
                var components = URLComponents()
                components.scheme = "baidumap"
                components.host = "map"
                components.path = "/marker"
                components.queryItems = [
                    URLQueryItem(name: "location", value: "\(resolvedCoordinate.latitude),\(resolvedCoordinate.longitude)"),
                    URLQueryItem(name: "title", value: locationText),
                    URLQueryItem(name: "content", value: query.isEmpty ? locationText : query),
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
                URLQueryItem(name: "referer", value: "RaveHub"),
                URLQueryItem(name: "keyword", value: query.isEmpty ? locationText : query)
            ]
            if let resolvedCoordinate {
                items.append(URLQueryItem(name: "center", value: "\(resolvedCoordinate.latitude),\(resolvedCoordinate.longitude)"))
            }
            components.queryItems = items
            return components.url
        }
    }
}

struct PostMediaGridView: View {
    let mediaURLs: [String]
    var allowsFullscreen: Bool = true

    @State private var selectedMedia: FullscreenMediaSelection?
    @State private var singleImageAspectRatioByID: [String: CGFloat] = [:]
    @State private var singleImageContainerWidth: CGFloat = max(UIScreen.main.bounds.width - 64, 1)

    private var items: [FullscreenMediaItem] {
        mediaURLs
            .enumerated()
            .compactMap { offset, raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return FullscreenMediaItem(rawURL: trimmed, index: offset)
            }
    }

    var body: some View {
        Group {
            if items.count == 1, let first = items.first {
                mediaTapWrapper(index: 0) {
                    singleMediaView(first)
                }
            } else if !items.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        mediaTapWrapper(index: index) {
                            mediaThumbnail(item)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedMedia) { selection in
            FullscreenMediaViewer(items: items, initialIndex: selection.id)
        }
    }

    @ViewBuilder
    private func mediaTapWrapper<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        if allowsFullscreen {
            Button {
                selectedMedia = FullscreenMediaSelection(id: index)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    private func singleMediaView(_ item: FullscreenMediaItem) -> some View {
        let width = max(singleImageContainerWidth, 1)
        let maxHeight = width * 1.5
        let naturalHeight = singleImageAspectRatio(for: item).map { width / max($0, 0.0001) }
        let isOverflowing = (naturalHeight ?? maxHeight) > maxHeight
        let targetHeight = min(naturalHeight ?? width, maxHeight)

        return ZStack {
            if item.isVideo {
                if let url = item.url {
                    PostVideoThumbnailView(url: url, contentMode: .fill)
                        .overlay {
                            LinearGradient(
                                colors: [Color.black.opacity(0.18), Color.black.opacity(0.42)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 42, weight: .semibold))
                                    .foregroundStyle(.white)
                                PostVideoDurationLabel(url: url, font: .subheadline)
                            }
                        }
                        .frame(height: 230)
                } else {
                    mediaPlaceholder
                        .frame(height: 230)
                }
            } else {
                ImageLoaderView(
                    urlString: item.url?.absoluteString,
                    resizingMode: isOverflowing ? .fill : .fit,
                    onImageLoaded: { imageSize in
                        guard imageSize.width > 0, imageSize.height > 0 else { return }
                        let ratio = imageSize.width / imageSize.height
                        let old = singleImageAspectRatioByID[item.id]
                        if old == nil || abs((old ?? ratio) - ratio) > 0.001 {
                            singleImageAspectRatioByID[item.id] = ratio
                        }
                    }
                )
                    .background(mediaPlaceholder.frame(height: 200))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(targetHeight, 1))
                    .background(Color.black.opacity(0.06))
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    updateSingleImageContainerWidth(geo.size.width)
                                }
                                .onChange(of: geo.size.width) { _, newValue in
                                    updateSingleImageContainerWidth(newValue)
                                }
                        }
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func singleImageAspectRatio(for item: FullscreenMediaItem) -> CGFloat? {
        singleImageAspectRatioByID[item.id]
    }

    private func updateSingleImageContainerWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0 else { return }
        if abs(singleImageContainerWidth - width) > 0.5 {
            singleImageContainerWidth = width
        }
    }

    private func mediaThumbnail(_ item: FullscreenMediaItem) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ZStack {
                    if item.isVideo {
                        if let url = item.url {
                            PostVideoThumbnailView(url: url, contentMode: .fill)
                                .overlay {
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.2), Color.black.opacity(0.44)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                                .overlay {
                                    VStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(.white)
                                        PostVideoDurationLabel(url: url, font: .caption2)
                                    }
                                }
                        } else {
                            mediaPlaceholder
                        }
                    } else {
                        ImageLoaderView(urlString: item.url?.absoluteString)
                            .background(mediaPlaceholder)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var mediaPlaceholder: some View {
        ZStack {
            RaverTheme.card
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }
}

private enum PostVideoThumbnailGenerator {
    static func makeThumbnail(from url: URL, maxLength: CGFloat = 1200) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxLength, height: maxLength)

            let candidateTimes = [
                CMTime(seconds: 0.15, preferredTimescale: 600),
                CMTime(seconds: 0.5, preferredTimescale: 600),
                CMTime(seconds: 1.0, preferredTimescale: 600),
                CMTime(seconds: 2.0, preferredTimescale: 600)
            ]

            for time in candidateTimes {
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    return UIImage(cgImage: cgImage)
                }
            }
            return nil
        }.value
    }
}

private final class PostVideoThumbnailCache {
    static let shared = NSCache<NSString, UIImage>()
}

private final class PostVideoDurationCache {
    static let shared = NSCache<NSString, NSString>()
}

private enum PostVideoDebugLogger {
    static func log(_ message: String) {
        #if DEBUG
        print("[PostVideoDuration] \(message)")
        #endif
    }
}

private enum PostVideoDurationLoader {
    static func loadText(from url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            PostVideoDebugLogger.log("start loading duration: \(url.absoluteString)")

            do {
                let duration = try await asset.load(.duration)
                let isPlayable = (try? await asset.load(.isPlayable)) ?? false

                guard duration.isValid else {
                    PostVideoDebugLogger.log("duration invalid. url=\(url.absoluteString), isPlayable=\(isPlayable)")
                    return nil
                }
                guard !duration.isIndefinite else {
                    PostVideoDebugLogger.log("duration indefinite. url=\(url.absoluteString), isPlayable=\(isPlayable)")
                    return nil
                }

                let seconds = duration.seconds
                guard seconds.isFinite, !seconds.isNaN, seconds > 0 else {
                    PostVideoDebugLogger.log(
                        "duration seconds not usable. url=\(url.absoluteString), seconds=\(seconds), isPlayable=\(isPlayable)"
                    )
                    return nil
                }

                let formatted = formatDuration(totalSeconds: Int(seconds.rounded()))
                PostVideoDebugLogger.log(
                    "duration loaded success. url=\(url.absoluteString), seconds=\(seconds), text=\(formatted), isPlayable=\(isPlayable)"
                )
                return formatted
            } catch {
                PostVideoDebugLogger.log("duration load failed. url=\(url.absoluteString), error=\(error.userFacingMessage ?? "")")
                return nil
            }
        }.value
    }

    private static func formatDuration(totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct PostVideoDurationLabel: View {
    let url: URL
    let font: Font

    @State private var durationText: String?

    var body: some View {
        ZStack {
            if let durationText {
                Text(durationText)
                    .font(font.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.45), radius: 2, x: 0, y: 1)
            }
        }
        .task(id: url.absoluteString) {
            await loadDurationIfNeeded()
        }
    }

    @MainActor
    private func loadDurationIfNeeded() async {
        if durationText != nil { return }

        let key = url.absoluteString as NSString
        if let cached = PostVideoDurationCache.shared.object(forKey: key) {
            durationText = cached as String
            PostVideoDebugLogger.log("duration cache hit. url=\(url.absoluteString), text=\(durationText ?? "")")
            return
        }

        guard let loaded = await PostVideoDurationLoader.loadText(from: url) else {
            PostVideoDebugLogger.log("duration label not shown because load returned nil. url=\(url.absoluteString)")
            return
        }
        PostVideoDurationCache.shared.setObject(loaded as NSString, forKey: key)
        durationText = loaded
        PostVideoDebugLogger.log("duration label updated. url=\(url.absoluteString), text=\(loaded)")
    }
}

private struct PostVideoThumbnailView: View {
    let url: URL
    let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.92), Color.black.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: didFail ? "video.slash.fill" : "video.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
        .task(id: url.absoluteString) {
            await loadThumbnailIfNeeded()
        }
    }

    @MainActor
    private func loadThumbnailIfNeeded() async {
        if image != nil || didFail { return }
        let cacheKey = url.absoluteString as NSString
        if let cached = PostVideoThumbnailCache.shared.object(forKey: cacheKey) {
            image = cached
            return
        }
        guard let generated = await PostVideoThumbnailGenerator.makeThumbnail(from: url) else {
            didFail = true
            return
        }
        PostVideoThumbnailCache.shared.setObject(generated, forKey: cacheKey)
        image = generated
    }
}

struct PostSharePayload: Identifiable {
    let id: String
    let post: Post

    init(post: Post) {
        self.id = post.id
        self.post = post
    }

    var shareSummary: String {
        let trimmed = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return LT("来自 Raver 的动态", "A post from Raver", "Raverからの投稿")
        }
        return String(trimmed.prefix(90))
    }

    var shareTitle: String {
        "\(post.author.displayName) · \(LT("Raver 动态", "Raver Post", "Raver投稿"))"
    }

    var shareURLString: String {
        "https://ravehub.top/posts/\(post.id)"
    }

    var shareURL: URL {
        URL(string: shareURLString) ?? URL(string: "https://ravehub.top")!
    }

    var firstMedia: FullscreenMediaItem? {
        guard let first = post.images.first?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty else {
            return nil
        }
        return FullscreenMediaItem(rawURL: first, index: 0)
    }

    var cardPayload: PostShareCardPayload {
        let firstURL = firstMedia?.url?.absoluteString
        let hasVideo = firstMedia?.isVideo ?? false
        return PostShareCardPayload(
            postID: post.id,
            authorID: post.author.id,
            authorDisplayName: post.author.displayName,
            authorUsername: post.author.username,
            contentText: post.content,
            coverImageURL: firstURL,
            hasVideo: hasVideo,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
            shareCount: post.shareCount,
            badgeText: LT("Post", "Post", "投稿")
        )
    }
}

struct PostInAppShareSheet: View {
    @Environment(\.dismiss) private var dismiss

    let payload: PostSharePayload
    let onRecordShare: (_ channel: String) -> Void

    @State private var isShowingSystemShare = false
    @State private var feedbackText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(RaverTheme.secondaryText.opacity(0.35))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            HStack(spacing: 10) {
                Text(LT("分享动态", "Share Post", "投稿を共有"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(RaverTheme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            PostSharePreviewCard(payload: payload)

            HStack(spacing: 18) {
                PostShareActionButton(
                    title: LT("系统分享", "System Share", "システム共有"),
                    icon: "square.and.arrow.up"
                ) {
                    isShowingSystemShare = true
                }

                PostShareActionButton(
                    title: LT("复制链接", "Copy Link", "リンクをコピー"),
                    icon: "link"
                ) {
                    UIPasteboard.general.string = payload.shareURLString
                    feedbackText = LT("链接已复制", "Link copied", "リンクをコピーしました")
                    onRecordShare("copy_link")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        dismiss()
                    }
                }

                Spacer()
            }

            if let feedbackText {
                Text(feedbackText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(RaverTheme.background)
        .presentationDetents([.height(350), .medium])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $isShowingSystemShare) {
            PostSystemActivityShareSheet(payload: payload) { activityType, completed, _, _ in
                guard completed else { return }
                let channel = activityType?.rawValue ?? "system"
                onRecordShare(channel)
                dismiss()
            }
        }
    }
}

private struct PostShareActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(width: 48, height: 48)
                    .background(RaverTheme.card)
                    .clipShape(Circle())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }
}

struct PostSharePreviewCard: View {
    let payload: PostSharePayload

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            mediaPreview
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(payload.post.author.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)

                Text(payload.shareSummary)
                    .font(.footnote)
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Label("\(payload.post.likeCount)", systemImage: "heart")
                    Label("\(payload.post.commentCount)", systemImage: "text.bubble")
                    Label("\(payload.post.shareCount)", systemImage: "square.and.arrow.up")
                }
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var mediaPreview: some View {
        if let item = payload.firstMedia {
            if item.isVideo, let url = item.url {
                ZStack {
                    PostVideoThumbnailView(url: url, contentMode: .fill)
                    Image(systemName: "play.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.45), radius: 2, x: 0, y: 1)
                }
            } else {
                ImageLoaderView(urlString: item.url?.absoluteString)
                    .background(RaverTheme.card)
            }
        } else {
            ZStack {
                RaverTheme.card
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }
}

private struct PostSystemActivityShareSheet: UIViewControllerRepresentable {
    let payload: PostSharePayload
    var completion: UIActivityViewController.CompletionWithItemsHandler?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemSource = PostShareActivityItemSource(payload: payload)
        let controller = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
        controller.completionWithItemsHandler = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class PostShareActivityItemSource: NSObject, UIActivityItemSource {
    private let payload: PostSharePayload

    init(payload: PostSharePayload) {
        self.payload = payload
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        payload.shareURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        payload.shareURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        payload.shareTitle
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = payload.shareSummary
        metadata.originalURL = payload.shareURL
        metadata.url = payload.shareURL

        if let previewImage = PostShareMetadataCardRenderer.makeImage(payload: payload) {
            let provider = NSItemProvider(object: previewImage)
            metadata.imageProvider = provider
            metadata.iconProvider = provider
        }
        return metadata
    }
}

private enum PostShareMetadataCardRenderer {
    static func makeImage(payload: PostSharePayload) -> UIImage? {
        let size = CGSize(width: 960, height: 520)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1).setFill()
            cg.fill(bounds)

            let cardRect = bounds.insetBy(dx: 44, dy: 44)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 28)
            UIColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1).setFill()
            cardPath.fill()

            let titleRect = CGRect(x: cardRect.minX + 34, y: cardRect.minY + 34, width: cardRect.width - 68, height: 170)
            let bodyStyle = NSMutableParagraphStyle()
            bodyStyle.lineBreakMode = .byTruncatingTail
            bodyStyle.maximumLineHeight = 58
            bodyStyle.minimumLineHeight = 58
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 50, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: bodyStyle
            ]
            NSString(string: payload.shareSummary).draw(with: titleRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: titleAttrs, context: nil)

            let authorRect = CGRect(x: cardRect.minX + 34, y: cardRect.maxY - 120, width: cardRect.width - 68, height: 80)
            let authorAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
                .foregroundColor: UIColor(white: 0.88, alpha: 1)
            ]
            NSString(string: payload.shareTitle).draw(in: authorRect, withAttributes: authorAttrs)
        }
    }
}
