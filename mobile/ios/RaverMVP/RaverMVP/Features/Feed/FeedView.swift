import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: FeedViewModel
    @State private var selectedUserForProfile: UserSummary?
    @State private var selectedPostForDetail: Post?
    @State private var selectedPostForEdit: Post?
    @State private var showCompose = false

    init() {
        _viewModel = StateObject(wrappedValue: FeedViewModel(service: AppEnvironment.makeService()))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView("加载中...")
                        .padding(.top, 12)
                } else if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        "还没有动态",
                        systemImage: "square.and.pencil",
                        description: Text("成为第一个发帖的人，开始你的社群互动。")
                    )
                    .padding(.top, 12)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                                    onAuthorTap: {
                                        selectedUserForProfile = post.author
                                    },
                                    onSquadTap: nil,
                                    onEditTap: post.author.id == appState.session?.user.id
                                        ? { selectedPostForEdit = post }
                                        : nil
                                )
                                .foregroundStyle(RaverTheme.primaryText)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedPostForEdit?.id == post.id {
                                        return
                                    }
                                    selectedPostForDetail = post
                                }
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
                                .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 92)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(RaverTheme.accent)
                                .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 6)
                        )
                }
                .accessibilityLabel("发布动态")
                .padding(.trailing, 8)
                .padding(.bottom, 42)
            }
            .navigationDestination(item: $selectedUserForProfile) { user in
                UserProfileView(userID: user.id)
            }
            .sheet(isPresented: $showCompose) {
                ComposePostView(
                    mode: .create,
                    onPostCreated: { created in
                        viewModel.mergeNewPost(created)
                    }
                )
                .environmentObject(appState)
            }
            .sheet(item: $selectedPostForEdit) { post in
                ComposePostView(
                    mode: .edit(post),
                    onPostUpdated: { updated in
                        viewModel.mergeUpdatedPost(updated)
                    },
                    onPostDeleted: { deletedPostID in
                        viewModel.removePost(deletedPostID)
                        if selectedPostForDetail?.id == deletedPostID {
                            selectedPostForDetail = nil
                        }
                    }
                )
                    .environmentObject(appState)
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
            .alert("加载失败", isPresented: Binding(
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
}
