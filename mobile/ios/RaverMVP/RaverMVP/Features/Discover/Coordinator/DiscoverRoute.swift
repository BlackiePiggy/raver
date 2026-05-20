import SwiftUI

enum DiscoverRoute: Hashable {
    case labelDetail(labelID: String, prefetchedLabel: LearnLabel? = nil)
    case festivalDetail(festivalID: String, prefetchedFestival: LearnFestival? = nil)
    case setDetail(setID: String)
    case newsDetail(articleID: String)
    case learnFestivalCreate
    case learnFestivalEdit(festivalID: String)
    case newsPublish
    case setCreate
    case setEdit(setID: String)
    case eventCreate
    case eventEdit(eventID: String)
    case djImport(initialName: String? = nil)
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
    case .labelDetail(let labelID, let prefetchedLabel):
        DiscoverLabelDetailLoaderView(
            labelID: labelID,
            prefetchedLabel: prefetchedLabel,
            repository: appContainer.discoverWikiRepository
        )

    case .festivalDetail(let festivalID, let prefetchedFestival):
        DiscoverFestivalDetailLoaderView(
            festivalID: festivalID,
            prefetchedFestival: prefetchedFestival,
            repository: appContainer.discoverWikiRepository
        )

    case .setDetail(let setID):
        DJSetDetailView(setID: setID)

    case .newsDetail(let articleID):
        DiscoverNewsDetailLoaderView(articleID: articleID, repository: appContainer.discoverNewsRepository)

    case .eventCreate:
        EventEditorView(mode: .create) {
            NotificationCenter.default.post(name: .discoverEventDidSave, object: nil)
        }

    case .eventEdit(let eventID):
        DiscoverEventEditorLoaderView(eventID: eventID, eventReadRepository: appContainer.eventReadRepository)

    case .djImport(let initialName):
        DJsModuleView(
            viewModel: DJsModuleViewModel(repository: appContainer.djListRepository),
            initialImportName: initialName,
            openImportOnAppear: true,
            dismissAfterSuccessfulImport: true
        )

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
        DiscoverSetEditorLoaderView(setID: setID, setReadRepository: appContainer.setReadRepository)
    }
}

private struct DiscoverRouteLoaderScaffold<Content: View>: View {
    let phase: LoadPhase
    let retry: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            switch phase {
            case .idle, .initialLoading:
                EventDetailSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(message: message, retryAction: retry)
                        .padding(16)
                        .padding(.top, 72)
                }
                .background(RaverTheme.background)
            case .empty:
                ContentUnavailableView(
                    LT("内容不存在", "Content Unavailable", "コンテンツがありません"),
                    systemImage: "exclamationmark.circle"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            case .success:
                content()
            }
        }
    }
}

private struct DiscoverEventEditorLoaderView: View {
    let eventID: String
    let eventReadRepository: EventReadRepository

    init(eventID: String, eventReadRepository: EventReadRepository) {
        self.eventID = eventID
        self.eventReadRepository = eventReadRepository
    }

    @State private var event: WebEvent?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        DiscoverRouteLoaderScaffold(phase: phase) {
            Task { await loadEvent(force: true) }
        } content: {
            if let event {
                EventEditorView(mode: .edit(event)) {
                    NotificationCenter.default.post(name: .discoverEventDidSave, object: event.id)
                }
            } else {
                Color.clear
            }
        }
        .task {
            await loadEvent(force: false)
        }
    }

    @MainActor
    private func loadEvent(force: Bool) async {
        if event != nil && !force { return }
        phase = .initialLoading
        do {
            event = try await eventReadRepository.fetchEvent(id: eventID)
            phase = .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("活动加载失败，请稍后重试", "Failed to load event. Please try again later.", "イベントを読み込めませんでした。時間をおいて再試行してください。"))
        }
    }
}

private struct DiscoverSetEditorLoaderView: View {
    let setID: String
    let setReadRepository: SetReadRepository

    init(setID: String, setReadRepository: SetReadRepository) {
        self.setID = setID
        self.setReadRepository = setReadRepository
    }

    @State private var set: WebDJSet?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        DiscoverRouteLoaderScaffold(phase: phase) {
            Task { await loadSet(force: true) }
        } content: {
            if let set {
                DJSetEditorView(mode: .edit(set)) {
                    NotificationCenter.default.post(name: .discoverSetDidSave, object: set.id)
                }
            } else {
                Color.clear
            }
        }
        .task {
            await loadSet(force: false)
        }
    }

    @MainActor
    private func loadSet(force: Bool) async {
        if set != nil && !force { return }
        phase = .initialLoading
        do {
            set = try await setReadRepository.fetchDJSet(id: setID)
            phase = .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("Set 加载失败，请稍后重试", "Failed to load set. Please try again later.", "Setを読み込めませんでした。時間をおいて再試行してください。"))
        }
    }
}

private struct DiscoverNewsDetailLoaderView: View {
    let articleID: String
    let repository: DiscoverNewsRepository

    @State private var article: DiscoverNewsArticle?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        DiscoverRouteLoaderScaffold(phase: phase) {
            Task { await loadArticle(force: true) }
        } content: {
            if let article {
                DiscoverNewsDetailView(article: article)
            } else {
                Color.clear
            }
        }
        .task {
            await loadArticle(force: false)
        }
    }

    @MainActor
    private func loadArticle(force: Bool) async {
        if article != nil && !force { return }
        phase = .initialLoading
        do {
            article = try await repository.fetchArticle(id: articleID)
            phase = .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("资讯加载失败，请稍后重试", "Failed to load article. Please try again later.", "記事を読み込めませんでした。時間をおいて再試行してください。"))
        }
    }
}

private struct DiscoverLabelDetailLoaderView: View {
    let labelID: String
    let prefetchedLabel: LearnLabel?
    let repository: DiscoverWikiRepository

    @State private var label: LearnLabel?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        DiscoverRouteLoaderScaffold(phase: phase) {
            Task { await loadLabel(force: true) }
        } content: {
            if let label {
                LearnLabelDetailView(label: label)
            } else {
                Color.clear
            }
        }
        .task {
            if let prefetchedLabel, label == nil {
                label = prefetchedLabel
                phase = .success
            }
            await loadLabel(force: false)
        }
    }

    @MainActor
    private func loadLabel(force: Bool) async {
        if label != nil && !force { return }
        if label == nil {
            phase = .initialLoading
        }
        do {
            label = try await fetchLearnLabelByID(labelID, repository: repository)
            phase = .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("厂牌加载失败，请稍后重试", "Failed to load label. Please try again later.", "レーベルを読み込めませんでした。時間をおいて再試行してください。"))
        }
    }
}

private struct DiscoverFestivalDetailLoaderView: View {
    let festivalID: String
    let prefetchedFestival: LearnFestival?
    let repository: DiscoverWikiRepository

    @State private var festival: LearnFestival?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        DiscoverRouteLoaderScaffold(phase: phase) {
            Task { await loadFestival(force: true) }
        } content: {
            if let festival {
                LearnFestivalDetailView(festival: festival)
            } else {
                Color.clear
            }
        }
        .task {
            if let prefetchedFestival, festival == nil {
                festival = prefetchedFestival
                phase = .success
            }
            await loadFestival(force: false)
        }
    }

    @MainActor
    private func loadFestival(force: Bool) async {
        if festival != nil && !force { return }
        if festival == nil {
            phase = .initialLoading
        }
        do {
            festival = try await fetchLearnFestivalByID(festivalID, repository: repository)
            phase = .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("电音节加载失败，请稍后重试", "Failed to load festival. Please try again later.", "フェスを読み込めませんでした。時間をおいて再試行してください。"))
        }
    }
}

private struct DiscoverFestivalEditorLoaderView: View {
    let festivalID: String
    let repository: DiscoverWikiRepository
    let onSave: (LearnFestival) -> Void

    @State private var festival: LearnFestival?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        DiscoverRouteLoaderScaffold(phase: phase) {
            Task { await loadFestival(force: true) }
        } content: {
            if let festival {
                LearnFestivalEditorView(mode: .edit(festival), onSaved: onSave)
            } else {
                Color.clear
            }
        }
        .task {
            await loadFestival(force: false)
        }
    }

    @MainActor
    private func loadFestival(force: Bool) async {
        if festival != nil && !force { return }
        phase = .initialLoading
        do {
            festival = try await fetchLearnFestivalByID(festivalID, repository: repository)
            phase = .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("电音节加载失败，请稍后重试", "Failed to load festival. Please try again later.", "フェスを読み込めませんでした。時間をおいて再試行してください。"))
        }
    }
}

private func fetchLearnLabelByID(_ labelID: String, repository: DiscoverWikiRepository) async throws -> LearnLabel {
    try await repository.fetchLearnLabel(id: labelID)
}

private func fetchLearnFestivalByID(_ festivalID: String, repository: DiscoverWikiRepository) async throws -> LearnFestival {
    LearnFestival(web: try await repository.fetchLearnFestival(id: festivalID))
}
