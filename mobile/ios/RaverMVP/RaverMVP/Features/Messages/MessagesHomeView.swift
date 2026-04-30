import SwiftUI
import PhotosUI
import UIKit

enum MessageAlertCategory: String, CaseIterable, Identifiable, Hashable {
    case like
    case comment
    case follow
    case squadInvite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .like: return L("点赞消息", "Like Notifications")
        case .comment: return L("评论消息", "Comment Notifications")
        case .follow: return L("关注消息", "Follow Notifications")
        case .squadInvite: return L("小队邀请", "Squad Invites")
        }
    }

    var iconName: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "text.bubble.fill"
        case .follow: return "person.badge.plus"
        case .squadInvite: return "person.3.fill"
        }
    }

    var type: AppNotificationType {
        switch self {
        case .like: return .like
        case .comment: return .comment
        case .follow: return .follow
        case .squadInvite: return .squadInvite
        }
    }
}

struct CreateSquadView: View {
    private enum SquadPrivacy: String, CaseIterable, Identifiable {
        case `public`
        case `private`

        var id: String { rawValue }
        var title: String {
            switch self {
            case .public: return L("公开小队", "Public Squad")
            case .private: return L("私密小队", "Private Squad")
            }
        }

        var subtitle: String {
            switch self {
            case .public: return L("所有人可发现并申请加入", "Anyone can discover and request to join")
            case .private: return L("仅邀请成员可加入", "Invite-only members can join")
            }
        }

        var isPublic: Bool { self == .public }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    let service: SocialService
    let onCreated: (Conversation) -> Void

    @State private var squadName = ""
    @State private var squadDescription = ""
    @State private var squadPrivacy: SquadPrivacy?
    @State private var squadFlagURL = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedFlagPhotoItem: PhotosPickerItem?
    @State private var customAvatarData: Data?
    @State private var friends: [UserSummary] = []
    @State private var selectedFriendIDs: [String] = []
    @State private var isLoadingFriends = false
    @State private var isSubmitting = false
    @State private var isUploadingFlag = false
    @State private var error: String?
    private var webService: WebFeatureService { appContainer.webService }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                avatarPicker

                VStack(alignment: .leading, spacing: 8) {
                    Text(LL("小队名称（可选）"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField(LL("不填则使用默认名称"), text: $squadName)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LL("小队简介（可选）"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextEditor(text: $squadDescription)
                        .frame(minHeight: 88)
                        .padding(8)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LL("小队性质（必选）"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    HStack(spacing: 10) {
                        ForEach(SquadPrivacy.allCases) { item in
                            Button {
                                squadPrivacy = item
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(squadPrivacy == item ? RaverTheme.accent.opacity(0.16) : RaverTheme.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            squadPrivacy == item ? RaverTheme.accent : RaverTheme.cardBorder,
                                            lineWidth: squadPrivacy == item ? 1.2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LL("小队旗帜图（可选，用于小队卡片背景）"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    TextField(LL("输入旗帜图 URL 或选择本地图片上传"), text: $squadFlagURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $selectedFlagPhotoItem, matching: .images) {
                            if isUploadingFlag {
                                Label(L("上传中...", "Uploading..."), systemImage: "arrow.trianglehead.2.clockwise")
                            } else {
                                Label(LL("选择旗帜图"), systemImage: "flag.pattern.checkered")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUploadingFlag)

                        if !squadFlagURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(L("清空", "Clear")) {
                                squadFlagURL = ""
                                selectedFlagPhotoItem = nil
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }

                    if let flagURL = AppConfig.resolvedURLString(squadFlagURL),
                       (flagURL.hasPrefix("http://") || flagURL.hasPrefix("https://")),
                       URL(string: flagURL) != nil {
                        ImageLoaderView(urlString: flagURL)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(RaverTheme.card)
                                    .overlay(
                                        Image(systemName: "flag.pattern.checkered")
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    )
                            )
                        .frame(maxWidth: .infinity)
                        .frame(height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(LL("选择好友"))
                                .font(.headline)
                            Spacer()
                            Text(L("已选 \(selectedFriendIDs.count)/2", "Selected \(selectedFriendIDs.count)/2"))
                                .font(.caption)
                                .foregroundStyle(selectedFriendIDs.count >= 2 ? RaverTheme.secondaryText : .orange)
                        }

                        Text(L("创建小队至少需要 3 人，请至少选择 2 位好友。", "Squads need at least 3 people. Select at least 2 friends."))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)

                        if isLoadingFriends {
                            ProgressView(L("加载好友中...", "Loading friends..."))
                        } else if friends.isEmpty {
                            ContentUnavailableView(
                                L("暂无好友", "No Friends Yet"),
                                systemImage: "person.2.slash",
                                description: Text(LL("双方互相关注后会出现在这里"))
                            )
                        } else {
                            ForEach(friends) { friend in
                                Button {
                                    toggleFriend(friend.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        avatar(for: friend)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(friend.displayName)
                                                .font(.subheadline.bold())
                                            Text("@\(friend.username)")
                                                .font(.caption)
                                                .foregroundStyle(RaverTheme.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: selectedFriendIDs.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedFriendIDs.contains(friend.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    Task { await createSquad() }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(LL("创建"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSubmitting || squadPrivacy == nil || selectedFriendIDs.count < 2)
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .raverSystemNavigation(title: L("创建小队", "Create Squad"))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Dismiss")) {
                    dismissKeyboard()
                }
            }
        }
        .task {
            await loadFriends()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    customAvatarData = data
                }
            }
        }
        .onChange(of: selectedFlagPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                await uploadFlagImage(data: data)
            }
        }
        .alert(L("操作失败", "Operation Failed"), isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    @ViewBuilder
    private var avatarPicker: some View {
        HStack(spacing: 12) {
            Group {
                if let data = customAvatarData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(RaverTheme.card)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(RaverTheme.secondaryText)
                        )
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(customAvatarData == nil ? L("选择小队头像（可选）", "Choose squad avatar (optional)") : L("更换小队头像", "Replace squad avatar"), systemImage: "photo")
            }
            .buttonStyle(.bordered)

            if customAvatarData != nil {
                Button(L("移除", "Remove")) {
                    customAvatarData = nil
                    selectedPhotoItem = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    private func toggleFriend(_ id: String) {
        if let index = selectedFriendIDs.firstIndex(of: id) {
            selectedFriendIDs.remove(at: index)
        } else {
            selectedFriendIDs.append(id)
        }
    }

    @ViewBuilder
    private func avatar(for user: UserSummary) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(avatarFallback(for: user))
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            avatarFallback(for: user)
        }
    }

    private func avatarFallback(for user: UserSummary) -> some View {
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
    private func loadFriends() async {
        guard let myID = appState.session?.user.id else { return }
        isLoadingFriends = true
        defer { isLoadingFriends = false }

        do {
            let page = try await service.fetchFriends(userID: myID, cursor: nil)
            friends = page.users
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    @MainActor
    private func createSquad() async {
        guard let squadPrivacy else {
            error = L("请选择小队性质（公开或私密）", "Please choose a squad type (public or private).")
            return
        }
        guard selectedFriendIDs.count >= 2 else {
            error = L("创建小队至少需要 3 人，请至少选择 2 位好友。", "Squads need at least 3 people. Select at least 2 friends.")
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let normalizedName = squadName.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedDescription = squadDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedFlagURL = squadFlagURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let conversation = try await service.createSquad(
                input: CreateSquadInput(
                    name: normalizedName.isEmpty ? nil : normalizedName,
                    description: normalizedDescription.isEmpty ? nil : normalizedDescription,
                    isPublic: squadPrivacy.isPublic,
                    bannerURL: normalizedFlagURL.isEmpty ? nil : normalizedFlagURL,
                    memberIds: selectedFriendIDs
                )
            )

            if let customAvatarData {
                _ = try await service.uploadSquadAvatar(
                    squadID: conversation.id,
                    imageData: customAvatarData,
                    fileName: "squad-\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
            } else if let generated = await generateDefaultAvatarData() {
                _ = try await service.uploadSquadAvatar(
                    squadID: conversation.id,
                    imageData: generated,
                    fileName: "squad-\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
            }

            onCreated(conversation)
            dismiss()
        } catch {
            self.error = error.userFacingMessage
        }
    }

    @MainActor
    private func uploadFlagImage(data: Data) async {
        isUploadingFlag = true
        defer { isUploadingFlag = false }
        do {
            let uploaded = try await webService.uploadEventImage(
                imageData: data,
                fileName: "squad-flag-\(Int(Date().timeIntervalSince1970)).jpg",
                mimeType: "image/jpeg"
            )
            squadFlagURL = uploaded.url
        } catch {
            self.error = error.userFacingMessage
        }
    }

    @MainActor
    private func generateDefaultAvatarData() async -> Data? {
        guard let me = appState.session?.user else { return nil }
        let selectedMembers = selectedFriendIDs.compactMap { id in
            friends.first(where: { $0.id == id })
        }
        let participants = Array(([me] + selectedMembers).prefix(4))
        if participants.isEmpty { return nil }

        let rendered = await renderSquadAvatar(for: participants)
        return rendered.jpegData(compressionQuality: 0.85)
    }

    @MainActor
    private func renderSquadAvatar(for users: [UserSummary]) async -> UIImage {
        let canvas = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: canvas)
        let tileRects = [
            CGRect(x: 0, y: 0, width: 256, height: 256),
            CGRect(x: 256, y: 0, width: 256, height: 256),
            CGRect(x: 0, y: 256, width: 256, height: 256),
            CGRect(x: 256, y: 256, width: 256, height: 256),
        ]

        var imageByUserID: [String: UIImage] = [:]
        for user in users {
            guard imageByUserID[user.id] == nil else { continue }
            let asset = AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: user.avatarURL
            )
            if let image = UIImage(named: asset) {
                imageByUserID[user.id] = image
            }
        }

        return renderer.image { context in
            UIColor(RaverTheme.card).setFill()
            context.fill(CGRect(origin: .zero, size: canvas))

            for (index, rect) in tileRects.enumerated() {
                guard index < users.count else { continue }
                let user = users[index]
                if let image = imageByUserID[user.id] {
                    context.cgContext.saveGState()
                    context.cgContext.clip(to: rect)
                    drawFill(image: image, in: rect)
                    context.cgContext.restoreGState()
                } else {
                    UIColor(RaverTheme.accent.opacity(0.25)).setFill()
                    context.fill(rect)
                    let text = String(user.displayName.prefix(1))
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 64, weight: .bold),
                        .foregroundColor: UIColor.label,
                    ]
                    let size = text.size(withAttributes: attrs)
                    let origin = CGPoint(
                        x: rect.midX - size.width / 2,
                        y: rect.midY - size.height / 2
                    )
                    text.draw(at: origin, withAttributes: attrs)
                }
            }
        }
    }

    private func drawFill(image: UIImage, in rect: CGRect) {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            image.draw(in: rect)
            return
        }

        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: drawRect)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

struct MessagesHomeView: View {
    @Environment(\.appPush) private var appPush
    @Environment(\.messagesPush) private var messagesPush
    @ObservedObject var chatViewModel: MessagesViewModel
    @ObservedObject var alertViewModel: MessageNotificationsViewModel
    let onUnreadStateChanged: () -> Void

    init(
        chatViewModel: MessagesViewModel,
        alertViewModel: MessageNotificationsViewModel,
        onUnreadStateChanged: @escaping () -> Void
    ) {
        self.chatViewModel = chatViewModel
        self.alertViewModel = alertViewModel
        self.onUnreadStateChanged = onUnreadStateChanged
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                HStack(spacing: 16) {
                    alertsRow
                }
                Spacer(minLength: 12)
                HStack(spacing: 12) {
                    editConversationsButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if chatViewModel.isLoading && chatViewModel.conversations.isEmpty {
                Spacer()
                ProgressView(L("加载消息中...", "Loading messages..."))
                Spacer()
            } else if chatViewModel.conversations.isEmpty {
                Spacer()
                ContentUnavailableView(
                    L("暂无会话", "No Conversations Yet"),
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text(LL("从用户主页发起私信或加入小队后会显示在这里"))
                )
                Spacer()
            } else {
                List(chatViewModel.conversations) { conversation in
                    Button {
                        if chatViewModel.isEditingConversations {
                            chatViewModel.toggleConversationSelection(conversation.id)
                        } else {
                            appPush(.conversation(target: .fromConversation(conversation)))
                            Task {
                                await chatViewModel.markConversationRead(conversationID: conversation.id)
                                onUnreadStateChanged()
                            }
                        }
                    } label: {
                        conversationRow(conversation)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !chatViewModel.isEditingConversations {
                            Button(conversation.isPinned ? L("取消置顶", "Unpin") : L("置顶", "Pin")) {
                                Task {
                                    await chatViewModel.setConversationPinned(
                                        conversationID: conversation.id,
                                        pinned: !conversation.isPinned
                                    )
                                }
                            }
                            .tint(RaverTheme.accent)

                            Button(conversation.unreadCount > 0 ? L("已读", "Read") : L("未读", "Unread")) {
                                Task {
                                    if conversation.unreadCount > 0 {
                                        await chatViewModel.markConversationRead(conversationID: conversation.id)
                                    } else {
                                        await chatViewModel.markConversationUnread(
                                            conversationID: conversation.id,
                                            unread: true
                                        )
                                    }
                                    onUnreadStateChanged()
                                }
                            }
                            .tint(.blue)

                            Button(L("隐藏", "Hide"), role: .destructive) {
                                Task {
                                    await chatViewModel.hideConversation(conversationID: conversation.id)
                                    onUnreadStateChanged()
                                }
                            }
                        }
                    }
                    .contextMenu {
                        Button(conversation.isPinned ? L("取消置顶", "Unpin") : L("置顶", "Pin")) {
                            Task {
                                await chatViewModel.setConversationPinned(
                                    conversationID: conversation.id,
                                    pinned: !conversation.isPinned
                                )
                            }
                        }

                        Button(conversation.unreadCount > 0 ? L("标记已读", "Mark Read") : L("标记未读", "Mark Unread")) {
                            Task {
                                if conversation.unreadCount > 0 {
                                    await chatViewModel.markConversationRead(conversationID: conversation.id)
                                } else {
                                    await chatViewModel.markConversationUnread(
                                        conversationID: conversation.id,
                                        unread: true
                                    )
                                }
                                onUnreadStateChanged()
                            }
                        }

                        Button(L("隐藏会话", "Hide Conversation"), role: .destructive) {
                            Task {
                                await chatViewModel.hideConversation(conversationID: conversation.id)
                                onUnreadStateChanged()
                            }
                        }
                    }
                    .listRowBackground(
                        chatViewModel.isConversationSelected(conversation.id)
                            ? RaverTheme.accent.opacity(0.10)
                            : RaverTheme.card
                    )
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(RaverTheme.background)
        .safeAreaInset(edge: .bottom) {
            if chatViewModel.isEditingConversations {
                conversationBatchBar
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshAll()
        }
        .refreshable {
            await refreshAll()
        }
        .onChange(of: chatViewModel.unreadTotal) { _, _ in
            onUnreadStateChanged()
        }
        .onChange(of: alertViewModel.unreadCounts.total) { _, _ in
            onUnreadStateChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: .raverMessageAlertsDidMutate)) { _ in
            Task {
                await alertViewModel.load()
                onUnreadStateChanged()
            }
        }
        .alert(L("消息加载失败", "Failed to Load Messages"), isPresented: Binding(
            get: { chatViewModel.error != nil || alertViewModel.error != nil },
            set: { newValue in
                if !newValue {
                    chatViewModel.error = nil
                    alertViewModel.error = nil
                }
            }
        )) {
            Button(L("重试", "Retry")) {
                Task { await refreshAll() }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(chatViewModel.error ?? alertViewModel.error ?? "")
        }
    }

    private var alertsRow: some View {
        ForEach(MessageAlertCategory.allCases) { category in
            Button {
                messagesPush(.alertCategory(category))
            } label: {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(RaverTheme.card)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: category.iconName)
                                .foregroundStyle(RaverTheme.primaryText)
                        )

                    let count = alertViewModel.unreadCount(for: category.type)
                    if count > 0 {
                        Text(unreadBadgeText(for: count))
                            .font(.caption2.bold())
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(category.title)
        }
    }

    private var editConversationsButton: some View {
        Button {
            if chatViewModel.isEditingConversations {
                chatViewModel.exitConversationEditing()
            } else {
                chatViewModel.toggleConversationEditing()
            }
        } label: {
            Circle()
                .fill(chatViewModel.isEditingConversations ? RaverTheme.accent : RaverTheme.card)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: chatViewModel.isEditingConversations ? "checkmark" : "square.and.pencil")
                        .font(.system(size: chatViewModel.isEditingConversations ? 18 : 17, weight: .semibold))
                        .foregroundStyle(chatViewModel.isEditingConversations ? Color.white : RaverTheme.secondaryText)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chatViewModel.isEditingConversations ? L("完成编辑", "Finish Editing") : L("编辑会话", "Edit Conversations"))
    }

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: 10) {
            if chatViewModel.isEditingConversations {
                Image(systemName: chatViewModel.isConversationSelected(conversation.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(chatViewModel.isConversationSelected(conversation.id) ? RaverTheme.accent : RaverTheme.secondaryText)
            }

            // 头像
            conversationAvatar(conversation)
                .frame(width: 40, height: 40)
                .background(RaverTheme.card)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Text(conversation.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)

                        if conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.accent)
                        }

                        if conversation.type == .group {
                            Text(LL("小队"))
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RaverTheme.accent.opacity(0.24))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    Text(conversation.updatedAt.chatTimeText)
                        .font(.system(size: 12))
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                HStack(spacing: 8) {
                    Text(conversation.previewText)
                        .font(.system(size: 13))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)

                    if conversation.unreadCount > 0 {
                        Text(unreadBadgeText(for: conversation.unreadCount))
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .foregroundStyle(Color.white)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var conversationBatchBar: some View {
        VStack(spacing: 10) {
            Divider()
            HStack(spacing: 12) {
                Button {
                    if chatViewModel.selectedConversationIDs.count == chatViewModel.conversations.count {
                        chatViewModel.clearConversationSelection()
                    } else {
                        chatViewModel.selectAllConversations()
                    }
                } label: {
                    Text(
                        chatViewModel.selectedConversationIDs.count == chatViewModel.conversations.count
                            ? L("取消全选", "Clear All")
                            : L("全选", "Select All")
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 12)

                Text(
                    L("已选 \(chatViewModel.selectedConversationIDs.count) 项", "Selected \(chatViewModel.selectedConversationIDs.count)")
                )
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)

                Spacer(minLength: 12)

                Button {
                    Task {
                        await chatViewModel.markSelectedConversationsRead()
                        onUnreadStateChanged()
                    }
                } label: {
                    Text(L("标为已读", "Mark Read"))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(chatViewModel.selectedConversationIDs.isEmpty)

                Button(role: .destructive) {
                    Task {
                        await chatViewModel.hideSelectedConversations()
                        onUnreadStateChanged()
                    }
                } label: {
                    Text(L("隐藏", "Hide"))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(chatViewModel.selectedConversationIDs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func unreadBadgeText(for count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }

    @ViewBuilder
    private func conversationAvatar(_ conversation: Conversation) -> some View {
        if conversation.type == .group,
           let resolved = AppConfig.resolvedURLString(conversation.avatarURL),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(fallbackConversationAvatar(conversation))
        } else if conversation.type == .direct,
                  let resolved = AppConfig.resolvedURLString(conversation.peer?.avatarURL ?? conversation.avatarURL),
                  resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
                  URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(fallbackConversationAvatar(conversation))
        } else {
            fallbackConversationAvatar(conversation)
        }
    }

    private func fallbackConversationAvatar(_ conversation: Conversation) -> some View {
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

    @MainActor
    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await chatViewModel.load() }
            group.addTask { await alertViewModel.load() }
        }
        onUnreadStateChanged()
    }
}

private struct MessageGlobalSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var chatViewModel: MessagesViewModel
    let onSelectResult: (MessagesViewModel.GlobalSearchSection, ChatMessageSearchResult) -> Void

    @State private var query = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if !chatViewModel.globalSearchSections.isEmpty {
                    ForEach(chatViewModel.globalSearchSections) { section in
                        Section {
                            ForEach(section.results, id: \.message.id) { result in
                                Button {
                                    onSelectResult(section, result)
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
                        } header: {
                            HStack(spacing: 8) {
                                conversationHeaderAvatar(section.conversation)
                                    .frame(width: 22, height: 22)
                                    .clipShape(Circle())
                                Text(section.conversation.title)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text("\(section.results.count)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !chatViewModel.isGlobalSearching,
                          chatViewModel.globalSearchError == nil {
                    ContentUnavailableView(
                        L("无搜索结果", "No Results"),
                        systemImage: "magnifyingglass",
                        description: Text(L("请尝试更换关键词。", "Try a different keyword."))
                    )
                }
            }
            .listStyle(.insetGrouped)
            .overlay(alignment: .center) {
                if chatViewModel.isGlobalSearching {
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
                prompt: L("搜索消息内容或文件名", "Search message text or file name")
            )
            .onSubmit(of: .search) {
                triggerSearch(immediate: true)
            }
            .onChange(of: query) { _, _ in
                triggerSearch(immediate: false)
            }
            .navigationTitle(L("全局聊天搜索", "Global Chat Search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("关闭", "Close")) {
                        dismiss()
                    }
                }
            }
        }
        .alert(
            L("搜索失败", "Search Failed"),
            isPresented: Binding(
                get: { chatViewModel.globalSearchError != nil },
                set: { isPresented in
                    if !isPresented {
                        chatViewModel.globalSearchError = nil
                    }
                }
            )
        ) {
            Button(L("好的", "OK"), role: .cancel) {}
        } message: {
            Text(chatViewModel.globalSearchError ?? "")
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
            chatViewModel.clearGlobalSearchState()
        }
    }

    private func triggerSearch(immediate: Bool) {
        debounceTask?.cancel()
        let delay: UInt64 = immediate ? 0 : 250_000_000
        let pendingQuery = query
        let normalizedQuery = pendingQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedQuery.isEmpty {
            IMProbeLogger.log(
                "[GlobalSearch] trigger query=\(normalizedQuery) immediate=\(immediate ? 1 : 0)"
            )
        }
        debounceTask = Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            await chatViewModel.searchGlobally(query: pendingQuery)
        }
    }

    private func previewText(for message: ChatMessage) -> String {
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
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

    @ViewBuilder
    private func conversationHeaderAvatar(_ conversation: Conversation) -> some View {
        if conversation.type == .group,
           let resolved = AppConfig.resolvedURLString(conversation.avatarURL),
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
        } else if conversation.type == .direct,
                  let resolved = AppConfig.resolvedURLString(conversation.peer?.avatarURL ?? conversation.avatarURL),
                  (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")),
                  URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
        } else {
            fallbackConversationAvatar(conversation)
        }
    }

    private func fallbackConversationAvatar(_ conversation: Conversation) -> some View {
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
            .background(RaverTheme.card)
    }
}

struct MessageAlertDetailView: View {
    @Environment(\.appPush) private var appPush
    @Environment(\.messagesPush) private var messagesPush
    @Environment(\.messagesPresent) private var messagesPresent
    let category: MessageAlertCategory
    @ObservedObject var viewModel: MessageNotificationsViewModel
    let onReadChange: () -> Void

    var body: some View {
        Group {
            let items = viewModel.items(for: category.type)
            if items.isEmpty {
                ContentUnavailableView(
                    L("暂无\(category.title)", "No \(category.title) Yet"),
                    systemImage: category.iconName
                )
            } else {
                List(items) { item in
                    Button {
                        Task {
                            await viewModel.markRead(item)
                            onReadChange()
                            handleTap(item)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            alertLeadingAvatar(for: item)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.text)
                                    .font(.subheadline)
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .multilineTextAlignment(.leading)
                                Text(item.createdAt.feedTimeText)
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(RaverTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: category.title)
    }

    @ViewBuilder
    private func alertLeadingAvatar(for item: AppNotification) -> some View {
        if let actor = item.actor {
            if let resolved = AppConfig.resolvedURLString(actor.avatarURL),
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
               URL(string: resolved) != nil {
                ImageLoaderView(urlString: resolved)
                    .background(alertLeadingAvatarFallback(actor))
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            } else {
                alertLeadingAvatarFallback(actor)
            }
        } else {
            Image(systemName: category.iconName)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(item.isRead ? RaverTheme.cardBorder : Color.red)
                .clipShape(Circle())
        }
    }

    private func handleTap(_ item: AppNotification) {
        guard let target = item.target else { return }
        switch target.type {
        case "user":
            if let actor = item.actor {
                appPush(.userProfile(userID: actor.id))
            }
        case "squad":
            messagesPresent(.squadProfile(target.id))
        default:
            break
            }
        }
    }

    private func alertLeadingAvatarFallback(_ actor: UserSummary) -> some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: actor.id,
                username: actor.username,
                avatarURL: actor.avatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: 30, height: 30)
        .background(RaverTheme.cardBorder)
        .clipShape(Circle())
    }
