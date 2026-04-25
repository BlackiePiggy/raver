import Foundation
import UIKit

final class RaverChatMessageCellFactory {
    private let maxBubbleWidthRatio: CGFloat

    init(maxBubbleWidthRatio: CGFloat) {
        self.maxBubbleWidthRatio = maxBubbleWidthRatio
    }

    func registerCells(in collectionView: UICollectionView) {
        collectionView.register(
            DemoAlignedMessageCell.self,
            forCellWithReuseIdentifier: DemoAlignedMessageCell.reuseIdentifier
        )
        collectionView.register(
            DemoAlignedMediaMessageCell.self,
            forCellWithReuseIdentifier: DemoAlignedMediaMessageCell.reuseIdentifier
        )
        collectionView.register(
            DemoAlignedTimeSeparatorCell.self,
            forCellWithReuseIdentifier: DemoAlignedTimeSeparatorCell.reuseIdentifier
        )
        collectionView.register(
            DemoAlignedSystemMessageCell.self,
            forCellWithReuseIdentifier: DemoAlignedSystemMessageCell.reuseIdentifier
        )
    }

    func dequeueConfiguredCell(
        in collectionView: UICollectionView,
        at indexPath: IndexPath,
        item: RaverChatListItem
    ) -> UICollectionViewCell {
        switch item {
        case let .timeSeparator(text):
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: DemoAlignedTimeSeparatorCell.reuseIdentifier,
                for: indexPath
            ) as? DemoAlignedTimeSeparatorCell else {
                return UICollectionViewCell()
            }
            cell.configure(text: text)
            return cell
        case let .message(presentation):
            let message = presentation.message
            switch message.kind {
            case .system:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: DemoAlignedSystemMessageCell.reuseIdentifier,
                    for: indexPath
                ) as? DemoAlignedSystemMessageCell else {
                    return UICollectionViewCell()
                }
                cell.configure(text: message.content)
                return cell
            case .image, .video, .voice, .file:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: DemoAlignedMediaMessageCell.reuseIdentifier,
                    for: indexPath
                ) as? DemoAlignedMediaMessageCell else {
                    return UICollectionViewCell()
                }
                cell.configure(
                    message: message,
                    maxBubbleWidthRatio: maxBubbleWidthRatio,
                    showSenderMeta: presentation.showSenderMeta,
                    isClusterStart: presentation.isClusterStart,
                    isClusterEnd: presentation.isClusterEnd
                )
                return cell

            default:
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: DemoAlignedMessageCell.reuseIdentifier,
                    for: indexPath
                ) as? DemoAlignedMessageCell else {
                    return UICollectionViewCell()
                }
                cell.configure(
                    message: message,
                    maxBubbleWidthRatio: maxBubbleWidthRatio,
                    showSenderMeta: presentation.showSenderMeta,
                    isClusterStart: presentation.isClusterStart,
                    isClusterEnd: presentation.isClusterEnd
                )
                return cell
            }
        }
    }
}
