import Foundation

protocol SquadProfileRepository {
    func fetchSquadProfile(squadID: String) async throws -> SquadProfile
    func joinSquad(squadID: String) async throws
    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws
    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws
    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws
    func removeSquadMember(squadID: String, memberUserID: String) async throws
    func uploadSquadAvatar(
        squadID: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> AvatarUploadResponse
    func uploadSquadBannerImage(
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> UploadMediaResponse
}

struct SquadProfileRepositoryAdapter: SquadProfileRepository {
    private let socialService: SocialService
    private let webService: WebFeatureService

    init(
        socialService: SocialService,
        webService: WebFeatureService
    ) {
        self.socialService = socialService
        self.webService = webService
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        try await socialService.fetchSquadProfile(squadID: squadID)
    }

    func joinSquad(squadID: String) async throws {
        try await socialService.joinSquad(squadID: squadID)
    }

    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws {
        try await socialService.updateSquadMySettings(squadID: squadID, input: input)
    }

    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws {
        try await socialService.updateSquadInfo(squadID: squadID, input: input)
    }

    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws {
        try await socialService.updateSquadMemberRole(squadID: squadID, memberUserID: memberUserID, role: role)
    }

    func removeSquadMember(squadID: String, memberUserID: String) async throws {
        try await socialService.removeSquadMember(squadID: squadID, memberUserID: memberUserID)
    }

    func uploadSquadAvatar(
        squadID: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> AvatarUploadResponse {
        try await socialService.uploadSquadAvatar(
            squadID: squadID,
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType
        )
    }

    func uploadSquadBannerImage(
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> UploadMediaResponse {
        try await webService.uploadEventImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType
        )
    }
}
