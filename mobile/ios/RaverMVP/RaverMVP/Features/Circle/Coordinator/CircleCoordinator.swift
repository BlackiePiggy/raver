import SwiftUI

enum CircleRoute: Hashable {
    case ratingEventDetail(String)
    case postCreate
    case postEdit(postID: String)
    case idCreate
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

private struct CirclePostEditorLoaderView: View {
    let postID: String
    let service: SocialService
    let webService: WebFeatureService

    @State private var post: Post?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
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
            } else if isLoading {
                ProgressView(L("加载动态中...", "Loading post..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadPost(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载动态中...", "Loading post..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
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
        defer { isLoading = false }
        do {
            post = try await service.fetchPost(postID: postID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
