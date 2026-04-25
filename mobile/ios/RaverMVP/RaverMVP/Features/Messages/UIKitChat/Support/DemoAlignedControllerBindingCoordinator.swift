import Combine
import Foundation

@MainActor
final class DemoAlignedControllerBindingCoordinator {
    private let chatController: RaverChatController
    private let onMessagesChanged: () -> Void
    private let onLoadingOlderChanged: (Bool) -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        chatController: RaverChatController,
        onMessagesChanged: @escaping () -> Void,
        onLoadingOlderChanged: @escaping (Bool) -> Void
    ) {
        self.chatController = chatController
        self.onMessagesChanged = onMessagesChanged
        self.onLoadingOlderChanged = onLoadingOlderChanged
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
    }

    func stop() {
        cancellables.removeAll()
    }
}
