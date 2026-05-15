import SwiftUI
import UIKit

struct VirtualAssetAvatarView<AvatarContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let size: CGFloat
    let avatarFrame: VirtualAssetDefinition?
    let avatarContent: AvatarContent

    init(
        size: CGFloat,
        avatarFrame: VirtualAssetDefinition?,
        @ViewBuilder avatarContent: () -> AvatarContent
    ) {
        self.size = size
        self.avatarFrame = avatarFrame
        self.avatarContent = avatarContent()
    }

    var body: some View {
        let metrics = AvatarFrameMetrics(asset: avatarFrame, colorScheme: colorScheme)
        ZStack {
            avatarContent
                .frame(width: size, height: size)
                .clipShape(Circle())

            if metrics.shouldRender(for: size) {
                avatarFrameOverlay(metrics)
            }
        }
        .frame(width: size + metrics.externalInset * 2, height: size + metrics.externalInset * 2)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func avatarFrameOverlay(_ metrics: AvatarFrameMetrics) -> some View {
        if metrics.renderMode == "code_glow" {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: metrics.fallbackGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: metrics.ringWidth
                )
                .frame(width: size + metrics.externalInset * 1.5, height: size + metrics.externalInset * 1.5)
                .overlay(
                    Circle()
                        .stroke(metrics.innerRingColor.opacity(0.7), lineWidth: max(0.8, metrics.ringWidth * 0.34))
                        .frame(width: size + metrics.externalInset * 0.72, height: size + metrics.externalInset * 0.72)
                )
                .shadow(color: metrics.glowColor.opacity(0.62), radius: metrics.glowRadius)
                .shadow(color: metrics.glowColor.opacity(0.34), radius: metrics.glowRadius * 0.48)
                .allowsHitTesting(false)
        } else if let frameImageURL = metrics.frameImageURL {
            ImageLoaderView(
                urlString: frameImageURL,
                resizingMode: .fit,
                showsIndicator: false,
                showsFallback: false
            )
            .frame(width: size + metrics.externalInset * 2, height: size + metrics.externalInset * 2)
            .allowsHitTesting(false)
        } else {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: metrics.fallbackGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(2, size * 0.055)
                )
                .frame(width: size + metrics.externalInset * 1.5, height: size + metrics.externalInset * 1.5)
                .shadow(color: metrics.fallbackGradientColors.first?.opacity(0.22) ?? .clear, radius: 6)
                .allowsHitTesting(false)
        }
    }
}

struct VirtualAssetBadgeView: View {
    @Environment(\.colorScheme) private var colorScheme

    let asset: VirtualAssetDefinition
    var compact: Bool = false
    var showTitle: Bool = true

    var body: some View {
        let payload = VirtualAssetPayloadResolver.resolvedPayload(for: asset, colorScheme: colorScheme)
        let mode = compact ? "icon" : (payload.string("displayMode") ?? "pill")
        let title = payload.string("title") ?? asset.name
        let background = badgeBackgroundColor(payload)
        let foreground = VirtualAssetColorParser.color(from: payload.string("textColorHex")) ?? RaverTheme.primaryText
        let shape = VirtualAssetBadgeShape(style: payload.string("badgeShape") ?? "circle")

        Group {
            if mode == "icon", !showTitle {
                badgeIcon(payload: payload, background: background, foreground: foreground, shape: shape)
            } else if mode == "icon_text" || showTitle {
                HStack(spacing: 5) {
                    badgeIconImage(payload: payload, foreground: foreground)
                        .frame(width: compact ? 18 : 21, height: compact ? 18 : 21)
                        .background(shape.fill(badgeFill(payload: payload, fallback: background)))
                        .overlay(shape.stroke(badgeBorderColor(payload), lineWidth: 0.8))
                    Text(title)
                        .font(.system(size: compact ? 10 : 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(foreground)
                }
                .padding(.horizontal, compact ? 7 : 9)
                .padding(.vertical, compact ? 4 : 6)
                .background(Capsule().fill(background.opacity(colorScheme == .dark ? 0.62 : 0.2)))
                .overlay(Capsule().stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.34), lineWidth: 0.8))
            } else {
                badgeIcon(payload: payload, background: background, foreground: foreground, shape: shape)
            }
        }
        .accessibilityLabel(title)
    }

    private func badgeBackgroundColor(_ payload: [String: VirtualAssetJSONValue]) -> Color {
        let key = colorScheme == .dark ? "darkBackgroundColorHex" : "lightBackgroundColorHex"
        return VirtualAssetColorParser.color(from: payload.string(key))
            ?? VirtualAssetColorParser.color(from: payload.string("backgroundColorHex"))
            ?? RaverTheme.card
    }

    private func badgeIcon(
        payload: [String: VirtualAssetJSONValue],
        background: Color,
        foreground: Color,
        shape: VirtualAssetBadgeShape
    ) -> some View {
        badgeIconImage(payload: payload, foreground: foreground)
            .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
            .background(shape.fill(badgeFill(payload: payload, fallback: background)))
            .overlay(shape.stroke(badgeBorderColor(payload), lineWidth: 0.9))
            .shadow(
                color: (VirtualAssetColorParser.color(from: payload.string("glowColorHex")) ?? background)
                    .opacity(colorScheme == .dark ? 0.38 : 0.18),
                radius: compact ? 4 : 6,
                y: 1
            )
    }

    @ViewBuilder
    private func badgeIconImage(
        payload: [String: VirtualAssetJSONValue],
        foreground: Color
    ) -> some View {
        let iconURL = compact ? (payload.string("compactIconURL") ?? payload.string("iconURL")) : payload.string("iconURL")
        if let iconURL {
            ImageLoaderView(
                urlString: iconURL,
                resizingMode: .fit,
                showsIndicator: false,
                showsFallback: false
            )
            .frame(width: compact ? 14 : 16, height: compact ? 14 : 16)
        } else {
            Text(payload.string("letter") ?? "R")
                .font(.system(size: compact ? 11 : 14, weight: .black, design: .rounded))
                .minimumScaleFactor(0.7)
                .foregroundStyle(foreground)
        }
    }

    private func badgeFill(payload: [String: VirtualAssetJSONValue], fallback: Color) -> LinearGradient {
        let colors = VirtualAssetColorParser.colors(from: payload.arrayStrings("gradientColors"))
        return LinearGradient(
            colors: colors.isEmpty ? [fallback, fallback] : colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func badgeBorderColor(_ payload: [String: VirtualAssetJSONValue]) -> Color {
        VirtualAssetColorParser.color(from: payload.string("borderColorHex"))
            ?? Color.white.opacity(colorScheme == .dark ? 0.18 : 0.42)
    }
}

struct VirtualAssetTitleMedalView: View {
    @Environment(\.colorScheme) private var colorScheme

    let asset: VirtualAssetDefinition
    var compact: Bool = false
    var maxWidth: CGFloat? = nil

    var body: some View {
        let payload = VirtualAssetPayloadResolver.resolvedPayload(for: asset, colorScheme: colorScheme)
        let text = medalText(payload)
        let shape = VirtualAssetMedalShape(style: payload.string("labelShape") ?? "capsule")
        let gradientColors = VirtualAssetColorParser.colors(from: payload.arrayStrings("gradientColors"))
        let background = VirtualAssetColorParser.color(from: payload.string("backgroundColorHex")) ?? RaverTheme.accent
        let textColor = VirtualAssetColorParser.color(from: payload.string("textColorHex")) ?? .white
        let borderColor = VirtualAssetColorParser.color(from: payload.string("borderColorHex")) ?? Color.white.opacity(0.2)
        let resolvedWidth = maxWidth ?? CGFloat(payload.double(compact ? "compactFixedWidth" : "fixedWidth") ?? (compact ? 74 : 88))

        HStack(spacing: compact ? 4 : 6) {
            medalIcon(payload: payload, textColor: textColor)
            Text(text)
                .font(.system(size: compact ? 10 : 12, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 4 : 6)
        .frame(width: resolvedWidth, alignment: .center)
        .background(
            shape.fill(
                LinearGradient(
                    colors: gradientColors.isEmpty ? [background, background] : gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
        .overlay(shape.stroke(borderColor, lineWidth: 0.9))
        .shadow(color: (gradientColors.first ?? background).opacity(colorScheme == .dark ? 0.24 : 0.14), radius: 8, y: 3)
        .accessibilityLabel(text)
    }

    private func medalText(_ payload: [String: VirtualAssetJSONValue]) -> String {
        let text = payload.string("text") ?? asset.name
        let limit = payload.int("maxTextLength") ?? (compact ? 8 : 16)
        guard text.count > limit else { return text }
        let endIndex = text.index(text.startIndex, offsetBy: max(1, limit - 1))
        return String(text[..<endIndex]) + "…"
    }

    @ViewBuilder
    private func medalIcon(payload: [String: VirtualAssetJSONValue], textColor: Color) -> some View {
        if let iconURL = payload.string("iconURL") {
            ImageLoaderView(
                urlString: iconURL,
                resizingMode: .fit,
                showsIndicator: false,
                showsFallback: false
            )
            .frame(width: compact ? 11 : 13, height: compact ? 11 : 13)
        } else {
            Image(systemName: "bolt.fill")
                .font(.system(size: compact ? 9 : 11, weight: .black))
                .foregroundStyle(textColor.opacity(0.92))
        }
    }
}

struct VirtualAssetChatBubbleContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let asset: VirtualAssetDefinition?
    let isMine: Bool
    let content: (VirtualAssetChatBubbleRenderStyle) -> Content

    init(
        asset: VirtualAssetDefinition?,
        isMine: Bool,
        @ViewBuilder content: @escaping (VirtualAssetChatBubbleRenderStyle) -> Content
    ) {
        self.asset = asset
        self.isMine = isMine
        self.content = content
    }

    var body: some View {
        let style = VirtualAssetChatBubbleRenderer.style(
            for: asset,
            isMine: isMine,
            colorScheme: colorScheme
        )
        content(style)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: style.swiftUIBackgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(style.borderColor), lineWidth: style.borderColor == .clear ? 0 : 0.8)
            )
    }
}

struct VirtualAssetRenderPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    let appearance: UserAssetAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                VirtualAssetAvatarView(size: 72, avatarFrame: appearance.avatarFrame) {
                    AvatarPlaceholderView(size: 72, backgroundColor: RaverTheme.accent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let titleMedal = appearance.titleMedal {
                        VirtualAssetTitleMedalView(asset: titleMedal)
                    }
                    profileBadges
                }
            }

            VirtualAssetChatBubbleContainer(asset: appearance.chatBubbleSkin, isMine: true) { style in
                Text(LT("这是一条装扮气泡预览", "This is a bubble skin preview", "これは吹き出しスキンのプレビューです"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(style.textColor))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(RaverTheme.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(RaverTheme.cardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var profileBadges: some View {
        if appearance.profileBadges.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(appearance.profileBadges.prefix(5)) { badge in
                    VirtualAssetBadgeView(asset: badge, compact: true, showTitle: false)
                }
            }
        }
    }
}

struct VirtualAssetChatBubbleRenderStyle: Hashable {
    var backgroundColors: [UIColor]
    var textColor: UIColor
    var secondaryTextColor: UIColor
    var borderColor: UIColor

    var swiftUIBackgroundColors: [Color] {
        let colors = backgroundColors.map(Color.init)
        return colors.isEmpty ? [RaverTheme.accent, RaverTheme.accent] : colors
    }
}

enum VirtualAssetChatBubbleRenderer {
    private static let gradientLayerName = "VirtualAssetChatBubbleGradientLayer"

    static func style(
        for asset: VirtualAssetDefinition?,
        isMine: Bool,
        colorScheme: ColorScheme
    ) -> VirtualAssetChatBubbleRenderStyle {
        let traitStyle: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let traitCollection = UITraitCollection(userInterfaceStyle: traitStyle)
        return style(for: asset, isMine: isMine, traitCollection: traitCollection)
    }

    static func style(
        for asset: VirtualAssetDefinition?,
        isMine: Bool,
        traitCollection: UITraitCollection
    ) -> VirtualAssetChatBubbleRenderStyle {
        let defaultStyle = defaultStyle(isMine: isMine)
        guard isMine,
              let asset,
              asset.type == .chatBubbleSkin,
              asset.status == .active || asset.status == .hidden else {
            return defaultStyle
        }

        let payload = VirtualAssetPayloadResolver.resolvedPayload(for: asset, traitCollection: traitCollection)
        if payload.bool("outgoingSupported") == false {
            return defaultStyle
        }

        let backgroundColors = VirtualAssetColorParser.uiColors(from: payload.arrayStrings("gradientColors"), traitCollection: traitCollection)
        let singleBackground = VirtualAssetColorParser.uiColor(from: payload.string("backgroundColorHex"), traitCollection: traitCollection)
        let resolvedBackgrounds = backgroundColors.isEmpty ? [singleBackground ?? UIColor(RaverTheme.accent)] : backgroundColors
        let requestedTextColor = VirtualAssetColorParser.uiColor(from: payload.string("textColorHex"), traitCollection: traitCollection) ?? .white
        let fallbackTextColor = VirtualAssetColorParser.uiColor(from: payload.string("fallbackTextColorHex"), traitCollection: traitCollection) ?? defaultStyle.textColor
        let textColor = VirtualAssetColorParser.hasReadableContrast(
            foreground: requestedTextColor,
            background: resolvedBackgrounds.first ?? UIColor(RaverTheme.accent)
        ) ? requestedTextColor : fallbackTextColor

        return VirtualAssetChatBubbleRenderStyle(
            backgroundColors: resolvedBackgrounds,
            textColor: textColor,
            secondaryTextColor: textColor.withAlphaComponent(0.85),
            borderColor: VirtualAssetColorParser.uiColor(from: payload.string("borderColorHex"), traitCollection: traitCollection) ?? .clear
        )
    }

    static func apply(
        asset: VirtualAssetDefinition?,
        to bubbleView: UIView,
        primaryLabels: [UILabel],
        secondaryLabels: [UILabel] = [],
        isMine: Bool,
        traitCollection: UITraitCollection
    ) {
        let style = style(for: asset, isMine: isMine, traitCollection: traitCollection)
        apply(style: style, to: bubbleView, primaryLabels: primaryLabels, secondaryLabels: secondaryLabels)
    }

    static func apply(
        style: VirtualAssetChatBubbleRenderStyle,
        to bubbleView: UIView,
        primaryLabels: [UILabel],
        secondaryLabels: [UILabel] = []
    ) {
        removeGradientLayer(from: bubbleView)
        if style.backgroundColors.count > 1 {
            let gradient = CAGradientLayer()
            gradient.name = gradientLayerName
            gradient.colors = style.backgroundColors.map(\.cgColor)
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.frame = bubbleView.bounds
            bubbleView.layer.insertSublayer(gradient, at: 0)
            bubbleView.backgroundColor = style.backgroundColors.first
        } else {
            bubbleView.backgroundColor = style.backgroundColors.first
        }
        bubbleView.layer.borderWidth = style.borderColor == .clear ? 0 : 0.8
        bubbleView.layer.borderColor = style.borderColor.cgColor
        primaryLabels.forEach { $0.textColor = style.textColor }
        secondaryLabels.forEach { $0.textColor = style.secondaryTextColor }
    }

    static func removeGradientLayer(from bubbleView: UIView) {
        bubbleView.layer.sublayers?
            .filter { $0.name == gradientLayerName }
            .forEach { $0.removeFromSuperlayer() }
    }

    static func updateGradientFrame(in bubbleView: UIView) {
        bubbleView.layer.sublayers?
            .filter { $0.name == gradientLayerName }
            .forEach { $0.frame = bubbleView.bounds }
    }

    private static func defaultStyle(isMine: Bool) -> VirtualAssetChatBubbleRenderStyle {
        if isMine {
            return VirtualAssetChatBubbleRenderStyle(
                backgroundColors: [UIColor(RaverTheme.accent)],
                textColor: .white,
                secondaryTextColor: UIColor.white.withAlphaComponent(0.85),
                borderColor: .clear
            )
        }
        return VirtualAssetChatBubbleRenderStyle(
            backgroundColors: [UIColor(RaverTheme.card)],
            textColor: UIColor(RaverTheme.primaryText),
            secondaryTextColor: UIColor(RaverTheme.secondaryText),
            borderColor: .clear
        )
    }
}

struct VirtualAssetMedalShape: Shape {
    let style: String

    func path(in rect: CGRect) -> Path {
        switch style {
        case "ticket":
            return ticketPath(in: rect)
        case "ribbon":
            return ribbonPath(in: rect)
        case "hex":
            return hexPath(in: rect)
        case "slant", "neon_plate":
            return slantPath(in: rect)
        default:
            return Path(roundedRect: rect, cornerRadius: rect.height / 2)
        }
    }

    private func ticketPath(in rect: CGRect) -> Path {
        let corner = rect.height * 0.24
        let notch = rect.height * 0.18
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + corner), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notch))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + notch))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - corner, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - corner), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + notch))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }

    private func ribbonPath(in rect: CGRect) -> Path {
        let cut = min(rect.width * 0.08, rect.height * 0.34)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + cut, y: rect.minY), control: CGPoint(x: rect.minX - cut, y: rect.midY))
        path.closeSubpath()
        return path
    }

    private func hexPath(in rect: CGRect) -> Path {
        let inset = min(rect.width * 0.08, rect.height * 0.45)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }

    private func slantPath(in rect: CGRect) -> Path {
        let slant = min(rect.width * 0.08, rect.height * 0.42)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + slant, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct VirtualAssetBadgeShape: Shape {
    let style: String

    func path(in rect: CGRect) -> Path {
        switch style {
        case "diamond":
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
            return path
        case "hex":
            return polygonPath(in: rect, sides: 6, rotation: .pi / 6)
        case "octagon":
            return polygonPath(in: rect, sides: 8, rotation: .pi / 8)
        case "ticket":
            return VirtualAssetMedalShape(style: "ticket").path(in: rect)
        case "shield":
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.18))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY - rect.height * 0.22))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.22))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.18))
            path.closeSubpath()
            return path
        case "slant":
            return VirtualAssetMedalShape(style: "slant").path(in: rect)
        case "star":
            return starPath(in: rect, points: 5)
        case "burst":
            return starPath(in: rect, points: 8)
        case "capsule":
            return Path(roundedRect: rect, cornerRadius: rect.height * 0.34)
        default:
            return Path(ellipseIn: rect)
        }
    }

    private func polygonPath(in rect: CGRect, sides: Int, rotation: CGFloat) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<sides {
            let angle = CGFloat(index) / CGFloat(sides) * .pi * 2 + rotation - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func starPath(in rect: CGRect, points: Int) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.58
        var path = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(index) / CGFloat(points * 2) * .pi * 2 - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private struct AvatarFrameMetrics {
    let frameImageURL: String?
    let renderMode: String?
    let externalInset: CGFloat
    let minAvatarSize: CGFloat
    let fallbackGradientColors: [Color]
    let glowColor: Color
    let glowRadius: CGFloat
    let ringWidth: CGFloat
    let innerRingColor: Color

    init(asset: VirtualAssetDefinition?, colorScheme: ColorScheme) {
        guard let asset else {
            self.frameImageURL = nil
            self.renderMode = nil
            self.externalInset = 0
            self.minAvatarSize = .greatestFiniteMagnitude
            self.fallbackGradientColors = [.clear, .clear]
            self.glowColor = .clear
            self.glowRadius = 0
            self.ringWidth = 0
            self.innerRingColor = .clear
            return
        }
        let payload = VirtualAssetPayloadResolver.resolvedPayload(for: asset, colorScheme: colorScheme)
        let variantURLKey = colorScheme == .dark ? "darkVariantURL" : "lightVariantURL"
        self.frameImageURL = payload.string(variantURLKey) ?? payload.string("frameImageURL")
        self.renderMode = payload.string("renderMode")
        self.externalInset = max(2, min(8, abs(payload.insets("frameInsets").minimumValue)))
        self.minAvatarSize = CGFloat(payload.double("minAvatarSize") ?? 24)
        let colors = VirtualAssetColorParser.colors(from: payload.arrayStrings("gradientColors"))
        self.fallbackGradientColors = colors.isEmpty ? [RaverTheme.accent, Color.cyan] : colors
        self.glowColor = VirtualAssetColorParser.color(from: payload.string("glowColorHex"))
            ?? fallbackGradientColors.first
            ?? RaverTheme.accent
        self.glowRadius = CGFloat(payload.double("glowRadius") ?? 8)
        self.ringWidth = CGFloat(payload.double("ringWidth") ?? 2.5)
        self.innerRingColor = VirtualAssetColorParser.color(from: payload.string("innerRingColorHex")) ?? .white.opacity(0.5)
    }

    func shouldRender(for avatarSize: CGFloat) -> Bool {
        externalInset > 0 && avatarSize >= minAvatarSize
    }
}

private enum VirtualAssetPayloadResolver {
    static func resolvedPayload(
        for asset: VirtualAssetDefinition,
        colorScheme: ColorScheme
    ) -> [String: VirtualAssetJSONValue] {
        let key = colorScheme == .dark ? "darkVariant" : "lightVariant"
        return mergeVariant(asset.renderPayload, variantKey: key)
    }

    static func resolvedPayload(
        for asset: VirtualAssetDefinition,
        traitCollection: UITraitCollection
    ) -> [String: VirtualAssetJSONValue] {
        let key = traitCollection.userInterfaceStyle == .dark ? "darkVariant" : "lightVariant"
        return mergeVariant(asset.renderPayload, variantKey: key)
    }

    private static func mergeVariant(
        _ payload: [String: VirtualAssetJSONValue],
        variantKey: String
    ) -> [String: VirtualAssetJSONValue] {
        guard let variant = payload.object(variantKey) else { return payload }
        return payload.merging(variant) { _, variantValue in variantValue }
    }
}

private enum VirtualAssetColorParser {
    static func color(from raw: String?) -> Color? {
        uiColor(from: raw).map(Color.init)
    }

    static func colors(from rawValues: [String]?) -> [Color] {
        uiColors(from: rawValues).map(Color.init)
    }

    static func uiColors(from rawValues: [String]?, traitCollection: UITraitCollection? = nil) -> [UIColor] {
        rawValues?.compactMap { uiColor(from: $0, traitCollection: traitCollection) } ?? []
    }

    static func uiColor(from raw: String?, traitCollection: UITraitCollection? = nil) -> UIColor? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.hasPrefix("#") {
            return hexColor(raw)
        }
        if raw.lowercased().hasPrefix("rgba") || raw.lowercased().hasPrefix("rgb") {
            return rgbaColor(raw)
        }
        if raw.lowercased().hasPrefix("hsl") {
            return hslColor(raw)
        }
        return nil
    }

    static func hasReadableContrast(foreground: UIColor, background: UIColor) -> Bool {
        contrastRatio(foreground, background) >= 4.5
    }

    private static func hexColor(_ raw: String) -> UIColor? {
        var value = raw.replacingOccurrences(of: "#", with: "")
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6 || value.count == 8,
              let intValue = UInt64(value, radix: 16) else { return nil }

        let alpha: CGFloat
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        if value.count == 8 {
            alpha = CGFloat((intValue & 0xFF000000) >> 24) / 255
            red = CGFloat((intValue & 0x00FF0000) >> 16) / 255
            green = CGFloat((intValue & 0x0000FF00) >> 8) / 255
            blue = CGFloat(intValue & 0x000000FF) / 255
        } else {
            alpha = 1
            red = CGFloat((intValue & 0xFF0000) >> 16) / 255
            green = CGFloat((intValue & 0x00FF00) >> 8) / 255
            blue = CGFloat(intValue & 0x0000FF) / 255
        }
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func rgbaColor(_ raw: String) -> UIColor? {
        let numbers = raw
            .replacingOccurrences(of: "rgba", with: "")
            .replacingOccurrences(of: "rgb", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard numbers.count >= 3,
              let red = Double(numbers[0]),
              let green = Double(numbers[1]),
              let blue = Double(numbers[2]) else { return nil }
        let alpha = numbers.count > 3 ? (Double(numbers[3]) ?? 1) : 1
        return UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }

    private static func hslColor(_ raw: String) -> UIColor? {
        let values = raw
            .replacingOccurrences(of: "hsla", with: "")
            .replacingOccurrences(of: "hsl", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "") }
        guard values.count >= 3,
              let hue = Double(values[0]),
              let saturation = Double(values[1]),
              let lightness = Double(values[2]) else { return nil }
        let alpha = values.count > 3 ? (Double(values[3]) ?? 1) : 1
        return UIColor(hue: CGFloat((hue.truncatingRemainder(dividingBy: 360)) / 360), saturation: CGFloat(saturation / 100), brightness: CGFloat(lightness / 100), alpha: CGFloat(alpha))
    }

    private static func contrastRatio(_ lhs: UIColor, _ rhs: UIColor) -> CGFloat {
        let lhsLum = relativeLuminance(lhs)
        let rhsLum = relativeLuminance(rhs)
        return (max(lhsLum, rhsLum) + 0.05) / (min(lhsLum, rhsLum) + 0.05)
    }

    private static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func convert(_ component: CGFloat) -> CGFloat {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * convert(red) + 0.7152 * convert(green) + 0.0722 * convert(blue)
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

    func int(_ key: String) -> Int? {
        double(key).map(Int.init)
    }

    func bool(_ key: String) -> Bool? {
        guard let value = self[key] else { return nil }
        if case .bool(let bool) = value { return bool }
        if case .string(let string) = value { return Bool(string) }
        return nil
    }

    func object(_ key: String) -> [String: VirtualAssetJSONValue]? {
        self[key]?.objectValue
    }

    func arrayStrings(_ key: String) -> [String]? {
        guard let value = self[key], case .array(let array) = value else { return nil }
        return array.compactMap(\.stringValue)
    }

    func insets(_ key: String) -> EdgeInsetValues {
        let object = object(key) ?? [:]
        return EdgeInsetValues(
            top: object.double("top") ?? 0,
            left: object.double("left") ?? 0,
            bottom: object.double("bottom") ?? 0,
            right: object.double("right") ?? 0
        )
    }
}

private struct EdgeInsetValues: Hashable {
    var top: Double
    var left: Double
    var bottom: Double
    var right: Double

    var minimumValue: Double {
        [top, left, bottom, right].min() ?? 0
    }
}
