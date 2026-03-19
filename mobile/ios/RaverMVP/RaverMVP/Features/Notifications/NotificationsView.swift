import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel: NotificationsViewModel
    @State private var selectedUser: UserSummary?
    @State private var selectedSquad: PostSquad?

    init() {
        _viewModel = StateObject(wrappedValue: NotificationsViewModel(service: AppEnvironment.makeService()))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView("加载通知中...")
                } else if viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        "暂无通知",
                        systemImage: "bell.slash",
                        description: Text("收到新的关注、点赞、评论或小队邀请后会显示在这里")
                    )
                } else {
                    List(viewModel.notifications) { item in
                        Button {
                            handleTap(item)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                notificationLeadingAvatar(for: item)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.text)
                                        .font(.subheadline)
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .multilineTextAlignment(.leading)

                                    HStack(spacing: 8) {
                                        Text(item.type.title)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                        Text(item.createdAt.feedTimeText)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
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
            .navigationTitle("通知")
            .toolbar {
                if viewModel.unreadCount > 0 {
                    Text("未读 \(viewModel.unreadCount)")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .navigationDestination(item: $selectedUser) { user in
                UserProfileView(userID: user.id)
            }
            .navigationDestination(item: $selectedSquad) { squad in
                SquadProfileView(squadID: squad.id)
            }
            .alert("通知加载失败", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("重试") {
                    Task { await viewModel.load() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(viewModel.error ?? "")
            }
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
            selectedSquad = PostSquad(
                id: target.id,
                name: target.title ?? "小队",
                avatarURL: nil
            )
        default:
            break
        }
    }

    @ViewBuilder
    private func notificationLeadingAvatar(for item: AppNotification) -> some View {
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
            Image(systemName: item.type.iconName)
                .font(.subheadline.bold())
                .foregroundStyle(iconColor(for: item.type))
                .frame(width: 30, height: 30)
                .background(RaverTheme.cardBorder)
                .clipShape(Circle())
        }
    }

    private func iconColor(for type: AppNotificationType) -> Color {
        switch type {
        case .follow:
            return .blue
        case .like:
            return .pink
        case .comment:
            return .orange
        case .squadInvite:
            return .green
        }
    }
}
