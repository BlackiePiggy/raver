import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    let conversation: Conversation
    let service: SocialService

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            messageList

            Divider().overlay(RaverTheme.cardBorder)

            composerBar
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: conversation.title)
        .toolbar {
            if conversation.type == .direct, let peer = conversation.peer {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appPush(.userProfile(userID: peer.id))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(L("查看用户主页", "View User Profile"))
                }
            }
            if conversation.type == .group {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appPush(.squadProfile(squadID: conversation.id))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Dismiss")) {
                    dismissKeyboard()
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
        .overlay {
            if isLoading {
                ProgressView(LL("同步中..."))
            }
        }
        .alert(L("发送失败", "Send Failed"), isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
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
            .scrollDismissesKeyboard(.interactively)
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
            TextField(L("发消息...", "Message..."), text: $input)
                .submitLabel(.send)
                .onSubmit {
                    Task { await sendMessage() }
                }
                .padding(12)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(L("发送", "Send")) {
                Task { await sendMessage() }
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
                    appPush(.userProfile(userID: message.sender.id))
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
                messageBodyWithTime(message)
            }

            if message.isMine {
                Button {
                    appPush(.userProfile(userID: message.sender.id))
                } label: {
                    avatarView(for: message.sender)
                }
                .buttonStyle(.plain)
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
                    appPush(.userProfile(userID: message.sender.id))
                } label: {
                    avatarView(for: message.sender)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                Text(message.sender.displayName)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)

                messageBodyWithTime(message)
            }

            if message.isMine {
                Button {
                    appPush(.userProfile(userID: message.sender.id))
                } label: {
                    avatarView(for: message.sender)
                }
                .buttonStyle(.plain)
            }

            if !message.isMine { Spacer(minLength: 44) }
        }
    }

    @ViewBuilder
    private func messageBodyWithTime(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isMine {
                timeLabel(for: message)
            }

            Text(message.content)
                .padding(10)
                .background(message.isMine ? RaverTheme.accent : RaverTheme.card)
                .foregroundStyle(message.isMine ? Color.white : RaverTheme.primaryText)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !message.isMine {
                timeLabel(for: message)
            }
        }
    }

    private func timeLabel(for message: ChatMessage) -> some View {
        Text(message.createdAt.chatTimeText)
            .font(.caption2)
            .foregroundStyle(RaverTheme.secondaryText)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func avatarView(for user: UserSummary) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           URL(string: resolved) != nil,
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(avatarViewFallback(for: user))
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            avatarViewFallback(for: user)
        }
    }

    private func avatarViewFallback(for user: UserSummary) -> some View {
        let asset = AppConfig.resolvedUserAvatarAssetName(
            userID: user.id,
            username: user.username,
            avatarURL: user.avatarURL
        )
        return Image(asset)
            .resizable()
            .scaledToFill()
            .background(RaverTheme.card)
            .frame(width: 34, height: 34)
            .clipShape(Circle())
    }

    @MainActor
    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await service.fetchMessages(conversationID: conversation.id)
        } catch {
            self.error = error.userFacingMessage
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    @MainActor
    private func sendMessage() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let sent = try await service.sendMessage(conversationID: conversation.id, content: text)
            messages.append(sent)
            input = ""
            dismissKeyboard()
        } catch {
            self.error = error.userFacingMessage
        }
    }
}
