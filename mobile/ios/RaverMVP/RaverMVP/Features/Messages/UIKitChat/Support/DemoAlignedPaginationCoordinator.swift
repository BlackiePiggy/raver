import Foundation
import UIKit

@MainActor
final class DemoAlignedPaginationCoordinator {
    private weak var loadingIndicator: UIActivityIndicatorView?
    private let topTriggerOffset: CGFloat
    private let onLoadOlder: () async -> Void

    private var topTriggerArmed = true

    init(
        loadingIndicator: UIActivityIndicatorView,
        topTriggerOffset: CGFloat,
        onLoadOlder: @escaping () async -> Void
    ) {
        self.loadingIndicator = loadingIndicator
        self.topTriggerOffset = topTriggerOffset
        self.onLoadOlder = onLoadOlder
    }

    func reset() {
        topTriggerArmed = true
        loadingIndicator?.stopAnimating()
        IMProbeLogger.log("[DemoAlignedPagination] reset armed=1 loading=0")
    }

    func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            loadingIndicator?.startAnimating()
            IMProbeLogger.log("[DemoAlignedPagination] loading state=1")
            return
        }
        loadingIndicator?.stopAnimating()
        IMProbeLogger.log("[DemoAlignedPagination] loading state=0")
    }

    func handleScrollDidScroll(_ scrollView: UIScrollView) {
        let topThreshold = -scrollView.adjustedContentInset.top + topTriggerOffset
        let isAtTopTrigger = scrollView.contentOffset.y <= topThreshold

        guard isAtTopTrigger else {
            if !topTriggerArmed {
                IMProbeLogger.log(
                    "[DemoAlignedPagination] rearm offsetY=\(String(format: "%.1f", scrollView.contentOffset.y)) threshold=\(String(format: "%.1f", topThreshold))"
                )
            }
            topTriggerArmed = true
            return
        }

        guard topTriggerArmed else { return }
        topTriggerArmed = false
        IMProbeLogger.log(
            "[DemoAlignedPagination] trigger load-older offsetY=\(String(format: "%.1f", scrollView.contentOffset.y)) threshold=\(String(format: "%.1f", topThreshold))"
        )

        Task { @MainActor [weak self] in
            await self?.onLoadOlder()
        }
    }
}
