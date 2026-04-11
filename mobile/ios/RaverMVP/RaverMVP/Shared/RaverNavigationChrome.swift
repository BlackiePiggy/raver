import SwiftUI

enum RaverNavigationCircleButtonStyle {
    case glass
    case dimmed
}

struct RaverNavigationCircleIconButton: View {
    let systemName: String
    let style: RaverNavigationCircleButtonStyle
    let action: () -> Void

    var frameSize: CGFloat = 38
    var font: Font = .system(size: 15, weight: .bold)

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(font)
                .foregroundStyle(Color.white)
                .frame(width: frameSize, height: frameSize)
                .background(backgroundView)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .glass:
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        case .dimmed:
            Circle()
                .fill(Color.black.opacity(0.36))
        }
    }
}

struct RaverImmersiveFloatingTopBar: View {
    let onBack: () -> Void
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            RaverNavigationCircleIconButton(
                systemName: "chevron.left",
                style: .glass,
                action: onBack
            )

            Spacer()

            if let trailing {
                trailing
            }
        }
        .padding(.horizontal, 12)
//        .padding(.top, topSafeAreaInset())
        .zIndex(10)
    }
}

struct RaverGradientMaskedTopBar: View {
    let title: String
    let onBack: () -> Void
    var trailing: AnyView? = nil

    var body: some View {
        let safeTop = topSafeAreaInset()

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color.black.opacity(1),
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            ZStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack {
                    RaverNavigationCircleIconButton(
                        systemName: "chevron.left",
                        style: .dimmed,
                        action: onBack,
                        frameSize: 34,
                        font: .headline.weight(.semibold)
                    )

                    Spacer()

                    if let trailing {
                        trailing
                    } else {
                        Color.clear
                            .frame(width: 34, height: 34)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, safeTop + 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: safeTop + 70, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    static var contentTopSpacing: CGFloat {
        50
    }
}

extension View {
    func raverSystemNavigation(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline
    ) -> some View {
        modifier(
            RaverSystemNavigationModifier(
                title: title,
                displayMode: displayMode
            )
        )
    }

    func raverImmersiveFloatingNavigationChrome(
        trailing: AnyView? = nil,
        onBack: @escaping () -> Void
    ) -> some View {
        modifier(
            RaverHiddenNavigationOverlayModifier(
                overlay: AnyView(
                    RaverImmersiveFloatingTopBar(
                        onBack: onBack,
                        trailing: trailing
                    )
                )
            )
        )
    }

    func raverGradientNavigationChrome(
        title: String,
        trailing: AnyView? = nil,
        onBack: @escaping () -> Void
    ) -> some View {
        modifier(
            RaverGradientNavigationModifier(
                title: title,
                trailing: trailing,
                onBack: onBack
            )
        )
    }

    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

private struct RaverSystemNavigationModifier: ViewModifier {
    let title: String
    let displayMode: NavigationBarItem.TitleDisplayMode

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
    }
}

private struct RaverHiddenNavigationOverlayModifier: ViewModifier {
    let overlay: AnyView

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                overlay
            }
    }
}

private struct RaverGradientNavigationModifier: ViewModifier {
    let title: String
    let trailing: AnyView?
    let onBack: () -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: RaverGradientMaskedTopBar.contentTopSpacing)
            }
            .modifier(
                RaverHiddenNavigationOverlayModifier(
                    overlay: AnyView(
                        RaverGradientMaskedTopBar(
                            title: title,
                            onBack: onBack,
                            trailing: trailing
                        )
                    )
                )
            )
    }
}
