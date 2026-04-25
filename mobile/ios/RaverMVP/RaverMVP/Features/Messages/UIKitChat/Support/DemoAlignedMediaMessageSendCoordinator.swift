import Foundation

@MainActor
final class DemoAlignedMediaMessageSendCoordinator {
    private let chatController: RaverChatController
    private let progressPresenter: DemoAlignedMediaSendProgressPresenter
    private let chatContextProvider: DemoAlignedChatContextProvider
    private let failureFeedbackActions: DemoAlignedFailureFeedbackActions
    private let onSendSucceeded: () -> Void

    init(
        chatController: RaverChatController,
        progressPresenter: DemoAlignedMediaSendProgressPresenter,
        chatContextProvider: DemoAlignedChatContextProvider,
        failureFeedbackActions: DemoAlignedFailureFeedbackActions,
        onSendSucceeded: @escaping () -> Void
    ) {
        self.chatController = chatController
        self.progressPresenter = progressPresenter
        self.chatContextProvider = chatContextProvider
        self.failureFeedbackActions = failureFeedbackActions
        self.onSendSucceeded = onSendSucceeded
    }

    func sendImage(fileURL: URL) async {
        progressPresenter.setSendingState(true)
        let sessionID = progressPresenter.currentSendingSessionID()
        defer { progressPresenter.setSendingState(false) }

        do {
            _ = try await chatController.sendImageMessage(
                fileURL: fileURL,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.progressPresenter.updateProgress(progress, sessionID: sessionID)
                    }
                }
            )
            onSendSucceeded()
        } catch {
            DemoAlignedChatLogger.sendFailed(
                kind: "image",
                conversationID: chatContextProvider.conversationID,
                error: error
            )
            failureFeedbackActions.showSendFailureHint()
        }
    }

    func sendVideo(fileURL: URL) async {
        progressPresenter.setSendingState(true)
        let sessionID = progressPresenter.currentSendingSessionID()
        defer { progressPresenter.setSendingState(false) }

        do {
            _ = try await chatController.sendVideoMessage(
                fileURL: fileURL,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.progressPresenter.updateProgress(progress, sessionID: sessionID)
                    }
                }
            )
            onSendSucceeded()
        } catch {
            DemoAlignedChatLogger.sendFailed(
                kind: "video",
                conversationID: chatContextProvider.conversationID,
                error: error
            )
            failureFeedbackActions.showSendFailureHint()
        }
    }
}
