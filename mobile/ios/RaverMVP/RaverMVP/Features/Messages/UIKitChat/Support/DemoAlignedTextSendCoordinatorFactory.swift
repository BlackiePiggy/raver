import Foundation
import UIKit

struct DemoAlignedTextSendCoordinatorFactoryDependencies {
    let chatController: RaverChatController
    let inputField: UITextField
    let sendButton: UIButton
    let mediaProgressPresenter: DemoAlignedMediaSendProgressPresenter?
    let chatContextProvider: DemoAlignedChatContextProvider?
    let failureFeedbackActions: DemoAlignedFailureFeedbackActions?
    let onSendSucceeded: () -> Void
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedTextSendCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedTextSendCoordinatorFactoryDependencies
    ) -> DemoAlignedTextSendCoordinator? {
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

        return DemoAlignedTextSendCoordinator(
            chatController: dependencies.chatController,
            inputField: dependencies.inputField,
            sendButton: dependencies.sendButton,
            mediaProgressPresenter: mediaProgressPresenter,
            chatContextProvider: chatContextProvider,
            failureFeedbackActions: failureFeedbackActions,
            onSendSucceeded: dependencies.onSendSucceeded
        )
    }
}
