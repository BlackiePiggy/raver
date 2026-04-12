import SwiftUI

struct NewsModuleView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.discoverPush) private var discoverPush

    private let onHorizontalDragStateChanged: ((Bool) -> Void)?

    @State private var articles: [DiscoverNewsArticle] = []
    @State private var nextCursor: String?
    @State private var selectedCategory: DiscoverNewsCategory = .all
    @State private var isLoading = false
    @State private var searchKeyword = ""
    @State private var errorMessage: String?
    @State private var isSelectorDragging = false

    init(onHorizontalDragStateChanged: ((Bool) -> Void)? = nil) {
        self.onHorizontalDragStateChanged = onHorizontalDragStateChanged
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
            await reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverNewsDidPublish)) { _ in
            Task { await reload() }
        }
        .onDisappear {
            notifySelectorDragging(false)
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
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
                            Text(category.rawValue)
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
                discoverPush(
                    .searchInput(
                        domain: .news,
                        initialQuery: searchKeyword
                    )
                )
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(RaverTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(RaverTheme.secondaryText.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

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
            if isLoading && articles.isEmpty {
                ProgressView(LL("资讯加载中..."))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            } else if displayedArticles.isEmpty {
                VStack(spacing: 12) {
                    ContentUnavailableView(LL("暂无资讯"), systemImage: "newspaper")
                    Text(LL("点击右上角“发布资讯”发布图文内容后会显示在这里。"))
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
                            DiscoverNewsRow(article: article)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())

                        if index < displayedArticles.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if nextCursor != nil {
                        Button(LL("加载更多资讯")) {
                            Task { await loadMore() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
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
        isLoading = true
        defer { isLoading = false }

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
            articles = deduped
            nextCursor = fetchedPageCursor
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
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
            nextCursor = fetchedPageCursor
        } catch {
            errorMessage = error.userFacingMessage
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
