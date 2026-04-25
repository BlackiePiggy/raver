import Foundation
import UIKit

struct DemoAlignedMediaSendCoordinatorFactoryDependencies {
    let presenter: UIViewController
    let chatContextProvider: DemoAlignedChatContextProvider?
    let failureFeedbackActions: DemoAlignedFailureFeedbackActions?
    let onPicked: (DemoAlignedPickedMedia) -> Void
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedMediaSendCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedMediaSendCoordinatorFactoryDependencies
    ) -> DemoAlignedMediaSendCoordinator? {
        guard let chatContextProvider = dependencies.chatContextProvider,
              let failureFeedbackActions = dependencies.failureFeedbackActions else {
            dependencies.onMissingDependencies([
                "chatContextProvider",
                "failureFeedbackActions"
            ])
            return nil
        }

        return DemoAlignedMediaSendCoordinator(
            presenter: dependencies.presenter,
            chatContextProvider: chatContextProvider,
            failureFeedbackActions: failureFeedbackActions,
            onPicked: dependencies.onPicked
        )
    }
}
