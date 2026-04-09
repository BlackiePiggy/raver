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
    case eventDetail(eventID: String)
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

}

@MainActor
struct DiscoverRouteDestinationView: View {
    @EnvironmentObject private var appContainer: AppContainer

    let route: DiscoverRoute
    let push: (DiscoverRoute) -> Void

    var body: some View {
        makeDiscoverRouteDestination(route, push: push, appContainer: appContainer)
    }
}

@MainActor
@ViewBuilder
func makeDiscoverRouteDestination(
    _ route: DiscoverRoute,
    push: @escaping (DiscoverRoute) -> Void,
    appContainer: AppContainer
) -> some View {
    switch route {
    case .searchInput(let domain, let initialQuery, let preferredWikiSectionRaw):
        DiscoverFullScreenSearchInputView(
            title: domain.searchTitle,
            placeholder: domain.searchPlaceholder,
            initialQuery: initialQuery
        ) { keyword in
            push(
                .searchResults(
                    domain: domain,
                    query: keyword,
                    preferredWikiSectionRaw: preferredWikiSectionRaw
                )
            )
        }
        .toolbar(.hidden, for: .tabBar)

    case .searchResults(let domain, let query, let preferredWikiSectionRaw):
        switch domain {
        case .events:
            EventsSearchResultsView(
                viewModel: EventsSearchResultsViewModel(
                    query: query,
                    service: appContainer.webService
                )
            )
            .toolbar(.hidden, for: .tabBar)

        case .news:
            NewsSearchResultsView(
                viewModel: NewsSearchResultsViewModel(
                    query: query,
                    socialService: appContainer.socialService
                )
            )
            .toolbar(.hidden, for: .tabBar)

        case .djs:
            DJsSearchResultsView(
                viewModel: DJsSearchResultsViewModel(
                    query: query,
                    service: appContainer.webService
                )
            )
                .toolbar(.hidden, for: .tabBar)

        case .sets:
            SetsSearchResultsView(
                viewModel: SetsSearchResultsViewModel(
                    query: query,
                    service: appContainer.webService
                )
            )
                .toolbar(.hidden, for: .tabBar)

        case .wiki:
            WikiSearchResultsView(
                viewModel: WikiSearchResultsViewModel(
                    query: query,
                    service: appContainer.webService
                ),
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
            .toolbar(.hidden, for: .tabBar)
        }

    case .eventDetail(let eventID):
        EventDetailView(eventID: eventID)
            .toolbar(.hidden, for: .tabBar)
    }
}
