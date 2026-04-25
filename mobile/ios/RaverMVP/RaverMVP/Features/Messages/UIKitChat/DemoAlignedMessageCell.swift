import Foundation
import UIKit
import SDWebImage

final class DemoAlignedMessageCell: UICollectionViewCell {
    static let reuseIdentifier = "DemoAlignedMessageCell"
    private static let sendingIconSpinKey = "DemoAlignedMessageCell.sendingIconSpin"

    private let bubbleView = UIView()
    private let senderMetaRow = UIStackView()
    private let senderAvatarView = UIImageView()
    private let senderNameLabel = UILabel()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private let statusRow = UIStackView()
    private let statusPillView = UIView()
    private let statusPillStack = UIStackView()
    private let statusPillIconView = UIImageView()
    private let statusPillLabel = UILabel()
    private let contentStack = UIStackView()
    private var bubbleMaxWidthConstraint: NSLayoutConstraint!
    private var bubbleTopToContentConstraint: NSLayoutConstraint!
    private var bubbleTopToSenderConstraint: NSLayoutConstraint!
    private var mineTrailingConstraint: NSLayoutConstraint!
    private var mineLeadingConstraint: NSLayoutConstraint!
    private var otherLeadingConstraint: NSLayoutConstraint!
    private var otherTrailingConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        senderAvatarView.sd_cancelCurrentImageLoad()
        senderAvatarView.image = UIImage(systemName: "person.crop.circle.fill")
        senderNameLabel.text = nil
        senderMetaRow.isHidden = true
        setBubbleAlignment(isMine: false)
        stopSendingIconAnimation()
        statusPillIconView.image = nil
        statusPillIconView.isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bubbleMaxWidthConstraint?.constant = bounds.width * 0.72
    }

    private func configureUI() {
        contentView.layoutMargins = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)

        senderMetaRow.translatesAutoresizingMaskIntoConstraints = false
        senderMetaRow.axis = .horizontal
        senderMetaRow.alignment = .center
        senderMetaRow.spacing = 6
        contentView.addSubview(senderMetaRow)

        senderAvatarView.translatesAutoresizingMaskIntoConstraints = false
        senderAvatarView.contentMode = .scaleAspectFill
        senderAvatarView.clipsToBounds = true
        senderAvatarView.layer.cornerRadius = 10
        senderAvatarView.tintColor = UIColor(RaverTheme.secondaryText)
        senderAvatarView.image = UIImage(systemName: "person.crop.circle.fill")
        senderAvatarView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        senderAvatarView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        senderMetaRow.addArrangedSubview(senderAvatarView)

        senderNameLabel.translatesAutoresizingMaskIntoConstraints = false
        senderNameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        senderNameLabel.textColor = UIColor(RaverTheme.secondaryText)
        senderMetaRow.addArrangedSubview(senderNameLabel)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 14
        bubbleView.layer.masksToBounds = true
        contentView.addSubview(bubbleView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 4
        bubbleView.addSubview(contentStack)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 16)

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textAlignment = .right
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        statusRow.translatesAutoresizingMaskIntoConstraints = false
        statusRow.axis = .horizontal
        statusRow.alignment = .center
        statusRow.spacing = 6

        statusPillView.translatesAutoresizingMaskIntoConstraints = false
        statusPillView.layer.cornerRadius = 8
        statusPillView.layer.masksToBounds = true
        statusPillView.isHidden = true

        statusPillStack.translatesAutoresizingMaskIntoConstraints = false
        statusPillStack.axis = .horizontal
        statusPillStack.alignment = .center
        statusPillStack.spacing = 4
        statusPillView.addSubview(statusPillStack)

        statusPillIconView.translatesAutoresizingMaskIntoConstraints = false
        statusPillIconView.contentMode = .scaleAspectFit
        statusPillIconView.isHidden = true
        NSLayoutConstraint.activate([
            statusPillIconView.widthAnchor.constraint(equalToConstant: 10),
            statusPillIconView.heightAnchor.constraint(equalToConstant: 10)
        ])
        statusPillStack.addArrangedSubview(statusPillIconView)

        statusPillLabel.translatesAutoresizingMaskIntoConstraints = false
        statusPillLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        statusPillLabel.textAlignment = .center
        statusPillLabel.numberOfLines = 1
        statusPillStack.addArrangedSubview(statusPillLabel)

        NSLayoutConstraint.activate([
            statusPillStack.leadingAnchor.constraint(equalTo: statusPillView.leadingAnchor, constant: 6),
            statusPillStack.trailingAnchor.constraint(equalTo: statusPillView.trailingAnchor, constant: -6),
            statusPillStack.topAnchor.constraint(equalTo: statusPillView.topAnchor, constant: 2),
            statusPillStack.bottomAnchor.constraint(equalTo: statusPillView.bottomAnchor, constant: -2)
        ])

        contentStack.addArrangedSubview(messageLabel)
        statusRow.addArrangedSubview(timeLabel)
        statusRow.addArrangedSubview(statusPillView)
        contentStack.addArrangedSubview(statusRow)

        bubbleMaxWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
        bubbleTopToContentConstraint = bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2)
        bubbleTopToSenderConstraint = bubbleView.topAnchor.constraint(equalTo: senderMetaRow.bottomAnchor, constant: 4)
        mineTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        mineLeadingConstraint = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor)
        otherLeadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor)
        otherTrailingConstraint = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor)

        NSLayoutConstraint.activate([
            senderMetaRow.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            senderMetaRow.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
            senderMetaRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),

            bubbleMaxWidthConstraint,
            bubbleTopToContentConstraint,
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            contentStack.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            contentStack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10)
        ])

        senderMetaRow.isHidden = true
        otherLeadingConstraint.isActive = true
        otherTrailingConstraint.isActive = true
    }

    func configure(
        message: ChatMessage,
        maxBubbleWidthRatio: CGFloat,
        showSenderMeta: Bool,
        isClusterStart: Bool,
        isClusterEnd: Bool
    ) {
        guard bubbleMaxWidthConstraint != nil else { return }
        bubbleMaxWidthConstraint.constant = max(180, bounds.width * maxBubbleWidthRatio)
        messageLabel.text = message.content
        timeLabel.text = message.createdAt.chatTimeText
        applyClusterLayout(
            isMine: message.isMine,
            isClusterStart: isClusterStart,
            isClusterEnd: isClusterEnd
        )

        let shouldShowSenderMeta = showSenderMeta && !message.isMine
        senderMetaRow.isHidden = !shouldShowSenderMeta
        bubbleTopToContentConstraint.isActive = !shouldShowSenderMeta
        bubbleTopToSenderConstraint.isActive = shouldShowSenderMeta
        if shouldShowSenderMeta {
            configureSenderMeta(for: message.sender)
        }

        setBubbleAlignment(isMine: message.isMine)
        if message.isMine {
            bubbleView.backgroundColor = UIColor(RaverTheme.accent)
            messageLabel.textColor = .white
            timeLabel.textColor = UIColor.white.withAlphaComponent(0.85)
            configureDeliveryStatus(message.deliveryStatus, isMine: true)
        } else {
            bubbleView.backgroundColor = UIColor(RaverTheme.card)
            messageLabel.textColor = UIColor(RaverTheme.primaryText)
            timeLabel.textColor = UIColor(RaverTheme.secondaryText)
            configureDeliveryStatus(message.deliveryStatus, isMine: false)
        }
    }

    private func configureSenderMeta(for sender: UserSummary) {
        senderNameLabel.text = sender.displayName.isEmpty ? sender.username : sender.displayName

        let fallback = UIImage(systemName: "person.crop.circle.fill")
        senderAvatarView.image = fallback
        guard let avatarURL = sender.avatarURL,
              let resolved = AppConfig.resolvedURLString(avatarURL),
              let url = URL(string: resolved) else {
            return
        }
        senderAvatarView.sd_setImage(with: url, placeholderImage: fallback)
    }

    private func configureDeliveryStatus(_ status: ChatMessageDeliveryStatus, isMine: Bool) {
        guard isMine else {
            stopSendingIconAnimation()
            statusPillView.isHidden = true
            return
        }
        switch status {
        case .sent:
            stopSendingIconAnimation()
            statusPillView.isHidden = true
            statusPillIconView.image = nil
            statusPillIconView.isHidden = true
        case .sending:
            statusPillLabel.text = L("发送中", "Sending")
            statusPillView.backgroundColor = isMine
                ? UIColor.white.withAlphaComponent(0.22)
                : UIColor(RaverTheme.cardBorder).withAlphaComponent(0.6)
            statusPillLabel.textColor = isMine ? .white : UIColor(RaverTheme.secondaryText)
            statusPillIconView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
            statusPillIconView.tintColor = statusPillLabel.textColor
            statusPillIconView.isHidden = false
            startSendingIconAnimation()
            statusPillView.isHidden = false
        case .failed:
            stopSendingIconAnimation()
            statusPillLabel.text = L("失败·点重试", "Failed · Tap retry")
            statusPillView.backgroundColor = isMine
                ? UIColor.systemRed.withAlphaComponent(0.28)
                : UIColor.systemRed.withAlphaComponent(0.12)
            statusPillLabel.textColor = isMine ? .white : UIColor.systemRed
            statusPillIconView.image = UIImage(systemName: "exclamationmark.circle.fill")
            statusPillIconView.tintColor = statusPillLabel.textColor
            statusPillIconView.isHidden = false
            statusPillView.isHidden = false
        }
    }

    private func startSendingIconAnimation() {
        guard statusPillIconView.layer.animation(forKey: Self.sendingIconSpinKey) == nil else {
            return
        }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = Double.pi * 2
        animation.duration = 0.9
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        statusPillIconView.layer.add(animation, forKey: Self.sendingIconSpinKey)
    }

    private func stopSendingIconAnimation() {
        statusPillIconView.layer.removeAnimation(forKey: Self.sendingIconSpinKey)
    }

    private func setBubbleAlignment(isMine: Bool) {
        NSLayoutConstraint.deactivate([
            mineTrailingConstraint,
            mineLeadingConstraint,
            otherLeadingConstraint,
            otherTrailingConstraint
        ])

        if isMine {
            NSLayoutConstraint.activate([
                mineTrailingConstraint,
                mineLeadingConstraint
            ])
        } else {
            NSLayoutConstraint.activate([
                otherLeadingConstraint,
                otherTrailingConstraint
            ])
        }
    }

    private func applyClusterLayout(
        isMine: Bool,
        isClusterStart: Bool,
        isClusterEnd: Bool
    ) {
        let topInset: CGFloat = isClusterStart ? 4 : 1
        let bottomInset: CGFloat = isClusterEnd ? 4 : 1
        contentView.layoutMargins = UIEdgeInsets(top: topInset, left: 8, bottom: bottomInset, right: 8)

        var corners: CACornerMask
        if isMine {
            corners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            if isClusterStart { corners.insert(.layerMaxXMinYCorner) }
            if isClusterEnd { corners.insert(.layerMaxXMaxYCorner) }
        } else {
            corners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            if isClusterStart { corners.insert(.layerMinXMinYCorner) }
            if isClusterEnd { corners.insert(.layerMinXMaxYCorner) }
        }
        bubbleView.layer.cornerRadius = 14
        bubbleView.layer.maskedCorners = corners
    }
}
