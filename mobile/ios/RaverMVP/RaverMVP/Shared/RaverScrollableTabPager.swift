import SwiftUI

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
    private let showsDivider: Bool
    private let indicatorHeight: CGFloat
    private let tabFont: Font
    private let page: (ID) -> Page

    @State private var tabBarScrollState: ID?
    @State private var mainViewScrollState: ID?
    @State private var progress: CGFloat = 0
    @State private var tabLayouts: [ID: TabLayout] = [:]

    init(
        items: [RaverScrollableTabItem<ID>],
        selection: Binding<ID>,
        tabSpacing: CGFloat = 20,
        tabHorizontalPadding: CGFloat = 15,
        dividerColor: Color = .gray.opacity(0.3),
        indicatorColor: Color = .primary,
        indicatorColorProvider: ((ID) -> Color)? = nil,
        isPageSwipeDisabled: Bool = false,
        showsDivider: Bool = true,
        indicatorHeight: CGFloat = 1.8,
        tabFont: Font = .system(size: 18, weight: .regular),
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
        self.showsDivider = showsDivider
        self.indicatorHeight = indicatorHeight
        self.tabFont = tabFont
        self.page = page
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
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
                    if abs(progress - clamped) > 0.0001 {
                        progress = clamped
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

    private func syncToSelection(animated: Bool) {
        let apply = {
            tabBarScrollState = selection
            mainViewScrollState = selection
            if let idx = items.firstIndex(where: { $0.id == selection }) {
                progress = CGFloat(idx)
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
