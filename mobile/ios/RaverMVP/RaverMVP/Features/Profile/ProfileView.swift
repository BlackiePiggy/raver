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
        Group {
            if viewModel.isLoading && viewModel.profile == nil {
                ProgressView(L("加载中...", "Loading..."))
            } else if let profile = viewModel.profile {
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
                ContentUnavailableView(L("资料加载失败", "Failed to Load Profile"), systemImage: "person.crop.circle.badge.exclam")
            }
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
                if let locationI18n = event.locationI18n {
                    let localized = locationI18n.text(for: AppLanguagePreference.current.effectiveLanguage)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !localized.isEmpty {
                        return localized
                    }
                }

                let localizedCountry: String? = {
                    if let countryI18n = event.countryI18n {
                        let localized = countryI18n.text(for: AppLanguagePreference.current.effectiveLanguage)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return localized.isEmpty ? nil : localized
                    }
                    return nil
                }()
                let text = [event.city, event.country]
                    .compactMap { value in
                        guard let value, !value.isEmpty else { return nil }
                        return value
                    }
                    .joined(separator: " · ")
                let localizedText = [event.city, localizedCountry]
                    .compactMap { value in
                        guard let value, !value.isEmpty else { return nil }
                        return value
                    }
                    .joined(separator: " · ")
                if !localizedText.isEmpty { return localizedText }
                return text.isEmpty ? L("现场记录", "Live Record") : text
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
