import Foundation
import Combine

@MainActor
final class SquadProfileViewModel: ObservableObject {
    @Published var profile: SquadProfile?
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isProcessingJoin = false
    @Published var isSavingMySettings = false
    @Published var isSavingGroupInfo = false
    @Published var memberActionInFlightUserID: String?
    @Published var bannerMessage: String?
    @Published var error: String?

    private let squadID: String
    private let repository: SquadProfileRepository

    init(squadID: String, repository: SquadProfileRepository) {
        self.squadID = squadID
        self.repository = repository
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        let hadContent = profile != nil
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            profile = try await repository.fetchSquadProfile(squadID: squadID)
            phase = profile == nil ? .empty : .success
            bannerMessage = nil
            error = nil
        } catch {
            let message = error.userFacingMessage ?? LT("小队加载失败，请稍后重试", "Failed to load squad. Please try again later.", "Squadを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    func joinIfNeeded() async -> Bool {
        guard let profile else { return false }
        if profile.isMember { return true }

        isProcessingJoin = true
        defer { isProcessingJoin = false }

        do {
            try await repository.joinSquad(squadID: profile.id)
            self.profile = try await repository.fetchSquadProfile(squadID: profile.id)
            phase = .success
            bannerMessage = nil
            return true
        } catch {
            self.error = error.userFacingMessage
            return false
        }
    }

    func buildConversation() -> Conversation? {
        guard let profile else { return nil }
        return Conversation(
            id: profile.id,
            type: .group,
            title: profile.name,
            avatarURL: profile.avatarURL,
            lastMessage: profile.lastMessage ?? LT("暂无消息", "No messages yet", "メッセージはまだありません"),
            lastMessageSenderID: nil,
            unreadCount: 0,
            updatedAt: profile.updatedAt,
            peer: nil
        )
    }

    func saveMySettings(nickname: String?, notificationsEnabled: Bool) async -> Bool {
        guard let profile else { return false }
        if isSavingMySettings { return false }

        isSavingMySettings = true
        defer { isSavingMySettings = false }

        do {
            try await repository.updateSquadMySettings(
                squadID: profile.id,
                input: UpdateSquadMySettingsInput(
                    nickname: nickname,
                    notificationsEnabled: notificationsEnabled
                )
            )
            self.profile = try await repository.fetchSquadProfile(squadID: profile.id)
            phase = .success
            bannerMessage = nil
            error = nil
            return true
        } catch {
            self.error = error.userFacingMessage
            return false
        }
    }

    func saveGroupInfo(input: UpdateSquadInfoInput) async -> Bool {
        guard let profile else { return false }
        if isSavingGroupInfo { return false }

        isSavingGroupInfo = true
        defer { isSavingGroupInfo = false }

        do {
            try await repository.updateSquadInfo(squadID: profile.id, input: input)
            self.profile = try await repository.fetchSquadProfile(squadID: profile.id)
            phase = .success
            bannerMessage = nil
            error = nil
            return true
        } catch {
            self.error = error.userFacingMessage
            return false
        }
    }

    func updateMemberRole(memberUserID: String, role: String) async -> Bool {
        guard let profile else { return false }
        if memberActionInFlightUserID != nil { return false }

        memberActionInFlightUserID = memberUserID
        defer { memberActionInFlightUserID = nil }

        do {
            try await repository.updateSquadMemberRole(squadID: profile.id, memberUserID: memberUserID, role: role)
            self.profile = try await repository.fetchSquadProfile(squadID: profile.id)
            phase = .success
            bannerMessage = nil
            error = nil
            return true
        } catch {
            self.error = error.userFacingMessage
            return false
        }
    }

    func removeMember(memberUserID: String) async -> Bool {
        guard let profile else { return false }
        if memberActionInFlightUserID != nil { return false }

        memberActionInFlightUserID = memberUserID
        defer { memberActionInFlightUserID = nil }

        do {
            try await repository.removeSquadMember(squadID: profile.id, memberUserID: memberUserID)
            self.profile = try await repository.fetchSquadProfile(squadID: profile.id)
            phase = .success
            bannerMessage = nil
            error = nil
            return true
        } catch {
            self.error = error.userFacingMessage
            return false
        }
    }
}
