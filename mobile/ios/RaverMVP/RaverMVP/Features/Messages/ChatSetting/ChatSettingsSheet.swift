import SwiftUI
import PhotosUI
import UIKit

protocol ChatSettingsRepository: IMChatConversationDataSource {
    func fetchSquadProfile(squadID: String) async throws -> SquadProfile
    func fetchSquadMemberDirectory(squadID: String) async throws -> GroupMemberDirectory
    func fetchSquadInviteOption(squadID: String) async throws -> GroupInviteOption
    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage
    func isUserBlacklisted(userID: String) async throws -> Bool
    func setConversationMuted(conversationID: String, muted: Bool) async throws
    func fetchUserProfile(userID: String) async throws -> UserProfile
    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws
    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws
    func uploadSquadAvatar(
        squadID: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> AvatarUploadResponse
    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws
    func clearConversationHistory(conversationID: String) async throws
    func leaveSquad(squadID: String) async throws
    func disbandSquad(squadID: String) async throws
    func setSquadInviteOption(squadID: String, option: GroupInviteOption) async throws
    func inviteUserToSquad(squadID: String, inviteeUserID: String) async throws
    func removeSquadMember(squadID: String, memberUserID: String) async throws
    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws
}

struct ChatSettingsRepositoryAdapter: ChatSettingsRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchConversations(type: ConversationType) async throws -> [Conversation] {
        try await service.fetchConversations(type: type)
    }

    func markConversationRead(conversationID: String) async throws {
        try await service.markConversationRead(conversationID: conversationID)
    }

    func setConversationPinned(conversationID: String, pinned: Bool) async throws {
        try await service.setConversationPinned(conversationID: conversationID, pinned: pinned)
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws {
        try await service.markConversationUnread(conversationID: conversationID, unread: unread)
    }

    func hideConversation(conversationID: String) async throws {
        try await service.hideConversation(conversationID: conversationID)
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        try await service.fetchSquadProfile(squadID: squadID)
    }

    func fetchSquadMemberDirectory(squadID: String) async throws -> GroupMemberDirectory {
        try await service.fetchSquadMemberDirectory(squadID: squadID)
    }

    func fetchSquadInviteOption(squadID: String) async throws -> GroupInviteOption {
        try await service.fetchSquadInviteOption(squadID: squadID)
    }

    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage {
        try await service.fetchFriends(userID: userID, cursor: cursor)
    }

    func isUserBlacklisted(userID: String) async throws -> Bool {
        try await service.isUserBlacklisted(userID: userID)
    }

    func setConversationMuted(conversationID: String, muted: Bool) async throws {
        try await service.setConversationMuted(conversationID: conversationID, muted: muted)
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        try await service.fetchUserProfile(userID: userID)
    }

    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws {
        try await service.updateSquadInfo(squadID: squadID, input: input)
    }

    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws {
        try await service.updateSquadMySettings(squadID: squadID, input: input)
    }

    func uploadSquadAvatar(
        squadID: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> AvatarUploadResponse {
        try await service.uploadSquadAvatar(
            squadID: squadID,
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType
        )
    }

    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws {
        try await service.setUserBlacklisted(userID: userID, blacklisted: blacklisted)
    }

    func clearConversationHistory(conversationID: String) async throws {
        try await service.clearConversationHistory(conversationID: conversationID)
    }

    func leaveSquad(squadID: String) async throws {
        try await service.leaveSquad(squadID: squadID)
    }

    func disbandSquad(squadID: String) async throws {
        try await service.disbandSquad(squadID: squadID)
    }

    func setSquadInviteOption(squadID: String, option: GroupInviteOption) async throws {
        try await service.setSquadInviteOption(squadID: squadID, option: option)
    }

    func inviteUserToSquad(squadID: String, inviteeUserID: String) async throws {
        try await service.inviteUserToSquad(squadID: squadID, inviteeUserID: inviteeUserID)
    }

    func removeSquadMember(squadID: String, memberUserID: String) async throws {
        try await service.removeSquadMember(squadID: squadID, memberUserID: memberUserID)
    }

    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws {
        try await service.updateSquadMemberRole(squadID: squadID, memberUserID: memberUserID, role: role)
    }
}

struct ChatSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @FocusState private var isRemarkFieldFocused: Bool
    @FocusState private var isGroupNicknameFieldFocused: Bool

    let conversation: Conversation
    let repository: ChatSettingsRepository
    let chatStore: IMChatStore
    var onLeaveConversation: (() -> Void)? = nil

    @State private var notificationsMuted = false
    @State private var topPinned = false
    @State private var isMuting = false
    @State private var isClearing = false
    @State private var isLeaving = false
    @State private var isDisbanding = false
    @State private var isLoadingSquadProfile = false
    @State private var hasLoadedConversationSettings = false
    @State private var errorMessage: String?
    @State private var squadProfile: SquadProfile?
    @State private var groupMemberDirectory: GroupMemberDirectory?
    @State private var showLeaveConfirm = false
    @State private var showDisbandConfirm = false
    @State private var showLeaderLeaveGuide = false
    @State private var showGroupMembers = false
    @State private var showInviteMembers = false
    @State private var showBlacklistConfirm = false
    @State private var showInviteOptionPicker = false
    @State private var isSavingRemark = false
    @State private var isUpdatingBlacklist = false
    @State private var isUpdatingInviteOption = false
    @State private var isSavingGroupInfo = false
    @State private var isSavingGroupNickname = false
    @State private var isLoadingDirectSettings = false
    @State private var hasLoadedDirectSettings = false
    @State private var isBlacklisted = false
    @State private var isTencentFriend = false
    @State private var directRemarkName = ""
    @State private var committedDirectRemarkName = ""
    @State private var directBaseDisplayName = ""
    @State private var directDisplayNameOverride: String?
    @State private var inviteFeedbackMessage: String?
    @State private var groupInviteOption: GroupInviteOption = .forbid
    @State private var groupNicknameDraft = ""
    @State private var committedGroupNickname = ""
    @State private var editingGroupInfoField: GroupInfoEditableField?
    @State private var groupInfoDraft = ""
    @State private var selectedGroupAvatarPhotoItem: PhotosPickerItem?
    @State private var isUploadingGroupAvatar = false
    @State private var reportTarget: ReportSheetTarget?

    private var platformSquadID: String {
        TencentIMIdentity.normalizePlatformSquadID(conversation.id)
    }

    private var directChatUserID: String? {
        conversation.peer?.id.nilIfBlank ?? conversation.id.nilIfBlank
    }

    private var effectiveGroupMembers: [SquadMemberProfile] {
        groupMemberDirectory?.members ?? squadProfile?.members ?? []
    }

    private var effectiveGroupMemberCount: Int {
        groupMemberDirectory?.members.count ?? squadProfile?.memberCount ?? 0
    }

    private var effectiveGroupMyRole: String? {
        groupMemberDirectory?.myRole ?? squadProfile?.myRole
    }

    private var displayTitle: String {
        if conversation.type == .group {
            return squadProfile?.name ?? conversation.title
        }
        return directDisplayNameOverride?.nilIfBlank
            ?? conversation.peer?.displayName.nilIfBlank
            ?? conversation.title
    }

    var body: some View {
        List {
            headerSection

            if conversation.type == .direct {
                directSections
            } else {
                groupSections
            }

            sharedSections
        }
        .listStyle(.insetGrouped)
        .raverSystemNavigation(title: LT("聊天详情", "Chat Details", "チャット詳細"))
        .overlay {
            if isClearing || isLeaving || isDisbanding {
                ProgressView(LT("同步中...", "Syncing...", "同期中..."))
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, blocked in
                OperationBannerCenter.shared.success(
                    blocked
                        ? LT("举报已提交，并已拉黑该用户", "Report submitted and user blocked", "通報を送信し、このユーザーをブロックしました")
                        : LT("举报已提交", "Report submitted", "通報を送信しました")
                )
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .overlay(alignment: .top) {
            if let inviteFeedbackMessage {
                Text(inviteFeedbackMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.78))
                    )
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert(LT("操作失败", "Operation Failed", "操作に失敗しました"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            LT("确认退出群聊？", "Leave this group?", "グループチャットを退出しますか？"),
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button(LT("删除并退出", "Delete and Leave", "削除して退出"), role: .destructive) {
                Task { await leaveSquad() }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(LT("退出后你将无法继续查看群聊内容。", "After leaving, you won't be able to view this chat until rejoining.", "退出すると、再参加するまでこのチャット内容を確認できません。"))
        }
        .confirmationDialog(
            LT("确认解散小队？", "Disband this squad?", "Squad を解散しますか？"),
            isPresented: $showDisbandConfirm,
            titleVisibility: .visible
        ) {
            Button(LT("解散小队", "Disband Squad", "Squad を解散"), role: .destructive) {
                Task { await disbandSquad() }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(LT("解散后小队成员与群聊将被移除，且无法恢复。", "Disbanding removes members and group chat and cannot be undone.", "解散すると Squad メンバーとグループチャットは削除され、元に戻せません。"))
        }
        .alert(LT("需要先转让队长", "Transfer Leader First", "先にリーダーを譲渡してください"), isPresented: $showLeaderLeaveGuide) {
            Button(LT("查看群成员", "View Members", "グループメンバーを見る")) {
                showGroupMembers = true
            }
            Button(LT("我知道了", "Got It", "了解しました"), role: .cancel) {}
        } message: {
            Text(LT("当前你是队长，需先在群成员页转让队长后再退出。", "You're the group owner. Transfer ownership in the member list before leaving.", "現在あなたはリーダーです。退出する前にメンバー画面でリーダーを譲渡してください。"))
        }
        .confirmationDialog(
            isBlacklisted
                ? LT("确认将对方移出黑名单？", "Remove this user from blacklist?", "相手をブラックリストから解除しますか？")
                : LT("确认将对方加入黑名单？", "Add this user to blacklist?", "相手をブラックリストに追加しますか？"),
            isPresented: $showBlacklistConfirm,
            titleVisibility: .visible
        ) {
            Button(
                isBlacklisted
                    ? LT("移出黑名单", "Remove from Blacklist", "ブラックリストから解除")
                    : LT("加入黑名单", "Add to Blacklist", "ブラックリストに追加"),
                role: .destructive
            ) {
                Task { await updateBlacklistStatus(!isBlacklisted) }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(
                isBlacklisted
                    ? LT("移出黑名单后，对方将恢复正常聊天权限。", "Removing from blacklist restores normal chat access.", "解除すると、相手の通常のチャット権限が復元されます。")
                    : LT("加入黑名单后，你将不会再接收对方的消息。", "After adding to blacklist, you won't receive this user's messages.", "追加すると、このユーザーからのメッセージを受信しなくなります。")
            )
        }
        .confirmationDialog(
            LT("邀请方式", "Invite Type", "招待方式"),
            isPresented: $showInviteOptionPicker,
            titleVisibility: .visible
        ) {
            ForEach(GroupInviteOption.allCases, id: \.rawValue) { option in
                Button(option == groupInviteOption ? "✓ \(option.title)" : option.title) {
                    Task { await updateInviteOption(option) }
                }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(LT("参考腾讯群聊逻辑，只有允许邀请时，成员区的邀请入口才可用。", "Aligned with Tencent group chat logic, member invites are only available when invite is enabled.", "Tencent グループチャットの仕様に合わせ、招待が許可されている場合のみメンバー欄の招待入口が利用できます。"))
        }
        .sheet(item: $editingGroupInfoField) { field in
            NavigationStack {
                GroupInfoFieldEditorView(
                    field: field,
                    text: $groupInfoDraft,
                    isSaving: isSavingGroupInfo,
                    onSave: {
                        Task { await saveGroupInfoField(field) }
                    }
                )
            }
        }
        .onChange(of: notificationsMuted) { oldValue, newValue in
            guard hasLoadedConversationSettings else { return }
            guard oldValue != newValue else { return }
            Task { await updateMuteStatus(newValue, rollbackTo: oldValue) }
        }
        .task(id: conversation.id) {
            notificationsMuted = conversation.isMuted
            topPinned = conversation.isPinned
            directDisplayNameOverride = conversation.peer?.displayName.nilIfBlank ?? conversation.title
            hasLoadedConversationSettings = true
            if conversation.type == .group {
                await loadSquadProfile(force: false)
                await loadGroupMemberDirectory(force: false)
                await loadGroupInviteOption(force: false)
            } else {
                await loadDirectConversationSettings(force: false)
            }
        }
        .onChange(of: topPinned) { oldValue, newValue in
            guard hasLoadedConversationSettings else { return }
            guard oldValue != newValue else { return }
            Task { await updatePinnedStatus(newValue, rollbackTo: oldValue) }
        }
        .onChange(of: isRemarkFieldFocused) { oldValue, newValue in
            guard oldValue, !newValue else { return }
            Task { await commitInlineRemarkIfNeeded() }
        }
        .onChange(of: isGroupNicknameFieldFocused) { oldValue, newValue in
            guard oldValue, !newValue else { return }
            Task { await commitGroupNicknameIfNeeded() }
        }
        .onChange(of: selectedGroupAvatarPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task { await updateGroupAvatar(from: newValue) }
        }
    }

    private var headerSection: some View {
        Section {
            if conversation.type == .direct {
                Button {
                    openDirectProfile()
                } label: {
                    headerRow(showChevron: true)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    openGroupProfile()
                } label: {
                    headerRow(showChevron: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var directSections: some View {
        Group {
            Section {
                placeholderRow(titleCN: "聊天历史搜索", titleEN: "Search Chat History", titleJA: "チャット履歴を検索", icon: "magnifyingglass") {
                    popThenOpenConversationSearch()
                }
                HStack(spacing: 12) {
                    Label(LT("设置备注名", "Nickname", "メモ名を設定"), systemImage: "pencil")
                    Spacer(minLength: 12)
                    TextField(
                        LT("输入备注名", "Enter remark", "メモ名を入力"),
                        text: Binding(
                            get: { directRemarkName },
                            set: { directRemarkName = String($0.prefix(Self.remarkNameLimit)) }
                        )
                    )
                    .focused($isRemarkFieldFocused)
                    .submitLabel(.done)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: 160)
                    .disabled(isSavingRemark || !isTencentFriend)
                    .onSubmit {
                        Task { await commitInlineRemarkIfNeeded() }
                    }
                }
                if !isTencentFriend {
                    Text(LT("仅好友支持备注名", "Nickname is available for friends only", "メモ名は友達にのみ設定できます"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            Section {
                Toggle(LT("消息免打扰", "Mute Notifications", "通知をミュート"), isOn: $notificationsMuted)
                    .disabled(isMuting)
                Toggle(LT("置顶聊天", "Pin Chat", "チャットをピン留め"), isOn: $topPinned)
            }

            Section {
                Button(role: .destructive) {
                    showBlacklistConfirm = true
                } label: {
                    Label(
                        isBlacklisted
                            ? LT("移出黑名单", "Remove from Blacklist", "ブラックリストから解除")
                            : LT("加入黑名单", "Add to Blacklist", "ブラックリストに追加"),
                        systemImage: isBlacklisted ? "person.crop.circle.badge.checkmark" : "hand.raised"
                    )
                }
                .disabled(isUpdatingBlacklist || isLoadingDirectSettings)
                Button(role: .destructive) {
                    openDirectReportSheet()
                } label: {
                    Label(LT("举报", "Report", "通報"), systemImage: "exclamationmark.bubble")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await clearHistory() }
                } label: {
                    Label(LT("清空聊天记录", "Clear Chat History", "チャット履歴を消去"), systemImage: "trash")
                }
                .disabled(isClearing)

                placeholderRow(titleCN: "删除好友", titleEN: "Delete Friend", titleJA: "友達を削除", icon: "person.crop.circle.badge.xmark", destructive: true)
            }
        }
    }

    private var groupSections: some View {
        Group {
            Section {
                if isLoadingSquadProfile && squadProfile == nil {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(LT("同步群信息中...", "Syncing group info...", "グループ情報を同期中..."))
                            .font(.footnote)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                if let profile = squadProfile {
                    ZStack {
                        NavigationLink(
                            destination: InviteSquadMembersView(
                                squadID: platformSquadID,
                                existingMemberIDs: Set(effectiveGroupMembers.map(\.id)),
                                repository: repository,
                                currentUserID: appState.session?.user.id ?? "",
                                onInvited: { invitedUsers in
                                    handleInvitedMembers(invitedUsers)
                                }
                            ),
                            isActive: $showInviteMembers
                        ) {
                            EmptyView()
                        }
                        .hidden()

                        NavigationLink(
                            destination: GroupMemberListView(
                                squadID: platformSquadID,
                                memberDirectory: groupMemberDirectory ?? GroupMemberDirectory(
                                    members: profile.members,
                                    myRole: effectiveGroupMyRole
                                ),
                                repository: repository,
                                onDirectoryChanged: { updatedDirectory in
                                    groupMemberDirectory = updatedDirectory
                                    if var updatedProfile = squadProfile {
                                        updatedProfile.members = updatedDirectory.members
                                        updatedProfile.memberCount = updatedDirectory.members.count
                                        updatedProfile.myRole = updatedDirectory.myRole ?? updatedProfile.myRole
                                        squadProfile = updatedProfile
                                    }
                                }
                            ),
                            isActive: $showGroupMembers
                        ) {
                            EmptyView()
                        }
                        .hidden()

                        GroupMembersPreviewView(
                            members: effectiveGroupMembers,
                            memberCount: effectiveGroupMemberCount,
                            onShowAll: { showGroupMembers = true },
                            onInvite: {
                                guard groupInviteOption != .forbid else {
                                    errorMessage = LT("当前群聊已禁止邀请成员，请先在“邀请方式”中开启。", "Group invites are disabled. Enable them in Invite Type first.", "このグループチャットではメンバー招待が無効です。「招待方式」で有効にしてください。")
                                    return
                                }
                                showInviteMembers = true
                            }
                        )
                    }
                } else {
                    placeholderRow(titleCN: "群成员", titleEN: "Group Members", titleJA: "グループメンバー", icon: "person.3")
                }
            }

            Section {
                PhotosPicker(selection: $selectedGroupAvatarPhotoItem, matching: .images) {
                    HStack(spacing: 12) {
                        Text(LT("群头像", "Group Avatar", "グループアイコン"))
                            .foregroundStyle(Color.primary)
                        Spacer(minLength: 12)
                        groupAvatarAccessory(size: 34)
                        if isUploadingGroupAvatar {
                            ProgressView()
                                .controlSize(.small)
                        } else if canManageInviteOption {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canManageInviteOption || isUploadingGroupAvatar)

                groupInfoActionRow(
                    title: LT("群名称", "Group Name", "グループ名"),
                    value: squadProfile?.name ?? "",
                    editable: canManageInviteOption,
                    action: { beginEditingGroupInfo(.groupName) }
                )
                groupInfoActionRow(
                    title: LT("群公告", "Group Notice", "グループお知らせ"),
                    value: squadProfile?.notice ?? "",
                    editable: canManageInviteOption,
                    action: { beginEditingGroupInfo(.notice) }
                )
                groupInfoActionRow(
                    title: LT("群简介", "Group Introduction", "グループ紹介"),
                    value: squadProfile?.description ?? "",
                    editable: canManageInviteOption,
                    action: { beginEditingGroupInfo(.introduction) }
                )
                Button {
                    pushRoute(.squadOfflineActivityHistory(squadID: platformSquadID))
                } label: {
                    Label(LT("历史活动记录", "Activity History", "過去の活動記録"), systemImage: "clock.arrow.circlepath")
                }
                HStack(spacing: 12) {
                    Label(LT("我在本群的昵称", "My Group Nickname", "このグループでの自分のニックネーム"), systemImage: "person.text.rectangle")
                    Spacer(minLength: 12)
                    TextField(
                        LT("输入群昵称", "Enter nickname", "グループニックネームを入力"),
                        text: Binding(
                            get: { groupNicknameDraft },
                            set: { groupNicknameDraft = String($0.prefix(Self.remarkNameLimit)) }
                        )
                    )
                    .focused($isGroupNicknameFieldFocused)
                    .submitLabel(.done)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: 180)
                    .disabled(isSavingGroupNickname)
                    .onSubmit {
                        Task { await commitGroupNicknameIfNeeded() }
                    }
                }
                Button {
                    if canManageInviteOption {
                        showInviteOptionPicker = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(LT("邀请方式", "Invite Type", "招待方式"))
                            .foregroundStyle(Color.primary)
                        Spacer(minLength: 12)
                        if isUpdatingInviteOption {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(groupInviteOption.title)
                                .font(.subheadline)
                                .foregroundStyle(RaverTheme.secondaryText)
                            if canManageInviteOption {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(isUpdatingInviteOption || !canManageInviteOption)
                placeholderRow(titleCN: "查找聊天记录", titleEN: "Search Chat History", titleJA: "チャット履歴を検索", icon: "magnifyingglass") {
                    popThenOpenConversationSearch()
                }
            }

            Section {
                Toggle(LT("消息免打扰", "Mute Notifications", "通知をミュート"), isOn: $notificationsMuted)
                    .disabled(isMuting)
                Toggle(LT("置顶聊天", "Pin Chat", "チャットをピン留め"), isOn: $topPinned)
                Button(role: .destructive) {
                    openGroupReportSheet()
                } label: {
                    Label(LT("举报", "Report", "通報"), systemImage: "exclamationmark.bubble")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await clearHistory() }
                } label: {
                    Label(LT("清空聊天记录", "Clear Chat History", "チャット履歴を消去"), systemImage: "trash")
                }
                .disabled(isClearing)

                if canDisbandSquad {
                    Button(role: .destructive) {
                        showDisbandConfirm = true
                    } label: {
                        Label(LT("解散群聊", "Disband Group", "グループチャットを解散"), systemImage: "xmark.circle")
                    }
                    .disabled(isDisbanding || isLeaving)
                }

                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Label(LT("删除并退出", "Delete and Leave", "削除して退出"), systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(isLeaving || isDisbanding)
            }
        }
    }

    @ViewBuilder
    private var sharedSections: some View {
        EmptyView()
    }

    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        let avatarURL: String? = conversation.type == .group
            ? (squadProfile?.avatarURL ?? conversation.avatarURL)
            : (conversation.peer?.avatarURL ?? conversation.avatarURL)

        if let resolved = AppConfig.resolvedURLString(avatarURL),
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            AvatarPlaceholderView(size: size, isGroup: conversation.type == .group)
        }
    }

    private func headerRow(showChevron: Bool) -> some View {
        HStack(spacing: 12) {
            avatarView(size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                if conversation.type == .group {
                    Text(LT("群聊", "Group Chat", "グループチャット"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            Spacer(minLength: 0)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func placeholderRow(
        titleCN: String,
        titleEN: String,
        titleJA: String,
        icon: String,
        destructive: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            if let action {
                action()
            } else {
                errorMessage = LT("该功能暂未接入，先保留入口。", "This feature is not wired yet. Placeholder for now.", "この機能はまだ接続されていません。入口のみ保持しています。")
            }
        } label: {
            Label(LT(titleCN, titleEN, titleJA), systemImage: icon)
                .foregroundStyle(destructive ? Color.red : Color.primary)
        }
    }

    private func groupInfoActionRow(
        title: String,
        value: String,
        editable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 12)
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? LT("未设置", "Not Set", "未設定") : value)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if editable {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!editable)
        .contentShape(Rectangle())
    }

    private var canDisbandSquad: Bool {
        guard conversation.type == .group else { return false }
        return (effectiveGroupMyRole ?? squadProfile?.myRole) == "leader"
    }

    private var canManageInviteOption: Bool {
        guard conversation.type == .group else { return false }
        guard let squadProfile else { return false }
        let role = effectiveGroupMyRole ?? squadProfile.myRole
        return squadProfile.canEditGroup || role == "leader" || role == "admin"
    }

    private static let remarkNameLimit = 24

    private func pushRoute(_ route: AppRoute) {
        DispatchQueue.main.async {
            appPush(route)
        }
    }

    private func openDirectProfile() {
        guard conversation.type == .direct else { return }
        let resolved = TencentIMIdentity.normalizePlatformUserIDForProfile(
            directChatUserID ?? conversation.id
        )
        pushRoute(.userProfile(userID: resolved))
    }

    private func openGroupProfile() {
        guard conversation.type == .group else { return }
        pushRoute(.squadProfile(squadID: platformSquadID))
    }

    private func openDirectReportSheet() {
        guard conversation.type == .direct else { return }
        let targetUserID = TencentIMIdentity.normalizePlatformUserIDForProfile(
            directChatUserID ?? conversation.id
        )
        reportTarget = ReportSheetTarget(
            id: targetUserID,
            type: .user,
            title: displayTitle,
            preview: conversation.lastMessage,
            targetUserID: targetUserID,
            targetUserDisplayName: displayTitle
        )
    }

    private func openGroupReportSheet() {
        guard conversation.type == .group else { return }
        let targetID = conversation.sdkConversationID?.nilIfBlank ?? platformSquadID
        reportTarget = ReportSheetTarget(
            id: targetID,
            type: .groupChat,
            title: displayTitle,
            preview: conversation.lastMessage,
            targetUserID: nil,
            targetUserDisplayName: nil
        )
    }

    private func popThenOpenConversationSearch() {
        let targetConversationID = conversation.sdkConversationID ?? conversation.id
        dismiss()
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .raverOpenConversationSearch,
                object: nil,
                userInfo: ["conversationID": targetConversationID]
            )
        }
    }

    @MainActor
    private func loadSquadProfile(force: Bool) async {
        guard conversation.type == .group else { return }
        if isLoadingSquadProfile { return }
        if squadProfile != nil && !force { return }

        isLoadingSquadProfile = true
        defer { isLoadingSquadProfile = false }

        do {
            squadProfile = try await repository.fetchSquadProfile(squadID: platformSquadID)
            groupNicknameDraft = squadProfile?.myNickname ?? ""
            committedGroupNickname = groupNicknameDraft
        } catch {
            // Keep detail page usable even when profile fetch fails.
        }
    }

    @MainActor
    private func loadGroupMemberDirectory(force: Bool) async {
        guard conversation.type == .group else { return }
        if groupMemberDirectory != nil && !force { return }

        do {
            let directory = try await repository.fetchSquadMemberDirectory(squadID: platformSquadID)
            groupMemberDirectory = directory
            if var profile = squadProfile {
                profile.members = directory.members
                profile.memberCount = directory.members.count
                profile.myRole = directory.myRole ?? profile.myRole
                squadProfile = profile
            }
        } catch {
            if force {
                errorMessage = error.userFacingMessage ?? LT("加载群成员失败", "Failed to load group members", "グループメンバーの読み込みに失敗しました")
            }
        }
    }

    @MainActor
    private func loadGroupInviteOption(force: Bool) async {
        guard conversation.type == .group else { return }
        if isUpdatingInviteOption && !force { return }

        do {
            groupInviteOption = try await repository.fetchSquadInviteOption(squadID: platformSquadID)
        } catch {
            if force {
                errorMessage = error.userFacingMessage ?? LT("加载邀请方式失败", "Failed to load invite option", "招待方式の読み込みに失敗しました")
            }
        }
    }

    @MainActor
    private func loadDirectConversationSettings(force: Bool) async {
        guard conversation.type == .direct else { return }
        guard !isLoadingDirectSettings else { return }
        if hasLoadedDirectSettings && !force { return }
        guard let peerID = directChatUserID else { return }

        isLoadingDirectSettings = true
        defer { isLoadingDirectSettings = false }

        do {
            let currentUserID = appState.session?.user.id ?? ""
            async let loadedFriends = repository.fetchFriends(userID: currentUserID, cursor: nil)
            async let loadedBlacklistState = repository.isUserBlacklisted(userID: peerID)
            let (friendList, blacklisted) = try await (loadedFriends, loadedBlacklistState)
            let baseDisplayName = await resolveDirectBaseDisplayName(peerID: peerID)
            let platformPeerID = TencentIMIdentity.normalizePlatformUserIDForProfile(peerID)
            let friendship = friendList.users.contains(where: { $0.id == platformPeerID })
            let remark = chatStore.directConversationRemarkOverride(
                conversationID: conversation.id,
                peerUserID: peerID
            )
            let resolvedRemark = remark ?? ""
            isTencentFriend = friendship
            directRemarkName = resolvedRemark
            committedDirectRemarkName = resolvedRemark
            isBlacklisted = blacklisted
            directBaseDisplayName = baseDisplayName
            if let remarkDisplay = resolvedRemark.nilIfBlank {
                directDisplayNameOverride = remarkDisplay
            } else if !baseDisplayName.isEmpty {
                directDisplayNameOverride = baseDisplayName
            }
            hasLoadedDirectSettings = true
        } catch {
            let baseDisplayName = await resolveDirectBaseDisplayName(peerID: peerID)
            isTencentFriend = false
            directRemarkName = ""
            committedDirectRemarkName = ""
            directBaseDisplayName = baseDisplayName
            if !baseDisplayName.isEmpty {
                directDisplayNameOverride = baseDisplayName
            }
            hasLoadedDirectSettings = true
        }
    }

    @MainActor
    private func updateMuteStatus(_ muted: Bool, rollbackTo oldValue: Bool) async {
        guard !isMuting else { return }
        isMuting = true
        defer { isMuting = false }
        do {
            try await repository.setConversationMuted(conversationID: conversation.id, muted: muted)
            chatStore.updateConversationMuteState(conversationID: conversation.id, muted: muted)
        } catch {
            notificationsMuted = oldValue
            errorMessage = error.userFacingMessage ?? LT("更新免打扰失败", "Failed to update mute status", "ミュート設定の更新に失敗しました")
        }
    }

    @MainActor
    private func updatePinnedStatus(_ pinned: Bool, rollbackTo oldValue: Bool) async {
        do {
            try await chatStore.setConversationPinned(
                conversationID: conversation.id,
                pinned: pinned,
                using: repository
            )
        } catch {
            topPinned = oldValue
            errorMessage = error.userFacingMessage ?? LT("更新置顶状态失败", "Failed to update pin status", "ピン留め状態の更新に失敗しました")
        }
    }

    @MainActor
    private func updateRemarkName() async {
        guard conversation.type == .direct else { return }
        guard !isSavingRemark else { return }
        guard let peerID = directChatUserID else { return }
        guard isTencentFriend else {
            errorMessage = LT("当前仅支持为好友设置备注名", "Nickname can only be set for friends", "現在、メモ名は友達にのみ設定できます")
            directRemarkName = committedDirectRemarkName
            return
        }

        isSavingRemark = true
        defer { isSavingRemark = false }

        let trimmedRemark = String(
            directRemarkName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(Self.remarkNameLimit)
        )
        let remarkValue = trimmedRemark.isEmpty ? nil : trimmedRemark

        let resolvedDisplayName: String
        if let remarkValue {
            resolvedDisplayName = remarkValue
        } else {
            resolvedDisplayName = await resolveDirectBaseDisplayName(peerID: peerID)
        }

        directRemarkName = remarkValue ?? ""
        committedDirectRemarkName = remarkValue ?? ""
        directDisplayNameOverride = resolvedDisplayName
        chatStore.setDirectConversationRemarkOverride(
            conversationID: conversation.id,
            peerUserID: peerID,
            displayName: remarkValue
        )
        NotificationCenter.default.post(
            name: .raverConversationIdentityUpdated,
            object: nil,
            userInfo: [
                "conversationID": conversation.id,
                "sdkConversationID": conversation.sdkConversationID ?? "",
                "displayName": resolvedDisplayName
            ]
        )
    }

    @MainActor
    private func commitInlineRemarkIfNeeded() async {
        let normalizedCurrent = String(
            directRemarkName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(Self.remarkNameLimit)
        )
        let normalizedCommitted = committedDirectRemarkName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCurrent != normalizedCommitted else { return }
        directRemarkName = normalizedCurrent
        await updateRemarkName()
    }

    private func resolveDirectBaseDisplayName(peerID: String) async -> String {
        if !directBaseDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return directBaseDisplayName
        }

        let platformUserID = TencentIMIdentity.normalizePlatformUserIDForProfile(peerID)
        if let profile = try? await repository.fetchUserProfile(userID: platformUserID),
           let displayName = profile.displayName.nilIfBlank {
            return displayName
        }

        if let refreshed = try? await repository.fetchConversations(type: .direct).first(where: {
            $0.id == conversation.id
                || $0.sdkConversationID == conversation.sdkConversationID
                || $0.id == conversation.sdkConversationID
                || $0.sdkConversationID == conversation.id
        }) {
            if let displayName = refreshed.peer?.displayName.nilIfBlank {
                return displayName
            }
            if let title = refreshed.title.nilIfBlank, !TencentIMIdentity.isTencentIMUserID(title) {
                return title
            }
        }

        if let displayName = conversation.peer?.displayName.nilIfBlank,
           !TencentIMIdentity.isTencentIMUserID(displayName) {
            return displayName
        }
        if let title = conversation.title.nilIfBlank,
           !TencentIMIdentity.isTencentIMUserID(title) {
            return title
        }
        return conversation.peer?.username.nilIfBlank
            ?? conversation.peer?.displayName.nilIfBlank
            ?? conversation.title
    }

    private func beginEditingGroupInfo(_ field: GroupInfoEditableField) {
        guard canManageInviteOption else { return }
        editingGroupInfoField = field
        switch field {
        case .groupName:
            groupInfoDraft = squadProfile?.name ?? ""
        case .notice:
            groupInfoDraft = squadProfile?.notice ?? ""
        case .introduction:
            groupInfoDraft = squadProfile?.description ?? ""
        }
    }

    @MainActor
    private func saveGroupInfoField(_ field: GroupInfoEditableField) async {
        guard let profile = squadProfile else { return }
        guard !isSavingGroupInfo else { return }
        isSavingGroupInfo = true
        defer { isSavingGroupInfo = false }

        var input = UpdateSquadInfoInput(
            name: profile.name,
            description: profile.description ?? "",
            isPublic: nil,
            avatarURL: profile.avatarURL,
            bannerURL: nil,
            notice: profile.notice
        )

        let trimmed = groupInfoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field {
        case .groupName:
            input.name = trimmed.isEmpty ? profile.name : trimmed
        case .notice:
            input.notice = trimmed
        case .introduction:
            input.description = trimmed
        }

        do {
            try await repository.updateSquadInfo(squadID: platformSquadID, input: input)
            squadProfile = try await repository.fetchSquadProfile(squadID: platformSquadID)
            editingGroupInfoField = nil
        } catch {
            errorMessage = error.userFacingMessage ?? LT("更新群资料失败", "Failed to update group info", "グループ情報の更新に失敗しました")
        }
    }

    @MainActor
    private func commitGroupNicknameIfNeeded() async {
        let normalizedCurrent = String(
            groupNicknameDraft
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(Self.remarkNameLimit)
        )
        let normalizedCommitted = committedGroupNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCurrent != normalizedCommitted else { return }
        groupNicknameDraft = normalizedCurrent
        await updateGroupNickname()
    }

    @MainActor
    private func updateGroupNickname() async {
        guard !isSavingGroupNickname else { return }
        guard let profile = squadProfile else { return }

        isSavingGroupNickname = true
        defer { isSavingGroupNickname = false }

        do {
            try await repository.updateSquadMySettings(
                squadID: platformSquadID,
                input: UpdateSquadMySettingsInput(
                    nickname: groupNicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : groupNicknameDraft,
                    notificationsEnabled: profile.myNotificationsEnabled ?? true
                )
            )
            let refreshed = try await repository.fetchSquadProfile(squadID: platformSquadID)
            squadProfile = refreshed
            groupNicknameDraft = refreshed.myNickname ?? ""
            committedGroupNickname = groupNicknameDraft
        } catch {
            groupNicknameDraft = committedGroupNickname
            errorMessage = error.userFacingMessage ?? LT("更新群昵称失败", "Failed to update group nickname", "グループニックネームの更新に失敗しました")
        }
    }

    @MainActor
    private func updateGroupAvatar(from item: PhotosPickerItem) async {
        guard conversation.type == .group else { return }
        guard canManageInviteOption else { return }
        guard !isUploadingGroupAvatar else { return }

        isUploadingGroupAvatar = true
        defer {
            isUploadingGroupAvatar = false
            selectedGroupAvatarPhotoItem = nil
        }

        do {
            guard let rawData = try await item.loadTransferable(type: Data.self),
                  !rawData.isEmpty else {
                throw ServiceError.message(LT("无法读取所选图片", "Unable to read the selected image", "選択した画像を読み取れません"))
            }

            let uploadData: Data
            if let image = UIImage(data: rawData),
               let jpegData = image.jpegData(compressionQuality: 0.88) {
                uploadData = jpegData
            } else {
                uploadData = rawData
            }

            let uploaded = try await repository.uploadSquadAvatar(
                squadID: platformSquadID,
                imageData: uploadData,
                fileName: "group-avatar-\(Int(Date().timeIntervalSince1970)).jpg",
                mimeType: "image/jpeg"
            )

            let currentProfile = squadProfile
            let input = UpdateSquadInfoInput(
                name: currentProfile?.name ?? conversation.title,
                description: currentProfile?.description ?? "",
                isPublic: nil,
                avatarURL: uploaded.avatarURL,
                bannerURL: nil,
                notice: currentProfile?.notice ?? ""
            )
            try await repository.updateSquadInfo(squadID: platformSquadID, input: input)
            await loadSquadProfile(force: true)
        } catch {
            errorMessage = error.userFacingMessage ?? LT("更新群头像失败", "Failed to update group avatar", "グループアイコンの更新に失敗しました")
        }
    }

    @ViewBuilder
    private func groupAvatarAccessory(size: CGFloat) -> some View {
        let avatarURL = squadProfile?.avatarURL ?? conversation.avatarURL
        if let resolved = AppConfig.resolvedURLString(avatarURL),
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            AvatarPlaceholderView(size: size, isGroup: true)
        }
    }

    @MainActor
    private func updateBlacklistStatus(_ shouldBlacklist: Bool) async {
        guard conversation.type == .direct else { return }
        guard !isUpdatingBlacklist else { return }
        guard let peerID = directChatUserID else { return }

        isUpdatingBlacklist = true
        defer { isUpdatingBlacklist = false }

        do {
            try await repository.setUserBlacklisted(userID: peerID, blacklisted: shouldBlacklist)
            isBlacklisted = shouldBlacklist
        } catch {
            errorMessage = error.userFacingMessage ?? LT("更新黑名单状态失败", "Failed to update blacklist status", "ブラックリスト状態の更新に失敗しました")
        }
    }

    @MainActor
    private func clearHistory() async {
        guard !isClearing else { return }
        isClearing = true
        defer { isClearing = false }
        do {
            try await repository.clearConversationHistory(conversationID: conversation.id)
            chatStore.clearMessages(for: conversation)
        } catch {
            errorMessage = error.userFacingMessage ?? LT("清空聊天记录失败", "Failed to clear chat history", "チャット履歴の消去に失敗しました")
        }
    }

    @MainActor
    private func leaveSquad() async {
        guard conversation.type == .group else { return }
        guard !isLeaving else { return }
        if (effectiveGroupMyRole ?? squadProfile?.myRole) == "leader" {
            showLeaderLeaveGuide = true
            return
        }
        isLeaving = true
        defer { isLeaving = false }

        do {
            try await repository.leaveSquad(squadID: platformSquadID)
            chatStore.removeConversation(conversationID: conversation.id)
            dismiss()
            onLeaveConversation?()
        } catch {
            let message = error.userFacingMessage ?? LT("退出小队失败", "Failed to leave squad", "Squad の退出に失敗しました")
            if requiresLeaderTransfer(message) {
                showLeaderLeaveGuide = true
                await loadSquadProfile(force: true)
            } else {
                errorMessage = message
            }
        }
    }

    @MainActor
    private func disbandSquad() async {
        guard conversation.type == .group else { return }
        guard !isDisbanding else { return }
        isDisbanding = true
        defer { isDisbanding = false }

        do {
            try await repository.disbandSquad(squadID: platformSquadID)
            chatStore.removeConversation(conversationID: conversation.id)
            dismiss()
            onLeaveConversation?()
        } catch {
            errorMessage = error.userFacingMessage ?? LT("解散小队失败", "Failed to disband squad", "Squad の解散に失敗しました")
        }
    }

    private func requiresLeaderTransfer(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("leader cannot leave squad")
            || normalized.contains("transfer ownership")
            || message.contains("队长")
    }

    @MainActor
    private func updateInviteOption(_ option: GroupInviteOption) async {
        guard conversation.type == .group else { return }
        guard !isUpdatingInviteOption else { return }
        if option == groupInviteOption { return }

        let previous = groupInviteOption
        isUpdatingInviteOption = true
        defer { isUpdatingInviteOption = false }

        do {
            try await repository.setSquadInviteOption(squadID: platformSquadID, option: option)
            groupInviteOption = option
        } catch {
            groupInviteOption = previous
            errorMessage = error.userFacingMessage ?? LT("更新邀请方式失败", "Failed to update invite option", "招待方式の更新に失敗しました")
        }
    }

    @MainActor
    private func handleInvitedMembers(_ invitedUsers: [UserSummary]) {
        guard conversation.type == .group else { return }
        guard !invitedUsers.isEmpty else { return }

        if var directory = groupMemberDirectory {
            var existingIDs = Set(directory.members.map(\.id))
            for user in invitedUsers where !existingIDs.contains(user.id) {
                directory.members.append(
                    SquadMemberProfile(
                        id: user.id,
                        username: user.username,
                        displayName: user.displayName,
                        avatarURL: user.avatarURL,
                        isFollowing: user.isFollowing,
                        role: "member",
                        nickname: nil,
                        isCaptain: false,
                        isAdmin: false
                    )
                )
                existingIDs.insert(user.id)
            }
            groupMemberDirectory = directory
            if var profile = squadProfile {
                profile.members = directory.members
                profile.memberCount = directory.members.count
                squadProfile = profile
            }
        } else if var profile = squadProfile {
            var existingIDs = Set(profile.members.map(\.id))
            for user in invitedUsers where !existingIDs.contains(user.id) {
                profile.members.append(
                    SquadMemberProfile(
                        id: user.id,
                        username: user.username,
                        displayName: user.displayName,
                        avatarURL: user.avatarURL,
                        isFollowing: user.isFollowing,
                        role: "member",
                        nickname: nil,
                        isCaptain: false,
                        isAdmin: false
                    )
                )
                existingIDs.insert(user.id)
            }
            profile.memberCount = profile.members.count
            squadProfile = profile
        }

        inviteFeedbackMessage = invitedUsers.count == 1
            ? LT("邀请成功", "Invite sent", "招待を送信しました")
            : LT("已邀请 \\(invitedUsers.count) 位成员", "Invited \\(invitedUsers.count) members", "\\(invitedUsers.count) 人のメンバーを招待しました")

        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    inviteFeedbackMessage = nil
                }
            }
        }

        Task {
            await loadGroupMemberDirectory(force: true)
            await loadSquadProfile(force: true)
        }
    }
}

private enum GroupInfoEditableField: String, Identifiable {
    case groupName
    case notice
    case introduction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groupName:
            return LT("群名称", "Group Name", "グループ名")
        case .notice:
            return LT("群公告", "Group Notice", "グループお知らせ")
        case .introduction:
            return LT("群简介", "Group Introduction", "グループ紹介")
        }
    }

    var placeholder: String {
        switch self {
        case .groupName:
            return LT("输入群名称", "Enter group name", "グループ名を入力")
        case .notice:
            return LT("输入群公告", "Enter group notice", "グループお知らせを入力")
        case .introduction:
            return LT("输入群简介", "Enter group introduction", "グループ紹介を入力")
        }
    }
}

private struct GroupInfoFieldEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let field: GroupInfoEditableField
    @Binding var text: String
    let isSaving: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(RaverTheme.card)
        }
        .navigationTitle(field.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(LT("取消", "Cancel", "キャンセル")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onSave()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(LT("保存", "Save", "保存"))
                    }
                }
                .disabled(isSaving)
            }
        }
    }
}

private struct GroupMembersPreviewView: View {
    @Environment(\.appPush) private var appPush

    let members: [SquadMemberProfile]
    let memberCount: Int
    let onShowAll: () -> Void
    let onInvite: () -> Void

    private var previewMembers: [SquadMemberProfile] {
        Array(sortedMembers.prefix(9))
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 48, maximum: 72), spacing: 12), count: 5)
    }

    private var sortedMembers: [SquadMemberProfile] {
        members.sorted { lhs, rhs in
            let lhsRank = memberRank(lhs)
            let rhsRank = memberRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.shownName.localizedCaseInsensitiveCompare(rhs.shownName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("群成员（\\(memberCount)）", "Members (\\(memberCount))", "グループメンバー（\\(memberCount)）"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onShowAll) {
                    HStack(spacing: 4) {
                        Text(LT("全部", "All", "すべて"))
                            .font(.footnote)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(RaverTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 10) {
                ForEach(previewMembers) { member in
                    memberPreviewCell(member)
                }
                invitePreviewCell
            }
        }
        .padding(.vertical, 4)
    }

    private func memberPreviewCell(_ member: SquadMemberProfile) -> some View {
        Button {
            DispatchQueue.main.async {
                appPush(.userProfile(userID: member.id))
            }
        } label: {
            VStack(spacing: 6) {
                memberAvatar(member, size: 40)
                Text(member.shownName)
                    .font(.caption2)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var invitePreviewCell: some View {
        Button(action: onInvite) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(RaverTheme.accent)
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(LT("邀请", "Invite", "招待"))
                    .font(.caption2)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func memberRank(_ member: SquadMemberProfile) -> Int {
        if member.role == "leader" { return 0 }
        if member.role == "admin" { return 1 }
        return 2
    }

    @ViewBuilder
    private func memberAvatar(_ member: SquadMemberProfile, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(member.avatarURL),
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            AvatarPlaceholderView(size: size)
        }
    }
}

private struct InviteSquadMembersView: View {
    @Environment(\.dismiss) private var dismiss

    let squadID: String
    let existingMemberIDs: Set<String>
    let repository: ChatSettingsRepository
    let currentUserID: String
    let onInvited: ([UserSummary]) -> Void

    @State private var friends: [UserSummary] = []
    @State private var selectedUserIDs = Set<String>()
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var availableFriends: [UserSummary] {
        friends.filter { !existingMemberIDs.contains($0.id) && $0.id != currentUserID }
    }

    var body: some View {
        List {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(LT("加载好友中...", "Loading friends...", "友達を読み込み中..."))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            } else if availableFriends.isEmpty {
                ContentUnavailableView(
                    LT("暂无可邀请好友", "No Friends Available", "招待できる友達はいません"),
                    systemImage: "person.2.slash",
                    description: Text(LT("当前没有可邀请进入该群聊的好友。", "There are no friends available to invite into this group chat.", "現在、このグループチャットに招待できる友達はいません。"))
                )
            } else {
                Section {
                    ForEach(availableFriends) { friend in
                        Button {
                            toggleSelection(friend.id)
                        } label: {
                            HStack(spacing: 10) {
                                inviteeAvatar(friend, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .foregroundStyle(Color.primary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: selectedUserIDs.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedUserIDs.contains(friend.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(LT("选择好友", "Select Friends", "友達を選択"))
                } footer: {
                    Text(LT("参考腾讯群聊逻辑，这里通过发送群邀请的方式邀请好友加入。", "Aligned with Tencent group chat flow, invitations are sent to selected friends.", "Tencent グループチャットの流れに合わせ、ここではグループ招待を送信して友達を招待します。"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .raverSystemNavigation(title: LT("邀请成员", "Invite Members", "メンバーを招待"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LT("发送", "Send", "送信")) {
                    Task { await sendInvites() }
                }
                .disabled(selectedUserIDs.isEmpty || isSubmitting || isLoading)
            }
        }
        .alert(LT("操作失败", "Operation Failed", "操作に失敗しました"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await loadFriends()
        }
        .overlay {
            if isSubmitting {
                ProgressView(LT("邀请中...", "Inviting...", "招待中..."))
            }
        }
    }

    private func toggleSelection(_ userID: String) {
        if selectedUserIDs.contains(userID) {
            selectedUserIDs.remove(userID)
        } else {
            selectedUserIDs.insert(userID)
        }
    }

    @MainActor
    private func loadFriends() async {
        guard !currentUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            friends = try await repository.fetchFriends(userID: currentUserID, cursor: nil).users
        } catch {
            errorMessage = error.userFacingMessage ?? LT("加载好友失败", "Failed to load friends", "友達の読み込みに失敗しました")
        }
    }

    @MainActor
    private func sendInvites() async {
        guard !selectedUserIDs.isEmpty else { return }
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let invitedUsers = availableFriends.filter { selectedUserIDs.contains($0.id) }
            for userID in selectedUserIDs {
                try await repository.inviteUserToSquad(squadID: squadID, inviteeUserID: userID)
            }
            onInvited(invitedUsers)
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage ?? LT("发送邀请失败", "Failed to send invite", "招待の送信に失敗しました")
        }
    }

    @ViewBuilder
    private func inviteeAvatar(_ user: UserSummary, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            AvatarPlaceholderView(size: size)
        }
    }
}

private struct GroupMemberListView: View {
    let squadID: String
    let repository: ChatSettingsRepository
    let onDirectoryChanged: (GroupMemberDirectory) -> Void

    @State private var memberDirectory: GroupMemberDirectory
    @State private var selectedProfileUserID: String?
    @State private var pendingRemoveMember: SquadMemberProfile?
    @State private var memberActionTarget: SquadMemberProfile?
    @State private var memberActionInFlightUserID: String?
    @State private var feedbackMessage: String?
    @State private var errorMessage: String?

    init(
        squadID: String,
        memberDirectory: GroupMemberDirectory,
        repository: ChatSettingsRepository,
        onDirectoryChanged: @escaping (GroupMemberDirectory) -> Void
    ) {
        self.squadID = squadID
        self.repository = repository
        self.onDirectoryChanged = onDirectoryChanged
        _memberDirectory = State(initialValue: memberDirectory)
    }

    private var leaders: [SquadMemberProfile] {
        memberDirectory.members.filter { $0.role == "leader" }
    }

    private var admins: [SquadMemberProfile] {
        memberDirectory.members.filter { $0.role == "admin" }
            .sorted { $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending }
    }

    private var members: [SquadMemberProfile] {
        memberDirectory.members.filter { $0.role != "leader" && $0.role != "admin" }
            .sorted { $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending }
    }

    var body: some View {
        List {
            memberSection(title: LT("群主", "Owner", "オーナー"), data: leaders)
            memberSection(title: LT("管理员", "Admins", "管理者"), data: admins)
            memberSection(title: LT("成员", "Members", "メンバー"), data: members)
        }
        .background {
            NavigationLink(
                destination: selectedProfileDestination,
                isActive: Binding(
                    get: { selectedProfileUserID != nil },
                    set: { isActive in
                        if !isActive {
                            selectedProfileUserID = nil
                        }
                    }
                )
            ) {
                EmptyView()
            }
            .hidden()
        }
        .listStyle(.insetGrouped)
        .raverSystemNavigation(title: LT("群成员", "Group Members", "グループメンバー"))
        .confirmationDialog(
            LT("确认移除该成员？", "Remove this member?", "このメンバーを削除しますか？"),
            isPresented: Binding(
                get: { pendingRemoveMember != nil },
                set: { if !$0 { pendingRemoveMember = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(LT("移除成员", "Remove Member", "メンバーを削除"), role: .destructive) {
                guard let member = pendingRemoveMember else { return }
                Task { await removeMember(member) }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(
                pendingRemoveMember == nil
                    ? ""
                    : LT("移除后，该成员将立即被踢出群聊。", "After removal, this member will be kicked from the group immediately.", "削除すると、このメンバーは直ちにグループチャットから退出させられます。")
            )
        }
        .confirmationDialog(
            LT("成员管理", "Member Management", "メンバー管理"),
            isPresented: Binding(
                get: { memberActionTarget != nil },
                set: { if !$0 { memberActionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let member = memberActionTarget {
                memberRoleButtons(for: member)
                if canRemove(member) {
                    Button(LT("移除成员", "Remove Member", "メンバーを削除"), role: .destructive) {
                        pendingRemoveMember = member
                    }
                }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        }
        .alert(LT("操作失败", "Operation Failed", "操作に失敗しました"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.78))
                    )
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func memberSection(title: String, data: [SquadMemberProfile]) -> some View {
        if !data.isEmpty {
            Section(title) {
                ForEach(data) { member in
                    HStack(spacing: 10) {
                        memberAvatar(member, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.shownName)
                                .foregroundStyle(Color.primary)
                            if member.isCaptain {
                                Text(LT("队长", "Leader", "リーダー"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else if member.isAdmin {
                                Text(LT("管理员", "Admin", "管理者"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                        Spacer(minLength: 0)
                        if memberActionInFlightUserID == member.id {
                            ProgressView()
                                .controlSize(.small)
                        } else if canManageMember(member) {
                            Button {
                                memberActionTarget = member
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openUserProfile(member.id)
                    }
                    .contextMenu {
                        memberRoleActions(for: member)
                        if canRemove(member) {
                            Button(role: .destructive) {
                                pendingRemoveMember = member
                            } label: {
                                Label(LT("移除成员", "Remove Member", "メンバーを削除"), systemImage: "person.crop.circle.badge.xmark")
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canRemove(member) {
                            Button(role: .destructive) {
                                pendingRemoveMember = member
                            } label: {
                                Label(LT("移除", "Remove", "削除"), systemImage: "person.crop.circle.badge.xmark")
                            }
                        }
                    }
                }
            }
        }
    }

    private func canManageMember(_ member: SquadMemberProfile) -> Bool {
        canRemove(member) || canManageRole(member)
    }

    private func canManageRole(_ member: SquadMemberProfile) -> Bool {
        switch memberDirectory.myRole {
        case "leader":
            return member.role != "leader"
        default:
            return false
        }
    }

    @ViewBuilder
    private var selectedProfileDestination: some View {
        if let selectedProfileUserID {
            UserProfileView(
                userID: TencentIMIdentity.normalizePlatformUserIDForProfile(selectedProfileUserID)
            )
        } else {
            EmptyView()
        }
    }

    private func openUserProfile(_ userID: String) {
        selectedProfileUserID = userID
    }

    private func canRemove(_ member: SquadMemberProfile) -> Bool {
        guard member.role != "leader" else { return false }
        switch memberDirectory.myRole {
        case "leader":
            return member.role == "admin" || member.role == "member"
        case "admin":
            return member.role == "member"
        default:
            return false
        }
    }

    @ViewBuilder
    private func memberRoleActions(for member: SquadMemberProfile) -> some View {
        switch memberDirectory.myRole {
        case "leader":
            if member.role == "member" {
                Button {
                    Task { await updateMemberRole(member, role: "admin") }
                } label: {
                    Label(LT("设为管理员", "Promote to Admin", "管理者に設定"), systemImage: "person.badge.plus")
                }
            }

            if member.role == "admin" {
                Button {
                    Task { await updateMemberRole(member, role: "member") }
                } label: {
                    Label(LT("降为成员", "Demote to Member", "メンバーに戻す"), systemImage: "person.badge.minus")
                }
            }

            if member.role != "leader" {
                Button {
                    Task { await updateMemberRole(member, role: "leader") }
                } label: {
                    Label(LT("转让队长", "Transfer Leader", "リーダーを譲渡"), systemImage: "crown")
                }
            }
        case "admin":
            EmptyView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func memberRoleButtons(for member: SquadMemberProfile) -> some View {
        switch memberDirectory.myRole {
        case "leader":
            if member.role == "member" {
                Button(LT("设为管理员", "Promote to Admin", "管理者に設定")) {
                    Task { await updateMemberRole(member, role: "admin") }
                }
            }
            if member.role == "admin" {
                Button(LT("降为成员", "Demote to Member", "メンバーに戻す")) {
                    Task { await updateMemberRole(member, role: "member") }
                }
            }
            if member.role != "leader" {
                Button(LT("转让队长", "Transfer Leader", "リーダーを譲渡")) {
                    Task { await updateMemberRole(member, role: "leader") }
                }
            }
        default:
            EmptyView()
        }
    }

    @MainActor
    private func removeMember(_ member: SquadMemberProfile) async {
        guard memberActionInFlightUserID == nil else { return }
        memberActionInFlightUserID = member.id
        defer { memberActionInFlightUserID = nil }

        do {
            try await repository.removeSquadMember(squadID: squadID, memberUserID: member.id)
            pendingRemoveMember = nil
            memberDirectory.members.removeAll { $0.id == member.id }
            onDirectoryChanged(memberDirectory)
            showFeedback(LT("移除成功", "Member removed", "削除しました"))
        } catch {
            errorMessage = error.userFacingMessage ?? LT("移除成员失败", "Failed to remove member", "メンバー削除に失敗しました")
        }
    }

    @MainActor
    private func updateMemberRole(_ member: SquadMemberProfile, role: String) async {
        guard memberActionInFlightUserID == nil else { return }
        memberActionInFlightUserID = member.id
        defer { memberActionInFlightUserID = nil }

        do {
            try await repository.updateSquadMemberRole(squadID: squadID, memberUserID: member.id, role: role)
            if let index = memberDirectory.members.firstIndex(where: { $0.id == member.id }) {
                switch role {
                case "leader":
                    for idx in memberDirectory.members.indices where memberDirectory.members[idx].role == "leader" {
                        memberDirectory.members[idx].role = "member"
                        memberDirectory.members[idx].isCaptain = false
                        memberDirectory.members[idx].isAdmin = false
                    }
                    memberDirectory.members[index].role = "leader"
                    memberDirectory.members[index].isCaptain = true
                    memberDirectory.members[index].isAdmin = false
                    memberDirectory.myRole = "member"
                case "admin":
                    memberDirectory.members[index].role = "admin"
                    memberDirectory.members[index].isCaptain = false
                    memberDirectory.members[index].isAdmin = true
                default:
                    memberDirectory.members[index].role = "member"
                    memberDirectory.members[index].isCaptain = false
                    memberDirectory.members[index].isAdmin = false
                }
            }
            onDirectoryChanged(memberDirectory)
            let feedback = switch role {
            case "leader": LT("已转让队长", "Ownership transferred", "リーダーを譲渡しました")
            case "admin": LT("已设为管理员", "Promoted to admin", "管理者に設定しました")
            default: LT("已降为成员", "Demoted to member", "メンバーに戻しました")
            }
            showFeedback(feedback)
        } catch {
            errorMessage = error.userFacingMessage ?? LT("更新成员角色失败", "Failed to update member role", "メンバー権限の更新に失敗しました")
        }
    }

    @MainActor
    private func showFeedback(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            feedbackMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    feedbackMessage = nil
                }
            }
        }
    }

    @ViewBuilder
    private func memberAvatar(_ member: SquadMemberProfile, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(member.avatarURL),
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            AvatarPlaceholderView(size: size)
        }
    }
}
