import SwiftUI

private struct RankingBoardCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: RankingBoardShareCardPayload
}

private struct RankingBoardSharePreviewCard: View {
    let payload: RankingBoardShareCardPayload

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

                Text(payload.boardName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                Text(rankingMetadataText)
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
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }

    private var rankingMetadataText: String {
        if let subtitle = payload.boardSubtitle?.nilIfBlank {
            return "\(payload.year) · \(subtitle)"
        }
        return String(payload.year)
    }
}

struct RankingBoardDetailView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.appPush) private var appPush

    private var djRankingRepository: DJRankingRepository {
        appContainer.djRankingRepository
    }

    let board: RankingBoard

    @State private var selectedYear: Int
    @State private var detail: RankingBoardDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var fullChatSharePresentation: RankingBoardCardSharePresentation?
    @State private var shareMorePresentation: RankingBoardCardSharePresentation?
    @State private var isShareMorePanelVisible = false

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    init(board: RankingBoard, initialYear: Int? = nil) {
        self.board = board
        let latestYear = board.years.max() ?? 2025
        let seededYear = initialYear.flatMap { board.years.contains($0) || board.years.isEmpty ? $0 : nil } ?? latestYear
        _selectedYear = State(initialValue: seededYear)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                contentBody
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: board.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareMorePresentation = RankingBoardCardSharePresentation(
                        payload: makeRankingBoardShareCardPayload()
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
                RankingBoardSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
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
        .task {
            await load()
        }
        .onChange(of: selectedYear) { _, _ in
            Task { await load() }
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

    @ViewBuilder
    private var contentBody: some View {
        if isLoading, detail == nil {
            ProgressView(LT("加载榜单中...", "Loading rankings...", "ランキングを読み込み中..."))
                .frame(maxWidth: .infinity, minHeight: 240)
        } else if let detail {
            rankingDetailContent(detail: detail)
        } else {
            ContentUnavailableView(LT("榜单为空", "榜单为空", "ランキングは空です"), systemImage: "list.number")
                .frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    private func rankingDetailContent(detail: RankingBoardDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            rankingHeader
            rankingGrid(entries: detail.entries)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var rankingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(board.title)
                .font(.title.weight(.black))
                .foregroundStyle(RaverTheme.primaryText)
            Text(board.subtitle ?? board.defaultSubtitle)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedYears, id: \.self) { year in
                            Button {
                                selectedYear = year
                            } label: {
                                Text(verbatim: String(year))
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedYear == year ? RaverTheme.accent : RaverTheme.card)
                            .foregroundStyle(selectedYear == year ? Color.white : RaverTheme.primaryText)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .id(year)
                        }
                    }
                }
                .onAppear {
                    scrollYearSelector(to: selectedYear, proxy: proxy, animated: false)
                }
                .onChange(of: selectedYear) { _, year in
                    scrollYearSelector(to: year, proxy: proxy, animated: true)
                }
                .onChange(of: sortedYears) { _, _ in
                    scrollYearSelector(to: selectedYear, proxy: proxy, animated: false)
                }
            }
        }
        .padding(16)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sortedYears: [Int] {
        let candidateYears = detail?.years ?? board.years
        return Array(Set(candidateYears)).sorted(by: >)
    }

    private func scrollYearSelector(
        to year: Int,
        proxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard sortedYears.contains(year) else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(year, anchor: .leading)
                }
            } else {
                proxy.scrollTo(year, anchor: .leading)
            }
        }
    }

    private func rankingGrid(entries: [RankingEntry]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(entries) { entry in
                Button {
                    if let festival = entry.festival {
                        appPush(.discover(.festivalDetail(festivalID: festival.id)))
                    } else if let dj = entry.dj {
                        appPush(.djDetail(djID: dj.id))
                    }
                } label: {
                    RankingEntryCard(entry: entry)
                }
                .buttonStyle(.plain)
                .disabled(entry.festival?.id == nil && entry.dj?.id == nil)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await djRankingRepository.fetchRankingBoardDetail(boardID: board.id, year: selectedYear)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func makeRankingBoardShareCardPayload() -> RankingBoardShareCardPayload {
        RankingBoardShareCardPayload(
            boardID: board.id,
            boardName: board.title,
            boardSubtitle: detail?.title.nilIfBlank ?? board.subtitle?.nilIfBlank ?? board.defaultSubtitle,
            year: selectedYear,
            coverImageURL: board.coverImageUrl,
            badgeText: LT("榜单", "Ranking", "ランキング")
        )
    }

    private func rankingBoardDeeplink(for payload: RankingBoardShareCardPayload) -> String {
        var components = URLComponents()
        components.scheme = "raver"
        components.host = "ranking-board"
        components.path = "/\(payload.boardID)"
        components.queryItems = [
            URLQueryItem(name: "year", value: String(payload.year)),
            URLQueryItem(name: "title", value: payload.boardName),
            URLQueryItem(name: "subtitle", value: payload.boardSubtitle),
            URLQueryItem(name: "coverImageURL", value: payload.coverImageURL)
        ]
        return components.string ?? "raver://ranking-board/\(payload.boardID)?year=\(payload.year)"
    }

    private func shareTarget() -> ShareTarget {
        let payload = makeRankingBoardShareCardPayload()
        let canonicalURL = "https://ravehub.top/ranking-board/\(payload.boardID)?year=\(payload.year)"
        return ShareTarget(
            type: .rankingBoard,
            id: payload.boardID,
            title: payload.boardName,
            subtitle: payload.boardSubtitle,
            imageURL: payload.coverImageURL,
            canonicalURL: canonicalURL,
            deepLink: rankingBoardDeeplink(for: payload),
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
        _ payload: RankingBoardShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.shareMessageRepository.sendRankingBoardCardMessage(
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
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                errorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ共有連携は未接続です。")
            }
        ]
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        [
            SharePanelQuickAction(
                title: LT("复制链接", "Copy Link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                Task { await copyRankingBoardShareLink() }
            },
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openRankingBoardPoster() }
            }
        ]
    }

    @MainActor
    private func copyRankingBoardShareLink() async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: shareTarget())
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("链接已复制", "Link copied", "リンクをコピーしました")
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openRankingBoardPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(), channel: "view_poster")
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
                        hintText: LT("榜单海报由分享系统统一生成，标题、摘要和二维码都会跟随短链保持一致。", "Ranking posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "ランキング海報は共有システムで生成され、タイトル、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
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
}

private struct RankingEntryCard: View {
    let entry: RankingEntry

    var body: some View {
        ZStack {
            GeometryReader { geo in
                entryImage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.22), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    Spacer()
                    Text(deltaLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(deltaColor.opacity(0.88))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                Spacer()
            }

            HStack {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text("\(entry.rank)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                        )
                }
                .padding(.leading, 8)
                .padding(.bottom, 8)
                Spacer()
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 10) {
                    Spacer(minLength: 46)

                    Text((entry.festival?.name ?? entry.name).uppercased())
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.trailing, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var entryImage: some View {
        if let festivalBackground = AppConfig.resolvedURLString(entry.festival?.backgroundUrl),
           URL(string: festivalBackground) != nil {
            ImageLoaderView(urlString: festivalBackground)
                .background(fallbackImage)
        } else if let festivalAvatar = AppConfig.resolvedURLString(entry.festival?.avatarUrl),
                  URL(string: festivalAvatar) != nil {
            ImageLoaderView(urlString: festivalAvatar)
                .background(fallbackImage)
        } else if let avatar = AppConfig.resolvedDJAvatarURLString(entry.dj?.avatarMediumUrl ?? entry.dj?.avatarUrl, size: .medium),
                  URL(string: highResAvatarURL(avatar)) != nil {
            ImageLoaderView(urlString: highResAvatarURL(avatar))
                .background(fallbackImage)
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.10, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String((entry.festival?.name ?? entry.name).prefix(2)).uppercased())
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var deltaLabel: String {
        guard let delta = entry.delta else { return "—" }
        if delta > 0 { return "▲ \(delta)" }
        if delta < 0 { return "▼ \(abs(delta))" }
        return "• 0"
    }

    private var deltaColor: Color {
        guard let delta = entry.delta else { return Color.gray }
        if delta > 0 { return Color.green }
        if delta < 0 { return Color.red }
        return Color.gray
    }
}

extension RankingBoard {
    var defaultSubtitle: String {
        switch id {
        case "djmag":
            return LT("全球电子音乐最有影响力榜单之一", "One of the most influential global electronic music rankings", "世界で最も影響力のある電子音楽ランキングの一つ")
        case "dongye":
            return LT("中文圈 DJ 热度与影响力榜单", "Popularity and influence ranking for Chinese-speaking DJs", "中国語圏DJの人気と影響力ランキング")
        default:
            return LT("各大榜单年度排名与升降变化", "Annual ranking movements across major charts", "主要ランキングの年間順位と変動")
        }
    }

    var shortMark: String {
        switch id {
        case "djmag":
            return "TOP"
        case "dongye":
            return "东野"
        default:
            return String(title.prefix(3)).uppercased()
        }
    }
}
