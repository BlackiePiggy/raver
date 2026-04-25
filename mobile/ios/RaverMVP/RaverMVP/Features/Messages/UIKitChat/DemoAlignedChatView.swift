import SwiftUI
import UIKit

@MainActor
final class DemoAlignedChatNavigationBridge: ObservableObject {
    weak var controller: DemoAlignedChatViewController?

    func presentConversationSearch() {
        controller?.presentConversationSearch()
    }

    func presentChatSettings() {
        controller?.presentChatSettings()
    }
}

struct DemoAlignedChatView: UIViewControllerRepresentable {
    @Environment(\.appPush) private var appPush
    @Environment(\.dismiss) private var dismiss

    let conversation: Conversation
    let service: SocialService
    let navigationBridge: DemoAlignedChatNavigationBridge

    func makeUIViewController(context: Context) -> DemoAlignedChatViewController {
        let controller = DemoAlignedChatViewController(
            conversation: conversation,
            service: service,
            onNavigate: { route in
                appPush(route)
            },
            onLeaveConversation: {
                dismiss()
            }
        )
        navigationBridge.controller = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: DemoAlignedChatViewController, context: Context) {
        navigationBridge.controller = uiViewController
        uiViewController.updateConversation(
            conversation,
            service: service,
            onNavigate: { route in
                appPush(route)
            },
            onLeaveConversation: {
                dismiss()
            }
        )
    }
}
