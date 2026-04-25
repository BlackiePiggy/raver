import Foundation
import UIKit

final class RaverChatScrollCoordinator {
    struct PaginationAnchor {
        let contentHeight: CGFloat
        let offsetY: CGFloat
    }

    private var shouldForceScrollOnNextApply = true

    func forceScrollOnNextApply() {
        shouldForceScrollOnNextApply = true
    }

    func isNearBottom(in collectionView: UICollectionView, threshold: CGFloat) -> Bool {
        let visibleBottom = collectionView.contentOffset.y
            + collectionView.bounds.height
            - collectionView.adjustedContentInset.bottom
        return visibleBottom >= collectionView.contentSize.height - threshold
    }

    func capturePaginationAnchor(in collectionView: UICollectionView) -> PaginationAnchor {
        PaginationAnchor(
            contentHeight: collectionView.contentSize.height,
            offsetY: collectionView.contentOffset.y
        )
    }

    func restorePaginationAnchor(_ anchor: PaginationAnchor, in collectionView: UICollectionView) {
        collectionView.layoutIfNeeded()
        let newHeight = collectionView.contentSize.height
        let delta = max(0, newHeight - anchor.contentHeight)
        guard delta > 0 else { return }

        collectionView.contentOffset = CGPoint(
            x: collectionView.contentOffset.x,
            y: anchor.offsetY + delta
        )
    }

    func shouldAutoScroll(
        forceScrollToBottom: Bool,
        isLoadingOlder: Bool,
        isNearBottom: Bool,
        lastIDChanged: Bool
    ) -> Bool {
        let bootstrapForce = shouldForceScrollOnNextApply
        let shouldScroll =
            forceScrollToBottom ||
            bootstrapForce ||
            (!isLoadingOlder && isNearBottom && lastIDChanged)

        let reason: String
        if forceScrollToBottom {
            reason = "force-scroll-token"
        } else if bootstrapForce {
            reason = "initial-bootstrap"
        } else if !isLoadingOlder && isNearBottom && lastIDChanged {
            reason = "near-bottom-tail-changed"
        } else if isLoadingOlder {
            reason = "blocked-loading-older"
        } else if !isNearBottom {
            reason = "blocked-not-near-bottom"
        } else {
            reason = "blocked-tail-unchanged"
        }
        OpenIMProbeLogger.log(
            "[DemoAlignedScroll] auto-scroll decision result=\(shouldScroll ? 1 : 0) reason=\(reason) force=\(forceScrollToBottom ? 1 : 0) bootstrap=\(bootstrapForce ? 1 : 0) loadingOlder=\(isLoadingOlder ? 1 : 0) nearBottom=\(isNearBottom ? 1 : 0) tailChanged=\(lastIDChanged ? 1 : 0)"
        )

        shouldForceScrollOnNextApply = false
        return shouldScroll
    }
}
