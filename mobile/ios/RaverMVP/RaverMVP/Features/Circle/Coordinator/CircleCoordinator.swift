import SwiftUI

enum CircleRoute: Hashable {
    case squadProfile(String)
    case ratingEventDetail(String)
    case eventDetail(String)
    case djDetail(String)
    case userProfile(String)
    case postDetail(Post)
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
        }
    }
}
