import SwiftUI

struct MessagesCoordinatorView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
        }
        .background(RaverTheme.background)
    }
}
