import Combine
import Foundation

@MainActor
final class DemoAlignedControllerBindingCoordinator {
    private let chatController: RaverChatController
    private let onMessagesChanged: () -> Void
    private let onLoadingOlderChanged: (Bool) -> Void
    private let onReplyDraftChanged: (ChatMessage?) -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        chatController: RaverChatController,
        onMessagesChanged: @escaping () -> Void,
        onLoadingOlderChanged: @escaping (Bool) -> Void,
        onReplyDraftChanged: @escaping (ChatMessage?) -> Void
    ) {
        self.chatController = chatController
        self.onMessagesChanged = onMessagesChanged
        self.onLoadingOlderChanged = onLoadingOlderChanged
        self.onReplyDraftChanged = onReplyDraftChanged
    }

    func start() {
        guard cancellables.isEmpty else { return }

        chatController.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.onMessagesChanged()
            }
            .store(in: &cancellables)

        chatController.$isLoadingOlder
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.onLoadingOlderChanged(isLoading)
            }
            .store(in: &cancellables)

        chatController.$replyDraftMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] draft in
                self?.onReplyDraftChanged(draft)
            }
            .store(in: &cancellables)

        chatController.$playingVoiceMessageID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.onMessagesChanged()
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }
}
