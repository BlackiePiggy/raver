import Foundation
import Combine

@MainActor
final class RecommendEventsViewModel: ObservableObject {
    @Published private(set) var events: [WebEvent] = []
    @Published private(set) var phase: LoadPhase = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var markedCheckinIDsByEventID: [String: String] = [:]
    @Published var bannerMessage: String?
    @Published var errorMessage: String?

    private struct CachedDailyRecommendations {
        let dateKey: String
        let userKey: String
        let events: [WebEvent]
    }

    private static var cachedDailyRecommendations: CachedDailyRecommendations?
    private let fetchRecommendedEventsUseCase: FetchRecommendedDiscoverEventsUseCase
    private let fetchEventsPageUseCase: FetchDiscoverEventsPageUseCase
    private let fetchMarkedEventCheckinsUseCase: FetchMarkedEventCheckinsUseCase
    private let toggleMarkedEventUseCase: ToggleMarkedEventUseCase
    private var hasLoadedRecommendations = false

    init(
        recommendationRepository: EventRecommendationRepository,
        listRepository: EventListRepository,
        checkinRepository: EventCheckinRepository
    ) {
        self.fetchRecommendedEventsUseCase = FetchRecommendedDiscoverEventsUseCase(repository: recommendationRepository)
        self.fetchEventsPageUseCase = FetchDiscoverEventsPageUseCase(repository: listRepository)
        self.fetchMarkedEventCheckinsUseCase = FetchMarkedEventCheckinsUseCase(repository: checkinRepository)
        self.toggleMarkedEventUseCase = ToggleMarkedEventUseCase(repository: checkinRepository)
    }

    func loadIfNeeded(sessionUserID: String?) async {
        applyCachedRecommendationsIfAvailable(sessionUserID: sessionUserID)
        if hasLoadedRecommendations {
            await reloadMarkedState(isLoggedIn: sessionUserID != nil)
            return
        }
        await reload(sessionUserID: sessionUserID, force: false)
    }

    func reload(sessionUserID: String?, force: Bool = true) async {
        await reloadMarkedState(isLoggedIn: sessionUserID != nil)
        await loadRecommendations(sessionUserID: sessionUserID, force: force)
    }

    func reloadMarkedState(isLoggedIn: Bool) async {
        guard isLoggedIn else {
            markedCheckinIDsByEventID = [:]
            return
        }

        do {
            markedCheckinIDsByEventID = try await fetchMarkedEventCheckinsUseCase.execute()
        } catch {
            bannerMessage = error.userFacingMessage
        }
    }

    func toggleMarked(event: WebEvent, isLoggedIn: Bool) async {
        guard isLoggedIn else {
            bannerMessage = LT("请先登录再收藏活动", "Please log in before saving events.", "イベントを保存するにはログインしてください。")
            return
        }

        do {
            markedCheckinIDsByEventID = try await toggleMarkedEventUseCase.execute(
                event: event,
                markedCheckinIDsByEventID: markedCheckinIDsByEventID
            )
        } catch {
            bannerMessage = error.userFacingMessage
        }
    }

    private func loadRecommendations(sessionUserID: String?, force: Bool) async {
        guard !isLoading else { return }
        if !force, hasLoadedRecommendations, !events.isEmpty {
            return
        }

        applyCachedRecommendationsIfAvailable(sessionUserID: sessionUserID)
        let hadContent = !events.isEmpty
        isLoading = true
        if !hadContent {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            let recommended = try await fetchRecommendedEventsUseCase.execute(
                limit: 10,
                statuses: ["ongoing", "upcoming", "ended"]
            )
            if !recommended.isEmpty {
                events = recommended
                cacheRecommendations(recommended, sessionUserID: sessionUserID)
                hasLoadedRecommendations = true
                phase = .success
                bannerMessage = nil
                return
            }

            events = try await loadRecommendationsLegacy()
            cacheRecommendations(events, sessionUserID: sessionUserID)
            hasLoadedRecommendations = true
            phase = events.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            // Backward-compatible fallback for servers that have not deployed /v1/events/recommendations yet.
            do {
                events = try await loadRecommendationsLegacy()
                cacheRecommendations(events, sessionUserID: sessionUserID)
                hasLoadedRecommendations = true
                phase = events.isEmpty ? .empty : .success
                bannerMessage = nil
            } catch {
                let message = error.userFacingMessage ?? LT("推荐活动加载失败，请稍后重试", "Failed to load recommended events. Please try again later.", "おすすめイベントを読み込めませんでした。時間をおいて再試行してください。")
                if hadContent {
                    bannerMessage = message
                    phase = .success
                } else {
                    phase = .failure(message: message)
                }
            }
        }
    }

    private func applyCachedRecommendationsIfAvailable(sessionUserID: String?) {
        guard events.isEmpty,
              let cached = Self.cachedDailyRecommendations,
              cached.dateKey == Self.todayKey(),
              cached.userKey == Self.userCacheKey(sessionUserID),
              !cached.events.isEmpty else {
            return
        }
        events = cached.events
        phase = .success
        hasLoadedRecommendations = true
    }

    private func cacheRecommendations(_ events: [WebEvent], sessionUserID: String?) {
        guard !events.isEmpty else { return }
        Self.cachedDailyRecommendations = CachedDailyRecommendations(
            dateKey: Self.todayKey(),
            userKey: Self.userCacheKey(sessionUserID),
            events: events
        )
    }

    private static func userCacheKey(_ sessionUserID: String?) -> String {
        let trimmed = sessionUserID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "anonymous" : trimmed
    }

    private static func todayKey(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }

    private func loadRecommendationsLegacy() async throws -> [WebEvent] {
        let statuses = ["ongoing", "upcoming", "ended"]
        let perPage = 40
        var candidatesByStatus: [String: [WebEvent]] = [:]

        for status in statuses {
            candidatesByStatus[status] = try await loadLegacyCandidates(for: status, perPage: perPage)
        }

        var selected: [WebEvent] = []
        var selectedIDs = Set<String>()

        // Keep status diversity first when backend recommendation endpoint is unavailable.
        for status in statuses {
            guard let bucket = candidatesByStatus[status], !bucket.isEmpty else { continue }
            if let picked = bucket.shuffled().first(where: { !selectedIDs.contains($0.id) }) {
                selected.append(picked)
                selectedIDs.insert(picked.id)
            }
            if selected.count >= 10 {
                return selected
            }
        }

        let pool = statuses
            .flatMap { candidatesByStatus[$0] ?? [] }
            .shuffled()
        for event in pool where !selectedIDs.contains(event.id) {
            selected.append(event)
            selectedIDs.insert(event.id)
            if selected.count >= 10 {
                break
            }
        }
        return selected
    }

    private func loadLegacyCandidates(for status: String, perPage: Int) async throws -> [WebEvent] {
        let firstPage = try await fetchEventsPageUseCase.execute(
            DiscoverEventsPageRequest(
                page: 1,
                limit: perPage,
                search: nil,
                eventType: nil,
                status: status
            )
        )

        var merged = firstPage.items
        let totalPages = max(firstPage.pagination?.totalPages ?? 1, 1)
        if totalPages > 1 {
            let randomPage = Int.random(in: 1...totalPages)
            if randomPage > 1 {
                let randomPageResult = try await fetchEventsPageUseCase.execute(
                    DiscoverEventsPageRequest(
                        page: randomPage,
                        limit: perPage,
                        search: nil,
                        eventType: nil,
                        status: status
                    )
                )
                merged.append(contentsOf: randomPageResult.items)
            }
        }

        var uniqueByID: [String: WebEvent] = [:]
        for event in merged where EventVisualStatus.resolve(event: event) != .cancelled {
            uniqueByID[event.id] = event
        }
        return Array(uniqueByID.values)
    }
}
