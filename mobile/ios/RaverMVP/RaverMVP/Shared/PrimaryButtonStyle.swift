import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(RaverTheme.accent.opacity(configuration.isPressed ? 0.75 : 1.0))
            )
    }
}

struct CompactPrimaryButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 8
    var cornerRadius: CGFloat = 10
    var enabledOpacity: CGFloat = 1.0
    var disabledOpacity: CGFloat = 0.45

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RaverTheme.accent.opacity(configuration.isPressed ? 0.75 : 1.0))
            )
            .opacity(isEnabled ? enabledOpacity : disabledOpacity)
    }
}
