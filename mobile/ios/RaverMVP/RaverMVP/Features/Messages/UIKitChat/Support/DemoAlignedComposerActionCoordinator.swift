import Foundation
import UIKit

@MainActor
final class DemoAlignedComposerActionCoordinator {
    private let nearBottomThreshold: CGFloat
    private let sendText: () async -> Void
    private let refreshSendButtonState: () -> Void
    private let isSendingMedia: () -> Bool
    private let presentImagePicker: () -> Void
    private let presentVideoPicker: () -> Void
    private let scrollToBottom: (Bool) -> Void
    private let isNearBottom: (CGFloat) -> Bool
    private let updateJumpToBottomUI: (Bool, Bool) -> Void

    init(
        nearBottomThreshold: CGFloat,
        sendText: @escaping () async -> Void,
        refreshSendButtonState: @escaping () -> Void,
        isSendingMedia: @escaping () -> Bool,
        presentImagePicker: @escaping () -> Void,
        presentVideoPicker: @escaping () -> Void,
        scrollToBottom: @escaping (Bool) -> Void,
        isNearBottom: @escaping (CGFloat) -> Bool,
        updateJumpToBottomUI: @escaping (Bool, Bool) -> Void
    ) {
        self.nearBottomThreshold = nearBottomThreshold
        self.sendText = sendText
        self.refreshSendButtonState = refreshSendButtonState
        self.isSendingMedia = isSendingMedia
        self.presentImagePicker = presentImagePicker
        self.presentVideoPicker = presentVideoPicker
        self.scrollToBottom = scrollToBottom
        self.isNearBottom = isNearBottom
        self.updateJumpToBottomUI = updateJumpToBottomUI
    }

    func handleSendTapped() {
        Task { @MainActor in
            await sendText()
        }
    }

    func handleInputEditingChanged() {
        refreshSendButtonState()
    }

    func handleImageTapped() {
        guard !isSendingMedia() else { return }
        presentImagePicker()
    }

    func handleVideoTapped() {
        guard !isSendingMedia() else { return }
        presentVideoPicker()
    }

    func handleTextFieldDidBeginEditing() {
        refreshSendButtonState()
        scrollToBottom(true)
    }

    func handleTextFieldDidEndEditing() {
        refreshSendButtonState()
        let nearBottom = isNearBottom(nearBottomThreshold)
        updateJumpToBottomUI(nearBottom, true)
    }

    func handleTextFieldShouldReturn() -> Bool {
        handleSendTapped()
        return true
    }
}
