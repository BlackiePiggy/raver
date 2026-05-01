import SwiftUI
import PhotosUI
import UIKit

struct ChatSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @FocusState private var isRemarkFieldFocused: Bool
    @FocusState private var isGroupNicknameFieldFocused: Bool

    let conversation: Conversation
    let service: SocialService
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
        .raverSystemNavigation(title: L("聊天详情", "Chat Details"))
        .overlay {
            if isClearing || isLeaving || isDisbanding {
                ProgressView(LL("同步中..."))
            }
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
        .alert(L("操作失败", "Operation Failed"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            L("确认退出群聊？", "Leave this group?"),
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button(L("删除并退出", "Delete and Leave"), role: .destructive) {
                Task { await leaveSquad() }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("退出后你将无法继续查看群聊内容。", "After leaving, you won't be able to view this chat until rejoining."))
        }
        .confirmationDialog(
            L("确认解散小队？", "Disband this squad?"),
            isPresented: $showDisbandConfirm,
            titleVisibility: .visible
        ) {
            Button(L("解散小队", "Disband Squad"), role: .destructive) {
                Task { await disbandSquad() }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("解散后小队成员与群聊将被移除，且无法恢复。", "Disbanding removes members and group chat and cannot be undone."))
        }
        .alert(L("需要先转让队长", "Transfer Leader First"), isPresented: $showLeaderLeaveGuide) {
            Button(L("查看群成员", "View Members")) {
                showGroupMembers = true
            }
            Button(L("我知道了", "Got It"), role: .cancel) {}
        } message: {
            Text(L("当前你是队长，需先在群成员页转让队长后再退出。", "You're the group owner. Transfer ownership in the member list before leaving."))
        }
        .confirmationDialog(
            isBlacklisted
                ? L("确认将对方移出黑名单？", "Remove this user from blacklist?")
                : L("确认将对方加入黑名单？", "Add this user to blacklist?"),
            isPresented: $showBlacklistConfirm,
            titleVisibility: .visible
        ) {
            Button(
                isBlacklisted
                    ? L("移出黑名单", "Remove from Blacklist")
                    : L("加入黑名单", "Add to Blacklist"),
                role: .destructive
            ) {
                Task { await updateBlacklistStatus(!isBlacklisted) }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(
                isBlacklisted
                    ? L("移出黑名单后，对方将恢复正常聊天权限。", "Removing from blacklist restores normal chat access.")
                    : L("加入黑名单后，你将不会再接收对方的消息。", "After adding to blacklist, you won't receive this user's messages.")
            )
        }
        .confirmationDialog(
            L("邀请方式", "Invite Type"),
            isPresented: $showInviteOptionPicker,
            titleVisibility: .visible
        ) {
            ForEach(GroupInviteOption.allCases, id: \.rawValue) { option in
                Button(option == groupInviteOption ? "✓ \(option.title)" : option.title) {
                    Task { await updateInviteOption(option) }
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("参考腾讯群聊逻辑，只有允许邀请时，成员区的邀请入口才可用。", "Aligned with Tencent group chat logic, member invites are only available when invite is enabled."))
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
                placeholderRow(titleCN: "聊天历史搜索", titleEN: "Search Chat History", icon: "magnifyingglass") {
                    popThenOpenConversationSearch()
                }
                HStack(spacing: 12) {
                    Label(L("设置备注名", "Nickname"), systemImage: "pencil")
                    Spacer(minLength: 12)
                    TextField(
                        L("输入备注名", "Enter remark"),
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
                    Text(L("仅好友支持备注名", "Nickname is available for friends only"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            Section {
                Toggle(L("消息免打扰", "Mute Notifications"), isOn: $notificationsMuted)
                    .disabled(isMuting)
                Toggle(L("置顶聊天", "Pin Chat"), isOn: $topPinned)
            }

            Section {
                Button(role: .destructive) {
                    showBlacklistConfirm = true
                } label: {
                    Label(
                        isBlacklisted
                            ? L("移出黑名单", "Remove from Blacklist")
                            : L("加入黑名单", "Add to Blacklist"),
                        systemImage: isBlacklisted ? "person.crop.circle.badge.checkmark" : "hand.raised"
                    )
                }
                .disabled(isUpdatingBlacklist || isLoadingDirectSettings)
                placeholderRow(titleCN: "举报", titleEN: "Report", icon: "exclamationmark.bubble")
            }

            Section {
                Button(role: .destructive) {
                    Task { await clearHistory() }
                } label: {
                    Label(L("清空聊天记录", "Clear Chat History"), systemImage: "trash")
                }
                .disabled(isClearing)

                placeholderRow(titleCN: "删除好友", titleEN: "Delete Friend", icon: "person.crop.circle.badge.xmark", destructive: true)
            }
        }
    }

    private var groupSections: some View {
        Group {
            Section {
                if isLoadingSquadProfile && squadProfile == nil {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(L("同步群信息中...", "Syncing group info..."))
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
                                service: service,
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
                                service: service,
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
                                    errorMessage = L("当前群聊已禁止邀请成员，请先在“邀请方式”中开启。", "Group invites are disabled. Enable them in Invite Type first.")
                                    return
                                }
                                showInviteMembers = true
                            }
                        )
                    }
                } else {
                    placeholderRow(titleCN: "群成员", titleEN: "Group Members", icon: "person.3")
                }
            }

            Section {
                PhotosPicker(selection: $selectedGroupAvatarPhotoItem, matching: .images) {
                    HStack(spacing: 12) {
                        Text(L("群头像", "Group Avatar"))
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
                    title: L("群名称", "Group Name"),
                    value: squadProfile?.name ?? "",
                    editable: canManageInviteOption,
                    action: { beginEditingGroupInfo(.groupName) }
                )
                groupInfoActionRow(
                    title: L("群公告", "Group Notice"),
                    value: squadProfile?.notice ?? "",
                    editable: canManageInviteOption,
                    action: { beginEditingGroupInfo(.notice) }
                )
                groupInfoActionRow(
                    title: L("群简介", "Group Introduction"),
                    value: squadProfile?.description ?? "",
                    editable: canManageInviteOption,
                    action: { beginEditingGroupInfo(.introduction) }
                )
                HStack(spacing: 12) {
                    Label(L("我在本群的昵称", "My Group Nickname"), systemImage: "person.text.rectangle")
                    Spacer(minLength: 12)
                    TextField(
                        L("输入群昵称", "Enter nickname"),
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
                        Text(L("邀请方式", "Invite Type"))
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
                placeholderRow(titleCN: "查找聊天记录", titleEN: "Search Chat History", icon: "magnifyingglass") {
                    popThenOpenConversationSearch()
                }
            }

            Section {
                Toggle(L("消息免打扰", "Mute Notifications"), isOn: $notificationsMuted)
                    .disabled(isMuting)
                Toggle(L("置顶聊天", "Pin Chat"), isOn: $topPinned)
                placeholderRow(titleCN: "举报", titleEN: "Report", icon: "exclamationmark.bubble")
            }

            Section {
                Button(role: .destructive) {
                    Task { await clearHistory() }
                } label: {
                    Label(L("清空聊天记录", "Clear Chat History"), systemImage: "trash")
                }
                .disabled(isClearing)

                if canDisbandSquad {
                    Button(role: .destructive) {
                        showDisbandConfirm = true
                    } label: {
                        Label(L("解散群聊", "Disband Group"), systemImage: "xmark.circle")
                    }
                    .disabled(isDisbanding || isLeaving)
                }

                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Label(L("删除并退出", "Delete and Leave"), systemImage: "rectangle.portrait.and.arrow.right")
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
            let assetName: String = {
                if conversation.type == .group {
                    return AppConfig.resolvedGroupAvatarAssetName(
                        groupID: platformSquadID,
                        groupName: squadProfile?.name ?? conversation.title,
                        avatarURL: avatarURL
                    )
                }
                return AppConfig.resolvedUserAvatarAssetName(
                    userID: conversation.peer?.id,
                    username: conversation.peer?.username,
                    avatarURL: avatarURL
                )
            }()

            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
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
                    Text(L("群聊", "Group Chat"))
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
        icon: String,
        destructive: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            if let action {
                action()
            } else {
                errorMessage = L("该功能暂未接入，先保留入口。", "This feature is not wired yet. Placeholder for now.")
            }
        } label: {
            Label(L(titleCN, titleEN), systemImage: icon)
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
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L("未设置", "Not Set") : value)
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
            squadProfile = try await service.fetchSquadProfile(squadID: platformSquadID)
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
            let directory = try await service.fetchSquadMemberDirectory(squadID: platformSquadID)
            groupMemberDirectory = directory
            if var profile = squadProfile {
                profile.members = directory.members
                profile.memberCount = directory.members.count
                profile.myRole = directory.myRole ?? profile.myRole
                squadProfile = profile
            }
        } catch {
            if force {
                errorMessage = error.userFacingMessage ?? L("加载群成员失败", "Failed to load group members")
            }
        }
    }

    @MainActor
    private func loadGroupInviteOption(force: Bool) async {
        guard conversation.type == .group else { return }
        if isUpdatingInviteOption && !force { return }

        do {
            groupInviteOption = try await service.fetchSquadInviteOption(squadID: platformSquadID)
        } catch {
            if force {
                errorMessage = error.userFacingMessage ?? L("加载邀请方式失败", "Failed to load invite option")
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
            async let loadedFriends = service.fetchFriends(userID: currentUserID, cursor: nil)
            async let loadedBlacklistState = service.isUserBlacklisted(userID: peerID)
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
            try await service.setConversationMuted(conversationID: conversation.id, muted: muted)
            chatStore.updateConversationMuteState(conversationID: conversation.id, muted: muted)
        } catch {
            notificationsMuted = oldValue
            errorMessage = error.userFacingMessage ?? L("更新免打扰失败", "Failed to update mute status")
        }
    }

    @MainActor
    private func updatePinnedStatus(_ pinned: Bool, rollbackTo oldValue: Bool) async {
        do {
            try await chatStore.setConversationPinned(
                conversationID: conversation.id,
                pinned: pinned,
                using: service
            )
        } catch {
            topPinned = oldValue
            errorMessage = error.userFacingMessage ?? L("更新置顶状态失败", "Failed to update pin status")
        }
    }

    @MainActor
    private func updateRemarkName() async {
        guard conversation.type == .direct else { return }
        guard !isSavingRemark else { return }
        guard let peerID = directChatUserID else { return }
        guard isTencentFriend else {
            errorMessage = L("当前仅支持为好友设置备注名", "Nickname can only be set for friends")
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
        if let profile = try? await service.fetchUserProfile(userID: platformUserID),
           let displayName = profile.displayName.nilIfBlank {
            return displayName
        }

        if let refreshed = try? await service.fetchConversations(type: .direct).first(where: {
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
            try await service.updateSquadInfo(squadID: platformSquadID, input: input)
            squadProfile = try await service.fetchSquadProfile(squadID: platformSquadID)
            editingGroupInfoField = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("更新群资料失败", "Failed to update group info")
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
            try await service.updateSquadMySettings(
                squadID: platformSquadID,
                input: UpdateSquadMySettingsInput(
                    nickname: groupNicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : groupNicknameDraft,
                    notificationsEnabled: profile.myNotificationsEnabled ?? true
                )
            )
            let refreshed = try await service.fetchSquadProfile(squadID: platformSquadID)
            squadProfile = refreshed
            groupNicknameDraft = refreshed.myNickname ?? ""
            committedGroupNickname = groupNicknameDraft
        } catch {
            groupNicknameDraft = committedGroupNickname
            errorMessage = error.userFacingMessage ?? L("更新群昵称失败", "Failed to update group nickname")
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
                throw ServiceError.message(L("无法读取所选图片", "Unable to read the selected image"))
            }

            let uploadData: Data
            if let image = UIImage(data: rawData),
               let jpegData = image.jpegData(compressionQuality: 0.88) {
                uploadData = jpegData
            } else {
                uploadData = rawData
            }

            let uploaded = try await service.uploadSquadAvatar(
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
            try await service.updateSquadInfo(squadID: platformSquadID, input: input)
            await loadSquadProfile(force: true)
        } catch {
            errorMessage = error.userFacingMessage ?? L("更新群头像失败", "Failed to update group avatar")
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
            Image(
                AppConfig.resolvedGroupAvatarAssetName(
                    groupID: platformSquadID,
                    groupName: squadProfile?.name ?? conversation.title,
                    avatarURL: avatarURL
                )
            )
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
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
            try await service.setUserBlacklisted(userID: peerID, blacklisted: shouldBlacklist)
            isBlacklisted = shouldBlacklist
        } catch {
            errorMessage = error.userFacingMessage ?? L("更新黑名单状态失败", "Failed to update blacklist status")
        }
    }

    @MainActor
    private func clearHistory() async {
        guard !isClearing else { return }
        isClearing = true
        defer { isClearing = false }
        do {
            try await service.clearConversationHistory(conversationID: conversation.id)
            chatStore.clearMessages(for: conversation)
        } catch {
            errorMessage = error.userFacingMessage ?? L("清空聊天记录失败", "Failed to clear chat history")
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
            try await service.leaveSquad(squadID: platformSquadID)
            chatStore.removeConversation(conversationID: conversation.id)
            dismiss()
            onLeaveConversation?()
        } catch {
            let message = error.userFacingMessage ?? L("退出小队失败", "Failed to leave squad")
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
            try await service.disbandSquad(squadID: platformSquadID)
            chatStore.removeConversation(conversationID: conversation.id)
            dismiss()
            onLeaveConversation?()
        } catch {
            errorMessage = error.userFacingMessage ?? L("解散小队失败", "Failed to disband squad")
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
            try await service.setSquadInviteOption(squadID: platformSquadID, option: option)
            groupInviteOption = option
        } catch {
            groupInviteOption = previous
            errorMessage = error.userFacingMessage ?? L("更新邀请方式失败", "Failed to update invite option")
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
            ? L("邀请成功", "Invite sent")
            : L("已邀请 \(invitedUsers.count) 位成员", "Invited \(invitedUsers.count) members")

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
            return L("群名称", "Group Name")
        case .notice:
            return L("群公告", "Group Notice")
        case .introduction:
            return L("群简介", "Group Introduction")
        }
    }

    var placeholder: String {
        switch self {
        case .groupName:
            return L("输入群名称", "Enter group name")
        case .notice:
            return L("输入群公告", "Enter group notice")
        case .introduction:
            return L("输入群简介", "Enter group introduction")
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
                Button(L("取消", "Cancel")) {
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
                        Text(L("保存", "Save"))
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
                Text(L("群成员（\(memberCount)）", "Members (\(memberCount))"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onShowAll) {
                    HStack(spacing: 4) {
                        Text(L("全部", "All"))
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
                Text(L("邀请", "Invite"))
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
            Image(
                AppConfig.resolvedUserAvatarAssetName(
                    userID: member.id,
                    username: member.username,
                    avatarURL: member.avatarURL
                )
            )
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}

private struct InviteSquadMembersView: View {
    @Environment(\.dismiss) private var dismiss

    let squadID: String
    let existingMemberIDs: Set<String>
    let service: SocialService
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
                    Text(L("加载好友中...", "Loading friends..."))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            } else if availableFriends.isEmpty {
                ContentUnavailableView(
                    L("暂无可邀请好友", "No Friends Available"),
                    systemImage: "person.2.slash",
                    description: Text(L("当前没有可邀请进入该群聊的好友。", "There are no friends available to invite into this group chat."))
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
                                    Text("@\(friend.username)")
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
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
                    Text(L("选择好友", "Select Friends"))
                } footer: {
                    Text(L("参考腾讯群聊逻辑，这里通过发送群邀请的方式邀请好友加入。", "Aligned with Tencent group chat flow, invitations are sent to selected friends."))
                }
            }
        }
        .listStyle(.insetGrouped)
        .raverSystemNavigation(title: L("邀请成员", "Invite Members"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("发送", "Send")) {
                    Task { await sendInvites() }
                }
                .disabled(selectedUserIDs.isEmpty || isSubmitting || isLoading)
            }
        }
        .alert(L("操作失败", "Operation Failed"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await loadFriends()
        }
        .overlay {
            if isSubmitting {
                ProgressView(LL("邀请中..."))
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
            friends = try await service.fetchFriends(userID: currentUserID, cursor: nil).users
        } catch {
            errorMessage = error.userFacingMessage ?? L("加载好友失败", "Failed to load friends")
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
                try await service.inviteUserToSquad(squadID: squadID, inviteeUserID: userID)
            }
            onInvited(invitedUsers)
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage ?? L("发送邀请失败", "Failed to send invite")
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
            Image(
                AppConfig.resolvedUserAvatarAssetName(
                    userID: user.id,
                    username: user.username,
                    avatarURL: user.avatarURL
                )
            )
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}

private struct GroupMemberListView: View {
    let squadID: String
    let service: SocialService
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
        service: SocialService,
        onDirectoryChanged: @escaping (GroupMemberDirectory) -> Void
    ) {
        self.squadID = squadID
        self.service = service
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
            memberSection(title: L("群主", "Owner"), data: leaders)
            memberSection(title: L("管理员", "Admins"), data: admins)
            memberSection(title: L("成员", "Members"), data: members)
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
        .raverSystemNavigation(title: L("群成员", "Group Members"))
        .confirmationDialog(
            L("确认移除该成员？", "Remove this member?"),
            isPresented: Binding(
                get: { pendingRemoveMember != nil },
                set: { if !$0 { pendingRemoveMember = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L("移除成员", "Remove Member"), role: .destructive) {
                guard let member = pendingRemoveMember else { return }
                Task { await removeMember(member) }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(
                pendingRemoveMember == nil
                    ? ""
                    : L("移除后，该成员将立即被踢出群聊。", "After removal, this member will be kicked from the group immediately.")
            )
        }
        .confirmationDialog(
            L("成员管理", "Member Management"),
            isPresented: Binding(
                get: { memberActionTarget != nil },
                set: { if !$0 { memberActionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let member = memberActionTarget {
                memberRoleButtons(for: member)
                if canRemove(member) {
                    Button(L("移除成员", "Remove Member"), role: .destructive) {
                        pendingRemoveMember = member
                    }
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        }
        .alert(L("操作失败", "Operation Failed"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
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
                                Text(L("队长", "Leader"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else if member.isAdmin {
                                Text(L("管理员", "Admin"))
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
                                Label(L("移除成员", "Remove Member"), systemImage: "person.crop.circle.badge.xmark")
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canRemove(member) {
                            Button(role: .destructive) {
                                pendingRemoveMember = member
                            } label: {
                                Label(L("移除", "Remove"), systemImage: "person.crop.circle.badge.xmark")
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
                    Label(L("设为管理员", "Promote to Admin"), systemImage: "person.badge.plus")
                }
            }

            if member.role == "admin" {
                Button {
                    Task { await updateMemberRole(member, role: "member") }
                } label: {
                    Label(L("降为成员", "Demote to Member"), systemImage: "person.badge.minus")
                }
            }

            if member.role != "leader" {
                Button {
                    Task { await updateMemberRole(member, role: "leader") }
                } label: {
                    Label(L("转让队长", "Transfer Leader"), systemImage: "crown")
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
                Button(L("设为管理员", "Promote to Admin")) {
                    Task { await updateMemberRole(member, role: "admin") }
                }
            }
            if member.role == "admin" {
                Button(L("降为成员", "Demote to Member")) {
                    Task { await updateMemberRole(member, role: "member") }
                }
            }
            if member.role != "leader" {
                Button(L("转让队长", "Transfer Leader")) {
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
            try await service.removeSquadMember(squadID: squadID, memberUserID: member.id)
            pendingRemoveMember = nil
            memberDirectory.members.removeAll { $0.id == member.id }
            onDirectoryChanged(memberDirectory)
            showFeedback(L("移除成功", "Member removed"))
        } catch {
            errorMessage = error.userFacingMessage ?? L("移除成员失败", "Failed to remove member")
        }
    }

    @MainActor
    private func updateMemberRole(_ member: SquadMemberProfile, role: String) async {
        guard memberActionInFlightUserID == nil else { return }
        memberActionInFlightUserID = member.id
        defer { memberActionInFlightUserID = nil }

        do {
            try await service.updateSquadMemberRole(squadID: squadID, memberUserID: member.id, role: role)
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
            case "leader": L("已转让队长", "Ownership transferred")
            case "admin": L("已设为管理员", "Promoted to admin")
            default: L("已降为成员", "Demoted to member")
            }
            showFeedback(feedback)
        } catch {
            errorMessage = error.userFacingMessage ?? L("更新成员角色失败", "Failed to update member role")
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
            Image(
                AppConfig.resolvedUserAvatarAssetName(
                    userID: member.id,
                    username: member.username,
                    avatarURL: member.avatarURL
                )
            )
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}
