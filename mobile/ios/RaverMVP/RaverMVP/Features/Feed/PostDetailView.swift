import SwiftUI
import UIKit

struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @State private var post: Post
    @StateObject private var appearanceResolver: VirtualAssetListAppearanceResolver
    private let postReadRepository: PostReadRepository
    private let interactionRepository: PostInteractionRepository
    private let commentRepository: PostCommentRepository
    private let eventTrackingRepository: FeedEventTrackingRepository
    private let shareMessageRepository: ShareMessageRepository

    @State private var comments: [Comment] = []
    @State private var commentInput = ""
    @State private var commentsPhase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var bannerMessage: String?
    @State private var error: String?
    @State private var isShowingHideReasonDialog = false
    @State private var isSharePanelVisible = false
    @State private var isSharePanelMounted = false
    @State private var isShowingMoreChatsSheet = false
    @State private var isShowingRealNameSheet = false
    @State private var reportTarget: ReportSheetTarget?
    @State private var replyTargetComment: Comment?
    @State private var commentSortMode: CommentSortMode = .hot
    @State private var visibleRootCount = 0
    @State private var expandedRootCommentIDs: Set<String> = []
    @State private var visibleReplyCountByRoot: [String: Int] = [:]
    @State private var feedSessionID = UUID().uuidString

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    private let rootPageSize = 12
    private let replyPreviewCount = 3
    private let replyPageSize = 6

    init(
        post: Post,
        postReadRepository: PostReadRepository,
        interactionRepository: PostInteractionRepository,
        commentRepository: PostCommentRepository,
        eventTrackingRepository: FeedEventTrackingRepository,
        shareMessageRepository: ShareMessageRepository,
        virtualAssetRepository: VirtualAssetRepository = AppEnvironment.makeVirtualAssetRepository()
    ) {
        self._post = State(initialValue: post)
        self._appearanceResolver = StateObject(
            wrappedValue: VirtualAssetListAppearanceResolver(
                repository: virtualAssetRepository,
                surface: "post_detail"
            )
        )
        self.postReadRepository = postReadRepository
        self.interactionRepository = interactionRepository
        self.commentRepository = commentRepository
        self.eventTrackingRepository = eventTrackingRepository
        self.shareMessageRepository = shareMessageRepository
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if isRefreshing || bannerMessage != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            if isRefreshing {
                                InlineLoadingBadge(title: LT("正在更新动态详情", "Updating post details", "投稿詳細を更新中"))
                            }
                            if let bannerMessage {
                                ScreenStatusBanner(
                                    message: bannerMessage,
                                    style: .error,
                                    actionTitle: LT("重试", "Retry", "再試行")
                                ) {
                                    Task { await loadComments() }
                                }
                            }
                        }
                    }

                    detailPostCard

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text(LT("评论", "Comment", "コメント"))
                                    .font(.headline)
                                Spacer()
                                if !comments.isEmpty {
                                    RaverSegmentedControl(
                                        items: CommentSortMode.allCases,
                                        selection: $commentSortMode,
                                        title: { $0.title },
                                        iconName: commentSortIconName
                                    )
                                    .frame(maxWidth: 190)
                                }
                            }

                            switch commentsPhase {
                            case .idle, .initialLoading:
                                CommentSectionSkeletonView()
                            case .failure(let message), .offline(let message):
                                ScreenErrorCard(
                                    title: LT("评论加载失败", "Comments Failed to Load", "コメントの読み込みに失敗しました"),
                                    message: message
                                ) {
                                    Task { await loadComments() }
                                }
                            case .empty:
                                Text(LT("还没有评论，来抢沙发吧。", "There are no comments yet, be the first to be the first.", "まだコメントはありません。最初にコメントしましょう。"))
                                    .font(.subheadline)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            case .success:
                                LazyVStack(alignment: .leading, spacing: 12) {
                                    ForEach(visibleCommentThreads) { thread in
                                        commentThreadView(thread)
                                            .onAppear {
                                                loadMoreRootCommentsIfNeeded(currentThreadID: thread.id)
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await loadComments()
            }

            Divider()

            VStack(spacing: 8) {
                if let replyTargetComment {
                    HStack(spacing: 8) {
                        Text(
                            LT(
                                "回复 \(replyTargetComment.author.displayName)",
                                "Replying to \(replyTargetComment.author.displayName)",
                                "\(replyTargetComment.author.displayName) に返信中"
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        Spacer()
                        Button {
                            self.replyTargetComment = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                HStack(spacing: 8) {
                    TextField(commentInputPlaceholder, text: $commentInput)
                        .submitLabel(.send)
                        .onSubmit {
                            submitComment()
                        }
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 1, style: .continuous))

                    Button(LT("发送", "Send", "送信")) {
                        submitComment()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            .background(RaverTheme.background)
        }
        .background(RaverTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareToolbarButton
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LT("收起", "Collapse", "閉じる")) {
                    dismissKeyboard()
                }
            }
        }
        .raverSystemNavigation(title: LT("动态详情", "动态详情", "投稿詳細"))
        .task {
            await loadComments()
        }
        .onAppear {
            appearanceResolver.warmAppearances(for: [post.author.id])
        }
        .onChange(of: post.author.id) { _, userID in
            appearanceResolver.warmAppearances(for: [userID])
        }
        .onChange(of: comments) { _, comments in
            appearanceResolver.warmAppearances(for: comments.map(\.author.id))
        }
        .onChange(of: commentSortMode) { _, _ in
            resetRootPaging()
        }
        .overlay { sharePanelOverlay }
        .animation(.sharePanelPresentSpring, value: isSharePanelVisible)
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
                        ? LT("举报已提交，并已拉黑该用户", "Report submitted and user blocked", "通報を送信し、このユーザーをブロックしました")
                        : LT("举报已提交", "Report submitted", "通報を送信しました")
                )
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .confirmationDialog(
            LT("告诉我们原因", "Tell us why", "理由を教えてください"),
            isPresented: $isShowingHideReasonDialog,
            titleVisibility: .visible
        ) {
            ForEach(PostHideReasonOption.allCases) { reason in
                Button(reason.title) {
                    Task { await hidePost(reason: reason.rawValue) }
                }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(LT("我们会据此减少类似内容。", "We'll show fewer similar posts.", "これをもとに類似コンテンツの表示を減らします。"))
        }
        .alert(LT("失败", "fail", "失敗"), isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private var shareToolbarButton: some View {
        Button {
            guard requireRealNameForSocialAction() else { return }
            presentSharePanel()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LT("更多", "More", "その他"))
    }

    @ViewBuilder
    private var sharePanelOverlay: some View {
        if isSharePanelMounted {
            SharePanelOverlay(
                isVisible: isSharePanelVisible,
                onBackdropTap: { dismissSharePanel() },
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
                    onDismiss: {
                        dismissSharePanel()
                    },
                    onConversationShared: { _ in },
                    onMoreChats: {
                        dismissSharePanel {
                            isShowingMoreChatsSheet = true
                        }
                    }
                )
            }
            .onAppear {
                withAnimation(.sharePanelPresentSpring) {
                    isSharePanelVisible = true
                }
            }
            .transition(.opacity)
        }
    }

    private var detailPostCard: some View {
        PostCardView(
            post: post,
            currentUserId: appState.session?.user.id,
            showsFollowButton: true,
            showsMoreButton: false,
            onLikeTap: {
                guard requireRealNameForSocialAction() else { return }
                Task {
                    do {
                        post = try await interactionRepository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
                        notifyPostUpdated()
                        await trackFeedEvent(eventType: "feed_like")
                    } catch {
                        self.error = error.userFacingMessage
                    }
                }
            },
            onRepostTap: {
                guard requireRealNameForSocialAction() else { return }
                Task {
                    do {
                        post = try await interactionRepository.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
                        notifyPostUpdated()
                    } catch {
                        self.error = error.userFacingMessage
                    }
                }
            },
            onSaveTap: {
                guard requireRealNameForSocialAction() else { return }
                Task {
                    do {
                        post = try await interactionRepository.toggleSave(postID: post.id, shouldSave: !post.isSaved)
                        notifyPostUpdated()
                        await trackFeedEvent(eventType: "feed_save")
                    } catch {
                        self.error = error.userFacingMessage
                    }
                }
            },
            onHideTap: nil,
            onFollowTap: {
                guard requireRealNameForSocialAction() else { return }
                Task {
                    do {
                        let author = try await interactionRepository.toggleFollow(userID: post.author.id, shouldFollow: !post.author.isFollowing)
                        post.author = author
                        notifyPostUpdated()
                    } catch {
                        self.error = error.userFacingMessage
                    }
                }
            },
            onMessageTap: nil,
            onAuthorTap: {
                appPush(.userProfile(userID: post.author.id))
            },
            onSquadTap: nil,
            onEditTap: nil,
            authorAppearance: appearanceResolver.appearance(userID: post.author.id)
        )
    }

    private func presentSharePanel() {
        isSharePanelMounted = true
        isSharePanelVisible = false
    }

    private func requireRealNameForSocialAction() -> Bool {
        guard appState.canUseSocialFeatures else {
            error = appState.socialFeatureUnavailableMessage
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

    private func commentSortIconName(_ mode: CommentSortMode) -> String? {
        switch mode {
        case .hot:
            return "flame.fill"
        case .timeline:
            return "clock.fill"
        }
    }

    private func dismissSharePanel(after completion: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isSharePanelVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard !isSharePanelVisible else { return }
            isSharePanelMounted = false
            completion?()
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

        post = try await interactionRepository.recordShare(postID: post.id, channel: "in_app_chat", status: "completed")
        notifyPostUpdated()
        await trackFeedEvent(eventType: "feed_share", metadata: ["channel": "in_app_chat"])
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                error = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat 共有機能はまだ接続されていません。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                error = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ 共有機能はまだ接続されていません。")
            }
        ]
    }

    private func shareQuickActions() -> [SharePanelQuickAction] {
        let payload = PostSharePayload(post: post)
        return [
            SharePanelQuickAction(
                title: LT("复制链接", "Copy Link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                Task { await copyPostShareLink() }
            },
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRコードを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                Task { await openPostQRCode(payload: payload) }
            },
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "ポスターを見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openPostPoster(payload: payload) }
            },
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "ポスターを保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                Task { await savePostPoster(payload: payload) }
            },
            SharePanelQuickAction(
                title: LT("不感兴趣", "Not Interested", "興味がない"),
                systemImage: "eye.slash",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                isShowingHideReasonDialog = true
            },
            SharePanelQuickAction(
                title: LT("举报", "Report", "通報"),
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
        ]
    }

    @MainActor
    private func copyPostShareLink() async {
        do {
            let payload = PostSharePayload(post: post)
            let result = try await shareLinkCoordinator.copyLink(
                target: ShareTarget(
                    type: .post,
                    id: post.id,
                    title: payload.shareTitle,
                    subtitle: payload.shareSummary,
                    imageURL: post.images.first
                )
            )

            if result.usedDeepLinkFallback {
                error = LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
            } else {
                OperationBannerCenter.shared.success(LT("已复制链接", "Link copied", "リンクをコピーしました"))
            }
        } catch {
            self.error = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクのコピーに失敗しました。後でもう一度お試しください。")
        }
    }

    @MainActor
    private func openPostQRCode(payload: PostSharePayload) async {
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
            self.error = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。後でもう一度お試しください。")
        }
    }

    @MainActor
    private func openPostPoster(payload: PostSharePayload) async {
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
                        navigationTitle: LT("分享海报", "Share Poster", "共有ポスター"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "ポスターはまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有ポスターはまだ準備できていません。後でもう一度お試しください。"),
                        hintText: LT("动态海报由分享系统统一生成，内容封面、摘要和二维码都会跟随短链一起更新。", "Post posters are generated by the share system, so the cover, summary, and QR code stay aligned with the short link.", "投稿ポスターは共有システムで生成され、カバー、概要、QRコードは短縮リンクと同期して更新されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "ポスターを保存")
                    )
                )
            )
        } catch {
            self.error = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有ポスターを開けませんでした。後でもう一度お試しください。")
        }
    }

    @MainActor
    private func savePostPoster(payload: PostSharePayload) async {
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
            OperationBannerCenter.shared.success(LT("海报已保存到相册", "Poster saved to Photos", "ポスターを写真に保存しました"))
        } catch {
            self.error = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "ポスターの保存に失敗しました。後でもう一度お試しください。")
        }
    }

    @MainActor
    private func loadComments() async {
        if isLoading { return }
        isLoading = true
        let hadComments = !comments.isEmpty
        if hadComments {
            isRefreshing = true
        } else {
            commentsPhase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            async let postTask = postReadRepository.fetchPost(postID: post.id)
            async let commentsTask = commentRepository.fetchComments(postID: post.id)
            let (loadedPost, loadedComments) = try await (postTask, commentsTask)
            post = loadedPost
            comments = loadedComments
            resetCommentPresentationState()
            commentsPhase = comments.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            if error.isUserInitiatedCancellation {
                return
            }
            let message = error.userFacingMessage ?? LT("评论加载失败，请稍后重试", "Failed to load comments. Please try again later.", "コメントの読み込みに失敗しました。後でもう一度お試しください。")
            if hadComments {
                bannerMessage = message
                commentsPhase = .success
            } else {
                commentsPhase = .failure(message: message)
            }
        }
    }

    @ViewBuilder
    private func commentAvatar(_ user: UserSummary, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           URL(string: resolved) != nil,
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            VirtualAssetAvatarView(size: size, avatarFrame: appearanceResolver.appearance(userID: user.id)?.avatarFrame) {
                ImageLoaderView(urlString: resolved)
                    .background(commentAvatarFallback(user, size: size))
                    .frame(width: size, height: size)
            }
        } else {
            VirtualAssetAvatarView(size: size, avatarFrame: appearanceResolver.appearance(userID: user.id)?.avatarFrame) {
                commentAvatarFallback(user, size: size)
            }
        }
    }

    private func commentAvatarFallback(_ user: UserSummary, size: CGFloat) -> some View {
        AvatarPlaceholderView(size: size, backgroundColor: RaverTheme.card)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func submitComment() {
        guard requireRealNameForSocialAction() else { return }
        Task {
            let text = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            do {
                let comment = try await commentRepository.addComment(
                    postID: post.id,
                    content: text,
                    parentCommentID: replyTargetComment?.id
                )
                comments.append(comment)
                post.commentCount += 1
                updatePresentationStateAfterAppending(comment: comment)
                commentsPhase = .success
                commentInput = ""
                replyTargetComment = nil
                dismissKeyboard()
                notifyPostUpdated()
            } catch {
                self.error = error.userFacingMessage
            }
        }
    }

    private func notifyPostUpdated() {
        NotificationCenter.default.post(name: .circlePostDidUpdate, object: post)
    }

    private var commentInputPlaceholder: String {
        if let replyTargetComment {
            return LT("回复 \\(replyTargetComment.author.displayName)...", "Reply to \\(replyTargetComment.author.displayName)...", "\\(replyTargetComment.author.displayName) に返信...")
        }
        return LT("说点什么...", "Say something...", "何か書いて...")
    }

    private var sortedCommentThreads: [CommentThread] {
        let orderedComments = comments.sorted(by: { $0.createdAt < $1.createdAt })
        let commentByID = Dictionary(uniqueKeysWithValues: orderedComments.map { ($0.id, $0) })
        var rootIDCache: [String: String] = [:]

        func normalizedID(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        func resolveRootID(for commentID: String) -> String? {
            if let cached = rootIDCache[commentID] {
                return cached
            }
            guard let comment = commentByID[commentID] else { return nil }

            if normalizedID(comment.parentCommentID) == nil {
                rootIDCache[commentID] = commentID
                return commentID
            }

            if let explicitRoot = normalizedID(comment.rootCommentID) {
                rootIDCache[commentID] = explicitRoot
                return explicitRoot
            }

            var visited: Set<String> = [commentID]
            var currentParentID = normalizedID(comment.parentCommentID)
            while let parentID = currentParentID, !visited.contains(parentID), let parent = commentByID[parentID] {
                if normalizedID(parent.parentCommentID) == nil {
                    rootIDCache[commentID] = parentID
                    return parentID
                }
                if let explicitRoot = normalizedID(parent.rootCommentID) {
                    rootIDCache[commentID] = explicitRoot
                    return explicitRoot
                }
                visited.insert(parentID)
                currentParentID = normalizedID(parent.parentCommentID)
            }
            return nil
        }

        var roots: [Comment] = []
        var repliesByRoot: [String: [Comment]] = [:]

        for comment in orderedComments {
            guard let rootID = resolveRootID(for: comment.id) else { continue }
            if normalizedID(comment.parentCommentID) == nil || rootID == comment.id {
                roots.append(comment)
            } else {
                repliesByRoot[rootID, default: []].append(comment)
            }
        }

        let threads = roots.map { root -> CommentThread in
            let replies = repliesByRoot[root.id] ?? []
            let lastReplyDate = replies.last?.createdAt ?? root.createdAt
            let ageHours = max(0, Date().timeIntervalSince(lastReplyDate) / 3600)
            let recencyBonus = 24.0 / (ageHours + 2.0)
            let hotScore = Double(replies.count) * 3 + recencyBonus
            return CommentThread(parent: root, replies: replies, lastActivityAt: lastReplyDate, hotScore: hotScore)
        }

        switch commentSortMode {
        case .hot:
            return threads.sorted {
                if $0.hotScore == $1.hotScore {
                    return $0.lastActivityAt > $1.lastActivityAt
                }
                return $0.hotScore > $1.hotScore
            }
        case .timeline:
            return threads.sorted(by: { $0.parent.createdAt > $1.parent.createdAt })
        }
    }

    private var visibleCommentThreads: [CommentThread] {
        Array(sortedCommentThreads.prefix(visibleRootCount))
    }

    @ViewBuilder
    private func commentThreadView(_ thread: CommentThread) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            commentRow(comment: thread.parent, indent: 0, showReplyTarget: false, isSecondary: false)

            if !thread.replies.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(displayedReplies(for: thread)) { reply in
                        commentRow(comment: reply, indent: 34, showReplyTarget: true, isSecondary: true)
                    }

                    commentRepliesActionBar(for: thread)
                }
            }
        }
    }

    @ViewBuilder
    private func commentRepliesActionBar(for thread: CommentThread) -> some View {
        let isExpanded = expandedRootCommentIDs.contains(thread.id)
        let visibleCount = visibleReplyCount(for: thread)
        let remaining = max(0, thread.replies.count - visibleCount)
        let shouldShowActionBar = isExpanded || thread.replies.count > replyPreviewCount

        if shouldShowActionBar {
            HStack(spacing: 14) {
                if isExpanded, remaining > 0 {
                    Button(
                        LT(
                            "查看更多回复（剩余 \(remaining) 条）",
                            "Show more replies (\(remaining) left)",
                            "返信をさらに表示（残り \(remaining) 件）"
                        )
                    ) {
                        loadMoreReplies(for: thread)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                }

                if !isExpanded, thread.replies.count > replyPreviewCount {
                    Button(
                        LT(
                            "展开 \(thread.replies.count) 条回复",
                            "Expand \(thread.replies.count) replies",
                            "\(thread.replies.count) 件の返信を展開"
                        )
                    ) {
                        expandReplies(for: thread)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                } else if isExpanded, thread.replies.count > replyPreviewCount {
                    Button(LT("收起回复", "收起回复", "返信を閉じる")) {
                        collapseReplies(for: thread)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                }

                Spacer()
            }
            .padding(.leading, 68)
        }
    }

    @ViewBuilder
    private func commentRow(comment: Comment, indent: CGFloat, showReplyTarget: Bool, isSecondary: Bool) -> some View {
        let avatarSize: CGFloat = isSecondary ? 24 : 30
        let authorFont: Font = isSecondary ? .caption.weight(.semibold) : .footnote.weight(.semibold)
        let contentFont: Font = isSecondary ? .caption : .footnote

        HStack(alignment: .top, spacing: 10) {
            Button {
                appPush(.userProfile(userID: comment.author.id))
            } label: {
                commentAvatar(comment.author, size: avatarSize)
                    .padding(.leading, indent)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Button {
                    appPush(.userProfile(userID: comment.author.id))
                } label: {
                    commentAuthorMeta(comment.author, font: authorFont, isSecondary: isSecondary)
                }
                .buttonStyle(.plain)

                if showReplyTarget, let replyTo = comment.replyToAuthor {
                    Text(
                        LT(
                            "回复 \(replyTo.displayName)：\(comment.content)",
                            "Reply to \(replyTo.displayName): \(comment.content)",
                            "\(replyTo.displayName) への返信：\(comment.content)"
                        )
                    )
                    .font(contentFont)
                    .foregroundStyle(RaverTheme.primaryText)
                } else {
                    Text(comment.content)
                        .font(contentFont)
                        .foregroundStyle(RaverTheme.primaryText)
                }

                Text(comment.createdAt.feedTimeText)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, isSecondary ? 2 : 4)
        .contentShape(Rectangle())
        .onTapGesture {
            replyTargetComment = comment
        }
    }

    @ViewBuilder
    private func commentAuthorMeta(_ author: UserSummary, font: Font, isSecondary: Bool) -> some View {
        HStack(spacing: 5) {
            Text(author.displayName)
                .font(font)
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(1)

            if !isSecondary, let titleMedal = appearanceResolver.appearance(userID: author.id)?.titleMedal {
                VirtualAssetTitleMedalView(asset: titleMedal, compact: true, maxWidth: 82)
            } else if let badge = appearanceResolver.appearance(userID: author.id)?.profileBadges.first {
                VirtualAssetBadgeView(asset: badge, compact: true, showTitle: false)
            }
        }
    }

    private func resetCommentPresentationState() {
        expandedRootCommentIDs = []
        visibleReplyCountByRoot = [:]
        resetRootPaging()
    }

    private func resetRootPaging() {
        let total = sortedCommentThreads.count
        visibleRootCount = min(rootPageSize, total)
    }

    private func loadMoreRootCommentsIfNeeded(currentThreadID: String) {
        guard let lastVisibleID = visibleCommentThreads.last?.id, currentThreadID == lastVisibleID else { return }
        let total = sortedCommentThreads.count
        guard visibleRootCount < total else { return }
        visibleRootCount = min(visibleRootCount + rootPageSize, total)
    }

    private func displayedReplies(for thread: CommentThread) -> [Comment] {
        if expandedRootCommentIDs.contains(thread.id) {
            return Array(thread.replies.prefix(visibleReplyCount(for: thread)))
        }
        return Array(thread.replies.prefix(replyPreviewCount))
    }

    private func visibleReplyCount(for thread: CommentThread) -> Int {
        let defaultExpandedCount = min(max(replyPageSize, replyPreviewCount), thread.replies.count)
        return min(
            thread.replies.count,
            max(defaultExpandedCount, visibleReplyCountByRoot[thread.id] ?? defaultExpandedCount)
        )
    }

    private func expandReplies(for thread: CommentThread) {
        expandedRootCommentIDs.insert(thread.id)
        visibleReplyCountByRoot[thread.id] = visibleReplyCount(for: thread)
    }

    private func collapseReplies(for thread: CommentThread) {
        expandedRootCommentIDs.remove(thread.id)
    }

    private func loadMoreReplies(for thread: CommentThread) {
        let current = visibleReplyCount(for: thread)
        visibleReplyCountByRoot[thread.id] = min(current + replyPageSize, thread.replies.count)
    }

    private func updatePresentationStateAfterAppending(comment: Comment) {
        let total = sortedCommentThreads.count
        if visibleRootCount == 0 {
            visibleRootCount = min(rootPageSize, total)
        } else {
            visibleRootCount = min(max(visibleRootCount, 1), total)
        }

        let hasParent = !(comment.parentCommentID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard hasParent else { return }
        let fallbackRootID = replyTargetComment?.rootCommentID ?? replyTargetComment?.id
        let rootID = (comment.rootCommentID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? comment.rootCommentID : nil) ?? fallbackRootID
        guard let rootID else { return }

        expandedRootCommentIDs.insert(rootID)
        if let thread = sortedCommentThreads.first(where: { $0.id == rootID }) {
            let current = visibleReplyCount(for: thread)
            visibleReplyCountByRoot[rootID] = min(current + 1, thread.replies.count)
        }
    }

    private func hidePost(reason: String) async {
        if appState.session == nil {
            await trackFeedEvent(eventType: "feed_hide", metadata: ["reason": "guest_local_hide"])
            NotificationCenter.default.post(name: .circlePostDidHide, object: post.id)
            dismiss()
            return
        }
        do {
            try await interactionRepository.hidePost(postID: post.id, reason: reason)
            await trackFeedEvent(eventType: "feed_hide", metadata: ["reason": reason])
            NotificationCenter.default.post(name: .circlePostDidHide, object: post.id)
            dismiss()
        } catch {
            self.error = error.userFacingMessage
        }
    }

    @MainActor
    private func trackFeedEvent(eventType: String, metadata: [String: String]? = nil) async {
        do {
            try await eventTrackingRepository.recordFeedEvent(
                input: FeedEventInput(
                    sessionID: feedSessionID,
                    eventType: eventType,
                    postID: post.id,
                    feedMode: nil,
                    position: nil,
                    metadata: metadata
                )
            )
        } catch {
            // 详情埋点失败不影响主流程
        }
    }
}

private enum CommentSortMode: String, CaseIterable, Identifiable {
    case hot
    case timeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hot:
            return LT("热度", "Hot", "人気")
        case .timeline:
            return LT("时间轴", "Timeline", "タイムライン")
        }
    }
}

private struct CommentThread: Identifiable {
    let parent: Comment
    let replies: [Comment]
    let lastActivityAt: Date
    let hotScore: Double

    var id: String { parent.id }
}
