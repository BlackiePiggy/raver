import SwiftUI

enum RaverNavigationCircleButtonStyle {
    case glass
    case dimmed
    case immersiveAdaptive
}

struct RaverNavigationCircleIconButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemName: String
    let style: RaverNavigationCircleButtonStyle
    let action: () -> Void

    var frameSize: CGFloat = 38
    var font: Font = .system(size: 15, weight: .bold)

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(font)
                .foregroundStyle(foregroundColor)
                .frame(width: frameSize, height: frameSize)
                .background(backgroundView)
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .glass:
            return .white
        case .dimmed:
            return colorScheme == .dark ? .white : Color.black.opacity(0.84)
        case .immersiveAdaptive:
            return colorScheme == .dark ? .white : Color.black.opacity(0.84)
        }
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
                .fill(
                    colorScheme == .dark
                        ? Color.black.opacity(0.36)
                        : Color.white.opacity(0.88)
                )
                .overlay {
                    if colorScheme != .dark {
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    }
                }
        case .immersiveAdaptive:
            if colorScheme == .dark {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
            } else {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
            }
        }
    }
}

struct RaverImmersiveFloatingTopBar: View {
    let onBack: () -> Void
    var buttonStyle: RaverNavigationCircleButtonStyle = .immersiveAdaptive
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            RaverNavigationCircleIconButton(
                systemName: "chevron.left",
                style: buttonStyle,
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
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let onBack: () -> Void
    var trailing: AnyView? = nil

    var body: some View {
        let safeTop = topSafeAreaInset()

        ZStack(alignment: .top) {
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            ZStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor)
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

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black.opacity(1),
                Color.black.opacity(0.95),
                Color.black.opacity(0.85),
                Color.black.opacity(0.0)
            ]
        }
        return [
            Color.white.opacity(0.98),
            Color.white.opacity(0.94),
            Color.white.opacity(0.82),
            Color.white.opacity(0.0)
        ]
    }

    private var titleColor: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.88)
    }

    static var contentTopSpacing: CGFloat {
        50
    }
}

struct RaverPinnedTitleOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let opacity: CGFloat

    var body: some View {
        let safeTop = topSafeAreaInset()

        ZStack(alignment: .top) {
            Rectangle()
                .fill(backgroundColor)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            backgroundColor,
                            backgroundColor.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                    .offset(y: 20)
                }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .frame(width: 176)
                .padding(.top, safeTop + 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: safeTop + 44, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : RaverTheme.background
    }

    private var titleColor: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.88)
    }
}

struct RaverImmersiveDetailPagerConfiguration {
    var heroHeight: CGFloat = 360
    var tabBarOverlayHeight: CGFloat = 52
    var pinnedTopBarHeight: CGFloat = 44
    var titleRevealLead: CGFloat = 8
    var titleRevealDistance: CGFloat = 20
    var backgroundColor: Color = RaverTheme.background
}

struct RaverImmersiveDetailPagerContext<TabID: Hashable> {
    let detailTopInset: CGFloat
    let coordinateSpaceName: (TabID) -> String
}

struct RaverImmersiveDetailOffsetMarker<TabID: Hashable>: View {
    let tabID: TabID
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: RaverImmersiveDetailVerticalOffsetPreferenceKey.self,
                    value: [AnyHashable(tabID): max(0, -proxy.frame(in: .named(coordinateSpaceName)).minY)]
                )
        }
        .frame(height: 0)
    }
}

struct RaverImmersiveDetailPagerChrome<TabID: Hashable, Hero: View, TabBar: View, Content: View>: View {
    let title: String
    let tabs: [TabID]
    let selectedTab: TabID
    @Binding var pageProgress: CGFloat
    let namespace: String
    let configuration: RaverImmersiveDetailPagerConfiguration

    private let hero: Hero
    private let tabBar: TabBar
    private let contentBuilder: (RaverImmersiveDetailPagerContext<TabID>) -> Content

    @State private var pageVerticalOffsets: [AnyHashable: CGFloat] = [:]

    init(
        title: String,
        tabs: [TabID],
        selectedTab: TabID,
        pageProgress: Binding<CGFloat>,
        namespace: String,
        configuration: RaverImmersiveDetailPagerConfiguration = .init(),
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder tabBar: () -> TabBar,
        @ViewBuilder content: @escaping (RaverImmersiveDetailPagerContext<TabID>) -> Content
    ) {
        self.title = title
        self.tabs = tabs
        self.selectedTab = selectedTab
        self._pageProgress = pageProgress
        self.namespace = namespace
        self.configuration = configuration
        self.hero = hero()
        self.tabBar = tabBar()
        self.contentBuilder = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            contentBuilder(context)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            hero
                .offset(y: -clampedHeroOffset)
                .zIndex(1)

            tabBar
                .offset(y: tabBarTopOffset)
                .zIndex(2)

            RaverPinnedTitleOverlay(
                title: title,
                opacity: topOverlayOpacity
            )
            .zIndex(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .top)
        .background(configuration.backgroundColor)
        .onPreferenceChange(RaverImmersiveDetailVerticalOffsetPreferenceKey.self) { values in
            pageVerticalOffsets.merge(values, uniquingKeysWith: { _, new in new })
        }
    }

    private var context: RaverImmersiveDetailPagerContext<TabID> {
        RaverImmersiveDetailPagerContext(
            detailTopInset: configuration.heroHeight + configuration.tabBarOverlayHeight,
            coordinateSpaceName: coordinateSpaceName(for:)
        )
    }

    private var activeVerticalOffset: CGFloat {
        guard !tabs.isEmpty else { return 0 }
        let clampedProgress = min(max(pageProgress, 0), CGFloat(max(0, tabs.count - 1)))
        let lowerIndex = Int(floor(clampedProgress))
        let upperIndex = Int(ceil(clampedProgress))
        let lowerOffset = pageVerticalOffsets[AnyHashable(tabs[lowerIndex])] ?? 0
        let upperOffset = pageVerticalOffsets[AnyHashable(tabs[upperIndex])] ?? lowerOffset

        guard lowerIndex != upperIndex else { return lowerOffset }
        let fraction = clampedProgress - CGFloat(lowerIndex)
        return lowerOffset + (upperOffset - lowerOffset) * fraction
    }

    private var clampedHeroOffset: CGFloat {
        min(max(activeVerticalOffset, 0), configuration.heroHeight)
    }

    private var tabBarTopOffset: CGFloat {
        max(pinnedTabTopLimit, configuration.heroHeight - clampedHeroOffset)
    }

    private var pinnedTabTopLimit: CGFloat {
        topSafeAreaInset() + configuration.pinnedTopBarHeight
    }

    private var topOverlayOpacity: CGFloat {
        let pinStart = max(0, configuration.heroHeight - pinnedTabTopLimit)
        return min(
            max(
                (activeVerticalOffset - pinStart + configuration.titleRevealLead) / configuration.titleRevealDistance,
                0
            ),
            1
        )
    }

    private func coordinateSpaceName(for tab: TabID) -> String {
        guard let index = tabs.firstIndex(where: { AnyHashable($0) == AnyHashable(tab) }) else {
            return "\(namespace)-unknown"
        }
        return "\(namespace)-\(index)"
    }
}

private struct RaverImmersiveDetailVerticalOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGFloat] = [:]

    static func reduce(value: inout [AnyHashable: CGFloat], nextValue: () -> [AnyHashable: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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
        buttonStyle: RaverNavigationCircleButtonStyle = .immersiveAdaptive,
        trailing: AnyView? = nil,
        onBack: @escaping () -> Void
    ) -> some View {
        modifier(
            RaverHiddenNavigationOverlayModifier(
                overlay: AnyView(
                    RaverImmersiveFloatingTopBar(
                        onBack: onBack,
                        buttonStyle: buttonStyle,
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
            .toolbar(.visible, for: .navigationBar)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .tint(RaverTheme.primaryText)
    }
}

private struct RaverHiddenNavigationOverlayModifier: ViewModifier {
    let overlay: AnyView

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            overlay
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
