import Foundation
import UIKit

struct RaverChatMessagePresentation {
    let message: ChatMessage
    let showSenderMeta: Bool
    let isClusterStart: Bool
    let isClusterEnd: Bool
    let isVoicePlaying: Bool
}

enum RaverChatListItem {
    case timeSeparator(String)
    case message(RaverChatMessagePresentation)
}

final class RaverChatCollectionDataSource: NSObject, UICollectionViewDataSource {
    private var conversationType: ConversationType
    private var items: [RaverChatListItem] = []
    private let cellFactory: RaverChatMessageCellFactory
    private var playingVoiceMessageID: String?
    var onReplyPreviewTapped: ((ChatMessage) -> Void)?

    init(
        conversationType: ConversationType,
        maxBubbleWidthRatio: CGFloat = 0.64
    ) {
        self.conversationType = conversationType
        self.cellFactory = RaverChatMessageCellFactory(maxBubbleWidthRatio: maxBubbleWidthRatio)
        super.init()
    }

    func registerCells(in collectionView: UICollectionView) {
        cellFactory.registerCells(in: collectionView)
    }

    func updateConversationType(_ type: ConversationType) {
        conversationType = type
    }

    func updateMessages(_ messages: [ChatMessage], playingVoiceMessageID: String?) {
        self.playingVoiceMessageID = playingVoiceMessageID
        let renderMessages = messages.filter { $0.kind != .typing }
        var builtItems: [RaverChatListItem] = []
        for index in renderMessages.indices {
            let message = renderMessages[index]
            let previous = index > 0 ? renderMessages[index - 1] : nil
            let next = index + 1 < renderMessages.count ? renderMessages[index + 1] : nil

            if shouldInsertTimeSeparator(current: message, previous: previous) {
                builtItems.append(.timeSeparator(timeSeparatorText(for: message.createdAt)))
            }

            let clusterStart = !isSameCluster(previous: previous, current: message)
            let clusterEnd = !isSameCluster(previous: message, current: next)

            builtItems.append(
                .message(
                    RaverChatMessagePresentation(
                        message: message,
                        showSenderMeta: shouldShowSenderMeta(
                            for: message,
                            isClusterStart: clusterStart
                        ),
                        isClusterStart: clusterStart,
                        isClusterEnd: clusterEnd,
                        isVoicePlaying: message.kind == .voice && message.id == playingVoiceMessageID
                    )
                )
            )
        }

        items = builtItems
    }


    func message(at indexPath: IndexPath) -> ChatMessage? {
        guard indexPath.section == 0 else { return nil }
        guard indexPath.item >= 0, indexPath.item < items.count else { return nil }
        guard case let .message(presentation) = items[indexPath.item] else { return nil }
        return presentation.message
    }

    func indexPath(forMessageID messageID: String) -> IndexPath? {
        guard !messageID.isEmpty else { return nil }
        for (offset, item) in items.enumerated() {
            guard case let .message(presentation) = item else { continue }
            if presentation.message.id == messageID {
                return IndexPath(item: offset, section: 0)
            }
        }
        return nil
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        cellFactory.dequeueConfiguredCell(
            in: collectionView,
            at: indexPath,
            item: items[indexPath.item],
            onReplyPreviewTapped: onReplyPreviewTapped
        )
    }

    private func shouldInsertTimeSeparator(current: ChatMessage, previous: ChatMessage?) -> Bool {
        guard let previous else { return true }
        let calendar = Calendar.current
        if !calendar.isDate(previous.createdAt, inSameDayAs: current.createdAt) {
            return true
        }
        return current.createdAt.timeIntervalSince(previous.createdAt) >= 5 * 60
    }

    private func shouldShowSenderMeta(for message: ChatMessage, isClusterStart: Bool) -> Bool {
        _ = isClusterStart
        guard supportsClustering(message) else { return false }
        return true
    }

    private func timeSeparatorText(for date: Date) -> String {
        let calendar = Calendar.current
        let timeText = Self.timeFormatter.string(from: date)
        if calendar.isDateInToday(date) {
            return L("今天 \(timeText)", "Today \(timeText)")
        }
        if calendar.isDateInYesterday(date) {
            return L("昨天 \(timeText)", "Yesterday \(timeText)")
        }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return Self.sameYearFormatter.string(from: date)
        }
        return Self.fullFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let sameYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMdHHmm")
        return formatter
    }()

    private static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMdHHmm")
        return formatter
    }()

    private func isSameCluster(previous: ChatMessage?, current: ChatMessage?) -> Bool {
        guard let previous, let current else { return false }
        guard supportsClustering(previous), supportsClustering(current) else { return false }

        if previous.isMine != current.isMine {
            return false
        }

        if previous.sender.id != current.sender.id {
            return false
        }

        let calendar = Calendar.current
        guard calendar.isDate(previous.createdAt, inSameDayAs: current.createdAt) else {
            return false
        }

        return current.createdAt.timeIntervalSince(previous.createdAt) < 3 * 60
    }

    private func supportsClustering(_ message: ChatMessage) -> Bool {
        message.kind != .system && message.kind != .typing
    }
}
