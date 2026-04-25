import Foundation
import UIKit

@MainActor
final class DemoAlignedMessageApplyCoordinator {
    struct Outcome {
        let shouldAutoScroll: Bool
        let pendingMessagesDelta: Int
        let isNearBottomAfterApply: Bool
        let hasNewFailedOutgoingMessage: Bool
    }

    private let viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator
    private weak var collectionView: UICollectionView?
    private let collectionDataSource: RaverChatCollectionDataSource
    private let nearBottomThreshold: CGFloat

    init(
        viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator,
        collectionView: UICollectionView,
        collectionDataSource: RaverChatCollectionDataSource,
        nearBottomThreshold: CGFloat
    ) {
        self.viewportScrollCoordinator = viewportScrollCoordinator
        self.collectionView = collectionView
        self.collectionDataSource = collectionDataSource
        self.nearBottomThreshold = nearBottomThreshold
    }

    func apply(
        currentMessages: [ChatMessage],
        nextMessages: [ChatMessage],
        forceScrollToBottom: Bool,
        isLoadingOlder: Bool,
        hasCompletedInitialLoad: Bool
    ) -> Outcome {
        guard let collectionView else {
            return Outcome(
                shouldAutoScroll: false,
                pendingMessagesDelta: 0,
                isNearBottomAfterApply: true,
                hasNewFailedOutgoingMessage: hasNewFailedOutgoingMessage(previous: currentMessages, current: nextMessages)
            )
        }

        let previousLastID = currentMessages.last?.id
        let previousCount = currentMessages.count
        let isNearBottomBeforeApply = viewportScrollCoordinator.isNearBottom(
            threshold: nearBottomThreshold
        )
        OpenIMProbeLogger.log(
            "[DemoAlignedMessageApply] before reload previousTail={\(debugMessageSummary(currentMessages.last))} nextTail={\(debugMessageSummary(nextMessages.last))}"
        )

        collectionDataSource.updateMessages(nextMessages)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        let lastIDChanged = previousLastID != nextMessages.last?.id
        let shouldAutoScroll = viewportScrollCoordinator.shouldAutoScroll(
            forceScrollToBottom: forceScrollToBottom,
            isLoadingOlder: isLoadingOlder,
            isNearBottom: isNearBottomBeforeApply,
            lastIDChanged: lastIDChanged
        )

        var pendingDelta = 0
        if !shouldAutoScroll,
           !isLoadingOlder,
           hasCompletedInitialLoad,
           previousLastID != nil,
           lastIDChanged {
            pendingDelta = max(1, nextMessages.count - previousCount)
        }

        let isNearBottomAfterApply = viewportScrollCoordinator.isNearBottom(
            threshold: nearBottomThreshold
        )
        OpenIMProbeLogger.log(
            "[DemoAlignedMessageApply] after reload shouldAutoScroll=\(shouldAutoScroll ? 1 : 0) pendingDelta=\(pendingDelta) nearBottomAfter=\(isNearBottomAfterApply ? 1 : 0) renderedTail={\(debugMessageSummary(nextMessages.last))}"
        )

        return Outcome(
            shouldAutoScroll: shouldAutoScroll,
            pendingMessagesDelta: pendingDelta,
            isNearBottomAfterApply: isNearBottomAfterApply,
            hasNewFailedOutgoingMessage: hasNewFailedOutgoingMessage(previous: currentMessages, current: nextMessages)
        )
    }

    private func debugMessageSummary(_ message: ChatMessage?) -> String {
        guard let message else { return "-" }
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = text.isEmpty ? "-" : (text.count > 24 ? "\(text.prefix(24))..." : text)
        return "id=\(message.id) mine=\(message.isMine ? 1 : 0) status=\(message.deliveryStatus.rawValue) content=\(snippet)"
    }

    private func hasNewFailedOutgoingMessage(
        previous: [ChatMessage],
        current: [ChatMessage]
    ) -> Bool {
        let previousStatusByID = Dictionary(
            uniqueKeysWithValues: previous.map { ($0.id, $0.deliveryStatus) }
        )
        for message in current where message.isMine && message.deliveryStatus == .failed {
            if previousStatusByID[message.id] != .failed {
                return true
            }
        }
        return false
    }
}
