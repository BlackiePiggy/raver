import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ProfileViewModel
    @State private var showEditProfile = false
    @State private var showPublishEvent = false
    @State private var showUploadSet = false
    @State private var showSettings = false
    @State private var showAvatarFullscreen = false
    @State private var showMyCheckins = false
    @State private var selectedProfileDestination: ProfileDestination?
    @State private var selectedFollowListKind: FollowListKind?
    @State private var selectedUserForProfile: UserSummary?
    @State private var selectedPostForDetail: Post?

    private enum ProfileDestination: Hashable, Identifiable {
        case myCheckins
        case myPublishes

        var id: String {
            switch self {
            case .myCheckins: return "checkins"
            case .myPublishes: return "publishes"
            }
        }
    }

    init() {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(service: AppEnvironment.makeService()))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView("加载中...")
                } else if let profile = viewModel.profile {
                    ScrollView {
                        VStack(spacing: 14) {
                            ProfileHeaderCard(
                                profile: profile,
                                onAvatarTap: {
                                    showAvatarFullscreen = true
                                },
                                onFollowersTap: {
                                    selectedFollowListKind = .followers
                                },
                                onFollowingTap: {
                                    selectedFollowListKind = .following
                                },
                                onFriendsTap: {
                                    selectedFollowListKind = .friends
                                }
                            )

                            ProfileRecentCheckinsCard(
                                title: "我的近期打卡",
                                checkins: viewModel.recentCheckins,
                                emptyText: "去发现页完成活动或 DJ 打卡，记录会显示在这里。"
                            ) {
                                showMyCheckins = true
                            }

                            profileQuickActions

                            Picker("内容", selection: $viewModel.selectedSection) {
                                ForEach(ProfileViewModel.Section.allCases) { section in
                                    Text(section.title).tag(section)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 2)

                            sectionContent
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await viewModel.refreshSection()
                    }
                } else {
                    ContentUnavailableView("资料加载失败", systemImage: "person.crop.circle.badge.exclam")
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.profile != nil {
                        Button {
                            showEditProfile = true
                        } label: {
                            Label("编辑", systemImage: "square.and.pencil")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.profile != nil {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .navigationDestination(item: $selectedFollowListKind) { kind in
                FollowListView(userID: appState.session?.user.id ?? "", kind: kind)
            }
            .navigationDestination(item: $selectedUserForProfile) { user in
                UserProfileView(userID: user.id)
            }
            .fullScreenCover(item: $selectedPostForDetail) { post in
                NavigationStack {
                    PostDetailView(post: post, service: appState.service)
                        .environmentObject(appState)
                }
            }
            .navigationDestination(item: $selectedProfileDestination) { destination in
                switch destination {
                case .myCheckins:
                    EmptyView()
                case .myPublishes:
                    MyPublishesView()
                }
            }
            .fullScreenCover(isPresented: $showMyCheckins) {
                NavigationStack {
                    MyCheckinsView()
                }
            }
            .navigationDestination(isPresented: $showEditProfile) {
                if let profile = viewModel.profile {
                    EditProfileView(profile: profile) { updated in
                        viewModel.applyUpdatedProfile(updated)
                    }
                }
            }
            .sheet(isPresented: $showPublishEvent) {
                EventEditorView(mode: .create) {
                    Task { await viewModel.load() }
                }
            }
            .sheet(isPresented: $showUploadSet) {
                DJSetEditorView(mode: .create) {}
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showAvatarFullscreen) {
                if let profile = viewModel.profile {
                    AvatarFullscreenView(profile: profile) {
                        showAvatarFullscreen = false
                    }
                }
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

    private var profileQuickActions: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("快捷入口")
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                Button {
                    selectedProfileDestination = .myPublishes
                } label: {
                    quickActionRow(title: "我的发布", icon: "square.stack.3d.up")
                }
                .buttonStyle(.plain)

                Button {
                    showPublishEvent = true
                } label: {
                    quickActionRow(title: "发布活动", icon: "calendar.badge.plus")
                }
                .buttonStyle(.plain)

                Button {
                    showUploadSet = true
                } label: {
                    quickActionRow(title: "上传 Set", icon: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickActionRow(title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(RaverTheme.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch viewModel.selectedSection {
        case .recent:
            if viewModel.recentPosts.isEmpty {
                ContentUnavailableView("还没有动态", systemImage: "square.and.pencil")
            } else {
                feedList(viewModel.recentPosts, actionAt: nil)
            }
        case .likes:
            if viewModel.likedItems.isEmpty {
                ContentUnavailableView("还没有点赞记录", systemImage: "heart")
            } else {
                feedList(viewModel.likedItems.map(\.post), actionAt: Dictionary(uniqueKeysWithValues: viewModel.likedItems.map { ($0.post.id, $0.actionAt) }))
            }
        case .reposts:
            if viewModel.repostedItems.isEmpty {
                ContentUnavailableView("还没有转发记录", systemImage: "arrow.2.squarepath")
            } else {
                feedList(viewModel.repostedItems.map(\.post), actionAt: Dictionary(uniqueKeysWithValues: viewModel.repostedItems.map { ($0.post.id, $0.actionAt) }))
            }
        }
    }

    @ViewBuilder
    private func feedList(_ posts: [Post], actionAt: [String: Date]?) -> some View {
        VStack(spacing: 12) {
            ForEach(posts) { post in
                VStack(alignment: .leading, spacing: 8) {
                    if let actionAt,
                       let at = actionAt[post.id] {
                        Text("操作于 \(at.feedTimeText)")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .padding(.horizontal, 4)
                    }

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
                            if post.author.id != appState.session?.user.id {
                                selectedUserForProfile = post.author
                            }
                        },
                        onSquadTap: nil
                    )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedPostForDetail = post
                }
            }
        }
    }
}

struct ProfileHeaderCard<Actions: View>: View {
    let profile: UserProfile
    let onAvatarTap: (() -> Void)?
    let onFollowersTap: (() -> Void)?
    let onFollowingTap: (() -> Void)?
    let onFriendsTap: (() -> Void)?
    @ViewBuilder let actions: () -> Actions

    init(
        profile: UserProfile,
        onAvatarTap: (() -> Void)? = nil,
        onFollowersTap: (() -> Void)? = nil,
        onFollowingTap: (() -> Void)? = nil,
        onFriendsTap: (() -> Void)? = nil,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.profile = profile
        self.onAvatarTap = onAvatarTap
        self.onFollowersTap = onFollowersTap
        self.onFollowingTap = onFollowingTap
        self.onFriendsTap = onFriendsTap
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 12) {
            avatarView

            Text(profile.displayName)
                .font(.title3.bold())
            Text("@\(profile.username)")
                .foregroundStyle(RaverTheme.secondaryText)

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            if !profile.tags.isEmpty {
                tagsFlow(profile.tags)
            }

            HStack(spacing: 24) {
                stat("动态", value: profile.postsCount)
                stat("粉丝", value: profile.followersCount, onTap: onFollowersTap)
                stat("关注", value: profile.followingCount, onTap: onFollowingTap)
                stat("好友", value: profile.friendsCount, onTap: onFriendsTap)
            }

            actions()
        }
        .padding(16)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let onAvatarTap {
            Button(action: onAvatarTap) {
                ProfileAvatarImage(profile: profile, size: 84)
            }
            .buttonStyle(.plain)
        } else {
            ProfileAvatarImage(profile: profile, size: 84)
        }
    }

    @ViewBuilder
    private func tagsFlow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tags.prefix(12).enumerated()), id: \.offset) { _, tag in
                    Text(formattedTagText(tag))
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RaverTheme.card)
                        .clipShape(Capsule())
                }

                if tags.count > 12 {
                    Text("+\(tags.count - 12)")
                        .font(.caption.bold())
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RaverTheme.card)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedTagText(_ tag: String) -> String {
        let words = normalizedTagWords(from: tag)
        guard !words.isEmpty else { return "#\(tag)" }

        if words.count == 1 {
            return "#\(words[0])"
        }

        if words.count == 2 {
            return "#\(words[0])\n\(words[1])"
        }

        if words.count == 3 {
            let lengths = words.enumerated().map { ($0.offset, $0.element.count) }
            guard let longest = lengths.max(by: { $0.1 < $1.1 })?.0 else {
                return "#\(words[0])\n\(words[1]) \(words[2])"
            }

            let others = words.enumerated()
                .filter { $0.offset != longest }
                .map(\.element)
                .joined(separator: " ")

            if longest == 2 {
                return "#\(others)\n\(words[2])"
            }
            return "#\(words[longest])\n\(others)"
        }

        return "#\(words.joined(separator: " "))"
    }

    private func normalizedTagWords(from tag: String) -> [String] {
        tag
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func stat(_ title: String, value: Int, onTap: (() -> Void)? = nil) -> some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    statBody(title: title, value: value)
                }
                .buttonStyle(.plain)
            } else {
                statBody(title: title, value: value)
            }
        }
    }

    private func statBody(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }
}

struct ProfileRecentCheckinsCard: View {
    let title: String
    let checkins: [WebCheckin]
    let emptyText: String
    let onShowAll: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Button("查看全部") {
                        onShowAll()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .buttonStyle(.plain)
                }

                if checkins.isEmpty {
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(checkins.prefix(3))) { item in
                        checkinPreviewRow(item)
                    }
                }
            }
        }
    }

    private func checkinPreviewRow(_ item: WebCheckin) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.type == "event" ? "calendar.circle.fill" : "music.mic.circle.fill")
                .font(.title3)
                .foregroundStyle(item.type == "event" ? Color(red: 0.88, green: 0.44, blue: 0.20) : Color(red: 0.26, green: 0.55, blue: 0.95))

            VStack(alignment: .leading, spacing: 4) {
                Text(checkinTitle(item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)

                Text(checkinSubtitle(item))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func checkinTitle(_ item: WebCheckin) -> String {
        if item.type == "event" {
            return item.event?.name ?? "活动打卡"
        }
        return item.dj?.name ?? "DJ 打卡"
    }

    private func checkinSubtitle(_ item: WebCheckin) -> String {
        let location: String = {
            if let event = item.event {
                let text = [event.city, event.country]
                    .compactMap { value in
                        guard let value, !value.isEmpty else { return nil }
                        return value
                    }
                    .joined(separator: " · ")
                return text.isEmpty ? "现场记录" : text
            }
            if let country = item.dj?.country, !country.isEmpty {
                return country
            }
            return "现场记录"
        }()
        return "\(item.attendedAt.formatted(date: .abbreviated, time: .omitted)) · \(location)"
    }
}

private struct ProfileAvatarImage: View {
    let profile: UserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let resolved = AppConfig.resolvedURLString(profile.avatarURL),
               let url = URL(string: resolved),
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(RaverTheme.card)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }

    private var fallbackAvatar: some View {
        let asset = AppConfig.resolvedUserAvatarAssetName(
            userID: profile.id,
            username: profile.username,
            avatarURL: profile.avatarURL
        )
        return Image(asset)
            .resizable()
            .scaledToFill()
    }
}

private struct AvatarFullscreenView: View {
    let profile: UserProfile
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                let size = min(proxy.size.width - 48, proxy.size.height * 0.62)
                VStack {
                    Spacer()
                    ProfileAvatarSquareImage(profile: profile, size: size)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                    Spacer()
                }
                .padding(.horizontal, 24)

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.white.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.top, 14)
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct ProfileAvatarSquareImage: View {
    let profile: UserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let resolved = AppConfig.resolvedURLString(profile.avatarURL),
               let url = URL(string: resolved),
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(RaverTheme.card)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fallbackAvatar: some View {
        let asset = AppConfig.resolvedUserAvatarAssetName(
            userID: profile.id,
            username: profile.username,
            avatarURL: profile.avatarURL
        )
        return Image(asset)
            .resizable()
            .scaledToFill()
    }
}
