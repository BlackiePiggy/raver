import SwiftUI

struct ChatSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush

    let conversation: Conversation
    let service: SocialService
    let chatStore: OpenIMChatStore
    var onLeaveConversation: (() -> Void)? = nil

    @State private var notificationsMuted = false
    @State private var isMuting = false
    @State private var isClearing = false
    @State private var isLeaving = false
    @State private var isDisbanding = false
    @State private var isLoadingSquadProfile = false
    @State private var errorMessage: String?
    @State private var squadProfile: SquadProfile?
    @State private var showLeaveConfirm = false
    @State private var showDisbandConfirm = false
    @State private var showLeaderLeaveGuide = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(L("消息免打扰", "Mute Notifications"), isOn: $notificationsMuted)
                        .disabled(isMuting)
                }

                Section {
                    if conversation.type == .direct {
                        DirectChatSettingsSection(peer: conversation.peer) { peer in
                            dismiss()
                            appPush(.userProfile(userID: peer.id))
                        }
                    } else {
                        if isLoadingSquadProfile && squadProfile == nil {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(L("同步小队权限中...", "Syncing squad permissions..."))
                                    .font(.footnote)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }

                        if let squadProfile {
                            LabeledContent {
                                Text(roleLabel(for: squadProfile.myRole))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(roleColor(for: squadProfile.myRole))
                            } label: {
                                Label(L("我的身份", "My Role"), systemImage: "person.badge.key")
                            }
                        }

                        GroupChatSettingsSection(
                            canManageSquad: canManageSquad,
                            canDisbandSquad: canDisbandSquad,
                            onOpenSquadProfile: {
                                dismiss()
                                appPush(.squadProfile(squadID: conversation.id))
                            },
                            onOpenSquadManage: {
                                dismiss()
                                appPush(.squadManage(squadID: conversation.id))
                            },
                            onOpenInviteApprovals: {
                                dismiss()
                                appPush(.messages(.alertCategory(.squadInvite)))
                            },
                            onDisbandSquad: {
                                showDisbandConfirm = true
                            },
                            onLeaveSquad: {
                                showLeaveConfirm = true
                            },
                            isDisbanding: isDisbanding,
                            isLeaving: isLeaving
                        )

                        if !canManageSquad {
                            Text(L("管理员相关操作需队长/管理员权限", "Admin actions require leader/admin permissions."))
                                .font(.footnote)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await clearHistory() }
                    } label: {
                        Label(L("清空聊天记录", "Clear Chat History"), systemImage: "trash")
                    }
                    .disabled(isClearing)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L("聊天设置", "Chat Settings"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("完成", "Done")) {
                        dismiss()
                    }
                }
            }
        }
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
            L("确认退出小队？", "Leave this squad?"),
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button(L("退出小队", "Leave Squad"), role: .destructive) {
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
            Text(
                L(
                    "解散后小队成员与群聊将被移除，且无法恢复。",
                    "Disbanding removes members and group chat and cannot be undone."
                )
            )
        }
        .alert(L("需要先转让队长", "Transfer Leader First"), isPresented: $showLeaderLeaveGuide) {
            Button(L("去管理小队", "Open Squad Manage")) {
                dismiss()
                appPush(.squadManage(squadID: conversation.id))
            }
            Button(L("我知道了", "Got It"), role: .cancel) {}
        } message: {
            Text(
                L(
                    "当前你是队长，需先在“管理小队”中转让队长后再退出。",
                    "You're the squad leader. Transfer ownership in Manage Squad before leaving."
                )
            )
        }
        .onChange(of: notificationsMuted) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await updateMuteStatus(newValue, rollbackTo: oldValue) }
        }
        .task(id: conversation.id) {
            guard conversation.type == .group else { return }
            await loadSquadProfile(force: false)
        }
    }

    private var canManageSquad: Bool {
        guard conversation.type == .group else { return false }
        guard let squadProfile else { return false }
        if squadProfile.canEditGroup {
            return true
        }
        return squadProfile.myRole == "leader" || squadProfile.myRole == "admin"
    }

    private var canDisbandSquad: Bool {
        guard conversation.type == .group else { return false }
        guard let squadProfile else { return false }
        return squadProfile.myRole == "leader"
    }

    private func roleLabel(for role: String?) -> String {
        switch role {
        case "leader":
            return L("队长", "Leader")
        case "admin":
            return L("管理员", "Admin")
        case "member":
            return L("成员", "Member")
        default:
            return L("未知", "Unknown")
        }
    }

    private func roleColor(for role: String?) -> Color {
        switch role {
        case "leader":
            return .orange
        case "admin":
            return .blue
        default:
            return RaverTheme.secondaryText
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
            squadProfile = try await service.fetchSquadProfile(squadID: conversation.id)
        } catch {
            // Keep chat settings usable even when profile fetch fails.
        }
    }

    @MainActor
    private func updateMuteStatus(_ muted: Bool, rollbackTo oldValue: Bool) async {
        guard !isMuting else { return }
        isMuting = true
        defer { isMuting = false }
        do {
            try await service.setConversationMuted(conversationID: conversation.id, muted: muted)
        } catch {
            notificationsMuted = oldValue
            errorMessage = error.userFacingMessage ?? L("更新免打扰失败", "Failed to update mute status")
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
            try await service.leaveSquad(squadID: conversation.id)
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
            try await service.disbandSquad(squadID: conversation.id)
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
