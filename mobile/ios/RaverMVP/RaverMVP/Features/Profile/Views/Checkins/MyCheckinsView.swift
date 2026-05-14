import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class MyCheckinsViewModel: ObservableObject {
    private enum PaginationSource {
        case overviewPrefetched
        case timelineAPI
    }

    let targetUserID: String?

    @Published var page = 1
    @Published var totalPages = 1
    @Published var canLoadMore = false
    @Published var timelineItems: [MyCheckinsOverviewTimelineItem] = []
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var bannerMessage: String?
    @Published var errorMessage: String?
    @Published var timelineDJIdentityByName: [String: CheckinDJLite] = [:]
    @Published var timelineDJIdentityByID: [String: CheckinDJLite] = [:]
    @Published var timelineLocalizedEventByID: [String: WebEvent] = [:]
    @Published var stats: MyCheckinsOverviewStats?
    @Published var galleryEvents: [MyCheckinsOverviewGalleryEvent] = []
    @Published var galleryArtists: [MyCheckinsOverviewGalleryArtist] = []
    @Published var galleryEventsPhase: LoadPhase = .idle
    @Published var galleryArtistsPhase: LoadPhase = .idle
    @Published var canLoadMoreGalleryEvents = false
    @Published var canLoadMoreGalleryArtists = false
    @Published var isLoadingGalleryEvents = false
    @Published var isLoadingGalleryArtists = false
    private var didLoadInitialPage = false
    private var nextPaginationSource: PaginationSource = .overviewPrefetched
    private var timelineLoadToken = 0
    private var lastRequestedTimelinePage: Int?
    private var galleryEventsPage = 1
    private var galleryArtistsPage = 1
    private var galleryEventsUseOverviewSummary = true
    private var galleryArtistsUseOverviewSummary = true
    private let timelinePageLimit = 20
    private let galleryPageLimit = 20
    private let repository: ProfileCheckinRepository

    init(
        targetUserID: String? = nil,
        repository: ProfileCheckinRepository
    ) {
        self.targetUserID = targetUserID
        self.repository = repository
    }

    func invalidateLoadedState() {
        didLoadInitialPage = false
        timelineLoadToken += 1
        lastRequestedTimelinePage = nil
    }

    func reload(force: Bool = false) async {
        if !force, didLoadInitialPage, !timelineItems.isEmpty, !isRefreshing {
            return
        }

        let hadContent = !timelineItems.isEmpty
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
            page = 1
            totalPages = 1
            canLoadMore = false
            timelineItems = []
            timelineDJIdentityByName = [:]
            timelineDJIdentityByID = [:]
            timelineLocalizedEventByID = [:]
            stats = nil
            galleryEvents = []
            galleryArtists = []
            galleryEventsPhase = .idle
            galleryArtistsPhase = .idle
            canLoadMoreGalleryEvents = false
            canLoadMoreGalleryArtists = false
            galleryEventsPage = 1
            galleryArtistsPage = 1
            galleryEventsUseOverviewSummary = true
            galleryArtistsUseOverviewSummary = true
            timelineLoadToken += 1
            lastRequestedTimelinePage = nil
        }
        defer { isRefreshing = false }
        await loadMore(reset: true)
    }

    func loadMore(reset: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if reset {
                let overview = try await fetchOverview()
                timelineDJIdentityByName = [:]
                timelineDJIdentityByID = [:]
                timelineLocalizedEventByID = [:]
                timelineItems = applyOverview(overview)
                print("[CheckinProjection] MyCheckins overview loaded items=\(timelineItems.count) ids=\(timelineItems.map(\.id).joined(separator: ","))")
                nextPaginationSource = .overviewPrefetched
                stats = overview.stats
                seedGallerySummary(from: overview)
                totalPages = overview.timeline.pagination.hasMore ? Int.max : 1
                page = 1
                canLoadMore = overview.timeline.pagination.hasMore
                phase = timelineItems.isEmpty ? .empty : .success
                didLoadInitialPage = true
                timelineLoadToken += 1
                lastRequestedTimelinePage = nil
                bannerMessage = nil
                return
            }

            let requestedPage = page
            guard requestedPage <= totalPages else {
                canLoadMore = false
                return
            }
            guard lastRequestedTimelinePage != requestedPage else { return }
            lastRequestedTimelinePage = requestedPage
            print("[CheckinProjection] MyCheckins timeline loadMore request page=\(requestedPage) totalPages=\(totalPages) currentItems=\(timelineItems.count)")
            let timelinePage = try await fetchTimelinePage(page: requestedPage, limit: timelinePageLimit)
            let nextItems = applyTimelinePage(timelinePage)

            if nextPaginationSource == .overviewPrefetched {
                timelineItems = mergeUniqueTimelineItems(timelineItems, with: nextItems)
                nextPaginationSource = .timelineAPI
            } else {
                timelineItems = mergeUniqueTimelineItems(timelineItems, with: nextItems)
            }

            totalPages = timelinePage.pagination?.totalPages ?? max(totalPages, requestedPage)
            page = requestedPage + 1
            canLoadMore = requestedPage < (timelinePage.pagination?.totalPages ?? requestedPage)
            if !canLoadMore {
                lastRequestedTimelinePage = nil
            }
            phase = timelineItems.isEmpty ? .empty : .success
            bannerMessage = nil
            print("[CheckinProjection] MyCheckins timeline loadMore finished page=\(requestedPage) received=\(nextItems.count) timelineItems=\(timelineItems.count) canLoadMore=\(canLoadMore)")
        } catch {
            if !reset {
                lastRequestedTimelinePage = nil
            }
            let message = error.userFacingMessage ?? L("打卡记录加载失败，请稍后重试", "Failed to load check-ins. Please try again later.")
            if reset {
                phase = .failure(message: message)
            } else if !timelineItems.isEmpty {
                bannerMessage = message
            } else {
                phase = .failure(message: message)
            }
        }
    }

    var currentTimelineLoadToken: Int {
        timelineLoadToken
    }

    func ensureGalleryEventsLoaded() async {
        guard galleryEventsUseOverviewSummary || galleryEventsPhase == .idle else { return }
        await loadMoreGalleryEvents(reset: true)
    }

    func ensureGalleryArtistsLoaded() async {
        guard galleryArtistsUseOverviewSummary || galleryArtistsPhase == .idle else { return }
        await loadMoreGalleryArtists(reset: true)
    }

    func loadMoreGalleryEvents(reset: Bool = false) async {
        guard !isLoadingGalleryEvents else { return }
        isLoadingGalleryEvents = true
        defer { isLoadingGalleryEvents = false }

        let shouldReplace = reset || galleryEventsUseOverviewSummary
        if galleryEvents.isEmpty {
            galleryEventsPhase = .initialLoading
        }

        do {
            let requestedPage = shouldReplace ? 1 : galleryEventsPage
            let page = try await fetchGalleryEventsPage(page: requestedPage, limit: galleryPageLimit)
            galleryEvents = shouldReplace
                ? page.items
                : mergeUniqueGalleryEvents(galleryEvents, with: page.items)
            galleryEventsPage = requestedPage + 1
            canLoadMoreGalleryEvents = requestedPage < (page.pagination?.totalPages ?? requestedPage)
            galleryEventsUseOverviewSummary = false
            galleryEventsPhase = galleryEvents.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? L("活动画廊加载失败，请稍后重试", "Failed to load event gallery. Please try again later.")
            if galleryEvents.isEmpty {
                galleryEventsPhase = .failure(message: message)
            } else {
                bannerMessage = message
                galleryEventsPhase = .success
            }
        }
    }

    func loadMoreGalleryArtists(reset: Bool = false) async {
        guard !isLoadingGalleryArtists else { return }
        isLoadingGalleryArtists = true
        defer { isLoadingGalleryArtists = false }

        let shouldReplace = reset || galleryArtistsUseOverviewSummary
        if galleryArtists.isEmpty {
            galleryArtistsPhase = .initialLoading
        }

        do {
            let requestedPage = shouldReplace ? 1 : galleryArtistsPage
            let page = try await fetchGalleryArtistsPage(page: requestedPage, limit: galleryPageLimit)
            galleryArtists = shouldReplace
                ? page.items
                : mergeUniqueGalleryArtists(galleryArtists, with: page.items)
            galleryArtistsPage = requestedPage + 1
            canLoadMoreGalleryArtists = requestedPage < (page.pagination?.totalPages ?? requestedPage)
            galleryArtistsUseOverviewSummary = false
            galleryArtistsPhase = galleryArtists.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? L("DJ 画廊加载失败，请稍后重试", "Failed to load DJ gallery. Please try again later.")
            if galleryArtists.isEmpty {
                galleryArtistsPhase = .failure(message: message)
            } else {
                bannerMessage = message
                galleryArtistsPhase = .success
            }
        }
    }

    private func fetchOverview() async throws -> MyCheckinsOverviewResponse {
        if let targetUserID {
            return try await repository.fetchUserCheckinsOverview(userID: targetUserID)
        }
        return try await repository.fetchMyCheckinsOverview()
    }

    private func fetchTimelinePage(page: Int, limit: Int) async throws -> MyCheckinsTimelinePage {
        if let targetUserID {
            return try await repository.fetchUserCheckinsTimeline(userID: targetUserID, page: page, limit: limit)
        }
        return try await repository.fetchMyCheckinsTimeline(page: page, limit: limit)
    }

    private func fetchGalleryEventsPage(page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage {
        if let targetUserID {
            return try await repository.fetchUserCheckinsGalleryEvents(userID: targetUserID, page: page, limit: limit)
        }
        return try await repository.fetchMyCheckinsGalleryEvents(page: page, limit: limit)
    }

    private func fetchGalleryArtistsPage(page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage {
        if let targetUserID {
            return try await repository.fetchUserCheckinsGalleryArtists(userID: targetUserID, page: page, limit: limit)
        }
        return try await repository.fetchMyCheckinsGalleryArtists(page: page, limit: limit)
    }

    func delete(id: String) async {
        do {
            try await repository.deleteCheckin(id: id)
            timelineItems.removeAll { $0.id == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func applyOverview(_ overview: MyCheckinsOverviewResponse) -> [MyCheckinsOverviewTimelineItem] {
        applyTimelineItems(overview.timeline.items)
    }

    private func seedGallerySummary(from overview: MyCheckinsOverviewResponse) {
        galleryEvents = overview.gallerySummary.topEvents
        galleryArtists = overview.gallerySummary.topArtists
        galleryEventsPage = 1
        galleryArtistsPage = 1
        galleryEventsUseOverviewSummary = true
        galleryArtistsUseOverviewSummary = true
        canLoadMoreGalleryEvents = overview.stats.eventCount > galleryEvents.count
        canLoadMoreGalleryArtists = overview.stats.artistCount > galleryArtists.count
        galleryEventsPhase = galleryEvents.isEmpty ? .idle : .success
        galleryArtistsPhase = galleryArtists.isEmpty ? .idle : .success
    }

    private func mergeUniqueGalleryEvents(
        _ base: [MyCheckinsOverviewGalleryEvent],
        with extras: [MyCheckinsOverviewGalleryEvent]
    ) -> [MyCheckinsOverviewGalleryEvent] {
        var merged = base
        var indexByID = Dictionary(uniqueKeysWithValues: base.enumerated().map { ($0.element.eventId, $0.offset) })
        for item in extras {
            if let existingIndex = indexByID[item.eventId] {
                merged[existingIndex] = item
                continue
            }
            indexByID[item.eventId] = merged.count
            merged.append(item)
        }
        return merged
    }

    private func mergeUniqueGalleryArtists(
        _ base: [MyCheckinsOverviewGalleryArtist],
        with extras: [MyCheckinsOverviewGalleryArtist]
    ) -> [MyCheckinsOverviewGalleryArtist] {
        var merged = base
        var indexByID = Dictionary(uniqueKeysWithValues: base.enumerated().map { ($0.element.id, $0.offset) })
        for item in extras {
            let key = item.id
            if let existingIndex = indexByID[key] {
                merged[existingIndex] = item
                continue
            }
            indexByID[key] = merged.count
            merged.append(item)
        }
        return merged
    }

    private func applyTimelinePage(_ page: MyCheckinsTimelinePage) -> [MyCheckinsOverviewTimelineItem] {
        for item in page.items {
            timelineLocalizedEventByID[item.event.id] = makeLocalizedEventDetail(from: item.event, timelineItem: item)
            seedTimelineDJIdentity(from: item)
        }
        return page.items
    }

    private func applyTimelineItems(_ timelineItems: [MyCheckinsOverviewTimelineItem]) -> [MyCheckinsOverviewTimelineItem] {
        timelineItems.map { item in
            timelineLocalizedEventByID[item.event.id] = makeLocalizedEventDetail(from: item.event, timelineItem: item)
            seedTimelineDJIdentity(from: item)
            return item
        }
    }

    private func mergeUniqueTimelineItems(
        _ base: [MyCheckinsOverviewTimelineItem],
        with extras: [MyCheckinsOverviewTimelineItem]
    ) -> [MyCheckinsOverviewTimelineItem] {
        var mergedByID: [String: MyCheckinsOverviewTimelineItem] = [:]
        for item in base + extras {
            if let existing = mergedByID[item.id] {
                if item.attendedAt > existing.attendedAt {
                    mergedByID[item.id] = item
                }
            } else {
                mergedByID[item.id] = item
            }
        }
        return mergedByID.values.sorted { lhs, rhs in
            if lhs.attendedAt == rhs.attendedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.attendedAt > rhs.attendedAt
        }
    }

    private func makeLocalizedEventDetail(
        from event: MyCheckinsOverviewTimelineEvent,
        timelineItem: MyCheckinsOverviewTimelineItem
    ) -> WebEvent {
        WebEvent(
            id: event.id,
            name: event.name ?? "",
            slug: "",
            description: "",
            countryI18n: event.country.map { WebBiText(en: $0, zh: $0) },
            cityI18n: event.city.map { WebBiText(en: $0, zh: $0) },
            coverImageUrl: event.coverImageUrl,
            lineupImageUrl: nil,
            eventType: "festival",
            organizerName: nil,
            city: event.city,
            country: event.country,
            manualLocation: event.address.map {
                WebEventManualLocation(
                    detailAddressI18n: WebBiText(en: $0, zh: $0),
                    formattedAddressI18n: WebBiText(en: $0, zh: $0),
                    selectedAt: timelineItem.createdAt
                )
            },
            latitude: nil,
            longitude: nil,
            startDate: event.startDate ?? timelineItem.attendedAt,
            endDate: event.endDate ?? timelineItem.attendedAt,
            ticketUrl: nil,
            ticketPriceMin: nil,
            ticketPriceMax: nil,
            ticketCurrency: nil,
            ticketNotes: nil,
            officialWebsite: nil,
            status: "ended",
            isVerified: true,
            createdAt: timelineItem.createdAt,
            updatedAt: timelineItem.createdAt,
            organizer: nil,
            ticketTiers: [],
            lineupSlots: []
        )
    }

    private func seedTimelineDJIdentity(from item: MyCheckinsOverviewTimelineItem) {
        for day in item.selections {
            for act in day.acts {
                for performer in act.performers {
                    let candidate = CheckinDJLite(
                        id: performer.djId ?? "performer-\(performer.performerIndex)-\(performer.name)",
                        name: performer.name,
                        avatarUrl: performer.avatarUrl,
                        country: performer.country
                    )
                    if let djId = performer.djId?.trimmingCharacters(in: .whitespacesAndNewlines), !djId.isEmpty {
                        timelineDJIdentityByID[djId] = mergedTimelineDJIdentity(
                            existing: timelineDJIdentityByID[djId],
                            candidate: candidate
                        )
                    }
                }
            }
        }
    }

    private func normalizedTimelineDJID(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("act-") || lowered.hasPrefix("solo-") || lowered.hasPrefix("unbound-") || lowered.contains("-performer-") {
            return nil
        }
        return trimmed
    }

    private func splitActNames(_ raw: String, keyword: String) -> [String]? {
        guard !raw.isEmpty else { return nil }
        let token = "__CHECKIN_SPLIT_TOKEN__"
        let pattern = "(?i)\\s*\(keyword)\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        let replaced = regex.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: token)
        let parts = replaced
            .components(separatedBy: token)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts
    }

    private func normalizedTimelineNameKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func mergedTimelineDJIdentity(existing: CheckinDJLite?, candidate: CheckinDJLite) -> CheckinDJLite {
        guard var existing else { return candidate }

        if (existing.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           !(candidate.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            existing.avatarUrl = candidate.avatarUrl
        }

        if (existing.country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           !(candidate.country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            existing.country = candidate.country
        }

        if existing.followerCount == nil {
            existing.followerCount = candidate.followerCount
        }
        if existing.soundCloudFollowers == nil {
            existing.soundCloudFollowers = candidate.soundCloudFollowers
        }

        let existingFollowers = existing.soundCloudFollowers ?? Int.min
        let candidateFollowers = candidate.soundCloudFollowers ?? Int.min
        if candidateFollowers > existingFollowers {
            existing.followerCount = candidate.followerCount
            existing.soundCloudFollowers = candidate.soundCloudFollowers
        }

        return existing
    }
}

private struct RaverCheckinsSegmentedControl<ID: Hashable>: View {
    let items: [ID]
    @Binding var selection: ID
    let title: (ID) -> String
    let iconName: (ID) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selection = item
                    }
                } label: {
                    segmentContent(for: item)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            RaverTheme.card.opacity(0.96),
                            RaverTheme.cardBorder.opacity(0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RaverTheme.cardBorder.opacity(0.72), lineWidth: 1)
        )
    }

    private func segmentContent(for item: ID) -> some View {
        let isSelected = selection == item

        return HStack(spacing: 7) {
            Image(systemName: iconName(item))
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(title(item))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .foregroundStyle(isSelected ? Color.white : RaverTheme.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.horizontal, 10)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RaverTheme.tabBarSelectionStart,
                                RaverTheme.accent,
                                RaverTheme.tabBarSelectionEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RaverTheme.tabBarSelectionStroke, lineWidth: 1)
                    )
                    .shadow(color: RaverTheme.tabBarShadowAccent, radius: 12, x: 0, y: 6)
                    .matchedGeometryEffect(id: "selected-segment", in: namespace)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @Namespace private var namespace
}

private struct MyCheckinsSharePresentation: Identifiable {
    let id = UUID()
    let payload: MyCheckinsShareCardPayload
}

private struct MyCheckinsSharePreviewCard: View {
    let payload: MyCheckinsShareCardPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverImageURL = payload.coverImageURL?.nilIfBlank {
                ZStack(alignment: .bottomLeading) {
                    ImageLoaderView(urlString: coverImageURL)
                        .frame(height: 142)
                        .clipped()

                    LinearGradient(
                        colors: [Color.black.opacity(0.06), Color.black.opacity(0.48)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    if let badgeText = payload.badgeText?.nilIfBlank {
                        Text(badgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.24), in: Capsule())
                            .padding(12)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if payload.coverImageURL?.nilIfBlank == nil,
                   let badgeText = payload.badgeText?.nilIfBlank {
                    Text(badgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if let summary = payload.summary?.nilIfBlank {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RaverTheme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RaverTheme.cardBorder.opacity(0.45), lineWidth: 1)
        )
    }
}

struct MyCheckinsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState
    @State private var pendingUnboundDJName: String?

    private struct TimelineDJEntry: Identifiable {
        let id: String
        let attendedAt: Date
        let dj: CheckinDJLite
    }

    private struct TimelineEventLite: Identifiable, Hashable {
        let id: String
        var name: String
        var nameI18n: WebBiText?
        var coverImageUrl: String?
        var address: String?
        var city: String?
        var country: String?
        var startDate: Date?
        var endDate: Date?

        var unifiedAddress: String {
            let explicitAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !explicitAddress.isEmpty { return explicitAddress }
            return [city, country]
                .compactMap { value in
                    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return trimmed.isEmpty ? nil : trimmed
                }
                .joined(separator: " · ")
        }
    }

    private struct TimelineNodeV2: Identifiable {
        let id: String
        var anchorDate: Date
        var day: Date
        let event: TimelineEventLite
        var structuredSelections: [EventAttendanceDaySelectionPayload]
        var summary: MyCheckinsOverviewTimelineSummary
    }

    private struct TimelineAttendanceSection: Identifiable {
        let id: String
        let title: String
        let djs: [TimelineDJEntry]
        var structuredDJSelections: [EventAttendanceDJSelection]?
    }

    private struct GalleryDJRankEntry: Identifiable {
        let id: String
        var dj: CheckinDJLite
        var count: Int
        var latestAttendedAt: Date
    }

    private struct GalleryDJCountSection: Identifiable {
        let id: String
        let count: Int
        let entries: [GalleryDJRankEntry]
    }

    private enum TimelineActType {
        case solo
        case b2b
        case b3b

        var performerCount: Int {
            switch self {
            case .solo: return 1
            case .b2b: return 2
            case .b3b: return 3
            }
        }

        var canonicalToken: String {
            switch self {
            case .solo: return "solo"
            case .b2b: return "b2b"
            case .b3b: return "b3b"
            }
        }
    }

    private enum TimelineCheckinAvatarSize {
        case small
        case medium
        case large

        var frameWidth: CGFloat {
            switch self {
            case .small:
                return TimelineAvatarLayout.performerSize
            case .medium:
                return TimelineAvatarLayout.contentWidth(for: 2) + TimelineAvatarLayout.mediumHorizontalInset * 2
            case .large:
                return TimelineAvatarLayout.contentWidth(for: 3) + TimelineAvatarLayout.largeHorizontalInset * 2
            }
        }

        var frameHeight: CGFloat { TimelineAvatarLayout.performerSize }
        var performerSize: CGFloat { TimelineAvatarLayout.performerSize }
    }

    private enum TimelineAvatarLayout {
        static let performerSize: CGFloat = 56
        static let groupSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 8
        static let mediumHorizontalInset: CGFloat = 4
        static let largeHorizontalInset: CGFloat = 7

        static func contentWidth(for performerCount: Int) -> CGFloat {
            guard performerCount > 0 else { return 0 }
            return performerSize + CGFloat(max(0, performerCount - 1)) * 68
        }
    }

    private struct TimelineActPerformer: Identifiable {
        let id: String
        let name: String
        let djID: String?
        let avatarUrl: String?
        let followerCount: Int?
    }

    private struct TimelineActEntry: Identifiable {
        let id: String
        let title: String
        let type: TimelineActType
        let performers: [TimelineActPerformer]
    }

    private struct TimelineLineupActPerformer {
        let name: String
        let djID: String?
        let avatarUrl: String?
    }

    private struct TimelineLineupResolvedAct {
        let type: TimelineActType
        let performers: [TimelineLineupActPerformer]
    }

    private enum DisplayMode: String, CaseIterable {
        case timeline
        case gallery

        var title: String {
            switch self {
            case .timeline: return L("时间轴", "Timeline")
            case .gallery: return L("画廊", "Gallery")
            }
        }

        var iconName: String {
            switch self {
            case .timeline: return "waveform.path.ecg"
            case .gallery: return "square.grid.2x2"
            }
        }
    }

    private enum GalleryMode: String, CaseIterable {
        case event
        case dj

        var title: String {
            switch self {
            case .event: return L("活动", "Events")
            case .dj: return "DJ"
            }
        }

        var iconName: String {
            switch self {
            case .event: return "calendar"
            case .dj: return "headphones"
            }
        }
    }

    private let targetUserID: String?
    private let navigationTitleText: String
    private let ownerDisplayName: String?

    @State private var displayMode: DisplayMode = .timeline
    @State private var galleryMode: GalleryMode = .event
    @State private var shareMorePresentation: MyCheckinsSharePresentation?
    @State private var fullChatSharePresentation: MyCheckinsSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var timelineAutoLoadTask: Task<Void, Never>?
    @State private var galleryAutoLoadTask: Task<Void, Never>?
    @State private var didTriggerTimelineAutoLoadInVisibleCycle = false
    @State private var didTriggerGalleryAutoLoadInVisibleCycle = false
    @StateObject private var viewModel: MyCheckinsViewModel

    init(
        repository: ProfileCheckinRepository,
        targetUserID: String? = nil,
        title: String = "",
        ownerDisplayName: String? = nil
    ) {
        self.targetUserID = targetUserID
        self.navigationTitleText = title.isEmpty ? L("我的打卡", "My Check-ins") : title
        self.ownerDisplayName = ownerDisplayName
        _viewModel = StateObject(
            wrappedValue: MyCheckinsViewModel(
                targetUserID: targetUserID,
                repository: repository
            )
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if viewModel.isRefreshing {
                            InlineLoadingBadge(title: L("正在更新打卡记录", "Updating check-ins"))
                        }
                        if let bannerMessage = viewModel.bannerMessage {
                            ScreenStatusBanner(
                                message: bannerMessage,
                                style: .error,
                                actionTitle: L("重试", "Retry")
                            ) {
                                Task { await viewModel.reload(force: true) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                RaverCheckinsSegmentedControl(
                    items: DisplayMode.allCases,
                    selection: $displayMode,
                    title: { $0.title },
                    iconName: { $0.iconName }
                )

                if displayMode == .gallery {
                    RaverCheckinsSegmentedControl(
                        items: GalleryMode.allCases,
                        selection: $galleryMode,
                        title: { $0.title },
                        iconName: { $0.iconName }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if viewModel.phase == .idle || viewModel.phase == .initialLoading {
                    FeedSkeletonView(count: 3)
                        .frame(maxWidth: .infinity)
                } else if case .failure(let message) = viewModel.phase {
                    ScreenErrorCard(
                        title: L("打卡记录加载失败", "Check-ins Failed to Load"),
                        message: message
                    ) {
                        Task { await viewModel.reload(force: true) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else if case .offline(let message) = viewModel.phase {
                    ScreenErrorCard(
                        title: L("网络不可用", "Network Unavailable"),
                        message: message
                    ) {
                        Task { await viewModel.reload(force: true) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else if isCurrentViewEmpty {
                    VStack(spacing: 12) {
                        ContentUnavailableView(LL("还没有观演记录"), systemImage: "sparkles.tv")
                        Text(LL("去发现页完成活动或 DJ 打卡，记录会按你选择的观演时间展示。"))
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    if displayMode == .timeline {
                        timelineView
                    } else {
                        galleryView
                    }
                    activeAutoLoadMoreSentinel
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(RaverTheme.background)
        .scrollIndicators(.hidden)
        .raverGradientNavigationChrome(
            title: navigationTitleText,
            trailing: navigationShareButton.eraseToAnyView()
        ) {
            dismiss()
        }
        .task(id: targetUserID ?? "me") {
            await viewModel.reload()
            if targetUserID == nil, !CheckinProjectionMutationStore.hasUnconsumedMutation {
                CheckinProjectionMutationStore.markConsumed(CheckinProjectionMutationStore.token)
            }
        }
        .onAppear {
            Task {
                await reconcileMissedCheckinMutationIfNeeded()
            }
        }
        .task(id: displayMode) {
            await ensureActiveGalleryLoaded()
        }
        .task(id: galleryMode) {
            await ensureActiveGalleryLoaded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .raverCheckinsDidMutate)) { notification in
            guard targetUserID == nil else { return }
            let checkinId = notification.object as? String ?? "unknown"
            print("[CheckinProjection] MyCheckins received raverCheckinsDidMutate checkinId=\(checkinId); invalidating loaded state and refreshing v2 read model")
            viewModel.invalidateLoadedState()
            Task {
                await viewModel.reload(force: true)
                await ensureActiveGalleryLoaded()
                CheckinProjectionMutationStore.markConsumed(CheckinProjectionMutationStore.token)
                print("[CheckinProjection] MyCheckins refresh finished after mutation checkinId=\(checkinId) phase=\(viewModel.phase) timelineItems=\(viewModel.timelineItems.count) galleryEvents=\(viewModel.galleryEvents.count) galleryArtists=\(viewModel.galleryArtists.count)")
            }
        }
        .refreshable {
            await viewModel.reload(force: true)
            await ensureActiveGalleryLoaded()
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try await sendSharePayload(
                        presentation.payload,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                showWidgetStatusBanner(
                    message: L("已分享到 \(conversation.title)", "Shared to \(conversation.title)"),
                    conversation: conversation
                )
            } preview: {
                MyCheckinsSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(L("DJ 信息待补充", "DJ Info Needed"), isPresented: Binding(
            get: { pendingUnboundDJName != nil },
            set: { if !$0 { pendingUnboundDJName = nil } }
        )) {
            Button(L("关闭", "Close"), role: .cancel) {
                pendingUnboundDJName = nil
            }
            Button(L("去补充", "Add Info")) {
                let name = pendingUnboundDJName
                pendingUnboundDJName = nil
                appPush(.discover(.djImport(initialName: name)))
            }
        } message: {
            Text(L("这个 DJ 暂未建立唯一档案，补充资料后就可以跳转到详情页。", "This DJ does not have a unique profile yet. Add the info to enable detail navigation."))
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(),
                        loadConversations: {
                            try await loadSharePanelConversations()
                        },
                        onSendToConversation: { conversation, note in
                            try await sendSharePayload(
                                presentation.payload,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        showWidgetStatusBanner(
                            message: L("已分享到 \(conversation.title)", "Shared to \(conversation.title)"),
                            conversation: conversation
                        )
                    } onMoreChats: {
                        dismissShareMorePanel {
                            fullChatSharePresentation = presentation
                        }
                    }
                }
                .onAppear {
                    withAnimation(.sharePanelPresentSpring) {
                        isShareMorePanelVisible = true
                    }
                }
            }
        }
        .operationBannerHost()
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
    }

    private var timelineItems: [MyCheckinsOverviewTimelineItem] { viewModel.timelineItems }
    private var timelineDJIdentityByName: [String: CheckinDJLite] {
        get { viewModel.timelineDJIdentityByName }
        nonmutating set { viewModel.timelineDJIdentityByName = newValue }
    }
    private var timelineDJIdentityByID: [String: CheckinDJLite] {
        get { viewModel.timelineDJIdentityByID }
        nonmutating set { viewModel.timelineDJIdentityByID = newValue }
    }
    private var timelineLocalizedEventByID: [String: WebEvent] {
        get { viewModel.timelineLocalizedEventByID }
        nonmutating set { viewModel.timelineLocalizedEventByID = newValue }
    }
    private var errorMessage: String? {
        get { viewModel.errorMessage }
        nonmutating set { viewModel.errorMessage = newValue }
    }
    private var effectiveOwnerDisplayName: String {
        if let trimmedOwnerDisplayName = ownerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmedOwnerDisplayName.isEmpty {
            return trimmedOwnerDisplayName
        }
        if targetUserID == nil,
           let sessionName = appState.session?.user.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
           !sessionName.isEmpty {
            return sessionName
        }
        return L("Ta", "They")
    }
    private var effectiveShareUserID: String? {
        if let trimmedTargetUserID = targetUserID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmedTargetUserID.isEmpty {
            return trimmedTargetUserID
        }
        if let sessionUserID = appState.session?.user.id.trimmingCharacters(in: .whitespacesAndNewlines),
           !sessionUserID.isEmpty {
            return sessionUserID
        }
        return nil
    }

    private var timelineNodes: [TimelineNodeV2] {
        buildTimelineNodes(from: timelineItems)
    }

    private var galleryEventNodes: [TimelineNodeV2] {
        timelineNodes
    }

    private var galleryDJEntries: [TimelineDJEntry] {
        timelineNodes
            .flatMap { node in
                timelineDJEntries(
                    from: node.structuredSelections,
                    attendedAt: node.anchorDate,
                    eventID: node.event.id
                )
            }
            .sorted { $0.attendedAt > $1.attendedAt }
    }

    private var galleryDJSections: [GalleryDJCountSection] {
        let ranked = viewModel.galleryArtists.map { artist in
            GalleryDJRankEntry(
                id: artist.id,
                dj: CheckinDJLite(
                    id: artist.djId ?? artist.id,
                    name: artist.name,
                    avatarUrl: artist.avatarUrl,
                    country: artist.country
                ),
                count: artist.count,
                latestAttendedAt: artist.latestAttendedAt
            )
        }

        let grouped = Dictionary(grouping: ranked, by: \.count)
        return grouped.keys
            .sorted(by: >)
            .map { count in
                GalleryDJCountSection(
                    id: "count-\(count)",
                    count: count,
                    entries: ranked.filter { $0.count == count }
                )
            }
    }

    private var checkinActivityCount: Int {
        viewModel.stats?.eventCount ?? timelineNodes.count
    }

    private var checkinArtistCount: Int {
        viewModel.stats?.artistCount ?? Set(
            galleryDJEntries.map { entry in
                galleryDJGroupingKey(for: resolvedGalleryDJ(entry.dj))
            }
        ).count
    }

    private var shareStatsSummaryText: String {
        L(
            "打卡\(checkinActivityCount)次活动、\(checkinArtistCount)个艺人",
            "Checked in at \(checkinActivityCount) events, \(checkinArtistCount) artists"
        )
    }

    private var timelineStatsText: String {
        L(
            "\(checkinActivityCount)次活动、\(checkinArtistCount)个艺人",
            "\(checkinActivityCount) events, \(checkinArtistCount) artists"
        )
    }

    private var isCurrentViewEmpty: Bool {
        switch displayMode {
        case .timeline:
            return timelineNodes.isEmpty
        case .gallery:
            if activeGalleryPhase == .initialLoading {
                return false
            }
            if case .failure = activeGalleryPhase {
                return false
            }
            return galleryMode == .event ? viewModel.galleryEvents.isEmpty : viewModel.galleryArtists.isEmpty
        }
    }

    private var activeGalleryPhase: LoadPhase {
        galleryMode == .event ? viewModel.galleryEventsPhase : viewModel.galleryArtistsPhase
    }

    private var galleryCanLoadMore: Bool {
        galleryMode == .event ? viewModel.canLoadMoreGalleryEvents : viewModel.canLoadMoreGalleryArtists
    }

    @ViewBuilder
    private var activeAutoLoadMoreSentinel: some View {
        switch displayMode {
        case .timeline:
            timelineAutoLoadMoreSentinel
        case .gallery:
            galleryAutoLoadMoreSentinel
        }
    }

    private func ensureActiveGalleryLoaded() async {
        guard displayMode == .gallery else { return }
        switch galleryMode {
        case .event:
            await viewModel.ensureGalleryEventsLoaded()
        case .dj:
            await viewModel.ensureGalleryArtistsLoaded()
        }
    }

    private func reconcileMissedCheckinMutationIfNeeded() async {
        guard targetUserID == nil else { return }
        let currentToken = CheckinProjectionMutationStore.token
        let consumedToken = CheckinProjectionMutationStore.consumedToken
        guard currentToken > consumedToken else { return }

        print("[CheckinProjection] MyCheckins detected missed mutation token consumed=\(consumedToken) current=\(currentToken); refreshing v2 read model")
        while viewModel.isLoading || viewModel.isRefreshing {
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        viewModel.invalidateLoadedState()
        await viewModel.reload(force: true)
        await ensureActiveGalleryLoaded()
        CheckinProjectionMutationStore.markConsumed(currentToken)
        print("[CheckinProjection] MyCheckins refresh finished after missed mutation token=\(currentToken) phase=\(viewModel.phase) timelineItems=\(viewModel.timelineItems.count) galleryEvents=\(viewModel.galleryEvents.count) galleryArtists=\(viewModel.galleryArtists.count)")
    }

    private func loadMoreActiveGallery() async {
        switch galleryMode {
        case .event:
            await viewModel.loadMoreGalleryEvents()
        case .dj:
            await viewModel.loadMoreGalleryArtists()
        }
    }

    private func triggerTimelineAutoLoadMore() {
        guard !didTriggerTimelineAutoLoadInVisibleCycle else { return }
        guard timelineAutoLoadTask == nil else { return }
        guard viewModel.canLoadMore, !viewModel.isLoading else { return }
        let loadToken = viewModel.currentTimelineLoadToken
        didTriggerTimelineAutoLoadInVisibleCycle = true
        timelineAutoLoadTask = Task {
            guard loadToken == viewModel.currentTimelineLoadToken else {
                timelineAutoLoadTask = nil
                return
            }
            await viewModel.loadMore()
            timelineAutoLoadTask = nil
        }
    }

    private func triggerGalleryAutoLoadMore() {
        guard !didTriggerGalleryAutoLoadInVisibleCycle else { return }
        guard galleryAutoLoadTask == nil else { return }
        didTriggerGalleryAutoLoadInVisibleCycle = true
        galleryAutoLoadTask = Task {
            await loadMoreActiveGallery()
            galleryAutoLoadTask = nil
        }
    }

    private func reloadActiveGallery() async {
        switch galleryMode {
        case .event:
            await viewModel.loadMoreGalleryEvents(reset: true)
        case .dj:
            await viewModel.loadMoreGalleryArtists(reset: true)
        }
    }

    private var navigationShareButton: some View {
        Button {
            guard let payload = makeSharePayload() else {
                errorMessage = L("当前打卡页暂时无法分享。", "This check-ins page cannot be shared right now.")
                return
            }
            shareMorePresentation = MyCheckinsSharePresentation(payload: payload)
            isShareMorePanelVisible = false
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func dismissShareMorePanel(after completion: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            completion?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = appContainer.shareMessageRepository.fetchConversations(type: .direct)
        async let groups = appContainer.shareMessageRepository.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendSharePayload(
        _ payload: MyCheckinsShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.shareMessageRepository.sendMyCheckinsCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await appContainer.shareMessageRepository.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                errorMessage = L("微信分享接口待接入。", "WeChat share hook is not connected yet.")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                errorMessage = L("QQ 分享接口待接入。", "QQ share hook is not connected yet.")
            }
        ]
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        [
            SharePanelQuickAction(
                title: L("举报", "Report"),
                systemImage: "flag",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                openCheckinsReportEntry()
            }
        ]
    }

    private func openCheckinsReportEntry() {
        errorMessage = L("举报入口即将开放，当前已记录该需求。", "Report entry is coming soon. We have recorded this request.")
    }

    private func makeSharePayload() -> MyCheckinsShareCardPayload? {
        guard let userID = effectiveShareUserID else { return nil }

        let coverImageURL = timelineItems
            .compactMap { $0.event.coverImageUrl?.nilIfBlank }
            .first
            ?? viewModel.galleryEvents.compactMap { $0.coverImageUrl?.nilIfBlank }.first
            ?? viewModel.galleryArtists.compactMap { $0.avatarUrl?.nilIfBlank }.first

        let shareTitle: String
        if let targetUserID, !targetUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            shareTitle = navigationTitleText
        } else {
            shareTitle = L("\(effectiveOwnerDisplayName)的打卡", "\(effectiveOwnerDisplayName)'s Check-ins")
        }

        return MyCheckinsShareCardPayload(
            userID: userID,
            displayName: effectiveOwnerDisplayName,
            title: shareTitle,
            summary: shareStatsSummaryText,
            coverImageURL: coverImageURL,
            badgeText: L("打卡", "Check-ins")
        )
    }

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(timelineStatsText)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.leading, 30)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.78, blue: 0.69),
                                Color(red: 0.99, green: 0.91, blue: 0.84),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
                    .padding(.leading, 11)
                    .padding(.top, 10)

                VStack(spacing: 26) {
                    ForEach(timelineNodes) { node in
                        timelineNodeRow(node)
                    }
                }
                .padding(.leading, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var galleryView: some View {
        Group {
            if activeGalleryPhase == .initialLoading {
                FeedSkeletonView(count: 3)
                    .frame(maxWidth: .infinity)
            } else if case .failure(let message) = activeGalleryPhase {
                ScreenErrorCard(
                    title: L("画廊加载失败", "Gallery Failed to Load"),
                    message: message
                ) {
                    Task { await reloadActiveGallery() }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                if galleryMode == .event {
                    galleryEventView
                } else {
                    galleryDJView
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var timelineAutoLoadMoreSentinel: some View {
        if viewModel.canLoadMore {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L("正在加载更多", "Loading more"))
                    .font(.footnote)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .onAppear {
                triggerTimelineAutoLoadMore()
            }
            .onDisappear {
                didTriggerTimelineAutoLoadInVisibleCycle = false
            }
        }
    }

    @ViewBuilder
    private var galleryAutoLoadMoreSentinel: some View {
        if galleryCanLoadMore {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L("正在加载更多", "Loading more"))
                    .font(.footnote)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .onAppear {
                triggerGalleryAutoLoadMore()
            }
            .onDisappear {
                didTriggerGalleryAutoLoadInVisibleCycle = false
            }
        }
    }

    private var galleryEventView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(viewModel.galleryEvents) { event in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        appPush(.eventDetail(eventID: event.eventId))
                    } label: {
                        galleryEventHero(for: event)
                            .frame(height: 124)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text(galleryEventTitle(for: event))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var galleryDJView: some View {
        let columns = [
            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top)
        ]

        return VStack(alignment: .leading, spacing: 16) {
            ForEach(galleryDJSections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("观看\(section.count)次", "Watched \(section.count)x"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.84, green: 0.42, blue: 0.28))

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(section.entries) { rankedEntry in
                            Button {
                                if let resolvedID = resolvedTimelineDetailDJID(for: rankedEntry.dj) {
                                    appPush(.djDetail(djID: resolvedID))
                                } else {
                                    presentUnboundDJPrompt(name: rankedEntry.dj.name)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    djAvatar(for: rankedEntry.dj)
                                        .frame(width: 72, height: 72)
                                    Text(rankedEntry.dj.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func timelineNodeRow(_ node: TimelineNodeV2) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(red: 0.98, green: 0.45, blue: 0.27))
                .frame(width: 12, height: 12)
                .background(
                    Circle()
                        .fill(RaverTheme.background)
                        .frame(width: 28, height: 28)
                )
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 12) {
                timelineTimestamp(for: node)
                timelineExperienceCard(node)
            }
        }
    }

    private func timelineTimestamp(for node: TimelineNodeV2) -> some View {
        Text(node.day.appLocalizedYMDWeekdayText())
            .font(.headline.weight(.bold))
            .foregroundStyle(RaverTheme.primaryText)
    }

    private func timelineExperienceCard(_ node: TimelineNodeV2) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            let event = node.event
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(eventNodeTitle(for: node))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let subtitle = eventNodeSubtitle(for: node, fallbackEvent: event) {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                .padding(.bottom, 12)

                Button {
                    appPush(.eventDetail(eventID: event.id))
                } label: {
                    eventHero(for: event)
                        .frame(height: 188)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }

            let attendanceSections = attendanceSections(for: node)
            if !attendanceSections.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(attendanceSections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 10) {
                                Text(section.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.84, green: 0.42, blue: 0.28))

                                Spacer()

                                checkinCountBadge(attendanceSectionDJCount(section))
                            }

                            if section.djs.isEmpty {
                                Text(LL("未选择 DJ"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
                                if let structured = section.structuredDJSelections {
                                    timelineStructuredDJGrid(structured, sectionID: section.id, node: node)
                                } else {
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
                                            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
                                            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
                                            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top)
                                        ],
                                        alignment: .leading,
                                        spacing: 10
                                    ) {
                                        ForEach(sortedTimelineDJEntries(section.djs)) { entry in
                                            timelineDJButton(entry)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.trailing, 4)
    }

    @ViewBuilder
    private func eventHero(for event: CheckinEventLite) -> some View {
        if let cover = AppConfig.resolvedURLString(event.coverImageUrl), let url = URL(string: cover) {
            ImageLoaderView(urlString: url.absoluteString)
                .background(eventTimelineFallback)
        } else {
            eventTimelineFallback
        }
    }

    @ViewBuilder
    private func eventHero(for event: TimelineEventLite) -> some View {
        if let cover = AppConfig.resolvedURLString(event.coverImageUrl), let url = URL(string: cover) {
            ImageLoaderView(urlString: url.absoluteString)
                .background(eventTimelineFallback)
        } else {
            eventTimelineFallback
        }
    }

    @ViewBuilder
    private func galleryEventHero(for event: MyCheckinsOverviewGalleryEvent) -> some View {
        if let cover = AppConfig.resolvedURLString(event.coverImageUrl), let url = URL(string: cover) {
            ImageLoaderView(urlString: url.absoluteString)
                .background(eventTimelineFallback)
        } else {
            eventTimelineFallback
        }
    }

    private func galleryEventTitle(for event: MyCheckinsOverviewGalleryEvent) -> String {
        let trimmed = event.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? L("未命名活动", "Untitled Event") : trimmed
    }

    private var eventTimelineFallback: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.70, blue: 0.54),
                Color(red: 0.84, green: 0.42, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            VStack(spacing: 10) {
                Image(systemName: "music.note.house.fill")
                    .font(.title)
                Text(L("音乐节回忆", "Festival Memory"))
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(Color.white.opacity(0.92))
        )
    }

    private func standaloneDJHeader(manualEventName: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(manualEventName ?? L("单独 DJ 打卡", "Standalone DJ Check-in"))
                .font(.title3.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)

            Text(
                manualEventName == nil
                    ? L("这次是单独的 DJ 打卡，暂无匹配活动。", "This is a standalone DJ check-in, with no matched event.")
                    : L("这次是单独的 DJ 打卡，暂无匹配活动，已按你填写的活动信息记录。", "This is a standalone DJ check-in. No matched event was found, so it was recorded with your custom event info.")
            )
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private func timelineDJButton(_ entry: TimelineDJEntry) -> some View {
        Button {
            if let resolvedID = resolvedTimelineDetailDJID(for: entry.dj) {
                appPush(.djDetail(djID: resolvedID))
            } else {
                presentUnboundDJPrompt(name: entry.dj.name)
            }
        } label: {
            VStack(spacing: 6) {
                djAvatar(for: entry.dj)
                    .frame(width: 54, height: 54)

                Text(entry.dj.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .top)
        }
        .buttonStyle(.plain)
    }

    private func timelineStructuredDJGrid(
        _ selections: [EventAttendanceDJSelection],
        sectionID: String,
        node: TimelineNodeV2
    ) -> some View {
        let acts = sortedTimelineActs(
            timelineActs(
                from: selections,
                sectionID: sectionID,
                eventID: node.event.id,
                dayID: sectionID
            )
        )
        let b3bActs = acts.filter { $0.type == .b3b }
        let b2bActs = acts.filter { $0.type == .b2b }
        let otherActs = acts.filter { $0.type == .solo }

        return VStack(alignment: .leading, spacing: TimelineAvatarLayout.groupSpacing) {
            if !b3bActs.isEmpty {
                VStack(alignment: .leading, spacing: TimelineAvatarLayout.sectionSpacing) {
                    Text("B3B")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    ForEach(b3bActs) { act in
                        timelineActItem(act, avatarSize: .large)
                    }
                }
            }

            if !b2bActs.isEmpty {
                VStack(alignment: .leading, spacing: TimelineAvatarLayout.sectionSpacing) {
                    Text("B2B")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: TimelineAvatarLayout.groupSpacing
                    ) {
                        ForEach(b2bActs) { act in
                            timelineActItem(act, avatarSize: .medium)
                        }
                    }
                }
            }

            if !otherActs.isEmpty {
                VStack(alignment: .leading, spacing: TimelineAvatarLayout.sectionSpacing) {
                    if !b2bActs.isEmpty || !b3bActs.isEmpty {
                        Text("Solo")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: TimelineAvatarLayout.groupSpacing
                    ) {
                        ForEach(otherActs) { act in
                            timelineActItem(act, avatarSize: .small)
                        }
                    }
                }
            }
        }
    }

    private func timelineActItem(_ act: TimelineActEntry, avatarSize: TimelineCheckinAvatarSize) -> some View {
        VStack(spacing: 7) {
            timelineActAvatars(act, size: avatarSize)

            Text(act.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func timelineActAvatars(_ act: TimelineActEntry, size: TimelineCheckinAvatarSize) -> some View {
        let avatarSize = size.performerSize
        Group {
            if act.type == .solo {
                timelineSoloActAvatar(act, avatarSize: avatarSize)
            } else {
                timelineCollaborativeActAvatars(act, avatarSize: avatarSize)
            }
        }
        .frame(width: size.frameWidth, height: size.frameHeight)
    }

    private func timelineSoloActAvatar(_ act: TimelineActEntry, avatarSize: CGFloat) -> some View {
        timelinePerformerAvatarButton(act.performers.first, size: avatarSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func timelineCollaborativeActAvatars(_ act: TimelineActEntry, avatarSize: CGFloat) -> some View {
        let performers = Array(act.performers.prefix(act.type.performerCount))
        let connectorText = act.type == .b2b ? "B2B" : "B3B"
        let connectorColor = timelineConnectorColor(for: act.type)

        return HStack(spacing: 10) {
            ForEach(Array(performers.enumerated()), id: \.offset) { index, performer in
                timelinePerformerAvatarButton(performer, size: avatarSize)
                if index < performers.count - 1 {
                    timelineActConnectorLabel(text: connectorText, color: connectorColor)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func timelineConnectorColor(for type: TimelineActType) -> Color {
        switch type {
        case .solo:
            return Color(red: 0.98, green: 0.52, blue: 0.20)
        case .b2b:
            return Color(red: 0.98, green: 0.52, blue: 0.20)
        case .b3b:
            return Color(red: 0.18, green: 0.74, blue: 0.92)
        }
    }

    @ViewBuilder
    private func timelinePerformerAvatarButton(_ performer: TimelineActPerformer?, size: CGFloat) -> some View {
        if let performer,
           let djID = performer.djID,
           !djID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
                appPush(.djDetail(djID: djID))
            } label: {
                timelinePerformerAvatar(performer, size: size)
            }
            .buttonStyle(.plain)
        } else {
            timelinePerformerAvatar(performer, size: size)
        }
    }

    private func timelinePerformerAvatar(_ performer: TimelineActPerformer?, size: CGFloat) -> some View {
        Group {
            if let avatar = AppConfig.resolvedDJAvatarURLString(performer?.avatarUrl, size: .small),
               let url = URL(string: avatar) {
                ImageLoaderView(urlString: url.absoluteString)
                    .background(timelinePerformerFallback(performer))
            } else {
                timelinePerformerFallback(performer)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func timelinePerformerFallback(_ performer: TimelineActPerformer?) -> some View {
        let initial = String((performer?.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1) ?? "?")).uppercased()
        return Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.67, blue: 0.97), Color(red: 0.42, green: 0.22, blue: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(initial)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white)
            )
    }

    private func timelineActConnectorLabel(text: String, color: Color) -> some View {
        Text("B")
            .font(.system(size: 8.5, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 10, height: 10)
            .background(color.opacity(0.14), in: Circle())
            .scaleEffect(1.2)
            .frame(width: 10, height: 24)
    }

    @ViewBuilder
    private func djAvatar(for dj: CheckinDJLite) -> some View {
        if let avatar = AppConfig.resolvedDJAvatarURLString(dj.avatarUrl, size: .small),
           let url = URL(string: avatar) {
            ImageLoaderView(urlString: url.absoluteString)
                .background(djAvatarFallback(for: dj))
            .clipShape(Circle())
        } else {
            djAvatarFallback(for: dj)
        }
    }

    private func djAvatarFallback(for dj: CheckinDJLite) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.67, blue: 0.97), Color(red: 0.42, green: 0.22, blue: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(dj.name.prefix(1)).uppercased())
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)
            )
    }

    private func eventNodeTitle(for node: TimelineNodeV2) -> String {
        if let fullEvent = localizedEventDetail(for: node) {
            let localizedName = fullEvent.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !localizedName.isEmpty { return localizedName }
        }
        let event = node.event
        if let localized = localizedBiText(event.nameI18n) {
            return localized
        }
        let trimmed = event.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L("未命名活动", "Untitled Event") : trimmed
    }

    private func eventNodeSubtitle(for node: TimelineNodeV2, fallbackEvent: TimelineEventLite) -> String? {
        if let fullEvent = localizedEventDetail(for: node) {
            let location = fullEvent.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            if !location.isEmpty { return location }
        }

        let event = fallbackEvent
        let unifiedLocation = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !unifiedLocation.isEmpty {
            return unifiedLocation
        }

        let fallbackCountry = event.country?.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = (fallbackCountry?.isEmpty == false) ? fallbackCountry : nil
        let city = event.city?.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = [city, country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
        return location.isEmpty ? nil : location
    }

    private func localizedEventDetail(for node: TimelineNodeV2) -> WebEvent? {
        timelineLocalizedEventByID[node.event.id]
    }

    private func localizedBiText(_ value: WebBiText?) -> String? {
        guard let value else { return nil }
        let text = value.text(for: AppLanguagePreference.current.effectiveLanguage)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func checkinCountBadge(_ count: Int) -> some View {
        Text(L("\(count) 位", "\(count) DJs"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(red: 0.82, green: 0.39, blue: 0.20))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(red: 1.00, green: 0.94, blue: 0.90), in: Capsule())
    }

    private func attendanceSectionDJCount(_ section: TimelineAttendanceSection) -> Int {
        guard let structured = section.structuredDJSelections else {
            return section.djs.count
        }

        return structured.reduce(0) { total, selection in
            let rawName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let names = splitActNames(rawName, keyword: "B3B"), names.count >= 3 {
                return total + 3
            }
            if let names = splitActNames(rawName, keyword: "B2B"), names.count >= 2 {
                return total + 2
            }
            return total + 1
        }
    }

    private func buildTimelineNodes(from items: [MyCheckinsOverviewTimelineItem]) -> [TimelineNodeV2] {
        items.map { item in
            let event = TimelineEventLite(
                id: item.event.id,
                name: item.event.name ?? "",
                nameI18n: item.event.nameI18n,
                coverImageUrl: item.event.coverImageUrl,
                address: item.event.address,
                city: item.event.city,
                country: item.event.country,
                startDate: item.event.startDate,
                endDate: item.event.endDate
            )
            return TimelineNodeV2(
                id: item.id,
                anchorDate: item.attendedAt,
                day: Calendar.current.startOfDay(for: item.attendedAt),
                event: event,
                structuredSelections: timelineSelectionPayloads(from: item.selections),
                summary: item.summary
            )
        }
        .sorted { lhs, rhs in
            if lhs.anchorDate == rhs.anchorDate {
                return lhs.id > rhs.id
            }
            return lhs.anchorDate > rhs.anchorDate
        }
    }

    private func timelineSelectionPayloads(
        from days: [MyCheckinsOverviewTimelineDay]
    ) -> [EventAttendanceDaySelectionPayload] {
        days
            .sorted { $0.dayIndex < $1.dayIndex }
            .map { day in
                EventAttendanceDaySelectionPayload(
                    dayID: day.dayId,
                    dayIndex: day.dayIndex,
                    djSelections: day.acts.map { act in
                        let primaryPerformer = act.performers.first
                        return EventAttendanceDJSelection(
                            id: act.actGroupId,
                            djId: act.actType == "solo" ? primaryPerformer?.djId : nil,
                            name: act.displayName,
                            avatarUrl: act.actType == "solo" ? primaryPerformer?.avatarUrl : nil,
                            country: act.actType == "solo" ? primaryPerformer?.country : nil,
                            actGroupId: act.actGroupId,
                            actType: act.actType,
                            performerIndex: primaryPerformer?.performerIndex,
                            performers: act.performers
                        )
                    }
                )
            }
    }

    private func timelineDJEntries(
        from selections: [EventAttendanceDaySelectionPayload],
        attendedAt: Date,
        eventID: String? = nil
    ) -> [TimelineDJEntry] {
        selections
            .sorted { $0.dayIndex < $1.dayIndex }
            .enumerated()
            .flatMap { sectionIndex, payload in
                payload.djSelections.enumerated().flatMap { index, selection in
                    timelineDJEntries(
                        from: selection,
                        attendedAt: attendedAt.addingTimeInterval(TimeInterval(sectionIndex * 100 + index)),
                        entryPrefix: "structured-\(payload.dayID)-\(selection.id)-\(index)",
                        eventID: eventID,
                        dayID: payload.dayID
                    )
                }
            }
    }

    private func timelineDJEntries(
        from selection: EventAttendanceDJSelection,
        attendedAt: Date,
        entryPrefix: String,
        eventID: String? = nil,
        dayID: String? = nil
    ) -> [TimelineDJEntry] {
        let rawName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawName.isEmpty else { return [] }
        if let performers = selection.performers, !performers.isEmpty {
            return performers
                .sorted { $0.performerIndex < $1.performerIndex }
                .enumerated()
                .map { offset, performer in
                    timelineResolvedDJEntry(
                        name: performer.name,
                        fallbackID: performer.djId ?? "\(selection.id)-performer-\(performer.performerIndex)",
                        attendedAt: attendedAt.addingTimeInterval(TimeInterval(offset)),
                        entryID: "\(entryPrefix)-performer-\(performer.performerIndex)",
                        explicitDJID: performer.djId.flatMap(normalizedTimelineDJID),
                        explicitAvatarURL: performer.avatarUrl,
                        explicitCountry: performer.country
                    )
                }
        }

        if let lineupAct = timelineResolveLineupAct(for: selection, eventID: eventID, dayID: dayID) {
            return lineupAct.performers.enumerated().map { offset, performer in
                timelineResolvedDJEntry(
                    name: performer.name,
                    fallbackID: performer.djID ?? "\(selection.id)-\(lineupAct.type.canonicalToken)-\(offset)",
                    attendedAt: attendedAt.addingTimeInterval(TimeInterval(offset)),
                    entryID: "\(entryPrefix)-\(lineupAct.type.canonicalToken)-\(offset)",
                    explicitDJID: normalizedTimelineDJID(performer.djID ?? ""),
                    explicitAvatarURL: performer.avatarUrl
                )
            }
        }

        if let names = splitActNames(rawName, keyword: "B3B"), names.count >= 3 {
            return Array(names.prefix(3).enumerated()).map { offset, name in
                timelineResolvedDJEntry(
                    name: name,
                    fallbackID: "\(selection.id)-b3b-\(offset)",
                    attendedAt: attendedAt.addingTimeInterval(TimeInterval(offset)),
                    entryID: "\(entryPrefix)-b3b-\(offset)",
                    explicitAvatarURL: selection.avatarUrl,
                    explicitCountry: selection.country
                )
            }
        }

        if let names = splitActNames(rawName, keyword: "B2B"), names.count >= 2 {
            return Array(names.prefix(2).enumerated()).map { offset, name in
                timelineResolvedDJEntry(
                    name: name,
                    fallbackID: "\(selection.id)-b2b-\(offset)",
                    attendedAt: attendedAt.addingTimeInterval(TimeInterval(offset)),
                    entryID: "\(entryPrefix)-b2b-\(offset)",
                    explicitAvatarURL: selection.avatarUrl,
                    explicitCountry: selection.country
                )
            }
        }

        return [
            timelineResolvedDJEntry(
                name: rawName,
                fallbackID: selection.id,
                attendedAt: attendedAt,
                entryID: entryPrefix,
                explicitDJID: selection.djId.flatMap(normalizedTimelineDJID),
                explicitAvatarURL: selection.avatarUrl,
                explicitCountry: selection.country
            )
        ]
    }

    private func timelineResolveLineupAct(
        for selection: EventAttendanceDJSelection,
        eventID: String?,
        dayID: String?
    ) -> TimelineLineupResolvedAct? {
        guard let eventID else { return nil }
        let actsByOptionID = timelineLineupActsByOptionID(for: eventID, dayID: dayID)
        let selectionID = selection.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selectionID.isEmpty, let exact = actsByOptionID[selectionID] {
            return exact
        }

        let rawName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let (type, names) = timelineSelectionActTypeAndNames(rawName) else { return nil }
        let canonical = timelineCanonicalActKey(type: type, performerNames: names)

        return actsByOptionID.values.first { timelineCanonicalActKey(for: $0) == canonical }
    }

    private func timelineLineupActsByOptionID(for eventID: String, dayID: String?) -> [String: TimelineLineupResolvedAct] {
        guard let event = timelineLocalizedEventByID[eventID] else { return [:] }

        var firstStartByOptionID: [String: Date] = [:]
        var result: [String: TimelineLineupResolvedAct] = [:]

        for slot in event.lineupSlots.sorted(by: { $0.startTime < $1.startTime }) {
            let dayIndex = timelineLineupDayIndex(
                for: slot,
                eventStartDate: event.startDate,
                dayRolloverHour: event.dayRolloverHour
            )
            let slotDayDate = timelineLineupDayDate(for: dayIndex, anchorDate: event.startDate)
            let slotDayID = timelineCheckinDayKey(for: slotDayDate)
            if let dayID, slotDayID != dayID {
                continue
            }

            guard let act = timelineParseLineupAct(slot: slot) else { continue }
            let displayName = timelineComposeActName(type: act.type, performerNames: act.performers.map(\.name))
            guard !displayName.isEmpty else { continue }

            let optionID: String = {
                if act.type == .solo, let djID = act.performers.first?.djID, !djID.isEmpty {
                    return djID
                }
                let canonical = timelineCanonicalActKey(for: act)
                if act.type == .solo {
                    return "solo-\(slotDayID)-\(canonical)"
                }
                return "act-\(slotDayID)-\(canonical)"
            }()

            let shouldReplace: Bool
            if let existingStart = firstStartByOptionID[optionID] {
                shouldReplace = slot.startTime < existingStart
            } else {
                shouldReplace = true
            }

            if shouldReplace {
                firstStartByOptionID[optionID] = slot.startTime
                result[optionID] = act
            }
        }

        return result
    }

    private func timelineParseLineupAct(slot: WebEventLineupSlot) -> TimelineLineupResolvedAct? {
        let preferredName = slot.djName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = slot.dj?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawName = preferredName.isEmpty ? fallbackName : preferredName
        let normalizedDJIDs = timelineNormalizedLineupDJIDs(from: slot)
        let slotAvatar = firstNonEmptyValue(
            slot.dj?.avatarSmallUrl,
            slot.dj?.avatarUrl,
            slot.dj?.avatarMediumUrl,
            slot.dj?.avatarOriginalUrl
        )
        guard let act = timelineParseLineupAct(name: rawName, djIDs: normalizedDJIDs, slotAvatar: slotAvatar) else {
            return nil
        }
        return timelineCanonicalizedLineupAct(act)
    }

    private func timelineParseLineupAct(
        name: String,
        djIDs: [String],
        slotAvatar: String?
    ) -> TimelineLineupResolvedAct? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let split = splitActNames(trimmed, keyword: "B3B"), split.count >= 3 {
            let names = Array(split.prefix(3))
            let performers = names.enumerated().map { index, item in
                let djID = index < djIDs.count ? djIDs[index] : nil
                let avatar = timelineAvatarURL(forDJID: djID, fallbackAvatar: index == 0 ? slotAvatar : nil)
                return TimelineLineupActPerformer(name: item, djID: djID, avatarUrl: avatar)
            }
            return TimelineLineupResolvedAct(type: .b3b, performers: performers)
        }

        if let split = splitActNames(trimmed, keyword: "B2B"), split.count >= 2 {
            let names = Array(split.prefix(2))
            let performers = names.enumerated().map { index, item in
                let djID = index < djIDs.count ? djIDs[index] : nil
                let avatar = timelineAvatarURL(forDJID: djID, fallbackAvatar: index == 0 ? slotAvatar : nil)
                return TimelineLineupActPerformer(name: item, djID: djID, avatarUrl: avatar)
            }
            return TimelineLineupResolvedAct(type: .b2b, performers: performers)
        }

        let soloDJID = djIDs.first
        let soloAvatar = timelineAvatarURL(forDJID: soloDJID, fallbackAvatar: slotAvatar)
        return TimelineLineupResolvedAct(
            type: .solo,
            performers: [TimelineLineupActPerformer(name: trimmed, djID: soloDJID, avatarUrl: soloAvatar)]
        )
    }

    private func timelineAvatarURL(forDJID djID: String?, fallbackAvatar: String?) -> String? {
        if let djID,
           let resolved = timelineDJIdentityByID[djID],
           let avatar = firstNonEmptyValue(resolved.avatarUrl) {
            return avatar
        }
        return firstNonEmptyValue(fallbackAvatar)
    }

    private func timelineCanonicalizedLineupAct(_ act: TimelineLineupResolvedAct) -> TimelineLineupResolvedAct {
        let performers = act.performers.map { performer in
            guard let djID = normalizedTimelineDJID(performer.djID ?? ""),
                  let resolved = timelineDJIdentityByID[djID] else {
                return performer
            }

            return TimelineLineupActPerformer(
                name: firstNonEmptyValue(resolved.name, performer.name) ?? performer.name,
                djID: performer.djID,
                avatarUrl: firstNonEmptyValue(performer.avatarUrl, resolved.avatarUrl)
            )
        }

        return TimelineLineupResolvedAct(type: act.type, performers: performers)
    }

    private func timelineNormalizedLineupDJIDs(from slot: WebEventLineupSlot) -> [String] {
        let rawIDs = (slot.djIds ?? []) + [slot.djId ?? ""]
        var result: [String] = []
        var seen = Set<String>()
        for raw in rawIDs {
            guard let normalized = normalizedTimelineDJID(raw) else { continue }
            if seen.insert(normalized).inserted {
                result.append(normalized)
            }
        }
        return result
    }

    private func timelineCanonicalActKey(for act: TimelineLineupResolvedAct) -> String {
        timelineCanonicalActKey(type: act.type, performerNames: act.performers.map(\.name))
    }

    private func timelineCanonicalActKey(type: TimelineActType, performerNames: [String]) -> String {
        let names = performerNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
        return "\(type.canonicalToken)-\(names)"
    }

    private func timelineComposeActName(type: TimelineActType, performerNames: [String]) -> String {
        let normalized = performerNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else { return "" }
        switch type {
        case .solo:
            return normalized[0]
        case .b2b:
            return normalized.prefix(2).joined(separator: " B2B ")
        case .b3b:
            return normalized.prefix(3).joined(separator: " B3B ")
        }
    }

    private func timelineSelectionActTypeAndNames(_ rawName: String) -> (TimelineActType, [String])? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let split = splitActNames(trimmed, keyword: "B3B"), split.count >= 3 {
            return (.b3b, Array(split.prefix(3)))
        }
        if let split = splitActNames(trimmed, keyword: "B2B"), split.count >= 2 {
            return (.b2b, Array(split.prefix(2)))
        }
        return (.solo, [trimmed])
    }

    private func timelineNormalizeDayRolloverHour(_ raw: Int?) -> Int {
        guard let raw, (0...23).contains(raw) else { return 6 }
        return raw
    }

    private func timelineLineupDayDate(for dayIndex: Int, anchorDate: Date) -> Date {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        guard dayIndex > 1 else { return anchorDay }
        return calendar.date(byAdding: .day, value: dayIndex - 1, to: anchorDay) ?? anchorDay
    }

    private func timelineLineupDayIndex(
        for slot: WebEventLineupSlot,
        eventStartDate: Date,
        dayRolloverHour: Int?
    ) -> Int {
        if let explicit = slot.festivalDayIndex, explicit > 0 {
            return explicit
        }
        return timelineLineupDayIndex(
            for: slot.startTime,
            eventStartDate: eventStartDate,
            dayRolloverHour: dayRolloverHour
        )
    }

    private func timelineLineupDayIndex(
        for date: Date,
        eventStartDate: Date,
        dayRolloverHour: Int?
    ) -> Int {
        let calendar = Calendar.current
        let rolloverHour = timelineNormalizeDayRolloverHour(dayRolloverHour)
        let anchorDay = calendar.startOfDay(for: eventStartDate)
        let targetDay = calendar.startOfDay(for: date)
        var dayOffset = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day ?? 0
        if dayOffset > 0 && calendar.component(.hour, from: date) < rolloverHour {
            dayOffset -= 1
        }
        return max(1, dayOffset + 1)
    }

    private func timelineCheckinDayKey(for date: Date) -> String {
        Self.timelineCheckinDayFormatter.string(from: date)
    }

    private static let timelineCheckinDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func timelineResolvedDJEntry(
        name: String,
        fallbackID: String,
        attendedAt: Date,
        entryID: String,
        explicitDJID: String? = nil,
        explicitAvatarURL: String? = nil,
        explicitCountry: String? = nil
    ) -> TimelineDJEntry {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedByID = explicitDJID.flatMap { timelineDJIdentityByID[$0] }
        let displayName = firstNonEmptyValue(resolvedByID?.name, cleanedName) ?? cleanedName

        let resolvedID: String = {
            if let explicitDJID, !explicitDJID.isEmpty { return explicitDJID }
            if let resolvedByID, !resolvedByID.id.isEmpty { return resolvedByID.id }
            return fallbackID
        }()

        let avatar = (explicitAvatarURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? explicitAvatarURL
            : resolvedByID?.avatarUrl
        let country = (explicitCountry?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? explicitCountry
            : resolvedByID?.country
        let followerCount = resolvedByID?.followerCount
        let soundCloudFollowers = resolvedByID?.soundCloudFollowers

        return TimelineDJEntry(
            id: entryID,
            attendedAt: attendedAt,
            dj: CheckinDJLite(
                id: resolvedID,
                name: displayName,
                avatarUrl: avatar,
                country: country,
                followerCount: followerCount,
                soundCloudFollowers: soundCloudFollowers
            )
        )
    }

    private func timelineActs(
        from selections: [EventAttendanceDJSelection],
        sectionID: String,
        eventID: String?,
        dayID: String?
    ) -> [TimelineActEntry] {
        selections.enumerated().compactMap { index, selection in
            timelineAct(
                from: selection,
                entryID: "\(sectionID)-\(index)",
                eventID: eventID,
                dayID: dayID
            )
        }
    }

    private func sortedTimelineActs(_ acts: [TimelineActEntry]) -> [TimelineActEntry] {
        acts
            .enumerated()
            .sorted { lhs, rhs in
                let leftFollowers = timelineActMaxFollowers(lhs.element)
                let rightFollowers = timelineActMaxFollowers(rhs.element)

                switch (leftFollowers, rightFollowers) {
                case let (left?, right?):
                    if left != right { return left > right }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }

                let leftName = timelineSortNameKey(lhs.element.title)
                let rightName = timelineSortNameKey(rhs.element.title)
                let nameCompare = leftName.localizedCaseInsensitiveCompare(rightName)
                if nameCompare != .orderedSame {
                    return nameCompare == .orderedAscending
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func sortedTimelineDJEntries(_ entries: [TimelineDJEntry]) -> [TimelineDJEntry] {
        entries
            .enumerated()
            .sorted { lhs, rhs in
                let leftFollowers = timelineDJFollowers(lhs.element.dj)
                let rightFollowers = timelineDJFollowers(rhs.element.dj)

                switch (leftFollowers, rightFollowers) {
                case let (left?, right?):
                    if left != right { return left > right }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }

                let leftName = timelineSortNameKey(lhs.element.dj.name)
                let rightName = timelineSortNameKey(rhs.element.dj.name)
                let nameCompare = leftName.localizedCaseInsensitiveCompare(rightName)
                if nameCompare != .orderedSame {
                    return nameCompare == .orderedAscending
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func timelineActMaxFollowers(_ act: TimelineActEntry) -> Int? {
        act.performers.compactMap { timelinePerformerFollowers($0) }.max()
    }

    private func timelinePerformerFollowers(_ performer: TimelineActPerformer) -> Int? {
        if let followers = performer.followerCount {
            return followers
        }

        if let djID = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !djID.isEmpty,
           let resolvedByID = timelineDJIdentityByID[djID] {
            if let followers = resolvedByID.soundCloudFollowers {
                return followers
            }
        }

        return nil
    }

    private func timelineDJFollowers(_ dj: CheckinDJLite) -> Int? {
        if let followers = dj.soundCloudFollowers {
            return followers
        }

        if let resolvedByID = timelineDJIdentityByID[dj.id] {
            if let followers = resolvedByID.soundCloudFollowers {
                return followers
            }
        }

        return nil
    }

    private func timelineSortNameKey(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func timelineAct(
        from selection: EventAttendanceDJSelection,
        entryID: String,
        eventID: String?,
        dayID: String?
    ) -> TimelineActEntry? {
        let rawName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawName.isEmpty else { return nil }
        if let performers = selection.performers, !performers.isEmpty {
            let actType = timelineActType(from: selection.actType, performerCount: performers.count)
            let resolvedPerformers = performers
                .sorted { $0.performerIndex < $1.performerIndex }
                .map { performer in
                    timelineActPerformer(
                        name: performer.name,
                        fallbackID: performer.djId ?? "\(entryID)-performer-\(performer.performerIndex)",
                        explicitDJID: performer.djId.flatMap(normalizedTimelineDJID),
                        explicitAvatarURL: performer.avatarUrl
                    )
                }
            return TimelineActEntry(
                id: "\(entryID)-\(selection.actGroupId ?? selection.id)",
                title: rawName,
                type: actType,
                performers: resolvedPerformers
            )
        }

        if let lineupAct = timelineResolveLineupAct(for: selection, eventID: eventID, dayID: dayID) {
            let performers = Array(lineupAct.performers.prefix(lineupAct.type.performerCount).enumerated()).map { offset, performer in
                timelineActPerformer(
                    name: performer.name,
                    fallbackID: "\(entryID)-\(lineupAct.type.canonicalToken)-\(offset)",
                    explicitDJID: normalizedTimelineDJID(performer.djID ?? ""),
                    explicitAvatarURL: performer.avatarUrl
                )
            }
            return TimelineActEntry(
                id: "\(entryID)-\(lineupAct.type.canonicalToken)",
                title: rawName,
                type: lineupAct.type,
                performers: performers
            )
        }

        if let names = splitActNames(rawName, keyword: "B3B"), names.count >= 3 {
            let performers = Array(names.prefix(3).enumerated()).map { offset, name in
                timelineActPerformer(name: name, fallbackID: "\(entryID)-b3b-\(offset)")
            }
            return TimelineActEntry(id: "\(entryID)-b3b", title: rawName, type: .b3b, performers: performers)
        }

        if let names = splitActNames(rawName, keyword: "B2B"), names.count >= 2 {
            let performers = Array(names.prefix(2).enumerated()).map { offset, name in
                timelineActPerformer(name: name, fallbackID: "\(entryID)-b2b-\(offset)")
            }
            return TimelineActEntry(id: "\(entryID)-b2b", title: rawName, type: .b2b, performers: performers)
        }

        let explicitID = selection.djId.flatMap(normalizedTimelineDJID)
        let performer = timelineActPerformer(
            name: rawName,
            fallbackID: "\(entryID)-solo",
            explicitDJID: explicitID,
            explicitAvatarURL: selection.avatarUrl
        )
        return TimelineActEntry(id: "\(entryID)-solo", title: rawName, type: .solo, performers: [performer])
    }

    private func timelineActType(from raw: String?, performerCount: Int) -> TimelineActType {
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "b3b":
            return .b3b
        case "b2b":
            return .b2b
        default:
            if performerCount >= 3 { return .b3b }
            if performerCount == 2 { return .b2b }
            return .solo
        }
    }

    private func timelineActPerformer(
        name: String,
        fallbackID: String,
        explicitDJID: String? = nil,
        explicitAvatarURL: String? = nil
    ) -> TimelineActPerformer {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lookupKey = normalizedTimelineNameKey(normalizedName)
        let resolved = timelineDJIdentityByName[lookupKey]
        let resolvedID = resolved?.id
        let resolvedByID = explicitDJID.flatMap { timelineDJIdentityByID[$0] }
        let resolvedAvatar = resolvedByID?.avatarUrl ?? resolved?.avatarUrl
        let resolvedFollowers = resolved?.soundCloudFollowers
        let resolvedByIDFollowers = resolvedByID?.soundCloudFollowers
        let djID = (explicitDJID?.isEmpty == false) ? explicitDJID : resolvedID
        let avatar = (explicitAvatarURL?.isEmpty == false) ? explicitAvatarURL : resolvedAvatar
        let followers = resolvedByIDFollowers ?? resolvedFollowers
        let displayName = firstNonEmptyValue(resolvedByID?.name, resolved?.name, normalizedName) ?? normalizedName

        return TimelineActPerformer(
            id: fallbackID,
            name: displayName,
            djID: djID,
            avatarUrl: avatar,
            followerCount: followers
        )
    }

    private func splitActNames(_ raw: String, keyword: String) -> [String]? {
        guard !raw.isEmpty else { return nil }
        let token = "__CHECKIN_SPLIT_TOKEN__"
        let pattern = "(?i)\\s*\(keyword)\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        let replaced = regex.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: token)
        let parts = replaced
            .components(separatedBy: token)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts
    }

    private func normalizedTimelineDJID(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("act-") || lowered.hasPrefix("solo-") || lowered.hasPrefix("unbound-") || lowered.contains("-performer-") {
            return nil
        }
        return trimmed
    }

    private func presentUnboundDJPrompt(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUnboundDJName = trimmedName.isEmpty ? LL("待补充 DJ") : trimmedName
    }

    private func galleryDJGroupingKey(for dj: CheckinDJLite) -> String {
        if let resolvedID = resolvedTimelineDetailDJID(for: dj)?.lowercased(), !resolvedID.isEmpty {
            return "id:\(resolvedID)"
        }
        return "raw:\(dj.id.lowercased())"
    }

    private func resolvedGalleryDJ(_ dj: CheckinDJLite) -> CheckinDJLite {
        let resolvedID = resolvedTimelineDetailDJID(for: dj) ?? dj.id
        let resolvedByID = timelineDJIdentityByID[resolvedID]

        let avatar = firstNonEmptyValue(dj.avatarUrl, resolvedByID?.avatarUrl)
        let country = firstNonEmptyValue(dj.country, resolvedByID?.country)
        let followerCount = dj.followerCount ?? resolvedByID?.followerCount
        let soundCloudFollowers = dj.soundCloudFollowers ?? resolvedByID?.soundCloudFollowers
        let displayName = firstNonEmptyValue(resolvedByID?.name, dj.name) ?? dj.name

        return CheckinDJLite(
            id: resolvedID,
            name: displayName,
            avatarUrl: avatar,
            country: country,
            followerCount: followerCount,
            soundCloudFollowers: soundCloudFollowers
        )
    }

    private func mergedGalleryDJIdentity(existing: CheckinDJLite, candidate: CheckinDJLite) -> CheckinDJLite {
        let existingResolvedID = resolvedTimelineDetailDJID(for: existing)
        let candidateResolvedID = resolvedTimelineDetailDJID(for: candidate)

        let mergedID = candidateResolvedID
            ?? existingResolvedID
            ?? normalizedTimelineDJID(existing.id)
            ?? normalizedTimelineDJID(candidate.id)
            ?? existing.id

        let mergedName = firstNonEmptyValue(timelineDJIdentityByID[mergedID]?.name, existing.name, candidate.name) ?? existing.name
        let mergedAvatar = firstNonEmptyValue(existing.avatarUrl, candidate.avatarUrl)
        let mergedCountry = firstNonEmptyValue(existing.country, candidate.country)

        let existingFollowers = existing.soundCloudFollowers ?? Int.min
        let candidateFollowers = candidate.soundCloudFollowers ?? Int.min
        let preferredByFollowers = candidateFollowers > existingFollowers ? candidate : existing
        let mergedFollowerCount = preferredByFollowers.followerCount ?? existing.followerCount ?? candidate.followerCount
        let mergedSoundCloudFollowers = preferredByFollowers.soundCloudFollowers ?? existing.soundCloudFollowers ?? candidate.soundCloudFollowers

        return CheckinDJLite(
            id: mergedID,
            name: mergedName,
            avatarUrl: mergedAvatar,
            country: mergedCountry,
            followerCount: mergedFollowerCount,
            soundCloudFollowers: mergedSoundCloudFollowers
        )
    }

    private func firstNonEmptyValue(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private func resolvedTimelineDetailDJID(for dj: CheckinDJLite) -> String? {
        if let normalizedID = normalizedTimelineDJID(dj.id) {
            return normalizedID
        }
        return nil
    }

    private func normalizedTimelineNameKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func mergedTimelineDJIdentity(existing: CheckinDJLite?, candidate: CheckinDJLite) -> CheckinDJLite {
        guard var existing else { return candidate }

        if (existing.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           !(candidate.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            existing.avatarUrl = candidate.avatarUrl
        }

        if (existing.country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           !(candidate.country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            existing.country = candidate.country
        }

        if existing.followerCount == nil {
            existing.followerCount = candidate.followerCount
        }
        if existing.soundCloudFollowers == nil {
            existing.soundCloudFollowers = candidate.soundCloudFollowers
        }

        let existingFollowers = existing.soundCloudFollowers ?? Int.min
        let candidateFollowers = candidate.soundCloudFollowers ?? Int.min
        if candidateFollowers > existingFollowers {
            existing.followerCount = candidate.followerCount
            existing.soundCloudFollowers = candidate.soundCloudFollowers
        }

        return existing
    }

    private func attendanceSections(for node: TimelineNodeV2) -> [TimelineAttendanceSection] {
        if !node.structuredSelections.isEmpty {
            return node.structuredSelections
                .sorted { $0.dayIndex < $1.dayIndex }
                .map { selection in
                    TimelineAttendanceSection(
                        id: selection.dayID,
                        title: "Day\(selection.dayIndex)",
                        djs: timelineDJEntries(
                            from: [selection],
                            attendedAt: node.anchorDate,
                            eventID: node.event.id
                        ),
                        structuredDJSelections: selection.djSelections
                    )
                }
        }

        guard let title = fallbackDayLabel(for: node) else { return [] }
        return [
            TimelineAttendanceSection(
                id: "fallback-\(node.id)",
                title: title,
                djs: [],
                structuredDJSelections: nil
            )
        ]
    }

    private func fallbackDayLabel(for node: TimelineNodeV2) -> String? {
        let event = node.event
        guard let startDate = event.startDate else { return nil }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let currentDay = calendar.startOfDay(for: node.day)
        let dayOffset = calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0
        let totalDaySpan = event.endDate.map {
            max(1, (calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: $0)).day ?? 0) + 1)
        } ?? 1
        guard totalDaySpan > 1, dayOffset >= 0 else { return nil }
        return "Day\(dayOffset + 1)"
    }

    private func manualEventName(from note: String?) -> String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("manual_event:") else { return nil }
        let rawName = String(trimmed.dropFirst("manual_event:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return rawName.isEmpty ? nil : rawName
    }

    private func normalizedStandaloneEventKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9\\u4e00-\\u9fa5-]", with: "", options: .regularExpression)
    }

}
