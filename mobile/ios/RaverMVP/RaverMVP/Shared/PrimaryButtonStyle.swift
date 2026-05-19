import SwiftUI

struct RaverTabBarReservedHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var raverTabBarReservedHeight: CGFloat {
        get { self[RaverTabBarReservedHeightKey.self] }
        set { self[RaverTabBarReservedHeightKey.self] = newValue }
    }
}

private struct RaverTabBarBottomPaddingModifier: ViewModifier {
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight

    let extra: CGFloat
    let minBottom: CGFloat?

    func body(content: Content) -> some View {
        let resolved = max(0, tabBarReservedHeight) + extra
        let bottom = max(minBottom ?? 0, resolved)
        content.padding(.bottom, bottom)
    }
}

extension View {
    func raverTabBarBottomPadding(_ extra: CGFloat = 0, min minBottom: CGFloat? = nil) -> some View {
        modifier(RaverTabBarBottomPaddingModifier(extra: extra, minBottom: minBottom))
    }
}

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
