import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appContainer: AppContainer
    let userID: String

    var body: some View {
        UserProfileScreen(
            viewModel: UserProfileViewModel(
                userID: userID,
                repository: appContainer.profileSocialRepository
            )
        )
    }
}

private struct UserProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.appPush) private var appPush
    @Environment(\.profilePush) private var profilePush
    @StateObject private var viewModel: UserProfileViewModel
    @State private var isStartingDirectChat = false

    init(viewModel: UserProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .initialLoading:
                ProfileSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(message: message) {
                        Task { await viewModel.load() }
                    }
                    .padding(16)
                    .padding(.top, 40)
                }
            case .empty, .success:
                ScrollView {
                    VStack(spacing: 14) {
                        if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                            VStack(alignment: .leading, spacing: 10) {
                                if viewModel.isRefreshing {
                                    InlineLoadingBadge(title: L("正在更新主页", "Updating profile"))
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
                        }

                        if let profile = viewModel.profile {
                            ProfileHeaderCard(
                                profile: profile,
                                onFollowersTap: {
                                    if profile.canViewFollowersList {
                                        profilePush(.followList(userID: profile.id, kind: .followers))
                                    } else {
                                        viewModel.error = L("该用户已关闭粉丝列表展示", "This user has hidden the followers list.")
                                    }
                                },
                                onFollowingTap: {
                                    if profile.canViewFollowingList {
                                        profilePush(.followList(userID: profile.id, kind: .following))
                                    } else {
                                        viewModel.error = L("该用户已关闭关注列表展示", "This user has hidden the following list.")
                                    }
                                },
                                onFriendsTap: {
                                    profilePush(.followList(userID: profile.id, kind: .friends))
                                }
                            ) {
                                if !isCurrentUser(profile) {
                                    HStack(spacing: 10) {
                                        Button((profile.isFollowing ?? false) ? L("已关注", "Following") : L("关注", "Follow")) {
                                            Task { await viewModel.toggleFollow() }
                                        }
                                        .buttonStyle(.borderedProminent)

                                        Button {
                                            Task {
                                                guard !isStartingDirectChat else { return }
                                                isStartingDirectChat = true
                                                defer { isStartingDirectChat = false }
                                                do {
                                                    let identifier = profile.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                        ? profile.username
                                                        : profile.id
                                                    let conversation = try await appContainer.socialService.startDirectConversation(identifier: identifier)
                                                    IMChatStore.shared.stageConversation(conversation)
                                                    appPush(.conversation(target: .fromConversation(conversation)))
                                                } catch {
                                                    viewModel.error = error.userFacingMessage
                                                }
                                            }
                                        } label: {
                                            if isStartingDirectChat {
                                                ProgressView()
                                            } else {
                                                Label(LL("私信"), systemImage: "paperplane")
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(isStartingDirectChat)
                                    }
                                }
                            }

                            ProfileRecentCheckinsCard(
                                title: L("Ta 的近期打卡", "Recent Check-ins"),
                                checkins: viewModel.recentCheckins,
                                emptyText: L("Ta 还没有公开的打卡记录。", "No public check-ins yet.")
                            ) {
                                profilePush(.myCheckins(
                                    targetUserID: viewModel.profile?.id,
                                    title: L("\(viewModel.profile?.displayName ?? "Ta")的打卡", "\(viewModel.profile?.displayName ?? "Ta")'s Check-ins"),
                                    ownerDisplayName: viewModel.profile?.displayName
                                ))
                            }

                            if viewModel.posts.isEmpty {
                                ContentUnavailableView(
                                    L("Ta 还没有发布动态", "No Posts Yet"),
                                    systemImage: "text.badge.plus",
                                    description: Text(LL("先去打个招呼吧"))
                                )
                            } else {
                                ForEach(viewModel.posts) { post in
                                    PostCardView(
                                        post: post,
                                        currentUserId: appState.session?.user.id,
                                        showsFollowButton: false,
                                        onLikeTap: {
                                            Task { await viewModel.toggleLike(post: post) }
                                        },
                                        onRepostTap: {
                                            Task { await viewModel.toggleRepost(post: post) }
                                        },
                                        onFollowTap: nil,
                                        onMessageTap: nil,
                                        onAuthorTap: nil,
                                        onSquadTap: nil
                                    )
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        appPush(.postDetail(postID: post.id))
                                    }
                                    .onAppear {
                                        Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                                    }
                                }

                                if viewModel.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView(L("加载更多...", "Loading more..."))
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        } else {
                            ContentUnavailableView(LL("用户不存在"), systemImage: "person.slash")
                                .padding(.top, 80)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("用户主页", "Profile"))
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

    private func isCurrentUser(_ profile: UserProfile) -> Bool {
        profile.id == appState.session?.user.id
    }
}
