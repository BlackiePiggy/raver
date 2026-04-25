import Foundation
import UIKit

struct DemoAlignedKeyboardLifecycleCoordinatorFactoryDependencies {
    let hostView: UIView
    let inputField: UITextField
    let nearBottomThreshold: CGFloat
    let viewportCoordinator: DemoAlignedViewportCoordinator?
    let viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator?
}

enum DemoAlignedKeyboardLifecycleCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedKeyboardLifecycleCoordinatorFactoryDependencies
    ) -> DemoAlignedKeyboardLifecycleCoordinator {
        return DemoAlignedKeyboardLifecycleCoordinator(
            hostView: dependencies.hostView,
            inputField: dependencies.inputField,
            nearBottomThreshold: dependencies.nearBottomThreshold,
            isNearBottom: { [weak viewportScrollCoordinator = dependencies.viewportScrollCoordinator] threshold in
                viewportScrollCoordinator?.isNearBottom(threshold: threshold) ?? true
            },
            onKeyboardWillChangeFrame: { [weak hostView = dependencies.hostView, weak viewportCoordinator = dependencies.viewportCoordinator, weak viewportScrollCoordinator = dependencies.viewportScrollCoordinator] notification, shouldStickToBottom in
                viewportCoordinator?.handleKeyboardWillChangeFrame(
                    notification: notification,
                    shouldStickToBottom: shouldStickToBottom,
                    onLayoutIfNeeded: {
                        hostView?.layoutIfNeeded()
                    },
                    onScrollToBottom: {
                        viewportScrollCoordinator?.scrollToBottom(animated: false)
                    }
                )
            },
            onKeyboardWillHide: { [weak hostView = dependencies.hostView, weak viewportCoordinator = dependencies.viewportCoordinator, weak viewportScrollCoordinator = dependencies.viewportScrollCoordinator] notification, shouldStickToBottom in
                viewportCoordinator?.handleKeyboardWillHide(
                    notification: notification,
                    shouldStickToBottom: shouldStickToBottom,
                    onLayoutIfNeeded: {
                        hostView?.layoutIfNeeded()
                    },
                    onScrollToBottom: {
                        viewportScrollCoordinator?.scrollToBottom(animated: false)
                    },
                    onPostSettle: {
                        let nearBottom = viewportScrollCoordinator?.isNearBottom(
                            threshold: dependencies.nearBottomThreshold
                        ) ?? true
                        viewportCoordinator?.updateJumpToBottomUI(isNearBottom: nearBottom, animated: true)
                    }
                )
            }
        )
    }
}
