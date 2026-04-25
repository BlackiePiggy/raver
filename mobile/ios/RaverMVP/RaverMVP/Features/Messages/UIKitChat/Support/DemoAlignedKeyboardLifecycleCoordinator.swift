import Combine
import Foundation
import UIKit

@MainActor
final class DemoAlignedKeyboardLifecycleCoordinator {
    private let notificationCenter: NotificationCenter
    private weak var hostView: UIView?
    private weak var inputField: UITextField?
    private let nearBottomThreshold: CGFloat
    private let isNearBottom: (CGFloat) -> Bool
    private let onKeyboardWillChangeFrame: (Notification, Bool) -> Void
    private let onKeyboardWillHide: (Notification, Bool) -> Void

    private var cancellables = Set<AnyCancellable>()

    init(
        notificationCenter: NotificationCenter = .default,
        hostView: UIView,
        inputField: UITextField,
        nearBottomThreshold: CGFloat,
        isNearBottom: @escaping (CGFloat) -> Bool,
        onKeyboardWillChangeFrame: @escaping (Notification, Bool) -> Void,
        onKeyboardWillHide: @escaping (Notification, Bool) -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.hostView = hostView
        self.inputField = inputField
        self.nearBottomThreshold = nearBottomThreshold
        self.isNearBottom = isNearBottom
        self.onKeyboardWillChangeFrame = onKeyboardWillChangeFrame
        self.onKeyboardWillHide = onKeyboardWillHide
    }

    func start() {
        guard cancellables.isEmpty else { return }

        notificationCenter.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleKeyboardWillChangeFrame(notification)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleKeyboardWillHide(notification)
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }

    private func handleKeyboardWillChangeFrame(_ notification: Notification) {
        guard hostView?.window != nil else { return }
        onKeyboardWillChangeFrame(notification, shouldStickToBottom())
    }

    private func handleKeyboardWillHide(_ notification: Notification) {
        guard hostView?.window != nil else { return }
        onKeyboardWillHide(notification, shouldStickToBottom())
    }

    private func shouldStickToBottom() -> Bool {
        isNearBottom(nearBottomThreshold) || (inputField?.isFirstResponder ?? false)
    }
}
