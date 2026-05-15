import SwiftUI

enum ScreenStatusBannerStyle {
    case success
    case info
    case warning
    case error

    var background: Color {
        switch self {
        case .success:
            return Color(red: 0.08, green: 0.56, blue: 0.27)
        case .info:
            return RaverTheme.card
        case .warning:
            return Color.orange.opacity(0.12)
        case .error:
            return Color.red.opacity(0.12)
        }
    }

    var border: Color {
        switch self {
        case .success:
            return Color(red: 0.15, green: 0.74, blue: 0.38)
        case .info:
            return RaverTheme.cardBorder
        case .warning:
            return Color.orange.opacity(0.35)
        case .error:
            return Color.red.opacity(0.35)
        }
    }

    var foreground: Color {
        switch self {
        case .success:
            return Color.white
        case .info:
            return RaverTheme.secondaryText
        case .warning:
            return Color.orange
        case .error:
            return Color.red
        }
    }

    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle"
        case .info:
            return "arrow.triangle.2.circlepath"
        case .warning:
            return "wifi.exclamationmark"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

struct ScreenStatusBanner: View {
    let message: String
    var style: ScreenStatusBannerStyle = .info
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: style.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.foreground)

            Text(message)
                .font(.footnote)
                .foregroundStyle(style == .success ? Color.white : RaverTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(style.foreground)
                    .buttonStyle(.plain)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(style == .success ? Color.white.opacity(0.82) : RaverTheme.secondaryText)
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LT("关闭", "Close", "閉じる"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(style.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
    }
}

struct InlineLoadingBadge: View {
    var title: String = LT("正在更新", "Updating", "更新中")

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .font(.footnote)
        }
        .foregroundStyle(RaverTheme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(RaverTheme.card)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct FormStatusMessage: View {
    let message: String
    var style: ScreenStatusBannerStyle = .error

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: style.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.foreground)

            Text(message)
                .font(.footnote)
                .foregroundStyle(RaverTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(style.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
    }
}
