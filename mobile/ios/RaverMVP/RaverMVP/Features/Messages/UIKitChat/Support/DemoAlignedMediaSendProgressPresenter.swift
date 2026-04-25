import UIKit

@MainActor
final class DemoAlignedMediaSendProgressPresenter {
    private let imageButton: UIButton
    private let videoButton: UIButton
    private let containerView: UIView
    private let progressView: UIProgressView
    private let progressLabel: UILabel
    private let heightConstraint: NSLayoutConstraint
    private let hostView: UIView
    private var sendingSessionID = UUID()

    private(set) var isSendingMedia = false
    var onSendingStateChanged: ((Bool) -> Void)?

    init(
        imageButton: UIButton,
        videoButton: UIButton,
        containerView: UIView,
        progressView: UIProgressView,
        progressLabel: UILabel,
        heightConstraint: NSLayoutConstraint,
        hostView: UIView
    ) {
        self.imageButton = imageButton
        self.videoButton = videoButton
        self.containerView = containerView
        self.progressView = progressView
        self.progressLabel = progressLabel
        self.heightConstraint = heightConstraint
        self.hostView = hostView
    }

    func setSendingState(_ sending: Bool) {
        isSendingMedia = sending
        sendingSessionID = UUID()
        onSendingStateChanged?(sending)
        imageButton.isEnabled = !sending
        videoButton.isEnabled = !sending

        let alpha: CGFloat = sending ? 0.45 : 1
        imageButton.alpha = alpha
        videoButton.alpha = alpha

        if sending {
            updateProgress(0)
            return
        }

        progressView.setProgress(0, animated: false)
        progressLabel.text = L("发送媒体 0%", "Sending media 0%")
        progressView.isHidden = true
        progressLabel.isHidden = true
        heightConstraint.constant = 0
        containerView.isHidden = true
    }

    func currentSendingSessionID() -> UUID {
        sendingSessionID
    }

    func updateProgress(_ progress: Double, sessionID: UUID? = nil) {
        if let sessionID, sessionID != sendingSessionID {
            return
        }
        guard isSendingMedia else { return }

        let clamped = min(1, max(0, progress))
        if containerView.isHidden {
            containerView.isHidden = false
            progressView.isHidden = false
            progressLabel.isHidden = false
            heightConstraint.constant = 24
            UIView.animate(withDuration: 0.18) {
                self.hostView.layoutIfNeeded()
            }
        }

        progressView.setProgress(Float(clamped), animated: true)
        let percent = Int(round(clamped * 100))
        progressLabel.text = L("发送媒体 \(percent)%", "Sending media \(percent)%")
    }

    func updateProgress(_ progress: Double) {
        updateProgress(progress, sessionID: nil)
    }
}
