import Foundation
import SwiftUI
import UIKit

@MainActor
final class DemoAlignedChatRouteCoordinator {
    private weak var presenter: UIViewController?

    private var conversation: Conversation
    private var repository: ChatSettingsRepository
    private var onNavigate: ((AppRoute) -> Void)?
    private var onLeaveConversation: (() -> Void)?

    init(
        presenter: UIViewController,
        conversation: Conversation,
        repository: ChatSettingsRepository,
        onNavigate: ((AppRoute) -> Void)?,
        onLeaveConversation: (() -> Void)?
    ) {
        self.presenter = presenter
        self.conversation = conversation
        self.repository = repository
        self.onNavigate = onNavigate
        self.onLeaveConversation = onLeaveConversation
    }

    func updateContext(
        conversation: Conversation,
        repository: ChatSettingsRepository,
        onNavigate: ((AppRoute) -> Void)?,
        onLeaveConversation: (() -> Void)?
    ) {
        self.conversation = conversation
        self.repository = repository
        self.onNavigate = onNavigate
        self.onLeaveConversation = onLeaveConversation
    }

    func presentSettingsIfNeeded() {
        guard let presenter else { return }
        guard presenter.presentedViewController == nil else { return }

        let settingsView = ChatSettingsView(
            conversation: conversation,
            repository: repository,
            chatStore: IMChatStore.shared,
            onLeaveConversation: { [weak self] in
                self?.handleLeaveConversation()
            }
        )
        .environment(\.appPush) { [weak self] route in
            self?.handleRoutePush(route)
        }

        let host = UIHostingController(rootView: settingsView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        presenter.present(host, animated: true)
    }

    private func handleLeaveConversation() {
        guard let presenter else { return }

        presenter.dismiss(animated: true) { [weak self, weak presenter] in
            guard let self else { return }
            if let onLeaveConversation = self.onLeaveConversation {
                onLeaveConversation()
                return
            }
            presenter?.navigationController?.popViewController(animated: true)
        }
    }

    private func handleRoutePush(_ route: AppRoute) {
        guard let presenter else { return }

        presenter.dismiss(animated: true) { [weak self] in
            self?.onNavigate?(route)
        }
    }
}
