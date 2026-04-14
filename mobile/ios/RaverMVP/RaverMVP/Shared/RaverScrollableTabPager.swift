import SwiftUI
import Foundation

struct RaverScrollableTabItem<ID: Hashable>: Identifiable, Hashable {
    let id: ID
    let title: String
}

struct RaverScrollableTabBar<ID: Hashable>: View {
    private struct TabLayout {
        var size: CGSize = .zero
        var minX: CGFloat = .zero
    }

    @Binding private var selection: ID

    private let items: [RaverScrollableTabItem<ID>]
    private let progress: CGFloat
    private let onSelect: ((ID) -> Void)?
    private let tabSpacing: CGFloat
    private let tabHorizontalPadding: CGFloat
    private let dividerColor: Color
    private let indicatorColor: Color
    private let indicatorColorProvider: ((ID) -> Color)?
    private let activeTextColor: Color
    private let inactiveTextColor: Color
    private let activeTextColorProvider: ((ID) -> Color)?
    private let showsDivider: Bool
    private let indicatorHeight: CGFloat
    private let tabFont: Font

    @State private var tabBarScrollState: ID?
    @State private var tabLayouts: [ID: TabLayout] = [:]

    init(
        items: [RaverScrollableTabItem<ID>],
        selection: Binding<ID>,
        progress: CGFloat,
        onSelect: ((ID) -> Void)? = nil,
        tabSpacing: CGFloat = 20,
        tabHorizontalPadding: CGFloat = 15,
        dividerColor: Color = .gray.opacity(0.3),
        indicatorColor: Color = .primary,
        indicatorColorProvider: ((ID) -> Color)? = nil,
        activeTextColor: Color = RaverTheme.primaryText,
        inactiveTextColor: Color = RaverTheme.secondaryText,
        activeTextColorProvider: ((ID) -> Color)? = nil,
        showsDivider: Bool = true,
        indicatorHeight: CGFloat = 1.8,
        tabFont: Font = .system(size: 18, weight: .regular)
    ) {
        self.items = items
        self._selection = selection
        self.progress = progress
        self.onSelect = onSelect
        self.tabSpacing = tabSpacing
        self.tabHorizontalPadding = tabHorizontalPadding
        self.dividerColor = dividerColor
        self.indicatorColor = indicatorColor
        self.indicatorColorProvider = indicatorColorProvider
        self.activeTextColor = activeTextColor
        self.inactiveTextColor = inactiveTextColor
        self.activeTextColorProvider = activeTextColorProvider
        self.showsDivider = showsDivider
        self.indicatorHeight = indicatorHeight
        self.tabFont = tabFont
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: tabSpacing) {
                ForEach(items) { item in
                    Button {
                        withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                            if let onSelect {
                                onSelect(item.id)
                            } else {
                                selection = item.id
                            }
                            tabBarScrollState = item.id
                        }
                    } label: {
                        Text(item.title)
                            .font(tabFont.weight(isTabActive(item.id) ? .semibold : .regular))
                            .foregroundStyle(textColor(for: item.id))
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .raverHorizontalRect { rect in
                        let next = TabLayout(size: rect.size, minX: rect.minX)
                        if tabLayouts[item.id]?.size != next.size || tabLayouts[item.id]?.minX != next.minX {
                            tabLayouts[item.id] = next
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(
            id: Binding(
                get: { tabBarScrollState },
                set: { _ in }
            ),
            anchor: .center
        )
        .overlay(alignment: .bottomLeading) {
            ZStack(alignment: .leading) {
                if showsDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }

                Rectangle()
                    .fill(currentIndicatorColor)
                    .frame(width: indicatorWidth, height: indicatorHeight)
                    .offset(x: indicatorX)
            }
        }
        .safeAreaPadding(.horizontal, tabHorizontalPadding)
        .scrollIndicators(.hidden)
        .onAppear {
            tabBarScrollState = selection
        }
        .onChange(of: selection) { _, newValue in
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                tabBarScrollState = newValue
            }
        }
    }

    private var indicatorWidth: CGFloat {
        let inputRange = items.indices.map { CGFloat($0) }
        let outputRange = items.map { tabLayouts[$0.id]?.size.width ?? 0 }
        return progress.interpolate(inputRange: inputRange, outputRange: outputRange)
    }

    private var indicatorX: CGFloat {
        let inputRange = items.indices.map { CGFloat($0) }
        let outputRange = items.map { tabLayouts[$0.id]?.minX ?? 0 }
        return progress.interpolate(inputRange: inputRange, outputRange: outputRange)
    }

    private var currentIndicatorColor: Color {
        guard let indicatorColorProvider, !items.isEmpty else {
            return indicatorColor
        }
        let idx = max(0, min(items.count - 1, Int(round(progress))))
        return indicatorColorProvider(items[idx].id)
    }

    private func textColor(for id: ID) -> Color {
        if isTabActive(id) {
            if let activeTextColorProvider {
                return activeTextColorProvider(id)
            }
            return activeTextColor
        }
        return inactiveTextColor
    }

    private func isTabActive(_ id: ID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        let tabIndex = CGFloat(index)
        return abs(progress - tabIndex) < 0.5
    }
}

struct RaverScrollableTabPager<ID: Hashable, Page: View>: View {
    private struct TabLayout {
        var size: CGSize = .zero
        var minX: CGFloat = .zero
    }

    @Binding private var selection: ID

    private let items: [RaverScrollableTabItem<ID>]
    private let tabSpacing: CGFloat
    private let tabHorizontalPadding: CGFloat
    private let dividerColor: Color
    private let indicatorColor: Color
    private let indicatorColorProvider: ((ID) -> Color)?
    private let isPageSwipeDisabled: Bool
    private let showsTabBar: Bool
    private let showsDivider: Bool
    private let indicatorHeight: CGFloat
    private let tabFont: Font
    private let page: (ID) -> Page

    @State private var tabBarScrollState: ID?
    @State private var mainViewScrollState: ID?
    @State private var internalProgress: CGFloat = 0
    @State private var tabLayouts: [ID: TabLayout] = [:]
    private let externalProgress: Binding<CGFloat>?

    init(
        items: [RaverScrollableTabItem<ID>],
        selection: Binding<ID>,
        tabSpacing: CGFloat = 20,
        tabHorizontalPadding: CGFloat = 15,
        dividerColor: Color = .gray.opacity(0.3),
        indicatorColor: Color = .primary,
        indicatorColorProvider: ((ID) -> Color)? = nil,
        isPageSwipeDisabled: Bool = false,
        showsTabBar: Bool = true,
        showsDivider: Bool = true,
        indicatorHeight: CGFloat = 1.8,
        tabFont: Font = .system(size: 18, weight: .regular),
        progress: Binding<CGFloat>? = nil,
        @ViewBuilder page: @escaping (ID) -> Page
    ) {
        self.items = items
        self._selection = selection
        self.tabSpacing = tabSpacing
        self.tabHorizontalPadding = tabHorizontalPadding
        self.dividerColor = dividerColor
        self.indicatorColor = indicatorColor
        self.indicatorColorProvider = indicatorColorProvider
        self.isPageSwipeDisabled = isPageSwipeDisabled
        self.showsTabBar = showsTabBar
        self.showsDivider = showsDivider
        self.indicatorHeight = indicatorHeight
        self.tabFont = tabFont
        self.externalProgress = progress
        self.page = page
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabBar {
                tabBar
            }
            pager
        }
        .onAppear {
            syncToSelection(animated: false)
        }
        .onChange(of: selection) { _, newValue in
            guard newValue != mainViewScrollState else { return }
            syncToSelection(animated: true)
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: tabSpacing) {
                ForEach(items) { item in
                    Button {
                        withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                            selection = item.id
                            tabBarScrollState = item.id
                            mainViewScrollState = item.id
                        }
                    } label: {
                        Text(item.title)
                            .font(selection == item.id ? tabFont.weight(.semibold) : tabFont)
                            .foregroundStyle(selection == item.id ? RaverTheme.primaryText : RaverTheme.secondaryText)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .raverHorizontalRect { rect in
                        let next = TabLayout(size: rect.size, minX: rect.minX)
                        if tabLayouts[item.id]?.size != next.size || tabLayouts[item.id]?.minX != next.minX {
                            tabLayouts[item.id] = next
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(
            id: Binding(
                get: { tabBarScrollState },
                set: { _ in }
            ),
            anchor: .center
        )
        .overlay(alignment: .bottomLeading) {
            ZStack(alignment: .leading) {
                if showsDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }

                Rectangle()
                    .fill(currentIndicatorColor)
                    .frame(width: indicatorWidth, height: indicatorHeight)
                    .offset(x: indicatorX)
            }
        }
        .safeAreaPadding(.horizontal, tabHorizontalPadding)
        .scrollIndicators(.hidden)
    }

    private var pager: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(items) { item in
                        page(item.id)
                            .frame(width: size.width, height: size.height)
                            .contentShape(Rectangle())
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .raverHorizontalRect { rect in
                    guard size.width > 1 else { return }
                    let raw = -rect.minX / size.width
                    let clamped = min(max(raw, 0), CGFloat(max(0, items.count - 1)))
                    if abs(progressValue - clamped) > 0.0001 {
                        progressValue = clamped
                    }
                }
            }
            .scrollPosition(id: $mainViewScrollState)
            .scrollIndicators(.hidden)
            .scrollDisabled(isPageSwipeDisabled)
            .scrollTargetBehavior(.paging)
            .onChange(of: mainViewScrollState) { _, newValue in
                guard let newValue else { return }
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                    tabBarScrollState = newValue
                    selection = newValue
                }
            }
        }
    }

    private var indicatorWidth: CGFloat {
        let inputRange = items.indices.map { CGFloat($0) }
        let outputRange = items.map { tabLayouts[$0.id]?.size.width ?? 0 }
        return progressValue.interpolate(inputRange: inputRange, outputRange: outputRange)
    }

    private var indicatorX: CGFloat {
        let inputRange = items.indices.map { CGFloat($0) }
        let outputRange = items.map { tabLayouts[$0.id]?.minX ?? 0 }
        return progressValue.interpolate(inputRange: inputRange, outputRange: outputRange)
    }

    private var currentIndicatorColor: Color {
        guard let indicatorColorProvider, !items.isEmpty else {
            return indicatorColor
        }
        let idx = max(0, min(items.count - 1, Int(round(progressValue))))
        return indicatorColorProvider(items[idx].id)
    }

    private func syncToSelection(animated: Bool) {
        let apply = {
            tabBarScrollState = selection
            mainViewScrollState = selection
            if let idx = items.firstIndex(where: { $0.id == selection }) {
                progressValue = CGFloat(idx)
            }
        }
        if animated {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                apply()
            }
        } else {
            apply()
        }
    }

    private var progressValue: CGFloat {
        get { externalProgress?.wrappedValue ?? internalProgress }
        nonmutating set {
            if let externalProgress {
                externalProgress.wrappedValue = newValue
            } else {
                internalProgress = newValue
            }
        }
    }
}

struct RaverCarouselItemPhase {
    let distanceToCenter: CGFloat
    let revealProgress: CGFloat
    let suppressRevealAnimation: Bool
}

private struct RaverCarouselItemFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct RaverSnapCarousel<Content: View, Item: Identifiable>: View {
    let content: (Item, RaverCarouselItemPhase) -> Content
    let items: [Item]
    let spacing: CGFloat
    let trailingSpace: CGFloat
    let topInset: CGFloat
    let onHorizontalDragStateChanged: ((Bool) -> Void)?

    @Binding private var selection: Int
    @Binding private var index: Int

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var itemFrames: [Int: CGRect] = [:]
    @State private var suppressRevealAnimation = false
    @State private var scrollTargetSelection: Int?

    init(
        spacing: CGFloat = 15,
        trailingSpace: CGFloat = 100,
        topInset: CGFloat = 60,
        selection: Binding<Int>,
        index: Binding<Int>,
        items: [Item],
        onHorizontalDragStateChanged: ((Bool) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item, RaverCarouselItemPhase) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.trailingSpace = trailingSpace
        self.topInset = topInset
        self.onHorizontalDragStateChanged = onHorizontalDragStateChanged
        self._selection = selection
        self._index = index
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width - trailingSpace
            let carouselWidth = proxy.size.width - (trailingSpace - spacing)

            ZStack {
                if #available(iOS 17.0, *) {
                    viewAlignedBody(cardWidth: cardWidth, containerWidth: proxy.size.width)
                } else {
                    dragStackBody(cardWidth: cardWidth, carouselWidth: carouselWidth)
                }
            }
            .onAppear {
                guard !items.isEmpty else { return }
                if loopedIndices.indices.contains(selection) {
                    scrollTargetSelection = selection
                    syncExternalIndex(with: selection)
                } else {
                    selection = fakeIndex(for: index)
                    scrollTargetSelection = selection
                }
            }
            .onChange(of: selection) { _, newValue in
                if scrollTargetSelection != newValue {
                    scrollTargetSelection = newValue
                }
                syncExternalIndex(with: newValue)
            }
            .onChange(of: index) { _, newValue in
                let expectedSelection = fakeIndex(for: newValue)
                if selection != expectedSelection && !isDuplicateSelection(selection) {
                    selection = expectedSelection
                }
            }
        }
        .onDisappear {
            onHorizontalDragStateChanged?(false)
        }
    }

    @ViewBuilder
    private func dragStackBody(cardWidth: CGFloat, carouselWidth: CGFloat) -> some View {
        let progress = dragStackPageProgress(carouselWidth: carouselWidth)

        HStack(spacing: spacing) {
            ForEach(Array(loopedIndices.enumerated()), id: \.offset) { entry in
                let fakeIndex = entry.offset
                let itemIndex = entry.element
                let item = items[itemIndex]
                let phase = progressPhase(for: fakeIndex, pageProgress: progress)

                content(item, phase)
                    .frame(width: cardWidth)
                    .offset(y: topInset + liftOffset(for: phase))
            }
        }
        .padding(.leading, trailingSpace / 2)
        .padding(.trailing, spacing)
        .offset(x: -progress * carouselWidth)
        .contentShape(Rectangle())
        .gesture(dragGesture(carouselWidth: carouselWidth))
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func viewAlignedBody(cardWidth: CGFloat, containerWidth: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: spacing) {
                ForEach(Array(loopedIndices.enumerated()), id: \.offset) { entry in
                    let fakeIndex = entry.offset
                    let itemIndex = entry.element
                    let item = items[itemIndex]
                    let phase = centeredPhase(for: fakeIndex, containerWidth: containerWidth)

                    content(item, phase)
                        .frame(width: cardWidth)
                        .offset(y: topInset + liftOffset(for: phase))
                        .background {
                            GeometryReader { itemProxy in
                                Color.clear
                                    .preference(
                                        key: RaverCarouselItemFrameKey.self,
                                        value: [fakeIndex: itemProxy.frame(in: .named("RAVER_SNAP_CAROUSEL_SPACE"))]
                                    )
                            }
                        }
                        .id(fakeIndex)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.horizontal, trailingSpace / 2)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: viewAlignedSelectionBinding, anchor: .center)
        .coordinateSpace(name: "RAVER_SNAP_CAROUSEL_SPACE")
        .simultaneousGesture(horizontalDragRelayGesture)
        .onPreferenceChange(RaverCarouselItemFrameKey.self) { frames in
            itemFrames = frames
            adjustViewAlignedSelectionIfNeeded(containerWidth: containerWidth, frames: frames)
        }
    }

    private var loopedIndices: [Int] {
        guard !items.isEmpty else { return [] }
        guard items.count > 1 else { return Array(items.indices) }
        guard items.count >= 3 else {
            return [items.count - 1] + Array(items.indices) + [0]
        }
        return [items.count - 2, items.count - 1] + Array(items.indices) + [0, 1]
    }

    private func centeredPhase(for fakeIndex: Int, containerWidth: CGFloat) -> RaverCarouselItemPhase {
        guard containerWidth != 0 else {
            let distance = abs(CGFloat(fakeIndex - selection))
            let progress = max(0, 1 - min(distance, 1))
            return RaverCarouselItemPhase(
                distanceToCenter: distance,
                revealProgress: pow(progress, 1.6),
                suppressRevealAnimation: suppressRevealAnimation
            )
        }

        if let frame = itemFrames[fakeIndex], frame.width > 0 {
            let centerX = containerWidth / 2
            let distance = abs(frame.midX - centerX) / containerWidth
            let progress = max(0, 1 - min(distance, 1))
            return RaverCarouselItemPhase(
                distanceToCenter: distance,
                revealProgress: pow(progress, 1.6),
                suppressRevealAnimation: suppressRevealAnimation
            )
        }

        let fallbackDistance = abs(CGFloat(fakeIndex - selection))
        let fallbackProgress = max(0, 1 - min(fallbackDistance, 1))
        return RaverCarouselItemPhase(
            distanceToCenter: fallbackDistance,
            revealProgress: pow(fallbackProgress, 1.6),
            suppressRevealAnimation: suppressRevealAnimation
        )
    }

    private func dragStackPageProgress(carouselWidth: CGFloat) -> CGFloat {
        guard carouselWidth > 0 else { return CGFloat(selection) }
        return CGFloat(selection) - (dragTranslation / carouselWidth)
    }

    private func progressPhase(for fakeIndex: Int, pageProgress: CGFloat) -> RaverCarouselItemPhase {
        let distance = abs(CGFloat(fakeIndex) - pageProgress)
        let progress = max(0, 1 - min(distance, 1))

        return RaverCarouselItemPhase(
            distanceToCenter: distance,
            revealProgress: pow(progress, 1.6),
            suppressRevealAnimation: suppressRevealAnimation
        )
    }

    private func dragGesture(carouselWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.width
                if abs(value.translation.width) > abs(value.translation.height) {
                    onHorizontalDragStateChanged?(true)
                }
            }
            .onEnded { value in
                onHorizontalDragStateChanged?(false)
                finishDrag(value: value, carouselWidth: carouselWidth)
            }
    }

    private var horizontalDragRelayGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    onHorizontalDragStateChanged?(true)
                }
            }
            .onEnded { _ in
                onHorizontalDragStateChanged?(false)
            }
    }

    private func finishDrag(value: DragGesture.Value, carouselWidth: CGFloat) {
        guard items.count > 1, carouselWidth > 0 else { return }

        let projectedProgress = CGFloat(selection) - (value.predictedEndTranslation.width / carouselWidth)
        let translationProgress = CGFloat(selection) - (value.translation.width / carouselWidth)
        let projectedTravel = value.predictedEndTranslation.width - value.translation.width
        let flingThreshold = min(carouselWidth * 0.18, 72)

        let rawTarget: CGFloat
        if abs(projectedTravel) > flingThreshold {
            rawTarget = projectedProgress
        } else {
            rawTarget = translationProgress
        }

        var resolved = clampFakeSelection(Int(rawTarget.rounded()))

        if items.count >= 3 {
            resolved = min(max(resolved, 1), loopedIndices.count - 2)

            if resolved == 1 {
                resolved = items.count + 1
            } else if resolved == loopedIndices.count - 2 {
                resolved = 2
            }
        } else {
            if resolved == 0 {
                resolved = items.count
            } else if resolved == loopedIndices.count - 1 {
                resolved = 1
            }
        }

        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.16)) {
            selection = resolved
        }
    }

    private func fakeIndex(for originalIndex: Int) -> Int {
        guard items.count > 1 else { return max(0, min(originalIndex, max(items.count - 1, 0))) }
        let leadingBuffer = items.count >= 3 ? 2 : 1
        return clampOriginalIndex(originalIndex) + leadingBuffer
    }

    private func originalIndex(for fakeIndex: Int) -> Int {
        guard loopedIndices.indices.contains(fakeIndex) else { return clampOriginalIndex(index) }
        return loopedIndices[fakeIndex]
    }

    private func clampOriginalIndex(_ value: Int) -> Int {
        max(min(value, items.count - 1), 0)
    }

    private func clampFakeSelection(_ value: Int) -> Int {
        max(min(value, max(loopedIndices.count - 1, 0)), 0)
    }

    private func isDuplicateSelection(_ value: Int) -> Bool {
        guard items.count > 1 else { return false }
        if items.count >= 3 {
            return value == 1 || value == loopedIndices.count - 2
        }
        return value == 0 || value == loopedIndices.count - 1
    }

    private func syncExternalIndex(with fakeIndex: Int) {
        guard !items.isEmpty else { return }
        let mappedIndex = originalIndex(for: fakeIndex)
        if index != mappedIndex {
            index = mappedIndex
        }
    }

    @available(iOS 17.0, *)
    private var viewAlignedSelectionBinding: Binding<Int?> {
        Binding(
            get: {
                guard let scrollTargetSelection else { return nil }
                guard loopedIndices.indices.contains(scrollTargetSelection) else { return nil }
                return scrollTargetSelection
            },
            set: { newValue in
                guard let newValue else { return }
                scrollTargetSelection = newValue
                selection = newValue
            }
        )
    }

    private func jumpSelection(to value: Int) {
        guard selection != value else { return }
        suppressRevealAnimation = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollTargetSelection = value
            selection = value
        }
        DispatchQueue.main.async {
            suppressRevealAnimation = false
        }
    }

    @available(iOS 17.0, *)
    private func adjustViewAlignedSelectionIfNeeded(containerWidth: CGFloat, frames: [Int: CGRect]) {
        guard items.count > 1 else { return }
        guard isDuplicateSelection(selection) else { return }
        guard let rect = frames[selection], rect.width > 0 else { return }

        let centerX = containerWidth / 2
        let centeredThreshold: CGFloat = 1.5
        guard abs(rect.midX - centerX) <= centeredThreshold else { return }

        let target: Int
        if items.count >= 3 {
            if selection == 1 {
                target = items.count + 1
            } else if selection == loopedIndices.count - 2 {
                target = 2
            } else {
                return
            }
        } else {
            if selection == 0 {
                target = items.count
            } else if selection == loopedIndices.count - 1 {
                target = 1
            } else {
                return
            }
        }

        jumpSelection(to: target)
    }

    private func liftOffset(for phase: RaverCarouselItemPhase) -> CGFloat {
        let eased = 1 - pow(1 - phase.revealProgress, 1.15)
        return -topInset * eased
    }
}

private extension CGFloat {
    func interpolate(inputRange: [CGFloat], outputRange: [CGFloat]) -> CGFloat {
        guard !inputRange.isEmpty, inputRange.count == outputRange.count else { return 0 }
        guard inputRange.count > 1 else { return outputRange.first ?? 0 }

        let x = self
        let upperBound = inputRange.count - 1

        if x <= inputRange[0] {
            return outputRange[0]
        }

        for index in 1...upperBound {
            let x1 = inputRange[index - 1]
            let x2 = inputRange[index]
            let y1 = outputRange[index - 1]
            let y2 = outputRange[index]

            if x <= x2 {
                let denominator = x2 - x1
                guard abs(denominator) > 0.0001 else { return y2 }
                return y1 + ((y2 - y1) / denominator) * (x - x1)
            }
        }

        return outputRange[upperBound]
    }
}

private struct RaverHorizontalRectPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private extension View {
    @ViewBuilder
    func raverHorizontalRect(_ completion: @escaping (CGRect) -> Void) -> some View {
        self
            .overlay {
                GeometryReader { proxy in
                    let rect = proxy.frame(in: .scrollView(axis: .horizontal))
                    Color.clear
                        .preference(key: RaverHorizontalRectPreferenceKey.self, value: rect)
                        .onPreferenceChange(RaverHorizontalRectPreferenceKey.self, perform: completion)
                }
            }
    }
}
