import SwiftUI

struct DiscoverRecommendEventsRootView: View {
    @EnvironmentObject private var appContainer: AppContainer
    var onHorizontalDragStateChanged: ((Bool) -> Void)? = nil
    var onRequestMoveToNextDiscoverSection: (() -> Void)? = nil
    var isActive: Bool = true

    var body: some View {
        RecommendEventsModuleView(
            viewModel: RecommendEventsViewModel(
                recommendationRepository: appContainer.eventRecommendationRepository,
                listRepository: appContainer.eventListRepository,
                checkinRepository: appContainer.eventCheckinRepository
            ),
            isActive: isActive,
            onHorizontalDragStateChanged: onHorizontalDragStateChanged,
            onRequestMoveToNextDiscoverSection: onRequestMoveToNextDiscoverSection
        )
    }
}

struct RecommendEventsModuleView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight
    @StateObject private var viewModel: RecommendEventsViewModel
    @StateObject private var guidanceCenter = AppGuidanceCenter.shared

    private let onHorizontalDragStateChanged: ((Bool) -> Void)?
    private let onRequestMoveToNextDiscoverSection: (() -> Void)?
    private let cardCornerRadius: CGFloat = 28
    private let recommendGuidancePolicy = AppGuidanceRuntime.recommendEventsFirstRunPolicy

    @State private var isHorizontalDragging = false
    @State private var scrollPositionID: String?
    @State private var showRecommendGuide = false
    @State private var guideStep: RecommendEventsGuidanceStep = .tap
    @State private var guideHandOffset: CGFloat = 0
    @State private var hasTriggeredInitialLoad = false

    private let isActive: Bool
    init(
        viewModel: RecommendEventsViewModel,
        isActive: Bool = true,
        onHorizontalDragStateChanged: ((Bool) -> Void)? = nil,
        onRequestMoveToNextDiscoverSection: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.isActive = isActive
        self.onHorizontalDragStateChanged = onHorizontalDragStateChanged
        self.onRequestMoveToNextDiscoverSection = onRequestMoveToNextDiscoverSection
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if viewModel.phase == .idle || viewModel.phase == .initialLoading {
                    FeedSkeletonView(count: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else if case .failure(let message) = viewModel.phase {
                    ScreenErrorCard(
                        title: LT("推荐活动加载失败", "Recommended Events Failed to Load", "おすすめイベントの読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await viewModel.reload(sessionUserID: appState.session?.user.id) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if case .offline(let message) = viewModel.phase {
                    ScreenErrorCard(
                        title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                        message: message
                    ) {
                        Task { await viewModel.reload(sessionUserID: appState.session?.user.id) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.events.isEmpty {
                    ContentUnavailableView(
                        LT("暂无可推荐活动", "No Recommended Events", "おすすめイベントはまだありません"),
                        systemImage: "sparkles.tv"
                    )
                } else {
                    recommendationPager
                }
            }

            if showRecommendGuide && !viewModel.events.isEmpty {
                AppGuidanceOverlay(
                    step: guideStep.guidanceStep,
                    handOffset: guideHandOffset,
                    onPrimary: advanceGuide,
                    onDismiss: dismissGuide
                )
                .transition(.opacity)
                .zIndex(12)
            }

            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新推荐", "Updating recommendations", "おすすめを更新中"))
                    }
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
                        ) {
                            Task { await viewModel.reload(sessionUserID: appState.session?.user.id) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .zIndex(9)
            }
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presentGuideIfNeeded()
        }
        .task {
            await triggerInitialLoadIfNeeded()
        }
        .onChange(of: isActive) { _, _ in
            Task { await triggerInitialLoadIfNeeded() }
        }
        .onChange(of: viewModel.events.count) { _, _ in
            presentGuideIfNeeded()
        }
        .onChange(of: appState.shouldPresentPostRegistrationRecommendGuide) { _, _ in
            presentGuideIfNeeded()
        }
        .onChange(of: appState.isRegistrationOnboardingActive) { _, isActive in
            guard !isActive else { return }
            presentGuideIfNeeded()
        }
        .task(id: appState.session?.user.id) {
            guard isActive else { return }
            await viewModel.reloadMarkedState(isLoggedIn: appState.session != nil)
        }
        .onDisappear {
            notifyHorizontalDragging(false)
        }
    }

    @MainActor
    private func triggerInitialLoadIfNeeded() async {
        guard isActive else { return }
        guard !hasTriggeredInitialLoad else { return }
        hasTriggeredInitialLoad = true
        await viewModel.loadIfNeeded(sessionUserID: appState.session?.user.id)
        presentGuideIfNeeded()
    }

    private var recommendationPager: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let horizontalInset: CGFloat = 16  // 从 44 改为 16，卡片更宽
            let cardSpacing: CGFloat = 10
            let cardWidth = max(size.width - horizontalInset * 2, 1)
            let cardHeight = max(size.height, 1)          // 直接用全部高度，padding 移到外层处理

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
                                    .frame(width: max(proxy.size.width, 1), height: max(proxy.size.height, 1))
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
                    .frame(width: max(proxy.size.width, 1), height: max(proxy.size.height, 1))  // 父容器锁定可见区域
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
                        recommendationStatusPill(visualStatus)
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
        case .en, .ja:
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

    private func recommendationStatusPill(_ status: EventVisualStatus) -> some View {
        HStack(spacing: 6) {
            if status == .ongoing {
                LiveActivityBarsView(
                    color: Color.white.opacity(0.98),
                    barWidth: 2.6,
                    minHeight: 3,
                    maxHeight: 10,
                    cornerRadius: 1.3
                )
                .frame(width: 13, height: 10)
            }

            Text(status.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.badgeBackground, in: Capsule())
    }

    private func recommendationLocationText(for event: WebEvent) -> String {
        if !event.summaryLocation.isEmpty {
            return event.summaryLocation
        }
        return LT("地点待定", "Location TBA", "場所未定")
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
        if showRecommendGuide {
            dismissGuide()
        }
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

    private func presentGuideIfNeeded() {
        guard !appState.isRegistrationOnboardingActive else { return }
        guard !viewModel.events.isEmpty else { return }
        guard !showRecommendGuide else { return }
        let userID = appState.session?.user.id
        let shouldPresentForPolicy = guidanceCenter.shouldPresent(
            .recommendEventsFirstRun,
            policy: recommendGuidancePolicy,
            userID: userID
        )
        guard appState.shouldPresentPostRegistrationRecommendGuide || shouldPresentForPolicy else { return }
        guidanceCenter.markPresented(.recommendEventsFirstRun, policy: recommendGuidancePolicy, userID: userID)
        appState.consumePostRegistrationRecommendGuideRequest()
        guideStep = .tap
        guideHandOffset = 0
        withAnimation(.easeInOut(duration: 0.22)) {
            showRecommendGuide = true
        }
    }

    private func advanceGuide() {
        switch guideStep {
        case .tap:
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                guideStep = .swipe
            }
            startSwipeHintAnimation()
        case .swipe:
            dismissGuide()
        }
    }

    private func dismissGuide() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showRecommendGuide = false
        }
    }

    private func startSwipeHintAnimation() {
        guideHandOffset = 34
        withAnimation(
            .easeInOut(duration: 0.86)
                .repeatCount(3, autoreverses: true)
        ) {
            guideHandOffset = -52
        }
    }
}

private enum RecommendEventsGuidanceStep {
    case tap
    case swipe

    var guidanceStep: AppGuidanceStep {
        switch self {
        case .tap:
            return AppGuidanceStep(
                title: LT("点一下卡片", "Tap a card", "カードをタップ"),
                message: LT("每张推荐活动卡片都可以点击，进入活动详情。", "Every recommended event card opens its detail page.", "おすすめイベントのカードをタップすると詳細を開けます。"),
                buttonTitle: LT("知道了，下一步", "Got it, next", "次へ"),
                iconName: "hand.tap.fill",
                buttonIconName: "arrow.right",
                visualKind: .tap
            )
        case .swipe:
            return AppGuidanceStep(
                title: LT("向左滑动卡片", "Swipe left", "左へスワイプ"),
                message: LT("在卡片上向左滑，可以查看下一张推荐。", "Swipe left on a card to see the next pick.", "カードを左へスワイプすると次のおすすめを見られます。"),
                buttonTitle: LT("开始探索", "Start exploring", "探索を始める"),
                iconName: "hand.draw.fill",
                buttonIconName: "sparkles",
                visualKind: .swipeLeft
            )
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
