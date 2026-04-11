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
    case labelDetail(labelID: String)
    case festivalDetail(festivalID: String)
    case setDetail(setID: String)
    case newsDetail(articleID: String)
    case learnFestivalCreate
    case learnFestivalEdit(festivalID: String)
    case newsPublish
    case setCreate
    case setEdit(setID: String)
    case eventCreate
    case eventEdit(eventID: String)
}

extension Notification.Name {
    static let discoverEventDidSave = Notification.Name("discoverEventDidSave")
    static let discoverNewsDidPublish = Notification.Name("discoverNewsDidPublish")
    static let discoverSetDidSave = Notification.Name("discoverSetDidSave")
    static let discoverFestivalDidSave = Notification.Name("discoverFestivalDidSave")
    static let discoverRatingUnitDidUpdate = Notification.Name("discoverRatingUnitDidUpdate")
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

    case .labelDetail(let labelID):
        DiscoverLabelDetailLoaderView(labelID: labelID, repository: appContainer.discoverWikiRepository)

    case .festivalDetail(let festivalID):
        DiscoverFestivalDetailLoaderView(festivalID: festivalID, repository: appContainer.discoverWikiRepository)

    case .setDetail(let setID):
        DJSetDetailView(setID: setID)

    case .newsDetail(let articleID):
        DiscoverNewsDetailLoaderView(articleID: articleID, repository: appContainer.discoverNewsRepository)

    case .eventCreate:
        EventEditorView(mode: .create) {
            NotificationCenter.default.post(name: .discoverEventDidSave, object: nil)
        }

    case .eventEdit(let eventID):
        DiscoverEventEditorLoaderView(eventID: eventID, repository: appContainer.discoverEventsRepository)

    case .newsPublish:
        DiscoverNewsPublishSheet { draft in
            _ = try await appContainer.discoverNewsRepository.publish(draft: draft)
            NotificationCenter.default.post(name: .discoverNewsDidPublish, object: nil)
        }

    case .learnFestivalCreate:
        LearnFestivalEditorView(mode: .create) { festival in
            NotificationCenter.default.post(name: .discoverFestivalDidSave, object: festival.id)
        }

    case .learnFestivalEdit(let festivalID):
        DiscoverFestivalEditorLoaderView(festivalID: festivalID, repository: appContainer.discoverWikiRepository) { updated in
            NotificationCenter.default.post(name: .discoverFestivalDidSave, object: updated.id)
        }

    case .setCreate:
        DJSetEditorView(mode: .create) {
            NotificationCenter.default.post(name: .discoverSetDidSave, object: nil)
        }

    case .setEdit(let setID):
        DiscoverSetEditorLoaderView(setID: setID, repository: appContainer.discoverSetsRepository)
    }
}

private struct DiscoverEventEditorLoaderView: View {
    let eventID: String
    let repository: DiscoverEventsRepository

    @State private var event: WebEvent?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let event {
                EventEditorView(mode: .edit(event)) {
                    NotificationCenter.default.post(name: .discoverEventDidSave, object: event.id)
                }
            } else if isLoading {
                ProgressView(L("加载活动中...", "Loading event..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadEvent(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载活动中...", "Loading event..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadEvent(force: false)
        }
    }

    @MainActor
    private func loadEvent(force: Bool) async {
        if event != nil && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            event = try await repository.fetchEvent(id: eventID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct DiscoverSetEditorLoaderView: View {
    let setID: String
    let repository: DiscoverSetsRepository

    @State private var set: WebDJSet?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let set {
                DJSetEditorView(mode: .edit(set)) {
                    NotificationCenter.default.post(name: .discoverSetDidSave, object: set.id)
                }
            } else if isLoading {
                ProgressView(L("加载 Set 中...", "Loading set..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadSet(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载 Set 中...", "Loading set..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadSet(force: false)
        }
    }

    @MainActor
    private func loadSet(force: Bool) async {
        if set != nil && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            set = try await repository.fetchDJSet(id: setID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct DiscoverNewsDetailLoaderView: View {
    let articleID: String
    let repository: DiscoverNewsRepository

    @State private var article: DiscoverNewsArticle?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let article {
                DiscoverNewsDetailView(article: article)
            } else if isLoading {
                ProgressView(L("加载资讯中...", "Loading article..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadArticle(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载资讯中...", "Loading article..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadArticle(force: false)
        }
    }

    @MainActor
    private func loadArticle(force: Bool) async {
        if article != nil && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            article = try await repository.fetchArticle(id: articleID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct DiscoverLabelDetailLoaderView: View {
    let labelID: String
    let repository: DiscoverWikiRepository

    @State private var label: LearnLabel?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let label {
                LearnLabelDetailView(label: label)
            } else if isLoading {
                ProgressView(L("加载厂牌中...", "Loading label..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadLabel(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载厂牌中...", "Loading label..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadLabel(force: false)
        }
    }

    @MainActor
    private func loadLabel(force: Bool) async {
        if label != nil && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            label = try await fetchLearnLabelByID(labelID, repository: repository)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct DiscoverFestivalDetailLoaderView: View {
    let festivalID: String
    let repository: DiscoverWikiRepository

    @State private var festival: LearnFestival?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let festival {
                LearnFestivalDetailView(festival: festival)
            } else if isLoading {
                ProgressView(L("加载电音节中...", "Loading festival..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadFestival(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载电音节中...", "Loading festival..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadFestival(force: false)
        }
    }

    @MainActor
    private func loadFestival(force: Bool) async {
        if festival != nil && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            festival = try await fetchLearnFestivalByID(festivalID, repository: repository)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct DiscoverFestivalEditorLoaderView: View {
    let festivalID: String
    let repository: DiscoverWikiRepository
    let onSave: (LearnFestival) -> Void

    @State private var festival: LearnFestival?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let festival {
                LearnFestivalEditorView(mode: .edit(festival), onSaved: onSave)
            } else if isLoading {
                ProgressView(L("加载电音节中...", "Loading festival..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadFestival(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载电音节中...", "Loading festival..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadFestival(force: false)
        }
    }

    @MainActor
    private func loadFestival(force: Bool) async {
        if festival != nil && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            festival = try await fetchLearnFestivalByID(festivalID, repository: repository)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private func fetchLearnLabelByID(_ labelID: String, repository: DiscoverWikiRepository) async throws -> LearnLabel {
    var page = 1
    let limit = 100

    while true {
        let response = try await repository.fetchLearnLabels(
            page: page,
            limit: limit,
            sortBy: "followerCount",
            order: "desc",
            search: nil,
            nation: nil,
            genre: nil
        )
        if let matched = response.items.first(where: { $0.id == labelID }) {
            return matched
        }

        guard let pagination = response.pagination,
              page < pagination.totalPages else {
            break
        }
        page += 1
    }

    throw ServiceError.message(L("厂牌不存在或已被移除", "Label not found"))
}

private func fetchLearnFestivalByID(_ festivalID: String, repository: DiscoverWikiRepository) async throws -> LearnFestival {
    let festivals = try await repository.fetchLearnFestivals(search: nil)
    if let matched = festivals.first(where: { $0.id == festivalID }) {
        return LearnFestival(web: matched)
    }
    throw ServiceError.message(L("电音节不存在或已被移除", "Festival not found"))
}
