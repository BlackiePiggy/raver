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
    @EnvironmentObject private var appState: AppState

    let conversation: Conversation
    let service: SocialService
    let navigationBridge: DemoAlignedChatNavigationBridge
    var virtualAssetRepository: VirtualAssetRepository = AppEnvironment.makeVirtualAssetRepository()

    func makeUIViewController(context: Context) -> DemoAlignedChatViewController {
        let controller = DemoAlignedChatViewController(
            conversation: conversation,
            service: service,
            virtualAssetRepository: virtualAssetRepository,
            accountEnforcementStatusProvider: {
                await MainActor.run {
                    appState.accountEnforcementStatus
                }
            },
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
