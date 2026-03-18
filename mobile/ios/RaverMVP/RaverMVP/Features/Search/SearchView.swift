import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: SearchViewModel
    @State private var selectedUserForProfile: UserSummary?
    @State private var selectedSquadForProfile: PostSquad?

    init() {
        _viewModel = StateObject(wrappedValue: SearchViewModel(service: AppEnvironment.makeService()))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("搜索用户或动态", text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onSubmit {
                            Task { await viewModel.search() }
                        }

                    Button("搜索") {
                        Task { await viewModel.search() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)

                Picker("范围", selection: $viewModel.scope) {
                    ForEach(SearchViewModel.Scope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .onChange(of: viewModel.scope) { _, _ in
                    Task { await viewModel.search() }
                }
                .onAppear {
                    Task { await viewModel.search() }
                }

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("搜索中...")
                    Spacer()
                } else {
                    content
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("发现")
            .navigationDestination(item: $selectedUserForProfile) { user in
                UserProfileView(userID: user.id)
            }
            .navigationDestination(item: $selectedSquadForProfile) { squad in
                SquadProfileView(squadID: squad.id)
            }
            .alert("搜索失败", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.scope == .users {
            if viewModel.users.isEmpty {
                ContentUnavailableView(
                    "暂无用户结果",
                    systemImage: "person.2",
                    description: Text("试试输入更完整的用户名")
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
                            Button(user.isFollowing ? "已关注" : "关注") {
                                Task { await viewModel.toggleFollow(user: user) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedUserForProfile = user
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
                    "暂无动态结果",
                    systemImage: "text.magnifyingglass",
                    description: Text("试试不同关键词")
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
                        }
                    }
                    .padding(16)
                }
            }
        } else {
            if viewModel.squads.isEmpty {
                ContentUnavailableView(
                    "暂无小队推荐",
                    systemImage: "person.3",
                    description: Text("稍后再来看看新的社群")
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
                            Text("\(squad.memberCount) 人")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Button(squad.isMember ? "进入小队" : "加入并进入") {
                            selectedSquadForProfile = PostSquad(
                                id: squad.id,
                                name: squad.name,
                                avatarURL: squad.avatarURL
                            )
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
