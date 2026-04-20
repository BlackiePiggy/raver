import SwiftUI

struct DiscoverHomeView: View {
    fileprivate enum Section: String, CaseIterable, Identifiable {
        case recommend
        case events
        case news
        case djs
        case sets
        case learn

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recommend: return L("推荐", "Picks")
            case .events: return L("活动", "Events")
            case .news: return L("资讯", "News")
            case .djs: return L("DJ", "DJ")
            case .sets: return L("Sets", "Sets")
            case .learn: return L("Wiki", "Wiki")
            }
        }

        var themeColor: Color {
            switch self {
            case .recommend: return Color(red: 0.27, green: 0.85, blue: 0.82)
            case .events: return Color(red: 0.97, green: 0.54, blue: 0.21)
            case .news: return Color(red: 0.98, green: 0.62, blue: 0.22)
            case .djs: return Color(red: 0.44, green: 0.78, blue: 0.33)
            case .sets: return Color(red: 0.30, green: 0.67, blue: 0.97)
            case .learn: return Color(red: 0.76, green: 0.47, blue: 0.95)
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
        case .learn:
            LearnModuleView()
        }
    }

}
