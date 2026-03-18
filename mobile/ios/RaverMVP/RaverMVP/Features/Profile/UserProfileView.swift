import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: UserProfileViewModel
    @State private var pushedConversation: Conversation?
    @State private var selectedFollowListKind: FollowListKind?

    init(userID: String) {
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(userID: userID, service: AppEnvironment.makeService()))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.isLoading, viewModel.profile == nil {
                    ProgressView("加载主页中...")
                        .padding(.top, 80)
                } else if let profile = viewModel.profile {
                    ProfileHeaderCard(
                        profile: profile,
                        onFollowersTap: {
                            if profile.canViewFollowersList {
                                selectedFollowListKind = .followers
                            } else {
                                viewModel.error = "该用户已关闭粉丝列表展示"
                            }
                        },
                        onFollowingTap: {
                            if profile.canViewFollowingList {
                                selectedFollowListKind = .following
                            } else {
                                viewModel.error = "该用户已关闭关注列表展示"
                            }
                        },
                        onFriendsTap: {
                            selectedFollowListKind = .friends
                        }
                    ) {
                        if !isCurrentUser(profile) {
                            HStack(spacing: 10) {
                                Button((profile.isFollowing ?? false) ? "已关注" : "关注") {
                                    Task { await viewModel.toggleFollow() }
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    Task {
                                        do {
                                            let conversation = try await appState.service.startDirectConversation(identifier: profile.username)
                                            pushedConversation = conversation
                                        } catch {
                                            viewModel.error = error.localizedDescription
                                        }
                                    }
                                } label: {
                                    Label("私信", systemImage: "paperplane")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    if viewModel.posts.isEmpty {
                        ContentUnavailableView(
                            "Ta 还没有发布动态",
                            systemImage: "text.badge.plus",
                            description: Text("先去打个招呼吧")
                        )
                    } else {
                        ForEach(viewModel.posts) { post in
                            NavigationLink {
                                PostDetailView(post: post, service: appState.service)
                            } label: {
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
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                            }
                        }

                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView("加载更多...")
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } else {
                    ContentUnavailableView("用户不存在", systemImage: "person.slash")
                        .padding(.top, 80)
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .navigationTitle("用户主页")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pushedConversation) { conversation in
            ChatView(conversation: conversation, service: appState.service)
        }
        .navigationDestination(item: $selectedFollowListKind) { kind in
            FollowListView(userID: viewModel.profile?.id ?? "", kind: kind)
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
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

    private func isCurrentUser(_ profile: UserProfile) -> Bool {
        profile.id == appState.session?.user.id
    }

}
