import SwiftUI

enum FollowListKind: String, Identifiable {
    case followers
    case following
    case friends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followers: return LT("粉丝", "Followers", "フォロワー")
        case .following: return LT("关注", "Following", "フォロー中")
        case .friends: return LT("好友", "Friends", "友達")
        }
    }
}

struct FollowListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: FollowListViewModel

    init(userID: String, kind: FollowListKind, repository: ProfileUserRepository) {
        _viewModel = StateObject(wrappedValue: FollowListViewModel(
            userID: userID,
            kind: kind,
            repository: repository
        ))
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新列表", "Updating list", "一覧を更新中"))
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
                FollowListSkeletonView()
            case .failure(let message), .offline(let message):
                Spacer()
                ScreenErrorCard(message: message) {
                    Task { await viewModel.load() }
                }
                .padding(.horizontal, 16)
                Spacer()
            case .empty:
                ContentUnavailableView(
                    LT("暂无\(viewModel.kind.title)", "No \(viewModel.kind.title) Yet", "\(viewModel.kind.title) はまだありません"),
                    systemImage: "person.2"
                )
            case .success:
                List {
                    ForEach(viewModel.users) { user in
                        Button {
                            appPush(.userProfile(userID: user.id))
                        } label: {
                            HStack(spacing: 12) {
                                userAvatar(user)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()

                                if user.id != appState.session?.user.id {
                                    Button {
                                        Task {
                                            await viewModel.toggleFollow(user: user)
                                        }
                                    } label: {
                                        Text(user.isFollowing ? LT("已关注", "Following", "フォロー中") : LT("关注", "Follow", "フォロー"))
                                            .font(.caption.bold())
                                            .foregroundStyle(user.isFollowing ? RaverTheme.secondaryText : Color.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                            .background(user.isFollowing ? RaverTheme.card : RaverTheme.accent)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(RaverTheme.background)
                        .onAppear {
                            Task { await viewModel.loadMoreIfNeeded(currentUser: user) }
                        }
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView(LT("加载更多...", "Loading more...", "さらに読み込み中..."))
                            Spacer()
                        }
                        .listRowBackground(RaverTheme.background)
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: viewModel.kind.title)
        .task {
            await viewModel.load()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @ViewBuilder
    private func userAvatar(_ user: UserSummary) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           URL(string: resolved) != nil,
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(userAvatarFallback(user))
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            userAvatarFallback(user)
        }
    }

    private func userAvatarFallback(_ user: UserSummary) -> some View {
        AvatarPlaceholderView(size: 48)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }
}
