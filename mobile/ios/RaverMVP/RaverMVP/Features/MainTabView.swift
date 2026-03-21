import SwiftUI
import PhotosUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DiscoverHomeView()
                .tabItem {
                    Label("发现", systemImage: "safari.fill")
                }

            CircleHomeView()
                .tabItem {
                    Label("圈子", systemImage: "person.3.fill")
                }

            MessagesHomeView()
                .tabItem {
                    Label("消息", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .badge(appState.unreadMessagesCount > 0 ? Text("\(appState.unreadMessagesCount)") : nil)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(RaverTheme.accent)
        .task {
            await appState.refreshUnreadMessages()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await appState.refreshUnreadMessages() }
        }
    }
}

private struct CircleHomeView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case feed
        case squads
        case ratings

        var id: String { rawValue }
        var title: String {
            switch self {
            case .feed: return "动态"
            case .squads: return "小队"
            case .ratings: return "打分"
            }
        }

        var themeColor: Color {
            switch self {
            case .feed: return Color(red: 0.95, green: 0.30, blue: 0.38)
            case .squads: return Color(red: 0.30, green: 0.67, blue: 0.97)
            case .ratings: return Color(red: 0.98, green: 0.71, blue: 0.22)
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
                                        key: CirclePageOffsetPreferenceKey.self,
                                        value: [item: geo.frame(in: .named("CirclePager")).minX]
                                    )
                                }
                            )
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .coordinateSpace(name: "CirclePager")
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
                .onPreferenceChange(CirclePageOffsetPreferenceKey.self) { values in
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
                                    key: CircleTabFramePreferenceKey.self,
                                    value: [item: geo.frame(in: .named("CircleTabs"))]
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 3)
            }
            .coordinateSpace(name: "CircleTabs")
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
            .onPreferenceChange(CircleTabFramePreferenceKey.self) { value in
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
        case .squads:
            SquadHallView()
        case .ratings:
            CircleRatingHubView()
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

    private struct CircleTabFramePreferenceKey: PreferenceKey {
        static var defaultValue: [Section: CGRect] = [:]

        static func reduce(value: inout [Section: CGRect], nextValue: () -> [Section: CGRect]) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
    }

    private struct CirclePageOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: [Section: CGFloat] = [:]

        static func reduce(value: inout [Section: CGFloat], nextValue: () -> [Section: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
    }
}

private struct SquadHallView: View {
    private enum SquadListMode: String, CaseIterable, Identifiable {
        case plaza
        case mine

        var id: String { rawValue }

        var title: String {
            switch self {
            case .plaza: return "小队广场"
            case .mine: return "我的小队"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    private let service = AppEnvironment.makeService()

    @State private var squads: [SquadSummary] = []
    @State private var mySquads: [SquadSummary] = []
    @State private var squadProfilesByID: [String: SquadProfile] = [:]
    @State private var isLoading = false
    @State private var showCreateSquad = false
    @State private var selectedSquad: PostSquad?
    @State private var selectedMode: SquadListMode = .plaza
    @State private var errorMessage: String?
    private let cardColumns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Text("小队广场")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Button {
                        showCreateSquad = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.subheadline.weight(.bold))
                            Text("创建小队")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(RaverTheme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RaverTheme.card)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                HStack(spacing: 8) {
                    ForEach(SquadListMode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedMode = mode
                            }
                        } label: {
                            Text(mode.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedMode == mode ? Color.white : RaverTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(selectedMode == mode ? RaverTheme.accent : RaverTheme.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(selectedMode == mode ? Color.clear : RaverTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                if isLoading && displayedSquads.isEmpty {
                    Spacer()
                    ProgressView("加载小队中...")
                    Spacer()
                } else if displayedSquads.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        selectedMode == .mine ? "还没有加入小队" : "暂无小队",
                        systemImage: "flag.2.crossed",
                        description: Text(selectedMode == .mine ? "去小队广场逛逛，加入你感兴趣的小队。" : "创建一个小队，和朋友一起记录活动。")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: cardColumns, spacing: 14) {
                            ForEach(displayedSquads) { squad in
                                Button {
                                    selectedSquad = PostSquad(id: squad.id, name: squad.name, avatarURL: squad.avatarURL)
                                } label: {
                                    squadFlagCard(squad)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await loadSquads()
                    }
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadSquads()
            }
            .onAppear {
                Task { await loadSquads() }
            }
            .sheet(isPresented: $showCreateSquad) {
                NavigationStack {
                    CreateSquadView(service: appState.service) { conversation in
                        showCreateSquad = false
                        selectedSquad = PostSquad(id: conversation.id, name: conversation.title, avatarURL: conversation.avatarURL)
                        Task { await loadSquads() }
                    }
                    .environmentObject(appState)
                }
            }
            .fullScreenCover(item: $selectedSquad) { squad in
                NavigationStack {
                    SquadProfileView(squadID: squad.id, service: appState.service)
                        .environmentObject(appState)
                }
            }
            .alert("加载失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("重试") {
                    Task { await loadSquads() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var displayedSquads: [SquadSummary] {
        switch selectedMode {
        case .plaza:
            return squads
        case .mine:
            return mySquads
        }
    }

    @ViewBuilder
    private func squadBackgroundImage(_ squad: SquadSummary) -> some View {
        let bannerURL = AppConfig.resolvedURLString(squad.bannerURL)
        if let bannerURL,
           let url = URL(string: bannerURL),
           bannerURL.hasPrefix("http://") || bannerURL.hasPrefix("https://") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.63, blue: 0.32), Color(red: 0.87, green: 0.34, blue: 0.29)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.63, blue: 0.32), Color(red: 0.87, green: 0.34, blue: 0.29)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                @unknown default:
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.63, blue: 0.32), Color(red: 0.87, green: 0.34, blue: 0.29)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        } else {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.63, blue: 0.32), Color(red: 0.87, green: 0.34, blue: 0.29)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func leaderUserSummary(for squad: SquadSummary) -> UserSummary? {
        squadProfilesByID[squad.id]?.leader
    }

    @ViewBuilder
    private func leaderAvatar(_ squad: SquadSummary) -> some View {
        if let leader = leaderUserSummary(for: squad) {
            if let resolved = AppConfig.resolvedURLString(leader.avatarURL),
               let remoteURL = URL(string: resolved),
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(Color.white.opacity(0.22))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        leaderAvatarFallback(leader)
                    @unknown default:
                        leaderAvatarFallback(leader)
                    }
                }
                .clipShape(Circle())
            } else {
                leaderAvatarFallback(leader)
            }
        } else {
            Circle()
                .fill(Color.white.opacity(0.22))
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.white.opacity(0.9))
                )
        }
    }

    private func leaderAvatarFallback(_ leader: UserSummary) -> some View {
        let asset = AppConfig.resolvedUserAvatarAssetName(
            userID: leader.id,
            username: leader.username,
            avatarURL: leader.avatarURL
        )
        return Image(asset)
            .resizable()
            .scaledToFill()
            .background(Color.white.opacity(0.2))
            .clipShape(Circle())
    }

    private func squadIPText(_ squad: SquadSummary) -> String {
        // 当前数据模型暂未提供地区字段，先保留展示位以满足卡片结构。
        "IP地区：暂未公开"
    }

    private func squadFlagCard(_ squad: SquadSummary) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: 0, style: .continuous)

        return cardShape
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.63, blue: 0.32), Color(red: 0.87, green: 0.34, blue: 0.29)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(3 / 2, contentMode: .fit)
            .overlay {
                squadBackgroundImage(squad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.46),
                        Color.black.opacity(0.70),
                        Color.black.opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(squad.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        leaderAvatar(squad)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
                            )
                        Text(leaderLabelText(for: squad))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Text(squadIPText(squad))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)

                        Text("·")
                            .foregroundStyle(Color.white.opacity(0.72))

                        Text("\(squad.memberCount) 人")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
            .clipShape(cardShape)
    }

    private func leaderLabelText(for squad: SquadSummary) -> String {
        if let name = leaderUserSummary(for: squad)?.displayName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "队长 \(name)"
        }
        return "队长"
    }

    @MainActor
    private func loadSquads() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedSquads = try await service.fetchRecommendedSquads()
                .sorted(by: { lhs, rhs in
                    if lhs.isMember != rhs.isMember {
                        return lhs.isMember && !rhs.isMember
                    }
                    if lhs.updatedAt != rhs.updatedAt {
                        return lhs.updatedAt > rhs.updatedAt
                    }
                    return lhs.id < rhs.id
                })
            let loadedMySquads = try await service.fetchMySquads()
                .sorted(by: { lhs, rhs in
                    if lhs.updatedAt != rhs.updatedAt {
                        return lhs.updatedAt > rhs.updatedAt
                    }
                    return lhs.id < rhs.id
                })
            squads = loadedSquads
            mySquads = loadedMySquads

            // 补齐小队队长信息用于卡片展示。
            let combinedByID = Dictionary(
                (loadedSquads + loadedMySquads).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            for squad in combinedByID.values {
                if squadProfilesByID[squad.id] != nil { continue }
                if let profile = try? await service.fetchSquadProfile(squadID: squad.id) {
                    squadProfilesByID[squad.id] = profile
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SquadFlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 14
        var path = Path()

        path.move(to: CGPoint(x: radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius - 18, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 18, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX - 18, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius - 18, y: rect.maxY),
            control: CGPoint(x: rect.maxX - 18, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct TriangleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CircleRatingHubView: View {
    private let service = AppEnvironment.makeWebService()

    @State private var events: [WebRatingEvent] = []
    @State private var presentedEventRoute: CircleRatingEventRoute?
    @State private var isPresentingCreateEvent = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("事件驱动打分")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Button {
                        isPresentingCreateEvent = true
                    } label: {
                        Label("发布事件", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RaverTheme.card)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if isLoading && events.isEmpty {
                    ProgressView("正在加载打分事件…")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if let errorMessage, events.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                } else if events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("还没有打分事件")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text("点击右上角“发布事件”，先创建一个事件，再在事件内添加打分单位。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 14)
                } else {
                    ForEach(events) { event in
                        Button {
                            presentedEventRoute = CircleRatingEventRoute(id: event.id)
                        } label: {
                            eventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(RaverTheme.background)
        .task {
            await loadEvents()
        }
        .refreshable {
            await loadEvents()
        }
        .sheet(isPresented: $isPresentingCreateEvent) {
            CreateRatingEventSheet { input in
                let created = try await service.createRatingEvent(input: input)
                await MainActor.run {
                    events.insert(created, at: 0)
                }
            }
        }
        .fullScreenCover(item: $presentedEventRoute) { route in
            NavigationStack {
                CircleRatingEventDetailView(
                    eventID: route.id,
                    onClose: {
                        presentedEventRoute = nil
                    },
                    onUpdated: {
                        Task { await loadEvents() }
                    }
                )
            }
        }
    }

    private func eventCard(event: WebRatingEvent) -> some View {
        let ratedUnits = event.units.filter { $0.ratingCount > 0 }
        let average = ratedUnits.isEmpty
            ? 0
            : ratedUnits.map(\.rating).reduce(0, +) / Double(ratedUnits.count)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                RatingSquareImage(
                    imageURL: event.imageUrl,
                    fallbackSymbol: "sparkles.rectangle.stack.fill",
                    size: 72
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                    Text((event.description?.isEmpty == false ? event.description : "暂无事件描述") ?? "暂无事件描述")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(3)
                    Text("发布者：\(event.createdBy?.shownName ?? "匿名用户")")
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 2)
            }

            HStack(spacing: 8) {
                Label("\(event.units.count) 个单位", systemImage: "square.grid.2x2")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text("·")
                    .foregroundStyle(RaverTheme.secondaryText.opacity(0.7))
                Text("均分 \(average, specifier: "%.1f")/10")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Spacer()
                HalfStarRatingReadOnlyView(score: average, maxScore: 10, starSize: 12, spacing: 2)
                    .allowsHitTesting(false)
            }
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 14)
    }

    @MainActor
    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await service.fetchRatingEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CircleRatingEventDetailView: View {
    private let service = AppEnvironment.makeWebService()

    let eventID: String
    let onClose: () -> Void
    let onUpdated: () -> Void

    @State private var event: WebRatingEvent?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isPresentingCreateUnit = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let event {
                        HStack(alignment: .top, spacing: 10) {
                            RatingSquareImage(
                                imageURL: event.imageUrl,
                                fallbackSymbol: "sparkles.rectangle.stack.fill",
                                size: 72
                            )
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text((event.description?.isEmpty == false ? event.description : "暂无事件描述") ?? "暂无事件描述")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(4)
                                Text("发布者：\(event.createdBy?.shownName ?? "匿名用户")")
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if event.units.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("还没有打分单位")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text("点击右上角 +，在这个事件下发布第一个打分单位。")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(12)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            ForEach(event.units) { unit in
                                NavigationLink {
                                    CircleRatingUnitDetailView(
                                        unitID: unit.id,
                                        onSubmitted: {
                                            Task {
                                                await loadEvent()
                                                onUpdated()
                                            }
                                        }
                                    )
                                } label: {
                                    ratingUnitRow(unit: unit)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if isLoading {
                        ProgressView("正在加载事件…")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        Text(errorMessage ?? "事件不存在")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 54)
                .padding(.bottom, 20)
            }
            .background(RaverTheme.background)
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadEvent()
            }
            .onDisappear {
                onUpdated()
            }
            .sheet(isPresented: $isPresentingCreateUnit) {
                CreateRatingUnitSheet { input in
                    let created = try await service.createRatingUnit(eventID: eventID, input: input)
                    await MainActor.run {
                        guard event != nil else { return }
                        event?.units.append(created)
                        event?.updatedAt = Date()
                    }
                }
            }
            HStack {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.36))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    isPresentingCreateUnit = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.36))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)  // safeAreaInset 里原来就是 .padding(.top, 4)
        }
    }

    private func ratingUnitRow(unit: WebRatingUnit) -> some View {
        HStack(alignment: .center, spacing: 10) {
            RatingSquareImage(
                imageURL: unit.imageUrl,
                fallbackSymbol: "music.mic",
                size: 50
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(unit.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Text((unit.description?.isEmpty == false ? unit.description : "暂无单位描述") ?? "暂无单位描述")
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
                Text("发布者：\(unit.createdBy?.shownName ?? "匿名用户")")
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(unit.rating, specifier: "%.1f")")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Text("\(unit.ratingCount) 人评分")
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(10)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func loadEvent() async {
        isLoading = true
        defer { isLoading = false }
        do {
            event = try await service.fetchRatingEvent(id: eventID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CircleRatingUnitDetailView: View {
    @EnvironmentObject private var appState: AppState
    private let socialService = AppEnvironment.makeService()
    private let webService = AppEnvironment.makeWebService()

    let unitID: String
    let onSubmitted: () -> Void

    @State private var unit: WebRatingUnit?
    @State private var commentDraft = ""
    @State private var draftScore: Double = 0
    @State private var myProfile: UserProfile?
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let unit {
                    HStack(alignment: .top, spacing: 10) {
                        RatingSquareImage(
                            imageURL: unit.imageUrl,
                            fallbackSymbol: "music.mic",
                            size: 72
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(unit.name)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(RaverTheme.primaryText)
                            Text((unit.description?.isEmpty == false ? unit.description : "暂无单位描述") ?? "暂无单位描述")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(3)
                            Text("发布者：\(unit.createdBy?.shownName ?? "匿名用户")")
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("评分")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        HalfStarDragRatingControl(
                            score: $draftScore,
                            maxScore: 10,
                            expandsToFullWidth: true
                        )
                    }
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("评论")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)

                        if unit.comments.isEmpty {
                            Text("还没有评论，来写第一条吧")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(unit.comments) { comment in
                                let author = resolvedAuthor(comment: comment)
                                HStack(alignment: .top, spacing: 10) {
                                    NavigationLink {
                                        UserProfileView(userID: author.userID)
                                    } label: {
                                        ratingCommentAvatar(
                                            userID: author.userID,
                                            username: author.username,
                                            avatarURL: author.avatarURL
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(author.displayName)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(RaverTheme.secondaryText)
                                            HalfStarRatingReadOnlyView(
                                                score: comment.score,
                                                maxScore: 10,
                                                starSize: 10,
                                                spacing: 1.5
                                            )
                                        }
                                        Text(comment.content)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.primaryText)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("写评论…", text: $commentDraft)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RaverTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Button("发送") {
                                Task {
                                    await addComment()
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(canSendComment ? RaverTheme.accent : RaverTheme.secondaryText)
                            .buttonStyle(.plain)
                            .disabled(!canSendComment)
                            .opacity(canSendComment ? 1 : 0.45)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.9))
                        }
                    }
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView("正在加载评分单位…")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .padding(.bottom, 20)
        }
        .background(RaverTheme.background)
        .navigationTitle("评论列表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            await loadUnit()
            await refreshMyProfile()
        }
    }

    private var canSendComment: Bool {
        !isSubmitting
            && !commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draftScore >= 1
    }

    private func resolvedAuthor(comment: WebRatingComment) -> (userID: String, username: String, displayName: String, avatarURL: String?) {
        if let user = comment.user {
            return (
                userID: user.id,
                username: user.username,
                displayName: user.shownName,
                avatarURL: user.avatarUrl
            )
        }
        if let myID = appState.session?.user.id, comment.userId == myID {
            return (
                userID: myID,
                username: myProfile?.username ?? appState.session?.user.username ?? "me",
                displayName: myProfile?.displayName ?? appState.session?.user.displayName ?? "我",
                avatarURL: myProfile?.avatarURL ?? appState.session?.user.avatarURL
            )
        }
        return (
            userID: comment.userId,
            username: "user",
            displayName: "用户",
            avatarURL: nil
        )
    }

    @ViewBuilder
    private func ratingCommentAvatar(userID: String, username: String, avatarURL: String?) -> some View {
        if let resolved = AppConfig.resolvedURLString(avatarURL),
           let remoteURL = URL(string: resolved),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    Circle().fill(RaverTheme.cardBorder)
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    ratingCommentAvatarFallback(userID: userID, username: username, avatarURL: avatarURL)
                @unknown default:
                    ratingCommentAvatarFallback(userID: userID, username: username, avatarURL: avatarURL)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            ratingCommentAvatarFallback(userID: userID, username: username, avatarURL: avatarURL)
        }
    }

    private func ratingCommentAvatarFallback(userID: String, username: String, avatarURL: String?) -> some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: userID,
                username: username,
                avatarURL: avatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: 34, height: 34)
        .background(RaverTheme.cardBorder)
        .clipShape(Circle())
    }

    @MainActor
    private func refreshMyProfile() async {
        if let loaded = try? await socialService.fetchMyProfile() {
            myProfile = loaded
        }
    }

    @MainActor
    private func loadUnit() async {
        do {
            unit = try await webService.fetchRatingUnit(id: unitID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func addComment() async {
        guard canSendComment else { return }
        guard var unit else { return }

        let content = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let score = min(10, max(1, draftScore.rounded()))
        guard !content.isEmpty else { return }
        guard score >= 1 else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let created = try await webService.addRatingComment(
                unitID: unitID,
                input: CreateRatingCommentInput(score: score, content: content)
            )
            unit.comments.insert(created, at: 0)
            let scores = unit.comments.map(\.score)
            unit.ratingCount = scores.count
            unit.rating = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            self.unit = unit

            commentDraft = ""
            draftScore = 0
            errorMessage = nil
            onSubmitted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CreateRatingEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let webService = AppEnvironment.makeWebService()
    let onSubmit: (CreateRatingEventInput) async throws -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var imageURL = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var isSubmitting = false
    @State private var isUploadingCover = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("事件名称", text: $name)
                    TextField("事件描述（选填）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("封面图 URL（选填）", text: $imageURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? "上传封面图" : "更换封面图", systemImage: "photo")
                    }
                    if let selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if selectedCoverData != nil {
                        Text("已选择本地封面图，发布时会自动上传并使用该图片。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
            }
            .navigationTitle("发布打分事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("发布") {
                        Task { await submit() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || isUploadingCover)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
        }
    }

    @MainActor
    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            var finalImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await webService.uploadEventImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-event-cover-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalImageURL = upload.url
            }

            try await onSubmit(
                CreateRatingEventInput(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: finalImageURL.isEmpty ? nil : finalImageURL
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            selectedCoverData = nil
            return
        }
        do {
            selectedCoverData = try await item.loadTransferable(type: Data.self)
        } catch {
            selectedCoverData = nil
            errorMessage = "读取图片失败，请重试"
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }
}

private struct CreateRatingUnitSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let webService = AppEnvironment.makeWebService()
    let onSubmit: (CreateRatingUnitInput) async throws -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var imageURL = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var isSubmitting = false
    @State private var isUploadingCover = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("单位信息") {
                    TextField("单位名称", text: $name)
                    TextField("单位描述（选填）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("图片 URL（选填）", text: $imageURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? "上传单位图片" : "更换单位图片", systemImage: "photo")
                    }
                    if let selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if selectedCoverData != nil {
                        Text("已选择本地图片，发布时会自动上传并作为打分单位封面。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
            }
            .navigationTitle("发布打分单位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("发布") {
                        Task { await submit() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || isUploadingCover)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
        }
    }

    @MainActor
    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            var finalImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await webService.uploadEventImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-unit-cover-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalImageURL = upload.url
            }

            try await onSubmit(
                CreateRatingUnitInput(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: finalImageURL.isEmpty ? nil : finalImageURL
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            selectedCoverData = nil
            return
        }
        do {
            selectedCoverData = try await item.loadTransferable(type: Data.self)
        } catch {
            selectedCoverData = nil
            errorMessage = "读取图片失败，请重试"
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }
}

private struct HalfStarRatingReadOnlyView: View {
    let score: Double
    let maxScore: Double
    let starSize: CGFloat
    let spacing: CGFloat
    var expandsToFullWidth: Bool = false

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: symbolName(for: index))
                    .resizable()
                    .scaledToFit()
                    .frame(width: starSize, height: starSize)
                    .foregroundStyle(color(for: index))
                    .frame(maxWidth: expandsToFullWidth ? .infinity : nil)
            }
        }
    }

    private func symbolName(for index: Int) -> String {
        let normalized = normalizedScore
        if normalized >= Double(index) {
            return "star.fill"
        }
        if normalized >= Double(index) - 0.5 {
            return "star.leadinghalf.filled"
        }
        return "star"
    }

    private func color(for index: Int) -> Color {
        if normalizedScore >= Double(index) - 0.5 {
            return Color(red: 1.0, green: 0.73, blue: 0.20)
        }
        return Color.gray.opacity(0.45)
    }

    private var normalizedScore: Double {
        let safeMax = max(1, maxScore)
        let clamped = min(max(score, 0), safeMax)
        return clamped / 2
    }
}

private struct HalfStarDragRatingControl: View {
    @Binding var score: Double
    let maxScore: Double
    var expandsToFullWidth: Bool = false

    private let starSize: CGFloat = 24
    private let spacing: CGFloat = 6

    var body: some View {
        Group {
            if expandsToFullWidth {
                GeometryReader { proxy in
                    HalfStarRatingReadOnlyView(
                        score: score,
                        maxScore: maxScore,
                        starSize: starSize,
                        spacing: spacing,
                        expandsToFullWidth: true
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateScore(at: value.location.x, totalWidth: max(proxy.size.width, 1))
                            }
                    )
                }
                .frame(height: starSize)
            } else {
                HalfStarRatingReadOnlyView(
                    score: score,
                    maxScore: maxScore,
                    starSize: starSize,
                    spacing: spacing
                )
                .frame(width: controlWidth, height: starSize, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateScore(at: value.location.x, totalWidth: controlWidth)
                        }
                )
            }
        }
        .accessibilityLabel("星级评分")
        .accessibilityValue("\(Int(score))/10 分")
    }

    private var controlWidth: CGFloat {
        CGFloat(5) * starSize + CGFloat(4) * spacing
    }

    private func updateScore(at x: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        let clampedX = min(max(x, 0), totalWidth)
        let raw = Double(clampedX / totalWidth) * maxScore
        score = min(maxScore, max(0, raw.rounded()))
    }
}

private struct RatingSquareImage: View {
    let imageURL: String?
    let fallbackSymbol: String
    let size: CGFloat

    var body: some View {
        Group {
            if let imageURL = AppConfig.resolvedURLString(imageURL),
               let remoteURL = URL(string: imageURL),
               imageURL.hasPrefix("http://") || imageURL.hasPrefix("https://") {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(red: 0.24, green: 0.26, blue: 0.38), Color(red: 0.17, green: 0.55, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: fallbackSymbol)
                .font(.system(size: size * 0.33, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }
}

private struct CircleRatingEventRoute: Identifiable {
    let id: String
}
