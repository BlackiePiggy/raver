import Foundation
import Combine

@MainActor
final class RecommendEventsViewModel: ObservableObject {
    @Published private(set) var events: [WebEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var markedCheckinIDsByEventID: [String: String] = [:]
    @Published var errorMessage: String?

    private let fetchEventsPageUseCase: FetchDiscoverEventsPageUseCase
    private let fetchMarkedEventCheckinsUseCase: FetchMarkedEventCheckinsUseCase
    private let toggleMarkedEventUseCase: ToggleMarkedEventUseCase

    init(repository: DiscoverEventsRepository) {
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
            var uniqueByID: [String: WebEvent] = [:]
            var page = 1
            var totalPages = 1

            repeat {
                let result = try await fetchEventsPageUseCase.execute(
                    DiscoverEventsPageRequest(
                        page: page,
                        limit: 100,
                        search: nil,
                        eventType: nil,
                        status: "all"
                    )
                )
                for event in result.items {
                    uniqueByID[event.id] = event
                }
                totalPages = max(result.pagination?.totalPages ?? 1, 1)
                page += 1
            } while page <= totalPages

            let source = Array(uniqueByID.values).filter { event in
                EventVisualStatus.resolve(event: event) != .cancelled
            }

            events = Array(source.shuffled().prefix(10))
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
