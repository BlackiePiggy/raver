import Foundation
import UIKit

struct DemoAlignedMessageApplyCoordinatorFactoryDependencies {
    let viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator?
    let collectionView: UICollectionView
    let collectionDataSource: RaverChatCollectionDataSource
    let nearBottomThreshold: CGFloat
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedMessageApplyCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedMessageApplyCoordinatorFactoryDependencies
    ) -> DemoAlignedMessageApplyCoordinator? {
        guard let viewportScrollCoordinator = dependencies.viewportScrollCoordinator else {
            dependencies.onMissingDependencies(["viewportScrollCoordinator"])
            return nil
        }

        return DemoAlignedMessageApplyCoordinator(
            viewportScrollCoordinator: viewportScrollCoordinator,
            collectionView: dependencies.collectionView,
            collectionDataSource: dependencies.collectionDataSource,
            nearBottomThreshold: dependencies.nearBottomThreshold
        )
    }
}
