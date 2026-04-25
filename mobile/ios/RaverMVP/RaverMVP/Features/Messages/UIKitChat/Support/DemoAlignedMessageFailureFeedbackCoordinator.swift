import Foundation

@MainActor
final class DemoAlignedMessageFailureFeedbackCoordinator {
    private weak var hintPresenter: DemoAlignedSendFailureHintPresenter?
    private let chatContextProvider: DemoAlignedChatContextProvider

    init(
        hintPresenter: DemoAlignedSendFailureHintPresenter,
        chatContextProvider: DemoAlignedChatContextProvider
    ) {
        self.hintPresenter = hintPresenter
        self.chatContextProvider = chatContextProvider
    }

    func showSendFailureHint() {
        DemoAlignedChatLogger.sendFailureHintShown(
            conversationID: chatContextProvider.conversationID
        )
        hintPresenter?.show(
            message: L("消息发送失败，点按气泡重试", "Send failed. Tap bubble to retry")
        )
    }

    func show(message: String, reason: String) {
        DemoAlignedChatLogger.failureHintShown(
            conversationID: chatContextProvider.conversationID,
            reason: reason
        )
        hintPresenter?.show(message: message)
    }

    func reset() {
        hintPresenter?.reset()
    }
}
