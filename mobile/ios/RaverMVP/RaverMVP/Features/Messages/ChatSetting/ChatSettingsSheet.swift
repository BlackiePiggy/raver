import SwiftUI

struct ChatSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @FocusState private var isRemarkFieldFocused: Bool

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
    @State private var showLeaveConfirm = false
    @State private var showDisbandConfirm = false
    @State private var showLeaderLeaveGuide = false
    @State private var showGroupMembers = false
    @State private var showBlacklistConfirm = false
    @State private var isSavingRemark = false
    @State private var isUpdatingBlacklist = false
    @State private var isLoadingDirectSettings = false
    @State private var hasLoadedDirectSettings = false
    @State private var isBlacklisted = false
    @State private var directRemarkName = ""
    @State private var committedDirectRemarkName = ""
    @State private var directBaseDisplayName = ""
    @State private var directDisplayNameOverride: String?

    private var platformSquadID: String {
        TencentIMIdentity.normalizePlatformSquadID(conversation.id)
    }

    private var directChatUserID: String? {
        conversation.peer?.id.nilIfBlank ?? conversation.id.nilIfBlank
    }

    private var displayTitle: String {
        if conversation.type == .group {
            return conversation.title
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
            Button(L("去管理小队", "Open Squad Manage")) {
                dismissThenNavigate(.squadManage(squadID: platformSquadID))
            }
            Button(L("我知道了", "Got It"), role: .cancel) {}
        } message: {
            Text(L("当前你是队长，需先在“管理小队”中转让队长后再退出。", "You're the squad leader. Transfer ownership in Manage Squad before leaving."))
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
                headerRow(showChevron: false)
            }
        }
    }

    private var directSections: some View {
        Group {
            Section {
                placeholderRow(titleCN: "聊天历史搜索", titleEN: "Search Chat History", icon: "magnifyingglass") {
                    dismissThenOpenConversationSearch()
                }
                HStack(spacing: 12) {
                    Label(L("设置备注名", "Set Remark Name"), systemImage: "pencil")
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
                    .disabled(isSavingRemark)
                    .onSubmit {
                        Task { await commitInlineRemarkIfNeeded() }
                    }
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
                            destination: GroupMemberListView(profile: profile),
                            isActive: $showGroupMembers
                        ) {
                            EmptyView()
                        }
                        .hidden()

                        Button {
                            showGroupMembers = true
                        } label: {
                            GroupMembersPreviewView(profile: profile)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    placeholderRow(titleCN: "群成员", titleEN: "Group Members", icon: "person.3")
                }
            }

            Section {
                placeholderRow(titleCN: "分享群邀请", titleEN: "Share Group Invite", icon: "square.and.arrow.up")
                placeholderRow(titleCN: "群公告", titleEN: "Group Notice", icon: "megaphone")
                placeholderRow(titleCN: "我在本群的昵称", titleEN: "My Group Nickname", icon: "person.text.rectangle")
                placeholderRow(titleCN: "群备注", titleEN: "Group Remark", icon: "text.bubble")
                placeholderRow(titleCN: "查找聊天记录", titleEN: "Search Chat History", icon: "magnifyingglass") {
                    dismissThenOpenConversationSearch()
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

    private var sharedSections: some View {
        Section {
            if conversation.type == .group {
                Button {
                    dismissThenNavigate(.squadProfile(squadID: squadProfile?.id ?? platformSquadID))
                } label: {
                    Label(L("查看小队主页", "View Squad Profile"), systemImage: "person.3.fill")
                }
            }
        }
    }

    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        let avatarURL: String? = conversation.type == .group
            ? conversation.avatarURL
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
                        groupID: conversation.id,
                        groupName: conversation.title,
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

    private var canDisbandSquad: Bool {
        guard conversation.type == .group else { return false }
        guard let squadProfile else { return false }
        return squadProfile.myRole == "leader"
    }

    private static let remarkNameLimit = 24

    private func dismissThenNavigate(_ route: AppRoute) {
        dismiss()
        DispatchQueue.main.async {
            appPush(route)
        }
    }

    private func openDirectProfile() {
        guard conversation.type == .direct else { return }
        let resolved = TencentIMIdentity.normalizePlatformUserIDForProfile(
            directChatUserID ?? conversation.id
        )
        dismissThenNavigate(.userProfile(userID: resolved))
    }

    private func dismissThenOpenConversationSearch() {
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
        } catch {
            // Keep detail page usable even when profile fetch fails.
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
            async let loadedRemark = service.fetchFriendRemark(userID: peerID)
            async let loadedBlacklistState = service.isUserBlacklisted(userID: peerID)
            let (remark, blacklisted) = try await (loadedRemark, loadedBlacklistState)
            let baseDisplayName = await resolveDirectBaseDisplayName(peerID: peerID)
            let resolvedRemark = remark ?? chatStore.directConversationRemarkOverride(
                conversationID: conversation.id,
                peerUserID: peerID
            ) ?? ""
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
            let localRemark = chatStore.directConversationRemarkOverride(
                conversationID: conversation.id,
                peerUserID: peerID
            ) ?? ""
            directRemarkName = localRemark
            committedDirectRemarkName = localRemark
            directBaseDisplayName = baseDisplayName
            if localRemark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !baseDisplayName.isEmpty {
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

        isSavingRemark = true
        defer { isSavingRemark = false }

        let trimmedRemark = String(
            directRemarkName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(Self.remarkNameLimit)
        )
        let remarkValue = trimmedRemark.isEmpty ? nil : trimmedRemark

        do {
            try await service.setFriendRemark(userID: peerID, remark: remarkValue)

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
            chatStore.updateDirectConversationDisplayName(
                conversationID: conversation.id,
                displayName: resolvedDisplayName
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
        } catch {
            if shouldFallbackToLocalRemark(error) {
                let fallbackDisplayName: String
                if let remarkValue {
                    fallbackDisplayName = remarkValue
                } else {
                    fallbackDisplayName = await resolveDirectBaseDisplayName(peerID: peerID)
                }
                directRemarkName = remarkValue ?? ""
                committedDirectRemarkName = remarkValue ?? ""
                directDisplayNameOverride = fallbackDisplayName
                chatStore.setDirectConversationRemarkOverride(
                    conversationID: conversation.id,
                    peerUserID: peerID,
                    displayName: remarkValue
                )
                chatStore.updateDirectConversationDisplayName(
                    conversationID: conversation.id,
                    displayName: fallbackDisplayName
                )
                NotificationCenter.default.post(
                    name: .raverConversationIdentityUpdated,
                    object: nil,
                    userInfo: [
                        "conversationID": conversation.id,
                        "sdkConversationID": conversation.sdkConversationID ?? "",
                        "displayName": fallbackDisplayName
                    ]
                )
            } else {
                directRemarkName = committedDirectRemarkName
                errorMessage = error.userFacingMessage ?? L("设置备注名失败", "Failed to update remark name")
            }
        }
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

    private func shouldFallbackToLocalRemark(_ error: Error) -> Bool {
        let nsError = error as NSError
        let text = [
            error.localizedDescription,
            error.userFacingMessage,
            nsError.localizedFailureReason,
            nsError.localizedRecoverySuggestion
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
        return text.contains("friend_not_exist")
            || text.contains("friend not exist")
            || text.contains("err_sns_friendup")
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
}

private struct GroupMembersPreviewView: View {
    let profile: SquadProfile

    private var previewMembers: [SquadMemberProfile] {
        Array(profile.members.prefix(8))
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 48, maximum: 72), spacing: 12), count: 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("群成员（\(profile.memberCount)）", "Members (\(profile.memberCount))"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    Text(L("全部", "All"))
                        .font(.footnote)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(RaverTheme.secondaryText)
            }

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 10) {
                ForEach(previewMembers) { member in
                    memberPreviewCell(member)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func memberPreviewCell(_ member: SquadMemberProfile) -> some View {
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

private struct GroupMemberListView: View {
    @Environment(\.appPush) private var appPush

    let profile: SquadProfile

    private var leaders: [SquadMemberProfile] {
        profile.members.filter { $0.role == "leader" }
    }

    private var admins: [SquadMemberProfile] {
        profile.members.filter { $0.role == "admin" }
            .sorted { $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending }
    }

    private var members: [SquadMemberProfile] {
        profile.members.filter { $0.role != "leader" && $0.role != "admin" }
            .sorted { $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending }
    }

    var body: some View {
        List {
            memberSection(title: L("群主", "Owner"), data: leaders)
            memberSection(title: L("管理员", "Admins"), data: admins)
            memberSection(title: L("成员", "Members"), data: members)
        }
        .listStyle(.insetGrouped)
        .raverSystemNavigation(title: L("群成员", "Group Members"))
    }

    @ViewBuilder
    private func memberSection(title: String, data: [SquadMemberProfile]) -> some View {
        if !data.isEmpty {
            Section(title) {
                ForEach(data) { member in
                    Button {
                        appPush(.userProfile(userID: member.id))
                    } label: {
                        HStack(spacing: 10) {
                            memberAvatar(member, size: 34)
                            Text(member.shownName)
                                .foregroundStyle(Color.primary)
                            Spacer(minLength: 0)
                        }
                    }
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
