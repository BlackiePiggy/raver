import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: FeedViewModel
    @State private var selectedUserForProfile: UserSummary?
    @State private var showCompose = false

    init() {
        _viewModel = StateObject(wrappedValue: FeedViewModel(service: AppEnvironment.makeService()))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView("加载中...")
                } else if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        "还没有动态",
                        systemImage: "square.and.pencil",
                        description: Text("成为第一个发帖的人，开始你的社群互动。")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                                        onAuthorTap: {
                                            selectedUserForProfile = post.author
                                        },
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
                                .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("广场")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("发布动态")
                }
            }
            .navigationDestination(item: $selectedUserForProfile) { user in
                UserProfileView(userID: user.id)
            }
            .sheet(isPresented: $showCompose) {
                ComposePostView()
                    .environmentObject(appState)
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
