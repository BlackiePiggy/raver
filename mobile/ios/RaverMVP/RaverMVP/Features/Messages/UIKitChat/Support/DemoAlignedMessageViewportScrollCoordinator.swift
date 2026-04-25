import Foundation
import UIKit

@MainActor
final class DemoAlignedMessageViewportScrollCoordinator {
    private weak var collectionView: UICollectionView?
    private let scrollCoordinator: RaverChatScrollCoordinator

    init(
        collectionView: UICollectionView,
        scrollCoordinator: RaverChatScrollCoordinator
    ) {
        self.collectionView = collectionView
        self.scrollCoordinator = scrollCoordinator
    }

    func forceScrollOnNextApply() {
        scrollCoordinator.forceScrollOnNextApply()
    }

    func isNearBottom(threshold: CGFloat) -> Bool {
        guard let collectionView else { return true }
        return scrollCoordinator.isNearBottom(in: collectionView, threshold: threshold)
    }

    func shouldAutoScroll(
        forceScrollToBottom: Bool,
        isLoadingOlder: Bool,
        isNearBottom: Bool,
        lastIDChanged: Bool
    ) -> Bool {
        scrollCoordinator.shouldAutoScroll(
            forceScrollToBottom: forceScrollToBottom,
            isLoadingOlder: isLoadingOlder,
            isNearBottom: isNearBottom,
            lastIDChanged: lastIDChanged
        )
    }

    func capturePaginationAnchor() -> RaverChatScrollCoordinator.PaginationAnchor? {
        guard let collectionView else { return nil }
        return scrollCoordinator.capturePaginationAnchor(in: collectionView)
    }

    func restorePaginationAnchor(_ anchor: RaverChatScrollCoordinator.PaginationAnchor?) {
        guard let collectionView, let anchor else { return }
        scrollCoordinator.restorePaginationAnchor(anchor, in: collectionView)
    }

    func scrollToBottom(animated: Bool) {
        guard let collectionView else { return }
        let contentHeight = collectionView.contentSize.height
        guard contentHeight > 0 else { return }

        let targetY = max(
            -collectionView.adjustedContentInset.top,
            contentHeight - collectionView.bounds.height + collectionView.adjustedContentInset.bottom
        )
        let target = CGPoint(x: collectionView.contentOffset.x, y: targetY)
        collectionView.setContentOffset(target, animated: animated)
    }
}
