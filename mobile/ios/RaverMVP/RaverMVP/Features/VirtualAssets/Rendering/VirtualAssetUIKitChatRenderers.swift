import UIKit
import SDWebImage

enum VirtualAssetUIKitChatAvatarRenderer {
    static func apply(
        avatarFrame: VirtualAssetDefinition?,
        to avatarView: UIImageView,
        size: CGFloat
    ) {
        removeFrameOverlay(from: avatarView)
        guard let avatarFrame else { return }

        let metrics = UIKitAvatarFrameMetrics(asset: avatarFrame, traitCollection: avatarView.traitCollection)
        guard metrics.shouldRender(for: size) else { return }

        let overlaySize = size + metrics.externalInset * 2
        let overlay = UIImageView(frame: CGRect(
            x: -metrics.externalInset,
            y: -metrics.externalInset,
            width: overlaySize,
            height: overlaySize
        ))
        overlay.tag = frameOverlayTag
        overlay.contentMode = .scaleAspectFit
        overlay.isUserInteractionEnabled = false

        if let frameImageURL = metrics.frameImageURL,
           let url = URL(string: frameImageURL) {
            overlay.sd_setImage(with: url)
        } else {
            overlay.image = fallbackFrameImage(size: overlaySize, metrics: metrics)
        }
        avatarView.addSubview(overlay)
    }

    static func removeFrameOverlay(from avatarView: UIImageView) {
        avatarView.subviews
            .filter { $0.tag == frameOverlayTag }
            .forEach { $0.removeFromSuperview() }
    }

    private static let frameOverlayTag = 875_210

    private static func fallbackFrameImage(size: CGFloat, metrics: UIKitAvatarFrameMetrics) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(x: metrics.ringWidth + 2, y: metrics.ringWidth + 2, width: size - metrics.ringWidth * 2 - 4, height: size - metrics.ringWidth * 2 - 4)
            let path = UIBezierPath(ovalIn: rect)
            context.cgContext.setShadow(offset: .zero, blur: metrics.glowRadius, color: metrics.glowColor.withAlphaComponent(0.62).cgColor)
            context.cgContext.setLineWidth(metrics.ringWidth)
            if metrics.fallbackColors.count > 1,
               let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: metrics.fallbackColors.map(\.cgColor) as CFArray,
                locations: nil
               ) {
                context.cgContext.saveGState()
                context.cgContext.addPath(path.cgPath)
                context.cgContext.replacePathWithStrokedPath()
                context.cgContext.clip()
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.minX, y: rect.minY),
                    end: CGPoint(x: rect.maxX, y: rect.maxY),
                    options: []
                )
                context.cgContext.restoreGState()
            } else {
                context.cgContext.setStrokeColor((metrics.fallbackColors.first ?? UIColor(RaverTheme.accent)).cgColor)
                path.stroke()
            }
            context.cgContext.setShadow(offset: .zero, blur: 0)
            context.cgContext.setLineWidth(max(0.8, metrics.ringWidth * 0.34))
            context.cgContext.setStrokeColor(metrics.innerRingColor.cgColor)
            path.stroke()
        }
    }
}

enum VirtualAssetUIKitChatMetaRenderer {
    static func apply(
        appearance: UserAssetAppearance?,
        to stackView: UIStackView,
        after nameLabel: UILabel
    ) {
        removeDecorations(from: stackView)
        guard let appearance else { return }

        if let titleMedal = appearance.titleMedal {
            stackView.addArrangedSubview(makeTitleLabel(titleMedal, traitCollection: stackView.traitCollection))
        }

        if let badge = appearance.profileBadges.first {
            stackView.addArrangedSubview(makeBadgeView(badge, traitCollection: stackView.traitCollection))
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    static func removeDecorations(from stackView: UIStackView) {
        stackView.arrangedSubviews
            .filter { $0.tag == decorationTag }
            .forEach { view in
                stackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
    }

    private static let decorationTag = 875_211

    private static func makeTitleLabel(_ asset: VirtualAssetDefinition, traitCollection: UITraitCollection) -> UILabel {
        let payload = VirtualAssetPayloadReader.resolvedPayload(for: asset, traitCollection: traitCollection)
        let label = PaddingLabel(horizontalInset: 7, verticalInset: 3)
        label.tag = decorationTag
        label.font = .systemFont(ofSize: 10, weight: .heavy)
        label.text = payload.string("text") ?? asset.name
        label.textColor = VirtualAssetPayloadReader.uiColor(payload.string("textColorHex"), traitCollection: traitCollection) ?? .white
        label.backgroundColor = VirtualAssetPayloadReader.uiColor(payload.string("backgroundColorHex"), traitCollection: traitCollection) ?? UIColor(RaverTheme.accent)
        label.layer.cornerRadius = 7
        label.layer.masksToBounds = true
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private static func makeBadgeView(_ asset: VirtualAssetDefinition, traitCollection: UITraitCollection) -> UIView {
        let payload = VirtualAssetPayloadReader.resolvedPayload(for: asset, traitCollection: traitCollection)
        let container = UIView()
        container.tag = decorationTag
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = VirtualAssetPayloadReader.uiColor(payload.string("backgroundColorHex"), traitCollection: traitCollection)
            ?? UIColor(RaverTheme.card)
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true

        let letterLabel = UILabel()
        letterLabel.translatesAutoresizingMaskIntoConstraints = false
        letterLabel.text = payload.string("letter") ?? "R"
        letterLabel.textAlignment = .center
        letterLabel.font = .systemFont(ofSize: 11, weight: .black)
        letterLabel.textColor = VirtualAssetPayloadReader.uiColor(payload.string("textColorHex"), traitCollection: traitCollection)
            ?? UIColor(RaverTheme.accent)
        container.addSubview(letterLabel)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 18),
            container.heightAnchor.constraint(equalToConstant: 18),
            letterLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            letterLabel.widthAnchor.constraint(equalToConstant: 14),
            letterLabel.heightAnchor.constraint(equalToConstant: 14)
        ])
        container.setContentCompressionResistancePriority(.required, for: .horizontal)
        return container
    }
}

private final class PaddingLabel: UILabel {
    private let horizontalInset: CGFloat
    private let verticalInset: CGFloat

    init(horizontalInset: CGFloat, verticalInset: CGFloat) {
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + horizontalInset * 2, height: size.height + verticalInset * 2)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: horizontalInset, dy: verticalInset))
    }
}

private struct UIKitAvatarFrameMetrics {
    var frameImageURL: String?
    var renderMode: String?
    var externalInset: CGFloat
    var minAvatarSize: CGFloat
    var fallbackColors: [UIColor]
    var glowColor: UIColor
    var glowRadius: CGFloat
    var ringWidth: CGFloat
    var innerRingColor: UIColor

    init(asset: VirtualAssetDefinition, traitCollection: UITraitCollection) {
        let payload = VirtualAssetPayloadReader.resolvedPayload(for: asset, traitCollection: traitCollection)
        let variantURLKey = traitCollection.userInterfaceStyle == .dark ? "darkVariantURL" : "lightVariantURL"
        self.frameImageURL = payload.string(variantURLKey) ?? payload.string("frameImageURL")
        self.renderMode = payload.string("renderMode")
        self.externalInset = max(2, min(6, abs(payload.insets("frameInsets").minimumValue)))
        self.minAvatarSize = CGFloat(payload.double("minAvatarSize") ?? 24)
        let colors = VirtualAssetPayloadReader.uiColors(payload.arrayStrings("gradientColors"), traitCollection: traitCollection)
        self.fallbackColors = colors.isEmpty ? [UIColor(RaverTheme.accent)] : colors
        self.glowColor = VirtualAssetPayloadReader.uiColor(payload.string("glowColorHex"), traitCollection: traitCollection)
            ?? fallbackColors.first
            ?? UIColor(RaverTheme.accent)
        self.glowRadius = CGFloat(payload.double("glowRadius") ?? 8)
        self.ringWidth = CGFloat(payload.double("ringWidth") ?? 2.5)
        self.innerRingColor = VirtualAssetPayloadReader.uiColor(payload.string("innerRingColorHex"), traitCollection: traitCollection)
            ?? UIColor.white.withAlphaComponent(0.5)
    }

    func shouldRender(for avatarSize: CGFloat) -> Bool {
        externalInset > 0 && avatarSize >= minAvatarSize
    }
}

private enum VirtualAssetPayloadReader {
    static func resolvedPayload(
        for asset: VirtualAssetDefinition,
        traitCollection: UITraitCollection
    ) -> [String: VirtualAssetJSONValue] {
        let key = traitCollection.userInterfaceStyle == .dark ? "darkVariant" : "lightVariant"
        guard let variant = asset.renderPayload.object(key) else { return asset.renderPayload }
        return asset.renderPayload.merging(variant) { _, variantValue in variantValue }
    }

    static func uiColor(_ raw: String?, traitCollection: UITraitCollection) -> UIColor? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.hasPrefix("#") {
            return hexColor(raw)
        }
        return nil
    }

    static func uiColors(_ rawValues: [String]?, traitCollection: UITraitCollection) -> [UIColor] {
        rawValues?.compactMap { uiColor($0, traitCollection: traitCollection) } ?? []
    }

    private static func hexColor(_ raw: String) -> UIColor? {
        var value = raw.replacingOccurrences(of: "#", with: "")
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6 || value.count == 8,
              let intValue = UInt64(value, radix: 16) else { return nil }

        if value.count == 8 {
            return UIColor(
                red: CGFloat((intValue & 0x00FF0000) >> 16) / 255,
                green: CGFloat((intValue & 0x0000FF00) >> 8) / 255,
                blue: CGFloat(intValue & 0x000000FF) / 255,
                alpha: CGFloat((intValue & 0xFF000000) >> 24) / 255
            )
        }
        return UIColor(
            red: CGFloat((intValue & 0xFF0000) >> 16) / 255,
            green: CGFloat((intValue & 0x00FF00) >> 8) / 255,
            blue: CGFloat(intValue & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

private extension Dictionary where Key == String, Value == VirtualAssetJSONValue {
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func double(_ key: String) -> Double? {
        guard let value = self[key] else { return nil }
        if case .number(let number) = value { return number }
        if case .string(let string) = value { return Double(string) }
        return nil
    }

    func object(_ key: String) -> [String: VirtualAssetJSONValue]? {
        self[key]?.objectValue
    }

    func arrayStrings(_ key: String) -> [String]? {
        guard let value = self[key], case .array(let array) = value else { return nil }
        return array.compactMap(\.stringValue)
    }

    func insets(_ key: String) -> UIKitEdgeInsetValues {
        let object = object(key) ?? [:]
        return UIKitEdgeInsetValues(
            top: object.double("top") ?? 0,
            left: object.double("left") ?? 0,
            bottom: object.double("bottom") ?? 0,
            right: object.double("right") ?? 0
        )
    }
}

private struct UIKitEdgeInsetValues {
    var top: Double
    var left: Double
    var bottom: Double
    var right: Double

    var minimumValue: Double {
        [top, left, bottom, right].min() ?? 0
    }
}
