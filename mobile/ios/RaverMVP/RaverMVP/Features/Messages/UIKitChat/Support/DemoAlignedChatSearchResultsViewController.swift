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
        title = LT("搜索结果", "Search Results", "検索結果")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseID)
        tableView.rowHeight = 64
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.backgroundColor = UIColor(RaverTheme.background)
        navigationItem.prompt = "\(LT("关键词", "Keyword", "キーワード")): \(query)"
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
        IMProbeLogger.log(
            "[DemoAlignedSearch] result-selected query=\(query) message=\(result.message.id) source=\(result.source.rawValue)"
        )
        onSelectResult(result)
        navigationController?.popViewController(animated: true)
    }

    private func secondaryLine(for result: ChatMessageSearchResult) -> String {
        let timeText = result.message.createdAt.appLocalizedYMDHMText()
        let sender = result.message.isMine ? LT("我", "Me", "自分") : result.message.sender.displayName
        let source = LT("本地索引", "Local", "ローカル")
        return "\(sender) · \(timeText) · \(source)"
    }

    private func messagePreview(for message: ChatMessage) -> String {
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }

        switch message.kind {
        case .image:
            return LT("[图片]", "[Image]", "[画像]")
        case .video:
            return LT("[视频]", "[Video]", "[動画]")
        case .voice:
            return LT("[语音]", "[Voice]", "[音声]")
        case .file:
            return message.media?.fileName ?? LT("[文件]", "[File]", "[ファイル]")
        case .emoji:
            return LT("[表情]", "[Emoji]", "[絵文字]")
        case .location:
            return LT("[位置]", "[Location]", "[位置情報]")
        case .card:
            return LT("[名片]", "[Card]", "[カード]")
        case .custom:
            return LT("[自定义消息]", "[Custom Message]", "[カスタムメッセージ]")
        case .system:
            return LT("[系统消息]", "[System Message]", "[システムメッセージ]")
        case .typing:
            return LT("[输入中]", "[Typing]", "[入力中]")
        case .unknown:
            return LT("[消息]", "[Message]", "[メッセージ]")
        case .text:
            return LT("[文本消息]", "[Text Message]", "[テキストメッセージ]")
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
}
