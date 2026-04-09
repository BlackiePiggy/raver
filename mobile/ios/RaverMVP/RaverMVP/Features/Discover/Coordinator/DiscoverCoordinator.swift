import SwiftUI

struct DiscoverCoordinatorView<Content: View>: View {
    @State private var navPath: [DiscoverRoute] = []

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            content
                .navigationBarHidden(true)
                .navigationDestination(for: DiscoverRoute.self) { route in
                    DiscoverRouteDestinationView(route: route) { nextRoute in
                        navPath.append(nextRoute)
                    }
                }
        }
        .background(RaverTheme.background)
        .environment(\.discoverPush) { route in
            navPath.append(route)
        }
    }
}
