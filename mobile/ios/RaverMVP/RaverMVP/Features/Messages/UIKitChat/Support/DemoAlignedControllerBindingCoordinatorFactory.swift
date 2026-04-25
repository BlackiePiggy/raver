import Foundation

struct DemoAlignedControllerBindingCoordinatorFactoryDependencies {
    let chatController: RaverChatController
    let messageFlowCoordinator: DemoAlignedMessageFlowCoordinator?
    let paginationCoordinator: DemoAlignedPaginationCoordinator?
}

enum DemoAlignedControllerBindingCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedControllerBindingCoordinatorFactoryDependencies
    ) -> DemoAlignedControllerBindingCoordinator {
        DemoAlignedControllerBindingCoordinator(
            chatController: dependencies.chatController,
            onMessagesChanged: { [weak messageFlowCoordinator = dependencies.messageFlowCoordinator] in
                messageFlowCoordinator?.applyMessagesFromController()
            },
            onLoadingOlderChanged: { [weak paginationCoordinator = dependencies.paginationCoordinator] isLoading in
                paginationCoordinator?.updateLoadingState(isLoading)
            }
        )
    }
}
