import Foundation
import UIKit

struct DemoAlignedViewportScrollCoordinatorFactoryDependencies {
    let collectionView: UICollectionView
    let scrollCoordinator: RaverChatScrollCoordinator
}

enum DemoAlignedViewportScrollCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedViewportScrollCoordinatorFactoryDependencies
    ) -> DemoAlignedMessageViewportScrollCoordinator {
        DemoAlignedMessageViewportScrollCoordinator(
            collectionView: dependencies.collectionView,
            scrollCoordinator: dependencies.scrollCoordinator
        )
    }
}
