import Foundation

struct DemoAlignedMediaMessageSendCoordinatorFactoryDependencies {
    let chatController: RaverChatController
    let mediaProgressPresenter: DemoAlignedMediaSendProgressPresenter?
    let chatContextProvider: DemoAlignedChatContextProvider?
    let failureFeedbackActions: DemoAlignedFailureFeedbackActions?
    let onSendSucceeded: () -> Void
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedMediaMessageSendCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedMediaMessageSendCoordinatorFactoryDependencies
    ) -> DemoAlignedMediaMessageSendCoordinator? {
        guard let mediaProgressPresenter = dependencies.mediaProgressPresenter,
              let chatContextProvider = dependencies.chatContextProvider,
              let failureFeedbackActions = dependencies.failureFeedbackActions else {
            dependencies.onMissingDependencies([
                "mediaProgressPresenter",
                "chatContextProvider",
                "failureFeedbackActions"
            ])
            return nil
        }

        return DemoAlignedMediaMessageSendCoordinator(
            chatController: dependencies.chatController,
            progressPresenter: mediaProgressPresenter,
            chatContextProvider: chatContextProvider,
            failureFeedbackActions: failureFeedbackActions,
            onSendSucceeded: dependencies.onSendSucceeded
        )
    }
}
