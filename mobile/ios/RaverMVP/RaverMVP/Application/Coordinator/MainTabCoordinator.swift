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
    case conversation(target: ChatRouteTarget)
    case followedEventsInbox
    case followedDJsInbox
    case followedBrandsInbox
    case postDetail(postID: String)
    case eventDetail(eventID: String)
    case newsDetail(articleID: String)
    case eventSchedule(eventID: String)
    case eventRoute(
        eventID: String,
        ownerUserID: String?,
        ownerDisplayName: String?,
        selectedDayID: String?,
        selectedSlotIDs: [String]?
    )
    case djDetail(djID: String)
    case labelDetail(labelID: String)
    case rankingBoardDetail(board: RankingBoard, year: Int?)
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
             .followedEventsInbox,
             .followedDJsInbox,
             .followedBrandsInbox,
             .postDetail,
             .eventDetail,
             .newsDetail,
             .eventSchedule,
             .eventRoute,
             .djDetail,
             .labelDetail,
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
        case .followedEventsInbox:
            return "followed.events.inbox"
        case .followedDJsInbox:
            return "followed.djs.inbox"
        case .followedBrandsInbox:
            return "followed.brands.inbox"
        case .postDetail:
            return "post.detail"
        case .eventDetail:
            return "event.detail"
        case .newsDetail:
            return "news.detail"
        case .eventSchedule:
            return "event.schedule"
        case .eventRoute:
            return "event.route"
        case .djDetail:
            return "dj.detail"
        case .labelDetail:
            return "label.detail"
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
        case .followedEventsInbox:
            return .messages
        case .followedDJsInbox:
            return .messages
        case .followedBrandsInbox:
            return .messages
        case .postDetail, .squadProfile, .squadManage, .ratingUnitDetail:
            return .circle
        case .eventDetail, .newsDetail, .eventSchedule, .eventRoute, .djDetail, .labelDetail, .rankingBoardDetail:
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
#if DEBUG
        let description: String = {
            switch route {
            case .eventDetail(let eventID):
                return "eventDetail(\(eventID))"
            case .circle(let circleRoute):
                return "circle(\(circleRoute))"
            case .conversation(let target):
                return "conversation(\(target.debugSummary))"
            case .postDetail(let postID):
                return "postDetail(\(postID))"
            case .followedEventsInbox:
                return "followedEventsInbox"
            case .followedDJsInbox:
                return "followedDJsInbox"
            case .followedBrandsInbox:
                return "followedBrandsInbox"
            case .newsDetail(let articleID):
                return "newsDetail(\(articleID))"
            case .eventSchedule(let eventID):
                return "eventSchedule(\(eventID))"
            case .eventRoute(let eventID, let ownerUserID, let ownerDisplayName, _, let selectedSlotIDs):
                let owner = ownerDisplayName ?? ownerUserID ?? "nil"
                let slotCount = selectedSlotIDs?.count ?? 0
                return "eventRoute(\(eventID),owner=\(owner),slots=\(slotCount))"
            case .djDetail(let djID):
                return "djDetail(\(djID))"
            case .labelDetail(let labelID):
                return "labelDetail(\(labelID))"
            case .rankingBoardDetail(let board, let year):
                return "rankingBoardDetail(\(board.id), year=\(year?.description ?? "nil"))"
            case .squadProfile(let squadID):
                return "squadProfile(\(squadID))"
            case .squadManage(let squadID):
                return "squadManage(\(squadID))"
            case .ratingUnitDetail(let unitID):
                return "ratingUnitDetail(\(unitID))"
            case .userProfile(let userID):
                return "userProfile(\(userID))"
            case .discover(let route):
                return "discover(\(route))"
            case .messages(let route):
                return "messages(\(route))"
            case .profile(let route):
                return "profile(\(route))"
            }
        }()
        print("[RatingEventResolve] AppRouter.push route=\(description)")
        if case .eventDetail = route {
            print("[RatingEventResolve] AppRouter.push stack for eventDetail: begin")
            for (index, line) in Thread.callStackSymbols.prefix(20).enumerated() {
                print("[RatingEventResolve][stack \(index)] \(line)")
            }
            print("[RatingEventResolve] AppRouter.push stack for eventDetail: end")
        }
#endif
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
    @State private var handledSystemDeepLinkEventID: UUID?
    @State private var didReplayPushRouteTrace = false

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
        .task {
            if !didReplayPushRouteTrace {
                PushRouteTrace.dumpToConsole()
                didReplayPushRouteTrace = true
            }
            if let event = appState.systemDeepLinkEvent,
               handledSystemDeepLinkEventID != event.id {
                debugSystemRoute("consume pending systemDeepLinkEvent id=\(event.id) source=\(event.source) deeplink=\(event.deeplink)")
                handledSystemDeepLinkEventID = event.id
                handleSystemDeepLink(event.deeplink)
            }
        }
        .onReceive(appState.$systemDeepLinkEvent.compactMap { $0 }) { event in
            guard handledSystemDeepLinkEventID != event.id else { return }
            debugSystemRoute("receive systemDeepLinkEvent id=\(event.id) source=\(event.source) deeplink=\(event.deeplink)")
            handledSystemDeepLinkEventID = event.id
            handleSystemDeepLink(event.deeplink)
        }
    }

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        let _ = {
#if DEBUG
            print("[RatingEventResolve] routeDestination route=\(describeRoute(route))")
#endif
        }()
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

        case .messages(let messagesRoute):
            switch messagesRoute {
            case let .alertCategory(category):
                MessagesAlertDetailContainerView(
                    category: category,
                    repository: appContainer.messagesRepository
                ) {
                    NotificationCenter.default.post(name: .raverMessageAlertsDidMutate, object: nil)
                    Task {
                        await appState.refreshUnreadMessages()
                    }
                }
            case let .chatSettings(conversation):
                ChatSettingsView(
                    conversation: conversation,
                    service: appContainer.socialService,
                    chatStore: IMChatStore.shared
                )
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
            case .tools:
                ProfileToolsHubView()
            case .widgetManager:
                WidgetEventManagerView()
            case .movieBanner:
                MovieBannerEditorView()
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
            case let .myCheckins(targetUserID, title, ownerDisplayName):
                MyCheckinsView(
                    targetUserID: targetUserID,
                    title: title,
                    ownerDisplayName: ownerDisplayName
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

        case let .conversation(target):
            ConversationLoaderView(
                target: target,
                service: appContainer.socialService
            )

        case .followedEventsInbox:
            FollowedEventsInboxView(repository: appContainer.messagesRepository)

        case .followedDJsInbox:
            FollowedDJsInboxView(repository: appContainer.messagesRepository)

        case .followedBrandsInbox:
            FollowedBrandsInboxView(repository: appContainer.messagesRepository)

        case let .postDetail(postID):
            PostDetailLoaderView(postID: postID, service: appContainer.socialService)
                .environmentObject(appState)

        case .eventDetail(let eventID):
            EventDetailView(eventID: eventID)

        case .newsDetail(let articleID):
            makeDiscoverRouteDestination(
                .newsDetail(articleID: articleID),
                push: pushDiscoverRoute,
                appContainer: appContainer
            )

        case .eventSchedule(let eventID):
            EventDetailView(eventID: eventID, initialTabRawValue: "schedule")

        case let .eventRoute(eventID, ownerUserID, ownerDisplayName, selectedDayID, selectedSlotIDs):
            EventRoutePlannerLoaderView(
                eventID: eventID,
                ownerUserID: ownerUserID,
                ownerDisplayName: ownerDisplayName,
                selectedDayID: selectedDayID,
                selectedSlotIDs: selectedSlotIDs
            )

        case .djDetail(let djID):
            DJDetailView(djID: djID)

        case .labelDetail(let labelID):
            makeDiscoverRouteDestination(
                .labelDetail(labelID: labelID),
                push: pushDiscoverRoute,
                appContainer: appContainer
            )

        case .rankingBoardDetail(let board, let year):
            RankingBoardDetailView(board: board, initialYear: year)

        case .userProfile(let userID):
            UserProfileView(userID: TencentIMIdentity.normalizePlatformUserIDForProfile(userID))

        case .squadProfile(let squadID):
            SquadProfileView(
                squadID: TencentIMIdentity.normalizePlatformSquadID(squadID),
                service: appContainer.socialService
            )
                .environmentObject(appState)

        case .squadManage(let squadID):
            SquadManageRouteView(
                squadID: TencentIMIdentity.normalizePlatformSquadID(squadID),
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
                    squadID: TencentIMIdentity.normalizePlatformSquadID(squadID),
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
#if DEBUG
        print("[RatingEventResolve] pushCircleRoute route=\(route)")
#endif
        switch route {
        case .postCreate,
                .postEdit,
                .idCreate,
                .idDetail,
                .ratingEventDetail,
                .ratingEventCreate,
                .ratingEventImportFromEvent,
                .ratingUnitCreate:
            router.push(.circle(route))
        }
    }

    private func pushMessagesRoute(_ route: MessagesRoute) {
        switch route {
        case .alertCategory, .chatSettings:
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
                .tools,
                .widgetManager,
                .movieBanner,
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

    private func handleSystemDeepLink(_ deeplink: String) {
        debugSystemRoute("handle deeplink start value=\(deeplink)")
        guard let route = mapAppRoute(from: deeplink) else {
            debugSystemRoute("handle deeplink failed to map value=\(deeplink)")
            return
        }
        debugSystemRoute("handle deeplink mapped route=\(describeRoute(route))")
        if let tab = route.preferredTab {
            debugSystemRoute("switch tab to \(describeTab(tab)) for route=\(describeRoute(route))")
            router.switchTab(tab)
        }
        if router.path.last == route {
            debugSystemRoute("skip push because route already on top route=\(describeRoute(route))")
            return
        }
        debugSystemRoute("push route=\(describeRoute(route)) pathDepthBefore=\(router.path.count)")
        router.push(route)
    }

    private func mapAppRoute(from deeplink: String) -> AppRoute? {
        guard let url = URL(string: deeplink) else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let conversationType = queryItems.first(where: { $0.name == "conversationType" })?.value
        let businessConversationID = queryItems.first(where: { $0.name == "conversationID" })?.value
        let peerID = queryItems.first(where: { $0.name == "peerID" })?.value
        let groupID = queryItems.first(where: { $0.name == "groupID" })?.value
        let host = url.host?.lowercased() ?? ""
        let pathParts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        debugSystemRoute(
            "mapAppRoute deeplink=\(deeplink) host=\(host) pathParts=\(pathParts) query={conversationType=\(conversationType ?? "nil"),conversationID=\(businessConversationID ?? "nil"),peerID=\(peerID ?? "nil"),groupID=\(groupID ?? "nil")}"
        )

        if host == "messages", pathParts.count >= 2, pathParts[0].lowercased() == "conversation" {
            let target = ChatRouteTarget.pushReference(
                preferredConversationID: pathParts[1],
                businessConversationID: businessConversationID,
                conversationType: conversationType,
                peerID: peerID,
                groupID: groupID
            )
            debugSystemRoute("mapAppRoute resolved chat target=\(target.debugSummary)")
            return .conversation(target: target)
        }

        if host == "messages", pathParts.count >= 1, pathParts[0].lowercased() == "followed-events" {
            return .followedEventsInbox
        }

        if host == "messages", pathParts.count >= 1, pathParts[0].lowercased() == "followed-djs" {
            return .followedDJsInbox
        }

        if host == "messages", pathParts.count >= 1, pathParts[0].lowercased() == "followed-brands" {
            return .followedBrandsInbox
        }

        if host == "community", pathParts.count >= 2, pathParts[0].lowercased() == "post" {
            return .postDetail(postID: pathParts[1])
        }

        if host == "event", let eventID = pathParts.first {
            return .eventDetail(eventID: eventID)
        }

        if host == "news", let articleID = pathParts.first {
            return .newsDetail(articleID: articleID)
        }

        if host == "dj", let djID = pathParts.first {
            return .djDetail(djID: djID)
        }

        if host == "label", let labelID = pathParts.first {
            return .labelDetail(labelID: labelID)
        }

        if host == "ranking-board", let boardID = pathParts.first {
            let year = queryItems.first(where: { $0.name == "year" })?.value.flatMap(Int.init)
            let title = queryItems.first(where: { $0.name == "title" })?.value ?? L("榜单", "Ranking Board")
            let subtitle = queryItems.first(where: { $0.name == "subtitle" })?.value
            let coverImageURL = queryItems.first(where: { $0.name == "coverImageURL" })?.value
            let board = RankingBoard(
                id: boardID,
                title: title,
                subtitle: subtitle?.isEmpty == false ? subtitle : nil,
                coverImageUrl: coverImageURL?.isEmpty == false ? coverImageURL : nil,
                years: year.map { [$0] } ?? []
            )
            return .rankingBoardDetail(board: board, year: year)
        }

        if host == "squad", let squadID = pathParts.first {
            return .squadProfile(squadID: squadID)
        }

        if host == "profile", let userID = pathParts.first {
            return .userProfile(userID: userID)
        }

        let normalizedParts = ([host] + pathParts).filter { !$0.isEmpty }
        if normalizedParts.count >= 3, normalizedParts[0] == "messages", normalizedParts[1] == "conversation" {
            let target = ChatRouteTarget.pushReference(
                preferredConversationID: normalizedParts[2],
                businessConversationID: businessConversationID,
                conversationType: conversationType,
                peerID: peerID,
                groupID: groupID
            )
            debugSystemRoute("mapAppRoute resolved normalized chat target=\(target.debugSummary)")
            return .conversation(target: target)
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "messages", normalizedParts[1] == "followed-events" {
            return .followedEventsInbox
        }

        if normalizedParts.count >= 2, normalizedParts[0] == "messages", normalizedParts[1] == "followed-djs" {
            return .followedDJsInbox
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "messages", normalizedParts[1] == "followed-brands" {
            return .followedBrandsInbox
        }
        if normalizedParts.count >= 3, normalizedParts[0] == "community", normalizedParts[1] == "post" {
            return .postDetail(postID: normalizedParts[2])
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "event" {
            return .eventDetail(eventID: normalizedParts[1])
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "news" {
            return .newsDetail(articleID: normalizedParts[1])
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "dj" {
            return .djDetail(djID: normalizedParts[1])
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "label" {
            return .labelDetail(labelID: normalizedParts[1])
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "ranking-board" {
            let year = queryItems.first(where: { $0.name == "year" })?.value.flatMap(Int.init)
            let title = queryItems.first(where: { $0.name == "title" })?.value ?? L("榜单", "Ranking Board")
            let subtitle = queryItems.first(where: { $0.name == "subtitle" })?.value
            let coverImageURL = queryItems.first(where: { $0.name == "coverImageURL" })?.value
            let board = RankingBoard(
                id: normalizedParts[1],
                title: title,
                subtitle: subtitle?.isEmpty == false ? subtitle : nil,
                coverImageUrl: coverImageURL?.isEmpty == false ? coverImageURL : nil,
                years: year.map { [$0] } ?? []
            )
            return .rankingBoardDetail(board: board, year: year)
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "squad" {
            return .squadProfile(squadID: normalizedParts[1])
        }
        if normalizedParts.count >= 2, normalizedParts[0] == "profile" {
            return .userProfile(userID: normalizedParts[1])
        }
        return nil
    }

    private func describeRoute(_ route: AppRoute) -> String {
        switch route {
        case .conversation(let target):
            return "conversation(\(target.debugSummary))"
        case .postDetail(let postID):
            return "postDetail(\(postID))"
        case .followedEventsInbox:
            return "followedEventsInbox"
        case .followedDJsInbox:
            return "followedDJsInbox"
        case .followedBrandsInbox:
            return "followedBrandsInbox"
        case .eventDetail(let eventID):
            return "eventDetail(\(eventID))"
        case .newsDetail(let articleID):
            return "newsDetail(\(articleID))"
        case .eventSchedule(let eventID):
            return "eventSchedule(\(eventID))"
        case .eventRoute(let eventID, let ownerUserID, let ownerDisplayName, _, let selectedSlotIDs):
            let owner = ownerDisplayName ?? ownerUserID ?? "nil"
            let slotCount = selectedSlotIDs?.count ?? 0
            return "eventRoute(\(eventID),owner=\(owner),slots=\(slotCount))"
        case .djDetail(let djID):
            return "djDetail(\(djID))"
        case .labelDetail(let labelID):
            return "labelDetail(\(labelID))"
        case .squadProfile(let squadID):
            return "squadProfile(\(squadID))"
        case .userProfile(let userID):
            return "userProfile(\(userID))"
        default:
            return String(describing: route)
        }
    }

    private func describeTab(_ tab: MainTab) -> String {
        switch tab {
        case .discover:
            return "discover"
        case .circle:
            return "circle"
        case .messages:
            return "messages"
        case .profile:
            return "profile"
        }
    }

    private func debugSystemRoute(_ message: String) {
        PushRouteTrace.log("SystemPushRoute", message)
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
            await viewModel.markAllRead(for: category.type)
            onReadChange()
        }
    }
}

private struct RouteLoaderScaffold<Content: View>: View {
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

private struct ConversationLoaderView: View {
    @EnvironmentObject private var appState: AppState

    let target: ChatRouteTarget
    let service: SocialService

    @State private var conversation: Conversation?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false

    var body: some View {
        RouteLoaderScaffold(
            phase: phase,
            title: L("会话加载失败", "Conversation Failed to Load"),
            loadingView: AnyView(FeedSkeletonView(count: 4)),
            retry: {
                Task { await loadConversation(force: true) }
            }
        ) {
            if let conversation {
                TencentUIKitChatView(conversation: conversation, service: service)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyView()
            }
        }
        .task {
            debug("view task start target=\(target.debugSummary)")
            if let stagedConversation = target.stagedConversation {
                applyResolvedConversation(stagedConversation, logPrefix: "resolved from staged route")
                DispatchQueue.main.async {
                    IMChatStore.shared.stageConversation(stagedConversation)
                }
            }
            await loadConversation(force: false)
        }
        .onChange(of: appState.tencentIMConnectionState) { oldValue, newValue in
            debug("tencent im state changed \(oldValue) -> \(newValue) conversationID=\(target.preferredConversationID)")
            guard conversation == nil else { return }
            guard case .connected = newValue else { return }
            Task {
                await loadConversation(force: true)
            }
        }
        .onChange(of: appState.isAuthBootstrapping) { oldValue, newValue in
            guard oldValue != newValue else { return }
            guard conversation == nil else { return }
            guard newValue == false else { return }
            Task {
                await loadConversation(force: true)
            }
        }
    }

    @MainActor
    private func loadConversation(force: Bool) async {
        if conversation != nil && !force {
            debug("skip load conversation: already resolved target=\(target.debugSummary) current=\(describeConversation(conversation))")
            return
        }

        if resolveConversationFromCache() {
            debug("resolved from cache before remote fetch target=\(target.debugSummary)")
            return
        }

        if shouldWaitForSessionRecovery {
            phase = .initialLoading
            debug(
                "wait for session recovery target=\(target.debugSummary) authBootstrapping=\(appState.isAuthBootstrapping) tencentState=\(appState.tencentIMConnectionState)"
            )
            return
        }

        isLoading = true
        phase = .initialLoading
        defer { isLoading = false }
        debug(
            "load start force=\(force) target=\(target.debugSummary) tencentState=\(appState.tencentIMConnectionState) cachedCount=\(IMChatStore.shared.conversations.count) cacheSnapshot=\(summarizeConversations(IMChatStore.shared.conversations))"
        )

        do {
            let allConversations = try await withTimeout(seconds: 8) {
                async let directConversations = service.fetchConversations(type: .direct)
                async let groupConversations = service.fetchConversations(type: .group)
                return try await directConversations + groupConversations
            }
            debug("remote fetch success total=\(allConversations.count) snapshot=\(summarizeConversations(allConversations))")

            if let found = allConversations.first(where: {
                matchesRouteTarget($0, target: target)
            }) {
                applyResolvedConversation(found, logPrefix: "resolved from remote fetch")
                DispatchQueue.main.async {
                    IMChatStore.shared.stageConversation(found)
                }
            } else {
                phase = .empty
                debug("remote fetch completed but conversation not found target=\(target.debugSummary) remoteMatches=\(summarizePotentialMatches(allConversations))")
            }
        } catch {
            debug("remote fetch failed target=\(target.debugSummary) error=\(error.localizedDescription)")

            if resolveConversationFromCache() {
                debug("resolved from cache after remote failure target=\(target.debugSummary)")
                return
            }

            if let message = error.userFacingMessage, !message.isEmpty {
                phase = .failure(message: message)
            } else {
                phase = .failure(
                    message: L(
                        "聊天连接恢复中，请稍后重试",
                        "Chat connection is recovering. Please retry in a moment."
                    )
                )
            }
            debug("set loader phase failure")
        }
    }

    @MainActor
    private func resolveConversationFromCache() -> Bool {
        let storeMatch = IMChatStore.shared.conversations.first(where: {
            matchesRouteTarget($0, target: target)
        })
        let candidate = preferredConversationCandidate(
            target.stagedConversation,
            storeMatch
        )

        if let candidate {
            applyResolvedConversation(candidate, logPrefix: "resolved from cache")
            return true
        }
        debug("cache resolve miss target=\(target.debugSummary) cacheSnapshot=\(summarizeConversations(IMChatStore.shared.conversations)) potentialMatches=\(summarizePotentialMatches(IMChatStore.shared.conversations))")
        return false
    }

    @MainActor
    private func applyResolvedConversation(_ candidate: Conversation, logPrefix: String) {
        let previousConversation = conversation
        conversation = candidate
        phase = .success
        if let previousConversation, previousConversation != candidate {
            debug("\(logPrefix) updated target=\(target.debugSummary) conversation=\(describeConversation(candidate))")
        } else {
            debug("\(logPrefix) target=\(target.debugSummary) conversation=\(describeConversation(candidate))")
        }
    }

    private func preferredConversationCandidate(
        _ lhs: Conversation?,
        _ rhs: Conversation?
    ) -> Conversation? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            let lhsScore = conversationIdentityScore(lhs)
            let rhsScore = conversationIdentityScore(rhs)
            if rhsScore != lhsScore {
                return rhsScore > lhsScore ? rhs : lhs
            }
            return rhs.updatedAt >= lhs.updatedAt ? rhs : lhs
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func conversationIdentityScore(_ conversation: Conversation) -> Int {
        var score = 0
        if let title = normalizedText(conversation.title) {
            score += 1
            if !isFallbackConversationTitle(title, conversation: conversation) {
                score += 3
            }
        }
        if normalizedText(conversation.avatarURL) != nil {
            score += 2
        }
        if let peer = conversation.peer {
            score += userIdentityScore(peer)
        }
        return score
    }

    private func userIdentityScore(_ user: UserSummary) -> Int {
        var score = 0
        if normalizedText(user.id) != nil {
            score += 1
        }
        if let username = normalizedText(user.username), !username.isEmpty {
            score += 1
        }
        if let displayName = normalizedText(user.displayName),
           displayName.lowercased() != normalizedText(user.id)?.lowercased(),
           displayName.lowercased() != normalizedText(user.username)?.lowercased() {
            score += 3
        }
        if normalizedText(user.avatarURL) != nil {
            score += 2
        }
        return score
    }

    private func isFallbackConversationTitle(_ title: String, conversation: Conversation) -> Bool {
        let normalizedTitle = normalizedIdentifier(title)
        let fallbackValues = Set([
            conversation.id,
            conversation.sdkConversationID,
            conversation.peer?.id,
            conversation.peer?.username
        ]
        .compactMap { $0 }
        .map(normalizedIdentifier))

        if fallbackValues.contains(normalizedTitle) {
            return true
        }

        let genericTitles = [
            normalizedIdentifier(L("私信", "Direct")),
            normalizedIdentifier(L("群聊", "Group chat")),
            normalizedIdentifier(L("小队", "Squad"))
        ]
        return genericTitles.contains(normalizedTitle)
    }

    private func normalizedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ServiceError.message(
                    L("会话加载超时，请稍后重试", "Conversation loading timed out. Please retry.")
                )
            }
            guard let result = try await group.next() else {
                throw ServiceError.message(
                    L("会话加载失败，请稍后重试", "Failed to load conversation. Please retry.")
                )
            }
            group.cancelAll()
            return result
        }
    }

    private func debug(_ message: String) {
        print("[ConversationLoader] \(message)")
        IMProbeLogger.log("[ConversationLoader] \(message)")
        PushRouteTrace.log("ConversationLoader", message)
    }

    private func describeConversation(_ conversation: Conversation?) -> String {
        guard let conversation else { return "nil" }
        return "id=\(conversation.id),sdk=\(conversation.sdkConversationID ?? "nil"),type=\(conversation.type.rawValue),peerID=\(conversation.peer?.id ?? "nil"),peerUsername=\(conversation.peer?.username ?? "nil"),title=\(conversation.title)"
    }

    private func summarizeConversations(_ conversations: [Conversation], limit: Int = 12) -> String {
        if conversations.isEmpty { return "[]" }
        let prefix = conversations.prefix(limit).map { describeConversation($0) }
        let suffix = conversations.count > limit ? " ... total=\(conversations.count)" : ""
        return "[\(prefix.joined(separator: " | "))]\(suffix)"
    }

    private func summarizePotentialMatches(_ conversations: [Conversation], limit: Int = 12) -> String {
        let normalizedTargetIDs = Set(([target.preferredConversationID] + target.fallbackConversationIDs).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })

        let candidates = conversations.filter { conversation in
            let values = [
                conversation.id,
                conversation.sdkConversationID,
                conversation.peer?.id,
                conversation.peer?.username
            ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            if values.contains(where: { normalizedTargetIDs.contains($0) }) {
                return true
            }
            switch target.kind {
            case .direct(let userID):
                let normalizedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return values.contains(normalizedUserID)
            case .group(let groupID):
                let normalizedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return values.contains(normalizedGroupID)
            case .none:
                return false
            }
        }

        return summarizeConversations(Array(candidates.prefix(limit)), limit: limit)
    }

    private var shouldWaitForSessionRecovery: Bool {
        if appState.isAuthBootstrapping {
            return true
        }
        switch appState.tencentIMConnectionState {
        case .idle, .initializing, .connecting:
            return true
        case .disabled, .unavailable, .connected, .userSigExpired, .kickedOffline, .failed:
            return false
        }
    }

    private func matchesRouteTarget(_ conversation: Conversation, target: ChatRouteTarget) -> Bool {
        let targetIDs = Set(([target.preferredConversationID] + target.fallbackConversationIDs).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })

        if targetIDs.contains(conversation.id) || targetIDs.contains(conversation.sdkConversationID ?? "") {
            return true
        }

        guard let kind = target.kind else { return false }
        switch kind {
        case .direct(let userID):
            guard conversation.type == .direct else { return false }
            let candidates = [
                conversation.peer?.id,
                conversation.peer?.username,
                conversation.id,
                conversation.sdkConversationID
            ]
            return candidates.contains(userID)
        case .group(let groupID):
            guard conversation.type == .group else { return false }
            return conversation.id == groupID || conversation.sdkConversationID == groupID
        }
    }
}

private struct PostDetailLoaderView: View {
    let postID: String
    let service: SocialService

    @State private var post: Post?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false

    var body: some View {
        RouteLoaderScaffold(
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
                PostDetailView(post: post, service: service)
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

private struct CirclePostEditorLoaderView: View {
    let postID: String
    let service: SocialService
    let webService: WebFeatureService

    @State private var post: Post?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false

    var body: some View {
        RouteLoaderScaffold(
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

private struct ProfileResourceLoaderView<Resource, Content: View>: View {
    let loadingText: String
    let load: () async throws -> Resource
    let content: (Resource) -> Content

    @State private var resource: Resource?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false

    var body: some View {
        RouteLoaderScaffold(
            phase: phase,
            title: loadingText,
            loadingView: AnyView(EventDetailSkeletonView()),
            retry: {
                Task { await loadResource(force: true) }
            }
        ) {
            if let resource {
                content(resource)
            } else {
                EmptyView()
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
        phase = .initialLoading
        defer { isLoading = false }
        do {
            resource = try await load()
            phase = resource == nil ? .empty : .success
        } catch {
            phase = .failure(
                message: error.userFacingMessage ?? L("资源加载失败，请稍后重试", "Failed to load resource. Please try again later.")
            )
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
    @State private var phase: LoadPhase = .idle

    init(
        repository: ProfileSocialRepository,
        @ViewBuilder content: @escaping (UserProfile) -> Content
    ) {
        self.repository = repository
        self.content = content
    }

    var body: some View {
        RouteLoaderScaffold(
            phase: phase,
            title: L("个人资料加载失败", "Profile Failed to Load"),
            loadingView: AnyView(ProfileSkeletonView()),
            retry: {
                Task { await loadProfile(force: true) }
            }
        ) {
            if let profile {
                content(profile)
            } else {
                EmptyView()
            }
        }
        .task {
            await loadProfile(force: false)
        }
    }

    @MainActor
    private func loadProfile(force: Bool) async {
        if profile != nil && !force { return }
        phase = .initialLoading
        do {
            profile = try await repository.fetchMyProfile()
            phase = profile == nil ? .empty : .success
        } catch {
            phase = .failure(
                message: error.userFacingMessage ?? L("个人资料加载失败，请稍后重试", "Failed to load profile. Please try again later.")
            )
        }
    }
}
