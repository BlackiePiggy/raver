import SwiftUI
import UIKit

struct SearchView: View {
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        SearchScreen(
            viewModel: SearchViewModel(service: appContainer.socialService)
        )
    }
}

private struct SearchScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField(L("搜索用户或动态", "Search users or posts"), text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit {
                        Task { await performSearch() }
                    }

                Button(L("搜索", "Search")) {
                    Task { await performSearch() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)

            Picker(L("范围", "Scope"), selection: $viewModel.scope) {
                ForEach(SearchViewModel.Scope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .onChange(of: viewModel.scope) { _, _ in
                Task { await performSearch() }
            }
            .onAppear {
                Task { await performSearch() }
            }

            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: L("正在搜索", "Searching"))
                    }
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: L("重试", "Retry")
                        ) {
                            Task { await performSearch() }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            switch viewModel.phase {
            case .idle:
                ContentUnavailableView(
                    L("开始搜索", "Start Searching"),
                    systemImage: "magnifyingglass",
                    description: Text(LL("输入用户名、动态关键词或切换到小队推荐"))
                )
                .frame(maxHeight: .infinity)
            case .initialLoading:
                SearchResultsSkeletonView()
                Spacer(minLength: 0)
            case .failure(let message), .offline(let message):
                VStack {
                    ScreenErrorCard(message: message) {
                        Task { await performSearch() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }
            case .empty:
                content
            case .success:
                content
            }
        }
        .background(RaverTheme.background)
        .navigationTitle(L("发现", "Discover"))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Dismiss")) {
                    dismissKeyboard()
                }
            }
        }
        .alert(L("搜索失败", "Search Failed"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @MainActor
    private func performSearch() async {
        await viewModel.search()
        dismissKeyboard()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.scope == .users {
            if viewModel.users.isEmpty {
                ContentUnavailableView(
                    L("暂无用户结果", "No User Results"),
                    systemImage: "person.2",
                    description: Text(LL("试试输入更完整的用户名"))
                )
            } else {
                List(viewModel.users) { user in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(.headline)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer()
                            Button(user.isFollowing ? L("已关注", "Following") : L("关注", "Follow")) {
                                Task { await viewModel.toggleFollow(user: user) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appPush(.userProfile(userID: user.id))
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(RaverTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
        } else if viewModel.scope == .posts {
            if viewModel.posts.isEmpty {
                ContentUnavailableView(
                    L("暂无动态结果", "No Post Results"),
                    systemImage: "text.magnifyingglass",
                    description: Text(LL("试试不同关键词"))
                )
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
                                onSquadTap: nil
                            )
                            .foregroundStyle(RaverTheme.primaryText)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appPush(.postDetail(postID: post.id))
                            }
                        }
                    }
                    .padding(16)
                }
            }
        } else {
            if viewModel.squads.isEmpty {
                ContentUnavailableView(
                    L("暂无小队推荐", "No Squad Recommendations"),
                    systemImage: "person.3",
                    description: Text(LL("稍后再来看看新的社群"))
                )
            } else {
                List(viewModel.squads) { squad in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(squad.name)
                                    .font(.headline)
                                if let description = squad.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Text(L("\(squad.memberCount) 人", "\(squad.memberCount) members"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Button(squad.isMember ? L("进入小队", "Enter Squad") : L("加入并进入", "Join & Enter")) {
                            appPush(.squadProfile(squadID: squad.id))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(RaverTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
