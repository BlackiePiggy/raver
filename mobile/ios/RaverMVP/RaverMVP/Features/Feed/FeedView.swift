import SwiftUI
import UIKit

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
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight
    @StateObject private var viewModel: FeedViewModel
    @State private var editTapPostID: String?
    @State private var hideReasonTargetPost: Post?

    init(viewModel: FeedViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(LL("动态排序"), selection: $viewModel.selectedMode) {
                ForEach(FeedMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: L("正在更新动态", "Updating feed"))
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
                .padding(.bottom, 8)
            }

            Group {
                switch viewModel.phase {
                case .idle, .initialLoading:
                    FeedSkeletonView()
                case .failure(let message), .offline(let message):
                    VStack {
                        ScreenErrorCard(message: message) {
                            Task { await viewModel.load() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        Spacer()
                    }
                case .empty:
                    ContentUnavailableView(
                        L("还没有动态", "No Posts Yet"),
                        systemImage: "square.and.pencil",
                        description: Text(LL("成为第一个发帖的人，开始你的社群互动。"))
                    )
                    .padding(.top, 12)
                case .success:
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                                PostCardView(
                                    post: post,
                                    currentUserId: appState.session?.user.id,
                                    showsFollowButton: false,
                                    showsMoreButton: false,
                                    onLikeTap: {
                                        Task { await viewModel.toggleLike(post: post, position: index) }
                                    },
                                    onRepostTap: {
                                        Task { await viewModel.toggleRepost(post: post) }
                                    },
                                    onSaveTap: {
                                        guard appState.session != nil else {
                                            viewModel.error = L("请先登录后再收藏", "Please sign in before saving.")
                                            return
                                        }
                                        Task { await viewModel.toggleSave(post: post, position: index) }
                                    },
                                    onHideTap: {
                                        hideReasonTargetPost = post
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
                                    viewModel.trackOpenPost(post: post, position: index)
                                    appPush(.postDetail(postID: post.id))
                                }
                                .onAppear {
                                    viewModel.trackImpressionIfNeeded(post: post, position: index)
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
                        .padding(.top, 10)
                        .padding(.bottom, 92)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
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
            .padding(.bottom, max(tabBarReservedHeight + 50, 100))
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
        .onReceive(NotificationCenter.default.publisher(for: .circlePostDidHide)) { notification in
            guard let hiddenPostID = notification.object as? String else { return }
            viewModel.removePost(hiddenPostID)
        }
        .onChange(of: viewModel.selectedMode) { _, newMode in
            Task { await viewModel.switchMode(newMode) }
        }
        .task {
            await viewModel.load()
        }
        .confirmationDialog(
            L("告诉我们原因", "Tell us why"),
            isPresented: Binding(
                get: { hideReasonTargetPost != nil },
                set: { if !$0 { hideReasonTargetPost = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(PostHideReasonOption.allCases) { reason in
                Button(reason.title) {
                    guard let post = hideReasonTargetPost else { return }
                    hideReasonTargetPost = nil
                    if appState.session == nil {
                        let position = viewModel.posts.firstIndex(where: { $0.id == post.id })
                        viewModel.hideLocally(postID: post.id, position: position)
                    } else {
                        let position = viewModel.posts.firstIndex(where: { $0.id == post.id })
                        Task { await viewModel.hide(post: post, reason: reason.rawValue, position: position) }
                    }
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {
                hideReasonTargetPost = nil
            }
        } message: {
            Text(L("我们会据此减少类似内容。", "We'll show fewer similar posts."))
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
