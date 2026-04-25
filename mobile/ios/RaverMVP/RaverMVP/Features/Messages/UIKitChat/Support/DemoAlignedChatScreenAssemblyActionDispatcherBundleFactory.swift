import Foundation

struct DemoAlignedChatScreenAssemblyActionDispatcherBundleDependencies {
    let layout: () -> Void
    let collectionView: () -> Void
    let composer: () -> Void
    let jumpToBottomButton: () -> Void
    let olderLoadingIndicator: () -> Void
    let navigationItems: () -> Void

    let viewportScrollCoordinator: () -> Void
    let messageApplyCoordinator: () -> Void
    let sendFailureHintPresenter: () -> Void
    let chatContextProvider: () -> Void
    let messageFailureFeedbackCoordinator: () -> Void
    let failureFeedbackActions: () -> Void

    let mediaProgressPresenter: () -> Void
    let textSendCoordinator: () -> Void
    let mediaMessageSendCoordinator: () -> Void
    let mediaSendCoordinator: () -> Void
    let messageActionCoordinator: () -> Void

    let paginationCoordinator: () -> Void
    let viewportCoordinator: () -> Void
    let composerActionCoordinator: () -> Void
    let keyboardLifecycleCoordinator: () -> Void

    let messageFlowCoordinator: () -> Void
    let controllerBindingCoordinator: () -> Void

    let chatRouteCoordinator: () -> Void
    let chatScreenLifecycleCoordinator: () -> Void
}

enum DemoAlignedChatScreenAssemblyActionDispatcherBundleFactory {
    static func make(
        dependencies: DemoAlignedChatScreenAssemblyActionDispatcherBundleDependencies
    ) -> DemoAlignedChatScreenAssemblyActionDispatcherBundle {
        DemoAlignedChatScreenAssemblyActionDispatcherBundle(
            ui: DemoAlignedChatScreenAssemblyActionMapDispatcher(
                actionMappings: [
                    .layout: dependencies.layout,
                    .collectionView: dependencies.collectionView,
                    .composer: dependencies.composer,
                    .jumpToBottomButton: dependencies.jumpToBottomButton,
                    .olderLoadingIndicator: dependencies.olderLoadingIndicator,
                    .navigationItems: dependencies.navigationItems
                ]
            ),
            coordinatorContext: DemoAlignedChatScreenAssemblyActionMapDispatcher(
                actionMappings: [
                    .viewportScrollCoordinator: dependencies.viewportScrollCoordinator,
                    .messageApplyCoordinator: dependencies.messageApplyCoordinator,
                    .sendFailureHintPresenter: dependencies.sendFailureHintPresenter,
                    .chatContextProvider: dependencies.chatContextProvider,
                    .messageFailureFeedbackCoordinator: dependencies.messageFailureFeedbackCoordinator,
                    .failureFeedbackActions: dependencies.failureFeedbackActions
                ]
            ),
            coordinatorMedia: DemoAlignedChatScreenAssemblyActionMapDispatcher(
                actionMappings: [
                    .mediaProgressPresenter: dependencies.mediaProgressPresenter,
                    .textSendCoordinator: dependencies.textSendCoordinator,
                    .mediaMessageSendCoordinator: dependencies.mediaMessageSendCoordinator,
                    .mediaSendCoordinator: dependencies.mediaSendCoordinator,
                    .messageActionCoordinator: dependencies.messageActionCoordinator
                ]
            ),
            coordinatorScroll: DemoAlignedChatScreenAssemblyActionMapDispatcher(
                actionMappings: [
                    .paginationCoordinator: dependencies.paginationCoordinator,
                    .viewportCoordinator: dependencies.viewportCoordinator,
                    .composerActionCoordinator: dependencies.composerActionCoordinator,
                    .keyboardLifecycleCoordinator: dependencies.keyboardLifecycleCoordinator
                ]
            ),
            coordinatorMessagePipeline: DemoAlignedChatScreenAssemblyActionMapDispatcher(
                actionMappings: [
                    .messageFlowCoordinator: dependencies.messageFlowCoordinator,
                    .controllerBindingCoordinator: dependencies.controllerBindingCoordinator
                ]
            ),
            coordinatorRouteLifecycle: DemoAlignedChatScreenAssemblyActionMapDispatcher(
                actionMappings: [
                    .chatRouteCoordinator: dependencies.chatRouteCoordinator,
                    .chatScreenLifecycleCoordinator: dependencies.chatScreenLifecycleCoordinator
                ]
            )
        )
    }
}
