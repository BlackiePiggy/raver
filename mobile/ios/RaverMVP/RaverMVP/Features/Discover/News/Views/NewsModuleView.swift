import SwiftUI

struct NewsModuleView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.discoverPush) private var discoverPush
    private let onHorizontalDragStateChanged: ((Bool) -> Void)?
    private let isActive: Bool

    @State private var articles: [DiscoverNewsArticle] = []
    @State private var nextCursor: String?
    @State private var selectedCategory: DiscoverNewsCategory = .all
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var bannerMessage: String?
    @State private var isSelectorDragging = false
    @State private var hasTriggeredInitialLoad = false

    init(onHorizontalDragStateChanged: ((Bool) -> Void)? = nil, isActive: Bool = true) {
        self.onHorizontalDragStateChanged = onHorizontalDragStateChanged
        self.isActive = isActive
    }

    private var repository: DiscoverNewsRepository {
        appContainer.discoverNewsRepository
    }

    var body: some View {
        VStack(spacing: 0) {
            newsSelectorRow
            newsContentScrollView
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await triggerInitialLoadIfNeeded()
        }
        .onChange(of: isActive) { _, _ in
            Task { await triggerInitialLoadIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverNewsDidPublish)) { _ in
            Task { await reload() }
        }
        .onDisappear {
            notifySelectorDragging(false)
        }
    }

    @MainActor
    private func triggerInitialLoadIfNeeded() async {
        guard isActive else { return }
        guard !hasTriggeredInitialLoad else { return }
        hasTriggeredInitialLoad = true
        await reload()
    }

    private var newsSelectorRow: some View {
        HStack(spacing: 8) {
            HorizontalAxisLockedScrollView(
                showsIndicators: false,
                onDraggingChanged: { isDragging in
                    notifySelectorDragging(isDragging)
                }
            ) {
                HStack(spacing: 8) {
                    ForEach(DiscoverNewsCategory.allCases) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category
                            }
                        } label: {
                            Text(category.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedCategory == category ? .white : RaverTheme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedCategory == category ? category.badgeColor : RaverTheme.card)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 16)
            }
            .frame(height: 34)

            Button {
                discoverPush(.newsPublish)
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.51, blue: 0.18))
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(RaverTheme.background)
    }

    private var newsContentScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isRefreshing || bannerMessage != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if isRefreshing {
                            InlineLoadingBadge(title: LT("正在更新资讯", "Updating news", "ニュースを更新中"))
                        }
                        if let bannerMessage {
                            ScreenStatusBanner(
                                message: bannerMessage,
                                style: .error,
                                actionTitle: LT("重试", "Retry", "再試行")
                            ) {
                                Task { await reload() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                if phase == .idle || phase == .initialLoading {
                    FeedSkeletonView(count: 4)
                        .padding(.top, 16)
                } else if case .failure(let message) = phase {
                    ScreenErrorCard(
                        title: LT("资讯加载失败", "News Failed to Load", "ニュースの読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await reload() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                } else if case .offline(let message) = phase {
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message
                    ) {
                        Task { await reload() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                } else if displayedArticles.isEmpty {
                    VStack(spacing: 12) {
                        ContentUnavailableView(LT("暂无资讯", "暂无资讯", "ニュースはまだありません"), systemImage: "newspaper")
                        Text(LT("点击右上角“发布资讯”发布图文内容后会显示在这里。", "点击右上角“发布资讯”发布图文内容后会显示在这里。", "右上の「ニュースを公開」から画像付きコンテンツを投稿すると、ここに表示されます。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayedArticles.enumerated()), id: \.element.id) { index, article in
                            Button {
                                discoverPush(.newsDetail(articleID: article.id))
                            } label: {
                                DiscoverNewsRow(article: article, showsSummary: false)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())

                            if index < displayedArticles.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }

                        if nextCursor != nil {
                            Group {
                                if isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .padding(.vertical, 14)
                                        Spacer()
                                    }
                                } else {
                                    Color.clear
                                        .frame(height: 1)
                                }
                            }
                            .onAppear {
                                Task { await loadMore() }
                            }
                        }
                    }
                }
            }
            .raverTabBarBottomPadding(16)
        }
        .refreshable {
            await reload()
        }
    }

    private var displayedArticles: [DiscoverNewsArticle] {
        if selectedCategory == .all {
            return articles
        }
        return articles.filter { $0.category == selectedCategory }
    }

    @MainActor
    private func reload() async {
        guard !isLoading else { return }
        let hadContent = !articles.isEmpty
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            let targetCount = max(articles.count, 1)
            var cursor: String?
            var parsed: [DiscoverNewsArticle] = []
            var fetchedPageCursor: String?
            var fetchCount = 0

            repeat {
                let page = try await repository.fetchFeedPage(cursor: cursor)
                fetchedPageCursor = page.nextCursor
                parsed.append(contentsOf: page.items)
                cursor = fetchedPageCursor
                fetchCount += 1
            } while parsed.count < targetCount && fetchedPageCursor != nil && fetchCount < 20

            let deduped = deduplicatedArticles(parsed)
            articles = sortedArticles(deduped)
            nextCursor = fetchedPageCursor
            phase = articles.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            if error.isUserInitiatedCancellation {
                if !hadContent, case .initialLoading = phase {
                    phase = .idle
                }
                return
            }
            let message = error.userFacingMessage ?? LT("资讯加载失败，请稍后重试", "Failed to load news. Please try again later.", "ニュースを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    @MainActor
    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var cursor = nextCursor
            var parsed: [DiscoverNewsArticle] = []
            var fetchedPageCursor: String?
            var fetchCount = 0

            repeat {
                let page = try await repository.fetchFeedPage(cursor: cursor)
                fetchedPageCursor = page.nextCursor
                parsed.append(contentsOf: page.items)
                cursor = fetchedPageCursor
                fetchCount += 1
            } while parsed.isEmpty && fetchedPageCursor != nil && fetchCount < 3

            let existingIDs = Set(articles.map(\.id))
            let merged = parsed.filter { !existingIDs.contains($0.id) }
            articles.append(contentsOf: merged)
            articles = sortedArticles(deduplicatedArticles(articles))
            nextCursor = fetchedPageCursor
        } catch {
            if error.isUserInitiatedCancellation {
                return
            }
            bannerMessage = error.userFacingMessage ?? LT("更多资讯加载失败，请稍后重试", "Failed to load more news. Please try again later.", "さらにニュースを読み込めませんでした。時間をおいて再試行してください。")
        }
    }

    private func notifySelectorDragging(_ isDragging: Bool) {
        guard isSelectorDragging != isDragging else { return }
        isSelectorDragging = isDragging
        onHorizontalDragStateChanged?(isDragging)
    }

    private func deduplicatedArticles(_ items: [DiscoverNewsArticle]) -> [DiscoverNewsArticle] {
        var seen = Set<String>()
        var result: [DiscoverNewsArticle] = []
        result.reserveCapacity(items.count)

        for item in items where seen.insert(item.id).inserted {
            result.append(item)
        }
        return result
    }

    private func sortedArticles(_ items: [DiscoverNewsArticle]) -> [DiscoverNewsArticle] {
        items.sorted { lhs, rhs in
            if lhs.publishedAt != rhs.publishedAt {
                return lhs.publishedAt > rhs.publishedAt
            }
            return lhs.id > rhs.id
        }
    }

}

struct DiscoverNewsRow: View {
    let article: DiscoverNewsArticle
    let showsSummary: Bool

    init(article: DiscoverNewsArticle, showsSummary: Bool = true) {
        self.article = article
        self.showsSummary = showsSummary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(article.category.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(article.category.badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(article.category.badgeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(article.source)
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Text(article.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if showsSummary && !article.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(article.summary)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Text(article.publishedAt.appLocalizedYMDHMText())
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                    Label("\(article.replyCount)", systemImage: "bubble.left")
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .labelStyle(.titleAndIcon)
                }
            }

            Spacer(minLength: 0)

            newsCover
                .frame(width: 122, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var newsCover: some View {
        ImageLoaderView(urlString: article.coverImageURL, resizingMode: .fill)
            .background(fallbackCover)
    }

    private var fallbackCover: some View {
        LinearGradient(
            colors: [Color(red: 0.14, green: 0.17, blue: 0.21), Color(red: 0.11, green: 0.13, blue: 0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "newspaper.fill")
                .font(.title3)
                .foregroundStyle(RaverTheme.secondaryText.opacity(0.8))
        )
    }
}
