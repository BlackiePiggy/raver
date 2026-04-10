import SwiftUI
import UIKit
import CoreText

struct DiscoverRecommendEventsRootView: View {
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        RecommendEventsModuleView(
            viewModel: RecommendEventsViewModel(repository: appContainer.discoverEventsRepository)
        )
    }
}

struct RecommendEventsModuleView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.discoverPush) private var discoverPush
    @StateObject private var viewModel: RecommendEventsViewModel

    private let cardCornerRadius: CGFloat = 28
    private static var didRegisterAlteHaasFont = false
    private static var didLogRecommendFontDiagnostics = false

    @State private var scrollPositionID: String?
    @State private var isLoopJumping = false

    private struct RecommendationLoopItem: Identifiable {
        let id: String
        let event: WebEvent
        let eventIndex: Int
        let replicaIndex: Int
    }

    private let loopReplicaCount = 31
    private var loopCenterReplica: Int { loopReplicaCount / 2 }

    init(viewModel: RecommendEventsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
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
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ensureRecommendFontRegistered()
            logRecommendFontDiagnosticsIfNeeded()
            await viewModel.reload(isLoggedIn: appState.session != nil)
        }
        .refreshable {
            await viewModel.reload(isLoggedIn: appState.session != nil)
        }
        .task(id: appState.session != nil) {
            await viewModel.reloadMarkedState(isLoggedIn: appState.session != nil)
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

    private var recommendationPager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(loopItems) { item in
                    recommendationCard(item.event)
                        .id(item.id)
                        .containerRelativeFrame(.vertical)
                        .scrollTransition(axis: .vertical) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.66)
                                .blur(radius: phase.isIdentity ? 0 : 2.4)
                                .rotation3DEffect(
                                    .degrees(phase.isIdentity ? 0 : 5.5),
                                    axis: (x: 1, y: 0, z: 0),
                                    perspective: 0.72
                                )
                                .saturation(phase.isIdentity ? 1.05 : 0.86)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPositionID)
        .overlay(alignment: .trailing) {
            pageIndicator
                .padding(.trailing, 10)
        }
        .onAppear {
            if scrollPositionID == nil {
                scrollPositionID = centerPageID(for: 0)
            }
        }
        .onChange(of: viewModel.events) { _, _ in
            let validIDs = Set(loopItems.map(\.id))
            if let current = scrollPositionID, validIDs.contains(current) {
                return
            }
            scrollPositionID = centerPageID(for: 0)
        }
        .onChange(of: scrollPositionID) { _, newValue in
            guard viewModel.events.count > 1, let newValue, !isLoopJumping,
                  let item = loopItemByID[newValue] else { return }
            let distanceToCenter = abs(item.replicaIndex - loopCenterReplica)
            if distanceToCenter >= 3 {
                jumpToLoopTarget(centerPageID(for: item.eventIndex))
            }
        }
    }

    private var pageIndicator: some View {
        let current = currentIndex
        return VStack(spacing: 6) {
            ForEach(viewModel.events.indices, id: \.self) { idx in
                Capsule()
                    .fill(idx == current ? Color.white.opacity(0.92) : Color.white.opacity(0.28))
                    .frame(width: idx == current ? 4 : 3, height: idx == current ? 22 : 10)
            }
        }
    }

    private var currentIndex: Int {
        guard let id = scrollPositionID else { return 0 }
        return loopItemByID[id]?.eventIndex ?? 0
    }

    private var loopItems: [RecommendationLoopItem] {
        guard !viewModel.events.isEmpty else { return [] }
        var items: [RecommendationLoopItem] = []
        for replica in 0..<loopReplicaCount {
            for (index, event) in viewModel.events.enumerated() {
                items.append(
                    RecommendationLoopItem(
                        id: loopID(replica: replica, event: event, eventIndex: index),
                        event: event,
                        eventIndex: index,
                        replicaIndex: replica
                    )
                )
            }
        }
        return items
    }

    private var loopItemByID: [String: RecommendationLoopItem] {
        Dictionary(uniqueKeysWithValues: loopItems.map { ($0.id, $0) })
    }

    private func loopID(replica: Int, event: WebEvent, eventIndex: Int) -> String {
        "loop-\(replica)-\(eventIndex)-\(event.id)"
    }

    private func centerPageID(for eventIndex: Int) -> String? {
        guard viewModel.events.indices.contains(eventIndex) else { return nil }
        return loopID(replica: loopCenterReplica, event: viewModel.events[eventIndex], eventIndex: eventIndex)
    }

    private func jumpToLoopTarget(_ target: String?) {
        guard let target else { return }
        isLoopJumping = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                scrollPositionID = target
            }
            try? await Task.sleep(nanoseconds: 80_000_000)
            isLoopJumping = false
        }
    }

    private func recommendationCard(_ event: WebEvent) -> some View {
        GeometryReader { proxy in
            let cardWidth = max(0, proxy.size.width - 20)
            let cardHeight = max(0, proxy.size.height - 20)
            let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

            Button {
                discoverPush(.eventDetail(eventID: event.id))
            } label: {
                ZStack {
                    recommendationCover(for: event)
                        .overlay(recommendationAtmosphereOverlay)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(cardShape)

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 0)

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
                            .font(recommendMetaFont(size: 15))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .padding(.bottom, 0)

                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .medium))
                                Text(recommendationDateText(for: event))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .font(recommendMetaFont(size: 14))
                            .foregroundStyle(Color.white.opacity(0.86))
                            .padding(.bottom, 1)

                            recommendationHeadline(event.name)
                        }
                        .layoutPriority(2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    }
                    .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
                }
                .frame(width: cardWidth, height: cardHeight, alignment: .center)
                .contentShape(cardShape)
                .overlay(
                    cardShape
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.40), radius: 20, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func recommendationCover(for event: WebEvent) -> some View {
        if let cover = AppConfig.resolvedURLString(event.coverAssetURL),
           let url = URL(string: cover) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Color.black.opacity(0.72)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                case .failure:
                    recommendationFallbackCover
                @unknown default:
                    recommendationFallbackCover
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            recommendationFallbackCover
        }
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
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.28),
                    .clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 280
            )
            .blendMode(.screen)
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
            .font(recommendHeadlineFont(size: size).leading(.tight))
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

    private func recommendHeadlineFont(size: CGFloat) -> Font {
        ensureRecommendFontRegistered()
        if UIFont(name: "AlteHaasGrotesk_Bold", size: size) != nil {
            return .custom("AlteHaasGrotesk_Bold", size: size)
        }
        return .custom(
            preferredFontName(
                candidates: ["Alte Haas Grotesk Bold", "Alte Haas Grotesk", "HelveticaNeue-Bold", "Arial-BoldMT", "AvenirNext-Bold"],
                fallback: "HelveticaNeue-Bold"
            ),
            size: size
        )
    }

    private func recommendMetaFont(size: CGFloat) -> Font {
        ensureRecommendFontRegistered()
        if UIFont(name: "AlteHaasGrotesk_Bold", size: size) != nil {
            return .custom("AlteHaasGrotesk_Bold", size: size)
        }
        return .custom(
            preferredFontName(
                candidates: ["Alte Haas Grotesk Bold", "Alte Haas Grotesk", "HelveticaNeue-Bold", "Arial-BoldMT", "AvenirNext-Bold"],
                fallback: "HelveticaNeue-Bold"
            ),
            size: size
        )
    }

    private func preferredFontName(candidates: [String], fallback: String) -> String {
        for candidate in candidates where UIFont(name: candidate, size: 15) != nil {
            return candidate
        }
        return fallback
    }

    private func ensureRecommendFontRegistered() {
        guard !Self.didRegisterAlteHaasFont else { return }
        guard let fontURL = Bundle.main.url(forResource: "altehaasgroteskbold", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        Self.didRegisterAlteHaasFont = true
    }

    private func logRecommendFontDiagnosticsIfNeeded() {
        guard !Self.didLogRecommendFontDiagnostics else { return }
        Self.didLogRecommendFontDiagnostics = true

        let englishHeadlineCandidates = ["AlteHaasGrotesk_Bold", "Alte Haas Grotesk Bold", "Alte Haas Grotesk", "HelveticaNeue-Bold", "Arial-BoldMT", "AvenirNext-Bold"]
        let englishMetaCandidates = ["AlteHaasGrotesk_Bold", "Alte Haas Grotesk Bold", "Alte Haas Grotesk", "HelveticaNeue-Bold", "Arial-BoldMT", "AvenirNext-Bold"]
        let chineseHeadlineCandidates = ["PingFangSC-Heavy", "STHeitiSC-Medium", "HiraginoSansGB-W6"]
        let chineseMetaCandidates = ["PingFangSC-Regular", "STHeitiSC-Light"]

        let resolvedEnglishHeadline = preferredFontName(candidates: englishHeadlineCandidates, fallback: "HelveticaNeue-Bold")
        let resolvedEnglishMeta = preferredFontName(candidates: englishMetaCandidates, fallback: "HelveticaNeue-Bold")
        let resolvedChineseHeadline = preferredFontName(candidates: chineseHeadlineCandidates, fallback: "PingFangSC-Heavy")
        let resolvedChineseMeta = preferredFontName(candidates: chineseMetaCandidates, fallback: "PingFangSC-Regular")

        let matchedAlteFonts = UIFont.familyNames
            .flatMap { family in UIFont.fontNames(forFamilyName: family) }
            .filter { $0.lowercased().contains("alte") }

        print("[RecommendFont] isChineseUI=\(isChineseUI) effectiveLanguage=\(AppLanguagePreference.current.effectiveLanguage.rawValue)")
        print("[RecommendFont] AlteHaasGrotesk_Bold available=\(UIFont(name: "AlteHaasGrotesk_Bold", size: 16) != nil)")
        print("[RecommendFont] resolvedEnglishHeadline=\(resolvedEnglishHeadline) resolvedEnglishMeta=\(resolvedEnglishMeta)")
        print("[RecommendFont] resolvedChineseHeadline=\(resolvedChineseHeadline) resolvedChineseMeta=\(resolvedChineseMeta)")
        print("[RecommendFont] loadedAlteFonts=\(matchedAlteFonts)")
    }

    private func recommendationPill(title: String, background: Color) -> some View {
        Text(title)
            .font(recommendMetaFont(size: 12))
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
        if let venue = event.venueName, !venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return venue
        }
        return L("地点待定", "Location TBA")
    }

    private func recommendationDateText(for event: WebEvent) -> String {
        event.startDate.appLocalizedDateRangeText(to: event.endDate)
    }
}
