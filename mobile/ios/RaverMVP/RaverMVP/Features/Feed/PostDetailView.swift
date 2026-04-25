import SwiftUI
import UIKit

struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @State private var post: Post
    private let service: SocialService

    @State private var comments: [Comment] = []
    @State private var commentInput = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var sharePayload: PostSharePayload?
    @State private var isShowingHideReasonDialog = false
    @State private var replyTargetComment: Comment?
    @State private var commentSortMode: CommentSortMode = .hot
    @State private var visibleRootCount = 0
    @State private var expandedRootCommentIDs: Set<String> = []
    @State private var visibleReplyCountByRoot: [String: Int] = [:]
    @State private var feedSessionID = UUID().uuidString

    private let rootPageSize = 12
    private let replyPreviewCount = 3
    private let replyPageSize = 6

    init(post: Post, service: SocialService) {
        self._post = State(initialValue: post)
        self.service = service
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PostCardView(
                        post: post,
                        currentUserId: appState.session?.user.id,
                        showsFollowButton: true,
                        onLikeTap: {
                            Task {
                                do {
                                    post = try await service.toggleLike(postID: post.id, shouldLike: !post.isLiked)
                                    notifyPostUpdated()
                                    await trackFeedEvent(eventType: "feed_like")
                                } catch {
                                    self.error = error.userFacingMessage
                                }
                            }
                        },
                        onRepostTap: {
                            Task {
                                do {
                                    post = try await service.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
                                    notifyPostUpdated()
                                } catch {
                                    self.error = error.userFacingMessage
                                }
                            }
                        },
                        onSaveTap: {
                            Task {
                                guard appState.session != nil else {
                                    self.error = L("请先登录后再收藏", "Please sign in before saving.")
                                    return
                                }
                                do {
                                    post = try await service.toggleSave(postID: post.id, shouldSave: !post.isSaved)
                                    notifyPostUpdated()
                                    await trackFeedEvent(eventType: "feed_save")
                                } catch {
                                    self.error = error.userFacingMessage
                                }
                            }
                        },
                        onShareTap: {
                            sharePayload = PostSharePayload(post: post)
                        },
                        onHideTap: {
                            isShowingHideReasonDialog = true
                        },
                        onFollowTap: {
                            Task {
                                do {
                                    let author = try await service.toggleFollow(userID: post.author.id, shouldFollow: !post.author.isFollowing)
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
                        onEditTap: nil
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text(LL("评论"))
                                    .font(.headline)
                                Spacer()
                                if !comments.isEmpty {
                                    Picker(LL("排序"), selection: $commentSortMode) {
                                        ForEach(CommentSortMode.allCases) { mode in
                                            Text(mode.title).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(maxWidth: 190)
                                }
                            }

                            if isLoading {
                                ProgressView()
                            } else if comments.isEmpty {
                                Text(LL("还没有评论，来抢沙发吧。"))
                                    .font(.subheadline)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
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

            Divider()

            VStack(spacing: 8) {
                if let replyTargetComment {
                    HStack(spacing: 8) {
                        Text(
                            L(
                                "回复 \(replyTargetComment.author.displayName)",
                                "Replying to \(replyTargetComment.author.displayName)"
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

                    Button(L("发送", "Send")) {
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Collapse")) {
                    dismissKeyboard()
                }
            }
        }
        .raverGradientNavigationChrome(title: LL("动态详情")) {
            dismiss()
        }
        .task {
            await loadComments()
        }
        .onChange(of: commentSortMode) { _, _ in
            resetRootPaging()
        }
        .sheet(item: $sharePayload) { payload in
            PostInAppShareSheet(payload: payload) { channel in
                guard appState.session != nil else { return }
                Task {
                    do {
                        post = try await service.recordShare(postID: post.id, channel: channel, status: "completed")
                        notifyPostUpdated()
                        await trackFeedEvent(eventType: "feed_share", metadata: ["channel": channel])
                    } catch {
                        self.error = error.userFacingMessage
                    }
                }
            }
        }
        .confirmationDialog(
            L("告诉我们原因", "Tell us why"),
            isPresented: $isShowingHideReasonDialog,
            titleVisibility: .visible
        ) {
            ForEach(PostHideReasonOption.allCases) { reason in
                Button(reason.title) {
                    Task { await hidePost(reason: reason.rawValue) }
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("我们会据此减少类似内容。", "We'll show fewer similar posts."))
        }
        .alert(LL("失败"), isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    @MainActor
    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }

        do {
            comments = try await service.fetchComments(postID: post.id)
            resetCommentPresentationState()
        } catch {
            self.error = error.userFacingMessage
        }
    }

    @ViewBuilder
    private func commentAvatar(_ user: UserSummary, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           URL(string: resolved) != nil,
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(commentAvatarFallback(user, size: size))
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            commentAvatarFallback(user, size: size)
        }
    }

    private func commentAvatarFallback(_ user: UserSummary, size: CGFloat) -> some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: user.avatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func submitComment() {
        Task {
            let text = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            do {
                let comment = try await service.addComment(
                    postID: post.id,
                    content: text,
                    parentCommentID: replyTargetComment?.id
                )
                comments.append(comment)
                updatePresentationStateAfterAppending(comment: comment)
                commentInput = ""
                replyTargetComment = nil
                dismissKeyboard()
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
            return L("回复 \(replyTargetComment.author.displayName)...", "Reply to \(replyTargetComment.author.displayName)...")
        }
        return LL("说点什么...")
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
                        L(
                            "查看更多回复（剩余 \(remaining) 条）",
                            "Show more replies (\(remaining) left)"
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
                        L(
                            "展开 \(thread.replies.count) 条回复",
                            "Expand \(thread.replies.count) replies"
                        )
                    ) {
                        expandReplies(for: thread)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                } else if isExpanded, thread.replies.count > replyPreviewCount {
                    Button(LL("收起回复")) {
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
                    Text(comment.author.displayName)
                        .font(authorFont)
                        .foregroundStyle(RaverTheme.primaryText)
                }
                .buttonStyle(.plain)

                if showReplyTarget, let replyTo = comment.replyToAuthor {
                    Text(
                        L(
                            "回复 \(replyTo.displayName)：\(comment.content)",
                            "Reply to \(replyTo.displayName): \(comment.content)"
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
            try await service.hidePost(postID: post.id, reason: reason)
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
            try await service.recordFeedEvent(
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
            return L("热度", "Hot")
        case .timeline:
            return L("时间轴", "Timeline")
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
