import SwiftUI

struct GlobalSearchResultsPlaceholderView: View {
    let query: String
    let initialTab: GlobalSearchTab?

    @State private var selectedTab: GlobalSearchTab
    @State private var searchText: String
    @State private var submittedQuery: String
    @FocusState private var isSearchFocused: Bool

    init(query: String, initialTab: GlobalSearchTab? = nil) {
        self.query = query
        self.initialTab = initialTab
        _searchText = State(initialValue: query)
        _submittedQuery = State(initialValue: query)
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
                tabFont: .system(size: 18, weight: .regular)
            ) { tab in
                placeholderContent(for: tab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("搜索", "Search"))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSearchFocused ? RaverTheme.accent : RaverTheme.secondaryText)

                TextField(
                    L("搜索活动、资讯、DJ、Sets、榜单、打分、圈子内容", "Search events, news, DJs, sets, rankings, ratings, posts"),
                    text: $searchText
                )
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit {
                        submitSearch()
                    }

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
                }

                Button {
                    submitSearch()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            RaverTheme.accent.opacity(canSubmitSearch ? 1 : 0.42),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmitSearch)
                .accessibilityLabel(L("重新搜索", "Search again"))
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSearchFocused ? RaverTheme.accent.opacity(0.55) : RaverTheme.cardBorder, lineWidth: 1)
            )

            Text(L("聚合搜索结果页将在 Phase 2 接入完整内容。", "The aggregated results page will be completed in Phase 2."))
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

    private func placeholderContent(for tab: GlobalSearchTab) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(tab.themeColor)
                .frame(width: 70, height: 70)
                .background(tab.themeColor.opacity(0.12), in: Circle())

            Text(tab.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)

            Text(L("这里会展示 “\(submittedQuery)” 的\(tab.title)搜索结果。", "This tab will show \(tab.title) results for \"\(submittedQuery)\"."))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitSearch: Bool {
        !trimmedSearchText.isEmpty && trimmedSearchText != submittedQuery
    }

    private func submitSearch() {
        let keyword = trimmedSearchText
        guard !keyword.isEmpty else { return }
        submittedQuery = keyword
        searchText = keyword
        isSearchFocused = false
    }
}

private extension GlobalSearchTab {
    var themeColor: Color {
        switch self {
        case .all: return RaverTheme.accent
        case .events: return Color(red: 0.97, green: 0.54, blue: 0.21)
        case .news: return Color(red: 0.98, green: 0.62, blue: 0.22)
        case .djs: return Color(red: 0.44, green: 0.78, blue: 0.33)
        case .sets: return Color(red: 0.30, green: 0.67, blue: 0.97)
        case .rankings: return Color(red: 0.98, green: 0.71, blue: 0.22)
        case .ratings: return Color(red: 0.92, green: 0.42, blue: 0.80)
        case .posts: return Color(red: 0.95, green: 0.30, blue: 0.38)
        case .wiki: return Color(red: 0.76, green: 0.47, blue: 0.95)
        case .peopleSquads: return Color(red: 0.96, green: 0.45, blue: 0.28)
        }
    }
}
