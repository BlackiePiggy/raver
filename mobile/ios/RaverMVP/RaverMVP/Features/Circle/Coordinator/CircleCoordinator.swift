import SwiftUI

enum CircleRoute: Hashable {
    case ratingEventDetail(String)
    case postCreate
    case postEdit(postID: String)
    case idCreate
    case idDetail(entryID: String)
    case ratingEventCreate
    case ratingEventImportFromEvent
    case ratingUnitCreate(eventID: String)
}

private struct CirclePushKey: EnvironmentKey {
    static let defaultValue: (CircleRoute) -> Void = { _ in }
}

extension EnvironmentValues {
    var circlePush: (CircleRoute) -> Void {
        get { self[CirclePushKey.self] }
        set { self[CirclePushKey.self] = newValue }
    }
}

extension Notification.Name {
    static let circlePostDidCreate = Notification.Name("circlePostDidCreate")
    static let circlePostDidUpdate = Notification.Name("circlePostDidUpdate")
    static let circlePostDidDelete = Notification.Name("circlePostDidDelete")
    static let circlePostDidHide = Notification.Name("circlePostDidHide")
    static let circleIDDidCreate = Notification.Name("circleIDDidCreate")
    static let circleRatingEventDidCreate = Notification.Name("circleRatingEventDidCreate")
    static let circleRatingUnitDidCreate = Notification.Name("circleRatingUnitDidCreate")
}

struct CircleCoordinatorView<Content: View>: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState
    @State private var navPath = NavigationPath()
    private let content: Content
    private let onNavigationDepthChange: ((Int) -> Void)?

    init(
        onNavigationDepthChange: ((Int) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onNavigationDepthChange = onNavigationDepthChange
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            content
                .navigationBarHidden(true)
                .onAppear {
                    onNavigationDepthChange?(navPath.count)
                }
                .navigationDestination(for: CircleRoute.self) { route in
                    routeDestination(for: route)
                }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
        .background(RaverTheme.background)
        .environment(\.circlePush) { route in
            navPath.append(route)
        }
        .onAppear {
            onNavigationDepthChange?(navPath.count)
        }
        .onChange(of: navPath.count) { _, newValue in
            onNavigationDepthChange?(newValue)
        }
    }

    @ViewBuilder
    private func routeDestination(for route: CircleRoute) -> some View {
        switch route {
        case let .ratingEventDetail(eventID):
            CircleRatingEventDetailView(
                eventID: eventID,
                onClose: {},
                onUpdated: {}
            )
        case .postCreate:
            ComposePostView(
                service: appContainer.socialService,
                webService: appContainer.webService,
                mode: .create,
                onPostCreated: { created in
                    NotificationCenter.default.post(name: .circlePostDidCreate, object: created)
                }
            )
        case let .postEdit(postID):
            CirclePostEditorLoaderView(
                postID: postID,
                service: appContainer.socialService,
                webService: appContainer.webService
            )
        case .idCreate:
            CircleIDComposerSheet { entry in
                NotificationCenter.default.post(name: .circleIDDidCreate, object: entry)
            }
            .environmentObject(appState)
        case let .idDetail(entryID):
            CircleIDDetailLoaderView(entryID: entryID)
                .environmentObject(appState)
        case .ratingEventCreate:
            CreateRatingEventSheet { input in
                let created = try await appContainer.webService.createRatingEvent(input: input)
                NotificationCenter.default.post(name: .circleRatingEventDidCreate, object: created)
            }
        case .ratingEventImportFromEvent:
            CreateRatingEventFromEventSheet { sourceEventID in
                let created = try await appContainer.webService.createRatingEventFromEvent(eventID: sourceEventID)
                NotificationCenter.default.post(name: .circleRatingEventDidCreate, object: created)
            }
        case let .ratingUnitCreate(eventID):
            CreateRatingUnitSheet(eventID: eventID) { input in
                let created = try await appContainer.webService.createRatingUnit(eventID: eventID, input: input)
                NotificationCenter.default.post(
                    name: .circleRatingUnitDidCreate,
                    object: created,
                    userInfo: ["eventID": eventID]
                )
            }
        }
    }
}

private struct CircleRouteLoaderScaffold<Content: View>: View {
    let phase: LoadPhase
    let title: String
    let loadingView: AnyView
    let retry: () -> Void
    let content: () -> Content

    init(
        phase: LoadPhase,
        title: String,
        loadingView: AnyView,
        retry: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.phase = phase
        self.title = title
        self.loadingView = loadingView
        self.retry = retry
        self.content = content
    }

    var body: some View {
        Group {
            switch phase {
            case .idle, .initialLoading:
                loadingView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(RaverTheme.background)
            case .failure(let message):
                ScreenErrorCard(title: title, message: message, retryAction: retry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            case .offline(let message):
                ScreenErrorCard(
                    title: L("网络不可用", "Network Unavailable"),
                    message: message,
                    retryAction: retry
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            case .empty:
                ContentUnavailableView(title, systemImage: "tray")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            case .success:
                content()
            }
        }
    }
}

private struct CirclePostEditorLoaderView: View {
    let postID: String
    let service: SocialService
    let webService: WebFeatureService

    @State private var post: Post?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false

    var body: some View {
        CircleRouteLoaderScaffold(
            phase: phase,
            title: L("动态加载失败", "Post Failed to Load"),
            loadingView: AnyView(VStack(spacing: 12) {
                EventDetailSkeletonView()
                CommentSectionSkeletonView(count: 2)
            }),
            retry: {
                Task { await loadPost(force: true) }
            }
        ) {
            if let post {
                ComposePostView(
                    service: service,
                    webService: webService,
                    mode: .edit(post),
                    onPostUpdated: { updated in
                        NotificationCenter.default.post(name: .circlePostDidUpdate, object: updated)
                    },
                    onPostDeleted: { deletedPostID in
                        NotificationCenter.default.post(name: .circlePostDidDelete, object: deletedPostID)
                    }
                )
            } else {
                EmptyView()
            }
        }
        .task {
            await loadPost(force: false)
        }
    }

    @MainActor
    private func loadPost(force: Bool) async {
        if post != nil && !force { return }
        isLoading = true
        phase = .initialLoading
        defer { isLoading = false }
        do {
            post = try await service.fetchPost(postID: postID)
            phase = post == nil ? .empty : .success
        } catch {
            phase = .failure(
                message: error.userFacingMessage ?? L("动态加载失败，请稍后重试", "Failed to load post. Please try again later.")
            )
        }
    }
}
