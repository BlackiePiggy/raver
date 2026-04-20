import SwiftUI

enum MainTab: Hashable {
    case discover
    case circle
    case messages
    case profile
}

enum AppRoute: Hashable {
    case discover(DiscoverRoute)
    case circle(CircleRoute)
    case messages(MessagesRoute)
    case profile(ProfileRoute)
    case conversation(conversationID: String)
    case postDetail(postID: String)
    case eventDetail(eventID: String)
    case eventSchedule(eventID: String)
    case djDetail(djID: String)
    case rankingBoardDetail(board: RankingBoard)
    case userProfile(userID: String)
    case squadProfile(squadID: String)
    case squadManage(squadID: String)
    case ratingUnitDetail(unitID: String)
}

extension AppRoute {
    // Stage-6 metadata for tab bar behavior, analytics naming, and route->tab semantics.
    var hidesTabBar: Bool {
        switch self {
        case .discover:
            return false
        case .circle, .messages, .profile:
            return true
        case .conversation,
             .postDetail,
             .eventDetail,
             .eventSchedule,
             .djDetail,
             .rankingBoardDetail,
             .userProfile,
             .squadProfile,
             .squadManage,
             .ratingUnitDetail:
            return true
        }
    }

    var analyticsName: String {
        switch self {
        case .discover:
            return "discover.route"
        case .circle:
            return "circle.route"
        case .messages:
            return "messages.route"
        case .profile:
            return "profile.route"
        case .conversation:
            return "conversation.detail"
        case .postDetail:
            return "post.detail"
        case .eventDetail:
            return "event.detail"
        case .eventSchedule:
            return "event.schedule"
        case .djDetail:
            return "dj.detail"
        case .rankingBoardDetail:
            return "ranking.board.detail"
        case .userProfile:
            return "user.profile"
        case .squadProfile:
            return "squad.profile"
        case .squadManage:
            return "squad.manage"
        case .ratingUnitDetail:
            return "rating.unit.detail"
        }
    }

    var preferredTab: MainTab? {
        switch self {
        case .discover:
            return .discover
        case .circle:
            return .circle
        case .messages:
            return .messages
        case .profile:
            return .profile
        case .conversation:
            return .messages
        case .postDetail, .squadProfile, .squadManage, .ratingUnitDetail:
            return .circle
        case .eventDetail, .eventSchedule, .djDetail, .rankingBoardDetail:
            return .discover
        case .userProfile:
            return .profile
        }
    }
}

enum AppSheetRoute: Hashable, Identifiable {
    case squadProfile(squadID: String)

    var id: String {
        switch self {
        case .squadProfile(let squadID):
            return "squadProfile:\(squadID)"
        }
    }
}

enum AppFullScreenRoute: Hashable, Identifiable {
    case avatarFullscreen

    var id: String {
        switch self {
        case .avatarFullscreen:
            return "avatarFullscreen"
        }
    }
}

private struct AppNavigateKey: EnvironmentKey {
    static let defaultValue: (AppRoute) -> Void = { _ in }
}

extension EnvironmentValues {
    var appNavigate: (AppRoute) -> Void {
        get { self[AppNavigateKey.self] }
        set { self[AppNavigateKey.self] = newValue }
    }

    // Backward-compatible alias for incremental migration.
    var appPush: (AppRoute) -> Void {
        get { appNavigate }
        set { appNavigate = newValue }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: MainTab = .discover
    @Published var path: [AppRoute] = []
    @Published var sheet: AppSheetRoute?
    @Published var fullScreen: AppFullScreenRoute?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func switchTab(_ tab: MainTab) {
        selectedTab = tab
    }

    func open(tab: MainTab, route: AppRoute? = nil) {
        selectedTab = tab
        if let route {
            push(route)
        }
    }

    func presentSheet(_ route: AppSheetRoute) {
        sheet = route
    }

    func dismissSheet() {
        sheet = nil
    }

    func presentFullScreen(_ route: AppFullScreenRoute) {
        fullScreen = route
    }

    func dismissFullScreen() {
        fullScreen = nil
    }
}

@MainActor
struct MainTabCoordinatorView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState
    @StateObject private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            MainTabView()
                .toolbar(
                    router.selectedTab == .profile ? .visible : .hidden,
                    for: .navigationBar
                )
                .navigationDestination(for: AppRoute.self) { route in
                    routeDestination(for: route)
                }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
        .sheet(item: $router.sheet) { route in
            sheetDestination(for: route)
        }
        .fullScreenCover(item: $router.fullScreen) { route in
            fullScreenDestination(for: route)
        }
        .environmentObject(router)
        .environment(\.appNavigate) { route in
            router.push(route)
        }
        .environment(\.discoverPush) { route in
            pushDiscoverRoute(route)
        }
        .environment(\.circlePush) { route in
            pushCircleRoute(route)
        }
        .environment(\.messagesPush) { route in
            pushMessagesRoute(route)
        }
        .environment(\.messagesPresent) { route in
            presentMessagesRoute(route)
        }
        .environment(\.profilePush) { route in
            pushProfileRoute(route)
        }
    }

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .discover(let discoverRoute):
            makeDiscoverRouteDestination(
                discoverRoute,
                push: { nextRoute in
                    pushDiscoverRoute(nextRoute)
                },
                appContainer: appContainer
            )
                .environment(\.discoverPush) { nextRoute in
                    pushDiscoverRoute(nextRoute)
                }
                .environmentObject(appContainer)
                .environmentObject(appState)

        case .circle(let circleRoute):
            switch circleRoute {
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
                    webService: appContainer.webService,
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

        case .messages(let messagesRoute):
            switch messagesRoute {
            case let .alertCategory(category):
                MessagesAlertDetailContainerView(
                    category: category,
                    repository: appContainer.messagesRepository
                ) {
                    Task {
                        await appState.refreshUnreadMessages()
                    }
                }
            }

        case .profile(let profileRoute):
            switch profileRoute {
            case let .followList(userID, kind):
                FollowListView(
                    userID: userID,
                    kind: kind,
                    repository: appContainer.profileSocialRepository
                )
            case .settings:
                SettingsView()
            case .myPublishes:
                MyPublishesView(
                    service: appContainer.webService,
                    socialService: appContainer.socialService
                )
            case .myRoutes:
                MyRoutesView()
            case .editProfile:
                CurrentUserProfileLoaderView(repository: appContainer.profileSocialRepository) { profile in
                    EditProfileView(profile: profile, repository: appContainer.profileSocialRepository) { updated in
                        NotificationCenter.default.post(name: .profileDidUpdate, object: updated)
                    }
                }
            case let .myCheckins(targetUserID, title):
                MyCheckinsView(
                    targetUserID: targetUserID,
                    title: title
                )
            case .avatarFullscreen:
                CurrentUserProfileLoaderView(repository: appContainer.profileSocialRepository) { profile in
                    AvatarFullscreenView(profile: profile)
                        .toolbar(.hidden, for: .navigationBar)
                }
            case .publishEvent:
                EventEditorView(mode: .create) {}
            case .uploadSet:
                DJSetEditorView(mode: .create) {}
            case let .editEvent(eventID):
                ProfileEventEditorLoaderView(eventID: eventID, service: appContainer.webService)
            case let .editSet(setID):
                ProfileSetEditorLoaderView(setID: setID, service: appContainer.webService)
            case let .editRatingEvent(eventID):
                ProfileRatingEventEditorLoaderView(eventID: eventID, service: appContainer.webService)
            case let .editRatingUnit(unitID):
                ProfileRatingUnitEditorLoaderView(unitID: unitID, service: appContainer.webService)
            }

        case let .conversation(conversationID):
            ConversationLoaderView(
                conversationID: conversationID,
                service: appContainer.socialService
            )

        case let .postDetail(postID):
            PostDetailLoaderView(postID: postID, service: appContainer.socialService)
                .environmentObject(appState)

        case .eventDetail(let eventID):
            EventDetailView(eventID: eventID)

        case .eventSchedule(let eventID):
            EventDetailView(eventID: eventID, initialTabRawValue: "schedule")

        case .djDetail(let djID):
            DJDetailView(djID: djID)

        case .rankingBoardDetail(let board):
            RankingBoardDetailView(board: board)

        case .userProfile(let userID):
            UserProfileView(userID: userID)

        case .squadProfile(let squadID):
            SquadProfileView(
                squadID: squadID,
                service: appContainer.socialService
            )
                .environmentObject(appState)

        case .squadManage(let squadID):
            SquadManageRouteView(
                squadID: squadID,
                service: appContainer.socialService,
                webService: appContainer.webService
            )

        case .ratingUnitDetail(let unitID):
            CircleRatingUnitDetailView(unitID: unitID) {
                NotificationCenter.default.post(name: .discoverRatingUnitDidUpdate, object: unitID)
            }
            .environmentObject(appContainer)
            .environmentObject(appState)
            .environment(\.discoverPush) { nextRoute in
                pushDiscoverRoute(nextRoute)
            }
            .environment(\.circlePush) { circleRoute in
                router.push(.circle(circleRoute))
            }
        }
    }

    @ViewBuilder
    private func sheetDestination(for route: AppSheetRoute) -> some View {
        switch route {
        case .squadProfile(let squadID):
            NavigationStack {
                SquadProfileView(
                    squadID: squadID,
                    service: appContainer.socialService
                )
                    .environmentObject(appState)
            }
            .raverEnableCustomSwipeBack(edgeRatio: 0.2)
        }
    }

    @ViewBuilder
    private func fullScreenDestination(for route: AppFullScreenRoute) -> some View {
        switch route {
        case .avatarFullscreen:
            CurrentUserProfileLoaderView(repository: appContainer.profileSocialRepository) { profile in
                AvatarFullscreenView(profile: profile)
            }
        }
    }

    private func pushDiscoverRoute(_ route: DiscoverRoute) {
        router.push(.discover(route))
    }

    private func pushCircleRoute(_ route: CircleRoute) {
        switch route {
        case .postCreate,
                .postEdit,
                .idCreate,
                .ratingEventDetail,
                .ratingEventCreate,
                .ratingEventImportFromEvent,
                .ratingUnitCreate:
            router.push(.circle(route))
        }
    }

    private func pushMessagesRoute(_ route: MessagesRoute) {
        switch route {
        case .alertCategory:
            router.push(.messages(route))
        }
    }

    private func presentMessagesRoute(_ route: MessagesModalRoute) {
        switch route {
        case .squadProfile(let squadID):
            router.presentSheet(.squadProfile(squadID: squadID))
        }
    }

    private func pushProfileRoute(_ route: ProfileRoute) {
        switch route {
        case .followList,
                .settings,
                .myPublishes,
                .myRoutes,
                .editProfile,
                .myCheckins,
                .publishEvent,
                .uploadSet,
                .editEvent,
                .editSet,
                .editRatingEvent,
                .editRatingUnit:
            router.push(.profile(route))
        case .avatarFullscreen:
            router.presentFullScreen(.avatarFullscreen)
        }
    }
}

private struct MessagesAlertDetailContainerView: View {
    @StateObject private var viewModel: MessageNotificationsViewModel
    private let category: MessageAlertCategory
    private let onReadChange: () -> Void

    init(
        category: MessageAlertCategory,
        repository: MessagesRepository,
        onReadChange: @escaping () -> Void
    ) {
        self.category = category
        self.onReadChange = onReadChange
        _viewModel = StateObject(wrappedValue: MessageNotificationsViewModel(repository: repository))
    }

    var body: some View {
        MessageAlertDetailView(
            category: category,
            viewModel: viewModel,
            onReadChange: onReadChange
        )
        .task {
            await viewModel.load()
        }
    }
}

private struct ConversationLoaderView: View {
    let conversationID: String
    let service: SocialService

    @State private var conversation: Conversation?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let conversation {
                ChatView(conversation: conversation, service: service)
            } else if isLoading {
                ProgressView(L("加载会话中...", "Loading conversation..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadConversation(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载会话中...", "Loading conversation..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadConversation(force: false)
        }
    }

    @MainActor
    private func loadConversation(force: Bool) async {
        if conversation != nil && !force { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let directConversations = service.fetchConversations(type: .direct)
            async let groupConversations = service.fetchConversations(type: .group)
            let allConversations = try await directConversations + groupConversations
            if let found = allConversations.first(where: { $0.id == conversationID }) {
                conversation = found
                errorMessage = nil
            } else {
                errorMessage = L("会话不存在或已被移除", "Conversation not found")
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct PostDetailLoaderView: View {
    let postID: String
    let service: SocialService

    @State private var post: Post?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let post {
                PostDetailView(post: post, service: service)
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

private struct ProfileResourceLoaderView<Resource, Content: View>: View {
    let loadingText: String
    let load: () async throws -> Resource
    let content: (Resource) -> Content

    @State private var resource: Resource?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let resource {
                content(resource)
            } else if isLoading {
                ProgressView(loadingText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadResource(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(loadingText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadResource(force: false)
        }
    }

    @MainActor
    private func loadResource(force: Bool) async {
        if resource != nil && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            resource = try await load()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct ProfileEventEditorLoaderView: View {
    let eventID: String
    let service: WebFeatureService

    var body: some View {
        ProfileResourceLoaderView(
            loadingText: L("加载活动中...", "Loading event...")
        ) {
            try await service.fetchEvent(id: eventID)
        } content: { event in
            EventEditorView(mode: .edit(event)) {}
        }
    }
}

private struct ProfileSetEditorLoaderView: View {
    let setID: String
    let service: WebFeatureService

    var body: some View {
        ProfileResourceLoaderView(
            loadingText: L("加载 Set 中...", "Loading set...")
        ) {
            try await service.fetchDJSet(id: setID)
        } content: { set in
            DJSetEditorView(mode: .edit(set)) {}
        }
    }
}

private struct ProfileRatingEventEditorLoaderView: View {
    let eventID: String
    let service: WebFeatureService

    var body: some View {
        ProfileResourceLoaderView(
            loadingText: L("加载打分事件中...", "Loading rating event...")
        ) {
            try await service.fetchRatingEvent(id: eventID)
        } content: { event in
            RatingEventEditorSheet(event: event) {}
        }
    }
}

private struct ProfileRatingUnitEditorLoaderView: View {
    let unitID: String
    let service: WebFeatureService

    var body: some View {
        ProfileResourceLoaderView(
            loadingText: L("加载打分单位中...", "Loading rating unit...")
        ) {
            try await service.fetchRatingUnit(id: unitID)
        } content: { unit in
            RatingUnitEditorSheet(unit: unit) {}
        }
    }
}

private struct CurrentUserProfileLoaderView<Content: View>: View {
    let repository: ProfileSocialRepository
    let content: (UserProfile) -> Content

    @State private var profile: UserProfile?
    @State private var errorMessage: String?

    init(
        repository: ProfileSocialRepository,
        @ViewBuilder content: @escaping (UserProfile) -> Content
    ) {
        self.repository = repository
        self.content = content
    }

    var body: some View {
        Group {
            if let profile {
                content(profile)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadProfile(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载中...", "Loading..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadProfile(force: false)
        }
    }

    @MainActor
    private func loadProfile(force: Bool) async {
        if profile != nil && !force { return }
        do {
            profile = try await repository.fetchMyProfile()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
