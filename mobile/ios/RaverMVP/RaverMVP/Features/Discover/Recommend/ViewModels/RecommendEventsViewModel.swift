import Foundation
import Combine

@MainActor
final class RecommendEventsViewModel: ObservableObject {
    @Published private(set) var events: [WebEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var markedCheckinIDsByEventID: [String: String] = [:]
    @Published var errorMessage: String?

    private let fetchRecommendedEventsUseCase: FetchRecommendedDiscoverEventsUseCase
    private let fetchEventsPageUseCase: FetchDiscoverEventsPageUseCase
    private let fetchMarkedEventCheckinsUseCase: FetchMarkedEventCheckinsUseCase
    private let toggleMarkedEventUseCase: ToggleMarkedEventUseCase

    init(repository: DiscoverEventsRepository) {
        self.fetchRecommendedEventsUseCase = FetchRecommendedDiscoverEventsUseCase(repository: repository)
        self.fetchEventsPageUseCase = FetchDiscoverEventsPageUseCase(repository: repository)
        self.fetchMarkedEventCheckinsUseCase = FetchMarkedEventCheckinsUseCase(repository: repository)
        self.toggleMarkedEventUseCase = ToggleMarkedEventUseCase(repository: repository)
    }

    func reload(isLoggedIn: Bool) async {
        await reloadMarkedState(isLoggedIn: isLoggedIn)
        await loadRecommendations()
    }

    func reloadMarkedState(isLoggedIn: Bool) async {
        guard isLoggedIn else {
            markedCheckinIDsByEventID = [:]
            return
        }

        do {
            markedCheckinIDsByEventID = try await fetchMarkedEventCheckinsUseCase.execute()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func toggleMarked(event: WebEvent, isLoggedIn: Bool) async {
        guard isLoggedIn else {
            errorMessage = L("请先登录再收藏活动", "Please log in before saving events.")
            return
        }

        do {
            markedCheckinIDsByEventID = try await toggleMarkedEventUseCase.execute(
                event: event,
                markedCheckinIDsByEventID: markedCheckinIDsByEventID
            )
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func loadRecommendations() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let recommended = try await fetchRecommendedEventsUseCase.execute(
                limit: 10,
                statuses: ["ongoing", "upcoming", "ended"]
            )
            if !recommended.isEmpty {
                events = recommended
                return
            }

            events = try await loadRecommendationsLegacy()
        } catch {
            // Backward-compatible fallback for servers that have not deployed /v1/events/recommendations yet.
            do {
                events = try await loadRecommendationsLegacy()
            } catch {
                errorMessage = error.userFacingMessage
            }
        }
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
