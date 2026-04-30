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
        playingVoiceMessageID: String?,
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

        collectionDataSource.updateMessages(nextMessages, playingVoiceMessageID: playingVoiceMessageID)
        let hasIncomingTailMessage = previousLastID != nextMessages.last?.id && !(nextMessages.last?.isMine ?? false)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        if hasIncomingTailMessage {
            collectionView.alpha = 0.985
            UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseOut]) {
                collectionView.alpha = 1
            }
        }

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

        return Outcome(
            shouldAutoScroll: shouldAutoScroll,
            pendingMessagesDelta: pendingDelta,
            isNearBottomAfterApply: isNearBottomAfterApply,
            hasNewFailedOutgoingMessage: hasNewFailedOutgoingMessage(previous: currentMessages, current: nextMessages)
        )
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
