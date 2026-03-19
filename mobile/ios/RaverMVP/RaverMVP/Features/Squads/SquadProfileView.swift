import SwiftUI

struct SquadProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: SquadProfileViewModel
    @State private var pushedConversation: Conversation?
    @State private var showManageSheet = false
    @State private var myNicknameDraft = ""
    @State private var myNotificationsEnabled = true
    @State private var selectedMember: SquadMemberProfile?

    init(squadID: String, service: SocialService = AppEnvironment.makeService()) {
        _viewModel = StateObject(wrappedValue: SquadProfileViewModel(squadID: squadID, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView("加载小队中...")
                        .padding(.top, 80)
                } else if let profile = viewModel.profile {
                    headerCard(profile)
                    membersCard(profile)
                    groupDetailsCard(profile)
                    activitiesCard(profile)
                    chatHistoryCard(profile)

                    if profile.isMember {
                        mySettingsCard(profile)
                    }

                    if profile.canEditGroup {
                        Button {
                            showManageSheet = true
                        } label: {
                            Label("编辑小队信息", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        Task {
                            if await viewModel.joinIfNeeded(), let conversation = viewModel.buildConversation() {
                                pushedConversation = conversation
                            }
                        }
                    } label: {
                        if viewModel.isProcessingJoin {
                            ProgressView().tint(.white)
                        } else {
                            Text(profile.isMember ? "进入小队" : "加入并进入小队")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    ContentUnavailableView("小队不存在", systemImage: "person.3.sequence")
                        .padding(.top, 80)
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .navigationTitle("小队")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pushedConversation) { conversation in
            ChatView(conversation: conversation, service: appState.service)
        }
        .navigationDestination(item: $selectedMember) { member in
            UserProfileView(userID: member.id)
        }
        .sheet(isPresented: $showManageSheet) {
            if let profile = viewModel.profile {
                SquadManageSheet(profile: profile, isSaving: viewModel.isSavingGroupInfo) { input in
                    Task {
                        let success = await viewModel.saveGroupInfo(input: input)
                        if success {
                            showManageSheet = false
                            syncMySettingsFromProfile()
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.load()
            syncMySettingsFromProfile()
        }
        .refreshable {
            await viewModel.load()
            syncMySettingsFromProfile()
        }
        .onChange(of: viewModel.profile?.updatedAt) { _, _ in
            syncMySettingsFromProfile()
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

    private func headerCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    squadAvatar(squadID: profile.id, urlString: profile.avatarURL)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.title3.bold())
                        Text(profile.isPublic ? "公开小队" : "私密小队")
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

                HStack(spacing: 16) {
                    stat("成员", value: profile.memberCount)
                    stat("上限", value: profile.maxMembers)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("队长")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(profile.leader.displayName)
                            .font(.subheadline.bold())
                    }
                }
            }
        }
    }

    private func membersCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("小队成员")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(profile.members) { member in
                            Button {
                                selectedMember = member
                            } label: {
                                VStack(spacing: 6) {
                                    avatar(
                                        userID: member.id,
                                        username: member.username,
                                        urlString: member.avatarURL,
                                        size: 46
                                    )

                                    Text(member.shownName)
                                        .font(.caption2)
                                        .lineLimit(1)

                                    if member.isCaptain {
                                        badge("队长", color: .orange)
                                    } else if member.isAdmin {
                                        badge("管理员", color: .blue)
                                    }
                                }
                                .frame(width: 70)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func groupDetailsCard(_ profile: SquadProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("小队详情")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("小队通知")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(profile.notice.isEmpty ? "暂无小队通知" : profile.notice)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("小队二维码")
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
                Text("小队活动")
                    .font(.headline)

                if profile.activities.isEmpty {
                    Text("近期暂无活动")
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
                Text("聊天历史记录")
                    .font(.headline)

                if profile.recentMessages.isEmpty {
                    Text("还没有消息，加入后来发第一条吧。")
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
                Text("我的小队设置")
                    .font(.headline)

                TextField("本小队昵称", text: $myNicknameDraft)
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Toggle(isOn: $myNotificationsEnabled) {
                    Text("通知权限")
                        .font(.subheadline)
                }
                .tint(RaverTheme.accent)

                HStack {
                    if let role = profile.myRole, !role.isEmpty {
                        Text("当前身份：\(roleLabel(role))")
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
                            Text("保存")
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
        case "leader": return "队长"
        case "admin": return "管理员"
        default: return "成员"
        }
    }

    private func stat(_ title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private func squadAvatar(squadID: String, urlString: String?) -> some View {
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

    private func avatar(userID: String, username: String, urlString: String?, size: CGFloat) -> some View {
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
            if let resolved, !resolved.isEmpty {
                AsyncImage(url: URL(string: resolved)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        qrPlaceholder
                    }
                }
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

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }
}

private struct SquadManageSheet: View {
    @Environment(\.dismiss) private var dismiss

    let isSaving: Bool
    let onSave: (UpdateSquadInfoInput) -> Void

    @State private var name: String
    @State private var descriptionText: String
    @State private var notice: String
    @State private var avatarURL: String
    @State private var qrCodeURL: String

    init(profile: SquadProfile, isSaving: Bool, onSave: @escaping (UpdateSquadInfoInput) -> Void) {
        self.isSaving = isSaving
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _descriptionText = State(initialValue: profile.description ?? "")
        _notice = State(initialValue: profile.notice)
        _avatarURL = State(initialValue: profile.avatarURL ?? "")
        _qrCodeURL = State(initialValue: profile.qrCodeURL ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础") {
                    TextField("小队名称", text: $name)
                    TextField("简介", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("展示") {
                    TextField("头像 URL（可选）", text: $avatarURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("小队二维码 URL（可选）", text: $qrCodeURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("小队通知") {
                    TextField("小队通知内容", text: $notice, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("编辑小队信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(
                            UpdateSquadInfoInput(
                                name: name,
                                description: descriptionText,
                                avatarURL: avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : avatarURL,
                                notice: notice,
                                qrCodeURL: qrCodeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : qrCodeURL
                            )
                        )
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
