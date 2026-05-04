import SwiftUI
import Combine
import AVFoundation
import AVFAudio
import ExyteChat
import UIKit

extension Notification.Name {
    static let raverOpenConversationSearch = Notification.Name("raverOpenConversationSearch")
    static let raverConversationIdentityUpdated = Notification.Name("raverConversationIdentityUpdated")
}

private enum RaverMessageMenuAction: MessageMenuAction, Sendable {
    case copy
    case mention
    case reply
    case revoke
    case delete

    static let allCases: [RaverMessageMenuAction] = [.copy, .mention, .reply, .revoke, .delete]

    func title() -> String {
        switch self {
        case .copy:
            return L("复制", "Copy")
        case .mention:
            return L("@TA", "@Mention")
        case .reply:
            return L("回复", "Reply")
        case .revoke:
            return L("撤回", "Recall")
        case .delete:
            return L("删除", "Delete")
        }
    }

    func icon() -> Image {
        switch self {
        case .copy:
            return Image(systemName: "doc.on.doc")
        case .mention:
            return Image(systemName: "at")
        case .reply:
            return Image(systemName: "arrowshape.turn.up.left")
        case .revoke:
            return Image(systemName: "arrow.uturn.backward.circle")
        case .delete:
            return Image(systemName: "trash")
        }
    }

    static func menuItems(for message: Message) -> [RaverMessageMenuAction] {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind != ChatMessageKind.system.rawValue else {
            return []
        }

        var items: [RaverMessageMenuAction] = []
        if (message.customData["canCopy"] as? Bool) == true {
            items.append(.copy)
        }
        if (message.customData["canMention"] as? Bool) == true {
            items.append(.mention)
        }
        if (message.customData["canReply"] as? Bool) == true {
            items.append(.reply)
        }
        if (message.customData["canRevoke"] as? Bool) == true {
            items.append(.revoke)
        }
        if (message.customData["canDelete"] as? Bool) == true {
            items.append(.delete)
        }
        return items
    }
}

struct TencentUIKitChatView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appNavigate) private var appNavigate
    @Environment(\.appPush) private var appPush

    let conversation: Conversation
    let service: SocialService

    @StateObject private var viewModel: ExyteChatConversationViewModel
    @State private var scrollToID: String?
    @State private var isShowingConversationSearch = false
    @State private var highlightedMessageID: String?
    @State private var conversationSearchLocateFailureMessage: String?
    @State private var presentedAudioFile: ChatAudioFilePresentation?
    @State private var composerObservedText = ""
    @State private var composerInjectedText: String?
    @State private var mentionCandidates: [InputMentionCandidate] = []
    @State private var allowMentionAll = false

    private let recorderSettings = RecorderSettings(
        sampleRate: 16000,
        numberOfChannels: 1,
        linearPCMBitDepth: 16
    )

    init(conversation: Conversation, service: SocialService) {
        self.conversation = conversation
        self.service = service
        _viewModel = StateObject(
            wrappedValue: ExyteChatConversationViewModel(
                conversation: conversation,
                service: service
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            chatContent
        }
        .background(chatLifecycleBridge)
        .tint(RaverTheme.accent)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingConversationSearch) {
            ConversationMessageSearchSheet(
                conversation: conversation,
                searchExecutor: { query in
#if DEBUG
                    print("[IMSearchProbe] ui-search query=\(query) conversation=\(conversation.id)")
#endif
                    return try await viewModel.searchMessages(query: query, limit: 50)
                },
                onSelectResult: { result in
                    handleConversationSearchSelection(result)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $presentedAudioFile) { item in
            ChatAudioFilePlayerSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            L("未定位到消息", "Message Not Located"),
            isPresented: Binding(
                get: { conversationSearchLocateFailureMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        conversationSearchLocateFailureMessage = nil
                    }
                }
            )
        ) {
            Button(L("好的", "OK"), role: .cancel) {}
        } message: {
            Text(
                conversationSearchLocateFailureMessage
                ?? L(
                    "该结果暂不在当前加载窗口，请上滑加载更多历史后再试。",
                    "This result is outside the current loaded window. Load more history and try again."
                )
            )
        }
        .onChange(of: conversation) { oldConversation, updatedConversation in
            viewModel.updateConversation(updatedConversation)
            viewModel.updateCurrentSession(appState.session)

            guard oldConversation.id != updatedConversation.id else { return }
            DispatchQueue.main.async {
                IMChatStore.shared.deactivateConversation(oldConversation)
                IMChatStore.shared.activateConversation(updatedConversation)
                viewModel.handleViewDidAppear()
            }
        }
        .onChange(of: appState.session?.user.id) { _, _ in
            viewModel.updateCurrentSession(appState.session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .raverOpenConversationSearch)) { notification in
            guard let requestedConversationID = notification.userInfo?["conversationID"] as? String else { return }
            let matchesBusinessID = requestedConversationID == conversation.id
            let matchesSDKID = requestedConversationID == conversation.sdkConversationID
            guard matchesBusinessID || matchesSDKID else { return }
            isShowingConversationSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .raverConversationIdentityUpdated)) { notification in
            guard notificationMatchesConversation(notification) else { return }
            let displayName = (notification.userInfo?["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let displayName, !displayName.isEmpty else { return }
            viewModel.overrideDirectConversationDisplayName(displayName)
        }
        .task(id: conversation.id) {
            await refreshMentionCandidates()
        }
    }

    private var chatLifecycleBridge: some View {
        TencentChatLifecycleBridge(
            onViewDidLoad: {
                viewModel.updateCurrentSession(appState.session)
                viewModel.onStart()
            },
            onViewDidAppear: {
                IMChatStore.shared.activateConversation(conversation)
                viewModel.updateCurrentSession(appState.session)
                viewModel.handleViewDidAppear()
            },
            onViewWillDisappear: {
                IMChatStore.shared.deactivateConversation(conversation)
                viewModel.handleViewDidDisappear()
                viewModel.onStop()
            }
        )
        .allowsHitTesting(false)
    }

    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image("backArrow", bundle: .current)
                        .renderingMode(.template)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .frame(width: 24, height: 24)
                }

                Button {
                    Task {
                        if conversation.type == .group {
                            let squadID = TencentIMIdentity.normalizePlatformSquadID(conversation.id)
                            await MainActor.run {
                                appNavigate(.squadProfile(squadID: squadID))
                            }
                        } else {
                            guard let userID = await viewModel.resolveHeaderProfileTargetUserID() else { return }
                            await MainActor.run {
                                appNavigate(.userProfile(userID: userID))
                            }
                        }
                    }
                } label: {
                    ExyteAvatarView(
                        presentation: viewModel.chatHeaderAvatar,
                        size: 36
                    )
                }
                .buttonStyle(.plain)
                .disabled(conversation.type == .direct && !viewModel.canOpenHeaderProfile)

                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.chatTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                    Text(viewModel.chatStatus)
                        .font(.footnote)
                        .foregroundColor(Color(hex: "AFB3B8"))
                }

                Spacer(minLength: 0)

                Button {
                    appPush(.messages(.chatSettings(conversation)))
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(RaverTheme.accent)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text(
                        conversation.type == .group
                            ? L("群聊设置", "Group Chat Settings")
                            : L("更多操作", "More Actions")
                    )
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(colorScheme == .dark ? Color.black : Color.white)

            Rectangle()
                .fill(Color(hex: "E5E7EB").opacity(colorScheme == .dark ? 0.2 : 0.8))
                .frame(height: 0.5)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }

    private var chatContent: some View {
        ChatView(messages: viewModel.messages, chatType: .conversation) { draft in
            viewModel.send(draft: draft)
        } messageBuilder: { params in
            groupMessageContent(params)
        } messageMenuAction: { action, defaultActions, message in
            handleMessageMenuAction(action, defaultActions: defaultActions, message: message)
        }
        .enableLoadMore(offset: 1) {
            viewModel.loadMoreMessages()
        }
        .onInputViewTextChange { updatedText in
            composerObservedText = updatedText
            viewModel.handleComposerInputChanged(updatedText)
        }
        .setInputViewText(composerInjectedText, focus: true)
        .scrollToMessageID(scrollToID)
        .keyboardDismissMode(.interactive)
        .showUsername(false)
        .setMentionCandidates(mentionCandidates, allowMentionAll: allowMentionAll)
        .setAvailableInputs([.text, .media, .audio])
        .setMediaPickerLiveCameraStyle(.prominant)
        .setRecorderSettings(recorderSettings)
        .avatarBuilder { user in
            ExyteAvatarView(
                presentation: viewModel.avatarPresentation(for: user),
                size: 32
            )
        }
        .tapAvatarClosure { user, _ in
            guard viewModel.canOpenProfile(for: user) else { return }
            Task {
                guard let userID = await viewModel.resolveProfileTargetUserID(for: user) else { return }
                await MainActor.run {
                    appNavigate(.userProfile(userID: userID))
                }
            }
        }
        .swipeActions(
            edge: .leading,
            performsFirstActionWithFullSwipe: true,
            items: [
                SwipeAction(action: onReply, activeFor: { !$0.user.isCurrentUser }, background: RaverTheme.accent) {
                    VStack {
                        Image(systemName: "arrowshape.turn.up.left")
                            .imageScale(.large)
                            .foregroundStyle(.white)
                            .frame(height: 30)
                        Text("Reply")
                            .foregroundStyle(.white)
                            .font(.footnote)
                    }
                }
            ]
        )
        .chatTheme(chatTheme)
    }

    @ViewBuilder
    private func groupMessageContent(_ params: MessageBuilderParameters) -> some View {
        if let eventCard = eventCardPayload(from: params.message) {
            eventCardMessageContent(params, payload: eventCard)
        } else if let djCard = djCardPayload(from: params.message) {
            djCardMessageContent(params, payload: djCard)
        } else if let audioFile = audioFilePayload(from: params.message) {
            audioFileMessageContent(params, payload: audioFile)
        } else if conversation.type == .group,
           params.message.user.type == .other,
           params.positionInGroup == .single || params.positionInGroup == .first {
            VStack(alignment: .leading, spacing: 1) {
                Text(params.message.user.name)
                    .font(.caption)
                    .foregroundColor(Color(hex: "AFB3B8"))
                    .padding(.leading, 44)
                highlightedMessageContainer(messageID: params.message.id) {
                    params.defaultMessageView()
                }
            }
        } else {
            highlightedMessageContainer(messageID: params.message.id) {
                params.defaultMessageView()
            }
        }
    }

    @ViewBuilder
    private func audioFileMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatAudioFilePayload
    ) -> some View {
        let isMine = params.message.user.isCurrentUser
        let showAvatar = shouldShowAvatar(for: params)
        let showGroupName = conversation.type == .group &&
            params.message.user.type == .other &&
            (params.positionInGroup == .single || params.positionInGroup == .first)

        VStack(
            alignment: isMine ? .trailing : .leading,
            spacing: showGroupName ? 1 : 0
        ) {
            if showGroupName {
                Text(params.message.user.name)
                    .font(.caption)
                    .foregroundColor(Color(hex: "AFB3B8"))
                    .padding(.leading, 44)
            }

            highlightedMessageContainer(messageID: params.message.id) {
                HStack(alignment: .bottom, spacing: 6) {
                    if !isMine {
                        fileMessageAvatar(for: params.message.user, visible: showAvatar)
                    }

                    if isMine {
                        fileMessageTimeView(for: params.message, isMine: true)
                    }

                    Button {
                        openAudioFile(payload, for: params.message)
                    } label: {
                        audioFileBubble(
                            message: params.message,
                            payload: payload
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(payload.rawURL.isEmpty)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.35)
                            .onEnded { _ in
                                params.showContextMenuClosure()
                            }
                    )

                    if !isMine {
                        fileMessageTimeView(for: params.message, isMine: false)
                    }

                    if isMine {
                        fileMessageStatusView(for: params.message.status)
                    }
                }
                .padding(.top, fileRowTopPadding(for: params.positionInGroup, sectionPosition: params.positionInMessagesSection))
                .padding(.horizontal, 12)
                .padding(.leading, isMine ? 72 : 0)
                .padding(.trailing, isMine ? 0 : 72)
                .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
            }
        }
    }

    @ViewBuilder
    private func eventCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatEventCardPayload
    ) -> some View {
        let isMine = params.message.user.isCurrentUser
        let showAvatar = shouldShowAvatar(for: params)
        let showGroupName = conversation.type == .group &&
            params.message.user.type == .other &&
            (params.positionInGroup == .single || params.positionInGroup == .first)

        VStack(
            alignment: isMine ? .trailing : .leading,
            spacing: showGroupName ? 1 : 0
        ) {
            if showGroupName {
                Text(params.message.user.name)
                    .font(.caption)
                    .foregroundColor(Color(hex: "AFB3B8"))
                    .padding(.leading, 44)
            }

            highlightedMessageContainer(messageID: params.message.id) {
                HStack(alignment: .bottom, spacing: 6) {
                    if !isMine {
                        fileMessageAvatar(for: params.message.user, visible: showAvatar)
                    }

                    if isMine {
                        fileMessageTimeView(for: params.message, isMine: true)
                    }

                    Button {
                        appNavigate(.eventDetail(eventID: payload.eventID))
                    } label: {
                        ChatEventCardBubbleView(payload: payload)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.35)
                            .onEnded { _ in
                                params.showContextMenuClosure()
                            }
                    )

                    if !isMine {
                        fileMessageTimeView(for: params.message, isMine: false)
                    }

                    if isMine {
                        fileMessageStatusView(for: params.message.status)
                    }
                }
                .padding(.top, fileRowTopPadding(for: params.positionInGroup, sectionPosition: params.positionInMessagesSection))
                .padding(.horizontal, 12)
                .padding(.leading, isMine ? 72 : 0)
                .padding(.trailing, isMine ? 0 : 72)
                .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
            }
        }
    }

    @ViewBuilder
    private func djCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatDJCardPayload
    ) -> some View {
        let isMine = params.message.user.isCurrentUser
        let showAvatar = shouldShowAvatar(for: params)
        let showGroupName = conversation.type == .group &&
            params.message.user.type == .other &&
            (params.positionInGroup == .single || params.positionInGroup == .first)

        VStack(
            alignment: isMine ? .trailing : .leading,
            spacing: showGroupName ? 1 : 0
        ) {
            if showGroupName {
                Text(params.message.user.name)
                    .font(.caption)
                    .foregroundColor(Color(hex: "AFB3B8"))
                    .padding(.leading, 44)
            }

            highlightedMessageContainer(messageID: params.message.id) {
                HStack(alignment: .bottom, spacing: 6) {
                    if !isMine {
                        fileMessageAvatar(for: params.message.user, visible: showAvatar)
                    }

                    if isMine {
                        fileMessageTimeView(for: params.message, isMine: true)
                    }

                    Button {
                        appNavigate(.djDetail(djID: payload.djID))
                    } label: {
                        ChatDJCardBubbleView(payload: payload)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.35)
                            .onEnded { _ in
                                params.showContextMenuClosure()
                            }
                    )

                    if !isMine {
                        fileMessageTimeView(for: params.message, isMine: false)
                    }

                    if isMine {
                        fileMessageStatusView(for: params.message.status)
                    }
                }
                .padding(.top, fileRowTopPadding(for: params.positionInGroup, sectionPosition: params.positionInMessagesSection))
                .padding(.horizontal, 12)
                .padding(.leading, isMine ? 72 : 0)
                .padding(.trailing, isMine ? 0 : 72)
                .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
            }
        }
    }

    @ViewBuilder
    private func highlightedMessageContainer<Content: View>(
        messageID: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        highlightedMessageID == messageID
                            ? RaverTheme.accent.opacity(0.95)
                            : .clear,
                        lineWidth: 2
                    )
            }
            .animation(.easeOut(duration: 0.25), value: highlightedMessageID == messageID)
    }

    private func onReply(
        message: Message,
        defaultActions: @escaping (Message, DefaultMessageMenuAction) -> Void
    ) {
        defaultActions(message, .reply)
    }

    private func handleMessageMenuAction(
        _ action: RaverMessageMenuAction,
        defaultActions: @escaping (Message, DefaultMessageMenuAction) -> Void,
        message: Message
    ) {
        switch action {
        case .copy:
            defaultActions(message, .copy)
        case .mention:
            insertMentionFromMessage(message)
        case .reply:
            defaultActions(message, .reply)
        case .revoke:
            Task {
                await viewModel.revokeMessage(messageID: message.id)
            }
        case .delete:
            Task {
                await viewModel.deleteMessage(messageID: message.id)
            }
        }
    }

    private var composerMentionCandidates: [RaverChatMentionCandidate] {
        var ordered: [RaverChatMentionCandidate] = []
        var seen = Set<String>()

        func appendCandidate(username: String?, displayName: String?) {
            guard let username else { return }
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUsername.isEmpty else { return }
            let key = trimmedUsername.lowercased()
            guard !seen.contains(key) else { return }

            if let currentUsername = appState.session?.user.username.trimmingCharacters(in: .whitespacesAndNewlines),
               currentUsername.caseInsensitiveCompare(trimmedUsername) == .orderedSame {
                return
            }

            seen.insert(key)
            let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ordered.append(
                RaverChatMentionCandidate(
                    username: trimmedUsername,
                    displayName: trimmedDisplayName
                )
            )
        }

        if conversation.type == .group {
            appendCandidate(
                username: conversation.peer?.username,
                displayName: conversation.peer?.displayName
            )
        }

        for message in viewModel.messages {
            appendCandidate(
                username: message.customData["senderUsername"] as? String,
                displayName: message.customData["senderDisplayName"] as? String
            )
        }

        return ordered.sorted {
            $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending
        }
    }

    private func insertMentionFromMessage(_ message: Message) {
        guard conversation.type == .group else { return }
        let displayName = ((message.customData["senderDisplayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? ((message.customData["senderUsername"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines))
        guard let mentionText = displayName, !mentionText.isEmpty else {
            return
        }

        let existing = composerObservedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty {
            composerInjectedText = "@\(mentionText) "
            return
        }

        let separator = composerObservedText.last?.isWhitespace == true ? "" : " "
        composerInjectedText = composerObservedText + separator + "@\(mentionText) "
    }

    @MainActor
    private func refreshMentionCandidates() async {
        guard conversation.type == .group else {
            mentionCandidates = []
            allowMentionAll = false
            return
        }

        if conversation.type == .group {
            do {
                let directory = try await service.fetchSquadMemberDirectory(squadID: conversation.id)
                mentionCandidates = directory.members
                    .filter { member in
                        let memberID = member.id.trimmingCharacters(in: .whitespacesAndNewlines)
                        let username = member.username.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !username.isEmpty else { return false }
                        if let currentUserID = appState.session?.user.id.trimmingCharacters(in: .whitespacesAndNewlines),
                           !currentUserID.isEmpty,
                           currentUserID.caseInsensitiveCompare(memberID) == .orderedSame {
                            return false
                        }
                        if let currentUsername = appState.session?.user.username.trimmingCharacters(in: .whitespacesAndNewlines),
                           currentUsername.caseInsensitiveCompare(username) == .orderedSame {
                            return false
                        }
                        return true
                    }
                    .map {
                        let resolvedAvatarAsset = AppConfig.resolvedUserAvatarAssetName(
                            userID: $0.id,
                            username: $0.username,
                            avatarURL: $0.avatarURL
                        )
                        return InputMentionCandidate(
                            userID: $0.id,
                            username: $0.username,
                            displayName: $0.shownName,
                            avatarURL: "local-avatar://\(resolvedAvatarAsset)"
                        )
                    }
                    .sorted { $0.mentionText.localizedCaseInsensitiveCompare($1.mentionText) == .orderedAscending }

                let normalizedRole = directory.myRole?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                allowMentionAll = normalizedRole == "leader" || normalizedRole == "admin"
                viewModel.updateMentionCandidates(mentionCandidates, allowMentionAll: allowMentionAll)
                return
            } catch {
                // Fall back to the lightweight local candidate set below.
            }
        }

        mentionCandidates = composerMentionCandidates.map {
            let resolvedAvatarAsset = AppConfig.resolvedUserAvatarAssetName(
                userID: nil,
                username: $0.username,
                avatarURL: nil
            )
            return InputMentionCandidate(
                userID: $0.username.lowercased(),
                username: $0.username,
                displayName: $0.displayName ?? $0.username,
                avatarURL: "local-avatar://\(resolvedAvatarAsset)"
            )
        }
        allowMentionAll = false
        viewModel.updateMentionCandidates(mentionCandidates, allowMentionAll: allowMentionAll)
    }

    private var chatTheme: ChatTheme {
        ChatTheme(
            colors: .init(
                mainBG: RaverTheme.background,
                mainTint: RaverTheme.accent,
                mainText: RaverTheme.primaryText,
                mainCaptionText: RaverTheme.secondaryText,
                messageMyBG: RaverTheme.accent,
                messageReadStatus: RaverTheme.accent.opacity(0.95),
                messageMyText: .white,
                messageMyTimeText: Color.white.opacity(0.78),
                messageFriendBG: RaverTheme.card,
                messageFriendText: RaverTheme.primaryText,
                messageFriendTimeText: RaverTheme.secondaryText,
                messageSystemBG: RaverTheme.card,
                messageSystemText: RaverTheme.primaryText,
                messageSystemTimeText: RaverTheme.secondaryText,
                inputBG: RaverTheme.card,
                inputText: RaverTheme.primaryText,
                inputPlaceholderText: RaverTheme.secondaryText,
                inputSignatureBG: RaverTheme.card,
                inputSignatureText: RaverTheme.primaryText,
                inputSignaturePlaceholderText: RaverTheme.secondaryText,
                menuBG: RaverTheme.card,
                menuText: RaverTheme.primaryText,
                menuTextDelete: .red,
                statusError: .red,
                statusGray: RaverTheme.secondaryText,
                sendButtonBackground: RaverTheme.accent,
                recordDot: RaverTheme.accent
            )
        )
    }

    private func notificationMatchesConversation(_ notification: Notification) -> Bool {
        let requestedConversationID = notification.userInfo?["conversationID"] as? String
        let requestedSDKConversationID = notification.userInfo?["sdkConversationID"] as? String
        let matchesBusinessID = requestedConversationID == conversation.id
        let matchesSDKID = requestedConversationID == conversation.sdkConversationID
        let matchesPostedSDKID = requestedSDKConversationID == conversation.sdkConversationID
        let matchesPostedSDKToBusiness = requestedSDKConversationID == conversation.id
        return matchesBusinessID || matchesSDKID || matchesPostedSDKID || matchesPostedSDKToBusiness
    }

    private func handleConversationSearchSelection(_ result: ChatMessageSearchResult) {
        Task {
            let located = await viewModel.focusSearchResult(result)
            await MainActor.run {
                if located {
                    focusMessageInViewport(result.message.id)
                } else {
                    conversationSearchLocateFailureMessage = L(
                        "该结果暂不在当前加载窗口，请上滑加载更多历史后再试。",
                        "This result is outside the current loaded window. Load more history and try again."
                    )
                }
            }
        }
    }

    private func focusMessageInViewport(_ messageID: String) {
        highlightedMessageID = nil
        scrollToID = nil
        DispatchQueue.main.async {
            scrollToID = messageID
            highlightedMessageID = messageID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard highlightedMessageID == messageID else { return }
            highlightedMessageID = nil
        }
    }

    private func openAudioFile(_ payload: ChatAudioFilePayload, for message: Message) {
        guard !payload.rawURL.isEmpty else { return }
        presentedAudioFile = ChatAudioFilePresentation(
            id: message.id,
            fileName: payload.fileName,
            rawURL: payload.rawURL,
            fileSizeBytes: payload.fileSizeBytes,
            durationSeconds: payload.durationSeconds
        )
    }

    private func audioFilePayload(from message: Message) -> ChatAudioFilePayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.file.rawValue else {
            return nil
        }

        let fileName = (message.customData["fileName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawURL = (message.customData["fileMediaURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileSizeBytes = message.customData["fileSizeBytes"] as? Int
        let durationSeconds = message.customData["fileDurationSeconds"] as? Int

        return ChatAudioFilePayload(
            fileName: (fileName?.isEmpty == false ? fileName! : String(message.attributedText.characters)),
            rawURL: rawURL ?? "",
            fileSizeBytes: fileSizeBytes,
            durationSeconds: durationSeconds
        )
    }

    private func eventCardPayload(from message: Message) -> ChatEventCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "event",
              let eventID = (message.customData["eventID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !eventID.isEmpty,
              let eventName = (message.customData["eventName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !eventName.isEmpty else {
            return nil
        }

        return ChatEventCardPayload(
            eventID: eventID,
            eventName: eventName,
            venueName: (message.customData["venueName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            city: (message.customData["eventCity"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            startAtText: (message.customData["eventStartAtText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["eventCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["eventBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func djCardPayload(from message: Message) -> ChatDJCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "dj",
              let djID = (message.customData["djID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !djID.isEmpty,
              let djName = (message.customData["djName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !djName.isEmpty else {
            return nil
        }

        return ChatDJCardPayload(
            djID: djID,
            djName: djName,
            country: (message.customData["djCountry"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            genreText: (message.customData["djGenreText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["djCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["djBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func shouldShowAvatar(for params: MessageBuilderParameters) -> Bool {
        params.message.user.type == .other &&
            (params.positionInGroup == .single || params.positionInGroup == .last)
    }

    private func fileRowTopPadding(
        for groupPosition: PositionInUserGroup,
        sectionPosition: PositionInMessagesSection
    ) -> CGFloat {
        switch (groupPosition, sectionPosition) {
        case (.first, .middle), (.first, .last), (.single, .middle), (.single, .last):
            return 8
        default:
            return 4
        }
    }

    @ViewBuilder
    private func fileMessageAvatar(for user: User, visible: Bool) -> some View {
        if visible {
            Button {
                guard viewModel.canOpenProfile(for: user) else { return }
                Task {
                    guard let userID = await viewModel.resolveProfileTargetUserID(for: user) else { return }
                    await MainActor.run {
                        appNavigate(.userProfile(userID: userID))
                    }
                }
            } label: {
                ExyteAvatarView(
                    presentation: viewModel.avatarPresentation(for: user),
                    size: 32
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(width: 32, height: 32)
        }
    }

    private func audioFileBubble(message: Message, payload: ChatAudioFilePayload) -> some View {
        ChatAudioFileBubbleView(
            message: message,
            payload: payload
        )
    }

    private func fileMessageTimeView(for message: Message, isMine: Bool) -> some View {
        Text(message.createdAt.chatTimeText)
            .font(.caption)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            .foregroundStyle(isMine ? RaverTheme.secondaryText : RaverTheme.secondaryText)
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func fileMessageStatusView(for status: Message.Status?) -> some View {
        switch status {
        case .sending:
            ProgressView()
                .controlSize(.small)
                .frame(width: 14, height: 14)
                .padding(.bottom, 8)
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.red)
                .padding(.bottom, 8)
        case .read, .sent, .delivered:
            EmptyView()
        case nil:
            EmptyView()
        }
    }

    private func audioFileMetadataText(_ payload: ChatAudioFilePayload, fileType: String) -> String {
        let sizeText: String
        if let fileSizeBytes = payload.fileSizeBytes, fileSizeBytes > 0 {
            sizeText = ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
        } else {
            sizeText = L("未知大小", "Unknown size")
        }
        return "\(fileType) · \(sizeText)"
    }

    private func fileExtensionLabel(from fileName: String) -> String {
        let ext = URL(fileURLWithPath: fileName).pathExtension.uppercased()
        return ext.isEmpty ? L("音频", "Audio") : ext
    }

    private func audioDurationText(_ seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        return Self.durationLabel(for: TimeInterval(seconds))
    }

    private static func durationLabel(for timeInterval: TimeInterval) -> String {
        let totalSeconds = max(Int(timeInterval.rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct ChatAudioFilePayload {
    let fileName: String
    let rawURL: String
    let fileSizeBytes: Int?
    let durationSeconds: Int?
}

private struct ChatEventCardPayload {
    let eventID: String
    let eventName: String
    let venueName: String?
    let city: String?
    let startAtText: String?
    let coverImageURL: String?
    let badgeText: String?
}

private struct ChatDJCardPayload {
    let djID: String
    let djName: String
    let country: String?
    let genreText: String?
    let coverImageURL: String?
    let badgeText: String?
}

private struct ChatAudioFilePresentation: Identifiable {
    let id: String
    let fileName: String
    let rawURL: String
    let fileSizeBytes: Int?
    let durationSeconds: Int?
}

private struct ChatAudioFileResolvedMetadata {
    let playableURL: URL
    let artworkImage: UIImage?
    let durationSeconds: Int?
}

private actor ChatAudioFileMetadataStore {
    static let shared = ChatAudioFileMetadataStore()

    private var cache: [String: ChatAudioFileResolvedMetadata] = [:]

    func resolvedMetadata(
        for rawURL: String,
        fallbackDuration: Int?
    ) async throws -> ChatAudioFileResolvedMetadata {
        let key = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = cache[key] {
            return cached
        }

        guard let resolved = RaverChatMediaResolver.resolvedURL(from: rawURL) else {
            throw ServiceError.message(L("音频地址无效", "Invalid audio URL"))
        }

        let playableURL: URL
        if resolved.isFileURL {
            ChatMediaTempFileStore.noteAccess(for: resolved)
            playableURL = resolved
        } else {
            let (downloadedURL, _) = try await URLSession.shared.download(from: resolved)
            let ext = resolved.pathExtension.isEmpty ? "m4a" : resolved.pathExtension
            playableURL = try ChatMediaTempFileStore.copyFile(
                from: downloadedURL,
                defaultExtension: ext,
                prefix: "audio-file-meta",
                kind: .file
            )
        }

        let metadata = try await loadMetadata(from: playableURL, fallbackDuration: fallbackDuration)
        let resolvedMetadata = ChatAudioFileResolvedMetadata(
            playableURL: playableURL,
            artworkImage: metadata.artworkImage,
            durationSeconds: metadata.durationSeconds
        )
        cache[key] = resolvedMetadata
        return resolvedMetadata
    }

    private func loadMetadata(
        from fileURL: URL,
        fallbackDuration: Int?
    ) async throws -> (artworkImage: UIImage?, durationSeconds: Int?) {
        let asset = AVURLAsset(url: fileURL)
        let durationTime = try? await asset.load(.duration)
        let metadataItems = asset.commonMetadata

        let durationSeconds: Int? = {
            if let durationTime {
                let seconds = CMTimeGetSeconds(durationTime)
                if seconds.isFinite, seconds > 0 {
                    return max(1, Int(seconds.rounded()))
                }
            }
            return fallbackDuration
        }()

        var artworkImage: UIImage?
        for item in metadataItems {
            guard item.commonKey?.rawValue == AVMetadataKey.commonKeyArtwork.rawValue else { continue }
            if let data = item.dataValue, let image = UIImage(data: data) {
                artworkImage = image
                break
            }
            if let value = item.value as? Data, let image = UIImage(data: value) {
                artworkImage = image
                break
            }
        }

        return (artworkImage, durationSeconds)
    }
}

private struct ChatAudioFileBubbleView: View {
    let message: Message
    let payload: ChatAudioFilePayload

    var body: some View {
        let isMine = message.user.isCurrentUser
        let fileType = fileExtensionLabel(from: payload.fileName)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                artworkView(isMine: isMine)

                VStack(alignment: .leading, spacing: 4) {
                    Text(payload.fileName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isMine ? Color.white : RaverTheme.primaryText)
                        .lineLimit(2)

                    Text(audioFileMetadataText(payload, fileType: fileType))
                        .font(.caption)
                        .foregroundStyle(isMine ? Color.white.opacity(0.8) : RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(isMine ? Color.white : RaverTheme.accent)
            }

            if let durationText = audioDurationText(payload.durationSeconds) {
                Label(durationText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(isMine ? Color.white.opacity(0.74) : RaverTheme.secondaryText)
            } else {
                Label(L("点击播放", "Tap to play"), systemImage: "music.note")
                    .font(.caption)
                    .foregroundStyle(isMine ? Color.white.opacity(0.74) : RaverTheme.secondaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: 272, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isMine ? RaverTheme.accent : RaverTheme.card)
        )
    }

    @ViewBuilder
    private func artworkView(isMine: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isMine ? Color.white.opacity(0.2) : RaverTheme.accent.opacity(0.12))
                .frame(width: 42, height: 42)
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isMine ? Color.white : RaverTheme.accent)
        }
    }

    private func audioFileMetadataText(_ payload: ChatAudioFilePayload, fileType: String) -> String {
        let sizeText: String
        if let fileSizeBytes = payload.fileSizeBytes, fileSizeBytes > 0 {
            sizeText = ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
        } else {
            sizeText = L("未知大小", "Unknown size")
        }
        return "\(fileType) · \(sizeText)"
    }

    private func fileExtensionLabel(from fileName: String) -> String {
        let ext = URL(fileURLWithPath: fileName).pathExtension.uppercased()
        return ext.isEmpty ? L("音频", "Audio") : ext
    }

    private func audioDurationText(_ seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        return ChatAudioFilePlayerViewModel.durationLabel(TimeInterval(seconds))
    }
}

private struct ChatEventCardBubbleView: View {
    let payload: ChatEventCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.eventName,
            fallbackSystemImage: "ticket.fill"
        )
    }
}

private struct ChatDJCardBubbleView: View {
    let payload: ChatDJCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.djName,
            fallbackSystemImage: "music.mic"
        )
    }
}

private struct ChatPosterCardBubble: View {
    @Environment(\.colorScheme) private var colorScheme

    let imageURL: String?
    let badgeText: String?
    let title: String
    let fallbackSystemImage: String

    private let cardWidth: CGFloat = 224
    private let cardCornerRadius: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverView
                .frame(width: cardWidth, height: cardWidth)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                if let badgeText, !badgeText.isEmpty {
                    Text(badgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(badgeForegroundColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeBackgroundColor, in: Capsule())
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: cardWidth, alignment: .leading)
            .background(infoBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private var infoBackground: some ShapeStyle {
        LinearGradient(
            colors: colorScheme == .dark ? darkInfoColors : lightInfoColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lightInfoColors: [Color] {
        [
            Color(red: 0.93, green: 0.93, blue: 0.95),
            Color(red: 0.87, green: 0.87, blue: 0.90),
            RaverTheme.accent.opacity(0.12)
        ]
    }

    private var darkInfoColors: [Color] {
        [
            Color(red: 0.20, green: 0.20, blue: 0.23),
            Color(red: 0.14, green: 0.14, blue: 0.17),
            RaverTheme.accent.opacity(0.18)
        ]
    }

    private var dividerColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06)
    }

    private var titleColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.black.opacity(0.84)
    }

    private var badgeForegroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.94)
            : RaverTheme.accent.opacity(0.95)
    }

    private var badgeBackgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : RaverTheme.accent.opacity(0.10)
    }

    @ViewBuilder
    private var coverView: some View {
        if let imageURL,
           let url = URL(string: imageURL),
           !imageURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackCover
                }
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        LinearGradient(
            colors: [RaverTheme.accent.opacity(0.95), Color(red: 0.24, green: 0.20, blue: 0.58)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: fallbackSystemImage)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }
}

private struct ConversationMessageSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    let conversation: Conversation
    let searchExecutor: (String) async throws -> [ChatMessageSearchResult]
    let onSelectResult: (ChatMessageSearchResult) -> Void

    @State private var query = ""
    @State private var results: [ChatMessageSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if !results.isEmpty {
                    ForEach(results, id: \.message.id) { result in
                        Button {
                            onSelectResult(result)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(previewText(for: result.message))
                                    .font(.subheadline)
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(2)

                                HStack(spacing: 6) {
                                    Text(result.message.isMine ? L("我", "Me") : result.message.sender.displayName)
                                        .lineLimit(1)
                                    Text("·")
                                    Text(result.message.createdAt.chatTimeText)
                                        .lineLimit(1)
                                    Text("·")
                                    Text(result.source == .localIndex ? L("本地", "Local") : L("远端", "Remote"))
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !isSearching,
                          errorMessage == nil {
                    ContentUnavailableView(
                        L("无搜索结果", "No Results"),
                        systemImage: "magnifyingglass",
                        description: Text(L("请尝试更换关键词。", "Try a different keyword."))
                    )
                }
            }
            .listStyle(.insetGrouped)
            .overlay(alignment: .center) {
                if isSearching {
                    ProgressView(L("搜索中...", "Searching..."))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: L("搜索当前聊天记录", "Search this conversation")
            )
            .onSubmit(of: .search) {
                triggerSearch(immediate: true)
            }
            .onChange(of: query) { _, _ in
                triggerSearch(immediate: false)
            }
            .navigationTitle(L("搜索聊天记录", "Search in Conversation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("关闭", "Close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(conversation.title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .alert(
            L("搜索失败", "Search Failed"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button(L("好的", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
        }
    }

    private func triggerSearch(immediate: Bool) {
        debounceTask?.cancel()
        let pendingQuery = query
        let normalizedQuery = pendingQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        let delay: UInt64 = immediate ? 0 : 250_000_000
        debounceTask = Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            await performSearch(query: pendingQuery)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await searchExecutor(normalizedQuery)
            errorMessage = nil
        } catch {
            results = []
            errorMessage = error.userFacingMessage
        }
    }

    private func previewText(for message: ChatMessage) -> String {
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.kind == .card,
           let cardPreview = cardPreviewText(from: text) {
            return cardPreview
        }
        if !text.isEmpty {
            return text
        }

        switch message.kind {
        case .image:
            return L("[图片]", "[Image]")
        case .video:
            return L("[视频]", "[Video]")
        case .voice:
            return L("[语音]", "[Voice]")
        case .file:
            return message.media?.fileName ?? L("[文件]", "[File]")
        case .emoji:
            return L("[表情]", "[Emoji]")
        case .location:
            return L("[位置]", "[Location]")
        case .card:
            return L("[名片]", "[Card]")
        case .custom:
            return L("[自定义消息]", "[Custom Message]")
        case .system:
            return L("[系统消息]", "[System Message]")
        case .typing:
            return L("[输入中]", "[Typing]")
        case .unknown:
            return L("[消息]", "[Message]")
        case .text:
            return L("[文本消息]", "[Text Message]")
        }
    }

    private func cardPreviewText(from rawText: String) -> String? {
        if let payload = parseEventCardPayloadForPreview(from: rawText) {
            return "\(L("[活动卡片]", "[Event Card]")) \(payload.eventName)"
        }
        if let payload = parseDJCardPayloadForPreview(from: rawText) {
            return "\(L("[DJ卡片]", "[DJ Card]")) \(payload.djName)"
        }
        return nil
    }

    private func parseEventCardPayloadForPreview(from rawText: String) -> EventShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: EventShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "event",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(EventShareCardPayload.self, from: data)
    }

    private func parseDJCardPayloadForPreview(from rawText: String) -> DJShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: DJShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "dj",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(DJShareCardPayload.self, from: data)
    }
}

private struct ChatAudioFilePlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: ChatAudioFilePresentation
    @StateObject private var viewModel: ChatAudioFilePlayerViewModel

    init(item: ChatAudioFilePresentation) {
        self.item = item
        _viewModel = StateObject(wrappedValue: ChatAudioFilePlayerViewModel(item: item))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 16)

                artworkHero

                VStack(spacing: 8) {
                    Text(item.fileName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(metadataText)
                        .font(.footnote)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { viewModel.progress },
                            set: { viewModel.seek(to: $0) }
                        ),
                        in: 0...1
                    )
                    .tint(RaverTheme.accent)
                    .disabled(!viewModel.isReady)

                    HStack {
                        Text(viewModel.currentTimeLabel)
                        Spacer()
                        Text(viewModel.totalTimeLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.horizontal, 24)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                HStack(spacing: 28) {
                    Button {
                        viewModel.skip(by: -5)
                    } label: {
                        Image(systemName: "gobackward.5")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(RaverTheme.accent)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(RaverTheme.accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isReady)

                    Button {
                        viewModel.togglePlayback()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(RaverTheme.accent)
                                .frame(width: 72, height: 72)
                            if viewModel.isPreparing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.leading, viewModel.isPlaying ? 0 : 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPreparing || (!viewModel.isReady && viewModel.errorMessage == nil))

                    Button {
                        viewModel.skip(by: 5)
                    } label: {
                        Image(systemName: "goforward.5")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(RaverTheme.accent)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(RaverTheme.accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isReady)
                }

                Spacer()
            }
            .background(RaverTheme.background.ignoresSafeArea())
            .navigationTitle(L("音频播放", "Audio Player"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("关闭", "Close")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.prepareIfNeeded()
            viewModel.autoplayIfReady()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var metadataText: String {
        let fileType = URL(fileURLWithPath: item.fileName).pathExtension.uppercased()
        let typeText = fileType.isEmpty ? L("音频文件", "Audio File") : fileType
        let sizeText: String
        if let bytes = item.fileSizeBytes, bytes > 0 {
            sizeText = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        } else {
            sizeText = L("未知大小", "Unknown size")
        }
        let durationText: String
        if viewModel.totalDuration > 0 {
            durationText = ChatAudioFilePlayerViewModel.durationLabel(viewModel.totalDuration)
        } else if let seconds = item.durationSeconds, seconds > 0 {
            durationText = ChatAudioFilePlayerViewModel.durationLabel(TimeInterval(seconds))
        } else {
            durationText = L("时长未知", "Unknown duration")
        }
        return "\(typeText) · \(sizeText) · \(durationText)"
    }

    @ViewBuilder
    private var artworkHero: some View {
        if let artworkImage = viewModel.artworkImage {
            Image(uiImage: artworkImage)
                .resizable()
                .scaledToFill()
                .frame(width: 156, height: 156)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
        } else {
            ZStack {
                Circle()
                    .fill(RaverTheme.accent.opacity(0.12))
                    .frame(width: 132, height: 132)
                Image(systemName: "waveform")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(RaverTheme.accent)
            }
        }
    }
}

@MainActor
private final class ChatAudioFilePlayerViewModel: NSObject, ObservableObject, @preconcurrency AVAudioPlayerDelegate {
    @Published private(set) var isPreparing = false
    @Published private(set) var isReady = false
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var artworkImage: UIImage?

    private let item: ChatAudioFilePresentation
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var isSeeking = false

    init(item: ChatAudioFilePresentation) {
        self.item = item
        super.init()
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(currentTime / totalDuration, 0), 1)
    }

    var currentTimeLabel: String {
        Self.durationLabel(currentTime)
    }

    var totalTimeLabel: String {
        if totalDuration > 0 {
            return Self.durationLabel(totalDuration)
        }
        if let seconds = item.durationSeconds, seconds > 0 {
            return Self.durationLabel(TimeInterval(seconds))
        }
        return "0:00"
    }

    func prepareIfNeeded() async {
        guard !isPreparing, !isReady else { return }
        isPreparing = true
        errorMessage = nil
        defer { isPreparing = false }

        do {
            let metadata = try await ChatAudioFileMetadataStore.shared.resolvedMetadata(
                for: item.rawURL,
                fallbackDuration: item.durationSeconds
            )
            artworkImage = metadata.artworkImage
            try configurePlayer(url: metadata.playableURL)
            if totalDuration <= 0, let resolvedDuration = metadata.durationSeconds {
                totalDuration = TimeInterval(resolvedDuration)
            }
            isReady = true
        } catch {
            errorMessage = error.userFacingMessage
            isReady = false
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
                try AVAudioSession.sharedInstance().setActive(true, options: [])
            } catch {
                errorMessage = error.localizedDescription
            }
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func autoplayIfReady() {
        guard isReady, !isPlaying else { return }
        togglePlayback()
    }

    func skip(by delta: TimeInterval) {
        guard let player else { return }
        let duration = totalDuration > 0 ? totalDuration : player.duration
        let target = min(max(player.currentTime + delta, 0), duration)
        player.currentTime = target
        currentTime = target
    }

    func seek(to progress: Double) {
        guard let player, totalDuration > 0 else { return }
        isSeeking = true
        let clamped = min(max(progress, 0), 1)
        let time = clamped * totalDuration
        player.currentTime = time
        currentTime = time
        isSeeking = false
    }

    func stop() {
        stopTimer()
        player?.stop()
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        _ = flag
        currentTime = player.duration
        isPlaying = false
        stopTimer()
    }

    private func configurePlayer(url: URL) throws {
        stop()
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        totalDuration = player.duration
        currentTime = 0
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                guard !self.isSeeking else { return }
                self.currentTime = player.currentTime
                self.totalDuration = player.duration
                self.isPlaying = player.isPlaying
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    static func durationLabel(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = max(Int(timeInterval.rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    deinit {
        timer?.invalidate()
    }
}

@MainActor
private final class ExyteChatConversationViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published private(set) var chatTitle: String
    @Published private(set) var chatStatus: String
    @Published private(set) var chatHeaderAvatar: ExyteAvatarPresentation

    private var conversation: Conversation
    private let service: SocialService
    private let chatController: RaverChatController
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false
    private var isViewActive = false
    private var currentSessionUser: UserSummary?
    private var latestSourceMessages: [ChatMessage] = []
    private var avatarPresentationsByUserID: [String: ExyteAvatarPresentation] = [:]
    private var lastRequestedReadMessageID: String?
    private var typingResetTask: Task<Void, Never>?
    private var lastSentTypingAt: Date?
    private var isSendingTyping = false
    private var mentionCandidates: [InputMentionCandidate] = []
    private var allowMentionAll = false

    init(conversation: Conversation, service: SocialService) {
        self.conversation = conversation
        self.service = service
        self.chatTitle = conversation.title
        self.chatStatus = ExyteChatConversationViewModel.buildStatus(for: conversation)
        self.chatHeaderAvatar = .initials(
            String(conversation.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
        )
        self.chatController = RaverChatController(
            dataProvider: RaverChatDataProvider(
                conversation: conversation,
                service: service
            )
        )
        refreshConversationIdentity()
        bindController()
    }

    func onStart() {
        guard !hasStarted else { return }
        hasStarted = true
        chatController.start()
    }

    func onStop() {}

    func handleViewDidAppear() {
        isViewActive = true
        markConversationReadIfNeeded(triggerMessageID: latestSourceMessages.last(where: { !$0.isMine })?.id)
    }

    func handleViewDidDisappear() {
        isViewActive = false
        Task { [weak self] in
            await self?.sendTypingStatusIfNeeded(isTyping: false, force: true)
        }
    }

    func loadMoreMessages() {
        Task {
            await chatController.loadOlderMessagesIfNeeded()
        }
    }

    func send(draft: DraftMessage) {
        Task {
            await sendDraft(draft)
        }
    }

    func updateMentionCandidates(_ candidates: [InputMentionCandidate], allowMentionAll: Bool) {
        mentionCandidates = candidates
        self.allowMentionAll = allowMentionAll
    }

    func updateCurrentSession(_ session: Session?) {
        currentSessionUser = session?.user
        refreshConversationIdentity()
        rebuildMessages()
    }

    func updateConversation(_ conversation: Conversation) {
        guard self.conversation != conversation else { return }
        self.conversation = conversation
        lastRequestedReadMessageID = nil
        refreshConversationIdentity()
        rebuildMessages()
    }

    func overrideDirectConversationDisplayName(_ displayName: String) {
        guard conversation.type == .direct else { return }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        conversation.title = trimmed
        if var peer = conversation.peer {
            peer.displayName = trimmed
            conversation.peer = peer
        }
        refreshConversationIdentity()
    }

    func avatarPresentation(for user: User) -> ExyteAvatarPresentation {
        if let presentation = avatarPresentationsByUserID[user.id] {
            return presentation
        }

        if let url = user.avatarURL {
            return .remote(url: url, cacheKey: user.avatarCacheKey)
        }

        if let assetName = Self.localAvatarAssetName(from: user.avatarCacheKey) {
            return .localAsset(name: assetName)
        }

        return .initials(Self.initials(from: user.name))
    }

    var canOpenHeaderProfile: Bool {
        conversation.type == .direct
    }

    func canOpenProfile(for user: User) -> Bool {
        user.type != .system
    }

    func resolveHeaderProfileTargetUserID() async -> String? {
        guard conversation.type == .direct else { return nil }
        let peer = conversation.peer
        return resolveProfileUserID(
            chatUserID: peer?.id ?? conversation.id,
            username: peer?.username,
            displayName: peer?.displayName ?? conversation.title,
            avatarURL: peer?.avatarURL ?? conversation.avatarURL
        )
    }

    func resolveProfileTargetUserID(for user: User) async -> String? {
        if user.type == .current {
            return currentSessionUser?.id
        }
        guard user.type != .system else { return nil }

        if conversation.type == .direct, let peer = conversation.peer {
            return resolveProfileUserID(
                chatUserID: peer.id,
                username: peer.username,
                displayName: peer.displayName,
                avatarURL: peer.avatarURL
            )
        }

        let matchedSource = latestSourceMessages.last {
            if $0.kind == .system {
                return false
            }
            let candidateIDs = [
                normalizedText($0.sender.id),
                normalizedText($0.sender.username)
            ].compactMap { $0 }
            if candidateIDs.contains(user.id) {
                return true
            }
            return normalizedText($0.sender.displayName) == normalizedText(user.name)
        }

        return resolveProfileUserID(
            chatUserID: matchedSource?.sender.id ?? user.id,
            username: matchedSource?.sender.username,
            displayName: matchedSource?.sender.displayName ?? user.name,
            avatarURL: matchedSource?.sender.avatarURL
        )
    }

    func revokeMessage(messageID: String) async {
        do {
            try await chatController.revokeMessage(messageID)
        } catch {
#if DEBUG
            print("[ExyteChatConversationViewModel] revoke failed: \(error.localizedDescription)")
#endif
        }
    }

    func deleteMessage(messageID: String) async {
        do {
            try await chatController.deleteMessage(messageID)
        } catch {
#if DEBUG
            print("[ExyteChatConversationViewModel] delete failed: \(error.localizedDescription)")
#endif
        }
    }

    func searchMessages(query: String, limit: Int = 50) async throws -> [ChatMessageSearchResult] {
        try await chatController.searchMessages(query: query, limit: limit)
    }

    func focusSearchResult(_ result: ChatMessageSearchResult) async -> Bool {
        guard result.conversationID == conversation.id || result.message.conversationID == conversation.id else {
            return false
        }
        return await chatController.revealMessage(messageID: result.message.id)
    }

    private func bindController() {
        chatController.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.latestSourceMessages = messages
                self?.rebuildMessages()
                let latestIncomingMessageID = messages.last(where: { !$0.isMine })?.id
                self?.markConversationReadIfNeeded(triggerMessageID: latestIncomingMessageID)
            }
            .store(in: &cancellables)

        chatController.$latestInputStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.applyTypingStatus(event)
            }
            .store(in: &cancellables)
    }

    private func sendDraft(_ draft: DraftMessage) async {
        let replyMessageID = draft.replyMessage?.id
        var shouldAttachReply = replyMessageID != nil

        do {
            let trimmedText = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText == "/eventcarddemo" {
                let payload = EventShareCardPayload(
                    eventID: "demo-event-001",
                    eventName: "Raver Demo Night",
                    venueName: "Oil Club",
                    city: "Shanghai",
                    startAtISO8601: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 24 * 3)),
                    coverImageURL: "https://images.unsplash.com/photo-1571266028243-d220c9f1db71?auto=format&fit=crop&w=1200&q=80",
                    badgeText: L("活动", "Event")
                )
                try attachReplyIfNeeded(replyMessageID, shouldAttachReply: &shouldAttachReply)
                _ = try await chatController.sendEventCardMessage(payload)
                await sendTypingStatusIfNeeded(isTyping: false, force: true)
                return
            }

            if !trimmedText.isEmpty {
                try attachReplyIfNeeded(replyMessageID, shouldAttachReply: &shouldAttachReply)
                _ = try await chatController.sendTextMessage(
                    trimmedText,
                    mentionCandidates: mentionCandidates,
                    allowMentionAll: allowMentionAll
                )
            }

            if let fileURL = draft.fileURL {
                try attachReplyIfNeeded(replyMessageID, shouldAttachReply: &shouldAttachReply)
                _ = try await chatController.sendFileMessage(fileURL: fileURL)
            }

            if let recordingURL = draft.recording?.url {
                try attachReplyIfNeeded(replyMessageID, shouldAttachReply: &shouldAttachReply)
                _ = try await chatController.sendVoiceMessage(fileURL: recordingURL)
            }

            for media in draft.medias {
                guard let mediaURL = await media.getURL() else { continue }
                try attachReplyIfNeeded(replyMessageID, shouldAttachReply: &shouldAttachReply)
                switch media.type {
                case .image:
                    _ = try await chatController.sendImageMessage(fileURL: mediaURL)
                case .video:
                    _ = try await chatController.sendVideoMessage(fileURL: mediaURL)
                }
            }
            await sendTypingStatusIfNeeded(isTyping: false, force: true)
        } catch {
            if let replyMessageID,
               chatController.replyDraftMessage?.id == replyMessageID {
                chatController.clearReplyDraft()
            }
            await sendTypingStatusIfNeeded(isTyping: false, force: true)
            #if DEBUG
            print("[ExyteChatConversationViewModel] send failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func attachReplyIfNeeded(
        _ replyMessageID: String?,
        shouldAttachReply: inout Bool
    ) throws {
        guard shouldAttachReply, let replyMessageID else { return }
        guard chatController.replyDraftMessage?.id != replyMessageID else {
            shouldAttachReply = false
            return
        }
        let hasTarget = chatController.currentMessagesSnapshot().contains { $0.id == replyMessageID }
        guard hasTarget else {
            throw ServiceError.message(
                L("引用的消息已不可用", "The replied message is no longer available.")
            )
        }
        chatController.toggleReplyDraft(for: replyMessageID)
        shouldAttachReply = false
    }

    private func rebuildMessages() {
        avatarPresentationsByUserID.removeAll(keepingCapacity: true)
        messages = mapMessages(latestSourceMessages)
    }

    private func markConversationReadIfNeeded(triggerMessageID: String?) {
        guard isViewActive else { return }
        if let triggerMessageID, triggerMessageID == lastRequestedReadMessageID {
            return
        }
        if let triggerMessageID {
            lastRequestedReadMessageID = triggerMessageID
        }

        let service = self.service
        let conversationID = conversation.id
        Task {
            do {
                try await service.markConversationRead(conversationID: conversationID)
            } catch {
                #if DEBUG
                print("[ExyteChatConversationViewModel] markConversationRead failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func refreshConversationIdentity() {
        let headerIdentity = resolvedHeaderIdentity()
        chatTitle = headerIdentity.displayName
        refreshChatStatus()
        chatHeaderAvatar = makeAvatarPresentation(
            userID: headerIdentity.id,
            username: headerIdentity.username,
            displayName: headerIdentity.displayName,
            avatarURLString: headerIdentity.avatarURL,
            prefersGroupAsset: conversation.type == .group
        )

#if DEBUG
        print(
            """
            [IMProfile][ChatHeader] \
            conversationID=\(conversation.id) \
            conversationTitle=\(conversation.title) \
            peerID=\(conversation.peer?.id ?? "nil") \
            peerDisplayName=\(conversation.peer?.displayName ?? "nil") \
            peerAvatarURL=\(conversation.peer?.avatarURL ?? "nil") \
            conversationAvatarURL=\(conversation.avatarURL ?? "nil") \
            resolvedHeaderTitle=\(headerIdentity.displayName) \
            resolvedHeaderAvatar=\(headerIdentity.avatarURL ?? "nil")
            """
        )
#endif
    }

    private func mapMessages(_ source: [ChatMessage]) -> [Message] {
        let lookup = Dictionary(uniqueKeysWithValues: source.map { ($0.id, $0) })
        return source.compactMap { mapMessage($0, lookup: lookup) }
    }

    private func mapMessage(
        _ source: ChatMessage,
        lookup: [String: ChatMessage]
    ) -> Message? {
        guard source.kind != .typing else { return nil }

        let attachments = makeAttachments(from: source)
        let recording = makeRecording(from: source)
        let replyMessage = makeReplyMessage(from: source, lookup: lookup)

        return Message(
            id: source.id,
            user: makeUser(from: source),
            status: makeStatus(from: source),
            createdAt: source.createdAt,
            text: source.kind == .text || source.kind == .system ? source.content : "",
            attachments: attachments,
            recording: recording,
            replyMessage: replyMessage,
            customData: makeCustomData(from: source)
        )
    }

    private func makeUser(from source: ChatMessage) -> User {
        let type: UserType = source.kind == .system ? .system : (source.isMine ? .current : .other)
        let identity = resolvedMessageIdentity(for: source)
        let presentation = makeAvatarPresentation(
            userID: identity.id,
            username: identity.username,
            displayName: identity.displayName,
            avatarURLString: identity.avatarURL,
            prefersGroupAsset: false
        )
        avatarPresentationsByUserID[identity.id] = presentation
        return User(
            id: identity.id,
            name: identity.displayName,
            avatarURL: presentation.url,
            avatarCacheKey: presentation.cacheKey,
            type: type
        )
    }

    private func makeStatus(from source: ChatMessage) -> Message.Status? {
        if source.kind == .system {
            return nil
        }
        switch source.deliveryStatus {
        case .sending:
            return .sending
        case .failed:
            return .error(
                DraftMessage(
                    id: source.id,
                    text: source.content,
                    medias: [],
                    giphyMedia: nil,
                    recording: makeRecording(from: source),
                    replyMessage: nil,
                    createdAt: source.createdAt
                )
            )
        case .sent:
            return nil
        }
    }

    private func makeCustomData(from source: ChatMessage) -> [String: any Sendable] {
        var data: [String: any Sendable] = [
            "sourceKind": source.kind.rawValue,
            "senderUsername": source.sender.username,
            "senderDisplayName": source.sender.displayName,
            "senderAvatarURL": source.sender.avatarURL ?? "",
            "canCopy": source.kind == .text,
            "canMention": conversation.type == .group && !source.isMine && source.kind != .system && !source.sender.username.isEmpty,
            "canReply": source.kind != .system && source.deliveryStatus == .sent,
            "canDelete": source.kind != .system && source.deliveryStatus != .sending,
            "canRevoke": source.isMine &&
                source.kind != .system &&
                source.deliveryStatus == .sent &&
                Date().timeIntervalSince(source.createdAt) < 120,
            "fileName": source.media?.fileName ?? source.content,
            "fileMediaURL": source.media?.mediaURL ?? "",
            "fileSizeBytes": source.media?.fileSizeBytes ?? 0,
            "fileDurationSeconds": source.media?.durationSeconds ?? 0
        ]

        if source.kind == .card,
           let payload = parseEventCardPayload(from: source.content) {
            data["cardType"] = "event"
            data["eventID"] = payload.eventID
            data["eventName"] = payload.eventName
            data["venueName"] = payload.venueName ?? ""
            data["eventCity"] = payload.city ?? ""
            data["eventStartAtText"] = eventCardDateText(payload.startAtISO8601)
            data["eventCoverImageURL"] = payload.coverImageURL ?? ""
            data["eventBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
                  let payload = parseDJCardPayload(from: source.content) {
            data["cardType"] = "dj"
            data["djID"] = payload.djID
            data["djName"] = payload.djName
            data["djCountry"] = payload.country ?? ""
            data["djGenreText"] = payload.genreText ?? ""
            data["djCoverImageURL"] = payload.coverImageURL ?? ""
            data["djBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        }

        return data
    }

    private func parseEventCardPayload(from rawContent: String) -> EventShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: EventShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "event",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(EventShareCardPayload.self, from: data)
    }

    private func parseDJCardPayload(from rawContent: String) -> DJShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: DJShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "dj",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(DJShareCardPayload.self, from: data)
    }

    private func eventCardDateText(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return "" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    func handleComposerInputChanged(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { [weak self] in
            await self?.sendTypingStatusIfNeeded(isTyping: !normalized.isEmpty, force: false)
        }
    }

    private func applyTypingStatus(_ event: IMInputStatusEvent?) {
        typingResetTask?.cancel()
        guard let event,
              conversation.type == .direct,
              event.userID != currentSessionUser?.id,
              isConversationMatch(event.conversationID) else {
            refreshChatStatus()
            return
        }

        chatStatus = L("正在输入...", "Typing...")
        typingResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.refreshChatStatus()
            }
        }
    }

    private func refreshChatStatus() {
        chatStatus = Self.buildStatus(for: conversation)
    }

    private func sendTypingStatusIfNeeded(isTyping: Bool, force: Bool) async {
        guard conversation.type == .direct else { return }

        if !force {
            if isTyping {
                if isSendingTyping,
                   let lastSentTypingAt,
                   Date().timeIntervalSince(lastSentTypingAt) < 4 {
                    return
                }
            } else if !isSendingTyping {
                return
            }
        }

        do {
            try await service.sendTypingStatus(conversationID: conversation.id, isTyping: isTyping)
            isSendingTyping = isTyping
            if isTyping {
                lastSentTypingAt = Date()
            } else {
                lastSentTypingAt = nil
            }
        } catch {
            #if DEBUG
            print("[ExyteChatConversationViewModel] typing status failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func isConversationMatch(_ conversationID: String) -> Bool {
        if conversation.id == conversationID {
            return true
        }
        if let sdkConversationID = conversation.sdkConversationID, sdkConversationID == conversationID {
            return true
        }
        return false
    }

    private func makeAttachments(from source: ChatMessage) -> [Attachment] {
        switch source.kind {
        case .image:
            guard
                let thumbnail = RaverChatMediaResolver.resolvedURL(
                    from: source.media?.thumbnailURL ?? source.media?.mediaURL
                ),
                let full = RaverChatMediaResolver.resolvedURL(
                    from: source.media?.mediaURL ?? source.media?.thumbnailURL
                )
            else {
                return []
            }
            return [
                Attachment(
                    id: "\(source.id)-image",
                    thumbnail: thumbnail,
                    full: full,
                    type: .image,
                    thumbnailCacheKey: source.media?.thumbnailURL,
                    fullCacheKey: source.media?.mediaURL
                )
            ]
        case .video:
            guard
                let thumbnail = RaverChatMediaResolver.resolvedURL(
                    from: source.media?.thumbnailURL ?? source.media?.mediaURL
                ),
                let full = RaverChatMediaResolver.resolvedURL(
                    from: source.media?.mediaURL ?? source.media?.thumbnailURL
                )
            else {
                return []
            }
            return [
                Attachment(
                    id: "\(source.id)-video",
                    thumbnail: thumbnail,
                    full: full,
                    type: .video,
                    thumbnailCacheKey: source.media?.thumbnailURL,
                    fullCacheKey: source.media?.mediaURL
                )
            ]
        default:
            return []
        }
    }

    private func makeRecording(from source: ChatMessage) -> Recording? {
        guard source.kind == .voice else { return nil }
        let url = RaverChatMediaResolver.resolvedURL(from: source.media?.mediaURL)
        let duration = Double(source.media?.durationSeconds ?? 0)
        let samples = Array(repeating: CGFloat(0.45), count: 24)
        return Recording(duration: duration, waveformSamples: samples, url: url)
    }

    private func makeReplyMessage(
        from source: ChatMessage,
        lookup: [String: ChatMessage]
    ) -> ReplyMessage? {
        guard let replyToMessageID = source.replyToMessageID else { return nil }
        if let replied = lookup[replyToMessageID] {
            return ReplyMessage(
                id: replied.id,
                user: makeUser(from: replied),
                createdAt: replied.createdAt,
                text: replied.kind == .text || replied.kind == .system ? replied.content : "",
                attachments: makeAttachments(from: replied),
                recording: makeRecording(from: replied)
            )
        }

        if let replyPreview = source.replyPreview, !replyPreview.isEmpty {
            let identity = resolvedMessageIdentity(for: source)
            let presentation = makeAvatarPresentation(
                userID: identity.id,
                username: identity.username,
                displayName: identity.displayName,
                avatarURLString: identity.avatarURL,
                prefersGroupAsset: false
            )
            return ReplyMessage(
                id: replyToMessageID,
                user: User(
                    id: identity.id,
                    name: identity.displayName,
                    avatarURL: presentation.url,
                    avatarCacheKey: presentation.cacheKey,
                    type: .other
                ),
                createdAt: source.createdAt,
                text: replyPreview
            )
        }

        return nil
    }

    private static func buildStatus(for conversation: Conversation) -> String {
        switch conversation.type {
        case .direct:
            return L("在线", "online")
        case .group:
            return L("群聊", "Group chat")
        }
    }

    private func resolvedHeaderIdentity() -> UserSummary {
        switch conversation.type {
        case .direct:
            if let peer = conversation.peer {
                return normalizedIdentity(
                    from: peer,
                    fallbackID: conversation.id,
                    fallbackUsername: conversation.peer?.username ?? conversation.title,
                    fallbackDisplayName: conversation.title,
                    fallbackAvatarURL: resolvedConversationAvatarURL()
                )
            }
            return UserSummary(
                id: conversation.id,
                username: resolvedConversationUsername(),
                displayName: resolvedConversationDisplayName(),
                avatarURL: resolvedConversationAvatarURL(),
                isFollowing: false
            )
        case .group:
            let title = resolvedConversationDisplayName()
            return UserSummary(
                id: conversation.id,
                username: title.isEmpty ? conversation.id : title,
                displayName: title.isEmpty ? L("群聊", "Group chat") : title,
                avatarURL: resolvedConversationAvatarURL(),
                isFollowing: false
            )
        }
    }

    private func resolvedMessageIdentity(for source: ChatMessage) -> UserSummary {
        if source.isMine, let currentSessionUser {
            return normalizedIdentity(
                from: currentSessionUser,
                fallbackID: source.sender.id.isEmpty ? currentSessionUser.id : source.sender.id,
                fallbackUsername: source.sender.username,
                fallbackDisplayName: source.sender.displayName,
                fallbackAvatarURL: source.sender.avatarURL
            )
        }

        if conversation.type == .direct,
           let peer = conversation.peer {
            return normalizedIdentity(
                from: peer,
                fallbackID: source.sender.id,
                fallbackUsername: source.sender.username,
                fallbackDisplayName: resolvedConversationDisplayName(),
                fallbackAvatarURL: source.sender.avatarURL
            )
        }

        return normalizedIdentity(
            from: source.sender,
            fallbackID: source.sender.id,
            fallbackUsername: source.sender.username,
            fallbackDisplayName: source.sender.displayName
        )
    }

    private func normalizedIdentity(
        from user: UserSummary,
        fallbackID: String,
        fallbackUsername: String? = nil,
        fallbackDisplayName: String? = nil,
        fallbackAvatarURL: String? = nil
    ) -> UserSummary {
        let resolvedID = user.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallbackID
            : user.id
        let preferredUsername = normalizedText(user.username) ?? normalizedText(fallbackUsername)
        let resolvedUsername = preferredUsername ?? resolvedID
        let preferredDisplayName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = preferredDisplayName.isEmpty
            ? (normalizedText(fallbackDisplayName) ?? resolvedUsername)
            : preferredDisplayName
        let resolvedAvatarURL = normalizedText(user.avatarURL) ?? normalizedText(fallbackAvatarURL)
        return UserSummary(
            id: resolvedID,
            username: resolvedUsername,
            displayName: resolvedDisplayName,
            avatarURL: resolvedAvatarURL,
            isFollowing: user.isFollowing
        )
    }

    private func resolveProfileUserID(
        chatUserID: String,
        username: String?,
        displayName: String?,
        avatarURL: String?
    ) -> String? {
        let normalizedChatUserID = normalizedText(chatUserID) ?? ""
        guard !normalizedChatUserID.isEmpty else { return nil }

        if normalizedChatUserID == currentSessionUser?.id {
            return normalizedChatUserID
        }

        if !TencentIMIdentity.isTencentIMUserID(normalizedChatUserID) {
            return normalizedChatUserID
        }

        if let decoded = TencentIMIdentity.decodePlatformUserID(fromTencentIMUserID: normalizedChatUserID) {
            return decoded
        }

#if DEBUG
        print(
            "[ExyteChatConversationViewModel] unresolved Tencent IM user mapping chatUserID=\(normalizedChatUserID) " +
            "username=\(username ?? "nil") displayName=\(displayName ?? "nil") avatarURL=\(avatarURL ?? "nil")"
        )
#endif
        return nil
    }

    private func resolvedConversationDisplayName() -> String {
        switch conversation.type {
        case .direct:
            let peerDisplayName = normalizedText(conversation.peer?.displayName)
            let title = normalizedText(conversation.title)
            let username = normalizedText(conversation.peer?.username)
            return peerDisplayName ?? title ?? username ?? conversation.id
        case .group:
            return normalizedText(conversation.title) ?? L("群聊", "Group chat")
        }
    }

    private func resolvedConversationUsername() -> String {
        switch conversation.type {
        case .direct:
            return normalizedText(conversation.peer?.username)
                ?? normalizedText(conversation.peer?.id)
                ?? normalizedText(conversation.title)
                ?? conversation.id
        case .group:
            return normalizedText(conversation.title) ?? conversation.id
        }
    }

    private func resolvedConversationAvatarURL() -> String? {
        switch conversation.type {
        case .direct:
            return normalizedText(conversation.peer?.avatarURL) ?? normalizedText(conversation.avatarURL)
        case .group:
            return normalizedText(conversation.avatarURL)
        }
    }

    private func makeAvatarPresentation(
        userID: String,
        username: String,
        displayName: String,
        avatarURLString: String?,
        prefersGroupAsset: Bool
    ) -> ExyteAvatarPresentation {
        if let localAssetName = Self.localAvatarAssetName(from: avatarURLString) {
            return .localAsset(name: localAssetName)
        }

        if let url = RaverChatMediaResolver.resolvedURL(from: avatarURLString) {
            return .remote(url: url, cacheKey: avatarURLString)
        }

        let assetName = prefersGroupAsset
            ? AppConfig.resolvedGroupAvatarAssetName(
                groupID: userID,
                groupName: displayName,
                avatarURL: avatarURLString
            )
            : AppConfig.resolvedUserAvatarAssetName(
                userID: userID,
                username: username,
                avatarURL: avatarURLString
            )
        return .localAsset(name: assetName)
    }

    private static func localAvatarAssetName(from cacheKey: String?) -> String? {
        guard let cacheKey else { return nil }
        let prefix = "local-avatar://"
        guard cacheKey.hasPrefix(prefix) else { return nil }
        let name = String(cacheKey.dropFirst(prefix.count))
        return name.isEmpty ? nil : name
    }

    private static func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(1)).uppercased()
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum ExyteAvatarPresentation {
    case remote(url: URL, cacheKey: String?)
    case localAsset(name: String)
    case initials(String)

    var url: URL? {
        switch self {
        case .remote(let url, _):
            return url
        case .localAsset, .initials:
            return nil
        }
    }

    var cacheKey: String? {
        switch self {
        case .remote(_, let cacheKey):
            return cacheKey
        case .localAsset(let name):
            return "local-avatar://\(name)"
        case .initials:
            return nil
        }
    }
}

private struct TencentChatLifecycleBridge: UIViewControllerRepresentable {
    let onViewDidLoad: () -> Void
    let onViewDidAppear: () -> Void
    let onViewWillDisappear: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.onViewDidLoad = onViewDidLoad
        controller.onViewDidAppear = onViewDidAppear
        controller.onViewWillDisappear = onViewWillDisappear
        return controller
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.onViewDidLoad = onViewDidLoad
        uiViewController.onViewDidAppear = onViewDidAppear
        uiViewController.onViewWillDisappear = onViewWillDisappear
    }

    final class Controller: UIViewController {
        var onViewDidLoad: (() -> Void)?
        var onViewDidAppear: (() -> Void)?
        var onViewWillDisappear: (() -> Void)?

        override func loadView() {
            let view = UIView(frame: .zero)
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            DispatchQueue.main.async { [weak self] in
                self?.onViewDidLoad?()
            }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            DispatchQueue.main.async { [weak self] in
                self?.onViewDidAppear?()
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            DispatchQueue.main.async { [weak self] in
                self?.onViewWillDisappear?()
            }
        }
    }
}

private struct ExyteAvatarView: View {
    let presentation: ExyteAvatarPresentation
    let size: CGFloat

    var body: some View {
        Group {
            switch presentation {
            case .remote(let url, _):
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackShape
                    }
                }
            case .localAsset(let name):
                Image(name)
                    .resizable()
                    .scaledToFill()
            case .initials(let text):
                ZStack {
                    fallbackShape
                    Text(text)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackShape: some View {
        Circle()
            .fill(Color(hex: "AFB3B8"))
    }
}
