import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        NotificationsScreen(
            viewModel: NotificationsViewModel(service: appContainer.socialService)
        )
    }
}

private struct NotificationsScreen: View {
    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: NotificationsViewModel

    init(viewModel: NotificationsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                ProgressView(L("加载通知中...", "Loading notifications..."))
            } else if viewModel.notifications.isEmpty {
                ContentUnavailableView(
                    L("暂无通知", "No Notifications"),
                    systemImage: "bell.slash",
                    description: Text(LL("收到新的关注、点赞、评论或小队邀请后会显示在这里"))
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
        .navigationTitle(L("通知", "Notifications"))
        .toolbar {
            if viewModel.unreadCount > 0 {
                Text(L("未读", "Unread") + " \(viewModel.unreadCount)")
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
        .alert(L("通知加载失败", "Failed to Load Notifications"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("重试", "Retry")) {
                Task { await viewModel.load() }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
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
            appPush(.squadProfile(squadID: target.id))
        default:
            break
        }
    }

    @ViewBuilder
    private func notificationLeadingAvatar(for item: AppNotification) -> some View {
        if let actor = item.actor {
            if let resolved = AppConfig.resolvedURLString(actor.avatarURL),
               URL(string: resolved) != nil,
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                ImageLoaderView(urlString: resolved)
                    .background(notificationLeadingAvatarFallback(actor))
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            } else {
                notificationLeadingAvatarFallback(actor)
            }
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

    private func notificationLeadingAvatarFallback(_ actor: UserSummary) -> some View {
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
}
