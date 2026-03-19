import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    let conversation: Conversation
    let service: SocialService

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedPeerProfile: UserSummary?

    var body: some View {
        VStack(spacing: 0) {
            messageList

            Divider().overlay(RaverTheme.cardBorder)

            composerBar
        }
        .background(RaverTheme.background)
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if conversation.type == .direct, let peer = conversation.peer {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedPeerProfile = peer
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("查看用户主页")
                }
            }
            if conversation.type == .group {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SquadProfileView(squadID: conversation.id, service: appState.service)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await loadMessages()
            await appState.refreshUnreadMessages()
        }
        .onDisappear {
            Task { await appState.refreshUnreadMessages() }
        }
        .navigationDestination(item: $selectedPeerProfile) { user in
            UserProfileView(userID: user.id)
        }
        .overlay {
            if isLoading {
                ProgressView("同步中...")
            }
        }
        .alert("发送失败", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composerBar: some View {
        HStack(spacing: 8) {
            TextField("发消息...", text: $input)
                .padding(12)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button("发送") {
                Task {
                    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    do {
                        let sent = try await service.sendMessage(conversationID: conversation.id, content: text)
                        messages.append(sent)
                        input = ""
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(RaverTheme.background)
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        if conversation.type == .group {
            groupMessageRow(message)
        } else {
            directMessageRow(message)
        }
    }

    @ViewBuilder
    private func directMessageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isMine { Spacer(minLength: 44) }

            if !message.isMine {
                Button {
                    selectedPeerProfile = message.sender
                } label: {
                    avatarView(for: message.sender)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if !message.isMine {
                    Text(message.sender.displayName)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                Text(message.content)
                    .padding(10)
                    .background(message.isMine ? RaverTheme.accent : RaverTheme.card)
                    .foregroundStyle(message.isMine ? Color.white : RaverTheme.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(message.createdAt.chatTimeText)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            if message.isMine {
                avatarView(for: message.sender)
            }

            if !message.isMine { Spacer(minLength: 44) }
        }
    }

    @ViewBuilder
    private func groupMessageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isMine { Spacer(minLength: 44) }

            if !message.isMine {
                Button {
                    selectedPeerProfile = message.sender
                } label: {
                    avatarView(for: message.sender)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                Text(message.sender.displayName)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)

                Text(message.content)
                    .padding(10)
                    .background(message.isMine ? RaverTheme.accent : RaverTheme.card)
                    .foregroundStyle(message.isMine ? Color.white : RaverTheme.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(message.createdAt.chatTimeText)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            if message.isMine {
                avatarView(for: message.sender)
            }

            if !message.isMine { Spacer(minLength: 44) }
        }
    }

    private func avatarView(for user: UserSummary) -> some View {
        let resolved = AppConfig.resolvedURLString(user.avatarURL)
        return Group {
            if let resolved, !resolved.isEmpty {
                AsyncImage(url: URL(string: resolved)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackAvatar(user.displayName)
                    }
                }
            } else {
                fallbackAvatar(user.displayName)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }

    private func fallbackAvatar(_ name: String) -> some View {
        Circle()
            .fill(RaverTheme.accent.opacity(0.24))
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.caption.bold())
            )
    }

    @MainActor
    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await service.fetchMessages(conversationID: conversation.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
