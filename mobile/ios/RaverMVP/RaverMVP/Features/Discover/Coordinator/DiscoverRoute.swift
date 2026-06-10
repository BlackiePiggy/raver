import SwiftUI

enum DiscoverRoute: Hashable {
    case genreDetail(genreID: String, prefetchedGenre: LearnGenreDetail? = nil)
    case labelDetail(labelID: String, prefetchedLabel: LearnLabel? = nil)
    case festivalDetail(festivalID: String, prefetchedFestival: LearnFestival? = nil)
    case setDetail(setID: String)
    case newsDetail(articleID: String)
    case organizerCreate(initialName: String? = nil, sourceContextID: String? = nil)
    case organizerEdit(brandID: String)
    case newsPublish
    case setCreate
    case setEdit(setID: String)
    case eventCreate
    case eventEdit(eventID: String)
    case djImport(initialName: String? = nil)
}

extension Notification.Name {
    static let discoverEventDidSave = Notification.Name("discoverEventDidSave")
    static let contentSubmissionDidQueue = Notification.Name("contentSubmissionDidQueue")
    static let discoverNewsDidPublish = Notification.Name("discoverNewsDidPublish")
    static let discoverSetDidSave = Notification.Name("discoverSetDidSave")
    static let discoverOrganizerDidSave = Notification.Name("discoverOrganizerDidSave")
    static let discoverOrganizerDidCreate = Notification.Name("discoverOrganizerDidCreate")
    static let discoverOrganizerSubmissionQueued = Notification.Name("discoverOrganizerSubmissionQueued")
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
    case .genreDetail(let genreID, let prefetchedGenre):
        DiscoverGenreDetailLoaderView(
            genreID: genreID,
            prefetchedGenre: prefetchedGenre,
            repository: appContainer.discoverWikiRepository
        )

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
        EventUploadFlowView(mode: .create, webService: appContainer.webService) { outcome in
            postEventUploadOutcome(outcome)
        }

    case .eventEdit(let eventID):
        DiscoverEventEditorLoaderView(
            eventID: eventID,
            eventReadRepository: appContainer.eventReadRepository,
            webService: appContainer.webService
        )

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

    case .organizerCreate(let initialName, let sourceContextID):
        OrganizerUploadFlowView(mode: .create, initialName: initialName, sourceContextID: sourceContextID)

    case .organizerEdit(let brandID):
        DiscoverOrganizerUploadLoaderView(brandID: brandID, repository: appContainer.discoverWikiRepository)

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

private struct DiscoverGenreDetailLoaderView: View {
    let genreID: String
    let prefetchedGenre: LearnGenreDetail?
    let repository: DiscoverWikiRepository

    @State private var genre: LearnGenreDetail?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .initialLoading:
                GenreDetailSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(message: message, retryAction: {
                        Task { await loadGenre(force: true) }
                    })
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
                if let genre {
                    LearnGenreDetailView(genre: genre)
                } else {
                    Color.clear
                }
            }
        }
        .task {
            if let prefetchedGenre, genre == nil {
                genre = prefetchedGenre
                phase = .success
            }
            await loadGenre(force: false)
        }
    }

    @MainActor
    private func loadGenre(force: Bool) async {
        if genre != nil && !force { return }
        if genre == nil {
            phase = .initialLoading
        }
        do {
            genre = try await repository.fetchLearnGenreDetail(id: genreID)
            phase = .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("风格加载失败，请稍后重试", "Failed to load genre. Please try again later.", "ジャンルを読み込めませんでした。時間をおいて再試行してください。"))
        }
    }
}

private struct DiscoverEventEditorLoaderView: View {
    let eventID: String
    let eventReadRepository: EventReadRepository
    let webService: WebFeatureService

    init(eventID: String, eventReadRepository: EventReadRepository, webService: WebFeatureService) {
        self.eventID = eventID
        self.eventReadRepository = eventReadRepository
        self.webService = webService
    }

    @State private var event: WebEvent?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        DiscoverRouteLoaderScaffold(phase: phase) {
            Task { await loadEvent(force: true) }
        } content: {
            if let event {
                EventUploadFlowView(mode: .edit(eventID: event.id), event: event, webService: webService) { outcome in
                    postEventUploadOutcome(outcome)
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

private func postEventUploadOutcome(_ outcome: EventUploadSaveOutcome) {
    switch outcome {
    case .eventMutated(let eventID):
        NotificationCenter.default.post(name: .discoverEventDidSave, object: eventID)
    case .submissionQueued(let eventID):
        NotificationCenter.default.post(name: .contentSubmissionDidQueue, object: eventID)
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

private struct DiscoverOrganizerUploadLoaderView: View {
    let brandID: String
    let repository: DiscoverWikiRepository

    @State private var brand: WebLearnFestival?
    @State private var phase: LoadPhase = .idle

    var body: some View {
        DiscoverRouteLoaderScaffold(phase: phase) {
            Task { await loadBrand(force: true) }
        } content: {
            if let brand {
                OrganizerUploadFlowView(mode: .edit(id: brand.id), initialBrand: brand)
            } else {
                Color.clear
            }
        }
        .task {
            await loadBrand(force: false)
        }
    }

    @MainActor
    private func loadBrand(force: Bool) async {
        if brand != nil && !force { return }
        phase = .initialLoading
        do {
            brand = try await repository.fetchLearnFestival(id: brandID)
            phase = .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("主办方加载失败，请稍后重试", "Failed to load organizer. Please try again later.", "主催者を読み込めませんでした。時間をおいて再試行してください。"))
        }
    }
}

private func fetchLearnLabelByID(_ labelID: String, repository: DiscoverWikiRepository) async throws -> LearnLabel {
    try await repository.fetchLearnLabel(id: labelID)
}

private func fetchLearnFestivalByID(_ festivalID: String, repository: DiscoverWikiRepository) async throws -> LearnFestival {
    LearnFestival(web: try await repository.fetchLearnFestival(id: festivalID))
}
