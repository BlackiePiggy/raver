import Foundation

protocol SquadProfileRepository {
    func fetchSquadProfile(squadID: String) async throws -> SquadProfile
    func joinSquad(squadID: String) async throws
    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws
    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws
    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws
    func removeSquadMember(squadID: String, memberUserID: String) async throws
}

struct SquadProfileRepositoryAdapter: SquadProfileRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        try await service.fetchSquadProfile(squadID: squadID)
    }

    func joinSquad(squadID: String) async throws {
        try await service.joinSquad(squadID: squadID)
    }

    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws {
        try await service.updateSquadMySettings(squadID: squadID, input: input)
    }

    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws {
        try await service.updateSquadInfo(squadID: squadID, input: input)
    }

    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws {
        try await service.updateSquadMemberRole(squadID: squadID, memberUserID: memberUserID, role: role)
    }

    func removeSquadMember(squadID: String, memberUserID: String) async throws {
        try await service.removeSquadMember(squadID: squadID, memberUserID: memberUserID)
    }
}
