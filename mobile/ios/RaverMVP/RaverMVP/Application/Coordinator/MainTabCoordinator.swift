import SwiftUI

enum MainTab: Hashable {
    case discover
    case circle
    case messages
    case profile
}

struct MainTabCoordinatorView: View {
    @State private var selectedTab: MainTab = .discover

    var body: some View {
        MainTabView(selectedTab: $selectedTab)
    }
}
