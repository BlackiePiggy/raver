import SwiftUI
import PhotosUI
import UIKit

struct SquadProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @StateObject private var viewModel: SquadProfileViewModel
    @State private var myNicknameDraft = ""
    @State private var myNotificationsEnabled = true
    @State private var pendingRemoveMember: SquadMemberProfile?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    init(squadID: String, repository: SquadProfileRepository) {
        _viewModel = StateObject(wrappedValue: SquadProfileViewModel(squadID: squadID, repository: repository))
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新小队", "Updating squad", "Squadを更新中"))
                    }
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
                        ) {
                            Task {
                                await viewModel.load()
                                syncMySettingsFromProfile()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            switch viewModel.phase {
            case .idle, .initialLoading:
                SquadProfileSkeletonView()
            case .failure(let message), .offline(let message):
                Spacer()
                ScreenErrorCard(message: message) {
                    Task {
                        await viewModel.load()
                        syncMySettingsFromProfile()
                    }
                }
                .padding(.horizontal, 16)
                Spacer()
            case .empty:
                ContentUnavailableView(LT("小队不存在", "Squad not found", "Squadが存在しません"), systemImage: "person.3.sequence")
                    .padding(.top, 80)
            case .success:
                ScrollView {
                    VStack(spacing: 14) {
                        if let profile = viewModel.profile {
                            headerCard(profile)
                            membersCard(profile)
                            groupDetailsCard(profile)
                            activitiesCard(profile)

                            if profile.isMember {
                                mySettingsCard(profile)
                            }

                            if canManageSquad(profile) {
                                Button {
                                    appPush(.squadManage(squadID: profile.id))
                                } label: {
                                    Label(LT("编辑小队信息", "Edit Squad", "Squad情報を編集"), systemImage: "square.and.pencil")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }

                            Button {
                                Task {
                                    if await viewModel.joinIfNeeded(), let conversation = viewModel.buildConversation() {
                                        appPush(.conversation(target: .fromConversation(conversation)))
                                    }
                                }
                            } label: {
                                if viewModel.isProcessingJoin {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(profile.isMember ? LT("进入小队", "Enter Squad", "Squadへ入る") : LT("加入并进入小队", "Join & Enter Squad", "参加してSquadへ"))
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        } else {
                            ContentUnavailableView(LT("小队不存在", "Squad not found", "Squadが存在しません"), systemImage: "person.3.sequence")
                                .padding(.top, 80)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await viewModel.load()
                    syncMySettingsFromProfile()
                }
            }
        }
        .background(RaverTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LT("收起", "Dismiss", "閉じる")) {
                    dismissKeyboard()
                }
            }
        }
        .raverGradientNavigationChrome(
            title: LT("小队", "Squad", "Squad"),
            trailing: AnyView(headerTrailingActions)
        ) {
            dismiss()
        }
        .task {
            await viewModel.load()
            syncMySettingsFromProfile()
        }
        .onChange(of: viewModel.profile?.updatedAt) { _, _ in
            syncMySettingsFromProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadProfileDidUpdate)) { notification in
            let updatedSquadID = notification.object as? String
            guard let profile = viewModel.profile,
                  updatedSquadID == profile.id else { return }
            Task {
                await viewModel.load()
                syncMySettingsFromProfile()
            }
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
        .confirmationDialog(
            LT("移出小队成员", "Remove Squad Member", "Squadメンバーを削除"),
            isPresented: Binding(
                get: { pendingRemoveMember != nil },
                set: { if !$0 { pendingRemoveMember = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let member = pendingRemoveMember {
                Button(LT("移出 \(member.shownName)", "Remove \(member.shownName)", "\(member.shownName) を削除"), role: .destructive) {
                    let memberID = member.id
                    pendingRemoveMember = nil
                    Task { _ = await viewModel.removeMember(memberUserID: memberID) }
                }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {
                pendingRemoveMember = nil
            }
        } message: {
            if let member = pendingRemoveMember {
                Text(LT("将从小队中移出 \(member.shownName)。", "Remove \(member.shownName) from squad.", "\(member.shownName) をSquadから削除します。"))
            }
        }
    }

    @ViewBuilder
    private var headerTrailingActions: some View {
        if let profile = viewModel.profile {
            HStack(spacing: 8) {
                RaverNavigationCircleIconButton(
                    systemName: "qrcode",
                    style: .dimmed,
                    action: {
                        appPush(
                            .profile(
                                .shareQRCode(
                                    title: profile.name,
                                    subtitle: profile.description,
                                    imageURL: profile.avatarURL,
                                    shortURL: nil,
                                    qrCodeURL: profile.qrCodeURL
                                )
                            )
                        )
                    },
                    frameSize: 34,
                    font: .system(size: 14, weight: .semibold)
                )
                .accessibilityLabel(Text(LT("小队二维码", "Squad QR Code", "Squad QRコード")))

                RaverNavigationCircleIconButton(
                    systemName: "photo.on.rectangle",
                    style: .dimmed,
                    action: {
                        Task { await openSquadPoster(profile) }
                    },
                    frameSize: 34,
                    font: .system(size: 14, weight: .semibold)
                )
                .accessibilityLabel(Text(LT("分享海报", "Share Poster", "海報を共有")))

                RaverNavigationCircleIconButton(
                    systemName: "link",
                    style: .dimmed,
                    action: {
                        Task { await copySquadShareLink() }
                    },
                    frameSize: 34,
                    font: .system(size: 14, weight: .semibold)
                )
                .accessibilityLabel(Text(LT("复制链接", "Copy Link", "リンクをコピー")))
            }
        } else {
            Color.clear
                .frame(width: 34, height: 34)
        }
    }

    @MainActor
    private func copySquadShareLink() async {
        guard let profile = viewModel.profile else { return }

        let isInviteLink = !profile.isPublic
        let targetType: ShareTargetType = isInviteLink ? .squadInvite : .squadCard
        let successMessage = isInviteLink
            ? LT("已复制小队邀请链接", "Squad invite link copied", "Squad招待リンクをコピーしました")
            : LT("已复制小队链接", "Squad link copied", "Squadリンクをコピーしました")
        let failureMessage = isInviteLink
            ? LT("复制小队邀请链接失败，请稍后重试。", "Failed to copy squad invite link. Please try again.", "Squad招待リンクをコピーできませんでした。もう一度お試しください。")
            : LT("复制小队链接失败，请稍后重试。", "Failed to copy squad link. Please try again.", "Squadリンクをコピーできませんでした。もう一度お試しください。")

        do {
            let result = try await shareLinkCoordinator.copyLink(
                target: ShareTarget(
                    type: targetType,
                    id: profile.id,
                    title: isInviteLink ? LT("加入「\(profile.name)」", "Join \(profile.name)", "「\(profile.name)」に参加") : profile.name,
                    subtitle: profile.description,
                    imageURL: profile.avatarURL
                ),
                channel: isInviteLink ? "copy_invite_link" : "copy_link",
                preferPermanent: !isInviteLink,
                expiresInHours: isInviteLink ? 72 : nil,
                maxUses: isInviteLink ? 10 : nil
            )

            if result.usedDeepLinkFallback {
                viewModel.error = LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
            } else {
                OperationBannerCenter.shared.success(successMessage)
            }
        } catch {
            viewModel.error = error.userFacingMessage ?? failureMessage
        }
    }

    @MainActor
    private func openSquadPoster(_ profile: SquadProfile) async {
        let isInviteLink = !profile.isPublic
        let targetType: ShareTargetType = isInviteLink ? .squadInvite : .squadCard

        do {
            let resolved = try await shareLinkCoordinator.resolveLink(
                target: ShareTarget(
                    type: targetType,
                    id: profile.id,
                    title: isInviteLink ? LT("加入「\(profile.name)」", "Join \(profile.name)", "「\(profile.name)」に参加") : profile.name,
                    subtitle: profile.description,
                    imageURL: profile.avatarURL
                ),
                channel: "view_poster",
                preferPermanent: !isInviteLink,
                expiresInHours: isInviteLink ? 72 : nil,
                maxUses: isInviteLink ? 10 : nil
            )
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: profile.name,
                        subtitle: profile.description,
                        imageURL: profile.avatarURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: isInviteLink
                            ? LT("私密小队海报仍受邀请规则控制，过期或撤销后将无法继续加入。", "Private squad posters still follow invite-link rules and stop working after expiry or revocation.", "非公開Squadの海報は招待ルールに従います。有効期限切れまたは取消後は参加できません。")
                            : LT("群名片海报由系统统一生成，后续更新群头像或简介后可继续复用。", "The squad poster is generated by the system and can continue to be reused after future avatar or bio updates.", "Squad海報はシステムで生成され、今後アバターや紹介を更新しても継続利用できます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            viewModel.error = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    private func headerCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    squadAvatar(squadID: profile.id, urlString: profile.avatarURL)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.title3.bold())
                        Text("\(profile.isPublic ? LT("公开小队", "Public Squad", "公開Squad") : LT("私密小队", "Private Squad", "非公開Squad")) (\(profile.memberCount)/\(profile.maxMembers))")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(RaverTheme.card)
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)
                }

                if let description = profile.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
    }

    private func membersCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(LT("小队成员", "Squad Members", "Squadメンバー"))
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(profile.members) { member in
                            Button {
                                appPush(.userProfile(userID: member.id))
                            } label: {
                                VStack(spacing: 6) {
                                    avatarWithRoleBadge(member: member, size: 46)

                                    Text(member.shownName)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .frame(width: 70)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                memberContextMenu(profile: profile, member: member)
                            }
                        }
                    }
                }
            }
        }
    }

    private func groupDetailsCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(LT("小队详情", "Squad Details", "Squad詳細"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text(LT("小队通知", "Squad Notice", "Squad通知"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(profile.notice.isEmpty ? LT("暂无小队通知", "No Squad Notice Yet", "Squad通知はまだありません") : profile.notice)
                        .font(.subheadline)
                }
            }
        }
    }

    private func activitiesCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(LT("小队活动", "Squad Activities", "Squad活動"))
                    .font(.headline)

                if profile.activities.isEmpty {
                    Text(LT("近期暂无活动", "No recent activities", "最近の活動はありません"))
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(profile.activities) { activity in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.title)
                                .font(.subheadline.bold())
                            if let description = activity.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Text(activity.date.feedTimeText)
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func mySettingsCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(LT("我的小队设置", "My Squad Settings", "自分のSquad設定"))
                    .font(.headline)

                TextField(LT("本小队昵称", "Nickname in this squad", "このSquadでのニックネーム"), text: $myNicknameDraft)
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Toggle(isOn: $myNotificationsEnabled) {
                    Text(LT("通知权限", "Notification Permission", "通知権限"))
                        .font(.subheadline)
                }
                .tint(RaverTheme.accent)

                HStack {
                    if let role = profile.myRole, !role.isEmpty {
                        Text(LT("当前身份：\(roleLabel(role))", "Role: \(roleLabel(role))", "現在の役割: \(roleLabel(role))"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        Task {
                            _ = await viewModel.saveMySettings(
                                nickname: myNicknameDraft,
                                notificationsEnabled: myNotificationsEnabled
                            )
                        }
                    } label: {
                        if viewModel.isSavingMySettings {
                            ProgressView()
                        } else {
                            Text(LT("保存", "Save", "保存"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func syncMySettingsFromProfile() {
        guard let profile = viewModel.profile else { return }
        myNicknameDraft = profile.myNickname ?? ""
        myNotificationsEnabled = profile.myNotificationsEnabled ?? true
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "leader": return LT("队长", "Leader", "リーダー")
        case "admin": return LT("管理员", "Admin", "管理者")
        default: return LT("成员", "Member", "メンバー")
        }
    }

    private func canManageSquad(_ profile: SquadProfile) -> Bool {
        if profile.canEditGroup {
            return true
        }
        guard let role = profile.myRole else { return false }
        return role == "leader" || role == "admin"
    }

    @ViewBuilder
    private func memberContextMenu(profile: SquadProfile, member: SquadMemberProfile) -> some View {
        if let myRole = profile.myRole, viewModel.memberActionInFlightUserID == nil {
            if myRole == "leader" {
                if member.role == "member" {
                    Button {
                        Task { _ = await viewModel.updateMemberRole(memberUserID: member.id, role: "admin") }
                    } label: {
                        Label(LT("设为管理员", "Promote to Admin", "管理者に昇格"), systemImage: "person.badge.plus")
                    }
                }

                if member.role == "admin" {
                    Button {
                        Task { _ = await viewModel.updateMemberRole(memberUserID: member.id, role: "member") }
                    } label: {
                        Label(LT("降为成员", "Demote to Member", "メンバーに降格"), systemImage: "person.badge.minus")
                    }
                }

                if member.role != "leader" {
                    Button {
                        Task { _ = await viewModel.updateMemberRole(memberUserID: member.id, role: "leader") }
                    } label: {
                        Label(LT("转让队长", "Transfer Leader", "リーダーを譲渡"), systemImage: "crown")
                    }

                    Button(role: .destructive) {
                        pendingRemoveMember = member
                    } label: {
                        Label(LT("移出小队", "Remove from Squad", "Squadから削除"), systemImage: "person.crop.circle.badge.xmark")
                    }
                }
            } else if myRole == "admin", member.role == "member" {
                Button(role: .destructive) {
                    pendingRemoveMember = member
                } label: {
                    Label(LT("移出小队", "Remove from Squad", "Squadから削除"), systemImage: "person.crop.circle.badge.xmark")
                }
            }
        }
    }

    @ViewBuilder
    private func squadAvatar(squadID: String, urlString: String?) -> some View {
        if let resolved = AppConfig.resolvedURLString(urlString),
           URL(string: resolved) != nil,
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(squadAvatarFallback(squadID: squadID, urlString: urlString))
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            squadAvatarFallback(squadID: squadID, urlString: urlString)
        }
    }

    private func squadAvatarFallback(squadID: String, urlString: String?) -> some View {
        AvatarPlaceholderView(size: 56, isGroup: true, backgroundColor: RaverTheme.card)
    }

    @ViewBuilder
    private func avatar(userID: String, username: String, urlString: String?, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(urlString),
           URL(string: resolved) != nil,
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(avatarFallback(userID: userID, username: username, urlString: urlString, size: size))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            avatarFallback(userID: userID, username: username, urlString: urlString, size: size)
        }
    }

    private func avatarFallback(userID: String, username: String, urlString: String?, size: CGFloat) -> some View {
        AvatarPlaceholderView(size: size, backgroundColor: RaverTheme.card)
            .background(RaverTheme.card)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    private func avatarWithRoleBadge(member: SquadMemberProfile, size: CGFloat) -> some View {
        avatar(
            userID: member.id,
            username: member.username,
            urlString: member.avatarURL,
            size: size
        )
        .overlay(alignment: .bottom) {
            if let role = memberRoleBadge(member) {
                roleBadge(role.title, color: role.color)
            }
        }
    }

    private func memberRoleBadge(_ member: SquadMemberProfile) -> (title: String, color: Color)? {
        if member.isCaptain {
            return (LT("队长", "Leader", "リーダー"), .orange)
        }
        if member.isAdmin {
            return (LT("管理员", "Admin", "管理者"), .blue)
        }
        return nil
    }

    private func roleBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundStyle(.white)
            .background(color.opacity(0.9))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.75), lineWidth: 0.7)
            )
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

struct SquadManageRouteView: View {
    @Environment(\.dismiss) private var dismiss

    let squadID: String
    let repository: SquadProfileRepository

    @State private var profile: SquadProfile?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && profile == nil {
                ProgressView(LT("加载小队中...", "Loading squads...", "Squadを読み込み中..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile {
                SquadManageFormView(
                    profile: profile,
                    isSaving: isSaving,
                    repository: repository
                ) { input in
                    Task {
                        await save(input: input)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ContentUnavailableView(LT("小队不存在", "Squad not found", "Squadが存在しません"), systemImage: "person.3.sequence")
                    Button(LT("重试", "Retry", "再試行")) {
                        Task {
                            await load(force: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("编辑小队信息", "Edit Squad Info", "Squad情報を編集"))
        .task {
            await load(force: false)
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func load(force: Bool) async {
        if isLoading { return }
        if profile != nil && !force { return }

        isLoading = true
        defer { isLoading = false }

        do {
            profile = try await repository.fetchSquadProfile(squadID: squadID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func save(input: UpdateSquadInfoInput) async {
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await repository.updateSquadInfo(squadID: squadID, input: input)
            NotificationCenter.default.post(name: .squadProfileDidUpdate, object: squadID)
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct SquadManageFormView: View {
    private enum PrivacyOption: String, CaseIterable, Identifiable {
        case `public`
        case `private`

        var id: String { rawValue }
        var title: String {
            switch self {
            case .public: return LT("公开小队", "Public Squad", "公開Squad")
            case .private: return LT("私密小队", "Private Squad", "非公開Squad")
            }
        }

        var isPublic: Bool { self == .public }
    }

    let isSaving: Bool
    let onSave: (UpdateSquadInfoInput) -> Void

    private let squadID: String
    @State private var name: String
    @State private var descriptionText: String
    @State private var privacyOption: PrivacyOption
    @State private var notice: String
    @State private var avatarURL: String
    @State private var bannerURL: String
    @State private var selectedAvatarPhotoItem: PhotosPickerItem?
    @State private var selectedFlagPhotoItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var isUploadingFlag = false
    @State private var uploadError: String?
    private let repository: SquadProfileRepository

    init(
        profile: SquadProfile,
        isSaving: Bool,
        repository: SquadProfileRepository,
        onSave: @escaping (UpdateSquadInfoInput) -> Void
    ) {
        self.squadID = profile.id
        self.isSaving = isSaving
        self.repository = repository
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _descriptionText = State(initialValue: profile.description ?? "")
        _privacyOption = State(initialValue: profile.isPublic ? .public : .private)
        _notice = State(initialValue: profile.notice)
        _avatarURL = State(initialValue: profile.avatarURL ?? "")
        _bannerURL = State(initialValue: profile.bannerURL ?? "")
    }

    var body: some View {
        Form {
            Section(LT("基础", "Basics", "基本")) {
                TextField(LT("小队名称", "Squad name", "Squad名"), text: $name)
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
                TextField(LT("简介", "Description", "紹介"), text: $descriptionText, axis: .vertical)
                    .lineLimit(2...4)
                Picker(LT("小队性质", "Squad Type", "Squad種別"), selection: $privacyOption) {
                    ForEach(PrivacyOption.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(LT("展示", "Display", "表示")) {
                TextField(LT("头像 URL（可选）", "Avatar URL (optional)", "アバターURL（任意）"), text: $avatarURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
                PhotosPicker(selection: $selectedAvatarPhotoItem, matching: .images) {
                    if isUploadingAvatar {
                        Label(LT("头像上传中...", "Uploading avatar...", "アバターをアップロード中..."), systemImage: "arrow.trianglehead.2.clockwise")
                    } else {
                        Label(LT("从相册选择小队头像", "Choose squad avatar from Photos", "写真からSquadアバターを選択"), systemImage: "person.crop.circle.badge.plus")
                    }
                }
                .disabled(isUploadingAvatar || isUploadingFlag)
                TextField(LT("旗帜图 URL（可选）", "Banner URL (optional)", "バナー画像URL（任意）"), text: $bannerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
                PhotosPicker(selection: $selectedFlagPhotoItem, matching: .images) {
                    if isUploadingFlag {
                        Label(LT("旗帜图上传中...", "Uploading banner...", "バナー画像をアップロード中..."), systemImage: "arrow.trianglehead.2.clockwise")
                    } else {
                        Label(LT("从相册选择旗帜图", "Choose banner from Photos", "写真からバナー画像を選択"), systemImage: "flag.pattern.checkered")
                    }
                }
                .disabled(isUploadingFlag)
            }

            Section(LT("小队通知", "Squad Notice", "Squad通知")) {
                TextField(LT("小队通知内容", "Squad notice content", "Squad通知内容"), text: $notice, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onSave(
                        UpdateSquadInfoInput(
                            name: name,
                            description: descriptionText,
                            isPublic: privacyOption.isPublic,
                            avatarURL: avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : avatarURL,
                            bannerURL: bannerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bannerURL,
                            notice: notice,
                            qrCodeURL: nil
                        )
                    )
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(LT("保存", "Save", "保存"))
                    }
                }
                .disabled(isSaving || isUploadingAvatar || isUploadingFlag || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LT("收起", "Dismiss", "閉じる")) {
                    dismissKeyboard()
                }
            }
        }
        .onChange(of: selectedAvatarPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                await uploadAvatarImage(data: data)
            }
        }
        .onChange(of: selectedFlagPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                await uploadFlagImage(data: data)
            }
        }
        .alert(LT("上传失败", "Upload Failed", "アップロードに失敗しました"), isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(uploadError ?? "")
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    @MainActor
    private func uploadAvatarImage(data: Data) async {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            let uploadData: Data
            if let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.88) {
                uploadData = jpeg
            } else {
                uploadData = data
            }
            let uploaded = try await repository.uploadSquadAvatar(
                squadID: squadID,
                imageData: uploadData,
                fileName: "squad-avatar-\(Int(Date().timeIntervalSince1970)).jpg",
                mimeType: "image/jpeg"
            )
            avatarURL = uploaded.avatarURL
        } catch {
            uploadError = error.userFacingMessage
        }
    }

    @MainActor
    private func uploadFlagImage(data: Data) async {
        isUploadingFlag = true
        defer { isUploadingFlag = false }
        do {
            let uploaded = try await repository.uploadSquadBannerImage(
                imageData: data,
                fileName: "squad-flag-\(Int(Date().timeIntervalSince1970)).jpg",
                mimeType: "image/jpeg"
            )
            bannerURL = uploaded.url
        } catch {
            uploadError = error.userFacingMessage
        }
    }
}

extension Notification.Name {
    static let squadProfileDidUpdate = Notification.Name("squadProfileDidUpdate")
}
