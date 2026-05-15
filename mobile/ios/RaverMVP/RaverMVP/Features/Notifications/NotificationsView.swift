import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        NotificationsScreen(
            viewModel: NotificationsViewModel(repository: appContainer.notificationRepository),
            appearanceResolver: VirtualAssetListAppearanceResolver(
                repository: appContainer.virtualAssetRepository,
                surface: "notifications"
            )
        )
    }
}

private struct NotificationsScreen: View {
    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: NotificationsViewModel
    @StateObject private var appearanceResolver: VirtualAssetListAppearanceResolver

    init(
        viewModel: NotificationsViewModel,
        appearanceResolver: VirtualAssetListAppearanceResolver
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _appearanceResolver = StateObject(wrappedValue: appearanceResolver)
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新通知", "Updating notifications", "通知を更新中"))
                    }
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
                        ) {
                            Task { await viewModel.load() }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            switch viewModel.phase {
            case .idle, .initialLoading:
                NotificationListSkeletonView()
            case .failure(let message), .offline(let message):
                Spacer()
                ScreenErrorCard(message: message) {
                    Task { await viewModel.load() }
                }
                .padding(.horizontal, 16)
                Spacer()
            case .empty:
                ContentUnavailableView(
                    LT("暂无通知", "No Notifications", "通知はまだありません"),
                    systemImage: "bell.slash",
                    description: Text(LT("收到新的关注、点赞、评论或小队邀请后会显示在这里", "New follows, likes, comments, or squad invites will appear here.", "新しいフォロー、いいね、コメント、Squad招待を受け取るとここに表示されます"))
                )
            case .success:
                List(viewModel.notifications) { item in
                    Button {
                        Task {
                            await handleTap(item)
                        }
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
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .background(RaverTheme.background)
        .navigationTitle(LT("通知", "Notifications", "通知"))
        .toolbar {
            if viewModel.unreadCount > 0 {
                Text(LT("未读", "Unread", "未読") + " \(viewModel.unreadCount)")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.notifications) { _, notifications in
            appearanceResolver.warmAppearances(for: notifications.compactMap { $0.actor?.id })
        }
        .alert(LT("通知加载失败", "Failed to Load Notifications", "通知の読み込みに失敗しました"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(LT("重试", "Retry", "再試行")) {
                Task { await viewModel.load() }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    private func handleTap(_ item: AppNotification) async {
        await viewModel.markRead(item)
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
            let appearance = appearanceResolver.appearance(userID: actor.id)
            if let resolved = AppConfig.resolvedURLString(actor.avatarURL),
               URL(string: resolved) != nil,
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                VirtualAssetAvatarView(size: 30, avatarFrame: appearance?.avatarFrame) {
                    ImageLoaderView(urlString: resolved)
                        .background(notificationLeadingAvatarFallback(actor))
                        .frame(width: 30, height: 30)
                }
            } else {
                VirtualAssetAvatarView(size: 30, avatarFrame: appearance?.avatarFrame) {
                    notificationLeadingAvatarFallback(actor)
                }
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
        AvatarPlaceholderView(size: 30)
    }
}

#if DEBUG
#Preview("Notifications Repository Seam") {
    NavigationStack {
        NotificationsScreen(
            viewModel: NotificationsViewModel(repository: MockNotificationRepository()),
            appearanceResolver: VirtualAssetListAppearanceResolver(
                repository: MockVirtualAssetRepository(),
                surface: "notifications-preview"
            )
        )
    }
}
#endif
