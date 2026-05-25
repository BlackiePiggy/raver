import SwiftUI
import PhotosUI
import UIKit

struct SaveProfileUseCase {
    private let repository: ProfileUserRepository

    init(repository: ProfileUserRepository) {
        self.repository = repository
    }

    func execute(
        displayName: String,
        bio: String,
        birthYear: Int?,
        tags: [String],
        isFollowersListPublic: Bool,
        isFollowingListPublic: Bool
    ) async throws -> UserProfile {
        return try await repository.updateMyProfile(input: UpdateMyProfileInput(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            birthYear: birthYear,
            tags: tags,
            isFollowersListPublic: isFollowersListPublic,
            isFollowingListPublic: isFollowingListPublic
        ))
    }
}

@MainActor
final class EditProfileViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var error: String?

    private let saveProfileUseCase: SaveProfileUseCase

    init(repository: ProfileUserRepository) {
        self.saveProfileUseCase = SaveProfileUseCase(repository: repository)
    }

    func saveProfile(
        displayName: String,
        bio: String,
        birthYear: Int?,
        tags: [String],
        isFollowersListPublic: Bool,
        isFollowingListPublic: Bool,
    ) async -> UserProfile? {
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await saveProfileUseCase.execute(
                displayName: displayName,
                bio: bio,
                birthYear: birthYear,
                tags: tags,
                isFollowersListPublic: isFollowersListPublic,
                isFollowingListPublic: isFollowingListPublic
            )
            error = nil
            return updated
        } catch {
            self.error = error.userFacingMessage
            return nil
        }
    }
}

private extension UIImage {
    func resizedForProfileAvatar(maxPixel: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > maxPixel else { return self }
        let scale = maxPixel / longest
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image {
            _ in draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    @StateObject private var viewModel: EditProfileViewModel
    private let repository: ProfileUserRepository
    private let onSaved: (UserProfile) -> Void

    @State private var displayName: String
    @State private var bio: String
    @State private var selectedTags: [String]
    @State private var isBirthDateKnown: Bool
    @State private var selectedBirthDate: Date
    @State private var isFollowersListPublic: Bool
    @State private var isFollowingListPublic: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarData: Data?
    @State private var availableGenreTags: [String] = []
    @State private var tagSearchText = ""
    @State private var isLoadingGenreTags = false
    @State private var isShowingTagPicker = false

    private let currentAvatarURL: String?
    private let initialBirthYear: Int?

    init(
        profile: UserProfile,
        repository: ProfileUserRepository,
        onSaved: @escaping (UserProfile) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel(repository: repository))
        self.repository = repository
        self.onSaved = onSaved
        self.currentAvatarURL = profile.avatarURL
        self.initialBirthYear = profile.birthYear
        _displayName = State(initialValue: profile.displayName)
        _bio = State(initialValue: profile.bio)
        _selectedTags = State(initialValue: profile.tags)
        _isBirthDateKnown = State(initialValue: profile.birthYear != nil)
        _selectedBirthDate = State(initialValue: Self.date(forBirthYear: profile.birthYear))
        _isFollowersListPublic = State(initialValue: profile.isFollowersListPublic)
        _isFollowingListPublic = State(initialValue: profile.isFollowingListPublic)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if appState.accountEnforcementStatus.blocks(.profileUpdate) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LT("账号当前受限，无法修改资料", "Account restricted. Cannot edit profile.", "アカウントが制限中のため、プロフィールを編集できません。"))
                                .font(.subheadline.weight(.semibold))
                            Text(appState.accountEnforcementStatus.restrictionSummary)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }

                if let error = viewModel.error, !error.isEmpty {
                    FormStatusMessage(message: error, style: .error)
                }

                VStack(spacing: 12) {
                    avatarPreview

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(LT("更换头像", "Change Avatar", "アバターを変更"), systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.accountEnforcementStatus.blocks(.mediaUpload))
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text(LT("昵称", "Nickname", "ニックネーム"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField(LT("请输入昵称", "Enter a nickname", "ニックネームを入力"), text: $displayName)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LT("签名", "Bio", "自己紹介"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextEditor(text: $bio)
                        .frame(minHeight: 120)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LT("出生日期", "Date of Birth", "生年月日"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Toggle(
                        LT("已填写出生日期", "Birth date provided", "生年月日を入力済み"),
                        isOn: $isBirthDateKnown
                    )
                    .tint(RaverTheme.accent)

                    if isBirthDateKnown {
                        DatePicker(
                            "",
                            selection: $selectedBirthDate,
                            in: birthDateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Text(LT("历史未填写出生信息的用户可以暂时留空。填写后会用于年龄分级与功能限制判断。", "Users with no birth date on record can leave this blank for now. Once provided, it will be used for age gating and safety limits.", "これまで生年月日未設定のユーザーは空欄のままでも構いません。入力後は年齢区分と機能制限に使用されます。"))
                            .font(.footnote)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .padding(12)
                            .background(RaverTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LT("Tag", "Tags", "タグ"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Button {
                        isShowingTagPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "tag")
                                .font(.system(size: 14, weight: .semibold))
                            Text(selectedTagsSummary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .font(.subheadline)
                        .foregroundStyle(selectedTags.isEmpty ? RaverTheme.secondaryText : RaverTheme.primaryText)
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(LT("保存", "Save", "保存"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving || appState.accountEnforcementStatus.blocks(.profileUpdate))
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .raverSystemNavigation(title: LT("编辑资料", "Edit Profile", "プロフィール編集"))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LT("收起", "Dismiss", "閉じる")) {
                    dismissKeyboard()
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            guard !appState.accountEnforcementStatus.blocks(.mediaUpload) else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await applyPickedAvatarData(data)
                }
            }
        }
        .task {
            await loadGenreTagsIfNeeded()
        }
        .sheet(isPresented: $isShowingTagPicker) {
            GenreTagPickerSheet(
                tags: availableGenreTags,
                selectedTags: $selectedTags,
                searchText: $tagSearchText,
                isLoading: isLoadingGenreTags
            )
        }
    }

    private static func preparedAvatarData(from data: Data) -> Data {
        guard
            let image = UIImage(data: data),
            let resized = image.resizedForProfileAvatar(maxPixel: 512),
            let jpegData = resized.jpegData(compressionQuality: 0.78)
        else {
            return data
        }
        return jpegData
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
    private var avatarPreview: some View {
        if let pendingAvatarData,
           let image = UIImage(data: pendingAvatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
        } else if let resolved = AppConfig.resolvedURLString(currentAvatarURL),
                  URL(string: resolved) != nil,
                  resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(AvatarPlaceholderView(size: 88, backgroundColor: RaverTheme.card))
            .frame(width: 88, height: 88)
            .clipShape(Circle())
        } else {
            AvatarPlaceholderView(size: 88, backgroundColor: RaverTheme.card)
        }
    }

    @MainActor
    private func applyPickedAvatarData(_ data: Data) async {
        let prepared = Self.preparedAvatarData(from: data)
        pendingAvatarData = prepared
        guard let userId = appState.session?.user.id else { return }
        do {
            let localURL = try LocalProfileAvatarCache.save(imageData: prepared, userId: userId)
            let localAvatarURL = localURL.absoluteString
            appState.updateCurrentUserAvatarURL(localAvatarURL)
            if let snapshot = appState.currentUserProfileSnapshot(avatarURL: localAvatarURL) {
                NotificationCenter.default.post(name: .profileDidUpdate, object: snapshot)
            }
            Task {
                await uploadAvatarInBackground(prepared)
            }
        } catch {
            viewModel.error = error.userFacingMessage
        }
    }

    private func uploadAvatarInBackground(_ avatarData: Data) async {
        do {
            let uploaded = try await repository.uploadMyAvatar(
                imageData: avatarData,
                fileName: "avatar.jpg",
                mimeType: "image/jpeg"
            )
            await MainActor.run {
                appState.updateCurrentUserAvatarURL(uploaded.avatarURL)
                if let snapshot = appState.currentUserProfileSnapshot(avatarURL: uploaded.avatarURL) {
                    NotificationCenter.default.post(name: .profileDidUpdate, object: snapshot)
                }
            }
        } catch {
            await MainActor.run {
                viewModel.error = LT("头像正在本地显示，上传失败后可稍后重试。", "Your avatar is shown locally. Upload failed; please retry later.", "アイコンはローカル表示中です。アップロードに失敗したため後でもう一度お試しください。")
            }
        }
    }

    @MainActor
    private func save() async {
        guard !appState.accountEnforcementStatus.blocks(.profileUpdate) else {
            viewModel.error = appState.accountEnforcementStatus.restrictionSummary
            return
        }
        if var updated = await viewModel.saveProfile(
            displayName: displayName,
            bio: bio,
            birthYear: normalizedBirthYear,
            tags: selectedTags,
            isFollowersListPublic: isFollowersListPublic,
            isFollowingListPublic: isFollowingListPublic
        ) {
            if let currentAvatarURL = appState.session?.user.avatarURL,
               URL(string: currentAvatarURL)?.isFileURL == true {
                updated.avatarURL = currentAvatarURL
            }
            updated.birthYear = normalizedBirthYear
            appState.applyCurrentUserProfile(updated)
            onSaved(updated)
            dismiss()
        }
    }

    @MainActor
    private func loadGenreTagsIfNeeded() async {
        guard availableGenreTags.isEmpty, !isLoadingGenreTags else { return }
        isLoadingGenreTags = true
        defer { isLoadingGenreTags = false }

        do {
            let nodes = try await appContainer.webService.fetchLearnGenres()
            availableGenreTags = Self.flattenGenreTags(nodes)
            selectedTags = selectedTags.filter { availableGenreTags.contains($0) }
        } catch {
            viewModel.error = error.userFacingMessage ?? LT("流派标签加载失败，请稍后重试。", "Failed to load genre tags. Please try again.", "ジャンルタグの読み込みに失敗しました。後でもう一度お試しください。")
        }
    }

    private static func flattenGenreTags(_ nodes: [LearnGenreNode]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        func visit(_ node: LearnGenreNode) {
            let name = node.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, seen.insert(name.lowercased()).inserted {
                result.append(name)
            }
            node.children?.forEach(visit)
        }

        nodes.forEach(visit)
        return result
    }

    private var normalizedBirthYear: Int? {
        guard isBirthDateKnown else { return nil }
        return Calendar.current.component(.year, from: selectedBirthDate)
    }

    private var selectedTagsSummary: String {
        if selectedTags.isEmpty {
            return LT("管理并添加流派 Tag", "Manage and add genre tags", "ジャンルタグを管理・追加")
        }
        return selectedTags.joined(separator: " / ")
    }

    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        let maxDate = calendar.date(byAdding: .year, value: -13, to: now) ?? now
        let minDate = calendar.date(byAdding: .year, value: -100, to: now) ?? now
        return minDate...maxDate
    }

    private static func date(forBirthYear birthYear: Int?) -> Date {
        let calendar = Calendar.current
        if let birthYear,
           let date = calendar.date(from: DateComponents(year: birthYear, month: 7, day: 1)) {
            return date
        }
        return calendar.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }
}

private struct GenreTagPickerSheet: View {
    let tags: [String]
    @Binding var selectedTags: [String]
    @Binding var searchText: String
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss

    private var filteredTags: [String] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return tags }
        return tags.filter { $0.localizedCaseInsensitiveContains(keyword) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(LT("当前已选择", "Selected Tags", "現在選択中")) {
                    if selectedTags.isEmpty {
                        Text(LT("还没有添加任何流派 Tag", "No genre tags added yet", "ジャンルタグはまだ追加されていません"))
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        ForEach(selectedTags, id: \.self) { tag in
                            HStack(spacing: 12) {
                                Text(tag)
                                    .foregroundStyle(RaverTheme.primaryText)
                                Spacer()
                                Button(role: .destructive) {
                                    remove(tag)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(Color.red)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section(LT("添加 Tag", "Add Tags", "タグを追加")) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if filteredTags.isEmpty {
                        Text(LT("没有匹配的流派标签", "No matching genre tags", "一致するジャンルタグがありません"))
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        ForEach(filteredTags.filter { !selectedTags.contains($0) }, id: \.self) { tag in
                            Button {
                                add(tag)
                            } label: {
                                HStack {
                                    Text(tag)
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(RaverTheme.accent)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: LT("搜索流派 Tag", "Search genre tags", "ジャンルタグを検索"))
            .scrollContentBackground(.hidden)
            .background(RaverTheme.background)
            .navigationTitle(LT("管理 Tag", "Manage Tags", "タグを管理"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("完成", "Done", "完了")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func add(_ tag: String) {
        guard !selectedTags.contains(tag) else { return }
        selectedTags.append(tag)
    }

    private func remove(_ tag: String) {
        selectedTags.removeAll { $0 == tag }
    }
}
