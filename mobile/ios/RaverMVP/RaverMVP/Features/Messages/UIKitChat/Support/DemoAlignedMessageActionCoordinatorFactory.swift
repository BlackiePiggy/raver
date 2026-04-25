import Foundation
import UIKit

struct DemoAlignedMessageActionCoordinatorFactoryDependencies {
    let chatController: RaverChatController
    let presenter: UIViewController
    let chatContextProvider: DemoAlignedChatContextProvider?
    let failureFeedbackActions: DemoAlignedFailureFeedbackActions?
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedMessageActionCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedMessageActionCoordinatorFactoryDependencies
    ) -> DemoAlignedMessageActionCoordinator? {
        guard let chatContextProvider = dependencies.chatContextProvider,
              let failureFeedbackActions = dependencies.failureFeedbackActions else {
            dependencies.onMissingDependencies([
                "chatContextProvider",
                "failureFeedbackActions"
            ])
            return nil
        }

        return DemoAlignedMessageActionCoordinator(
            chatController: dependencies.chatController,
            presenter: dependencies.presenter,
            chatContextProvider: chatContextProvider,
            failureFeedbackActions: failureFeedbackActions
        )
    }
}
