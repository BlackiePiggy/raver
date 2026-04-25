import Foundation
import UIKit

struct DemoAlignedChatScreenLifecycleCoordinatorFactoryDependencies {
    let chatController: RaverChatController
    let titleHost: UIViewController?
    let collectionDataSource: RaverChatCollectionDataSource?
    let viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator?
    let paginationCoordinator: DemoAlignedPaginationCoordinator?
    let viewportCoordinator: DemoAlignedViewportCoordinator?
    let messageFlowCoordinator: DemoAlignedMessageFlowCoordinator?
    let failureFeedbackActions: DemoAlignedFailureFeedbackActions?
    let textSendCoordinator: DemoAlignedTextSendCoordinator?
    let chatRouteCoordinator: DemoAlignedChatRouteCoordinator?
}

enum DemoAlignedChatScreenLifecycleCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedChatScreenLifecycleCoordinatorFactoryDependencies
    ) -> DemoAlignedChatScreenLifecycleCoordinator {
        DemoAlignedChatScreenLifecycleCoordinator(
            chatController: dependencies.chatController,
            updateTitle: { [weak titleHost = dependencies.titleHost] title in
                titleHost?.title = title
            },
            updateCollectionConversationType: { [weak collectionDataSource = dependencies.collectionDataSource] conversation in
                collectionDataSource?.updateConversationType(conversation.type)
            },
            forceScrollOnNextApply: { [weak viewportScrollCoordinator = dependencies.viewportScrollCoordinator] in
                viewportScrollCoordinator?.forceScrollOnNextApply()
            },
            resetPagination: { [weak paginationCoordinator = dependencies.paginationCoordinator] in
                paginationCoordinator?.reset()
            },
            resetViewport: { [weak viewportCoordinator = dependencies.viewportCoordinator] in
                viewportCoordinator?.reset()
            },
            resetMessageFlowState: { [weak messageFlowCoordinator = dependencies.messageFlowCoordinator] in
                messageFlowCoordinator?.reset()
            },
            resetSendFailureHint: { [weak failureFeedbackActions = dependencies.failureFeedbackActions] in
                failureFeedbackActions?.reset()
            },
            refreshSendButtonState: { [weak textSendCoordinator = dependencies.textSendCoordinator] in
                textSendCoordinator?.refreshSendButtonState()
            },
            updateRouteContext: { [weak chatRouteCoordinator = dependencies.chatRouteCoordinator] conversation, service, onNavigate, onLeaveConversation in
                chatRouteCoordinator?.updateContext(
                    conversation: conversation,
                    service: service,
                    onNavigate: onNavigate,
                    onLeaveConversation: onLeaveConversation
                )
            }
        )
    }
}
