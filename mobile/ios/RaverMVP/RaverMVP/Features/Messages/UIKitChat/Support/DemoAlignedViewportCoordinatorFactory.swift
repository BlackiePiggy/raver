import Foundation
import UIKit

struct DemoAlignedViewportCoordinatorFactoryDependencies {
    let hostView: UIView
    let jumpToBottomButton: UIButton
    let keyboardSettleDelayNs: UInt64
}

enum DemoAlignedViewportCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedViewportCoordinatorFactoryDependencies
    ) -> DemoAlignedViewportCoordinator {
        let coordinator = DemoAlignedViewportCoordinator(
            hostView: dependencies.hostView,
            jumpToBottomButton: dependencies.jumpToBottomButton,
            keyboardSettleDelayNs: dependencies.keyboardSettleDelayNs
        )
        coordinator.reset()
        return coordinator
    }
}
