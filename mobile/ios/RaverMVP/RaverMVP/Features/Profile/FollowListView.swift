import SwiftUI

enum FollowListKind: String, Identifiable {
    case followers
    case following
    case friends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followers: return L("粉丝", "Followers")
        case .following: return L("关注", "Following")
        case .friends: return L("好友", "Friends")
        }
    }
}

struct FollowListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: FollowListViewModel

    init(userID: String, kind: FollowListKind, repository: ProfileSocialRepository) {
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
                        InlineLoadingBadge(title: L("正在更新列表", "Updating list"))
                    }
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: L("重试", "Retry")
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
                    L("暂无\(viewModel.kind.title)", "No \(viewModel.kind.title) Yet"),
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
                                    Text("@\(user.username)")
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
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
                                        Text(user.isFollowing ? L("已关注", "Following") : L("关注", "Follow"))
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
                            ProgressView(L("加载更多...", "Loading more..."))
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
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
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
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: user.avatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: 48, height: 48)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }
}
