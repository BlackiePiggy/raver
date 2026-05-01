import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @Environment(\.profilePush) private var profilePush
    @ObservedObject private var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: L("正在更新个人主页", "Updating profile"))
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
            }

            switch viewModel.phase {
            case .idle, .initialLoading:
                ProfileSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    VStack(spacing: 14) {
                        ScreenErrorCard(message: message) {
                            Task { await viewModel.load() }
                        }
                        profileQuickActions
                    }
                    .padding(16)
                    .padding(.top, 40)
                }
            case .empty:
                ScrollView {
                    VStack(spacing: 14) {
                        ContentUnavailableView(
                            L("离线模式", "Offline Mode"),
                            systemImage: "wifi.slash",
                            description: Text(L("网络不可用，已切换离线入口。你仍可进入我的行程和小工具。", "Network unavailable. Switched to offline entry. You can still access My Routes and Tools."))
                        )

                        profileQuickActions
                    }
                    .padding(16)
                }
            case .success:
                if let profile = viewModel.profile {
                    ScrollView {
                        VStack(spacing: 14) {
                            ProfileHeaderCard(
                                profile: profile,
                                onAvatarTap: {
                                    profilePush(.avatarFullscreen)
                                },
                                onFollowersTap: {
                                    profilePush(.followList(userID: currentUserID, kind: .followers))
                                },
                                onFollowingTap: {
                                    profilePush(.followList(userID: currentUserID, kind: .following))
                                },
                                onFriendsTap: {
                                    profilePush(.followList(userID: currentUserID, kind: .friends))
                                }
                            )

                            ProfileRecentCheckinsCard(
                                title: L("我的近期打卡", "My Recent Check-ins"),
                                checkins: viewModel.recentCheckins,
                                emptyText: L("去发现页完成活动或 DJ 打卡，记录会显示在这里。", "Complete event or DJ check-ins from Discover. Records will appear here.")
                            ) {
                                profilePush(.myCheckins(
                                    targetUserID: nil,
                                    title: L("我的打卡", "My Check-ins")
                                ))
                            }

                            profileQuickActions

                            Picker(LL("内容"), selection: $viewModel.selectedSection) {
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
                    ProfileSkeletonView()
                }
            }
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(RaverTheme.primaryText)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.profile != nil {
                    Button {
                        profilePush(.editProfile)
                    } label: {
                        Label(L("编辑", "Edit"), systemImage: "square.and.pencil")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.profile != nil {
                    Button {
                        profilePush(.settings)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    private var profileQuickActions: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("快捷入口", "Quick Actions"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                Button {
                    profilePush(.myPublishes)
                } label: {
                    quickActionRow(title: L("我的发布", "My Posts"), icon: "square.stack.3d.up")
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.selectedSection = .saves
                } label: {
                    quickActionRow(title: L("我的收藏", "My Saves"), icon: "bookmark")
                }
                .buttonStyle(.plain)

                Button {
                    profilePush(.myRoutes)
                } label: {
                    quickActionRow(title: L("我的行程", "My Routes"), icon: "point.topleft.down.curvedto.point.bottomright.up")
                }
                .buttonStyle(.plain)

                Button {
                    profilePush(.tools)
                } label: {
                    quickActionRow(title: L("小工具", "Tools"), icon: "wand.and.stars")
                }
                .buttonStyle(.plain)

                Button {
                    profilePush(.publishEvent)
                } label: {
                    quickActionRow(title: L("发布活动", "Publish Event"), icon: "calendar.badge.plus")
                }
                .buttonStyle(.plain)

                Button {
                    profilePush(.uploadSet)
                } label: {
                    quickActionRow(title: L("上传 Set", "Upload Set"), icon: "square.and.arrow.up")
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
                ContentUnavailableView(LL("还没有动态"), systemImage: "square.and.pencil")
            } else {
                feedList(viewModel.recentPosts, actionAt: nil)
            }
        case .likes:
            if viewModel.likedItems.isEmpty {
                ContentUnavailableView(LL("还没有点赞记录"), systemImage: "heart")
            } else {
                feedList(viewModel.likedItems.map(\.post), actionAt: Dictionary(uniqueKeysWithValues: viewModel.likedItems.map { ($0.post.id, $0.actionAt) }))
            }
        case .reposts:
            if viewModel.repostedItems.isEmpty {
                ContentUnavailableView(LL("还没有转发记录"), systemImage: "arrow.2.squarepath")
            } else {
                feedList(viewModel.repostedItems.map(\.post), actionAt: Dictionary(uniqueKeysWithValues: viewModel.repostedItems.map { ($0.post.id, $0.actionAt) }))
            }
        case .saves:
            if viewModel.savedItems.isEmpty {
                ContentUnavailableView(LL("还没有收藏记录"), systemImage: "bookmark")
            } else {
                feedList(viewModel.savedItems.map(\.post), actionAt: Dictionary(uniqueKeysWithValues: viewModel.savedItems.map { ($0.post.id, $0.actionAt) }))
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
                        Text(L("操作于 \(at.feedTimeText)", "Action at \(at.feedTimeText)"))
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
                        onSaveTap: {
                            Task { await viewModel.toggleSave(post: post) }
                        },
                        onFollowTap: nil,
                        onMessageTap: nil,
                        onAuthorTap: {
                            if post.author.id != appState.session?.user.id {
                                appPush(.userProfile(userID: post.author.id))
                            }
                        },
                        onSquadTap: nil
                    )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appPush(.postDetail(postID: post.id))
                }
            }
        }
    }

    private var currentUserID: String {
        appState.session?.user.id ?? ""
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
                stat(L("动态", "Posts"), value: profile.postsCount)
                stat(L("粉丝", "Followers"), value: profile.followersCount, onTap: onFollowersTap)
                stat(L("关注", "Following"), value: profile.followingCount, onTap: onFollowingTap)
                stat(L("好友", "Friends"), value: profile.friendsCount, onTap: onFriendsTap)
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
                    Button(LL("查看全部")) {
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
            if let event = item.event {
                if let nameI18n = event.nameI18n {
                    let localized = nameI18n.text(for: AppLanguagePreference.current.effectiveLanguage)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !localized.isEmpty { return localized }
                }
                let fallback = event.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !fallback.isEmpty { return fallback }
            }
            return L("活动打卡", "Event Check-in")
        }
        return item.dj?.name ?? L("DJ 打卡", "DJ Check-in")
    }

    private func checkinSubtitle(_ item: WebCheckin) -> String {
        let location: String = {
            if let event = item.event {
                let unified = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                return unified.isEmpty ? L("现场记录", "Live Record") : unified
            }
            if let country = item.dj?.country, !country.isEmpty {
                return country
            }
            return L("现场记录", "Live Record")
        }()
        return "\(item.attendedAt.appLocalizedYMDText()) · \(location)"
    }
}

private struct ProfileAvatarImage: View {
    let profile: UserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let resolved = AppConfig.resolvedURLString(profile.avatarURL),
               URL(string: resolved) != nil,
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                ImageLoaderView(urlString: resolved)
                    .background(fallbackAvatar)
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

struct AvatarFullscreenView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    var onClose: (() -> Void)? = nil

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
                            if let onClose {
                                onClose()
                            } else {
                                dismiss()
                            }
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
               URL(string: resolved) != nil,
               resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
                ImageLoaderView(urlString: resolved)
                    .background(fallbackAvatar)
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

struct MyRoutesView: View {
    @Environment(\.appPush) private var appPush
    @ObservedObject private var routeStore = EventRouteStore.shared
    @State private var cachedSnapshots: [EventManualCacheSnapshot] = []
    @State private var isLoadingCachedSnapshots = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if routeStore.routes.isEmpty, cachedSnapshots.isEmpty {
                    ContentUnavailableView(
                        L("暂无我的行程", "No Saved Routes"),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        description: Text(L("在活动时间表中定制并保存路线，或在活动详情缓存后，会显示在这里。", "Saved routes and cached events will appear here."))
                    )
                    .padding(.top, 80)
                }

                if !routeStore.routes.isEmpty {
                    sectionHeader(
                        title: L("我的路线", "My Saved Routes"),
                        subtitle: L("按你在时间表中的选择生成", "Built from your timetable selections")
                    )

                    ForEach(routeStore.routes) { route in
                        Button {
                            appPush(.eventSchedule(eventID: route.eventID))
                        } label: {
                            savedRouteRow(route)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                routeStore.delete(eventID: route.eventID)
                            } label: {
                                Label(L("删除", "Delete"), systemImage: "trash")
                            }
                        }
                    }
                }

                if !cachedSnapshots.isEmpty || isLoadingCachedSnapshots {
                    sectionHeader(
                        title: L("离线缓存活动", "Offline Cached Events"),
                        subtitle: L("弱网或离线时可直接打开", "Open directly in weak-network or offline mode")
                    )

                    if isLoadingCachedSnapshots, cachedSnapshots.isEmpty {
                        ProgressView(L("加载缓存中...", "Loading cache..."))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(cachedSnapshots) { snapshot in
                            Button {
                                appPush(.eventSchedule(eventID: snapshot.eventID))
                            } label: {
                                cachedSnapshotRow(snapshot)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await EventManualCacheStore.shared.removeSnapshot(eventID: snapshot.eventID)
                                        await loadCachedSnapshots()
                                    }
                                } label: {
                                    Label(L("删除缓存", "Delete Cache"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("我的行程", "My Routes"))
        .task {
            await loadCachedSnapshots()
        }
    }

    private func savedRouteRow(_ route: SavedEventRoute) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                ImageLoaderView(urlString: route.coverImageUrl, resizingMode: .fill)
                    .frame(width: 72, height: 72)
                    .background(
                        LinearGradient(
                            colors: [RaverTheme.accent.opacity(0.28), Color.black.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(route.eventName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    Label(eventDateText(route), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    Label(
                        L("\(route.selectedSlotIDs.count) 个已选演出", "\(route.selectedSlotIDs.count) selected sets"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private func cachedSnapshotRow(_ snapshot: EventManualCacheSnapshot) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                ImageLoaderView(
                    urlString: AppConfig.resolvedURLString(snapshot.event.coverAssetURL),
                    resizingMode: .fill
                )
                .frame(width: 72, height: 72)
                .background(
                    LinearGradient(
                        colors: [RaverTheme.accent.opacity(0.28), Color.black.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(snapshot.event.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    Label(eventDateText(snapshot.event), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    Label(
                        L("缓存于 \(Self.dateTimeFormatter.string(from: snapshot.cachedAt))", "Cached at \(Self.dateTimeFormatter.string(from: snapshot.cachedAt))"),
                        systemImage: "externaldrive.fill.badge.checkmark"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func eventDateText(_ route: SavedEventRoute) -> String {
        let start = Self.dateFormatter.string(from: route.startDate)
        let end = Self.dateFormatter.string(from: route.endDate)
        return start == end ? start : "\(start) - \(end)"
    }

    private func eventDateText(_ event: WebEvent) -> String {
        let start = Self.dateFormatter.string(from: event.startDate)
        let end = Self.dateFormatter.string(from: event.endDate)
        return start == end ? start : "\(start) - \(end)"
    }

    @MainActor
    private func loadCachedSnapshots() async {
        isLoadingCachedSnapshots = true
        defer { isLoadingCachedSnapshots = false }
        cachedSnapshots = await EventManualCacheStore.shared.allSnapshots()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguagePreference.current.effectiveLanguage == .zh ? "zh_Hans_CN" : "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguagePreference.current.effectiveLanguage == .zh ? "zh_Hans_CN" : "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ProfileToolsHubView: View {
    @Environment(\.profilePush) private var profilePush

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("演出现场常用工具", "Live Show Tools"))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(
                            L(
                                "输入一句话，立刻全屏展示，方便远距离应援互动。",
                                "Type one sentence and display it instantly in full screen for crowd interaction."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    profilePush(.movieBanner)
                } label: {
                    GlassCard {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L("Movie Banner 弹幕", "Movie Banner"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(L("超大字体全屏弹幕，支持静态与跑马灯。", "Huge full-screen banner with static and marquee modes."))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("小工具", "Tools"))
    }
}

struct MovieBannerEditorView: View {
    @State private var configuration = MovieBannerConfiguration()
    @State private var showDisplay = false
    @FocusState private var isInputFocused: Bool

    private var canStart: Bool {
        !configuration.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("弹幕内容", "Banner Message"))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)

                        TextField(
                            L("例如：XXX看这里 / 前排求互动", "For example: Look here / Front row says hi"),
                            text: $configuration.message,
                            axis: .vertical
                        )
                        .focused($isInputFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1 ... 4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )

                        Button {
                            isInputFocused = false
                            showDisplay = true
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(L("开始展示", "Start"))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canStart)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L("展示设置", "Display Settings"))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)

                        Picker(
                            L("展示模式", "Display Mode"),
                            selection: $configuration.mode
                        ) {
                            ForEach(MovieBannerMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        settingSliderRow(
                            title: L("字体大小", "Font Size"),
                            valueText: "\(Int(configuration.fontSize))",
                            value: $configuration.fontSize,
                            range: 64 ... 220,
                            step: 2
                        )

                        settingSliderRow(
                            title: L("滚动速度", "Scroll Speed"),
                            valueText: "\(Int(configuration.scrollSpeed))",
                            value: $configuration.scrollSpeed,
                            range: 20 ... 280,
                            step: 5
                        )

                        Toggle(L("闪烁效果", "Blink"), isOn: $configuration.isBlinkEnabled)
                            .tint(RaverTheme.accent)
                            .foregroundStyle(RaverTheme.primaryText)

                        Toggle(L("自动滚动", "Auto Scroll"), isOn: $configuration.autoScroll)
                            .tint(RaverTheme.accent)
                            .foregroundStyle(RaverTheme.primaryText)

                        MovieBannerColorPickerRow(
                            title: L("文字颜色", "Text Color"),
                            selection: $configuration.textColor
                        )

                        MovieBannerColorPickerRow(
                            title: L("背景颜色", "Background"),
                            selection: $configuration.backgroundColor
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("Movie Banner", "Movie Banner"))
        .fullScreenCover(isPresented: $showDisplay) {
            MovieBannerDisplayView(
                configuration: $configuration,
                isPresented: $showDisplay
            )
        }
    }

    @ViewBuilder
    private func settingSliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer(minLength: 8)
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            Slider(
                value: value,
                in: range,
                step: step
            )
            .tint(RaverTheme.accent)
        }
    }
}

private struct MovieBannerDisplayView: View {
    @Binding var configuration: MovieBannerConfiguration
    @Binding var isPresented: Bool

    @State private var controlsVisible = false
    @State private var isPaused = false
    @State private var scrollStartDate = Date()
    @State private var pausedDate: Date?
    @State private var pausedDuration: TimeInterval = 0
    @State private var controlsAutoHideTask: Task<Void, Never>?
    @State private var isInteractionLocked = false
    @State private var lockButtonOpacity: Double = 1.0
    @State private var lockButtonFadeTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            configuration.backgroundColor.color
                .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                bannerContent(in: context.date)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleScreenTap()
            }

            if controlsVisible {
                controlsLayer
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            lockButtonLayer
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBar(hidden: true)
        .onAppear {
            AppOrientationLock.shared.lockLandscapeOnly(forceRotate: true)
            resetScrollProgress()
            isPaused = !configuration.autoScroll
            showLockButtonTemporarily()
        }
        .onDisappear {
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
            lockButtonFadeTask?.cancel()
            lockButtonFadeTask = nil
            AppOrientationLock.shared.unlockLandscapeOnly(forcePortrait: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            if !isLandscapeInterface() {
                forceLandscapeOrientation()
            }
        }
        .onChange(of: configuration.mode) { _, mode in
            if mode == .staticCentered {
                isPaused = true
            } else if configuration.autoScroll {
                isPaused = false
            }
            resetScrollProgress()
        }
        .onChange(of: configuration.autoScroll) { _, enabled in
            if configuration.mode == .scrolling {
                isPaused = !enabled
                resetScrollProgress()
            }
        }
    }

    @ViewBuilder
    private func bannerContent(in renderDate: Date) -> some View {
        GeometryReader { proxy in
            if configuration.mode == .staticCentered {
                centeredTextView(renderDate: renderDate)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else if configuration.autoScroll {
                scrollingTextView(renderDate: renderDate, size: proxy.size)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                centeredTextView(renderDate: renderDate)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private func centeredTextView(renderDate: Date) -> some View {
        bannerText
            .lineLimit(1)
            .minimumScaleFactor(0.12)
            .padding(.horizontal, 20)
            .opacity(blinkOpacity(at: renderDate))
    }

    private func scrollingTextView(renderDate: Date, size: CGSize) -> some View {
        let message = resolvedMessage
        let font = UIFont.systemFont(ofSize: CGFloat(configuration.fontSize), weight: .bold)
        let textWidth = max(48, NSString(string: message).size(withAttributes: [.font: font]).width)
        let gap = max(40, CGFloat(configuration.fontSize) * 0.55)
        let cycle = textWidth + gap
        let timelineDate = frozenDate(for: renderDate)
        let elapsed = max(0, timelineDate.timeIntervalSince(scrollStartDate) - pausedDuration)
        let travel = CGFloat((elapsed * configuration.scrollSpeed).truncatingRemainder(dividingBy: Double(cycle)))
        let leadingOffset = size.width - travel

        return HStack(spacing: gap) {
            bannerText.opacity(blinkOpacity(at: timelineDate))
            bannerText.opacity(blinkOpacity(at: timelineDate))
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: true)
        .offset(x: leadingOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var controlsLayer: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        isPresented = false
                    } label: {
                        Label(L("返回", "Back"), systemImage: "chevron.backward")
                    }
                    .buttonStyle(.borderedProminent)

                    if configuration.mode == .scrolling {
                        Button {
                            if configuration.autoScroll {
                                togglePause()
                            } else {
                                configuration.autoScroll = true
                                isPaused = false
                                resetScrollProgress()
                            }
                        } label: {
                            Label(
                                configuration.autoScroll
                                    ? (isPaused ? L("继续", "Resume") : L("暂停", "Pause"))
                                    : L("开始滚动", "Start Scroll"),
                                systemImage: configuration.autoScroll
                                    ? (isPaused ? "play.fill" : "pause.fill")
                                    : "play.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer(minLength: 0)

                    Button {
                        configuration.textColor = configuration.textColor.next
                        keepControlsVisible()
                    } label: {
                        Label(L("文字色", "Text"), systemImage: "paintpalette")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        configuration.backgroundColor = configuration.backgroundColor.next
                        keepControlsVisible()
                    } label: {
                        Label(L("背景色", "BG"), systemImage: "circle.lefthalf.filled")
                    }
                    .buttonStyle(.bordered)
                }

                Picker(
                    L("模式", "Mode"),
                    selection: $configuration.mode
                ) {
                    ForEach(MovieBannerMode.allCases) { mode in
                        Text(mode.shortTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: configuration.mode) { _, _ in
                    keepControlsVisible()
                }

                if configuration.mode == .scrolling {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L("速度", "Speed"))
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.85))
                            Spacer(minLength: 8)
                            Text("\(Int(configuration.scrollSpeed))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                        Slider(
                            value: $configuration.scrollSpeed,
                            in: 20 ... 280,
                            step: 5
                        ) {
                            Text(L("速度", "Speed"))
                        } minimumValueLabel: {
                            Text(L("慢", "Slow"))
                                .font(.caption2)
                        } maximumValueLabel: {
                            Text(L("快", "Fast"))
                                .font(.caption2)
                        } onEditingChanged: { _ in
                            keepControlsVisible()
                        }
                        .tint(.white)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.66))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var lockButtonLayer: some View {
        HStack {
            Button {
                toggleInteractionLock()
            } label: {
                Image(systemName: isInteractionLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.58))
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .opacity(lockButtonOpacity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .allowsHitTesting(true)
    }

    private var bannerText: some View {
        Text(resolvedMessage)
            .font(.system(size: configuration.fontSize, weight: .bold))
            .foregroundStyle(configuration.textColor.color)
            .shadow(color: configuration.textColor.color.opacity(0.30), radius: 8, x: 0, y: 0)
    }

    private var resolvedMessage: String {
        let trimmed = configuration.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L("请输入内容", "Type Something") : trimmed
    }

    private func blinkOpacity(at date: Date) -> Double {
        guard configuration.isBlinkEnabled else { return 1.0 }
        let phase = sin(date.timeIntervalSinceReferenceDate * 8.0)
        return phase > 0 ? 1.0 : 0.28
    }

    private func togglePause() {
        if isPaused {
            if let pausedDate {
                pausedDuration += Date().timeIntervalSince(pausedDate)
            }
            self.pausedDate = nil
            isPaused = false
        } else {
            pausedDate = Date()
            isPaused = true
        }
        keepControlsVisible()
    }

    private func handleScreenTap() {
        showLockButtonTemporarily()
        guard !isInteractionLocked else { return }
        toggleControlsVisibility()
    }

    private func toggleInteractionLock() {
        isInteractionLocked.toggle()
        if isInteractionLocked {
            controlsVisible = false
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
        }
        showLockButtonTemporarily()
    }

    private func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
        if controlsVisible {
            scheduleControlsAutoHide()
        } else {
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
        }
    }

    private func keepControlsVisible() {
        guard controlsVisible else { return }
        scheduleControlsAutoHide()
    }

    private func scheduleControlsAutoHide() {
        controlsAutoHideTask?.cancel()
        controlsAutoHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controlsVisible = false
                }
            }
        }
    }

    private func showLockButtonTemporarily() {
        withAnimation(.easeOut(duration: 0.12)) {
            lockButtonOpacity = 1.0
        }
        scheduleLockButtonFadeOut()
    }

    private func scheduleLockButtonFadeOut() {
        lockButtonFadeTask?.cancel()
        lockButtonFadeTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.45)) {
                    lockButtonOpacity = 0
                }
            }
        }
    }

    private func resetScrollProgress() {
        scrollStartDate = Date()
        pausedDuration = 0
        pausedDate = isPaused ? Date() : nil
    }

    private func frozenDate(for date: Date) -> Date {
        guard configuration.mode == .scrolling, configuration.autoScroll else {
            return date
        }
        if isPaused, let pausedDate {
            return pausedDate
        }
        return date
    }

    private func forceLandscapeOrientation() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    }

    private func isLandscapeInterface() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .interfaceOrientation
            .isLandscape ?? false
    }
}

private struct MovieBannerColorPickerRow: View {
    let title: String
    @Binding var selection: MovieBannerColorPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(RaverTheme.primaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MovieBannerColorPreset.allCases) { preset in
                        Button {
                            selection = preset
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.45), lineWidth: 1)
                                    )
                                Text(preset.title)
                                    .font(.caption)
                            }
                            .foregroundStyle(selection == preset ? RaverTheme.primaryText : RaverTheme.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selection == preset ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct MovieBannerConfiguration {
    var message: String = ""
    var fontSize: Double = 120
    var scrollSpeed: Double = 90
    var isBlinkEnabled: Bool = false
    var autoScroll: Bool = true
    var mode: MovieBannerMode = .scrolling
    var textColor: MovieBannerColorPreset = .white
    var backgroundColor: MovieBannerColorPreset = .black
}

private enum MovieBannerMode: String, CaseIterable, Identifiable {
    case staticCentered
    case scrolling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .staticCentered:
            return L("静态居中", "Static Center")
        case .scrolling:
            return L("横向滚动", "Scrolling")
        }
    }

    var shortTitle: String {
        switch self {
        case .staticCentered:
            return L("静态", "Static")
        case .scrolling:
            return L("滚动", "Scroll")
        }
    }
}

private enum MovieBannerColorPreset: String, CaseIterable, Identifiable {
    case white
    case black
    case red
    case yellow
    case green
    case cyan
    case pink
    case purple
    case orange
    case blue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white:
            return L("白", "White")
        case .black:
            return L("黑", "Black")
        case .red:
            return L("红", "Red")
        case .yellow:
            return L("黄", "Yellow")
        case .green:
            return L("绿", "Green")
        case .cyan:
            return L("青", "Cyan")
        case .pink:
            return L("粉", "Pink")
        case .purple:
            return L("紫", "Purple")
        case .orange:
            return L("橙", "Orange")
        case .blue:
            return L("蓝", "Blue")
        }
    }

    var color: Color {
        switch self {
        case .white:
            return .white
        case .black:
            return .black
        case .red:
            return .red
        case .yellow:
            return .yellow
        case .green:
            return .green
        case .cyan:
            return .cyan
        case .pink:
            return .pink
        case .purple:
            return .purple
        case .orange:
            return .orange
        case .blue:
            return .blue
        }
    }

    var next: MovieBannerColorPreset {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        let nextIndex = all.index(after: index)
        return nextIndex == all.endIndex ? all[all.startIndex] : all[nextIndex]
    }
}
