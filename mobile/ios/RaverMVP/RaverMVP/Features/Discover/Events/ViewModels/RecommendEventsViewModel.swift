import Foundation
import Combine

@MainActor
final class RecommendEventsViewModel: ObservableObject {
    @Published private(set) var events: [WebEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var markedCheckinIDsByEventID: [String: String] = [:]
    @Published var errorMessage: String?

    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
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
            let page = try await service.fetchMyCheckins(page: 1, limit: 200, type: "event")
            let checkins = page.items.filter { $0.type.lowercased() == "event" && $0.eventId != nil }
            var markedMap: [String: String] = [:]
            for item in checkins {
                guard let eventID = item.eventId else { continue }
                let note = item.note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                if note == "marked" {
                    markedMap[eventID] = item.id
                }
            }
            markedCheckinIDsByEventID = markedMap
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
            if let checkinID = markedCheckinIDsByEventID[event.id] {
                try await service.deleteCheckin(id: checkinID)
                markedCheckinIDsByEventID[event.id] = nil
            } else {
                let created = try await service.createCheckin(
                    input: CreateCheckinInput(type: "event", eventId: event.id, djId: nil, note: "marked", rating: nil)
                )
                markedCheckinIDsByEventID[event.id] = created.id
            }
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
                let result = try await service.fetchEvents(
                    page: page,
                    limit: 100,
                    search: nil,
                    eventType: nil,
                    status: "all"
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
