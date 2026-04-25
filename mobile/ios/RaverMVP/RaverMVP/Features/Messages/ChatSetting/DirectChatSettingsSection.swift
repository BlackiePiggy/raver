import SwiftUI

struct DirectChatSettingsSection: View {
    let peer: UserSummary?
    let onOpenProfile: (UserSummary) -> Void

    var body: some View {
        if let peer {
            Button {
                onOpenProfile(peer)
            } label: {
                Label(L("查看用户主页", "View User Profile"), systemImage: "person.crop.circle")
            }
        }
    }
}
