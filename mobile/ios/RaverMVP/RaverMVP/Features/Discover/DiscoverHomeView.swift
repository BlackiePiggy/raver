import SwiftUI

struct DiscoverHomeView: View {
    fileprivate enum Section: String, CaseIterable, Identifiable {
        case recommend
        case events
        case news
        case djs
        case sets
        case rankings
        case organizers
        case labels
        case genres

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recommend: return LT("推荐", "Picks", "おすすめ")
            case .events: return LT("活动", "Events", "イベント")
            case .news: return LT("资讯", "News", "ニュース")
            case .djs: return LT("DJ", "DJ", "DJ")
            case .sets: return LT("Sets", "Sets", "Sets")
            case .rankings: return LT("榜单", "Rankings", "ランキング")
            case .organizers: return LT("主办方", "Organizers", "主催")
            case .labels: return LT("厂牌", "Labels", "レーベル")
            case .genres: return LT("流派", "Genres", "ジャンル")
            }
        }

        var themeColor: Color {
            switch self {
            case .recommend: return Color(red: 0.27, green: 0.85, blue: 0.82)
            case .events: return Color(red: 0.97, green: 0.54, blue: 0.21)
            case .news: return Color(red: 0.98, green: 0.62, blue: 0.22)
            case .djs: return Color(red: 0.44, green: 0.78, blue: 0.33)
            case .sets: return Color(red: 0.30, green: 0.67, blue: 0.97)
            case .rankings: return Color(red: 0.76, green: 0.47, blue: 0.95)
            case .organizers: return Color(red: 0.89, green: 0.39, blue: 0.58)
            case .labels: return Color(red: 0.42, green: 0.57, blue: 0.96)
            case .genres: return Color(red: 0.24, green: 0.79, blue: 0.68)
            }
        }

    }

    @State private var section: Section = .recommend
    @State private var isChildHorizontalDragging = false

    var body: some View {
        RaverScrollableTabPager(
            items: tabItems,
            selection: $section,
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColor: RaverTheme.primaryText,
            indicatorColorProvider: { $0.themeColor },
            isPageSwipeDisabled: isChildHorizontalDragging,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 18, weight: .regular)
        ) { tab in
            pageView(for: tab)
        }
        .background(RaverTheme.background)
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: section) { _, newValue in
            if newValue != .news, newValue != .events, newValue != .recommend, isChildHorizontalDragging {
                isChildHorizontalDragging = false
            }
        }
    }

    private var tabItems: [RaverScrollableTabItem<Section>] {
        Section.allCases.map { item in
            RaverScrollableTabItem(id: item, title: item.title)
        }
    }

    @ViewBuilder
    private func pageView(for section: Section) -> some View {
        switch section {
        case .recommend:
            DiscoverRecommendEventsRootView(
                onHorizontalDragStateChanged: { isDragging in
                    guard isChildHorizontalDragging != isDragging else { return }
                    isChildHorizontalDragging = isDragging
                },
                onRequestMoveToNextDiscoverSection: {
                    isChildHorizontalDragging = false
                    self.section = .events
                }
            )
        case .events:
            DiscoverEventsRootView(
                onHorizontalDragStateChanged: { isDragging in
                    guard isChildHorizontalDragging != isDragging else { return }
                    isChildHorizontalDragging = isDragging
                }
            )
        case .news:
            NewsModuleView(
                onHorizontalDragStateChanged: { isDragging in
                    guard isChildHorizontalDragging != isDragging else { return }
                    isChildHorizontalDragging = isDragging
                }
            )
        case .djs:
            DiscoverDJsRootView(
                onHorizontalDragStateChanged: { isDragging in
                    guard isChildHorizontalDragging != isDragging else { return }
                    isChildHorizontalDragging = isDragging
                }
            )
        case .sets:
            SetsModuleView()
        case .rankings:
            LearnModuleView(initialSection: .rankings, showsSectionTabs: false)
        case .organizers:
            LearnModuleView(initialSection: .festivals, showsSectionTabs: false)
        case .labels:
            LearnModuleView(initialSection: .labels, showsSectionTabs: false)
        case .genres:
            LearnModuleView(initialSection: .genres, showsSectionTabs: false)
        }
    }

}
