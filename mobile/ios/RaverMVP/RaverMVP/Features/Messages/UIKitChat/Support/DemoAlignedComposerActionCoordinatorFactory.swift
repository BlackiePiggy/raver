import Foundation
import UIKit

struct DemoAlignedComposerActionCoordinatorFactoryDependencies {
    let nearBottomThreshold: CGFloat
    let textSendCoordinator: DemoAlignedTextSendCoordinator?
    let currentInputText: () -> String
    let notifyInputChanged: (String) -> Void
    let mediaProgressPresenter: DemoAlignedMediaSendProgressPresenter?
    let mediaSendCoordinator: DemoAlignedMediaSendCoordinator?
    let viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator?
    let viewportCoordinator: DemoAlignedViewportCoordinator?
}

enum DemoAlignedComposerActionCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedComposerActionCoordinatorFactoryDependencies
    ) -> DemoAlignedComposerActionCoordinator {
        return DemoAlignedComposerActionCoordinator(
            nearBottomThreshold: dependencies.nearBottomThreshold,
            sendText: { [weak textSendCoordinator = dependencies.textSendCoordinator] in
                await textSendCoordinator?.sendCurrentInput()
            },
            refreshSendButtonState: { [weak textSendCoordinator = dependencies.textSendCoordinator] in
                textSendCoordinator?.refreshSendButtonState()
            },
            currentInputText: dependencies.currentInputText,
            notifyInputChanged: dependencies.notifyInputChanged,
            isSendingMedia: { [weak mediaProgressPresenter = dependencies.mediaProgressPresenter] in
                mediaProgressPresenter?.isSendingMedia == true
            },
            presentImagePicker: { [weak mediaSendCoordinator = dependencies.mediaSendCoordinator] in
                mediaSendCoordinator?.presentImagePicker()
            },
            presentVideoPicker: { [weak mediaSendCoordinator = dependencies.mediaSendCoordinator] in
                mediaSendCoordinator?.presentVideoPicker()
            },
            scrollToBottom: { [weak viewportScrollCoordinator = dependencies.viewportScrollCoordinator] animated in
                viewportScrollCoordinator?.scrollToBottom(animated: animated)
            },
            isNearBottom: { [weak viewportScrollCoordinator = dependencies.viewportScrollCoordinator] threshold in
                viewportScrollCoordinator?.isNearBottom(threshold: threshold) ?? true
            },
            updateJumpToBottomUI: { [weak viewportCoordinator = dependencies.viewportCoordinator] isNearBottom, animated in
                viewportCoordinator?.updateJumpToBottomUI(isNearBottom: isNearBottom, animated: animated)
            }
        )
    }
}
