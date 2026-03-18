import SwiftUI
import PhotosUI
import UIKit

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    private let service: SocialService
    private let onSaved: (UserProfile) -> Void

    @State private var displayName: String
    @State private var bio: String
    @State private var tagsText: String
    @State private var isFollowersListPublic: Bool
    @State private var isFollowingListPublic: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarData: Data?
    @State private var isSaving = false
    @State private var error: String?

    private let currentAvatarURL: String?

    init(profile: UserProfile, onSaved: @escaping (UserProfile) -> Void) {
        self.service = AppEnvironment.makeService()
        self.onSaved = onSaved
        self.currentAvatarURL = AppConfig.resolvedURLString(profile.avatarURL)
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
                        Label("更换头像", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("昵称")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField("请输入昵称", text: $displayName)
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("签名")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextEditor(text: $bio)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag（逗号分隔）")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    TextField("如: Techno, House", text: $tagsText)
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("允许他人查看我的粉丝列表", isOn: $isFollowersListPublic)
                        Toggle("允许他人查看我的关注列表", isOn: $isFollowingListPublic)
                    }
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("保存")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    pendingAvatarData = data
                }
            }
        }
        .alert("保存失败", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
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
        } else if let currentAvatarURL, !currentAvatarURL.isEmpty {
            AsyncImage(url: URL(string: currentAvatarURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Circle().fill(RaverTheme.card)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.card)
                .frame(width: 88, height: 88)
                .overlay(Image(systemName: "person.fill").foregroundStyle(RaverTheme.secondaryText))
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            if let data = pendingAvatarData {
                _ = try await service.uploadMyAvatar(imageData: data, fileName: "avatar.jpg", mimeType: "image/jpeg")
            }

            let tags = tagsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let updated = try await service.updateMyProfile(input: UpdateMyProfileInput(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: tags,
                isFollowersListPublic: isFollowersListPublic,
                isFollowingListPublic: isFollowingListPublic
            ))

            onSaved(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
