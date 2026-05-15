import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appContainer: AppContainer
    let userID: String

    var body: some View {
        UserProfileScreen(
            viewModel: UserProfileViewModel(
                userID: userID,
                userRepository: appContainer.profileUserRepository,
                contentRepository: appContainer.profileContentRepository,
                checkinRepository: appContainer.profileCheckinRepository,
                virtualAssetRepository: appContainer.virtualAssetRepository
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
    @State private var isUpdatingBlockStatus = false
    @State private var blockStatus: UserBlockStatus?
    @State private var reportTarget: ReportSheetTarget?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

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
                                    InlineLoadingBadge(title: LT("正在更新主页", "Updating profile", "プロフィールを更新中"))
                                }
                                if let bannerMessage = viewModel.bannerMessage {
                                    ScreenStatusBanner(
                                        message: bannerMessage,
                                        style: .error,
                                        actionTitle: LT("重试", "Retry", "再試行")
                                    ) {
                                        Task { await viewModel.load() }
                                    }
                                }
                            }
                        }

                        if let profile = viewModel.profile {
                            ProfileHeaderCard(
                                profile: profile,
                                appearance: viewModel.appearance,
                                onFollowersTap: {
                                    if profile.canViewFollowersList {
                                        profilePush(.followList(userID: profile.id, kind: .followers))
                                    } else {
                                        viewModel.error = LT("该用户已关闭粉丝列表展示", "This user has hidden the followers list.", "このユーザーはフォロワー一覧を非公開にしています。")
                                    }
                                },
                                onFollowingTap: {
                                    if profile.canViewFollowingList {
                                        profilePush(.followList(userID: profile.id, kind: .following))
                                    } else {
                                        viewModel.error = LT("该用户已关闭关注列表展示", "This user has hidden the following list.", "このユーザーはフォロー一覧を非公開にしています。")
                                    }
                                },
                                onFriendsTap: {
                                    profilePush(.followList(userID: profile.id, kind: .friends))
                                }
                            ) {
                                if !isCurrentUser(profile) {
                                    HStack(spacing: 10) {
                                        Button((profile.isFollowing ?? false) ? LT("已关注", "Following", "フォロー中") : LT("关注", "Follow", "フォロー")) {
                                            Task { await viewModel.toggleFollow() }
                                        }
                                        .buttonStyle(.borderedProminent)

                                        if profile.isFriend == true {
                                            Button {
                                                Task {
                                                    guard !isStartingDirectChat else { return }
                                                    isStartingDirectChat = true
                                                    defer { isStartingDirectChat = false }
                                                    do {
                                                        let identifier = profile.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                            ? profile.username
                                                            : profile.id
                                                        let conversation = try await appContainer.conversationRepository.startDirectConversation(identifier: identifier)
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
                                                    Label(LT("私信", "Message", "DM"), systemImage: "paperplane")
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .disabled(isStartingDirectChat)
                                        } else {
                                            Button {
                                                viewModel.error = LT("需要双方互相关注成为好友后才能聊天", "You can chat after you both follow each other.", "お互いにフォローして友達になるとチャットできます。")
                                            } label: {
                                                Label(LT("好友后私信", "Message after becoming friends", "友達になったらDMできます"), systemImage: "person.2")
                                            }
                                            .buttonStyle(.bordered)
                                            .disabled(true)
                                        }

                                        Button {
                                            Task { await toggleBlockStatus(for: profile) }
                                        } label: {
                                            if isUpdatingBlockStatus {
                                                ProgressView()
                                            } else {
                                                Label(
                                                    blockStatus?.isBlocked == true ? LT("解除拉黑", "Unblock", "ブロック解除") : LT("拉黑", "Block", "ブロック"),
                                                    systemImage: blockStatus?.isBlocked == true ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark"
                                                )
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(blockStatus?.isBlocked == true ? RaverTheme.accent : .red)
                                        .disabled(isUpdatingBlockStatus)
                                    }
                                }
                            }

                            ProfileRecentCheckinsCard(
                                title: LT("Ta 的近期打卡", "Recent Check-ins", "相手の最近のチェックイン"),
                                checkins: viewModel.recentCheckins,
                                emptyText: LT("Ta 还没有公开的打卡记录。", "No public check-ins yet.", "公開チェックインはまだありません。")
                            ) {
                                profilePush(.myCheckins(
                                    targetUserID: viewModel.profile?.id,
                                    title: LT(
                                        "\(viewModel.profile?.displayName ?? "Ta")的打卡",
                                        "\(viewModel.profile?.displayName ?? "Ta")'s Check-ins",
                                        "\(viewModel.profile?.displayName ?? "相手") のチェックイン"
                                    ),
                                    ownerDisplayName: viewModel.profile?.displayName
                                ))
                            }

                            if viewModel.posts.isEmpty {
                                ContentUnavailableView(
                                    LT("Ta 还没有发布动态", "No Posts Yet", "投稿はまだありません"),
                                    systemImage: "text.badge.plus",
                                    description: Text(LT("先去打个招呼吧", "Say hello first.", "まず挨拶してみましょう"))
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
                                        ProgressView(LT("加载更多...", "Loading more...", "さらに読み込み中..."))
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        } else {
                            ContentUnavailableView(LT("用户不存在", "User not found", "ユーザーが存在しません"), systemImage: "person.slash")
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
        .raverSystemNavigation(title: LT("用户主页", "Profile", "プロフィール"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let profile = viewModel.profile {
                    Button {
                        appPush(
                            .profile(
                                .shareQRCode(
                                    title: profile.displayName,
                                    subtitle: profile.bio.isEmpty ? nil : profile.bio,
                                    imageURL: profile.avatarURL,
                                    shortURL: nil,
                                    qrCodeURL: profile.qrCodeURL
                                )
                            )
                        )
                    } label: {
                        Image(systemName: "qrcode")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.profile != nil {
                    Button {
                        Task { await copyUserProfileShareLink() }
                    } label: {
                        Image(systemName: "link")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let profile = viewModel.profile, !isCurrentUser(profile) {
                    Button {
                        reportTarget = ReportSheetTarget(
                            id: profile.id,
                            type: .user,
                            title: profile.displayName,
                            preview: profile.bio,
                            targetUserID: profile.id,
                            targetUserDisplayName: profile.displayName
                        )
                    } label: {
                        Image(systemName: "flag")
                    }
                }
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, blocked in
                if blocked {
                    blockStatus = UserBlockStatus(isBlocked: true, blockedAt: Date())
                }
                OperationBannerCenter.shared.success(
                    blocked
                        ? LT("举报已提交，并已拉黑该用户", "Report submitted and user blocked", "報告を送信し、このユーザーをブロックしました")
                        : LT("举报已提交", "Report submitted", "報告を送信しました")
                )
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .task {
            await viewModel.load()
            await loadBlockStatusIfNeeded()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @MainActor
    private func copyUserProfileShareLink() async {
        guard let profile = viewModel.profile else { return }

        do {
            let result = try await shareLinkCoordinator.copyLink(
                target: ShareTarget(
                    type: .userCard,
                    id: profile.id,
                    title: profile.displayName,
                    subtitle: profile.bio.isEmpty ? nil : profile.bio,
                    imageURL: profile.avatarURL
                )
            )

            if result.usedDeepLinkFallback {
                viewModel.error = LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
            } else {
                OperationBannerCenter.shared.success(LT("已复制个人主页链接", "Profile link copied", "プロフィールリンクをコピーしました"))
            }
        } catch {
            viewModel.error = error.userFacingMessage ?? LT("复制个人主页链接失败，请稍后重试。", "Failed to copy profile link. Please try again.", "プロフィールリンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    private func isCurrentUser(_ profile: UserProfile) -> Bool {
        profile.id == appState.session?.user.id
    }

    @MainActor
    private func loadBlockStatusIfNeeded() async {
        guard let profile = viewModel.profile, !isCurrentUser(profile) else { return }
        do {
            blockStatus = try await appState.service.fetchUserBlockStatus(userID: profile.id)
        } catch {
            blockStatus = nil
        }
    }

    @MainActor
    private func toggleBlockStatus(for profile: UserProfile) async {
        guard !isUpdatingBlockStatus else { return }
        isUpdatingBlockStatus = true
        defer { isUpdatingBlockStatus = false }

        do {
            if blockStatus?.isBlocked == true {
                blockStatus = try await appState.service.unblockUser(userID: profile.id)
                OperationBannerCenter.shared.success(LT("已解除拉黑", "User unblocked", "ブロックを解除しました"))
            } else {
                blockStatus = try await appState.service.blockUser(
                    userID: profile.id,
                    input: UserBlockInput(
                        reason: "user_profile",
                        note: nil,
                        source: "profile"
                    )
                )
                OperationBannerCenter.shared.success(LT("已拉黑该用户", "User blocked", "このユーザーをブロックしました"))
            }
        } catch {
            viewModel.error = error.userFacingMessage ?? LT("操作失败，请稍后重试。", "Action failed. Please try again.", "操作に失敗しました。時間をおいて再試行してください。")
        }
    }
}
