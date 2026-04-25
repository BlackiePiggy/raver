import UIKit

final class DemoAlignedSendFailureHintPresenter {
    private weak var hostView: UIView?
    private let hintView = UIView()
    private let hintLabel = UILabel()
    private var hideWorkItem: DispatchWorkItem?

    init(hostView: UIView, anchorView: UIView) {
        self.hostView = hostView
        configure(in: hostView, anchorView: anchorView)
    }

    func show(message: String, duration: TimeInterval = 2.0) {
        hideWorkItem?.cancel()
        hintLabel.text = message
        hintView.isHidden = false

        UIView.animate(withDuration: 0.18) {
            self.hintView.alpha = 1
        }

        let work = DispatchWorkItem { [weak self] in
            self?.hideAnimated()
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func reset() {
        hideWorkItem?.cancel()
        hintView.alpha = 0
        hintView.isHidden = true
    }

    private func configure(in hostView: UIView, anchorView: UIView) {
        hintView.translatesAutoresizingMaskIntoConstraints = false
        hintView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
        hintView.layer.cornerRadius = 10
        hintView.layer.borderWidth = 0.5
        hintView.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.28).cgColor
        hintView.alpha = 0
        hintView.isHidden = true
        hostView.addSubview(hintView)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        hintLabel.textColor = UIColor.systemRed
        hintView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            hintView.leadingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            hintView.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            hintView.bottomAnchor.constraint(equalTo: anchorView.topAnchor, constant: -8),

            hintLabel.leadingAnchor.constraint(equalTo: hintView.leadingAnchor, constant: 10),
            hintLabel.trailingAnchor.constraint(equalTo: hintView.trailingAnchor, constant: -10),
            hintLabel.topAnchor.constraint(equalTo: hintView.topAnchor, constant: 7),
            hintLabel.bottomAnchor.constraint(equalTo: hintView.bottomAnchor, constant: -7)
        ])
    }

    private func hideAnimated() {
        UIView.animate(withDuration: 0.22, animations: {
            self.hintView.alpha = 0
        }, completion: { _ in
            self.hintView.isHidden = true
        })
    }
}
