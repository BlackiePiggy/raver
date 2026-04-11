import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        FeedScreen(
            viewModel: FeedViewModel(
                repository: appContainer.circleFeedRepository
            )
        )
    }
}

private struct FeedScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @Environment(\.circlePush) private var circlePush
    @StateObject private var viewModel: FeedViewModel
    @State private var editTapPostID: String?

    init(viewModel: FeedViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView(L("加载中...", "Loading..."))
                    .padding(.top, 12)
            } else if viewModel.posts.isEmpty {
                ContentUnavailableView(
                    L("还没有动态", "No Posts Yet"),
                    systemImage: "square.and.pencil",
                    description: Text(LL("成为第一个发帖的人，开始你的社群互动。"))
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
                                    appPush(.userProfile(userID: post.author.id))
                                },
                                onSquadTap: nil,
                                onEditTap: post.author.id == appState.session?.user.id
                                    ? {
                                        editTapPostID = post.id
                                        circlePush(.postEdit(postID: post.id))
                                    }
                                    : nil
                            )
                            .foregroundStyle(RaverTheme.primaryText)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if editTapPostID == post.id {
                                    editTapPostID = nil
                                    return
                                }
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
        .overlay(alignment: .bottomTrailing) {
            Button {
                circlePush(.postCreate)
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
            .accessibilityLabel(L("发布动态", "Publish Post"))
            .padding(.trailing, 8)
            .padding(.bottom, 42)
        }
        .onReceive(NotificationCenter.default.publisher(for: .circlePostDidCreate)) { notification in
            guard let created = notification.object as? Post else { return }
            viewModel.mergeNewPost(created)
        }
        .onReceive(NotificationCenter.default.publisher(for: .circlePostDidUpdate)) { notification in
            guard let updated = notification.object as? Post else { return }
            viewModel.mergeUpdatedPost(updated)
        }
        .onReceive(NotificationCenter.default.publisher(for: .circlePostDidDelete)) { notification in
            guard let deletedPostID = notification.object as? String else { return }
            viewModel.removePost(deletedPostID)
        }
        .task {
            await viewModel.load()
        }
        .alert(L("加载失败", "Load Failed"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("重试", "Retry")) {
                Task { await viewModel.load() }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}
