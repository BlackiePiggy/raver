import Foundation
import UIKit

struct DemoAlignedPaginationCoordinatorFactoryDependencies {
    let loadingIndicator: UIActivityIndicatorView
    let topTriggerOffset: CGFloat
    let onLoadOlder: () async -> Void
}

enum DemoAlignedPaginationCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedPaginationCoordinatorFactoryDependencies
    ) -> DemoAlignedPaginationCoordinator {
        DemoAlignedPaginationCoordinator(
            loadingIndicator: dependencies.loadingIndicator,
            topTriggerOffset: dependencies.topTriggerOffset,
            onLoadOlder: dependencies.onLoadOlder
        )
    }
}
