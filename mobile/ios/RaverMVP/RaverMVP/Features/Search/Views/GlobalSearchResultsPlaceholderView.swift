import SwiftUI

struct GlobalSearchResultsView: View {
    let query: String
    let initialTab: GlobalSearchTab?

    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: GlobalSearchResultsViewModel
    @State private var selectedTab: GlobalSearchTab
    @State private var searchText: String
    @FocusState private var isSearchFocused: Bool

    init(query: String, initialTab: GlobalSearchTab? = nil, service: WebFeatureService) {
        self.query = query
        self.initialTab = initialTab
        _viewModel = StateObject(wrappedValue: GlobalSearchResultsViewModel(query: query, service: service))
        _searchText = State(initialValue: query)
        _selectedTab = State(initialValue: initialTab ?? .all)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            RaverScrollableTabPager(
                items: tabItems,
                selection: $selectedTab,
                tabSpacing: 24,
                tabHorizontalPadding: 16,
                dividerColor: .gray.opacity(0.26),
                indicatorColorProvider: { $0.themeColor },
                showsDivider: false,
                indicatorHeight: 2.6,
                tabFont: .system(size: 14, weight: .regular)
            ) { tab in
                tabContent(for: tab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("搜索", "Search"))
        .onAppear {
            viewModel.loadInitial()
        }
        .onChange(of: viewModel.query) { _, newValue in
            searchText = newValue
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSearchFocused ? RaverTheme.accent : RaverTheme.secondaryText)

                TextField(
                    L("搜索活动、资讯、DJ、Sets、榜单、打分、圈子内容", "Search events, news, DJs, sets, rankings, ratings, posts"),
                    text: $searchText
                )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit {
                        submitSearch()
                    }
                    .accessibilityIdentifier("globalSearch.results.input")
                    .accessibilityLabel(L("搜索关键词", "Search query"))

                Spacer(minLength: 0)

                if !trimmedSearchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("清空关键词", "Clear query"))
                    .accessibilityIdentifier("globalSearch.results.clear")
                }

                Button {
                    submitSearch()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            RaverTheme.accent.opacity(canSubmitSearch ? 1 : 0.42),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmitSearch)
                .accessibilityLabel(L("重新搜索", "Search again"))
                .accessibilityIdentifier("globalSearch.results.submit")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSearchFocused ? RaverTheme.accent.opacity(0.55) : RaverTheme.cardBorder, lineWidth: 1)
            )

            Text(L("结果按相关性优先排序，部分分类可单独下拉刷新。", "Results are sorted by relevance. Pull individual tabs to refresh."))
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var tabItems: [RaverScrollableTabItem<GlobalSearchTab>] {
        GlobalSearchTab.allCases.map { tab in
            RaverScrollableTabItem(id: tab, title: tab.title)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: GlobalSearchTab) -> some View {
        switch viewModel.phaseByTab[tab] ?? .idle {
        case .idle, .loading:
            GlobalSearchLoadingState()
        case .failed(let message):
            GlobalSearchErrorState(message: message) {
                viewModel.retry(tab: tab)
            }
        case .empty:
            GlobalSearchEmptyState(query: viewModel.query)
        case .loaded:
            if tab == .all {
                allTab
            } else {
                domainTab(tab)
            }
        }
    }

    private var allTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                GlobalSearchSummaryStrip(
                    query: viewModel.query,
                    totalCount: viewModel.totalCount,
                    hasPartialFailures: !viewModel.partialFailureTabs.isEmpty
                )

                if !viewModel.topMatches.isEmpty {
                    section(
                        title: L("最佳匹配", "Top Matches"),
                        items: viewModel.topMatches,
                        showsViewAll: false,
                        targetTab: nil
                    )
                }

                ForEach(viewModel.previewTabs, id: \.self) { tab in
                    let items = viewModel.previewItems(for: tab)
                    section(
                        title: tab.title,
                        items: items,
                        showsViewAll: viewModel.count(for: tab) > items.count,
                        targetTab: tab
                    )
                }

                if viewModel.topMatches.isEmpty {
                    GlobalSearchEmptyState(query: viewModel.query)
                }

                partialFailureRows
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh(tab: .all)
        }
    }

    private func domainTab(_ tab: GlobalSearchTab) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L("\(tab.title)结果", "\(tab.title) Results"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Text("\(viewModel.count(for: tab))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tab.themeColor)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(tab.themeColor.opacity(0.12), in: Capsule())
                }
                .padding(.bottom, 4)

                ForEach(viewModel.items(for: tab)) { item in
                    GlobalSearchResultCard(item: item, onOpen: open)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh(tab: tab)
        }
    }

    private func section(
        title: String,
        items: [GlobalSearchItem],
        showsViewAll: Bool,
        targetTab: GlobalSearchTab?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                if showsViewAll, let targetTab {
                    Button {
                        selectedTab = targetTab
                    } label: {
                        Text(L("查看全部", "View All"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(targetTab.themeColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("查看全部\(targetTab.title)结果", "View all \(targetTab.title) results"))
                }
            }

            ForEach(items) { item in
                GlobalSearchResultCard(item: item, onOpen: open)
            }
        }
    }

    @ViewBuilder
    private var partialFailureRows: some View {
        if !viewModel.partialFailureTabs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(viewModel.partialFailureTabs).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { tab in
                    Button {
                        viewModel.retry(tab: tab)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption.weight(.bold))
                            Text(L("\(tab.title)结果加载失败，点此重试", "\(tab.title) results failed. Tap to retry."))
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(Color.orange)
                        .padding(10)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("globalSearch.partialFailure.\(tab.rawValue)")
                }
            }
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitSearch: Bool {
        !trimmedSearchText.isEmpty && trimmedSearchText != viewModel.query
    }

    private func submitSearch() {
        let keyword = trimmedSearchText
        guard !keyword.isEmpty else { return }
        viewModel.submitSearch(keyword)
        isSearchFocused = false
    }

    private func open(_ item: GlobalSearchItem) {
        guard let route = item.appRoute() else { return }
        GlobalSearchTelemetry.resultOpened(item)
        appPush(route)
    }
}

typealias GlobalSearchResultsPlaceholderView = GlobalSearchResultsView
