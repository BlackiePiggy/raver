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

protocol SquadActivityRepository {
    func fetchSquadProfile(squadID: String) async throws -> SquadProfile
    func fetchCurrentSquadOfflineActivity(squadID: String) async throws -> SquadOfflineActivity?
    func fetchSquadOfflineActivityHistory(squadID: String) async throws -> [SquadOfflineActivity]
    func startSquadOfflineActivity(squadID: String, input: StartSquadOfflineActivityInput) async throws -> SquadOfflineActivity
    func endSquadOfflineActivity(squadID: String, activityID: String) async throws -> SquadOfflineActivity?
    func joinSquadOfflineActivity(squadID: String, activityID: String) async throws -> SquadOfflineActivity
    func leaveSquadOfflineActivity(squadID: String, activityID: String) async throws -> SquadOfflineActivity?
    func removeSquadOfflineActivityParticipant(squadID: String, activityID: String, participantUserID: String) async throws -> SquadOfflineActivity?
    func updateSquadOfflineActivityStatus(squadID: String, activityID: String, input: SquadOfflineActivityStatusInput) async throws -> SquadOfflineActivity?
    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage
    func inviteUserToSquad(squadID: String, inviteeUserID: String) async throws
}

protocol LocationSyncRepository {
    func uploadSquadOfflineActivityLocation(
        squadID: String,
        activityID: String,
        input: SquadOfflineLocationUploadInput
    ) async throws
}

struct SquadActivityRepositoryAdapter: SquadActivityRepository {
    private let service: SocialService
    private let accountEnforcementStatusProvider: (() async -> AccountEnforcementStatus?)?

    init(
        service: SocialService,
        accountEnforcementStatusProvider: (() async -> AccountEnforcementStatus?)? = nil
    ) {
        self.service = service
        self.accountEnforcementStatusProvider = accountEnforcementStatusProvider
    }

    private func ensureAllowed(_ scopes: [AccountEnforcementScope]) async throws {
        guard let accountEnforcementStatusProvider else { return }
        guard let status = await accountEnforcementStatusProvider(),
              let restriction = status.restriction(for: scopes) else {
            return
        }
        throw ServiceError.accountEnforcementRestricted(restriction)
    }

    func fetchCurrentSquadOfflineActivity(squadID: String) async throws -> SquadOfflineActivity? {
        try await service.fetchCurrentSquadOfflineActivity(squadID: squadID)
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        try await service.fetchSquadProfile(squadID: squadID)
    }

    func fetchSquadOfflineActivityHistory(squadID: String) async throws -> [SquadOfflineActivity] {
        try await service.fetchSquadOfflineActivityHistory(squadID: squadID)
    }

    func startSquadOfflineActivity(squadID: String, input: StartSquadOfflineActivityInput) async throws -> SquadOfflineActivity {
        try await ensureAllowed([.eventCreate])
        return try await service.startSquadOfflineActivity(squadID: squadID, input: input)
    }

    func endSquadOfflineActivity(squadID: String, activityID: String) async throws -> SquadOfflineActivity? {
        try await service.endSquadOfflineActivity(squadID: squadID, activityID: activityID)
    }

    func joinSquadOfflineActivity(squadID: String, activityID: String) async throws -> SquadOfflineActivity {
        try await service.joinSquadOfflineActivity(squadID: squadID, activityID: activityID)
    }

    func leaveSquadOfflineActivity(squadID: String, activityID: String) async throws -> SquadOfflineActivity? {
        try await service.leaveSquadOfflineActivity(squadID: squadID, activityID: activityID)
    }

    func removeSquadOfflineActivityParticipant(squadID: String, activityID: String, participantUserID: String) async throws -> SquadOfflineActivity? {
        try await service.removeSquadOfflineActivityParticipant(
            squadID: squadID,
            activityID: activityID,
            participantUserID: participantUserID
        )
    }

    func updateSquadOfflineActivityStatus(squadID: String, activityID: String, input: SquadOfflineActivityStatusInput) async throws -> SquadOfflineActivity? {
        try await service.updateSquadOfflineActivityStatus(squadID: squadID, activityID: activityID, input: input)
    }

    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage {
        try await service.fetchFriends(userID: userID, cursor: cursor)
    }

    func inviteUserToSquad(squadID: String, inviteeUserID: String) async throws {
        try await service.inviteUserToSquad(squadID: squadID, inviteeUserID: inviteeUserID)
    }
}

struct LocationSyncRepositoryAdapter: LocationSyncRepository {
    private let service: SocialService
    private let accountEnforcementStatusProvider: (() async -> AccountEnforcementStatus?)?

    init(
        service: SocialService,
        accountEnforcementStatusProvider: (() async -> AccountEnforcementStatus?)? = nil
    ) {
        self.service = service
        self.accountEnforcementStatusProvider = accountEnforcementStatusProvider
    }

    private func ensureAllowed(_ scopes: [AccountEnforcementScope]) async throws {
        guard let accountEnforcementStatusProvider else { return }
        guard let status = await accountEnforcementStatusProvider(),
              let restriction = status.restriction(for: scopes) else {
            return
        }
        throw ServiceError.accountEnforcementRestricted(restriction)
    }

    func uploadSquadOfflineActivityLocation(
        squadID: String,
        activityID: String,
        input: SquadOfflineLocationUploadInput
    ) async throws {
        try await ensureAllowed([.locationShare])
        try await service.uploadSquadOfflineActivityLocation(
            squadID: squadID,
            activityID: activityID,
            input: input
        )
    }
}

extension JSONDecoder {
    static func raverISO8601() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
