import SwiftUI
import PhotosUI
import UIKit

struct SquadProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    private let service: SocialService
    @StateObject private var viewModel: SquadProfileViewModel
    @State private var myNicknameDraft = ""
    @State private var myNotificationsEnabled = true
    @State private var pendingRemoveMember: SquadMemberProfile?

    init(squadID: String, service: SocialService) {
        self.service = service
        _viewModel = StateObject(wrappedValue: SquadProfileViewModel(squadID: squadID, service: service))
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: L("正在更新小队", "Updating squad"))
                    }
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: L("重试", "Retry")
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
                ContentUnavailableView(LL("小队不存在"), systemImage: "person.3.sequence")
                    .padding(.top, 80)
            case .success:
                ScrollView {
                    VStack(spacing: 14) {
                        if let profile = viewModel.profile {
                            headerCard(profile)
                            membersCard(profile)
                            groupDetailsCard(profile)
                            activitiesCard(profile)
                            chatHistoryCard(profile)

                            if profile.isMember {
                                mySettingsCard(profile)
                            }

                            if canManageSquad(profile) {
                                Button {
                                    appPush(.squadManage(squadID: profile.id))
                                } label: {
                                    Label(L("编辑小队信息", "Edit Squad"), systemImage: "square.and.pencil")
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
                                    Text(profile.isMember ? L("进入小队", "Enter Squad") : L("加入并进入小队", "Join & Enter Squad"))
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        } else {
                            ContentUnavailableView(LL("小队不存在"), systemImage: "person.3.sequence")
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
                Button(L("收起", "Dismiss")) {
                    dismissKeyboard()
                }
            }
        }
        .raverGradientNavigationChrome(title: LL("小队")) {
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
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
        .confirmationDialog(
            L("移出小队成员", "Remove Squad Member"),
            isPresented: Binding(
                get: { pendingRemoveMember != nil },
                set: { if !$0 { pendingRemoveMember = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let member = pendingRemoveMember {
                Button(L("移出 \(member.shownName)", "Remove \(member.shownName)"), role: .destructive) {
                    let memberID = member.id
                    pendingRemoveMember = nil
                    Task { _ = await viewModel.removeMember(memberUserID: memberID) }
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {
                pendingRemoveMember = nil
            }
        } message: {
            if let member = pendingRemoveMember {
                Text(L("将从小队中移出 \(member.shownName)。", "Remove \(member.shownName) from squad."))
            }
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
                        Text("\(profile.isPublic ? L("公开小队", "Public Squad") : L("私密小队", "Private Squad")) (\(profile.memberCount)/\(profile.maxMembers))")
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
                Text(LL("小队成员"))
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
                Text(LL("小队详情"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text(LL("小队通知"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(profile.notice.isEmpty ? L("暂无小队通知", "No Squad Notice Yet") : profile.notice)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(LL("小队二维码"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    groupQRCode(urlString: profile.qrCodeURL)
                }
            }
        }
    }

    private func activitiesCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(LL("小队活动"))
                    .font(.headline)

                if profile.activities.isEmpty {
                    Text(LL("近期暂无活动"))
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

    private func chatHistoryCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(LL("聊天历史记录"))
                    .font(.headline)

                if profile.recentMessages.isEmpty {
                    Text(LL("还没有消息，加入后来发第一条吧。"))
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(profile.recentMessages) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.sender.displayName)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(item.content)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text(item.createdAt.feedTimeText)
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
                Text(LL("我的小队设置"))
                    .font(.headline)

                TextField(LL("本小队昵称"), text: $myNicknameDraft)
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Toggle(isOn: $myNotificationsEnabled) {
                    Text(LL("通知权限"))
                        .font(.subheadline)
                }
                .tint(RaverTheme.accent)

                HStack {
                    if let role = profile.myRole, !role.isEmpty {
                        Text(L("当前身份：\(roleLabel(role))", "Role: \(roleLabel(role))"))
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
                            Text(L("保存", "Save"))
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
        case "leader": return L("队长", "Leader")
        case "admin": return L("管理员", "Admin")
        default: return L("成员", "Member")
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
                        Label(L("设为管理员", "Promote to Admin"), systemImage: "person.badge.plus")
                    }
                }

                if member.role == "admin" {
                    Button {
                        Task { _ = await viewModel.updateMemberRole(memberUserID: member.id, role: "member") }
                    } label: {
                        Label(L("降为成员", "Demote to Member"), systemImage: "person.badge.minus")
                    }
                }

                if member.role != "leader" {
                    Button {
                        Task { _ = await viewModel.updateMemberRole(memberUserID: member.id, role: "leader") }
                    } label: {
                        Label(L("转让队长", "Transfer Leader"), systemImage: "crown")
                    }

                    Button(role: .destructive) {
                        pendingRemoveMember = member
                    } label: {
                        Label(L("移出小队", "Remove from Squad"), systemImage: "person.crop.circle.badge.xmark")
                    }
                }
            } else if myRole == "admin", member.role == "member" {
                Button(role: .destructive) {
                    pendingRemoveMember = member
                } label: {
                    Label(L("移出小队", "Remove from Squad"), systemImage: "person.crop.circle.badge.xmark")
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
        Image(
            AppConfig.resolvedGroupAvatarAssetName(
                groupID: squadID,
                groupName: viewModel.profile?.name,
                avatarURL: urlString
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: 56, height: 56)
        .background(RaverTheme.card)
        .clipShape(Circle())
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
        let asset = AppConfig.resolvedUserAvatarAssetName(
            userID: userID,
            username: username,
            avatarURL: urlString
        )
        return Image(asset)
            .resizable()
            .scaledToFill()
            .background(RaverTheme.card)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    private func groupQRCode(urlString: String?) -> some View {
        let resolved = AppConfig.resolvedURLString(urlString)
        return Group {
            if let resolved, !resolved.isEmpty, URL(string: resolved) != nil {
                ImageLoaderView(urlString: resolved, resizingMode: .fit)
                    .background(qrPlaceholder)
            } else {
                qrPlaceholder
            }
        }
        .frame(width: 160, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var qrPlaceholder: some View {
        ZStack {
            RaverTheme.card
            Image(systemName: "qrcode")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(RaverTheme.secondaryText)
        }
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
            return (L("队长", "Leader"), .orange)
        }
        if member.isAdmin {
            return (L("管理员", "Admin"), .blue)
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
    let service: SocialService
    let webService: WebFeatureService

    @State private var profile: SquadProfile?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && profile == nil {
                ProgressView(L("加载小队中...", "Loading squads..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile {
                SquadManageFormView(
                    profile: profile,
                    isSaving: isSaving,
                    webService: webService,
                    socialService: service
                ) { input in
                    Task {
                        await save(input: input)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ContentUnavailableView(LL("小队不存在"), systemImage: "person.3.sequence")
                    Button(L("重试", "Retry")) {
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
        .raverSystemNavigation(title: LL("编辑小队信息"))
        .task {
            await load(force: false)
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
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
            profile = try await service.fetchSquadProfile(squadID: squadID)
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
            try await service.updateSquadInfo(squadID: squadID, input: input)
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
            case .public: return L("公开小队", "Public Squad")
            case .private: return L("私密小队", "Private Squad")
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
    @State private var qrCodeURL: String
    @State private var selectedAvatarPhotoItem: PhotosPickerItem?
    @State private var selectedFlagPhotoItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var isUploadingFlag = false
    @State private var uploadError: String?
    private let webService: WebFeatureService
    private let socialService: SocialService

    init(
        profile: SquadProfile,
        isSaving: Bool,
        webService: WebFeatureService,
        socialService: SocialService,
        onSave: @escaping (UpdateSquadInfoInput) -> Void
    ) {
        self.squadID = profile.id
        self.isSaving = isSaving
        self.webService = webService
        self.socialService = socialService
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _descriptionText = State(initialValue: profile.description ?? "")
        _privacyOption = State(initialValue: profile.isPublic ? .public : .private)
        _notice = State(initialValue: profile.notice)
        _avatarURL = State(initialValue: profile.avatarURL ?? "")
        _bannerURL = State(initialValue: profile.bannerURL ?? "")
        _qrCodeURL = State(initialValue: profile.qrCodeURL ?? "")
    }

    var body: some View {
        Form {
            Section(LL("基础")) {
                TextField(LL("小队名称"), text: $name)
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
                TextField(LL("简介"), text: $descriptionText, axis: .vertical)
                    .lineLimit(2...4)
                Picker(LL("小队性质"), selection: $privacyOption) {
                    ForEach(PrivacyOption.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(LL("展示")) {
                TextField(LL("头像 URL（可选）"), text: $avatarURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
                PhotosPicker(selection: $selectedAvatarPhotoItem, matching: .images) {
                    if isUploadingAvatar {
                        Label(LL("头像上传中..."), systemImage: "arrow.trianglehead.2.clockwise")
                    } else {
                        Label(LL("从相册选择小队头像"), systemImage: "person.crop.circle.badge.plus")
                    }
                }
                .disabled(isUploadingAvatar || isUploadingFlag)
                TextField(LL("旗帜图 URL（可选）"), text: $bannerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
                PhotosPicker(selection: $selectedFlagPhotoItem, matching: .images) {
                    if isUploadingFlag {
                        Label(LL("旗帜图上传中..."), systemImage: "arrow.trianglehead.2.clockwise")
                    } else {
                        Label(LL("从相册选择旗帜图"), systemImage: "flag.pattern.checkered")
                    }
                }
                .disabled(isUploadingFlag)
                TextField(LL("小队二维码 URL（可选）"), text: $qrCodeURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
            }

            Section(LL("小队通知")) {
                TextField(LL("小队通知内容"), text: $notice, axis: .vertical)
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
                            qrCodeURL: qrCodeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : qrCodeURL
                        )
                    )
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(L("保存", "Save"))
                    }
                }
                .disabled(isSaving || isUploadingAvatar || isUploadingFlag || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Dismiss")) {
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
        .alert(LL("上传失败"), isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
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
            let uploaded = try await socialService.uploadSquadAvatar(
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
            let uploaded = try await webService.uploadEventImage(
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
