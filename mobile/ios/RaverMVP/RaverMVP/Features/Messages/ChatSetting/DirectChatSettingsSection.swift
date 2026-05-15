import SwiftUI

struct DirectChatSettingsSection: View {
    let peer: UserSummary?
    let onOpenProfile: (UserSummary) -> Void

    var body: some View {
        if let peer {
            Button {
                onOpenProfile(peer)
            } label: {
                Label(LT("查看用户主页", "View User Profile", "ユーザープロフィールを見る"), systemImage: "person.crop.circle")
            }
        }
    }
}
