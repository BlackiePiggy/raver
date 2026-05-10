import Foundation

struct SquadOfflineCoordinate: Codable, Hashable {
    var latitude: Double
    var longitude: Double
}

struct SquadOfflineLocationSnapshot: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double?
    var capturedAt: Date
}

struct SquadOfflineActivityParticipant: Codable, Identifiable, Hashable {
    let id: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var isFollowing: Bool
    var joinedAt: Date
    var leftAt: Date?
    var isInRestroom: Bool?
    var isBuyingDrink: Bool?
    var latestLocation: SquadOfflineLocationSnapshot?

    var isActive: Bool {
        leftAt == nil
    }
}

struct SquadOfflineActivityViewerSummary: Codable, Hashable {
    var restroomCount: Int?
    var buyingDrinkCount: Int?
}

struct SquadOfflineActivity: Codable, Identifiable, Hashable {
    let id: String
    var squadID: String
    var eventID: String?
    var eventName: String?
    var eventCoverImageURL: String?
    var eventVenueName: String?
    var eventVenueAddress: String?
    var eventAddressText: String?
    var eventCity: String?
    var eventCoordinate: SquadOfflineCoordinate?
    var title: String?
    var status: String
    var startedAt: Date
    var endedAt: Date?
    var createdBy: UserSummary?
    var isCreatedByMe: Bool
    var canManage: Bool
    var participantCount: Int
    var isJoined: Bool
    var uploadIntervalSeconds: Int
    var viewerSummary: SquadOfflineActivityViewerSummary?
    var viewerRoute: [SquadOfflineLocationSnapshot]? = nil
    var participants: [SquadOfflineActivityParticipant]

    var displayTitle: String? {
        let event = eventName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !event.isEmpty { return event }
        let activityTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return activityTitle.isEmpty ? nil : activityTitle
    }

    var activeParticipants: [SquadOfflineActivityParticipant] {
        participants.filter(\.isActive)
    }

    var durationSeconds: Int {
        let end = endedAt ?? Date()
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }

    var isEnded: Bool {
        endedAt != nil || status == "ended"
    }
}

struct StartSquadOfflineActivityInput: Codable {
    var eventID: String?
    var title: String?
}

struct SquadOfflineLocationUploadInput: Codable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double?
    var altitude: Double?
    var speed: Double?
    var heading: Double?
    var capturedAt: Date
}

struct SquadOfflineActivityStatusInput: Codable {
    var isInRestroom: Bool
    var isBuyingDrink: Bool
}

struct SquadOfflineActivityCardPayload: Codable, Hashable {
    var activityID: String
    var squadID: String
    var eventID: String?
    var title: String
    var eventName: String?
    var venueName: String?
    var city: String?
    var coverImageURL: String?
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var durationText: String
    var participantCount: Int
}

extension JSONDecoder {
    static func raverISO8601() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
