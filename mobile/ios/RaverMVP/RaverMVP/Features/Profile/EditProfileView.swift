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
        tagsText: String,
        isFollowersListPublic: Bool,
        isFollowingListPublic: Bool,
        pendingAvatarData: Data?
    ) async throws -> UserProfile {
        if let data = pendingAvatarData {
            _ = try await repository.uploadMyAvatar(
                imageData: data,
                fileName: "avatar.jpg",
                mimeType: "image/jpeg"
            )
        }

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return try await repository.updateMyProfile(input: UpdateMyProfileInput(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
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
        tagsText: String,
        isFollowersListPublic: Bool,
        isFollowingListPublic: Bool,
        pendingAvatarData: Data?
    ) async -> UserProfile? {
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await saveProfileUseCase.execute(
                displayName: displayName,
                bio: bio,
                tagsText: tagsText,
                isFollowersListPublic: isFollowersListPublic,
                isFollowingListPublic: isFollowingListPublic,
                pendingAvatarData: pendingAvatarData
            )
            error = nil
            return updated
        } catch {
            self.error = error.userFacingMessage
            return nil
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel: EditProfileViewModel
    private let onSaved: (UserProfile) -> Void

    @State private var displayName: String
    @State private var bio: String
    @State private var tagsText: String
    @State private var isFollowersListPublic: Bool
    @State private var isFollowingListPublic: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarData: Data?

    private let currentAvatarURL: String?

    init(
        profile: UserProfile,
        repository: ProfileUserRepository,
        onSaved: @escaping (UserProfile) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel(repository: repository))
        self.onSaved = onSaved
        self.currentAvatarURL = profile.avatarURL
        _displayName = State(initialValue: profile.displayName)
        _bio = State(initialValue: profile.bio)
        _tagsText = State(initialValue: profile.tags.joined(separator: ", "))
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
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LT("Tag（逗号分隔）", "Tags (comma separated)", "タグ（カンマ区切り）"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField(LT("如: Techno, House", "e.g. Techno, House", "例: Techno, House"), text: $tagsText)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(LT("允许他人查看我的粉丝列表", "Allow others to see my followers", "他の人にフォロワー一覧を表示する"), isOn: $isFollowersListPublic)
                        Toggle(LT("允许他人查看我的关注列表", "Allow others to see who I follow", "他の人にフォロー一覧を表示する"), isOn: $isFollowingListPublic)
                    }
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
                    pendingAvatarData = data
                }
            }
        }
        .alert(LT("保存失败", "Save Failed", "保存に失敗しました"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
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
    private func save() async {
        guard !appState.accountEnforcementStatus.blocks(.profileUpdate) else {
            viewModel.error = appState.accountEnforcementStatus.restrictionSummary
            return
        }
        if let updated = await viewModel.saveProfile(
            displayName: displayName,
            bio: bio,
            tagsText: tagsText,
            isFollowersListPublic: isFollowersListPublic,
            isFollowingListPublic: isFollowingListPublic,
            pendingAvatarData: pendingAvatarData
        ) {
            onSaved(updated)
            dismiss()
        }
    }
}
