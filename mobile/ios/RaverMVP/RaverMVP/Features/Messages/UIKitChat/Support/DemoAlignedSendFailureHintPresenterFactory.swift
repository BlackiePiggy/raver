import Foundation
import UIKit

struct DemoAlignedSendFailureHintPresenterFactoryDependencies {
    let hostView: UIView
    let anchorView: UIView
}

enum DemoAlignedSendFailureHintPresenterFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedSendFailureHintPresenterFactoryDependencies
    ) -> DemoAlignedSendFailureHintPresenter {
        DemoAlignedSendFailureHintPresenter(
            hostView: dependencies.hostView,
            anchorView: dependencies.anchorView
        )
    }
}
