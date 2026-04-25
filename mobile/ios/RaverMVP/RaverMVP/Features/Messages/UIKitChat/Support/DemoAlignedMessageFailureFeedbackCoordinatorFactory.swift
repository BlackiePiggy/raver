import Foundation

struct DemoAlignedMessageFailureFeedbackCoordinatorFactoryDependencies {
    let hintPresenter: DemoAlignedSendFailureHintPresenter?
    let chatContextProvider: DemoAlignedChatContextProvider?
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedMessageFailureFeedbackCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedMessageFailureFeedbackCoordinatorFactoryDependencies
    ) -> DemoAlignedMessageFailureFeedbackCoordinator? {
        guard let hintPresenter = dependencies.hintPresenter,
              let chatContextProvider = dependencies.chatContextProvider else {
            dependencies.onMissingDependencies([
                "sendFailureHintPresenter",
                "chatContextProvider"
            ])
            return nil
        }

        return DemoAlignedMessageFailureFeedbackCoordinator(
            hintPresenter: hintPresenter,
            chatContextProvider: chatContextProvider
        )
    }
}
