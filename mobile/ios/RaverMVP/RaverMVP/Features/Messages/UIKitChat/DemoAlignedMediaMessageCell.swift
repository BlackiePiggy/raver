import Foundation
import UIKit
import AVFoundation
import SDWebImage

final class DemoAlignedMediaMessageCell: UICollectionViewCell {
    static let reuseIdentifier = "DemoAlignedMediaMessageCell"
    private static let sendingIconSpinKey = "DemoAlignedMediaMessageCell.sendingIconSpin"

    private let senderMetaRow = UIStackView()
    private let senderAvatarView = UIImageView()
    private let senderNameLabel = UILabel()
    private let bubbleView = UIView()
    private let previewContainer = UIView()
    private let previewImageView = UIImageView()
    private let playIconView = UIImageView()
    private let durationBadgeLabel = UILabel()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let timeLabel = UILabel()
    private let statusRow = UIStackView()
    private let statusPillView = UIView()
    private let statusPillStack = UIStackView()
    private let statusPillIconView = UIImageView()
    private let statusPillLabel = UILabel()
    private let mainStack = UIStackView()
    private let textStack = UIStackView()
    private var bubbleMaxWidthConstraint: NSLayoutConstraint!
    private var bubbleTopToContentConstraint: NSLayoutConstraint!
    private var bubbleTopToSenderConstraint: NSLayoutConstraint!
    private var mineTrailingConstraint: NSLayoutConstraint!
    private var mineLeadingConstraint: NSLayoutConstraint!
    private var otherLeadingConstraint: NSLayoutConstraint!
    private var otherTrailingConstraint: NSLayoutConstraint!
    private var previewHeightConstraint: NSLayoutConstraint!
    private var renderToken = UUID()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bubbleMaxWidthConstraint?.constant = bounds.width * 0.72
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        renderToken = UUID()
        previewImageView.sd_cancelCurrentImageLoad()
        previewImageView.image = nil
        senderAvatarView.sd_cancelCurrentImageLoad()
        senderAvatarView.image = UIImage(systemName: "person.crop.circle.fill")
        senderNameLabel.text = nil
        senderMetaRow.isHidden = true
        setBubbleAlignment(isMine: false)
        stopSendingIconAnimation()
        statusPillIconView.image = nil
        statusPillIconView.isHidden = true
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
        let senderAvatarWidthConstraint = senderAvatarView.widthAnchor.constraint(equalToConstant: 20)
        senderAvatarWidthConstraint.priority = .defaultHigh
        senderAvatarWidthConstraint.isActive = true
        let senderAvatarHeightConstraint = senderAvatarView.heightAnchor.constraint(equalToConstant: 20)
        senderAvatarHeightConstraint.priority = .defaultHigh
        senderAvatarHeightConstraint.isActive = true
        senderMetaRow.addArrangedSubview(senderAvatarView)

        senderNameLabel.translatesAutoresizingMaskIntoConstraints = false
        senderNameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        senderNameLabel.textColor = UIColor(RaverTheme.secondaryText)
        senderMetaRow.addArrangedSubview(senderNameLabel)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 14
        bubbleView.layer.masksToBounds = true
        contentView.addSubview(bubbleView)

        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.spacing = 6
        bubbleView.addSubview(mainStack)

        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.layer.cornerRadius = 10
        previewContainer.layer.masksToBounds = true
        previewContainer.backgroundColor = UIColor(RaverTheme.cardBorder).withAlphaComponent(0.2)

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        previewContainer.addSubview(previewImageView)

        playIconView.translatesAutoresizingMaskIntoConstraints = false
        playIconView.image = UIImage(systemName: "play.circle.fill")
        playIconView.tintColor = UIColor.white.withAlphaComponent(0.94)
        playIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        previewContainer.addSubview(playIconView)

        durationBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        durationBadgeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        durationBadgeLabel.textColor = .white
        durationBadgeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        durationBadgeLabel.layer.cornerRadius = 7
        durationBadgeLabel.layer.masksToBounds = true
        durationBadgeLabel.textAlignment = .center
        durationBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        previewContainer.addSubview(durationBadgeLabel)

        let contentRow = UIStackView()
        contentRow.axis = .horizontal
        contentRow.alignment = .center
        contentRow.spacing = 8

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = UIColor(RaverTheme.secondaryText)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        let iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 18)
        iconWidthConstraint.priority = .defaultHigh
        iconWidthConstraint.isActive = true
        let iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: 18)
        iconHeightConstraint.priority = .defaultHigh
        iconHeightConstraint.isActive = true

        textStack.axis = .vertical
        textStack.spacing = 2

        titleLabel.numberOfLines = 1
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        detailLabel.numberOfLines = 1
        detailLabel.font = .systemFont(ofSize: 12)

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

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)
        contentRow.addArrangedSubview(iconView)
        contentRow.addArrangedSubview(textStack)

        mainStack.addArrangedSubview(previewContainer)
        mainStack.addArrangedSubview(contentRow)
        statusRow.addArrangedSubview(timeLabel)
        statusRow.addArrangedSubview(statusPillView)
        mainStack.addArrangedSubview(statusRow)

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

            mainStack.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            mainStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            mainStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            mainStack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10)
        ])

        previewHeightConstraint = previewContainer.heightAnchor.constraint(equalToConstant: 0)
        previewHeightConstraint.priority = .defaultHigh
        previewHeightConstraint.isActive = true
        NSLayoutConstraint.activate([
            previewImageView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),

            playIconView.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            playIconView.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),

            durationBadgeLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -6),
            durationBadgeLabel.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -6),
            durationBadgeLabel.heightAnchor.constraint(equalToConstant: 18),
            durationBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 36)
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
        bubbleMaxWidthConstraint.constant = max(180, bounds.width * maxBubbleWidthRatio)
        applyClusterLayout(
            isMine: message.isMine,
            isClusterStart: isClusterStart,
            isClusterEnd: isClusterEnd
        )
        let descriptor = descriptor(for: message)
        iconView.image = UIImage(systemName: descriptor.symbolName)
        titleLabel.text = descriptor.title
        detailLabel.text = descriptor.detail
        detailLabel.isHidden = descriptor.detail == nil
        timeLabel.text = message.createdAt.chatTimeText
        configurePreview(for: message)

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
            iconView.tintColor = .white
            titleLabel.textColor = .white
            detailLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            timeLabel.textColor = UIColor.white.withAlphaComponent(0.85)
            configureDeliveryStatus(message.deliveryStatus, isMine: true)
        } else {
            bubbleView.backgroundColor = UIColor(RaverTheme.card)
            iconView.tintColor = UIColor(RaverTheme.secondaryText)
            titleLabel.textColor = UIColor(RaverTheme.primaryText)
            detailLabel.textColor = UIColor(RaverTheme.secondaryText)
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

    private func configurePreview(for message: ChatMessage) {
        renderToken = UUID()
        let token = renderToken

        guard message.kind == .image || message.kind == .video else {
            previewContainer.isHidden = true
            previewHeightConstraint.constant = 0
            playIconView.isHidden = true
            durationBadgeLabel.isHidden = true
            previewImageView.image = nil
            return
        }

        previewContainer.isHidden = false
        previewHeightConstraint.constant = previewHeight(for: message)
        playIconView.isHidden = message.kind != .video

        if message.kind == .video,
           let duration = formatDuration(message.media?.durationSeconds),
           !duration.isEmpty {
            durationBadgeLabel.text = " \(duration) "
            durationBadgeLabel.isHidden = false
        } else {
            durationBadgeLabel.isHidden = true
        }

        let placeholder = message.kind == .video
            ? UIImage(systemName: "video.fill")
            : UIImage(systemName: "photo")
        previewImageView.image = placeholder

        if let previewRaw = RaverChatMediaResolver.previewRawURL(for: message),
           let previewURL = RaverChatMediaResolver.resolvedURL(from: previewRaw) {
            loadPreviewImage(url: previewURL, kind: message.kind, token: token)
            return
        }

        if message.kind == .video,
           let playbackRaw = RaverChatMediaResolver.playbackRawURL(for: message),
           let playbackURL = RaverChatMediaResolver.resolvedURL(from: playbackRaw) {
            generateVideoThumbnail(url: playbackURL, token: token)
        }
    }

    private func loadPreviewImage(url: URL, kind: ChatMessageKind, token: UUID) {
        if url.isFileURL {
            ChatMediaTempFileStore.noteAccess(for: url)
            if kind == .video {
                generateVideoThumbnail(url: url, token: token)
                return
            }

            if let image = UIImage(contentsOfFile: url.path), renderToken == token {
                previewImageView.image = image
            }
            return
        }

        previewImageView.sd_setImage(with: url, placeholderImage: previewImageView.image)
    }

    private func generateVideoThumbnail(url: URL, token: UUID) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let thumbnail = Self.makeVideoThumbnail(url: url)
            DispatchQueue.main.async {
                guard let self, self.renderToken == token else { return }
                if let thumbnail {
                    self.previewImageView.image = thumbnail
                }
            }
        }
    }

    private static func makeVideoThumbnail(url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: imageRef)
    }

    private func previewHeight(for message: ChatMessage) -> CGFloat {
        let defaultSize = CGSize(width: 220, height: message.kind == .video ? 150 : 220)
        let width = message.media?.width ?? defaultSize.width
        let height = message.media?.height ?? defaultSize.height

        guard width > 0, height > 0 else { return defaultSize.height }

        let maxWidth: CGFloat = 220
        let maxHeight: CGFloat = 240
        let minHeight: CGFloat = 120
        let scale = min(maxWidth / width, maxHeight / height)
        let fitHeight = max(minHeight, min(maxHeight, height * scale))
        return fitHeight
    }

    private func descriptor(for message: ChatMessage) -> (symbolName: String, title: String, detail: String?) {
        switch message.kind {
        case .image:
            let sizeText = formatFileSize(message.media?.fileSizeBytes)
            return ("photo", L("图片", "Image"), sizeText)
        case .video:
            let duration = formatDuration(message.media?.durationSeconds)
            return ("video", L("视频", "Video"), duration)
        case .voice:
            let duration = formatDuration(message.media?.durationSeconds)
            return ("waveform", L("语音", "Voice"), duration)
        case .file:
            let title = message.media?.fileName ?? L("文件", "File")
            let sizeText = formatFileSize(message.media?.fileSizeBytes)
            return ("doc", title, sizeText)
        default:
            return ("doc.text", message.content, nil)
        }
    }

    private func formatDuration(_ seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formatFileSize(_ bytes: Int?) -> String? {
        guard let bytes, bytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
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
