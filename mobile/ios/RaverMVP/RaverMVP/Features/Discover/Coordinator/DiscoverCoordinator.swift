import SwiftUI

struct DiscoverCoordinatorView<Content: View>: View {
    private let push: (DiscoverRoute) -> Void
    private let content: Content

    init(
        push: @escaping (DiscoverRoute) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.push = push
        self.content = content()
    }

    var body: some View {
        content
            .navigationBarHidden(true)
            .background(RaverTheme.background)
            .environment(\.discoverPush, push)
    }
}
