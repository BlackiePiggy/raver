import Foundation
import UIKit

@MainActor
final class DemoAlignedChatSearchResultsViewController: UITableViewController {
    private let query: String
    private let results: [ChatMessageSearchResult]
    private let onSelectResult: (ChatMessageSearchResult) -> Void

    init(
        query: String,
        results: [ChatMessageSearchResult],
        onSelectResult: @escaping (ChatMessageSearchResult) -> Void
    ) {
        self.query = query
        self.results = results
        self.onSelectResult = onSelectResult
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("搜索结果", "Search Results")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseID)
        tableView.rowHeight = 64
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.backgroundColor = UIColor(RaverTheme.background)
        navigationItem.prompt = "\(L("关键词", "Keyword")): \(query)"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseID, for: indexPath)
        let result = results[indexPath.row]
        let previewText = messagePreview(for: result.message)
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.attributedText = highlightedPreviewText(previewText, query: query)
        configuration.secondaryText = secondaryLine(for: result)
        configuration.textProperties.numberOfLines = 1
        configuration.secondaryTextProperties.numberOfLines = 1
        configuration.secondaryTextProperties.color = UIColor(RaverTheme.secondaryText)
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = UIColor(RaverTheme.background)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let result = results[indexPath.row]
        OpenIMProbeLogger.log(
            "[DemoAlignedSearch] result-selected query=\(query) message=\(result.message.id) source=\(result.source.rawValue)"
        )
        onSelectResult(result)
        navigationController?.popViewController(animated: true)
    }

    private func secondaryLine(for result: ChatMessageSearchResult) -> String {
        let timeText = Self.timeFormatter.string(from: result.message.createdAt)
        let sender = result.message.isMine ? L("我", "Me") : result.message.sender.displayName
        let source = result.source == .remoteFallback
            ? L("远端补偿", "Remote")
            : L("本地索引", "Local")
        return "\(sender) · \(timeText) · \(source)"
    }

    private func messagePreview(for message: ChatMessage) -> String {
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }

        switch message.kind {
        case .image:
            return L("[图片]", "[Image]")
        case .video:
            return L("[视频]", "[Video]")
        case .voice:
            return L("[语音]", "[Voice]")
        case .file:
            return message.media?.fileName ?? L("[文件]", "[File]")
        case .emoji:
            return L("[表情]", "[Emoji]")
        case .location:
            return L("[位置]", "[Location]")
        case .card:
            return L("[名片]", "[Card]")
        case .custom:
            return L("[自定义消息]", "[Custom Message]")
        case .system:
            return L("[系统消息]", "[System Message]")
        case .typing:
            return L("[输入中]", "[Typing]")
        case .unknown:
            return L("[消息]", "[Message]")
        case .text:
            return L("[文本消息]", "[Text Message]")
        }
    }

    private func highlightedPreviewText(_ text: String, query: String) -> NSAttributedString {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.label
            ]
        )

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return attributedText
        }

        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.length > 0 {
            let foundRange = nsText.range(
                of: normalizedQuery,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchRange
            )
            guard foundRange.location != NSNotFound else { break }

            attributedText.addAttributes(
                [
                    .foregroundColor: UIColor(RaverTheme.accent),
                    .font: UIFont.systemFont(ofSize: bodyFont.pointSize, weight: .semibold)
                ],
                range: foundRange
            )

            let nextLocation = foundRange.location + foundRange.length
            if nextLocation >= nsText.length {
                break
            }
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return attributedText
    }

    private static let cellReuseID = "search-result-cell"
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMdHHmm")
        return formatter
    }()
}
