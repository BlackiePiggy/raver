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
                        Text("创建小队")
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
        let resolved = AppConfig.resolvedURLString(user.avatarURL)
        return Group {
            if let resolved, !resolved.isEmpty {
                AsyncImage(url: URL(string: resolved)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallbackAvatar(name: user.displayName)
                    }
                }
            } else {
                fallbackAvatar(name: user.displayName)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }

    private func fallbackAvatar(name: String) -> some View {
        Circle()
            .fill(RaverTheme.accent.opacity(0.2))
            .overlay(Text(String(name.prefix(1))).font(.caption.bold()))
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
            guard let resolved = AppConfig.resolvedURLString(user.avatarURL),
                  let url = URL(string: resolved) else { continue }
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
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
    @State private var showDirectComposer = false
    @State private var showCreateSquad = false
    @State private var directIdentifier = ""
    @State private var isStartingDirect = false
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
                alertsRow

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
                        NavigationLink {
                            ChatView(conversation: conversation, service: appState.service)
                        } label: {
                            conversationRow(conversation)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            chatViewModel.markConversationRead(conversationID: conversation.id)
                            syncTabBadge()
                        })
                        .listRowBackground(RaverTheme.card)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("消息")
            .toolbar {
                Menu {
                    Button {
                        showDirectComposer = true
                    } label: {
                        Label("新私信", systemImage: "square.and.pencil")
                    }

                    Button {
                        showCreateSquad = true
                    } label: {
                        Label("创建小队", systemImage: "person.3.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
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
            .sheet(isPresented: $showDirectComposer) {
                NavigationStack {
                    VStack(spacing: 16) {
                        TextField("输入用户名（如 alice）", text: $directIdentifier)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button {
                            Task { await startDirectConversation() }
                        } label: {
                            if isStartingDirect {
                                ProgressView().tint(.white)
                            } else {
                                Text("开始私信")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(directIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStartingDirect)

                        Spacer()
                    }
                    .padding(16)
                    .background(RaverTheme.background)
                    .navigationTitle("新私信")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { showDirectComposer = false }
                        }
                    }
                }
                .presentationDetents([.medium])
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

    private var alertsRow: some View {
        HStack(spacing: 16) {
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)

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
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RaverTheme.accent)
                        .clipShape(Capsule())
                        .foregroundStyle(Color.white)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func startDirectConversation() async {
        let trimmed = directIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }

        isStartingDirect = true
        defer { isStartingDirect = false }

        do {
            let conversation = try await appState.service.startDirectConversation(identifier: trimmed)
            directIdentifier = ""
            showDirectComposer = false
            await refreshAll()
            pushedConversation = conversation
        } catch {
            chatViewModel.error = error.localizedDescription
        }
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
                        viewModel.markRead(item)
                        onReadChange()
                        handleTap(item)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: category.iconName)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(item.isRead ? RaverTheme.cardBorder : Color.red)
                                .clipShape(Circle())

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
