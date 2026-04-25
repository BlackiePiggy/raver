import Foundation
import UIKit

struct DemoAlignedMediaSendProgressPresenterFactoryDependencies {
    let imageButton: UIButton
    let videoButton: UIButton
    let containerView: UIView
    let progressView: UIProgressView
    let progressLabel: UILabel
    let heightConstraint: NSLayoutConstraint?
    let hostView: UIView
    let onSendingStateChanged: ((Bool) -> Void)?
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedMediaSendProgressPresenterFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedMediaSendProgressPresenterFactoryDependencies
    ) -> DemoAlignedMediaSendProgressPresenter? {
        guard let heightConstraint = dependencies.heightConstraint else {
            dependencies.onMissingDependencies(["mediaProgressHeightConstraint"])
            return nil
        }

        let presenter = DemoAlignedMediaSendProgressPresenter(
            imageButton: dependencies.imageButton,
            videoButton: dependencies.videoButton,
            containerView: dependencies.containerView,
            progressView: dependencies.progressView,
            progressLabel: dependencies.progressLabel,
            heightConstraint: heightConstraint,
            hostView: dependencies.hostView
        )
        presenter.onSendingStateChanged = dependencies.onSendingStateChanged
        return presenter
    }
}
