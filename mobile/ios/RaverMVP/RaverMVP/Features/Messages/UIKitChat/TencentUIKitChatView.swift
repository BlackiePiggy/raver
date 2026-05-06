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
    @State private var recentCardNavigation: RecentCardNavigation?

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
        if let ratingEventCard = ratingEventCardPayload(from: params.message) {
            ratingEventCardMessageContent(params, payload: ratingEventCard)
        } else if let eventCard = eventCardPayload(from: params.message) {
            eventCardMessageContent(params, payload: eventCard)
        } else if let postCard = postCardPayload(from: params.message) {
            postCardMessageContent(params, payload: postCard)
        } else if let ratingUnitCard = ratingUnitCardPayload(from: params.message) {
            ratingUnitCardMessageContent(params, payload: ratingUnitCard)
        } else if let djCard = djCardPayload(from: params.message) {
            djCardMessageContent(params, payload: djCard)
        } else if let setCard = setCardPayload(from: params.message) {
            setCardMessageContent(params, payload: setCard)
        } else if let brandCard = brandCardPayload(from: params.message) {
            brandCardMessageContent(params, payload: brandCard)
        } else if let labelCard = labelCardPayload(from: params.message) {
            labelCardMessageContent(params, payload: labelCard)
        } else if let newsCard = newsCardPayload(from: params.message) {
            newsCardMessageContent(params, payload: newsCard)
        } else if let rankingCard = rankingBoardCardPayload(from: params.message) {
            rankingBoardCardMessageContent(params, payload: rankingCard)
        } else if let idCard = circleIDCardPayload(from: params.message) {
            circleIDCardMessageContent(params, payload: idCard)
        } else if let myCheckinsCard = myCheckinsCardPayload(from: params.message) {
            myCheckinsCardMessageContent(params, payload: myCheckinsCard)
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

                    interactiveBubble {
                        navigateFromChatCard(kind: .event, id: payload.eventID) {
                            appNavigate(.eventDetail(eventID: payload.eventID))
                        }
                    } onLongPress: {
                        params.showContextMenuClosure()
                    } content: {
                        ChatEventCardBubbleView(payload: payload)
                    }

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
    private func postCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatPostCardPayload
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
                        appPush(.postDetail(postID: payload.postID))
                    } label: {
                        ChatPostCardBubbleView(payload: payload)
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
    private func ratingEventCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatRatingEventCardPayload
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

                    interactiveBubble {
#if DEBUG
                        print("[RatingEventResolve] chat-tap route=.circle(.ratingEventDetail(\(payload.eventID)))")
#endif
                        navigateFromChatCard(kind: .ratingEvent, id: payload.eventID) {
                            appPush(.circle(.ratingEventDetail(payload.eventID)))
                        }
                    } onLongPress: {
                        params.showContextMenuClosure()
                    } content: {
                        ChatRatingEventCardBubbleView(payload: payload)
                    }

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
    private func ratingUnitCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatRatingUnitCardPayload
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
                        appPush(.ratingUnitDetail(unitID: payload.unitID))
                    } label: {
                        ChatRatingUnitCardBubbleView(payload: payload)
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
    private func setCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatSetCardPayload
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
                        appPush(.discover(.setDetail(setID: payload.setID)))
                    } label: {
                        ChatSetCardBubbleView(payload: payload)
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
    private func brandCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatBrandCardPayload
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
                        appPush(.discover(.festivalDetail(festivalID: payload.brandID)))
                    } label: {
                        ChatBrandCardBubbleView(payload: payload)
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
    private func labelCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatLabelCardPayload
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
                        appPush(.labelDetail(labelID: payload.labelID))
                    } label: {
                        ChatLabelCardBubbleView(payload: payload)
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
    private func rankingBoardCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatRankingBoardCardPayload
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
                        let board = RankingBoard(
                            id: payload.boardID,
                            title: payload.boardName,
                            subtitle: payload.boardSubtitle,
                            coverImageUrl: payload.coverImageURL,
                            years: [payload.year]
                        )
                        appPush(.rankingBoardDetail(board: board, year: payload.year))
                    } label: {
                        ChatRankingBoardCardBubbleView(payload: payload)
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
    private func circleIDCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatCircleIDCardPayload
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
                        appPush(.circle(.idDetail(entryID: payload.entryID)))
                    } label: {
                        ChatCircleIDCardBubbleView(payload: payload)
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
    private func myCheckinsCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatMyCheckinsCardPayload
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
                        appPush(
                            .profile(
                                .myCheckins(
                                    targetUserID: payload.userID,
                                    title: payload.title,
                                    ownerDisplayName: payload.displayName
                                )
                            )
                        )
                    } label: {
                        ChatMyCheckinsCardBubbleView(payload: payload)
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
    private func newsCardMessageContent(
        _ params: MessageBuilderParameters,
        payload: ChatNewsCardPayload
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
                        appPush(.newsDetail(articleID: payload.articleID))
                    } label: {
                        ChatNewsCardBubbleView(
                            payload: payload,
                            maxWidth: newsCardMaxWidth(
                                message: params.message,
                                isMine: isMine
                            )
                        )
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

    private func newsCardMaxWidth(message: Message, isMine: Bool) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalScreenEdgePadding: CGFloat = 12 * 2
        let oppositeInsetProtection: CGFloat = 72
        let avatarWidth: CGFloat = isMine ? 0 : 32
        let avatarSpacing: CGFloat = isMine ? 0 : 6
        let timeSpacing: CGFloat = 6
        let baseTimeFont = UIFont.preferredFont(forTextStyle: .caption1)
        let timeFont = UIFont.monospacedDigitSystemFont(
            ofSize: baseTimeFont.pointSize,
            weight: .regular
        )
        let timeText = message.createdAt.chatTimeText
        let rawTimeWidth = ceil((timeText as NSString).size(withAttributes: [.font: timeFont]).width)
        let timeWidth = rawTimeWidth + 4
        let available = screenWidth
            - horizontalScreenEdgePadding
            - oppositeInsetProtection
            - avatarWidth
            - avatarSpacing
            - timeSpacing
            - timeWidth
        return max(220, min(available, 276))
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

    @ViewBuilder
    private func interactiveBubble<Content: View>(
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 0.35, perform: onLongPress)
            .accessibilityAddTraits(.isButton)
    }

    private func navigateFromChatCard(
        kind: ChatCardNavigationKind,
        id: String,
        perform: () -> Void
    ) {
        let now = Date()
        if let recentCardNavigation,
           recentCardNavigation.id == id,
           recentCardNavigation.kind != kind,
           now.timeIntervalSince(recentCardNavigation.timestamp) < 1.0 {
#if DEBUG
            print("[RatingEventResolve] suppress conflicting chat navigation kind=\(kind.rawValue) id=\(id) recent=\(recentCardNavigation.kind.rawValue)")
#endif
            return
        }

        recentCardNavigation = RecentCardNavigation(
            kind: kind,
            id: id,
            timestamp: now
        )
        perform()
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

    private func postCardPayload(from message: Message) -> ChatPostCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "post",
              let postID = (message.customData["postID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !postID.isEmpty,
              let authorID = (message.customData["postAuthorID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !authorID.isEmpty,
              let authorDisplayName = (message.customData["postAuthorDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !authorDisplayName.isEmpty else {
            return nil
        }

        return ChatPostCardPayload(
            postID: postID,
            authorID: authorID,
            authorDisplayName: authorDisplayName,
            authorUsername: (message.customData["postAuthorUsername"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            contentText: (message.customData["postContentText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            coverImageURL: (message.customData["postCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            hasVideo: (message.customData["postHasVideo"] as? Bool) ?? false,
            likeCount: (message.customData["postLikeCount"] as? Int) ?? 0,
            commentCount: (message.customData["postCommentCount"] as? Int) ?? 0,
            shareCount: (message.customData["postShareCount"] as? Int) ?? 0,
            badgeText: (message.customData["postBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func ratingEventCardPayload(from message: Message) -> ChatRatingEventCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "rating_event",
              let eventID = (message.customData["ratingEventID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !eventID.isEmpty,
              let eventName = (message.customData["ratingEventName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !eventName.isEmpty else {
            return nil
        }

        return ChatRatingEventCardPayload(
            eventID: eventID,
            eventName: eventName,
            description: (message.customData["ratingEventDescription"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["ratingEventCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["ratingEventBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func ratingUnitCardPayload(from message: Message) -> ChatRatingUnitCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "rating_unit",
              let unitID = (message.customData["ratingUnitID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !unitID.isEmpty,
              let unitName = (message.customData["ratingUnitName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !unitName.isEmpty else {
            return nil
        }

        return ChatRatingUnitCardPayload(
            unitID: unitID,
            unitName: unitName,
            eventID: (message.customData["ratingUnitEventID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            eventName: (message.customData["ratingUnitEventName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            description: (message.customData["ratingUnitDescription"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["ratingUnitCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: message.customData["ratingUnitRating"] as? Double,
            ratingCount: message.customData["ratingUnitRatingCount"] as? Int,
            badgeText: (message.customData["ratingUnitBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func brandCardPayload(from message: Message) -> ChatBrandCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "brand",
              let brandID = (message.customData["brandID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !brandID.isEmpty,
              let brandName = (message.customData["brandName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !brandName.isEmpty else {
            return nil
        }

        return ChatBrandCardPayload(
            brandID: brandID,
            brandName: brandName,
            country: (message.customData["brandCountry"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            city: (message.customData["brandCity"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            tagline: (message.customData["brandTagline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["brandCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["brandBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func setCardPayload(from message: Message) -> ChatSetCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "set",
              let setID = (message.customData["setID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !setID.isEmpty,
              let setTitle = (message.customData["setTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !setTitle.isEmpty else {
            return nil
        }

        return ChatSetCardPayload(
            setID: setID,
            setTitle: setTitle,
            djID: (message.customData["setDJID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            djName: (message.customData["setDJName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            eventName: (message.customData["setEventName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            venue: (message.customData["setVenue"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["setCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["setBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func labelCardPayload(from message: Message) -> ChatLabelCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "label",
              let labelID = (message.customData["labelID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !labelID.isEmpty,
              let labelName = (message.customData["labelName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !labelName.isEmpty else {
            return nil
        }

        return ChatLabelCardPayload(
            labelID: labelID,
            labelName: labelName,
            country: (message.customData["labelCountry"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            genreText: (message.customData["labelGenreText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["labelCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["labelBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func newsCardPayload(from message: Message) -> ChatNewsCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "news",
              let articleID = (message.customData["newsArticleID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !articleID.isEmpty,
              let headline = (message.customData["newsHeadline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !headline.isEmpty else {
            return nil
        }

        return ChatNewsCardPayload(
            articleID: articleID,
            headline: headline,
            summary: (message.customData["newsSummary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            source: (message.customData["newsSource"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryRawValue: (message.customData["newsCategoryRawValue"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["newsCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            authorName: (message.customData["newsAuthorName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["newsBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func rankingBoardCardPayload(from message: Message) -> ChatRankingBoardCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "ranking",
              let boardID = (message.customData["rankingBoardID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !boardID.isEmpty,
              let boardName = (message.customData["rankingBoardName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !boardName.isEmpty,
              let year = message.customData["rankingBoardYear"] as? Int else {
            return nil
        }

        return ChatRankingBoardCardPayload(
            boardID: boardID,
            boardName: boardName,
            boardSubtitle: (message.customData["rankingBoardSubtitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year,
            coverImageURL: (message.customData["rankingBoardCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["rankingBoardBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func circleIDCardPayload(from message: Message) -> ChatCircleIDCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "circle_id",
              let entryID = (message.customData["circleIDEntryID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !entryID.isEmpty,
              let songName = (message.customData["circleIDSongName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !songName.isEmpty,
              let contributorName = (message.customData["circleIDContributorName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !contributorName.isEmpty else {
            return nil
        }

        let rawDJNames = message.customData["circleIDDJNames"] as? [String] ?? []
        let djNames = rawDJNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return ChatCircleIDCardPayload(
            entryID: entryID,
            songName: songName,
            contributorName: contributorName,
            djNames: djNames,
            eventName: (message.customData["circleIDEventName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["circleIDCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            hasVideo: (message.customData["circleIDHasVideo"] as? Bool) ?? false,
            badgeText: (message.customData["circleIDBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func myCheckinsCardPayload(from message: Message) -> ChatMyCheckinsCardPayload? {
        guard let sourceKind = message.customData["sourceKind"] as? String,
              sourceKind == ChatMessageKind.card.rawValue,
              let cardType = message.customData["cardType"] as? String,
              cardType == "my_checkins",
              let userID = (message.customData["myCheckinsUserID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userID.isEmpty,
              let displayName = (message.customData["myCheckinsDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayName.isEmpty,
              let title = (message.customData["myCheckinsTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return nil
        }

        return ChatMyCheckinsCardPayload(
            userID: userID,
            displayName: displayName,
            title: title,
            summary: (message.customData["myCheckinsSummary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageURL: (message.customData["myCheckinsCoverImageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            badgeText: (message.customData["myCheckinsBadgeText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
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

private enum ChatCardNavigationKind: String {
    case event
    case ratingEvent
}

private struct RecentCardNavigation {
    let kind: ChatCardNavigationKind
    let id: String
    let timestamp: Date
}

private struct ChatPostCardPayload {
    let postID: String
    let authorID: String
    let authorDisplayName: String
    let authorUsername: String
    let contentText: String
    let coverImageURL: String?
    let hasVideo: Bool
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let badgeText: String?
}

private struct ChatRatingEventCardPayload {
    let eventID: String
    let eventName: String
    let description: String?
    let coverImageURL: String?
    let badgeText: String?
}

private struct ChatRatingUnitCardPayload {
    let unitID: String
    let unitName: String
    let eventID: String?
    let eventName: String?
    let description: String?
    let coverImageURL: String?
    let rating: Double?
    let ratingCount: Int?
    let badgeText: String?
}

private struct ChatBrandCardPayload {
    let brandID: String
    let brandName: String
    let country: String?
    let city: String?
    let tagline: String?
    let coverImageURL: String?
    let badgeText: String?
}

private struct ChatLabelCardPayload {
    let labelID: String
    let labelName: String
    let country: String?
    let genreText: String?
    let coverImageURL: String?
    let badgeText: String?
}

private struct ChatNewsCardPayload {
    let articleID: String
    let headline: String
    let summary: String?
    let source: String?
    let categoryRawValue: String?
    let coverImageURL: String?
    let authorName: String?
    let badgeText: String?
}

private struct ChatRankingBoardCardPayload {
    let boardID: String
    let boardName: String
    let boardSubtitle: String?
    let year: Int
    let coverImageURL: String?
    let badgeText: String?
}

private struct ChatCircleIDCardPayload {
    let entryID: String
    let songName: String
    let contributorName: String
    let djNames: [String]
    let eventName: String?
    let coverImageURL: String?
    let hasVideo: Bool
    let badgeText: String?
}

private struct ChatMyCheckinsCardPayload {
    let userID: String
    let displayName: String
    let title: String
    let summary: String?
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

private struct ChatPostCardBubbleView: View {
    @Environment(\.colorScheme) private var colorScheme

    let payload: ChatPostCardPayload

    private let cardWidth: CGFloat = 236
    private let cardCornerRadius: CGFloat = 18

    var body: some View {
        Group {
            if let imageURL = payload.coverImageURL?.nilIfBlank {
                ChatPosterCardBubble(
                    imageURL: imageURL,
                    badgeText: payload.badgeText,
                    title: titleText,
                    subtitle: subtitleText,
                    fallbackSystemImage: "text.bubble.fill"
                )
                .overlay(alignment: .topTrailing) {
                    if payload.hasVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.32), radius: 6, x: 0, y: 2)
                            .padding(12)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let badgeText = payload.badgeText?.nilIfBlank {
                        Text(badgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(badgeForegroundColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(badgeBackgroundColor, in: Capsule())
                    }

                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(3)

                    if let subtitleText {
                        Text(subtitleText)
                            .font(.caption)
                            .foregroundStyle(titleColor.opacity(0.72))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(width: cardWidth, alignment: .leading)
                .background(infoBackground)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            }
        }
    }

    private var titleText: String {
        let trimmed = payload.contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return L("来自 \(payload.authorDisplayName) 的动态", "A post from \(payload.authorDisplayName)")
        }
        return String(trimmed.prefix(100))
    }

    private var subtitleText: String? {
        let parts = [
            "@\(payload.authorUsername)".nilIfBlank,
            payload.commentCount > 0 ? "\(payload.commentCount) \(L("评论", "comments"))" : nil
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
            RaverTheme.accent.opacity(0.10)
        ]
    }

    private var darkInfoColors: [Color] {
        [
            Color(red: 0.20, green: 0.20, blue: 0.23),
            Color(red: 0.14, green: 0.14, blue: 0.17),
            RaverTheme.accent.opacity(0.14)
        ]
    }

    private var titleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.84)
    }

    private var badgeForegroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.94) : RaverTheme.accent.opacity(0.95)
    }

    private var badgeBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : RaverTheme.accent.opacity(0.10)
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

private struct ChatRatingEventCardBubbleView: View {
    let payload: ChatRatingEventCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.eventName,
            subtitle: payload.description?.nilIfBlank,
            fallbackSystemImage: "sparkles.rectangle.stack.fill"
        )
    }
}

private struct ChatRatingUnitCardBubbleView: View {
    let payload: ChatRatingUnitCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.unitName,
            subtitle: metadataText,
            fallbackSystemImage: "star.bubble.fill"
        )
    }

    private var metadataText: String? {
        var parts: [String] = []
        if let eventName = payload.eventName?.nilIfBlank {
            parts.append(eventName)
        }
        if let rating = payload.rating, rating > 0 {
            if let count = payload.ratingCount, count > 0 {
                parts.append(String(format: L("%.1f 分 · %d 人评分", "%.1f · %d ratings"), rating, count))
            } else {
                parts.append(String(format: L("%.1f 分", "%.1f"), rating))
            }
        } else if let description = payload.description?.nilIfBlank {
            parts.append(description)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct ChatSetCardBubbleView: View {
    let payload: ChatSetCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.setTitle,
            subtitle: metadataText,
            fallbackSystemImage: "waveform.circle.fill",
            coverAspectRatio: 16 / 9,
            badgePlacement: .coverBottomLeading
        )
    }

    private var metadataText: String? {
        let parts = [
            payload.djName?.nilIfBlank,
            payload.eventName?.nilIfBlank ?? payload.venue?.nilIfBlank
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct ChatBrandCardBubbleView: View {
    let payload: ChatBrandCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.brandName,
            fallbackSystemImage: "sparkles.tv"
        )
    }
}

private struct ChatLabelCardBubbleView: View {
    let payload: ChatLabelCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.labelName,
            subtitle: labelMetadataText,
            fallbackSystemImage: "opticaldiscdrive.fill"
        )
    }

    private var labelMetadataText: String? {
        let parts = [payload.country?.nilIfBlank, payload.genreText?.nilIfBlank].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct ChatRankingBoardCardBubbleView: View {
    let payload: ChatRankingBoardCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.boardName,
            subtitle: rankingMetadataText,
            fallbackSystemImage: "chart.bar.xaxis"
        )
    }

    private var rankingMetadataText: String {
        if let subtitle = payload.boardSubtitle?.nilIfBlank {
            return "\(payload.year) · \(subtitle)"
        }
        return String(payload.year)
    }
}

private struct ChatCircleIDCardBubbleView: View {
    @Environment(\.colorScheme) private var colorScheme

    let payload: ChatCircleIDCardPayload

    private let cardWidth: CGFloat = 236
    private let cardCornerRadius: CGFloat = 18

    var body: some View {
        Group {
            if let imageURL = payload.coverImageURL?.nilIfBlank {
                ChatPosterCardBubble(
                    imageURL: imageURL,
                    badgeText: payload.badgeText,
                    title: payload.songName,
                    subtitle: subtitleText,
                    fallbackSystemImage: "music.note"
                )
                .overlay(alignment: .topTrailing) {
                    if payload.hasVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.32), radius: 6, x: 0, y: 2)
                            .padding(12)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let badgeText = payload.badgeText?.nilIfBlank {
                        Text(badgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(badgeForegroundColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(badgeBackgroundColor, in: Capsule())
                    }

                    Text(payload.songName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(3)

                    if let subtitleText {
                        Text(subtitleText)
                            .font(.caption)
                            .foregroundStyle(titleColor.opacity(0.72))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(width: cardWidth, alignment: .leading)
                .background(infoBackground)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            }
        }
    }

    private var subtitleText: String? {
        let joinedDJs = payload.djNames.joined(separator: " · ").nilIfBlank
        let parts = [
            joinedDJs,
            payload.eventName?.nilIfBlank,
            payload.contributorName.nilIfBlank
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
            Color(red: 0.93, green: 0.95, blue: 0.98),
            Color(red: 0.88, green: 0.91, blue: 0.96),
            RaverTheme.accent.opacity(0.10)
        ]
    }

    private var darkInfoColors: [Color] {
        [
            Color(red: 0.18, green: 0.21, blue: 0.25),
            Color(red: 0.13, green: 0.15, blue: 0.19),
            RaverTheme.accent.opacity(0.14)
        ]
    }

    private var titleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.84)
    }

    private var badgeForegroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.94) : RaverTheme.accent.opacity(0.95)
    }

    private var badgeBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : RaverTheme.accent.opacity(0.10)
    }
}

private struct ChatNewsCardBubbleView: View {
    @Environment(\.colorScheme) private var colorScheme

    let payload: ChatNewsCardPayload
    let maxWidth: CGFloat?

    private let cardHeight: CGFloat = 82
    private let imageWidth: CGFloat = 94

    private var cardWidth: CGFloat {
        min(maxWidth ?? 276, 276)
    }

    var body: some View {
        HStack(spacing: 0) {
            coverView
                .frame(width: imageWidth, height: cardHeight)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                if let badgeText = payload.badgeText?.nilIfBlank {
                    newsBadgeView(badgeText)
                }

                Text(payload.headline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: cardWidth - imageWidth, height: cardHeight, alignment: .leading)
            .background(infoBackground)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var coverView: some View {
        if let raw = payload.coverImageURL,
           let url = URL(string: raw),
           !raw.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackCoverView
                }
            }
        } else {
            fallbackCoverView
        }
    }

    private var fallbackCoverView: some View {
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.16, blue: 0.22), Color(red: 0.18, green: 0.28, blue: 0.40)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "newspaper.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }

    private func newsBadgeView(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(accentColor.opacity(colorScheme == .dark ? 0.16 : 0.12), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }

    private var titleColor: Color {
        colorScheme == .dark ? Color.white : Color.black.opacity(0.9)
    }

    private var accentColor: Color {
        Color(red: 0.34, green: 0.74, blue: 0.96)
    }

    private var infoBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                colorScheme == .dark
                    ? Color(red: 0.10, green: 0.11, blue: 0.14)
                    : Color.white,
                colorScheme == .dark
                    ? Color(red: 0.15, green: 0.17, blue: 0.21)
                    : Color(red: 0.96, green: 0.97, blue: 0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }
}

private struct ChatSetCardPayload {
    let setID: String
    let setTitle: String
    let djID: String?
    let djName: String?
    let eventName: String?
    let venue: String?
    let coverImageURL: String?
    let badgeText: String?
}

private struct ChatMyCheckinsCardBubbleView: View {
    let payload: ChatMyCheckinsCardPayload

    var body: some View {
        ChatPosterCardBubble(
            imageURL: payload.coverImageURL,
            badgeText: payload.badgeText,
            title: payload.title,
            subtitle: payload.summary,
            fallbackSystemImage: "figure.walk.motion"
        )
    }
}

private struct ChatPosterCardBubble: View {
    enum BadgePlacement {
        case infoSection
        case coverBottomLeading
    }

    @Environment(\.colorScheme) private var colorScheme

    let imageURL: String?
    let badgeText: String?
    let title: String
    let subtitle: String?
    let fallbackSystemImage: String
    let coverAspectRatio: CGFloat
    let badgePlacement: BadgePlacement

    private let cardWidth: CGFloat = 224
    private let cardCornerRadius: CGFloat = 18

    init(
        imageURL: String?,
        badgeText: String?,
        title: String,
        subtitle: String? = nil,
        fallbackSystemImage: String,
        coverAspectRatio: CGFloat = 1,
        badgePlacement: BadgePlacement = .infoSection
    ) {
        self.imageURL = imageURL
        self.badgeText = badgeText
        self.title = title
        self.subtitle = subtitle
        self.fallbackSystemImage = fallbackSystemImage
        self.coverAspectRatio = max(coverAspectRatio, 0.01)
        self.badgePlacement = badgePlacement
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverView
                .frame(width: cardWidth, height: cardWidth / coverAspectRatio)
                .overlay(alignment: .bottomLeading) {
                    if badgePlacement == .coverBottomLeading,
                       let badgeText, !badgeText.isEmpty {
                        badgeView(badgeText)
                            .padding(.leading, 12)
                            .padding(.bottom, 12)
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                if badgePlacement == .infoSection,
                   let badgeText, !badgeText.isEmpty {
                    badgeView(badgeText)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(titleColor.opacity(0.72))
                        .lineLimit(1)
                }
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

    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(badgeForegroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeBackgroundColor, in: Capsule())
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
        if let payload = parseRatingEventCardPayloadForPreview(from: rawText) {
            return "\(L("[打分事件卡片]", "[Rating Event Card]")) \(payload.eventName)"
        }
        if let payload = parseRatingUnitCardPayloadForPreview(from: rawText) {
            return "\(L("[打分单位卡片]", "[Rating Unit Card]")) \(payload.unitName)"
        }
        if let payload = parseEventCardPayloadForPreview(from: rawText) {
            return "\(L("[活动卡片]", "[Event Card]")) \(payload.eventName)"
        }
        if let payload = parseDJCardPayloadForPreview(from: rawText) {
            return "\(L("[DJ卡片]", "[DJ Card]")) \(payload.djName)"
        }
        if let payload = parseSetCardPayloadForPreview(from: rawText) {
            return "\(L("[Set卡片]", "[Set Card]")) \(payload.setTitle)"
        }
        if let payload = parseBrandCardPayloadForPreview(from: rawText) {
            return "\(L("[音乐节卡片]", "[Festival Card]")) \(payload.brandName)"
        }
        if let payload = parseLabelCardPayloadForPreview(from: rawText) {
            return "\(L("[厂牌卡片]", "[Label Card]")) \(payload.labelName)"
        }
        if let payload = parseNewsCardPayloadForPreview(from: rawText) {
            return "\(L("[资讯卡片]", "[News Card]")) \(payload.headline)"
        }
        if let payload = parseRankingBoardCardPayloadForPreview(from: rawText) {
            return "\(L("[榜单卡片]", "[Ranking Card]")) \(payload.boardName) · \(payload.year)"
        }
        if let payload = parseCircleIDCardPayloadForPreview(from: rawText) {
            return "\(L("[ID卡片]", "[ID Card]")) \(payload.songName)"
        }
        if let payload = parseMyCheckinsCardPayloadForPreview(from: rawText) {
            return "\(L("[打卡卡片]", "[Check-ins Card]")) \(payload.title)"
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

    private func parseRatingEventCardPayloadForPreview(from rawText: String) -> RatingEventShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: RatingEventShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "rating_event",
           let payload = envelope.payload {
            return payload
        }

        return nil
    }

    private func parseRatingUnitCardPayloadForPreview(from rawText: String) -> RatingUnitShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: RatingUnitShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "rating_unit",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(RatingUnitShareCardPayload.self, from: data)
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

    private func parseSetCardPayloadForPreview(from rawText: String) -> SetShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: SetShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "set",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(SetShareCardPayload.self, from: data)
    }

    private func parseBrandCardPayloadForPreview(from rawText: String) -> BrandShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: BrandShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "brand",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(BrandShareCardPayload.self, from: data)
    }

    private func parseLabelCardPayloadForPreview(from rawText: String) -> LabelShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: LabelShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "label",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(LabelShareCardPayload.self, from: data)
    }

    private func parseNewsCardPayloadForPreview(from rawText: String) -> NewsShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: NewsShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "news",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(NewsShareCardPayload.self, from: data)
    }

    private func parseRankingBoardCardPayloadForPreview(from rawText: String) -> RankingBoardShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: RankingBoardShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "ranking",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(RankingBoardShareCardPayload.self, from: data)
    }

    private func parseCircleIDCardPayloadForPreview(from rawText: String) -> CircleIDShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: CircleIDShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "circle_id",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(CircleIDShareCardPayload.self, from: data)
    }

    private func parseMyCheckinsCardPayloadForPreview(from rawText: String) -> MyCheckinsShareCardPayload? {
        guard let data = rawText.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let cardType: String?
            let payload: MyCheckinsShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "my_checkins",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(MyCheckinsShareCardPayload.self, from: data)
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
           let payload = parseRatingEventCardPayload(from: source.content) {
            data["cardType"] = "rating_event"
            data["ratingEventID"] = payload.eventID
            data["ratingEventName"] = payload.eventName
            data["ratingEventDescription"] = payload.description ?? ""
            data["ratingEventCoverImageURL"] = payload.coverImageURL ?? ""
            data["ratingEventBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
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
                  let payload = parsePostCardPayload(from: source.content) {
            data["cardType"] = "post"
            data["postID"] = payload.postID
            data["postAuthorID"] = payload.authorID
            data["postAuthorDisplayName"] = payload.authorDisplayName
            data["postAuthorUsername"] = payload.authorUsername
            data["postContentText"] = payload.contentText
            data["postCoverImageURL"] = payload.coverImageURL ?? ""
            data["postHasVideo"] = payload.hasVideo
            data["postLikeCount"] = payload.likeCount
            data["postCommentCount"] = payload.commentCount
            data["postShareCount"] = payload.shareCount
            data["postBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
                  let payload = parseRatingUnitCardPayload(from: source.content) {
            data["cardType"] = "rating_unit"
            data["ratingUnitID"] = payload.unitID
            data["ratingUnitName"] = payload.unitName
            data["ratingUnitEventID"] = payload.eventID ?? ""
            data["ratingUnitEventName"] = payload.eventName ?? ""
            data["ratingUnitDescription"] = payload.description ?? ""
            data["ratingUnitCoverImageURL"] = payload.coverImageURL ?? ""
            data["ratingUnitRating"] = payload.rating ?? 0
            data["ratingUnitRatingCount"] = payload.ratingCount ?? 0
            data["ratingUnitBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
                  let payload = parseSetCardPayload(from: source.content) {
            data["cardType"] = "set"
            data["setID"] = payload.setID
            data["setTitle"] = payload.setTitle
            data["setDJID"] = payload.djID ?? ""
            data["setDJName"] = payload.djName ?? ""
            data["setEventName"] = payload.eventName ?? ""
            data["setVenue"] = payload.venue ?? ""
            data["setCoverImageURL"] = payload.coverImageURL ?? ""
            data["setBadgeText"] = payload.badgeText ?? ""
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
        } else if source.kind == .card,
                  let payload = parseBrandCardPayload(from: source.content) {
            data["cardType"] = "brand"
            data["brandID"] = payload.brandID
            data["brandName"] = payload.brandName
            data["brandCountry"] = payload.country ?? ""
            data["brandCity"] = payload.city ?? ""
            data["brandTagline"] = payload.tagline ?? ""
            data["brandCoverImageURL"] = payload.coverImageURL ?? ""
            data["brandBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
                  let payload = parseLabelCardPayload(from: source.content) {
            data["cardType"] = "label"
            data["labelID"] = payload.labelID
            data["labelName"] = payload.labelName
            data["labelCountry"] = payload.country ?? ""
            data["labelGenreText"] = payload.genreText ?? ""
            data["labelCoverImageURL"] = payload.coverImageURL ?? ""
            data["labelBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
                  let payload = parseNewsCardPayload(from: source.content) {
            data["cardType"] = "news"
            data["newsArticleID"] = payload.articleID
            data["newsHeadline"] = payload.headline
            data["newsSummary"] = payload.summary ?? ""
            data["newsSource"] = payload.source ?? ""
            data["newsCategoryRawValue"] = payload.categoryRawValue ?? ""
            data["newsCoverImageURL"] = payload.coverImageURL ?? ""
            data["newsAuthorName"] = payload.authorName ?? ""
            data["newsBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
                  let payload = parseRankingBoardCardPayload(from: source.content) {
            data["cardType"] = "ranking"
            data["rankingBoardID"] = payload.boardID
            data["rankingBoardName"] = payload.boardName
            data["rankingBoardSubtitle"] = payload.boardSubtitle ?? ""
            data["rankingBoardYear"] = payload.year
            data["rankingBoardCoverImageURL"] = payload.coverImageURL ?? ""
            data["rankingBoardBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
                  let payload = parseCircleIDCardPayload(from: source.content) {
            data["cardType"] = "circle_id"
            data["circleIDEntryID"] = payload.entryID
            data["circleIDSongName"] = payload.songName
            data["circleIDContributorName"] = payload.contributorName
            data["circleIDDJNames"] = payload.djNames
            data["circleIDEventName"] = payload.eventName ?? ""
            data["circleIDCoverImageURL"] = payload.coverImageURL ?? ""
            data["circleIDHasVideo"] = payload.hasVideo
            data["circleIDBadgeText"] = payload.badgeText ?? ""
            data["canCopy"] = false
        } else if source.kind == .card,
                  let payload = parseMyCheckinsCardPayload(from: source.content) {
            data["cardType"] = "my_checkins"
            data["myCheckinsUserID"] = payload.userID
            data["myCheckinsDisplayName"] = payload.displayName
            data["myCheckinsTitle"] = payload.title
            data["myCheckinsSummary"] = payload.summary ?? ""
            data["myCheckinsCoverImageURL"] = payload.coverImageURL ?? ""
            data["myCheckinsBadgeText"] = payload.badgeText ?? ""
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

    private func parsePostCardPayload(from rawContent: String) -> PostShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: PostShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "post",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(PostShareCardPayload.self, from: data)
    }

    private func parseRatingEventCardPayload(from rawContent: String) -> RatingEventShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: RatingEventShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "rating_event",
           let payload = envelope.payload {
            return payload
        }

        return nil
    }

    private func parseRatingUnitCardPayload(from rawContent: String) -> RatingUnitShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: RatingUnitShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "rating_unit",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(RatingUnitShareCardPayload.self, from: data)
    }

    private func parseMyCheckinsCardPayload(from rawContent: String) -> MyCheckinsShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: MyCheckinsShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "my_checkins",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(MyCheckinsShareCardPayload.self, from: data)
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

        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           jsonObject["setID"] != nil || jsonObject["setTitle"] != nil {
            return nil
        }

        return try? JSONDecoder().decode(DJShareCardPayload.self, from: data)
    }

    private func parseSetCardPayload(from rawContent: String) -> SetShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: SetShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "set",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(SetShareCardPayload.self, from: data)
    }

    private func parseBrandCardPayload(from rawContent: String) -> BrandShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: BrandShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "brand",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(BrandShareCardPayload.self, from: data)
    }

    private func parseLabelCardPayload(from rawContent: String) -> LabelShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: LabelShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "label",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(LabelShareCardPayload.self, from: data)
    }

    private func parseNewsCardPayload(from rawContent: String) -> NewsShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: NewsShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "news",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(NewsShareCardPayload.self, from: data)
    }

    private func parseRankingBoardCardPayload(from rawContent: String) -> RankingBoardShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: RankingBoardShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "ranking",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(RankingBoardShareCardPayload.self, from: data)
    }

    private func parseCircleIDCardPayload(from rawContent: String) -> CircleIDShareCardPayload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        struct Envelope: Decodable {
            let businessID: String?
            let version: Int?
            let cardType: String?
            let payload: CircleIDShareCardPayload?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.cardType == "circle_id",
           let payload = envelope.payload {
            return payload
        }

        return try? JSONDecoder().decode(CircleIDShareCardPayload.self, from: data)
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
