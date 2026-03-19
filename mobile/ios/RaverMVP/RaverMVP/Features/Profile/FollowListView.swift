import SwiftUI

enum FollowListKind: String, Identifiable {
    case followers
    case following
    case friends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followers: return "粉丝"
        case .following: return "关注"
        case .friends: return "好友"
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
                    ProgressView("加载中...")
                    Spacer()
                }
                .listRowBackground(RaverTheme.background)
            } else if viewModel.users.isEmpty {
                ContentUnavailableView(
                    "暂无\(viewModel.kind.title)",
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
                            if let avatar = AppConfig.resolvedURLString(user.avatarURL), !avatar.isEmpty {
                                AsyncImage(url: URL(string: avatar)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        Circle().fill(RaverTheme.card)
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(RaverTheme.accent.opacity(0.2))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Text(String(user.displayName.prefix(1)))
                                            .font(.headline.bold())
                                    )
                            }

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
                                    Text(user.isFollowing ? "已关注" : "关注")
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
                        ProgressView("加载更多...")
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
        .alert("提示", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}
