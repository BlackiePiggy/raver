import SwiftUI
import UIKit

private struct NewsCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: NewsShareCardPayload
}

private struct NewsSharePreviewCard: View {
    let payload: NewsShareCardPayload

    private let cardHeight: CGFloat = 82
    private let imageWidth: CGFloat = 94

    var body: some View {
        HStack(spacing: 0) {
            previewImage
                .frame(width: imageWidth, height: cardHeight)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                if let badge = payload.badgeText?.nilIfBlank {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(red: 0.34, green: 0.74, blue: 0.96))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.34, green: 0.74, blue: 0.96).opacity(0.12), in: Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(payload.headline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(height: cardHeight, alignment: .leading)
        }
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RaverTheme.primaryText.opacity(0.06), lineWidth: 1)
        }
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
            colors: [Color(red: 0.12, green: 0.16, blue: 0.22), Color(red: 0.18, green: 0.28, blue: 0.40)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "newspaper.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }
}

struct DiscoverNewsDetailView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush

    let article: DiscoverNewsArticle

    @State private var relatedDJs: [WebDJ] = []
    @State private var relatedEvents: [WebEvent] = []
    @State private var relatedBrands: [LearnFestival] = []
    @State private var isLoadingBindings = false
    @State private var comments: [Comment] = []
    @State private var visibleCommentCount = 20
    @State private var commentsPhase: LoadPhase = .idle
    @State private var isSendingComment = false
    @State private var commentInput = ""
    @State private var commentActionMessage: String?
    @State private var coverImageSize: CGSize = .zero
    @State private var shareMorePresentation: NewsCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: NewsCardSharePresentation?
    @State private var widgetStatusMessage: String?
    @State private var widgetStatusConversation: Conversation?
    @State private var widgetStatusDismissToken = UUID()
    @State private var errorMessage: String?

    private var newsRepository: DiscoverNewsRepository {
        appContainer.discoverNewsRepository
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)

                HStack(spacing: 8) {
                    Text(article.category.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(article.category.badgeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(article.category.badgeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Text(article.source)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    Spacer(minLength: 8)

                    Label(L("\(article.replyCount) 回复", "\(article.replyCount) replies"), systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                HStack(spacing: 6) {
                    Text(article.publishedAt.appLocalizedYMDHMText())
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(L("回复 \(article.replyCount)", "Replies \(article.replyCount)"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                newsCover
                    .aspectRatio(coverAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Divider()

                if !article.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(article.summary)
                        .font(.body)
                        .foregroundStyle(RaverTheme.primaryText)
                }

                if !article.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DiscoverNewsMarkdownView(markdown: article.body)
                }

                if let link = article.link,
                   let url = URL(string: link) {
                    Link(destination: url) {
                        Label(LL("查看原文链接"), systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(RaverTheme.accent)
                    .padding(.top, 6)
                }

                if hasAnyBoundEntity {
                    relatedEntitySection
                }

                authorSection

                commentsSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RaverTheme.background)
        .raverGradientNavigationChrome(
            title: LL("资讯详情"),
            trailing: navigationShareButton.eraseToAnyView()
        ) {
            dismiss()
        }
        .task(id: article.id) {
            await loadBoundEntities()
            await loadComments(reset: true)
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
                    message: L("已分享到 \(conversation.title)", "Shared to \(conversation.title)"),
                    conversation: conversation
                )
            } preview: {
                NewsSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
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
                        quickActions: shareMoreQuickActions(),
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
                            message: L("已分享到 \(conversation.title)", "Shared to \(conversation.title)"),
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
        .overlay(alignment: .top) {
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
                .padding(.horizontal, 16)
                .padding(.top, 120)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
        .animation(.easeOut(duration: 0.25), value: widgetStatusMessage != nil)
    }

    private var hasAnyBoundEntity: Bool {
        !article.boundDjIDs.isEmpty || !article.boundBrandIDs.isEmpty || !article.boundEventIDs.isEmpty
    }

    private var navigationShareButton: some View {
        Button {
            shareMorePresentation = NewsCardSharePresentation(
                payload: makeNewsShareCardPayload()
            )
            isShareMorePanelVisible = false
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var coverAspectRatio: CGFloat {
        guard coverImageSize.width > 1, coverImageSize.height > 1 else {
            return 16.0 / 9.0
        }
        return coverImageSize.width / coverImageSize.height
    }

    private var unresolvedBoundDjIDs: [String] {
        let resolved = Set(relatedDJs.map(\.id))
        return article.boundDjIDs.filter { !resolved.contains($0) }
    }

    private var unresolvedBoundBrandIDs: [String] {
        let resolved = Set(relatedBrands.map(\.id))
        return article.boundBrandIDs.filter { !resolved.contains($0) }
    }

    private var unresolvedBoundEventIDs: [String] {
        let resolved = Set(relatedEvents.map(\.id))
        return article.boundEventIDs.filter { !resolved.contains($0) }
    }

    private func shortIDLabel(_ id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return id }
        return "#\(trimmed.prefix(6))"
    }

    @ViewBuilder
    private var relatedEntitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text(LL("关联实体"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                if isLoadingBindings {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(relatedDJs) { dj in
                        Button {
                            appPush(.djDetail(djID: dj.id))
                        } label: {
                            HStack(spacing: 6) {
                                relatedDJAvatar(dj)
                                    .frame(width: 22, height: 22)
                                    .clipShape(Circle())
                                Text(dj.name)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(RaverTheme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(unresolvedBoundDjIDs, id: \.self) { id in
                        Button {
                            appPush(.djDetail(djID: id))
                        } label: {
                            Label("DJ \(shortIDLabel(id))", systemImage: "person.wave.2")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(RaverTheme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(relatedBrands) { brand in
                        Button {
                            discoverPush(.festivalDetail(festivalID: brand.id))
                        } label: {
                            Label(brand.name, systemImage: "music.quarternote.3")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(RaverTheme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(unresolvedBoundBrandIDs, id: \.self) { id in
                        Label("Brand \(shortIDLabel(id))", systemImage: "music.quarternote.3")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(RaverTheme.card, in: Capsule())
                    }

                    ForEach(relatedEvents) { event in
                        Button {
                            appPush(.eventDetail(eventID: event.id))
                        } label: {
                            Label(event.name, systemImage: "calendar")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(RaverTheme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(unresolvedBoundEventIDs, id: \.self) { id in
                        Button {
                            appPush(.eventDetail(eventID: id))
                        } label: {
                            Label("Event \(shortIDLabel(id))", systemImage: "calendar")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(RaverTheme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var authorSection: some View {
        Button {
            appPush(.userProfile(userID: article.authorID))
        } label: {
            HStack(spacing: 10) {
                authorAvatar
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(article.authorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text("@\(article.authorUsername)")
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.top, 2)

            Text(LL("评论"))
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)

            if let commentActionMessage {
                ScreenStatusBanner(message: commentActionMessage, style: .error)
            }

            if commentsPhase == .idle || commentsPhase == .initialLoading {
                CommentSectionSkeletonView(count: 3)
            } else if case .failure(let message) = commentsPhase {
                ScreenErrorCard(
                    title: L("评论加载失败", "Comments Failed to Load"),
                    message: message
                ) {
                    Task { await loadComments(reset: true) }
                }
            } else if case .offline(let message) = commentsPhase {
                ScreenErrorCard(
                    title: L("网络不可用", "Network Unavailable"),
                    message: message
                ) {
                    Task { await loadComments(reset: true) }
                }
            } else if comments.isEmpty {
                Text(LL("还没有评论，来抢沙发吧。"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(visibleComments.enumerated()), id: \.element.id) { index, comment in
                        Button {
                            appPush(.userProfile(userID: comment.author.id))
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                commentAvatar(comment.author)
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(comment.author.displayName)
                                        .font(.subheadline.weight(.semibold))
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
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if index == visibleComments.count - 1 {
                                loadNextCommentChunk()
                            }
                        }
                    }

                    if visibleCommentCount < comments.count {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                                .onAppear {
                                    loadNextCommentChunk()
                                }
                            Spacer()
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(LL("说点什么..."), text: $commentInput, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(L("发送", "Send")) {
                    Task { await submitComment() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSendingComment || commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibleComments: [Comment] {
        Array(comments.prefix(visibleCommentCount))
    }

    private func loadNextCommentChunk() {
        guard visibleCommentCount < comments.count else { return }
        visibleCommentCount = min(comments.count, visibleCommentCount + 20)
    }

    @ViewBuilder
    private func relatedDJAvatar(_ dj: WebDJ) -> some View {
        ImageLoaderView(
            urlString: AppConfig.resolvedDJAvatarURLString(dj.avatarOriginalUrl ?? dj.avatarUrl, size: .small),
            resizingMode: .fill
        )
        .background(avatarInitialFallback(dj.name))
    }

    private func avatarInitialFallback(_ name: String) -> some View {
        Circle()
            .fill(RaverTheme.card)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            )
    }

    @ViewBuilder
    private func commentAvatar(_ user: UserSummary) -> some View {
        ImageLoaderView(urlString: user.avatarURL, resizingMode: .fill)
            .background(commentAvatarFallback(user))
    }

    private func commentAvatarFallback(_ user: UserSummary) -> some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: user.avatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .background(RaverTheme.card)
        .clipShape(Circle())
    }

    @MainActor
    private func loadBoundEntities() async {
        let djIDs = article.boundDjIDs
        let brandIDs = article.boundBrandIDs
        let eventIDs = article.boundEventIDs
        guard !djIDs.isEmpty || !brandIDs.isEmpty || !eventIDs.isEmpty else { return }

        isLoadingBindings = true
        defer { isLoadingBindings = false }

        async let djsTask = fetchBoundDJs(ids: djIDs)
        async let brandsTask = fetchBoundBrands(ids: brandIDs)
        async let eventsTask = fetchBoundEvents(ids: eventIDs)
        relatedDJs = await djsTask
        relatedBrands = await brandsTask
        relatedEvents = await eventsTask
    }

    @MainActor
    private func loadComments(reset: Bool) async {
        if reset {
            visibleCommentCount = 20
            comments = []
        }
        commentsPhase = .initialLoading
        do {
            comments = try await newsRepository.fetchComments(postID: article.id)
            visibleCommentCount = min(max(visibleCommentCount, 20), comments.count)
            commentsPhase = comments.isEmpty ? .empty : .success
        } catch {
            commentsPhase = .failure(
                message: error.userFacingMessage ?? L("评论加载失败，请稍后重试", "Failed to load comments. Please try again later.")
            )
        }
    }

    @MainActor
    private func submitComment() async {
        let text = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSendingComment else { return }

        isSendingComment = true
        defer { isSendingComment = false }

        do {
            let comment = try await newsRepository.addComment(postID: article.id, content: text)
            comments.append(comment)
            visibleCommentCount = comments.count
            commentInput = ""
            commentsPhase = .success
            commentActionMessage = nil
        } catch {
            commentActionMessage = error.userFacingMessage ?? L("评论发送失败，请稍后重试", "Failed to send comment. Please try again later.")
        }
    }

    private func fetchBoundDJs(ids: [String]) async -> [WebDJ] {
        guard !ids.isEmpty else { return [] }
        var resultByID: [String: WebDJ] = [:]
        await withTaskGroup(of: (String, WebDJ?).self) { group in
            for id in ids {
                group.addTask {
                    do {
                        return (id, try await newsRepository.fetchDJ(id: id))
                    } catch {
                        return (id, nil)
                    }
                }
            }
            for await (id, dj) in group {
                if let dj {
                    resultByID[id] = dj
                }
            }
        }
        return ids.compactMap { resultByID[$0] }
    }

    private func fetchBoundEvents(ids: [String]) async -> [WebEvent] {
        guard !ids.isEmpty else { return [] }
        var resultByID: [String: WebEvent] = [:]
        await withTaskGroup(of: (String, WebEvent?).self) { group in
            for id in ids {
                group.addTask {
                    do {
                        return (id, try await newsRepository.fetchEvent(id: id))
                    } catch {
                        return (id, nil)
                    }
                }
            }
            for await (id, event) in group {
                if let event {
                    resultByID[id] = event
                }
            }
        }
        return ids.compactMap { resultByID[$0] }
    }

    private func fetchBoundBrands(ids: [String]) async -> [LearnFestival] {
        guard !ids.isEmpty else { return [] }
        do {
            let allFestivals = try await newsRepository.fetchLearnFestivals(search: nil as String?)
            let festivalByID: [String: LearnFestival] = Dictionary(
                uniqueKeysWithValues: allFestivals.map { ($0.id, LearnFestival(web: $0)) }
            )
            return ids.compactMap { festivalByID[$0] }
        } catch {
            return []
        }
    }

    private func makeNewsShareCardPayload() -> NewsShareCardPayload {
        NewsShareCardPayload(
            articleID: article.id,
            headline: article.title,
            summary: article.summary.nilIfBlank,
            source: article.source.nilIfBlank,
            categoryRawValue: article.category.rawValue,
            coverImageURL: article.coverImageURL?.nilIfBlank,
            publishedAtISO8601: ISO8601DateFormatter().string(from: article.publishedAt),
            authorName: article.authorName.nilIfBlank,
            badgeText: L("资讯", "News")
        )
    }

    private func newsDeeplink(for payload: NewsShareCardPayload) -> String {
        "raver://news/\(payload.articleID)"
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
        _ payload: NewsShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.socialService.sendNewsCardMessage(
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
                systemImage: "bubble.left.and.bubble.right.fill",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                errorMessage = L("QQ 分享接口待接入。", "QQ share hook is not connected yet.")
            }
        ]
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = [
            SharePanelQuickAction(
                title: L("复制链接", "Copy Link"),
                systemImage: "link",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                UIPasteboard.general.string = article.link?.nilIfBlank ?? newsDeeplink(for: makeNewsShareCardPayload())
                showWidgetStatusBanner(message: L("已复制链接", "Link copied"))
            },
            SharePanelQuickAction(
                title: L("复制 App 内链接", "Copy App Link"),
                systemImage: "link",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                UIPasteboard.general.string = newsDeeplink(for: makeNewsShareCardPayload())
                showWidgetStatusBanner(message: L("链接已复制", "Link copied"))
            }
        ]

        if let raw = article.link?.nilIfBlank,
           let url = URL(string: raw) {
            actions.append(
                SharePanelQuickAction(
                    title: L("查看原文", "Open Source"),
                    systemImage: "arrow.up.right.square",
                    accentColor: Color(red: 0.53, green: 0.45, blue: 0.96)
                ) {
                    UIApplication.shared.open(url)
                }
            )
        }

        return actions
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

    @ViewBuilder
    private var newsCover: some View {
        ImageLoaderView(
            urlString: article.coverImageURL,
            resizingMode: .fit,
            onImageLoaded: { imageSize in
                guard imageSize.width > 1, imageSize.height > 1 else { return }
                Task { @MainActor in
                    if coverImageSize != imageSize {
                        coverImageSize = imageSize
                    }
                }
            }
        )
            .background(fallbackCover)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.68),
                        Color.black.opacity(0.36),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 104)
            }
    }

    private var fallbackCover: some View {
        LinearGradient(
            colors: [Color(red: 0.14, green: 0.17, blue: 0.21), Color(red: 0.11, green: 0.13, blue: 0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "newspaper.fill")
                .font(.title2)
                .foregroundStyle(RaverTheme.secondaryText.opacity(0.8))
        )
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let resolved = AppConfig.resolvedURLString(article.authorAvatarURL),
           let remoteURL = URL(string: resolved),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    avatarFallback
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    avatarFallback
                @unknown default:
                    avatarFallback
                }
            }
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: article.authorID,
                username: article.authorUsername,
                avatarURL: article.authorAvatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .background(RaverTheme.cardBorder)
    }
}

private struct DiscoverNewsMarkdownView: View {
    let markdown: String
    @State private var imageSizeByURL: [String: CGSize] = [:]

    private enum ListKind {
        case unordered
        case ordered
    }

    private enum Block: Identifiable {
        case heading(id: String, level: Int, text: String)
        case paragraph(id: String, text: String)
        case quote(id: String, text: String)
        case list(id: String, kind: ListKind, items: [String])
        case code(id: String, text: String)
        case divider(id: String)
        case image(id: String, url: String)

        var id: String {
            switch self {
            case .heading(let id, _, _): return id
            case .paragraph(let id, _): return id
            case .quote(let id, _): return id
            case .list(let id, _, _): return id
            case .code(let id, _): return id
            case .divider(let id): return id
            case .image(let id, _): return id
            }
        }
    }

    private var blocks: [Block] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var result: [Block] = []
        var blockIndex = 0
        var paragraphLines: [String] = []
        var quoteLines: [String] = []
        var listKind: ListKind?
        var listItems: [String] = []
        var codeLines: [String] = []
        var isInCodeFence = false

        func nextID(_ prefix: String) -> String {
            defer { blockIndex += 1 }
            return "\(prefix)-\(blockIndex)"
        }

        func flushParagraph() {
            let text = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            paragraphLines.removeAll()
            guard !text.isEmpty else { return }
            result.append(.paragraph(id: nextID("p"), text: text))
        }

        func flushQuote() {
            let text = quoteLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            quoteLines.removeAll()
            guard !text.isEmpty else { return }
            result.append(.quote(id: nextID("q"), text: text))
        }

        func flushList() {
            guard let kind = listKind else { return }
            let items = listItems.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            listKind = nil
            listItems.removeAll()
            guard !items.isEmpty else { return }
            result.append(.list(id: nextID("l"), kind: kind, items: items))
        }

        func flushCode() {
            let text = codeLines.joined(separator: "\n")
            codeLines.removeAll()
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            result.append(.code(id: nextID("c"), text: text))
        }

        func flushAllTextContainers() {
            flushParagraph()
            flushQuote()
            flushList()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if isInCodeFence {
                if trimmed.hasPrefix("```") {
                    flushCode()
                    isInCodeFence = false
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if trimmed.hasPrefix("```") {
                flushAllTextContainers()
                isInCodeFence = true
                continue
            }

            if let imageURL = parseMarkdownImageURL(from: trimmed) {
                flushAllTextContainers()
                result.append(.image(id: nextID("img"), url: imageURL))
                continue
            }

            if isDividerLine(trimmed) {
                flushAllTextContainers()
                result.append(.divider(id: nextID("hr")))
                continue
            }

            if trimmed.isEmpty {
                flushAllTextContainers()
                continue
            }

            if let heading = parseHeading(from: trimmed) {
                flushAllTextContainers()
                result.append(.heading(id: nextID("h"), level: heading.level, text: heading.text))
                continue
            }

            if let quote = parseQuoteLine(from: trimmed) {
                flushParagraph()
                flushList()
                quoteLines.append(quote)
                continue
            } else {
                flushQuote()
            }

            if let unordered = parseUnorderedListItem(from: trimmed) {
                flushParagraph()
                if listKind != .unordered {
                    flushList()
                    listKind = .unordered
                }
                listItems.append(unordered)
                continue
            }

            if let ordered = parseOrderedListItem(from: trimmed) {
                flushParagraph()
                if listKind != .ordered {
                    flushList()
                    listKind = .ordered
                }
                listItems.append(ordered)
                continue
            }

            flushList()
            paragraphLines.append(line)
        }

        if isInCodeFence {
            flushCode()
        }
        flushAllTextContainers()
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                switch block {
                case .heading(_, let level, let text):
                    headingBlock(level: level, text: text)
                case .paragraph(_, let text):
                    paragraphBlock(text)
                case .quote(_, let text):
                    quoteBlock(text)
                case .list(_, let kind, let items):
                    listBlock(kind: kind, items: items)
                case .code(_, let text):
                    codeBlock(text)
                case .divider:
                    dividerBlock
                case .image(_, let url):
                    markdownImageBlock(url)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attributedInlineText(_ text: String) -> AttributedString {
        let normalized = text.replacingOccurrences(of: "\n", with: "  \n")
        if let parsed = try? AttributedString(
            markdown: normalized,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            return parsed
        }
        return AttributedString(text)
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .title2.weight(.bold)
        case 2: return .title3.weight(.bold)
        case 3: return .headline.weight(.semibold)
        default: return .subheadline.weight(.semibold)
        }
    }

    @ViewBuilder
    private func headingBlock(level: Int, text: String) -> some View {
        Text(attributedInlineText(text))
            .font(headingFont(for: level))
            .foregroundStyle(RaverTheme.primaryText)
            .lineSpacing(3)
            .tint(RaverTheme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, level <= 2 ? 4 : 2)
    }

    @ViewBuilder
    private func paragraphBlock(_ text: String) -> some View {
        markdownTextContainer {
            Text(attributedInlineText(text))
                .font(.callout)
                .foregroundStyle(RaverTheme.primaryText)
                .lineSpacing(5)
                .tint(RaverTheme.accent)
        }
    }

    @ViewBuilder
    private func quoteBlock(_ text: String) -> some View {
        markdownTextContainer {
            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(RaverTheme.accent.opacity(0.75))
                    .frame(width: 3)
                Text(attributedInlineText(text))
                    .font(.callout)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineSpacing(4)
                    .tint(RaverTheme.accent)
            }
        }
    }

    @ViewBuilder
    private func listBlock(kind: ListKind, items: [String]) -> some View {
        markdownTextContainer {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(kind == .ordered ? "\(index + 1)." : "•")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(RaverTheme.accent)
                            .padding(.top, 1)
                        Text(attributedInlineText(item))
                            .font(.callout)
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineSpacing(4)
                            .tint(RaverTheme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func codeBlock(_ text: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(red: 0.83, green: 0.90, blue: 0.98))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.40))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var dividerBlock: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private func markdownTextContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func markdownImageBlock(_ urlString: String) -> some View {
        ImageLoaderView(
            urlString: urlString,
            resizingMode: .fit,
            onImageLoaded: { imageSize in
                guard imageSize.width > 1, imageSize.height > 1 else { return }
                Task { @MainActor in
                    if imageSizeByURL[urlString] != imageSize {
                        imageSizeByURL[urlString] = imageSize
                    }
                }
            }
        )
            .aspectRatio(markdownImageAspectRatio(for: urlString), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(RaverTheme.secondaryText)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func markdownImageAspectRatio(for urlString: String) -> CGFloat {
        guard let size = imageSizeByURL[urlString], size.width > 1, size.height > 1 else {
            return 16.0 / 9.0
        }
        return size.width / size.height
    }

    private func parseMarkdownImageURL(from line: String) -> String? {
        guard line.hasPrefix("![") else { return nil }
        guard let open = line.firstIndex(of: "("),
              let close = line.lastIndex(of: ")"),
              open < close else {
            return nil
        }
        let url = String(line[line.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") else {
            return nil
        }
        return url
    }

    private func parseHeading(from line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard level > 0, level <= 6 else { return nil }
        let rest = String(line.dropFirst(level)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty else { return nil }
        return (level, rest)
    }

    private func parseQuoteLine(from line: String) -> String? {
        guard line.hasPrefix(">") else { return nil }
        return String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseUnorderedListItem(from line: String) -> String? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func parseOrderedListItem(from line: String) -> String? {
        var digitsEnd = line.startIndex
        while digitsEnd < line.endIndex, line[digitsEnd].isNumber {
            digitsEnd = line.index(after: digitsEnd)
        }
        guard digitsEnd > line.startIndex, digitsEnd < line.endIndex else { return nil }
        let separator = line[digitsEnd]
        guard separator == "." || separator == ")" else { return nil }
        let afterSeparator = line.index(after: digitsEnd)
        guard afterSeparator < line.endIndex, line[afterSeparator].isWhitespace else { return nil }
        let item = String(line[afterSeparator...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return item.isEmpty ? nil : item
    }

    private func isDividerLine(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        let compact = line.replacingOccurrences(of: " ", with: "")
        if compact.count < 3 { return false }
        return Set(compact).count == 1 && (compact.first == "-" || compact.first == "*" || compact.first == "_")
    }
}
