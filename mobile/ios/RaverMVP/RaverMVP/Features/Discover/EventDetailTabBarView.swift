import UIKit
import SwiftUI

final class EventDetailTabBarView: UIView {
    var onSelect: ((Int) -> Void)?

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.alwaysBounceVertical = false
        view.clipsToBounds = true
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 24
        return stack
    }()

    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(RaverTheme.accent)
        view.layer.cornerRadius = 1.5
        view.isUserInteractionEnabled = false
        return view
    }()

    private var buttons: [UIButton] = []
    private var titles: [String] = []
    private var selectedIndex: Int = 0
    private var progress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(RaverTheme.background)
        clipsToBounds = true
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateIndicatorFrame(animated: false)
    }

    func configure(titles: [String]) {
        guard titles != self.titles else { return }
        self.titles = titles
        rebuildButtons()
    }

    func setSelectedIndex(_ index: Int, animated: Bool) {
        let safeIndex = min(max(index, 0), max(0, buttons.count - 1))
        selectedIndex = safeIndex
        setProgress(CGFloat(safeIndex), animated: animated)
        ensureButtonVisible(at: safeIndex, animated: animated)
    }

    func setProgress(_ progress: CGFloat, animated: Bool = false) {
        let maxProgress = CGFloat(max(0, buttons.count - 1))
        self.progress = min(max(progress, 0), maxProgress)
        updateButtonStyles()
        updateIndicatorFrame(animated: animated)
    }

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.addSubview(indicatorView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -4),
            stackView.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func rebuildButtons() {
        for button in buttons {
            button.removeFromSuperview()
        }
        buttons.removeAll()

        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(title, for: .normal)
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
            button.configuration = configuration
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            buttons.append(button)
        }

        selectedIndex = min(max(selectedIndex, 0), max(0, buttons.count - 1))
        progress = min(max(progress, 0), CGFloat(max(0, buttons.count - 1)))
        updateButtonStyles()
        setNeedsLayout()
        layoutIfNeeded()
        updateIndicatorFrame(animated: false)
    }

    private func updateButtonStyles() {
        let fontSize: CGFloat = 15
        for (index, button) in buttons.enumerated() {
            let distance = abs(progress - CGFloat(index))
            let isNearSelected = distance < 0.5
            let weight: UIFont.Weight = isNearSelected ? .semibold : .medium
            button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
            let color = isNearSelected ? UIColor(RaverTheme.accent) : UIColor.white.withAlphaComponent(0.92)
            button.setTitleColor(color, for: .normal)
        }
    }

    private func updateIndicatorFrame(animated: Bool) {
        guard let frame = indicatorFrame(for: progress) else {
            indicatorView.isHidden = true
            return
        }

        indicatorView.isHidden = false
        let updates = { [weak self] in
            self?.indicatorView.frame = frame
        }

        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.6,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func indicatorFrame(for progress: CGFloat) -> CGRect? {
        guard !buttons.isEmpty else { return nil }

        let maxIndex = buttons.count - 1
        let clamped = min(max(progress, 0), CGFloat(maxIndex))
        let leftIndex = Int(floor(clamped))
        let rightIndex = min(leftIndex + 1, maxIndex)
        let t = clamped - CGFloat(leftIndex)

        let left = buttons[leftIndex].convert(buttons[leftIndex].bounds, to: scrollView)
        let right = buttons[rightIndex].convert(buttons[rightIndex].bounds, to: scrollView)

        let baseX = left.minX + (right.minX - left.minX) * t
        let baseWidth = left.width + (right.width - left.width) * t
        let elastic = (1 - abs(0.5 - t) * 2) * 16
        let indicatorY = bounds.height - 3

        return CGRect(
            x: baseX - elastic * 0.2,
            y: indicatorY,
            width: max(0, baseWidth + elastic),
            height: 3
        )
    }

    private func ensureButtonVisible(at index: Int, animated: Bool) {
        guard buttons.indices.contains(index) else { return }
        let target = buttons[index].convert(buttons[index].bounds.insetBy(dx: -20, dy: 0), to: scrollView)
        scrollView.scrollRectToVisible(target, animated: animated)
    }

    @objc
    private func handleTap(_ sender: UIButton) {
        let index = sender.tag
        setSelectedIndex(index, animated: true)
        onSelect?(index)
    }
}
