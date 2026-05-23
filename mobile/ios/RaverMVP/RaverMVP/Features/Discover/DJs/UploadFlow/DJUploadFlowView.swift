import SwiftUI
import PhotosUI

struct DJUploadFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DJUploadFlowViewModel
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?
    @State private var proofItem: PhotosPickerItem?
    @State private var showDiscardAlert = false

    init(
        mode: DJUploadMode,
        initialDJ: WebDJ? = nil,
        userID: String,
        importRepository: DJImportRepository,
        commandRepository: DJCommandRepository,
        mediaRepository: DJMediaRepository,
        onCompleted: ((WebDJ?) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: DJUploadFlowViewModel(
            mode: mode,
            initialDJ: initialDJ,
            userID: userID,
            importRepository: importRepository,
            commandRepository: commandRepository,
            mediaRepository: mediaRepository,
            onCompleted: onCompleted
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stepContent
                }
                .padding(16)
                .padding(.bottom, 96)
            }
            bottomBar
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LT("关闭", "Close", "閉じる")) {
                    if viewModel.draft.dirty {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .alert(LT("继续 DJ 草稿？", "Continue DJ draft?", "DJ下書きを続けますか？"), isPresented: Binding(
            get: { viewModel.pendingRestoreDraft != nil },
            set: { if !$0 { viewModel.pendingRestoreDraft = nil } }
        )) {
            Button(LT("继续草稿", "Continue Draft", "下書きを続ける")) {
                viewModel.restoreDraft()
            }
            Button(LT("重新开始", "Start Over", "最初から"), role: .destructive) {
                Task { await viewModel.discardRestoreDraft() }
            }
        } message: {
            Text(LT("检测到上次未提交的 DJ 草稿。重新开始会删除草稿中已上传但未提交的 OSS 图片。", "An unsent DJ draft was found. Starting over will delete uploaded draft images from OSS.", "未送信のDJ下書きがあります。最初から始めると下書き画像はOSSから削除されます。"))
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(LT("保存草稿并退出？", "Save draft and exit?", "下書きを保存して閉じますか？"), isPresented: $showDiscardAlert) {
            Button(LT("保存退出", "Save and Exit", "保存して閉じる")) {
                viewModel.saveDraft()
                dismiss()
            }
            Button(LT("继续编辑", "Keep Editing", "編集を続ける"), role: .cancel) {}
        } message: {
            Text(LT("未提交内容会保存在本地草稿中，下次进入会询问是否继续。", "Unsubmitted changes will be saved as a local draft.", "未送信の内容はローカル下書きとして保存されます。"))
        }
        .onChange(of: avatarItem) { _, item in Task { await loadPhoto(item, zone: .avatar) } }
        .onChange(of: bannerItem) { _, item in Task { await loadPhoto(item, zone: .banner) } }
        .onChange(of: proofItem) { _, item in Task { await loadPhoto(item, zone: .proof) } }
        .onChange(of: viewModel.successMessage) { _, message in
            if message != nil { dismiss() }
        }
    }

    private var navigationTitle: String {
        viewModel.draft.isCreate
            ? LT("上传 DJ", "Upload DJ", "DJをアップロード")
            : LT("编辑 DJ", "Edit DJ", "DJを編集")
    }

    private var progressHeader: some View {
        HStack(spacing: 8) {
            ForEach(DJUploadStep.allCases) { step in
                VStack(spacing: 6) {
                    Circle()
                        .fill(step == viewModel.draft.currentStep ? RaverTheme.accent : RaverTheme.card)
                        .frame(width: 10, height: 10)
                    Text(step.title)
                        .font(.caption2.weight(step == viewModel.draft.currentStep ? .bold : .regular))
                        .foregroundStyle(step == viewModel.draft.currentStep ? RaverTheme.primaryText : RaverTheme.secondaryText)
                }
                if step != DJUploadStep.allCases.last {
                    Rectangle()
                        .fill(RaverTheme.card)
                        .frame(height: 1)
                }
            }
        }
        .padding(16)
        .background(RaverTheme.background)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.draft.currentStep {
        case .identity:
            identityStep
        case .profile:
            profileStep
        case .links:
            linksStep
        case .review:
            reviewStep
        }
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(LT("DJ 身份", "DJ Identity", "DJ本人確認"))
            languagePicker
            TextField(LT("DJ 名称", "DJ Name", "DJ名"), text: localizedBinding(\.name))
                .textFieldStyle(.roundedBorder)
            imagePickerCard(zone: .avatar, item: $avatarItem, required: true)
            imagePickerCard(zone: .banner, item: $bannerItem, required: false)
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(LT("资料信息", "Profile Info", "プロフィール情報"))
            TextField(LT("别名，用逗号分隔", "Aliases, comma separated", "別名、カンマ区切り"), text: textBinding(\.aliasesText))
                .textFieldStyle(.roundedBorder)
            TextField(LT("Genres，用逗号分隔", "Genres, comma separated", "ジャンル、カンマ区切り"), text: textBinding(\.genresText))
                .textFieldStyle(.roundedBorder)
            TextField(LT("国家/地区", "Country/Region", "国/地域"), text: localizedBinding(\.country))
                .textFieldStyle(.roundedBorder)
            TextField(LT("简介", "Bio", "紹介"), text: localizedBinding(\.bio), axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var linksStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(LT("平台链接", "Platform Links", "プラットフォームリンク"))
            linkField("Spotify ID", \.spotifyId)
            linkField("Spotify URL", \.spotifyUrl)
            statField(LT("Spotify 粉丝数", "Spotify Followers", "Spotifyフォロワー数"), \.spotifyFollowers)
            linkField("Apple Music ID", \.appleMusicId)
            linkField("Instagram URL", \.instagramUrl)
            linkField("Facebook URL", \.facebookUrl)
            linkField("SoundCloud URL", \.soundcloudUrl)
            linkField("SoundCloud ID", \.soundcloudId)
            linkField("X/Twitter URL", \.twitterUrl)
            linkField("YouTube URL", \.youtubeUrl)
            linkField("NetEase URL", \.neteaseUrl)
            linkField("QQ Music URL", \.qqMusicUrl)
            linkField("Website", \.website)
            linkField(LT("Other 平台链接", "Other Platform URL", "その他リンク"), \.otherPlatformUrl)
            sectionTitle(LT("平台数据", "Platform Stats", "プラットフォーム統計"))
            statField(LT("曲目数", "Track Count", "トラック数"), \.trackCount)
            statField(LT("歌单数", "Playlist Count", "プレイリスト数"), \.playlistCount)
            statField(LT("SoundCloud 粉丝数", "SoundCloud Followers", "SoundCloudフォロワー数"), \.soundCloudFollowers)
            statField(LT("SoundCloud 收藏数", "SoundCloud Favorites", "SoundCloudお気に入り数"), \.soundCloudFavorites)
            Text(LT("如果没有任何平台链接，需要上传一张证明身份的图片。", "If no platform links are available, upload one proof image.", "リンクがない場合は証明画像を1枚アップロードしてください。"))
                .font(.footnote)
                .foregroundStyle(RaverTheme.secondaryText)
            imagePickerCard(zone: .proof, item: $proofItem, required: false)
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(LT("提交检查", "Review", "確認"))
            reviewRow(LT("名称", "Name", "名前"), viewModel.draft.primaryName)
            reviewRow(LT("头像", "Avatar", "アバター"), viewModel.draft.avatar == nil ? LT("未上传", "Missing", "未設定") : LT("已上传 OSS", "Uploaded to OSS", "OSSアップロード済み"))
            reviewRow(LT("平台链接", "Platform Links", "リンク"), viewModel.draft.hasPlatformLink ? LT("已填写", "Provided", "入力済み") : LT("未填写", "None", "なし"))
            reviewRow(LT("证明图片", "Proof Image", "証明画像"), viewModel.draft.proofImage == nil ? LT("未上传", "Not uploaded", "未設定") : LT("已上传 OSS", "Uploaded to OSS", "OSSアップロード済み"))
            ForEach(DJUploadValidation.issues(for: viewModel.draft)) { issue in
                Text(issue.message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var languagePicker: some View {
        Picker(LT("当前语言", "Language", "言語"), selection: Binding(
            get: { viewModel.draft.preferredLanguage },
            set: {
                viewModel.draft.preferredLanguage = $0
                viewModel.markDirty()
                viewModel.saveDraft()
            }
        )) {
            Text("中文").tag(EventUploadPreferredLanguage.zh)
            Text("English").tag(EventUploadPreferredLanguage.en)
            Text("日本語").tag(EventUploadPreferredLanguage.ja)
        }
        .pickerStyle(.segmented)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(LT("上一步", "Back", "戻る")) {
                viewModel.goBack()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.draft.currentStep.previous == nil || viewModel.isSubmitting)

            Button(viewModel.draft.currentStep == .review ? submitTitle : LT("下一步", "Next", "次へ")) {
                if viewModel.draft.currentStep == .review {
                    Task { await viewModel.submit() }
                } else {
                    viewModel.goNext()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSubmitting || !viewModel.uploadingZones.isEmpty)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var submitTitle: String {
        if viewModel.isSubmitting {
            return LT("提交中...", "Submitting...", "送信中...")
        }
        return viewModel.draft.isCreate
            ? LT("提交审核", "Submit for Review", "審査に送信")
            : LT("保存修改", "Save Changes", "変更を保存")
    }

    private func imagePickerCard(zone: DJUploadImageZone, item: Binding<PhotosPickerItem?>, required: Bool) -> some View {
        let image = viewModel.draft.image(for: zone)
        let isUploading = viewModel.uploadingZones.contains(zone)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(required ? "\(zone.title) *" : zone.title)
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                PhotosPicker(selection: item, matching: .images) {
                    Label(image == nil ? LT("上传", "Upload", "アップロード") : LT("更换", "Replace", "変更"), systemImage: "photo")
                }
                .buttonStyle(.bordered)
            }

            ZStack {
                if let image, let resolved = AppConfig.resolvedURLString(image.remoteURL) {
                    ImageLoaderView(urlString: resolved)
                        .frame(height: zone == .avatar ? 148 : 108)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(RaverTheme.card)
                        .frame(height: zone == .avatar ? 148 : 108)
                        .overlay {
                            Image(systemName: zone == .avatar ? "person.crop.circle" : "photo")
                                .font(.largeTitle)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                }

                if isUploading {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }

            if image != nil && zone != .avatar {
                Button(role: .destructive) {
                    Task { await viewModel.removeImage(zone: zone) }
                } label: {
                    Label(LT("删除图片", "Delete Image", "画像を削除"), systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(RaverTheme.primaryText)
    }

    private func linkField(_ title: String, _ keyPath: WritableKeyPath<DJUploadDraft, String>) -> some View {
        TextField(title, text: textBinding(keyPath))
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textFieldStyle(.roundedBorder)
    }

    private func statField(_ title: String, _ keyPath: WritableKeyPath<DJUploadDraft, String>) -> some View {
        TextField(title, text: textBinding(keyPath))
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(RaverTheme.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(RaverTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func textBinding(_ keyPath: WritableKeyPath<DJUploadDraft, String>) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath]
        } set: { value in
            viewModel.draft[keyPath: keyPath] = value
            viewModel.markDirty()
        }
    }

    private func localizedBinding(_ keyPath: WritableKeyPath<DJUploadDraft, EventUploadLocalizedFields>) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].currentValue(preferredLanguage: viewModel.draft.preferredLanguage)
        } set: { value in
            viewModel.draft[keyPath: keyPath].setCurrentValue(value, preferredLanguage: viewModel.draft.preferredLanguage)
            viewModel.markDirty()
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?, zone: DJUploadImageZone) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await viewModel.uploadImage(data, zone: zone)
            }
        } catch {
            viewModel.errorMessage = error.userFacingMessage ?? LT("图片读取失败", "Failed to read image", "画像を読み込めませんでした")
        }
    }
}
