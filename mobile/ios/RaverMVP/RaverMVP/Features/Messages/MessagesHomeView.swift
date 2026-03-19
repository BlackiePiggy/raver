import SwiftUI
import PhotosUI
import UIKit

private enum MessageAlertCategory: String, CaseIterable, Identifiable {
    case like
    case comment
    case follow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .like: return "点赞消息"
        case .comment: return "评论消息"
        case .follow: return "关注消息"
        }
    }

    var iconName: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "text.bubble.fill"
        case .follow: return "person.badge.plus"
        }
    }

    var type: AppNotificationType {
        switch self {
        case .like: return .like
        case .comment: return .comment
        case .follow: return .follow
        }
    }
}

private struct CreateSquadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let service: SocialService
    let onCreated: (Conversation) -> Void

    @State private var squadName = ""
    @State private var squadDescription = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customAvatarData: Data?
    @State private var friends: [UserSummary] = []
    @State private var selectedFriendIDs: [String] = []
    @State private var isLoadingFriends = false
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                avatarPicker

                VStack(alignment: .leading, spacing: 8) {
                    Text("小队名称（可选）")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField("不填则使用默认名称", text: $squadName)
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("小队简介（可选）")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextEditor(text: $squadDescription)
                        .frame(minHeight: 88)
                        .padding(8)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("选择好友")
                                .font(.headline)
                            Spacer()
                            Text("已选 \(selectedFriendIDs.count)")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        if isLoadingFriends {
                            ProgressView("加载好友中...")
                        } else if friends.isEmpty {
                            ContentUnavailableView(
                                "暂无好友",
                                systemImage: "person.2.slash",
                                description: Text("双方互相关注后会出现在这里")
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
                        Text("创建")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSubmitting)
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .navigationTitle("创建小队")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
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
        .alert("操作失败", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("确定", role: .cancel) {}
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
                Label(customAvatarData == nil ? "选择小队头像（可选）" : "更换小队头像", systemImage: "photo")
            }
            .buttonStyle(.bordered)

            if customAvatarData != nil {
                Button("移除") {
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

    private func avatar(for user: UserSummary) -> some View {
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
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func createSquad() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let normalizedName = squadName.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedDescription = squadDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let conversation = try await service.createSquad(
                input: CreateSquadInput(
                    name: normalizedName.isEmpty ? nil : normalizedName,
                    description: normalizedDescription.isEmpty ? nil : normalizedDescription,
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
            self.error = error.localizedDescription
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
}

struct MessagesHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var chatViewModel: MessagesViewModel
    @StateObject private var alertViewModel: MessageNotificationsViewModel
    @State private var showCreateSquad = false
    @State private var pushedConversation: Conversation?
    @State private var selectedCategory: MessageAlertCategory?

    init() {
        let service = AppEnvironment.makeService()
        _chatViewModel = StateObject(wrappedValue: MessagesViewModel(service: service))
        _alertViewModel = StateObject(wrappedValue: MessageNotificationsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack {
                    HStack {
                        Spacer()
                        createSquadButton
                    }

                    HStack(spacing: 16) {
                        alertsRow
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if chatViewModel.isLoading && chatViewModel.conversations.isEmpty {
                    Spacer()
                    ProgressView("加载消息中...")
                    Spacer()
                } else if chatViewModel.conversations.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "暂无会话",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("从用户主页发起私信或加入小队后会显示在这里")
                    )
                    Spacer()
                } else {
                    List(chatViewModel.conversations) { conversation in
                        Button {
                            pushedConversation = conversation
                            Task {
                                await chatViewModel.markConversationRead(conversationID: conversation.id)
                                syncTabBadge()
                            }
                        } label: {
                            conversationRow(conversation)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(RaverTheme.card)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshAll()
            }
            .refreshable {
                await refreshAll()
            }
            .onChange(of: chatViewModel.unreadTotal) { _, _ in
                syncTabBadge()
            }
            .onChange(of: alertViewModel.unreadCounts.total) { _, _ in
                syncTabBadge()
            }
            .navigationDestination(item: $pushedConversation) { conversation in
                ChatView(conversation: conversation, service: appState.service)
            }
            .navigationDestination(item: $selectedCategory) { category in
                MessageAlertDetailView(
                    category: category,
                    viewModel: alertViewModel
                ) {
                    syncTabBadge()
                }
            }
            .alert("消息加载失败", isPresented: Binding(
                get: { chatViewModel.error != nil || alertViewModel.error != nil },
                set: { newValue in
                    if !newValue {
                        chatViewModel.error = nil
                        alertViewModel.error = nil
                    }
                }
            )) {
                Button("重试") {
                    Task { await refreshAll() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(chatViewModel.error ?? alertViewModel.error ?? "")
            }
            .sheet(isPresented: $showCreateSquad) {
                NavigationStack {
                    CreateSquadView(service: appState.service) { conversation in
                        showCreateSquad = false
                        Task { await refreshAll() }
                        pushedConversation = conversation
                    }
                    .environmentObject(appState)
                }
            }
        }
    }

    private var createSquadButton: some View {
        Button {
            showCreateSquad = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
                Text("创建")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(RaverTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RaverTheme.card)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var alertsRow: some View {
        ForEach(MessageAlertCategory.allCases) { category in
            Button {
                selectedCategory = category
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
                        Text("\(count)")
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

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
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

        HStack(spacing: 12) {
            // 头像
            Image(avatarAsset)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .background(RaverTheme.card)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Text(conversation.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)

                        if conversation.type == .group {
                            Text("小队")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RaverTheme.accent.opacity(0.24))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    Text(conversation.updatedAt.chatTimeText)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                HStack(spacing: 8) {
                    Text(conversation.previewText)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RaverTheme.accent)
                            .clipShape(Capsule())
                            .foregroundStyle(Color.white)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @MainActor
    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await chatViewModel.load() }
            group.addTask { await alertViewModel.load() }
        }
        syncTabBadge()
    }

    private func syncTabBadge() {
        appState.unreadMessagesCount = chatViewModel.unreadTotal + alertViewModel.unreadCounts.total
    }
}

private struct MessageAlertDetailView: View {
    @EnvironmentObject private var appState: AppState
    let category: MessageAlertCategory
    @ObservedObject var viewModel: MessageNotificationsViewModel
    let onReadChange: () -> Void

    @State private var selectedUser: UserSummary?
    @State private var selectedSquad: PostSquad?

    var body: some View {
        Group {
            let items = viewModel.items(for: category.type)
            if items.isEmpty {
                ContentUnavailableView(
                    "暂无\(category.title)",
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
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedUser) { user in
            UserProfileView(userID: user.id)
        }
        .navigationDestination(item: $selectedSquad) { squad in
            SquadProfileView(squadID: squad.id)
        }
    }

    @ViewBuilder
    private func alertLeadingAvatar(for item: AppNotification) -> some View {
        if let actor = item.actor {
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
                selectedUser = actor
            }
        case "squad":
            selectedSquad = PostSquad(id: target.id, name: target.title ?? "小队", avatarURL: nil)
        default:
            break
        }
    }
}
