import Foundation
import UIKit

@MainActor
final class DemoAlignedTextSendCoordinator {
    private let chatController: RaverChatController
    private weak var inputField: UITextField?
    private weak var sendButton: UIButton?
    private let mediaProgressPresenter: DemoAlignedMediaSendProgressPresenter
    private let chatContextProvider: DemoAlignedChatContextProvider
    private let failureFeedbackActions: DemoAlignedFailureFeedbackActions
    private let onSendSucceeded: () -> Void

    init(
        chatController: RaverChatController,
        inputField: UITextField,
        sendButton: UIButton,
        mediaProgressPresenter: DemoAlignedMediaSendProgressPresenter,
        chatContextProvider: DemoAlignedChatContextProvider,
        failureFeedbackActions: DemoAlignedFailureFeedbackActions,
        onSendSucceeded: @escaping () -> Void
    ) {
        self.chatController = chatController
        self.inputField = inputField
        self.sendButton = sendButton
        self.mediaProgressPresenter = mediaProgressPresenter
        self.chatContextProvider = chatContextProvider
        self.failureFeedbackActions = failureFeedbackActions
        self.onSendSucceeded = onSendSucceeded
    }

    func refreshSendButtonState() {
        guard let sendButton else { return }
        let canSend = !trimmedInputText().isEmpty && !mediaProgressPresenter.isSendingMedia
        sendButton.isEnabled = canSend
        sendButton.alpha = canSend ? 1 : 0.45
    }

    func sendCurrentInput() async {
        guard !mediaProgressPresenter.isSendingMedia else { return }
        guard let inputField else { return }

        let text = trimmedInputText()
        guard !text.isEmpty else {
            refreshSendButtonState()
            return
        }

        inputField.text = nil
        refreshSendButtonState()

        do {
            _ = try await chatController.sendTextMessage(text)
            onSendSucceeded()
        } catch {
            DemoAlignedChatLogger.sendFailed(
                kind: "text",
                conversationID: chatContextProvider.conversationID,
                error: error
            )
            failureFeedbackActions.showSendFailureHint()
            if inputField.text?.isEmpty ?? true {
                inputField.text = text
            }
        }

        refreshSendButtonState()
    }

    private func trimmedInputText() -> String {
        (inputField?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
