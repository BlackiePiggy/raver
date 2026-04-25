import Foundation

struct DemoAlignedMessageFlowCoordinatorFactoryDependencies {
    let chatController: RaverChatController
    let messageApplyCoordinator: DemoAlignedMessageApplyCoordinator?
    let viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator?
    let viewportCoordinator: DemoAlignedViewportCoordinator?
    let onSendFailureHint: () -> Void
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedMessageFlowCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedMessageFlowCoordinatorFactoryDependencies
    ) -> DemoAlignedMessageFlowCoordinator? {
        guard let messageApplyCoordinator = dependencies.messageApplyCoordinator,
              let viewportScrollCoordinator = dependencies.viewportScrollCoordinator,
              let viewportCoordinator = dependencies.viewportCoordinator else {
            dependencies.onMissingDependencies([
                "messageApplyCoordinator",
                "viewportScrollCoordinator",
                "viewportCoordinator"
            ])
            return nil
        }

        return DemoAlignedMessageFlowCoordinator(
            chatController: dependencies.chatController,
            messageApplyCoordinator: messageApplyCoordinator,
            viewportScrollCoordinator: viewportScrollCoordinator,
            viewportCoordinator: viewportCoordinator,
            onSendFailureHint: dependencies.onSendFailureHint
        )
    }
}
