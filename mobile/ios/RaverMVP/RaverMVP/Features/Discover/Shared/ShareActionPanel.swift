import SwiftUI

struct SharePanelPrimaryAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let accentColor: Color
    let action: () -> Void
}

struct SharePanelQuickAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let accentColor: Color
    let action: () -> Void
}

extension Animation {
    static var sharePanelPresentSpring: Animation {
        .interpolatingSpring(
            mass: 0.92,
            stiffness: 210,
            damping: 24,
            initialVelocity: 1.6
        )
    }

    static var sharePanelDismissSpring: Animation {
        .interpolatingSpring(
            mass: 0.86,
            stiffness: 240,
            damping: 28,
            initialVelocity: 0.4
        )
    }
}

struct SharePanelOverlay<PanelContent: View>: View {
    let isVisible: Bool
    let onBackdropTap: () -> Void
    var horizontalPadding: CGFloat = 12
    var bottomPadding: CGFloat = 0
    var hiddenOffset: CGFloat = 320
    @ViewBuilder let panel: () -> PanelContent

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(isVisible ? 0.34 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: onBackdropTap)

            panel()
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
                .offset(y: isVisible ? 0 : hiddenOffset)
                .scaleEffect(isVisible ? 1 : 0.94, anchor: .bottom)
                .opacity(isVisible ? 1 : 0)
        }
        .zIndex(30)
    }
}

struct ShareActionPanel: View {
    let primaryActions: [SharePanelPrimaryAction]
    let quickActions: [SharePanelQuickAction]
    let loadConversations: () async throws -> [Conversation]
    let onSendToConversation: (Conversation, String?) async throws -> Void
    let onDismiss: () -> Void
    let onConversationShared: (Conversation) -> Void
    let onMoreChats: () -> Void
    var shareTitle: String = L("分享至", "Share to")
    var quickActionsTitle: String = L("更多操作", "More actions")
    var noteTitle: String = L("留言并发送", "Add a message")
    var notePlaceholder: String = L("说点什么（可选）", "Say something (optional)")
    var moreChatsTitle: String = L("更多聊天", "More chats")
    var itemSize: CGFloat = 44
    var itemSpacing: CGFloat = 5
    var itemLabelWidth: CGFloat = 60
    var panelHeight: CGFloat = 240
    var maxRecentConversations: Int = 8
    var placeholderConversationCount: Int = 5

    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sendingConversationID: String?
    @State private var selectedConversationID: String?
    @State private var shareNote = ""
    @FocusState private var isNoteFieldFocused: Bool

    private var recentConversations: [Conversation] {
        Array(conversations.prefix(maxRecentConversations))
    }

    private var shareRowSlotCount: Int {
        max(recentConversations.isEmpty ? placeholderConversationCount : recentConversations.count, 1)
    }

    private var selectedConversation: Conversation? {
        guard let selectedConversationID else { return nil }
        return recentConversations.first(where: { $0.id == selectedConversationID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(shareTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: itemSpacing) {
                        ForEach(primaryActions) { actionItem in
                            SharePanelPrimaryActionButton(
                                item: actionItem,
                                size: itemSize,
                                labelWidth: itemLabelWidth
                            ) {
                                onDismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                    actionItem.action()
                                }
                            }
                        }

                        ForEach(0..<shareRowSlotCount, id: \.self) { index in
                            if index < recentConversations.count {
                                let conversation = recentConversations[index]
                                SharePanelRecentConversationButton(
                                    conversation: conversation,
                                    size: itemSize,
                                    labelWidth: itemLabelWidth,
                                    isSelected: selectedConversationID == conversation.id,
                                    isSending: sendingConversationID == conversation.id
                                ) {
                                    toggleSelection(for: conversation)
                                }
                                .transition(.opacity)
                            } else {
                                SharePanelConversationPlaceholder(
                                    size: itemSize,
                                    labelWidth: itemLabelWidth
                                )
                            }
                        }

                        SharePanelMoreChatsButton(
                            size: itemSize,
                            labelWidth: itemLabelWidth,
                            title: moreChatsTitle
                        ) {
                            onDismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                onMoreChats()
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 16)
                    .animation(.easeIn(duration: 0.22), value: recentConversations.map(\.id))
                }
                .padding(.horizontal, -16)
                .padding(.bottom, 2)
                .compositingGroup()
            }

            VStack(alignment: .leading, spacing: 12) {
                if let selectedConversation = selectedConversation {
                    Text(noteTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)

                    HStack(spacing: 10) {
                        TextField(notePlaceholder, text: $shareNote)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.primaryText)
                            .focused($isNoteFieldFocused)
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)
                            .submitLabel(.send)
                            .onSubmit {
                                Task { await sendSelectedConversation() }
                            }

                        Button {
                            Task { await sendSelectedConversation() }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(RaverTheme.accent)
                                    .frame(width: 38, height: 38)
                                if sendingConversationID == selectedConversation.id {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(sendingConversationID != nil)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text(quickActionsTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: itemSpacing) {
                            ForEach(quickActions) { item in
                                SharePanelQuickActionButton(
                                    item: item,
                                    size: itemSize,
                                    labelWidth: itemLabelWidth
                                ) {
                                    onDismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        item.action()
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)
                    .padding(.bottom, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: panelHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(RaverTheme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .task {
            await loadRecentConversations()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func loadRecentConversations() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await loadConversations()
        } catch {
            errorMessage = error.userFacingMessage ?? L("聊天列表加载失败，请稍后重试", "Failed to load chats. Please try again later.")
        }
    }

    private func toggleSelection(for conversation: Conversation) {
        if selectedConversationID == conversation.id {
            selectedConversationID = nil
            shareNote = ""
            isNoteFieldFocused = false
            return
        }
        selectedConversationID = conversation.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if selectedConversationID == conversation.id {
                isNoteFieldFocused = true
            }
        }
    }

    @MainActor
    private func sendSelectedConversation() async {
        guard let selectedConversation else { return }
        guard sendingConversationID == nil else { return }
        sendingConversationID = selectedConversation.id
        defer { sendingConversationID = nil }
        do {
            try await onSendToConversation(selectedConversation, shareNote)
            selectedConversationID = nil
            shareNote = ""
            isNoteFieldFocused = false
            onDismiss()
            onConversationShared(selectedConversation)
        } catch {
            errorMessage = error.userFacingMessage ?? L("分享失败，请稍后重试", "Share failed. Please try again later.")
        }
    }
}

struct ChatShareSheet<PreviewContent: View>: View {
    @Environment(\.dismiss) private var dismiss

    let loadConversations: () async throws -> [Conversation]
    let onShareToConversation: (Conversation) async throws -> Void
    let onComplete: (Conversation) -> Void
    @ViewBuilder let preview: () -> PreviewContent
    var title: String = L("分享到聊天", "Share to Chat")
    var searchPlaceholder: String = L("搜索聊天", "Search chats")

    @State private var conversations: [Conversation] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sendingConversationID: String?

    private var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return conversations }
        return conversations.filter { conversation in
            let fields = [
                conversation.title,
                conversation.peer?.displayName ?? "",
                conversation.peer?.username ?? ""
            ]
            return fields.joined(separator: "\n").lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(RaverTheme.secondaryText.opacity(0.35))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            HStack(spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(RaverTheme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            preview()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(RaverTheme.secondaryText)

                TextField(searchPlaceholder, text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RaverTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Group {
                if isLoading {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(L("正在加载聊天列表", "Loading chats"))
                            .font(.footnote)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredConversations.isEmpty {
                    ContentUnavailableView(
                        L("暂无可分享的聊天", "No chats available"),
                        systemImage: "bubble.left.and.bubble.right"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredConversations) { conversation in
                                ChatShareConversationRow(
                                    conversation: conversation,
                                    isSending: sendingConversationID == conversation.id
                                ) {
                                    Task { await share(to: conversation) }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(RaverTheme.background)
        .task {
            await loadConversationList()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func loadConversationList() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await loadConversations()
        } catch {
            errorMessage = error.userFacingMessage ?? L("聊天列表加载失败，请稍后重试", "Failed to load chats. Please try again later.")
        }
    }

    @MainActor
    private func share(to conversation: Conversation) async {
        guard sendingConversationID == nil else { return }
        sendingConversationID = conversation.id
        defer { sendingConversationID = nil }
        do {
            try await onShareToConversation(conversation)
            dismiss()
            onComplete(conversation)
        } catch {
            errorMessage = error.userFacingMessage ?? L("分享失败，请稍后重试", "Share failed. Please try again later.")
        }
    }
}

private struct SharePanelRecentConversationButton: View {
    let conversation: Conversation
    let size: CGFloat
    let labelWidth: CGFloat
    let isSelected: Bool
    let isSending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    avatar
                        .frame(width: size, height: size)
                        .clipShape(Circle())

                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.56, green: 0.37, blue: 0.96))
                                .frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 1.4)
                        )
                    }

                    if isSending {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.72))
                                .frame(width: 22, height: 22)
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        }
                    }
                }

                Text(conversation.title)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .frame(width: labelWidth)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .compositingGroup()
    }

    @ViewBuilder
    private var avatar: some View {
        if conversation.type == .group,
           let resolved = AppConfig.resolvedURLString(conversation.avatarURL),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(fallbackAvatar)
        } else if conversation.type == .direct,
                  let resolved = AppConfig.resolvedURLString(conversation.peer?.avatarURL ?? conversation.avatarURL),
                  resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
                  URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(fallbackAvatar)
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        let avatarAsset: String = {
            if conversation.type == .group {
                return AppConfig.resolvedGroupAvatarAssetName(
                    groupID: conversation.id,
                    groupName: conversation.title,
                    avatarURL: conversation.avatarURL
                )
            }
            return AppConfig.resolvedUserAvatarAssetName(
                userID: conversation.peer?.id,
                username: conversation.peer?.username,
                avatarURL: conversation.peer?.avatarURL ?? conversation.avatarURL
            )
        }()

        return Image(avatarAsset)
            .resizable()
            .scaledToFill()
    }
}

private struct SharePanelMoreChatsButton: View {
    let size: CGFloat
    let labelWidth: CGFloat
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(RaverTheme.card)
                        .frame(width: size, height: size)
                    Circle()
                        .stroke(RaverTheme.secondaryText.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: size, height: size)
                    Image(systemName: "ellipsis.message")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .frame(width: labelWidth)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SharePanelConversationPlaceholder: View {
    let size: CGFloat
    let labelWidth: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(RaverTheme.card.opacity(0.78))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(RaverTheme.secondaryText.opacity(0.10), lineWidth: 0.8)
                )

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(RaverTheme.card.opacity(0.78))
                .frame(width: labelWidth * 0.66, height: 9)
        }
        .frame(width: labelWidth)
        .redacted(reason: .placeholder)
        .compositingGroup()
    }
}

private struct SharePanelPrimaryActionButton: View {
    let item: SharePanelPrimaryAction
    let size: CGFloat
    let labelWidth: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(item.accentColor.opacity(0.16))
                        .frame(width: size, height: size)
                    Image(systemName: item.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(item.accentColor)
                }

                Text(item.title)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .frame(width: labelWidth)
            }
        }
        .buttonStyle(.plain)
        .compositingGroup()
    }
}

private struct SharePanelQuickActionButton: View {
    let item: SharePanelQuickAction
    let size: CGFloat
    let labelWidth: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(item.accentColor.opacity(0.16))
                        .frame(width: size, height: size)
                    Image(systemName: item.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(item.accentColor)
                }

                Text(item.title)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(width: labelWidth)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ChatShareConversationRow: View {
    let conversation: Conversation
    let isSending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(conversation.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)

                        if conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.accent)
                        }
                    }

                    Text(conversation.previewText)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RaverTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
    }

    @ViewBuilder
    private var avatar: some View {
        if let resolved = AppConfig.resolvedURLString(conversation.avatarURL),
           URL(string: resolved) != nil,
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .background(avatarFallback)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        Circle()
            .fill(RaverTheme.accent.opacity(0.18))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: conversation.type == .group ? "person.3.fill" : "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RaverTheme.accent)
            )
    }
}
