import SwiftUI

enum DiscoverSearchDomain: String, Hashable {
    case events
    case news
    case djs
    case sets
    case wiki
}

enum DiscoverRoute: Hashable {
    case searchInput(
        domain: DiscoverSearchDomain,
        initialQuery: String = "",
        preferredWikiSectionRaw: String? = nil
    )
    case searchResults(
        domain: DiscoverSearchDomain,
        query: String,
        preferredWikiSectionRaw: String? = nil
    )
}

struct DiscoverPushKey: EnvironmentKey {
    static let defaultValue: (DiscoverRoute) -> Void = { _ in }
}

extension EnvironmentValues {
    var discoverPush: (DiscoverRoute) -> Void {
        get { self[DiscoverPushKey.self] }
        set { self[DiscoverPushKey.self] = newValue }
    }
}

extension DiscoverSearchDomain {
    var searchTitle: String {
        switch self {
        case .events:
            return L("搜索活动", "Search Events")
        case .news:
            return L("搜索资讯", "Search News")
        case .djs:
            return L("搜索 DJ / 榜单", "Search DJs / Rankings")
        case .sets:
            return L("搜索 Sets", "Search Sets")
        case .wiki:
            return L("搜索 Wiki", "Search Wiki")
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .events:
            return L("输入活动名称 / 城市 / 国家", "Enter event name / city / country")
        case .news:
            return L("输入资讯标题 / 来源 / 关键词", "Enter title / source / keyword")
        case .djs:
            return L("输入 DJ 名称或榜单关键词", "Enter DJ name or ranking keyword")
        case .sets:
            return L("输入 Sets 标题 / DJ 名称", "Enter set title / DJ name")
        case .wiki:
            return L("输入厂牌 / 电音节关键词", "Enter label / festival keyword")
        }
    }

    @ViewBuilder
    func resultsView(query: String, preferredWikiSectionRaw: String?) -> some View {
        switch self {
        case .events:
            EventsSearchResultsView(query: query)
        case .news:
            NewsSearchResultsView(query: query)
        case .djs:
            DJsSearchResultsView(query: query)
        case .sets:
            SetsSearchResultsView(query: query)
        case .wiki:
            WikiSearchResultsView(
                query: query,
                preferredSection: {
                    guard
                        let raw = preferredWikiSectionRaw,
                        let section = LearnModuleSection(rawValue: raw)
                    else {
                        return .labels
                    }
                    return section
                }()
            )
        }
    }
}

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
            case .recommend: return L("推荐", "Recommend")
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
    @State private var pageProgress: CGFloat = 0
    @State private var tabFrames: [Section: CGRect] = [:]
    @State private var pagerWidth: CGFloat = 1
    @State private var navPath: [DiscoverRoute] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                topTabs

                GeometryReader { proxy in
                    TabView(selection: $section) {
                        ForEach(Section.allCases) { item in
                            pageView(for: item)
                                .tag(item)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: DiscoverPageOffsetPreferenceKey.self,
                                            value: [item: geo.frame(in: .named("DiscoverPager")).minX]
                                        )
                                    }
                                )
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .coordinateSpace(name: "DiscoverPager")
                    .onAppear {
                        pagerWidth = max(1, proxy.size.width)
                        pageProgress = CGFloat(selectedIndex(for: section))
                    }
                    .onChange(of: proxy.size.width) { _, newValue in
                        pagerWidth = max(1, newValue)
                    }
                    .onChange(of: section) { _, newValue in
                        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                            pageProgress = CGFloat(selectedIndex(for: newValue))
                        }
                    }
                    .onPreferenceChange(DiscoverPageOffsetPreferenceKey.self) { values in
                        updatePageProgress(with: values)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: DiscoverRoute.self) { route in
                routeDestination(route)
            }
        }
        .background(RaverTheme.background)
        .environment(\.discoverPush) { route in
            navPath.append(route)
        }
    }

    private var topTabs: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(Section.allCases) { item in
                        Button {
                            selectSection(item)
                        } label: {
                            Text(item.title)
                                .font(.system(size: 18, weight: section == item ? .semibold : .regular))
                                .foregroundStyle(section == item ? RaverTheme.primaryText : RaverTheme.secondaryText)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        .id(item)
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                selectSection(item)
                            }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: DiscoverTabFramePreferenceKey.self,
                                    value: [item: geo.frame(in: .named("DiscoverTabs"))]
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 3)
            }
            .coordinateSpace(name: "DiscoverTabs")
            .overlay(alignment: .bottomLeading) {
                if let indicator = indicatorRect {
                    Capsule()
                        .fill(currentIndicatorColor)
                        .frame(width: indicator.width, height: 3)
                        .offset(x: indicator.minX, y: 0)
                        .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.75), value: indicator.minX)
                        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.72), value: indicator.width)
                        .allowsHitTesting(false)
                }
            }
            .background(RaverTheme.background)
            .onPreferenceChange(DiscoverTabFramePreferenceKey.self) { value in
                tabFrames = value
            }
            .onChange(of: section) { _, newSection in
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.84)) {
                    scrollProxy.scrollTo(newSection, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func pageView(for section: Section) -> some View {
        switch section {
        case .recommend:
            RecommendEventsModuleView()
        case .events:
            EventsModuleView()
        case .news:
            NewsModuleView()
        case .djs:
            DJsModuleView()
        case .sets:
            SetsModuleView()
        case .learn:
            LearnModuleView()
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: DiscoverRoute) -> some View {
        switch route {
        case .searchInput(let domain, let initialQuery, let preferredWikiSectionRaw):
            DiscoverFullScreenSearchInputView(
                title: domain.searchTitle,
                placeholder: domain.searchPlaceholder,
                initialQuery: initialQuery
            ) { keyword in
                navPath.append(
                    .searchResults(
                        domain: domain,
                        query: keyword,
                        preferredWikiSectionRaw: preferredWikiSectionRaw
                    )
                )
            }
            .toolbar(.hidden, for: .tabBar)

        case .searchResults(let domain, let query, let preferredWikiSectionRaw):
            domain.resultsView(query: query, preferredWikiSectionRaw: preferredWikiSectionRaw)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private var currentIndicatorColor: Color {
        let idx = max(0, min(Section.allCases.count - 1, Int(round(pageProgress))))
        return Section.allCases[idx].themeColor
    }

    private var indicatorRect: CGRect? {
        guard !tabFrames.isEmpty else { return nil }
        let count = Section.allCases.count
        guard count > 0 else { return nil }

        let clamped = min(max(pageProgress, 0), CGFloat(count - 1))
        let leftIndex = Int(floor(clamped))
        let rightIndex = min(leftIndex + 1, count - 1)
        let t = clamped - CGFloat(leftIndex)

        let leftSection = Section.allCases[leftIndex]
        let rightSection = Section.allCases[rightIndex]
        guard let leftFrame = tabFrames[leftSection], let rightFrame = tabFrames[rightSection] else {
            return nil
        }

        let baseX = leftFrame.minX + (rightFrame.minX - leftFrame.minX) * t
        let baseWidth = leftFrame.width + (rightFrame.width - leftFrame.width) * t
        let elastic = (1 - abs(0.5 - t) * 2) * 16
        return CGRect(x: baseX - elastic * 0.2, y: 0, width: baseWidth + elastic, height: 3)
    }

    private func selectedIndex(for section: Section) -> Int {
        Section.allCases.firstIndex(of: section) ?? 0
    }

    private func selectSection(_ item: Section) {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.84)) {
            section = item
            pageProgress = CGFloat(selectedIndex(for: item))
        }
    }

    private func updatePageProgress(with offsets: [Section: CGFloat]) {
        guard pagerWidth > 1 else { return }
        let progressCandidates: [(progress: CGFloat, distance: CGFloat)] = Section.allCases.enumerated().compactMap { index, item in
            guard let minX = offsets[item] else { return nil }
            let progress = CGFloat(index) - (minX / pagerWidth)
            return (progress, abs(minX))
        }

        guard let best = progressCandidates.min(by: { $0.distance < $1.distance }) else { return }
        let clamped = min(max(best.progress, 0), CGFloat(max(0, Section.allCases.count - 1)))
        pageProgress = clamped
    }
}

private struct DiscoverTabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [DiscoverHomeView.Section: CGRect] = [:]

    static func reduce(value: inout [DiscoverHomeView.Section: CGRect], nextValue: () -> [DiscoverHomeView.Section: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct DiscoverPageOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [DiscoverHomeView.Section: CGFloat] = [:]

    static func reduce(value: inout [DiscoverHomeView.Section: CGFloat], nextValue: () -> [DiscoverHomeView.Section: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
