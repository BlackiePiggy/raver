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
    private let replyPreviewLabel = UILabel()
    private let timeLabel = UILabel()
    private let statusRow = UIStackView()
    private let statusPillView = UIView()
    private let statusPillStack = UIStackView()
    private let statusPillIconView = UIImageView()
    private let statusPillLabel = UILabel()
    private let contentStack = UIStackView()
    private var onReplyPreviewTapped: (() -> Void)?
    private var senderMetaLeadingConstraint: NSLayoutConstraint!
    private var senderMetaTrailingConstraint: NSLayoutConstraint!
    private var senderMetaLeadingLimitConstraint: NSLayoutConstraint!
    private var senderMetaTrailingLimitConstraint: NSLayoutConstraint!
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
        replyPreviewLabel.isHidden = true
        replyPreviewLabel.text = nil
        replyPreviewLabel.attributedText = nil
        replyPreviewLabel.backgroundColor = .clear
        onReplyPreviewTapped = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bubbleMaxWidthConstraint?.constant = bounds.width * 0.64
    }

    private func configureUI() {
        contentView.layoutMargins = UIEdgeInsets(top: 2, left: 12, bottom: 2, right: 12)

        senderMetaRow.translatesAutoresizingMaskIntoConstraints = false
        senderMetaRow.axis = .horizontal
        senderMetaRow.alignment = .center
        senderMetaRow.spacing = 8
        contentView.addSubview(senderMetaRow)

        senderAvatarView.translatesAutoresizingMaskIntoConstraints = false
        senderAvatarView.contentMode = .scaleAspectFill
        senderAvatarView.clipsToBounds = true
        senderAvatarView.layer.cornerRadius = 14
        senderAvatarView.tintColor = UIColor(RaverTheme.secondaryText)
        senderAvatarView.image = UIImage(systemName: "person.crop.circle.fill")
        senderAvatarView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        senderAvatarView.heightAnchor.constraint(equalToConstant: 28).isActive = true
        senderMetaRow.addArrangedSubview(senderAvatarView)

        senderNameLabel.translatesAutoresizingMaskIntoConstraints = false
        senderNameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        senderNameLabel.textColor = UIColor(RaverTheme.secondaryText)
        senderMetaRow.addArrangedSubview(senderNameLabel)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 16
        bubbleView.layer.masksToBounds = true
        contentView.addSubview(bubbleView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 5
        bubbleView.addSubview(contentStack)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 16)

        replyPreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        replyPreviewLabel.numberOfLines = 2
        replyPreviewLabel.font = .systemFont(ofSize: 12, weight: .medium)
        replyPreviewLabel.layer.cornerRadius = 6
        replyPreviewLabel.layer.masksToBounds = true
        replyPreviewLabel.isHidden = true
        replyPreviewLabel.isUserInteractionEnabled = true
        replyPreviewLabel.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleReplyPreviewTapped))
        )

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

        contentStack.addArrangedSubview(replyPreviewLabel)
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
        senderMetaLeadingConstraint = senderMetaRow.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor)
        senderMetaTrailingConstraint = senderMetaRow.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        senderMetaLeadingLimitConstraint = senderMetaRow.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor)
        senderMetaTrailingLimitConstraint = senderMetaRow.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor)

        NSLayoutConstraint.activate([
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
        senderMetaLeadingConstraint.isActive = true
        senderMetaTrailingLimitConstraint.isActive = true
        otherLeadingConstraint.isActive = true
        otherTrailingConstraint.isActive = true
    }

    func configure(
        message: ChatMessage,
        maxBubbleWidthRatio: CGFloat,
        showSenderMeta: Bool,
        isClusterStart: Bool,
        isClusterEnd: Bool,
        onReplyPreviewTapped: ((ChatMessage) -> Void)?
    ) {
        guard bubbleMaxWidthConstraint != nil else { return }
        self.onReplyPreviewTapped = { onReplyPreviewTapped?(message) }
        bubbleMaxWidthConstraint.constant = max(180, bounds.width * maxBubbleWidthRatio)
        applyMessageTextStyle(message)
        if let replyPreview = message.replyPreview?.trimmingCharacters(in: .whitespacesAndNewlines),
           !replyPreview.isEmpty {
            replyPreviewLabel.isHidden = false
            replyPreviewLabel.attributedText = styledReplyPreview("↪︎ \(replyPreview)", isMine: message.isMine)
            replyPreviewLabel.backgroundColor = message.isMine
                ? UIColor.white.withAlphaComponent(0.18)
                : UIColor(RaverTheme.background)
        } else {
            replyPreviewLabel.isHidden = true
            replyPreviewLabel.text = nil
            replyPreviewLabel.attributedText = nil
            replyPreviewLabel.backgroundColor = .clear
        }
        timeLabel.text = message.createdAt.chatTimeText
        applyClusterLayout(
            isMine: message.isMine,
            isClusterStart: isClusterStart,
            isClusterEnd: isClusterEnd
        )

        let shouldShowSenderMeta = showSenderMeta
        senderMetaRow.isHidden = !shouldShowSenderMeta
        bubbleTopToContentConstraint.isActive = !shouldShowSenderMeta
        bubbleTopToSenderConstraint.isActive = shouldShowSenderMeta
        if shouldShowSenderMeta {
            configureSenderMeta(for: message.sender, isMine: message.isMine)
        }

        setBubbleAlignment(isMine: message.isMine)
        if message.isMine {
            bubbleView.backgroundColor = UIColor(RaverTheme.accent)
            messageLabel.textColor = .white
            timeLabel.textColor = UIColor.white.withAlphaComponent(0.85)
            configureDeliveryStatus(message.deliveryStatus, isMine: true, message: message)
        } else {
            bubbleView.backgroundColor = UIColor(RaverTheme.card)
            messageLabel.textColor = UIColor(RaverTheme.primaryText)
            timeLabel.textColor = UIColor(RaverTheme.secondaryText)
            configureDeliveryStatus(message.deliveryStatus, isMine: false, message: message)
        }
    }

    @objc
    private func handleReplyPreviewTapped() {
        guard !replyPreviewLabel.isHidden else { return }
        onReplyPreviewTapped?()
    }

    private func applyMessageTextStyle(_ message: ChatMessage) {
        let baseColor = message.isMine ? UIColor.white : UIColor(RaverTheme.primaryText)
        let attributed = NSMutableAttributedString(
            string: message.content,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: baseColor
            ]
        )

        for mention in message.mentionedUserIDs where !mention.isEmpty {
            let marker = "@\(mention)"
            let escaped = NSRegularExpression.escapedPattern(for: marker)
            guard let regex = try? NSRegularExpression(pattern: "(^|\\s)(\(escaped))") else {
                continue
            }
            let fullRange = NSRange(message.content.startIndex..<message.content.endIndex, in: message.content)
            for match in regex.matches(in: message.content, options: [], range: fullRange) {
                guard match.numberOfRanges > 2 else { continue }
                let mentionRange = match.range(at: 2)
                attributed.addAttributes([
                    .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: message.isMine
                        ? UIColor.white
                        : UIColor(RaverTheme.accent)
                ], range: mentionRange)
            }
        }

        messageLabel.attributedText = attributed
    }

    private func styledReplyPreview(_ text: String, isMine: Bool) -> NSAttributedString {
        let baseColor = isMine ? UIColor.white.withAlphaComponent(0.88) : UIColor(RaverTheme.secondaryText)
        let senderColor = isMine ? UIColor.white : UIColor(RaverTheme.accent)
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: baseColor
            ]
        )

        guard let colonIndex = text.firstIndex(of: ":") else {
            return attributed
        }
        let nameStart = text.index(text.startIndex, offsetBy: min(2, text.count))
        if nameStart < colonIndex,
           let range = NSRange(nameStart..<colonIndex, in: text) as NSRange? {
            attributed.addAttributes([
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: senderColor
            ], range: range)
        }
        return attributed
    }

    private func configureSenderMeta(for sender: UserSummary, isMine: Bool) {
        if isMine {
            senderNameLabel.text = L("我", "Me")
        } else {
            senderNameLabel.text = sender.displayName.isEmpty ? sender.username : sender.displayName
        }

        let fallback = UIImage(systemName: "person.crop.circle.fill")
        senderAvatarView.image = fallback
        guard let avatarURL = sender.avatarURL,
              let resolved = AppConfig.resolvedURLString(avatarURL),
              let url = URL(string: resolved) else {
            return
        }
        senderAvatarView.sd_setImage(with: url, placeholderImage: fallback)
    }

    private func configureDeliveryStatus(_ status: ChatMessageDeliveryStatus, isMine: Bool, message: ChatMessage) {
        guard isMine else {
            stopSendingIconAnimation()
            statusPillView.isHidden = true
            return
        }
        switch status {
        case .sent:
            stopSendingIconAnimation()
            if let readCount = message.readReceiptReadCount, readCount > 0 {
                if let unreadCount = message.readReceiptUnreadCount {
                    statusPillLabel.text = "\(L("已读", "Read")) \(readCount)\(L("人", "")) · \(L("未读", "Unread")) \(max(unreadCount, 0))"
                } else {
                    statusPillLabel.text = "\(L("已读", "Read")) \(readCount)\(L("人", ""))"
                }
            } else if let peerRead = message.peerRead {
                statusPillLabel.text = peerRead ? L("已读", "Read") : L("未读", "Unread")
            } else {
                statusPillLabel.text = L("已发送", "Sent")
            }
            statusPillView.backgroundColor = isMine
                ? UIColor.white.withAlphaComponent(0.2)
                : UIColor(RaverTheme.cardBorder).withAlphaComponent(0.6)
            statusPillLabel.textColor = isMine ? .white : UIColor(RaverTheme.secondaryText)
            statusPillIconView.image = UIImage(systemName: "checkmark")
            statusPillIconView.tintColor = statusPillLabel.textColor
            statusPillIconView.isHidden = false
            statusPillView.isHidden = false
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
            otherTrailingConstraint,
            senderMetaLeadingConstraint,
            senderMetaTrailingConstraint,
            senderMetaLeadingLimitConstraint,
            senderMetaTrailingLimitConstraint
        ])

        if isMine {
            NSLayoutConstraint.activate([
                mineTrailingConstraint,
                mineLeadingConstraint,
                senderMetaTrailingConstraint,
                senderMetaLeadingLimitConstraint
            ])
            senderMetaRow.alignment = .trailing
        } else {
            NSLayoutConstraint.activate([
                otherLeadingConstraint,
                otherTrailingConstraint,
                senderMetaLeadingConstraint,
                senderMetaTrailingLimitConstraint
            ])
            senderMetaRow.alignment = .leading
        }
    }

    private func applyClusterLayout(
        isMine: Bool,
        isClusterStart: Bool,
        isClusterEnd: Bool
    ) {
        let topInset: CGFloat = isClusterStart ? 4 : 1
        let bottomInset: CGFloat = isClusterEnd ? 4 : 1
        contentView.layoutMargins = UIEdgeInsets(top: topInset, left: 12, bottom: bottomInset, right: 12)

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
        bubbleView.layer.cornerRadius = 16
        bubbleView.layer.maskedCorners = corners
    }
}
