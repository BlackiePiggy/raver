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
    @StateObject private var viewModel: FollowListViewModel
    @State private var selectedUser: UserSummary?

    init(userID: String, kind: FollowListKind) {
        _viewModel = StateObject(wrappedValue: FollowListViewModel(
            userID: userID,
            kind: kind,
            service: AppEnvironment.makeService()
        ))
    }

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.users.isEmpty {
                HStack {
                    Spacer()
                    ProgressView(L("加载中...", "Loading..."))
                    Spacer()
                }
                .listRowBackground(RaverTheme.background)
            } else if viewModel.users.isEmpty {
                ContentUnavailableView(
                    L("暂无\(viewModel.kind.title)", "No \(viewModel.kind.title) Yet"),
                    systemImage: "person.2"
                )
                .listRowBackground(RaverTheme.background)
            } else {
                ForEach(viewModel.users) { user in
                    Button {
                        selectedUser = user
                    } label: {
                        HStack(spacing: 12) {
                            // 头像
                            userAvatar(user)

                            // 昵称和用户名
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

                            // 关注按钮
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
        }
        .scrollContentBackground(.hidden)
        .background(RaverTheme.background)
        .navigationTitle(viewModel.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(item: $selectedUser) { user in
            UserProfileView(userID: user.id)
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
           let remoteURL = URL(string: resolved),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    Circle().fill(RaverTheme.card)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    userAvatarFallback(user)
                @unknown default:
                    userAvatarFallback(user)
                }
            }
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
