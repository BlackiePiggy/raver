import SwiftUI

struct DiscoverHomeView: View {
    fileprivate enum Section: String, CaseIterable, Identifiable {
        case feed
        case events
        case djs
        case sets
        case learn

        var id: String { rawValue }

        var title: String {
            switch self {
            case .feed: return "动态"
            case .events: return "活动"
            case .djs: return "DJ"
            case .sets: return "Sets"
            case .learn: return "Wiki"
            }
        }

        var themeColor: Color {
            switch self {
            case .feed: return Color(red: 0.95, green: 0.30, blue: 0.38)
            case .events: return Color(red: 0.97, green: 0.54, blue: 0.21)
            case .djs: return Color(red: 0.44, green: 0.78, blue: 0.33)
            case .sets: return Color(red: 0.30, green: 0.67, blue: 0.97)
            case .learn: return Color(red: 0.76, green: 0.47, blue: 0.95)
            }
        }
    }

    @State private var section: Section = .feed
    @State private var pageProgress: CGFloat = 0
    @State private var tabFrames: [Section: CGRect] = [:]
    @State private var pagerWidth: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            topTabs

            GeometryReader { proxy in
                TabView(selection: $section) {
                    ForEach(Section.allCases) { item in
                        pageView(for: item)
                            .tag(item)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: DiscoverPageOffsetPreferenceKey.self,
                                        value: [item: geo.frame(in: .named("DiscoverPager")).minX]
                                    )
                                }
                            )
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .coordinateSpace(name: "DiscoverPager")
                .onAppear {
                    pagerWidth = max(1, proxy.size.width)
                    pageProgress = CGFloat(selectedIndex(for: section))
                }
                .onChange(of: proxy.size.width) { _, newValue in
                    pagerWidth = max(1, newValue)
                }
                .onChange(of: section) { _, newValue in
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                        pageProgress = CGFloat(selectedIndex(for: newValue))
                    }
                }
                .onPreferenceChange(DiscoverPageOffsetPreferenceKey.self) { values in
                    updatePageProgress(with: values)
                }
            }
        }
        .background(RaverTheme.background)
    }

    private var topTabs: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(Section.allCases) { item in
                        Button {
                            selectSection(item)
                        } label: {
                            Text(item.title)
                                .font(.system(size: 18, weight: section == item ? .semibold : .regular))
                                .foregroundStyle(section == item ? RaverTheme.primaryText : RaverTheme.secondaryText)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        .id(item)
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                selectSection(item)
                            }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: DiscoverTabFramePreferenceKey.self,
                                    value: [item: geo.frame(in: .named("DiscoverTabs"))]
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 3)
            }
            .coordinateSpace(name: "DiscoverTabs")
            .overlay(alignment: .bottomLeading) {
                if let indicator = indicatorRect {
                    Capsule()
                        .fill(currentIndicatorColor)
                        .frame(width: indicator.width, height: 3)
                        .offset(x: indicator.minX, y: 0)
                        .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.75), value: indicator.minX)
                        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.72), value: indicator.width)
                        .allowsHitTesting(false)
                }
            }
            .background(RaverTheme.background)
            .onPreferenceChange(DiscoverTabFramePreferenceKey.self) { value in
                tabFrames = value
            }
            .onChange(of: section) { _, newSection in
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.84)) {
                    scrollProxy.scrollTo(newSection, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func pageView(for section: Section) -> some View {
        switch section {
        case .feed:
            FeedView()
        case .events:
            EventsModuleView()
        case .djs:
            DJsModuleView()
        case .sets:
            SetsModuleView()
        case .learn:
            LearnModuleView()
        }
    }

    private var currentIndicatorColor: Color {
        let idx = max(0, min(Section.allCases.count - 1, Int(round(pageProgress))))
        return Section.allCases[idx].themeColor
    }

    private var indicatorRect: CGRect? {
        guard !tabFrames.isEmpty else { return nil }
        let count = Section.allCases.count
        guard count > 0 else { return nil }

        let clamped = min(max(pageProgress, 0), CGFloat(count - 1))
        let leftIndex = Int(floor(clamped))
        let rightIndex = min(leftIndex + 1, count - 1)
        let t = clamped - CGFloat(leftIndex)

        let leftSection = Section.allCases[leftIndex]
        let rightSection = Section.allCases[rightIndex]
        guard let leftFrame = tabFrames[leftSection], let rightFrame = tabFrames[rightSection] else {
            return nil
        }

        let baseX = leftFrame.minX + (rightFrame.minX - leftFrame.minX) * t
        let baseWidth = leftFrame.width + (rightFrame.width - leftFrame.width) * t
        let elastic = (1 - abs(0.5 - t) * 2) * 16
        return CGRect(x: baseX - elastic * 0.2, y: 0, width: baseWidth + elastic, height: 3)
    }

    private func selectedIndex(for section: Section) -> Int {
        Section.allCases.firstIndex(of: section) ?? 0
    }

    private func selectSection(_ item: Section) {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.84)) {
            section = item
            pageProgress = CGFloat(selectedIndex(for: item))
        }
    }

    private func updatePageProgress(with offsets: [Section: CGFloat]) {
        guard pagerWidth > 1 else { return }
        let progressCandidates: [(progress: CGFloat, distance: CGFloat)] = Section.allCases.enumerated().compactMap { index, item in
            guard let minX = offsets[item] else { return nil }
            let progress = CGFloat(index) - (minX / pagerWidth)
            return (progress, abs(minX))
        }

        guard let best = progressCandidates.min(by: { $0.distance < $1.distance }) else { return }
        let clamped = min(max(best.progress, 0), CGFloat(max(0, Section.allCases.count - 1)))
        pageProgress = clamped
    }
}

private struct DiscoverTabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [DiscoverHomeView.Section: CGRect] = [:]

    static func reduce(value: inout [DiscoverHomeView.Section: CGRect], nextValue: () -> [DiscoverHomeView.Section: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct DiscoverPageOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [DiscoverHomeView.Section: CGFloat] = [:]

    static func reduce(value: inout [DiscoverHomeView.Section: CGFloat], nextValue: () -> [DiscoverHomeView.Section: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
