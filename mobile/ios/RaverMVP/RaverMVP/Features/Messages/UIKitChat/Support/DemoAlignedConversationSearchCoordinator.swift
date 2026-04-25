import Foundation
import UIKit

@MainActor
final class DemoAlignedConversationSearchCoordinator {
    private weak var presenter: UIViewController?
    private let searchExecutor: (String) async throws -> [ChatMessageSearchResult]
    private let onSearchCompleted: (String, [ChatMessageSearchResult]) -> Void

    init(
        presenter: UIViewController,
        searchExecutor: @escaping (String) async throws -> [ChatMessageSearchResult],
        onSearchCompleted: @escaping (String, [ChatMessageSearchResult]) -> Void
    ) {
        self.presenter = presenter
        self.searchExecutor = searchExecutor
        self.onSearchCompleted = onSearchCompleted
    }

    func presentSearchPrompt() {
        guard let presenter else { return }

        let alert = UIAlertController(
            title: L("会话内搜索", "Search in Conversation"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = L("输入关键词", "Enter keyword")
            textField.returnKeyType = .search
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        alert.addAction(
            UIAlertAction(
                title: L("搜索", "Search"),
                style: .default,
                handler: { [weak self, weak alert] _ in
                    guard let self else { return }
                    let query = alert?.textFields?.first?.text ?? ""
                    Task { [weak self] in
                        await self?.performSearch(query: query)
                    }
                }
            )
        )

        presenter.present(alert, animated: true)
    }

    private func performSearch(query: String) async {
        guard let presenter else { return }
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return }
        OpenIMProbeLogger.log("[DemoAlignedSearch] submit query=\(normalizedQuery)")

        do {
            let results = try await searchExecutor(normalizedQuery)
            guard !results.isEmpty else {
                OpenIMProbeLogger.log("[DemoAlignedSearch] result-empty query=\(normalizedQuery)")
                let emptyAlert = UIAlertController(
                    title: L("无搜索结果", "No Results"),
                    message: L("请尝试更换关键词。", "Try a different keyword."),
                    preferredStyle: .alert
                )
                emptyAlert.addAction(UIAlertAction(title: L("好的", "OK"), style: .default))
                presenter.present(emptyAlert, animated: true)
                return
            }

            OpenIMProbeLogger.log(
                "[DemoAlignedSearch] result query=\(normalizedQuery) count=\(results.count)"
            )
            onSearchCompleted(normalizedQuery, results)
        } catch {
            OpenIMProbeLogger.log(
                "[DemoAlignedSearch] failed query=\(normalizedQuery) error=\(error.localizedDescription)"
            )
            let message = error.userFacingMessage
            let failureAlert = UIAlertController(
                title: L("搜索失败", "Search Failed"),
                message: message,
                preferredStyle: .alert
            )
            failureAlert.addAction(UIAlertAction(title: L("好的", "OK"), style: .default))
            presenter.present(failureAlert, animated: true)
        }
    }
}
