import SwiftUI

struct DiscoverRecommendEventsRootView: View {
    @EnvironmentObject private var appContainer: AppContainer
    var onHorizontalDragStateChanged: ((Bool) -> Void)? = nil
    var onRequestMoveToNextDiscoverSection: (() -> Void)? = nil

    var body: some View {
        RecommendEventsModuleView(
            viewModel: RecommendEventsViewModel(repository: appContainer.discoverEventsRepository),
            onHorizontalDragStateChanged: onHorizontalDragStateChanged,
            onRequestMoveToNextDiscoverSection: onRequestMoveToNextDiscoverSection
        )
    }
}

struct RecommendEventsModuleView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight
    @StateObject private var viewModel: RecommendEventsViewModel

    private let onHorizontalDragStateChanged: ((Bool) -> Void)?
    private let onRequestMoveToNextDiscoverSection: (() -> Void)?
    private let cardCornerRadius: CGFloat = 28

    @State private var isHorizontalDragging = false
    @State private var scrollPositionID: String?

    init(
        viewModel: RecommendEventsViewModel,
        onHorizontalDragStateChanged: ((Bool) -> Void)? = nil,
        onRequestMoveToNextDiscoverSection: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onHorizontalDragStateChanged = onHorizontalDragStateChanged
        self.onRequestMoveToNextDiscoverSection = onRequestMoveToNextDiscoverSection
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView(L("正在生成推荐...", "Generating recommendations..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.events.isEmpty {
                    ContentUnavailableView(
                        L("暂无可推荐活动", "No Recommended Events"),
                        systemImage: "sparkles.tv"
                    )
                } else {
                    recommendationPager
                }
            }

            topSearchRow
                .padding(.horizontal, 16)
                .padding(.top, topSearchContentInset)
                .zIndex(8)
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.reload(isLoggedIn: appState.session != nil)
        }
        .task(id: appState.session != nil) {
            await viewModel.reloadMarkedState(isLoggedIn: appState.session != nil)
        }
        .onDisappear {
            notifyHorizontalDragging(false)
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var topSearchContentInset: CGFloat {
        14
    }

    private var topSearchRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer(minLength: 0)
            Button {
                discoverPush(.searchInput(domain: .events, initialQuery: ""))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(searchFieldIconColor)

                    Text(L("寻找你的现场记忆", "Find your live memories"))
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .foregroundStyle(searchFieldPlaceholderColor)
                }
                .padding(.horizontal, 12)
                .frame(width: topSearchFieldWidth, height: 34, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(searchFieldGlassTintColor)
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(searchFieldBorderColor, lineWidth: 0.8)
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.34), lineWidth: 0.6)
                        .blur(radius: 0.2)
                        .mask(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: searchFieldShadowColor, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .frame(height: 40, alignment: .center)
    }

    private var topSearchFieldWidth: CGFloat {
        min(max(UIScreen.main.bounds.width * 0.34, 132), 168) + 20
    }

    private var searchFieldIconColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.84) : Color.black.opacity(0.68)
    }

    private var searchFieldPlaceholderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.56) : Color.black.opacity(0.44)
    }

    private var searchFieldBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.26)
    }

    private var searchFieldGlassTintColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.035)
            : Color.white.opacity(0.10)
    }

    private var searchFieldShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.12)
            : Color.black.opacity(0.08)
    }

    private var recommendationPager: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let horizontalInset: CGFloat = 16  // 从 44 改为 16，卡片更宽
            let cardSpacing: CGFloat = 10
            let cardWidth = size.width - horizontalInset * 2
            let cardHeight = size.height          // 直接用全部高度，padding 移到外层处理

            ScrollView(.horizontal) {
                HStack(spacing: cardSpacing) {
                    ForEach(viewModel.events) { event in
                        GeometryReader { proxy in
                                // 直接在这里计算视差偏移，不 clamp，和原例子保持一致
                                let minX = min(
                                    proxy.frame(in: .scrollView(axis: .horizontal)).minX * 1.4,
                                    proxy.size.width * 1.4
                                )
                                let parallaxOffset = -minX + 20

                                recommendationCard(event, parallaxOffset: parallaxOffset)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                            .frame(width: cardWidth, height: cardHeight)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content.scaleEffect(phase.isIdentity ? 1 : 0.95)
                            }
                    }
                }
                .padding(.horizontal, horizontalInset)
                .scrollTargetLayout()
                .frame(height: size.height, alignment: .top)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrollPositionID)
            .onAppear {
                if scrollPositionID == nil {
                    scrollPositionID = viewModel.events.first?.id
                }
            }
            .onChange(of: viewModel.events) { _, _ in
                scrollPositionID = viewModel.events.first?.id
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                        if isHorizontal { notifyHorizontalDragging(true) }
                    }
                    .onEnded { value in handleRecommendationDragEnded(value) }
            )
            .overlay(alignment: .bottom) {
                pageIndicator
//                    .padding(.bottom, tabBarReservedHeight - 14)
                    .padding(.bottom, 10)
            }
        }
        // ✅ padding 放在 GeometryReader 外面，不影响 size 计算
        .padding(.top, 10)
        .padding(.bottom, tabBarReservedHeight + 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func recommendationCard(_ event: WebEvent, parallaxOffset: CGFloat = 0) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        // 视差图片的额外出血宽度，决定了最大视差量
//        let horizontalBleed: CGFloat = 120
//        let clampedOffset = min(max(parallaxOffset, -horizontalBleed), horizontalBleed)

        return Button {
            appPush(.eventDetail(eventID: event.id))
        } label: {
            ZStack(alignment: .bottomLeading) {
                // 1. 背景兜底色
                recommendationFallbackCover
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 2. 视差封面图：用 GeometryReader 撑满卡片再做偏移
                GeometryReader { proxy in
                    ImageLoaderView(
                        urlString: event.coverAssetURL,
                        resizingMode: .fill,
                        showsIndicator: false,
                        showsFallback: false,
                        contentOffset: CGSize(width: parallaxOffset, height: 0)
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)  // 父容器锁定可见区域
                    .clipped()                                                    // 裁掉超出部分
                    .allowsHitTesting(false)
                }

                // 3. 氛围遮罩：铺满，不受视差偏移影响
                recommendationAtmosphereOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 4. 文字内容：固定在底部，宽度由卡片决定
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 8) {
                        recommendationPill(
                            title: EventTypeOption.displayText(for: event.eventType),
                            background: Color.white.opacity(0.15)
                        )
                        let visualStatus = EventVisualStatus.resolve(event: event)
                        recommendationPill(
                            title: visualStatus.title,
                            background: visualStatus.badgeBackground
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13, weight: .medium))
                        Text(recommendationLocationText(for: event))
                            .lineLimit(2)
                            .minimumScaleFactor(0.62)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .medium))
                        Text(recommendationDateText(for: event))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .padding(.bottom, 1)

                    recommendationHeadline(event.name)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 15)
                // ✅ 不设 maxWidth: .infinity，让 ZStack 的 alignment: .bottomLeading 控制对齐
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(cardShape)           // clipShape 在最外层，视差出血被裁掉
            .overlay(cardShape.stroke(Color.white.opacity(0.10), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.10), radius: 13, x: 0, y: 6)
            .contentShape(cardShape)
        }
        .buttonStyle(.plain)
    }

    private var recommendationFallbackCover: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.45, blue: 0.42),
                Color(red: 0.04, green: 0.12, blue: 0.16),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var recommendationAtmosphereOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.0), location: 0.0),
                .init(color: Color.black.opacity(0.0), location: 0.6),
                .init(color: Color.black.opacity(0.65), location: 0.8),
                .init(color: Color.black.opacity(0.88), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var currentIndex: Int {
        guard let id = scrollPositionID else { return 0 }
        return viewModel.events.firstIndex(where: { $0.id == id }) ?? 0
    }

    private var pageIndicator: some View {
        let total = viewModel.events.count
        let current = currentIndex

        return HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { idx in
                Capsule()
                    .fill(
                        idx == current
                            ? Color(red: 0.16, green: 0.95, blue: 0.92)
                            : Color.white.opacity(0.30)
                    )
                    .frame(width: idx == current ? 28 : 5, height: 3)
                    .shadow(
                        color: idx == current
                            ? Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.9)
                            : .clear,
                        radius: 6,
                        x: 0,
                        y: 0
                    )
                    .shadow(
                        color: idx == current
                            ? Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.5)
                            : .clear,
                        radius: 12,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.32, dampingFraction: 0.68), value: current)
            }
        }
    }

    private func recommendationHeadline(_ text: String) -> some View {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = isChineseUI ? clean : clean.uppercased()

        return ViewThatFits(in: .vertical) {
            recommendationHeadlineText(display, size: 40, tracking: isChineseUI ? 0.25 : 0.15)
            recommendationHeadlineText(display, size: 34, tracking: isChineseUI ? 0.2 : 0.12)
            recommendationHeadlineText(display, size: 30, tracking: isChineseUI ? 0.15 : 0.1)
            recommendationHeadlineText(display, size: 26, tracking: isChineseUI ? 0.1 : 0.08)
            recommendationHeadlineText(display, size: 22, tracking: 0.06)
        }
        .foregroundStyle(Color.white)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recommendationHeadlineText(_ text: String, size: CGFloat, tracking: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold).leading(.tight))
            .lineLimit(3)
            .minimumScaleFactor(0.34)
            .allowsTightening(true)
            .lineSpacing(-3)
            .tracking(tracking)
    }

    private var isChineseUI: Bool {
        switch AppLanguagePreference.current.effectiveLanguage {
        case .zh:
            return true
        case .en:
            return false
        case .system:
            let first = Locale.preferredLanguages.first?.lowercased() ?? ""
            return first.hasPrefix("zh")
        }
    }

    private func recommendationPill(title: String, background: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
    }

    private func recommendationLocationText(for event: WebEvent) -> String {
        if !event.summaryLocation.isEmpty {
            return event.summaryLocation
        }
        return L("地点待定", "Location TBA")
    }

    private func recommendationDateText(for event: WebEvent) -> String {
        event.startDate.appLocalizedDateRangeText(to: event.endDate)
    }

    private func notifyHorizontalDragging(_ isDragging: Bool) {
        guard isHorizontalDragging != isDragging else { return }
        isHorizontalDragging = isDragging
        onHorizontalDragStateChanged?(isDragging)
    }

    private func handleRecommendationDragEnded(_ value: DragGesture.Value) {
        notifyHorizontalDragging(false)

        guard currentIndex == viewModel.events.count - 1 else { return }
        guard viewModel.events.count > 1 else { return }
        guard abs(value.translation.width) > abs(value.translation.height) else { return }

        let didPullTowardNextDiscoverSection = value.translation.width < -48
            || value.predictedEndTranslation.width < -90

        if didPullTowardNextDiscoverSection {
            onRequestMoveToNextDiscoverSection?()
        }
    }
}

#Preview {
    RecommendEventsPreviewHost()
}

@MainActor
private struct RecommendEventsPreviewHost: View {
    @StateObject private var appContainer = AppContainer()
    @StateObject private var appState: AppState

    init() {
        let container = AppContainer()
        _appContainer = StateObject(wrappedValue: container)
        _appState = StateObject(wrappedValue: AppState(service: container.socialService))
    }

    var body: some View {
        DiscoverRecommendEventsRootView()
            .environmentObject(appContainer)
            .environmentObject(appState)
            .environment(\.raverTabBarReservedHeight, 88)
            .background(RaverTheme.background)
    }
}
