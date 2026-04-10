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
    case djDetail(djID: String)
    case labelDetail(label: LearnLabel)
    case festivalDetail(festival: LearnFestival)
    case setDetail(setID: String)
    case newsDetail(article: DiscoverNewsArticle)
    case learnFestivalCreate
    case learnFestivalEdit(festival: LearnFestival)
    case newsPublish
    case setCreate
    case setEdit(set: WebDJSet)
    case eventCreate
    case eventEdit(event: WebEvent)
    case eventDetail(eventID: String)
}

extension Notification.Name {
    static let discoverEventDidSave = Notification.Name("discoverEventDidSave")
    static let discoverNewsDidPublish = Notification.Name("discoverNewsDidPublish")
    static let discoverSetDidSave = Notification.Name("discoverSetDidSave")
    static let discoverFestivalDidSave = Notification.Name("discoverFestivalDidSave")
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

    case .searchResults(let domain, let query, let preferredWikiSectionRaw):
        switch domain {
        case .events:
            EventsSearchResultsView(
                viewModel: EventsSearchResultsViewModel(
                    query: query,
                    repository: appContainer.discoverEventsRepository
                )
            )

        case .news:
            NewsSearchResultsView(
                viewModel: NewsSearchResultsViewModel(
                    query: query,
                    repository: appContainer.discoverNewsRepository
                )
            )

        case .djs:
            DJsSearchResultsView(
                viewModel: DJsSearchResultsViewModel(
                    query: query,
                    repository: appContainer.discoverDJsRepository
                )
            )

        case .sets:
            SetsSearchResultsView(
                viewModel: SetsSearchResultsViewModel(
                    query: query,
                    repository: appContainer.discoverSetsRepository
                )
            )

        case .wiki:
            WikiSearchResultsView(
                viewModel: WikiSearchResultsViewModel(
                    query: query,
                    repository: appContainer.discoverWikiRepository
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
        }

    case .djDetail(let djID):
        DJDetailView(djID: djID)

    case .labelDetail(let label):
        LearnLabelDetailView(label: label)

    case .festivalDetail(let festival):
        LearnFestivalDetailView(festival: festival)

    case .setDetail(let setID):
        DJSetDetailView(setID: setID)

    case .newsDetail(let article):
        DiscoverNewsDetailView(article: article)

    case .eventDetail(let eventID):
        EventDetailView(eventID: eventID)

    case .eventCreate:
        EventEditorView(mode: .create) {
            NotificationCenter.default.post(name: .discoverEventDidSave, object: nil)
        }

    case .eventEdit(let event):
        EventEditorView(mode: .edit(event)) {
            NotificationCenter.default.post(name: .discoverEventDidSave, object: event.id)
        }

    case .newsPublish:
        DiscoverNewsPublishSheet { draft in
            _ = try await appContainer.discoverNewsRepository.publish(draft: draft)
            NotificationCenter.default.post(name: .discoverNewsDidPublish, object: nil)
        }

    case .learnFestivalCreate:
        LearnFestivalEditorView(mode: .create) { festival in
            NotificationCenter.default.post(name: .discoverFestivalDidSave, object: festival.id)
        }

    case .learnFestivalEdit(let festival):
        LearnFestivalEditorView(mode: .edit(festival)) { updated in
            NotificationCenter.default.post(name: .discoverFestivalDidSave, object: updated.id)
        }

    case .setCreate:
        DJSetEditorView(mode: .create) {
            NotificationCenter.default.post(name: .discoverSetDidSave, object: nil)
        }

    case .setEdit(let set):
        DJSetEditorView(mode: .edit(set)) {
            NotificationCenter.default.post(name: .discoverSetDidSave, object: set.id)
        }
    }
}
