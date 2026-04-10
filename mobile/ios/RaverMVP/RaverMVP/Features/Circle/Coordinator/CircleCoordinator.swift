import SwiftUI

enum CircleRoute: Hashable {
    case squadProfile(String)
    case ratingEventDetail(String)
    case eventDetail(String)
    case djDetail(String)
    case userProfile(String)
    case postDetail(Post)
    case postCreate
    case postEdit(Post)
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
    static let circleIDDidCreate = Notification.Name("circleIDDidCreate")
    static let circleRatingEventDidCreate = Notification.Name("circleRatingEventDidCreate")
    static let circleRatingUnitDidCreate = Notification.Name("circleRatingUnitDidCreate")
}

struct CircleCoordinatorView<Content: View>: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState
    @State private var navPath: [CircleRoute] = []
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            content
                .navigationBarHidden(true)
                .navigationDestination(for: CircleRoute.self) { route in
                    routeDestination(for: route)
                }
        }
        .background(RaverTheme.background)
        .environment(\.circlePush) { route in
            navPath.append(route)
        }
    }

    @ViewBuilder
    private func routeDestination(for route: CircleRoute) -> some View {
        switch route {
        case let .squadProfile(squadID):
            SquadProfileView(squadID: squadID, service: appContainer.socialService)
                .environmentObject(appState)
        case let .ratingEventDetail(eventID):
            CircleRatingEventDetailView(
                eventID: eventID,
                onClose: {},
                onUpdated: {}
            )
        case let .eventDetail(eventID):
            EventDetailView(eventID: eventID)
        case let .djDetail(djID):
            DJDetailView(djID: djID)
        case let .userProfile(userID):
            UserProfileView(userID: userID)
                .environmentObject(appState)
        case let .postDetail(post):
            PostDetailView(post: post, service: appContainer.socialService)
                .environmentObject(appState)
        case .postCreate:
            ComposePostView(
                service: appContainer.socialService,
                webService: appContainer.webService,
                mode: .create,
                onPostCreated: { created in
                    NotificationCenter.default.post(name: .circlePostDidCreate, object: created)
                }
            )
        case let .postEdit(post):
            ComposePostView(
                service: appContainer.socialService,
                webService: appContainer.webService,
                mode: .edit(post),
                onPostUpdated: { updated in
                    NotificationCenter.default.post(name: .circlePostDidUpdate, object: updated)
                },
                onPostDeleted: { deletedPostID in
                    NotificationCenter.default.post(name: .circlePostDidDelete, object: deletedPostID)
                }
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
