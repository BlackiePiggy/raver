import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: UserProfileViewModel
    @State private var pushedConversation: Conversation?
    @State private var selectedFollowListKind: FollowListKind?
    @State private var showAllCheckins = false
    @State private var selectedPostForDetail: Post?

    init(userID: String) {
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(userID: userID, service: AppEnvironment.makeService()))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.isLoading, viewModel.profile == nil {
                    ProgressView(L("加载主页中...", "Loading profile..."))
                        .padding(.top, 80)
                } else if let profile = viewModel.profile {
                    ProfileHeaderCard(
                        profile: profile,
                        onFollowersTap: {
                            if profile.canViewFollowersList {
                                selectedFollowListKind = .followers
                            } else {
                                viewModel.error = L("该用户已关闭粉丝列表展示", "This user has hidden the followers list.")
                            }
                        },
                        onFollowingTap: {
                            if profile.canViewFollowingList {
                                selectedFollowListKind = .following
                            } else {
                                viewModel.error = L("该用户已关闭关注列表展示", "This user has hidden the following list.")
                            }
                        },
                        onFriendsTap: {
                            selectedFollowListKind = .friends
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
                                        do {
                                            let conversation = try await appState.service.startDirectConversation(identifier: profile.username)
                                            pushedConversation = conversation
                                        } catch {
                                            viewModel.error = error.userFacingMessage
                                        }
                                    }
                                } label: {
                                    Label(LL("私信"), systemImage: "paperplane")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    ProfileRecentCheckinsCard(
                        title: L("Ta 的近期打卡", "Recent Check-ins"),
                        checkins: viewModel.recentCheckins,
                        emptyText: L("Ta 还没有公开的打卡记录。", "No public check-ins yet.")
                    ) {
                        showAllCheckins = true
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
                                selectedPostForDetail = post
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
        .background(RaverTheme.background)
        .navigationTitle(L("用户主页", "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pushedConversation) { conversation in
            ChatView(conversation: conversation, service: appState.service)
        }
        .navigationDestination(item: $selectedFollowListKind) { kind in
            FollowListView(userID: viewModel.profile?.id ?? "", kind: kind)
        }
        .fullScreenCover(isPresented: $showAllCheckins) {
            NavigationStack {
                MyCheckinsView(
                    targetUserID: viewModel.profile?.id,
                    title: L("\(viewModel.profile?.displayName ?? "Ta")的打卡", "\(viewModel.profile?.displayName ?? "Ta")'s Check-ins")
                )
            }
        }
        .fullScreenCover(item: $selectedPostForDetail) { post in
            NavigationStack {
                PostDetailView(post: post, service: appState.service)
                    .environmentObject(appState)
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
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
