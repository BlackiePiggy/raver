import Foundation
import SwiftUI
import UIKit

@MainActor
final class DemoAlignedMessageActionCoordinator {
    private let chatController: RaverChatController
    private weak var presenter: UIViewController?
    private let chatContextProvider: DemoAlignedChatContextProvider
    private let failureFeedbackActions: DemoAlignedFailureFeedbackActions

    init(
        chatController: RaverChatController,
        presenter: UIViewController,
        chatContextProvider: DemoAlignedChatContextProvider,
        failureFeedbackActions: DemoAlignedFailureFeedbackActions
    ) {
        self.chatController = chatController
        self.presenter = presenter
        self.chatContextProvider = chatContextProvider
        self.failureFeedbackActions = failureFeedbackActions
    }

    func handleMessageTapped(_ message: ChatMessage) async {
        if message.isMine, message.deliveryStatus == .failed {
            await resendMessage(messageID: message.id)
            return
        }

        if message.kind == .image || message.kind == .video {
            presentMediaPreviewIfNeeded(message)
        }
    }

    private func resendMessage(messageID: String) async {
        do {
            _ = try await chatController.resendFailedMessage(messageID: messageID)
        } catch {
            DemoAlignedChatLogger.resendFailed(
                conversationID: chatContextProvider.conversationID,
                messageID: messageID,
                error: error
            )
            failureFeedbackActions.showSendFailureHint()
        }
    }

    private func presentMediaPreviewIfNeeded(_ message: ChatMessage) {
        guard let rawURL = RaverChatMediaResolver.playbackRawURL(for: message), !rawURL.isEmpty else { return }
        guard let presenter else { return }

        let viewer = FullscreenMediaViewer(
            items: [FullscreenMediaItem(rawURL: rawURL, index: 0)],
            initialIndex: 0
        )
        let host = UIHostingController(rootView: viewer)
        host.modalPresentationStyle = .fullScreen
        presenter.present(host, animated: true)
    }
}
