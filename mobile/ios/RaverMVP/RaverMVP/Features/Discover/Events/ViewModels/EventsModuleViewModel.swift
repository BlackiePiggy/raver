import Foundation
import Combine

struct DiscoverEventsPageRequest: Equatable {
    let page: Int
    let limit: Int
    let search: String?
    let eventType: String?
    let status: String?
}

protocol DiscoverEventsRepository {
    func fetchEvents(request: DiscoverEventsPageRequest) async throws -> EventListPage
    func fetchEvent(id: String) async throws -> WebEvent
    func createEvent(input: CreateEventInput) async throws -> WebEvent
    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent
    func uploadEventImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        eventID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
    func importEventLineupFromImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        startDate: Date?,
        endDate: Date?
    ) async throws -> EventLineupImageImportResponse
    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func fetchMyCheckins(page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage
    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin
    func updateCheckin(id: String, input: UpdateCheckinInput) async throws -> WebCheckin
    func deleteCheckin(id: String) async throws
    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent]
    func fetchEventDJSets(eventName: String) async throws -> [WebDJSet]
    func deleteEvent(id: String) async throws
}

struct DiscoverEventsRepositoryAdapter: DiscoverEventsRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchEvents(request: DiscoverEventsPageRequest) async throws -> EventListPage {
        try await service.fetchEvents(
            page: request.page,
            limit: request.limit,
            search: request.search,
            eventType: request.eventType,
            status: request.status
        )
    }

    func fetchEvent(id: String) async throws -> WebEvent {
        try await service.fetchEvent(id: id)
    }

    func createEvent(input: CreateEventInput) async throws -> WebEvent {
        try await service.createEvent(input: input)
    }

    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent {
        try await service.updateEvent(id: id, input: input)
    }

    func uploadEventImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        eventID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        try await service.uploadEventImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            eventID: eventID,
            usage: usage
        )
    }

    func importEventLineupFromImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        startDate: Date?,
        endDate: Date?
    ) async throws -> EventLineupImageImportResponse {
        try await service.importEventLineupFromImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            startDate: startDate,
            endDate: endDate
        )
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        try await service.fetchMyCheckins(page: page, limit: limit, type: type)
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage {
        try await service.fetchMyCheckins(page: page, limit: limit, type: type, eventID: eventID, djID: djID)
    }

    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin {
        try await service.createCheckin(input: input)
    }

    func updateCheckin(id: String, input: UpdateCheckinInput) async throws -> WebCheckin {
        try await service.updateCheckin(id: id, input: input)
    }

    func deleteCheckin(id: String) async throws {
        try await service.deleteCheckin(id: id)
    }

    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent] {
        try await service.fetchEventRatingEvents(eventID: eventID)
    }

    func fetchEventDJSets(eventName: String) async throws -> [WebDJSet] {
        try await service.fetchEventDJSets(eventName: eventName)
    }

    func deleteEvent(id: String) async throws {
        try await service.deleteEvent(id: id)
    }
}

struct FetchDiscoverEventsPageUseCase {
    private let repository: DiscoverEventsRepository

    init(repository: DiscoverEventsRepository) {
        self.repository = repository
    }

    func execute(_ request: DiscoverEventsPageRequest) async throws -> EventListPage {
        try await repository.fetchEvents(request: request)
    }
}

struct FetchMarkedEventCheckinsUseCase {
    private let repository: DiscoverEventsRepository

    init(repository: DiscoverEventsRepository) {
        self.repository = repository
    }

    func execute(limit: Int = 200) async throws -> [String: String] {
        let page = try await repository.fetchMyCheckins(page: 1, limit: limit, type: "event")
        let checkins = page.items.filter { $0.type.lowercased() == "event" && $0.eventId != nil && $0.isMarkedCheckin }
        var markedMap: [String: String] = [:]
        for item in checkins {
            guard let eventID = item.eventId else { continue }
            markedMap[eventID] = item.id
        }
        return markedMap
    }
}

struct ToggleMarkedEventUseCase {
    private let repository: DiscoverEventsRepository

    init(repository: DiscoverEventsRepository) {
        self.repository = repository
    }

    func execute(event: WebEvent, markedCheckinIDsByEventID: [String: String]) async throws -> [String: String] {
        var next = markedCheckinIDsByEventID

        if let checkinID = next[event.id] {
            try await repository.deleteCheckin(id: checkinID)
            next[event.id] = nil
        } else {
            let created = try await repository.createCheckin(
                input: CreateCheckinInput(type: "event", eventId: event.id, djId: nil, note: "marked", rating: nil)
            )
            next[event.id] = created.id
        }
        return next
    }
}

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

    private let repository: DiscoverEventsRepository
    private let fetchEventsPageUseCase: FetchDiscoverEventsPageUseCase
    private let fetchMarkedEventCheckinsUseCase: FetchMarkedEventCheckinsUseCase
    private let toggleMarkedEventUseCase: ToggleMarkedEventUseCase
    private let pageSize = 10

    private var currentAllQuery = AllQuery(search: "", eventTypeKey: "")
    private var nextAllPage = 1
    private var totalAllPages = 1
    private var allReloadToken = UUID()
    private var markedReloadToken = UUID()
    private var hasLoadedMarkedState = false

    init(repository: DiscoverEventsRepository) {
        self.repository = repository
        self.fetchEventsPageUseCase = FetchDiscoverEventsPageUseCase(repository: repository)
        self.fetchMarkedEventCheckinsUseCase = FetchMarkedEventCheckinsUseCase(repository: repository)
        self.toggleMarkedEventUseCase = ToggleMarkedEventUseCase(repository: repository)
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
            let result = try await fetchEventsPageUseCase.execute(
                DiscoverEventsPageRequest(
                    page: 1,
                    limit: pageSize,
                    search: query.searchParam,
                    eventType: query.eventTypeParam,
                    status: "upcoming"
                )
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
            let result = try await fetchEventsPageUseCase.execute(
                DiscoverEventsPageRequest(
                    page: pageToLoad,
                    limit: pageSize,
                    search: query.searchParam,
                    eventType: query.eventTypeParam,
                    status: "upcoming"
                )
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
            let markedMap = try await fetchMarkedEventCheckinsUseCase.execute()
            guard markedReloadToken == token else { return }

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
            let wasMarked = markedCheckinIDsByEventID[event.id] != nil
            markedCheckinIDsByEventID = try await toggleMarkedEventUseCase.execute(
                event: event,
                markedCheckinIDsByEventID: markedCheckinIDsByEventID
            )

            if wasMarked {
                markedEvents.removeAll { $0.id == event.id }
            } else {
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

        let repository = repository
        return await withTaskGroup(of: WebEvent?.self, returning: [WebEvent].self) { group in
            for id in ids.sorted() {
                group.addTask {
                    try? await repository.fetchEvent(id: id)
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
