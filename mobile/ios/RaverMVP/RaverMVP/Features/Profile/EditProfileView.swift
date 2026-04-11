import SwiftUI
import PhotosUI
import UIKit

struct SaveProfileUseCase {
    private let repository: ProfileSocialRepository

    init(repository: ProfileSocialRepository) {
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

    init(repository: ProfileSocialRepository) {
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

    @StateObject private var viewModel: EditProfileViewModel
    private let onSaved: (UserProfile) -> Void

    @State private var displayName: String
    @State private var bio: String
    @State private var tagsText: String
    @State private var isFollowersListPublic: Bool
    @State private var isFollowingListPublic: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarData: Data?

    private let currentAvatarAsset: String
    private let currentAvatarURL: String?

    init(
        profile: UserProfile,
        repository: ProfileSocialRepository,
        onSaved: @escaping (UserProfile) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel(repository: repository))
        self.onSaved = onSaved
        self.currentAvatarAsset = AppConfig.resolvedUserAvatarAssetName(
            userID: profile.id,
            username: profile.username,
            avatarURL: profile.avatarURL
        )
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
                VStack(spacing: 12) {
                    avatarPreview

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(LL("更换头像"), systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text(LL("昵称"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField(LL("请输入昵称"), text: $displayName)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LL("签名"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextEditor(text: $bio)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LL("Tag（逗号分隔）"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField(LL("如: Techno, House"), text: $tagsText)
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
                        Toggle(LL("允许他人查看我的粉丝列表"), isOn: $isFollowersListPublic)
                        Toggle(LL("允许他人查看我的关注列表"), isOn: $isFollowingListPublic)
                    }
                }

                Button {
                    Task { await save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(L("保存", "Save"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L("编辑资料", "Edit Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Dismiss")) {
                    dismissKeyboard()
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    pendingAvatarData = data
                }
            }
        }
        .alert(L("保存失败", "Save Failed"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
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
                .background(
                    Image(currentAvatarAsset)
                        .resizable()
                        .scaledToFill()
                        .background(RaverTheme.card)
                )
            .frame(width: 88, height: 88)
            .clipShape(Circle())
        } else {
            Image(currentAvatarAsset)
                .resizable()
                .scaledToFill()
                .background(RaverTheme.card)
                .frame(width: 88, height: 88)
                .clipShape(Circle())
        }
    }

    @MainActor
    private func save() async {
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
