import SwiftUI

struct MediaPreviewOverlayButton: View {
    var size: CGFloat = 26
    var iconSize: CGFloat = 12
    var backgroundOpacity: Double = 0.58
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.black.opacity(backgroundOpacity), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    @ViewBuilder
    func mediaPreviewOverlay(
        isVisible: Bool = true,
        alignment: Alignment = .topTrailing,
        padding: CGFloat = 8,
        buttonSize: CGFloat = 26,
        iconSize: CGFloat = 12,
        action: @escaping () -> Void
    ) -> some View {
        overlay(alignment: alignment) {
            if isVisible {
                MediaPreviewOverlayButton(
                    size: buttonSize,
                    iconSize: iconSize,
                    action: action
                )
                .padding(padding)
            }
        }
    }
}
