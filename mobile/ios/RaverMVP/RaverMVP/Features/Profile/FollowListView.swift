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
    @State private var pushedConversation: Conversation?

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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer()
                            if user.isFollowing {
                                Text("已关注")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedUser = user
                        }

                        Button {
                            Task {
                                do {
                                    let conversation = try await appState.service.startDirectConversation(identifier: user.username)
                                    pushedConversation = conversation
                                } catch {
                                    viewModel.error = error.localizedDescription
                                }
                            }
                        } label: {
                            Label("发私信", systemImage: "paperplane")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(RaverTheme.card)
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
        .navigationDestination(item: $pushedConversation) { conversation in
            ChatView(conversation: conversation, service: appState.service)
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
