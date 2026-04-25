import Foundation
import UIKit

@MainActor
final class DemoAlignedViewportCoordinator {
    private weak var hostView: UIView?
    private weak var jumpToBottomButton: UIButton?
    private let keyboardSettleDelayNs: UInt64

    private var pendingNewMessageCount = 0
    private var isJumpToBottomVisible = false
    private var lastJumpToBottomTitle = ""

    init(
        hostView: UIView,
        jumpToBottomButton: UIButton,
        keyboardSettleDelayNs: UInt64
    ) {
        self.hostView = hostView
        self.jumpToBottomButton = jumpToBottomButton
        self.keyboardSettleDelayNs = keyboardSettleDelayNs
    }

    func reset() {
        pendingNewMessageCount = 0
        lastJumpToBottomTitle = ""
        setJumpToBottomVisible(false, animated: false)
    }

    func clearPendingMessages() {
        if pendingNewMessageCount > 0 {
            OpenIMProbeLogger.log("[DemoAlignedViewport] clear pending count=\(pendingNewMessageCount)")
        }
        pendingNewMessageCount = 0
    }

    func accumulatePendingMessages(by delta: Int) {
        guard delta > 0 else { return }
        let previous = pendingNewMessageCount
        pendingNewMessageCount = min(999, pendingNewMessageCount + delta)
        OpenIMProbeLogger.log(
            "[DemoAlignedViewport] pending +\(delta) total=\(pendingNewMessageCount) previous=\(previous)"
        )
    }

    func updateJumpToBottomUI(isNearBottom: Bool, animated: Bool) {
        guard let jumpToBottomButton else { return }

        if isNearBottom {
            if pendingNewMessageCount > 0 || isJumpToBottomVisible {
                OpenIMProbeLogger.log(
                    "[DemoAlignedViewport] near-bottom hide pending=\(pendingNewMessageCount)"
                )
            }
            pendingNewMessageCount = 0
            lastJumpToBottomTitle = ""
            setJumpToBottomVisible(false, animated: animated)
            return
        }

        let title: String
        if pendingNewMessageCount > 0 {
            let badgeText = pendingNewMessageCount > 99 ? "99+" : "\(pendingNewMessageCount)"
            title = L("\(badgeText) 条新消息", "\(badgeText) new messages")
        } else {
            title = L("回到底部", "Back to bottom")
        }

        var config = jumpToBottomButton.configuration ?? UIButton.Configuration.filled()
        config.title = title
        jumpToBottomButton.configuration = config
        if title != lastJumpToBottomTitle {
            OpenIMProbeLogger.log(
                "[DemoAlignedViewport] jump-title title=\(title) pending=\(pendingNewMessageCount)"
            )
            lastJumpToBottomTitle = title
        }
        setJumpToBottomVisible(true, animated: animated)
    }

    func handleJumpToBottomTapped(scrollToBottom: (Bool) -> Void) {
        OpenIMProbeLogger.log(
            "[DemoAlignedViewport] jump-tap pending=\(pendingNewMessageCount)"
        )
        pendingNewMessageCount = 0
        lastJumpToBottomTitle = ""
        scrollToBottom(true)
        updateJumpToBottomUI(isNearBottom: true, animated: true)
    }

    func handleKeyboardWillChangeFrame(
        notification: Notification,
        shouldStickToBottom: Bool,
        onLayoutIfNeeded: @escaping () -> Void,
        onScrollToBottom: @escaping () -> Void
    ) {
        animateAlongKeyboard(notification, animations: {
            onLayoutIfNeeded()
            guard shouldStickToBottom else { return }
            onScrollToBottom()
        })
    }

    func handleKeyboardWillHide(
        notification: Notification,
        shouldStickToBottom: Bool,
        onLayoutIfNeeded: @escaping () -> Void,
        onScrollToBottom: @escaping () -> Void,
        onPostSettle: @escaping () -> Void
    ) {
        animateAlongKeyboard(notification, animations: {
            onLayoutIfNeeded()
            guard shouldStickToBottom else { return }
            onScrollToBottom()
        }, completion: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: self.keyboardSettleDelayNs)
                onScrollToBottom()
                onPostSettle()
            }
        })
    }

    private func setJumpToBottomVisible(_ visible: Bool, animated: Bool) {
        guard let jumpToBottomButton else { return }
        guard visible != isJumpToBottomVisible else { return }
        isJumpToBottomVisible = visible
        OpenIMProbeLogger.log(
            "[DemoAlignedViewport] jump-visible state=\(visible ? 1 : 0) animated=\(animated ? 1 : 0)"
        )

        let applyVisibility = {
            jumpToBottomButton.alpha = visible ? 1 : 0
        }

        if visible {
            jumpToBottomButton.isHidden = false
        }

        guard animated else {
            applyVisibility()
            if !visible {
                jumpToBottomButton.isHidden = true
            }
            return
        }

        UIView.animate(withDuration: 0.2, animations: applyVisibility) { _ in
            if !visible {
                jumpToBottomButton.isHidden = true
            }
        }
    }

    private func animateAlongKeyboard(
        _ notification: Notification,
        animations: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
        let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)
        let options: UIView.AnimationOptions = [curve, .beginFromCurrentState, .allowUserInteraction]

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            animations()
        } completion: { _ in
            completion?()
        }
    }
}
