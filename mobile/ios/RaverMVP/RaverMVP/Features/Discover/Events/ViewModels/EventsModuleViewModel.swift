import Foundation
import Combine

@MainActor
final class EventsModuleViewModel: ObservableObject {
    struct AllQuery: Equatable {
        let search: String
        let eventTypeKey: String

        var searchParam: String? {
            let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        var eventTypeParam: String? {
            EventTypeOption.submissionValue(for: eventTypeKey)
        }
    }

    @Published private(set) var allEvents: [WebEvent] = []
    @Published private(set) var markedEvents: [WebEvent] = []
    @Published private(set) var markedCheckinIDsByEventID: [String: String] = [:]
    @Published private(set) var isLoadingAll = false
    @Published private(set) var isLoadingMarked = false
    @Published private(set) var isLoadingMoreAll = false
    @Published var errorMessage: String?

    private let service: WebFeatureService
    private let pageSize = 10

    private var currentAllQuery = AllQuery(search: "", eventTypeKey: "")
    private var nextAllPage = 1
    private var totalAllPages = 1
    private var allReloadToken = UUID()
    private var markedReloadToken = UUID()
    private var hasLoadedMarkedState = false

    init(service: WebFeatureService) {
        self.service = service
    }

    var canLoadMoreAll: Bool {
        nextAllPage <= totalAllPages
    }

    func reloadAll(query: AllQuery, force: Bool = false) async {
        guard force || query != currentAllQuery || allEvents.isEmpty else { return }

        let token = UUID()
        allReloadToken = token
        currentAllQuery = query
        isLoadingAll = true
        errorMessage = nil

        do {
            let result = try await service.fetchEvents(
                page: 1,
                limit: pageSize,
                search: query.searchParam,
                eventType: query.eventTypeParam,
                status: "upcoming"
            )

            guard allReloadToken == token else { return }
            allEvents = result.items
            totalAllPages = result.pagination?.totalPages ?? 1
            nextAllPage = 2
        } catch {
            guard allReloadToken == token else { return }
            errorMessage = error.userFacingMessage
        }

        if allReloadToken == token {
            isLoadingAll = false
        }
    }

    func loadMoreAllIfNeeded(query: AllQuery) async {
        guard query == currentAllQuery else { return }
        guard !isLoadingAll, !isLoadingMoreAll, nextAllPage <= totalAllPages else { return }

        let pageToLoad = nextAllPage
        isLoadingMoreAll = true

        do {
            let result = try await service.fetchEvents(
                page: pageToLoad,
                limit: pageSize,
                search: query.searchParam,
                eventType: query.eventTypeParam,
                status: "upcoming"
            )

            guard query == currentAllQuery else { return }
            allEvents = mergeUnique(existing: allEvents, with: result.items)
            totalAllPages = result.pagination?.totalPages ?? totalAllPages
            nextAllPage = pageToLoad + 1
        } catch {
            if query == currentAllQuery {
                errorMessage = error.userFacingMessage
            }
        }

        if query == currentAllQuery {
            isLoadingMoreAll = false
        }
    }

    func reloadMarkedState(isLoggedIn: Bool, force: Bool = false) async {
        guard isLoggedIn else {
            markedReloadToken = UUID()
            hasLoadedMarkedState = false
            markedCheckinIDsByEventID = [:]
            markedEvents = []
            isLoadingMarked = false
            return
        }

        guard force || !hasLoadedMarkedState else { return }

        let token = UUID()
        markedReloadToken = token
        isLoadingMarked = true
        errorMessage = nil

        do {
            let page = try await service.fetchMyCheckins(page: 1, limit: 200, type: "event")
            guard markedReloadToken == token else { return }

            let checkins = page.items.filter { $0.type.lowercased() == "event" && $0.eventId != nil && $0.isMarkedCheckin }
            var markedMap: [String: String] = [:]
            for item in checkins {
                guard let eventID = item.eventId else { continue }
                markedMap[eventID] = item.id
            }

            markedCheckinIDsByEventID = markedMap
            let loadedEvents = await fetchEventsByIDs(Array(markedMap.keys))
            guard markedReloadToken == token else { return }

            markedEvents = loadedEvents.sorted(by: { $0.startDate < $1.startDate })
            hasLoadedMarkedState = true
        } catch {
            guard markedReloadToken == token else { return }
            errorMessage = error.userFacingMessage
        }

        if markedReloadToken == token {
            isLoadingMarked = false
        }
    }

    func toggleMarked(event: WebEvent, isLoggedIn: Bool) async {
        guard isLoggedIn else {
            errorMessage = L("请先登录再标记活动", "Please log in before marking events.")
            return
        }

        markedReloadToken = UUID()
        isLoadingMarked = false

        do {
            if let checkinID = markedCheckinIDsByEventID[event.id] {
                try await service.deleteCheckin(id: checkinID)
                markedCheckinIDsByEventID[event.id] = nil
                markedEvents.removeAll { $0.id == event.id }
            } else {
                let created = try await service.createCheckin(
                    input: CreateCheckinInput(type: "event", eventId: event.id, djId: nil, note: "marked", rating: nil)
                )
                markedCheckinIDsByEventID[event.id] = created.id
                insertMarkedEvent(event)
            }
            hasLoadedMarkedState = true
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func insertMarkedEvent(_ event: WebEvent) {
        if let index = markedEvents.firstIndex(where: { $0.id == event.id }) {
            markedEvents[index] = event
        } else {
            markedEvents.append(event)
        }
        markedEvents.sort(by: { $0.startDate < $1.startDate })
    }

    private func fetchEventsByIDs(_ ids: [String]) async -> [WebEvent] {
        guard !ids.isEmpty else { return [] }

        let service = service
        return await withTaskGroup(of: WebEvent?.self, returning: [WebEvent].self) { group in
            for id in ids.sorted() {
                group.addTask {
                    try? await service.fetchEvent(id: id)
                }
            }

            var result: [WebEvent] = []
            for await item in group {
                if let item {
                    result.append(item)
                }
            }
            return result
        }
    }

    private func mergeUnique(existing: [WebEvent], with incoming: [WebEvent]) -> [WebEvent] {
        var merged = existing
        var seen = Set(existing.map(\.id))
        for item in incoming where seen.insert(item.id).inserted {
            merged.append(item)
        }
        return merged
    }
}
