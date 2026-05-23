import SwiftUI
import PhotosUI

struct DJUploadFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DJUploadFlowViewModel
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?
    @State private var proofItem: PhotosPickerItem?
    @State private var showDiscardAlert = false
    @State private var expandedLocalizedFieldKeys: Set<String> = []

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
        VStack(alignment: .leading, spacing: 12) {
            Text("\(currentStepIndex + 1)/\(DJUploadStep.allCases.count) · \(viewModel.draft.currentStep.title)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            HStack(spacing: 6) {
                ForEach(DJUploadStep.allCases) { step in
                    Capsule()
                        .fill(progressFillColor(for: step))
                        .frame(height: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
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
            sectionTitle(
                LT("DJ 身份", "DJ Identity", "DJ本人確認"),
                subtitle: LT("先确认 DJ 名称与基础图片，确保资料入口清晰完整。", "Start with the DJ name and core media so the profile reads clearly.", "まずDJ名と基本画像を整えて、プロフィールの入口を明確にします。")
            )
            preferredLanguageSection
            DJLocalizedExpandableFieldSection(
                title: LT("DJ 名称", "DJ Name", "DJ名"),
                isRequired: true,
                axis: .horizontal,
                includeEnglishFull: false,
                expanded: localizedExpansionBinding(for: "dj-name"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("DJ 名称", "DJ Name", "DJ名")),
                primaryBinding: localizedBinding(\.name),
                zhBinding: localizedBinding(\.name, language: .zh),
                enBinding: localizedBinding(\.name, language: .en),
                jaBinding: localizedBinding(\.name, language: .ja),
                englishFullBinding: nil,
                extraCount: viewModel.draft.name.secondaryValueCount(excluding: viewModel.draft.preferredLanguage),
                preferredLanguage: viewModel.draft.preferredLanguage
            )
            imagePickerCard(zone: .avatar, item: $avatarItem, required: true)
            imagePickerCard(zone: .banner, item: $bannerItem, required: false)
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("资料信息", "Profile Info", "プロフィール情報"),
                subtitle: LT("补充别名、风格、国家和简介，让 DJ 资料页更完整。", "Add aliases, genres, country, and bio to complete the profile.", "別名、ジャンル、国、紹介を補ってプロフィールを整えます。")
            )
            stringListSection(
                title: LT("别名", "Aliases", "別名"),
                subtitle: LT("用 + 添加多个别名，每一项单独填写。", "Add aliases with + and fill each item separately.", "+ で別名を追加し、1項目ずつ入力します。"),
                items: arrayBinding(\.aliases),
                placeholder: LT("输入别名", "Enter alias", "別名を入力")
            )
            stringListSection(
                title: LT("Genres", "Genres", "ジャンル"),
                subtitle: LT("用 + 添加多个风格标签，不需要手动输入逗号。", "Add genre tags with + instead of typing commas.", "+ でジャンルタグを追加できます。"),
                items: arrayBinding(\.genres),
                placeholder: LT("输入 Genre", "Enter genre", "ジャンルを入力")
            )
            DJLocalizedExpandableFieldSection(
                title: LT("国家/地区", "Country/Region", "国/地域"),
                isRequired: false,
                axis: .horizontal,
                includeEnglishFull: true,
                expanded: localizedExpansionBinding(for: "dj-country"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("国家/地区", "Country/Region", "国/地域")),
                primaryBinding: localizedBinding(\.country),
                zhBinding: localizedBinding(\.country, language: .zh),
                enBinding: localizedBinding(\.country, language: .en),
                jaBinding: localizedBinding(\.country, language: .ja),
                englishFullBinding: localizedEnglishFullBinding(\.country),
                extraCount: viewModel.draft.country.secondaryValueCount(excluding: viewModel.draft.preferredLanguage, includeEnglishFull: true),
                preferredLanguage: viewModel.draft.preferredLanguage
            )
            DJLocalizedExpandableFieldSection(
                title: LT("简介", "Bio", "紹介"),
                isRequired: false,
                axis: .vertical,
                includeEnglishFull: false,
                expanded: localizedExpansionBinding(for: "dj-bio"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("简介", "Bio", "紹介")),
                primaryBinding: localizedBinding(\.bio),
                zhBinding: localizedBinding(\.bio, language: .zh),
                enBinding: localizedBinding(\.bio, language: .en),
                jaBinding: localizedBinding(\.bio, language: .ja),
                englishFullBinding: nil,
                extraCount: viewModel.draft.bio.secondaryValueCount(excluding: viewModel.draft.preferredLanguage),
                preferredLanguage: viewModel.draft.preferredLanguage
            )
        }
    }

    private var linksStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("平台链接", "Platform Links", "プラットフォームリンク"),
                subtitle: LT("尽量补齐官方平台入口和关键数据，没有链接时可用证明图片补充。", "Add official platform links and stats where possible. Use a proof image if no links are available.", "公式リンクや主要データを補い、リンクがない場合は証明画像で補足します。")
            )
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
            sectionTitle(
                LT("平台数据", "Platform Stats", "プラットフォーム統計"),
                subtitle: LT("这些数字不是必填，但有的话会让资料可信度更高。", "These stats are optional, but they make the profile feel more complete.", "必須ではありませんが、数値があるとプロフィールの完成度が上がります。")
            )
            statField(LT("曲目数", "Track Count", "トラック数"), \.trackCount)
            statField(LT("歌单数", "Playlist Count", "プレイリスト数"), \.playlistCount)
            statField(LT("SoundCloud 粉丝数", "SoundCloud Followers", "SoundCloudフォロワー数"), \.soundCloudFollowers)
            statField(LT("SoundCloud 收藏数", "SoundCloud Favorites", "SoundCloudお気に入り数"), \.soundCloudFavorites)
            inlineInfoCard(LT("如果没有任何平台链接，需要上传一张证明身份的图片。", "If no platform links are available, upload one proof image.", "リンクがない場合は証明画像を1枚アップロードしてください。"))
            imagePickerCard(zone: .proof, item: $proofItem, required: false)
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("提交检查", "Review", "確認"),
                subtitle: LT("最后确认关键信息，提交后会进入审核或直接保存。", "Check the key details one last time before submitting.", "最後に重要な情報を確認してから送信します。")
            )
            reviewRow(LT("名称", "Name", "名前"), viewModel.draft.primaryName)
            if !viewModel.draft.aliases.isEmpty {
                reviewRow(LT("别名", "Aliases", "別名"), viewModel.draft.aliases.joined(separator: " · "))
            }
            if !viewModel.draft.genres.isEmpty {
                reviewRow("Genres", viewModel.draft.genres.joined(separator: " · "))
            }
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

    private var preferredLanguageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(LT("当前语言", "Language", "言語"), isRequired: false)
            languagePicker
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var bottomBar: some View {
        EventUploadBottomBar(
            canGoBack: viewModel.draft.currentStep.previous != nil,
            isFinalStep: viewModel.draft.currentStep == .review,
            isBusy: viewModel.isSubmitting || !viewModel.uploadingZones.isEmpty,
            onBack: viewModel.goBack,
            onNext: {
                if viewModel.draft.currentStep == .review {
                    Task { await viewModel.submit() }
                } else {
                    viewModel.goNext()
                }
            }
        )
    }

    private func imagePickerCard(zone: DJUploadImageZone, item: Binding<PhotosPickerItem?>, required: Bool) -> some View {
        let image = viewModel.draft.image(for: zone)
        let isUploading = viewModel.uploadingZones.contains(zone)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(zone.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(RaverTheme.primaryText)
                        if required {
                            Text("*")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.red)
                        }
                    }
                    Text(zoneDescription(zone))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                Spacer()
                Text(image == nil ? LT("0 张", "0 images", "0枚") : LT("1 张", "1 image", "1枚"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RaverTheme.background, in: Capsule())
            }

            PhotosPicker(selection: item, matching: .images) {
                imageActionLabel(
                    title: image == nil ? LT("选择图片", "Choose Image", "画像を選択") : LT("更换图片", "Replace Image", "画像を変更"),
                    systemImage: zone == .avatar ? "person.crop.circle.badge.plus" : "photo.on.rectangle"
                )
            }
            .buttonStyle(.plain)

            ZStack {
                if let image, let resolved = AppConfig.resolvedURLString(image.remoteURL) {
                    ImageLoaderView(urlString: resolved)
                        .frame(height: zone == .avatar ? 160 : 118)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(RaverTheme.background)
                        .frame(height: zone == .avatar ? 160 : 118)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: zone == .avatar ? "person.crop.circle" : "photo")
                                    .font(.system(size: zone == .avatar ? 28 : 24, weight: .semibold))
                                    .foregroundStyle(RaverTheme.accent)
                                Text(LT("上传后会显示预览", "Preview appears after upload", "アップロード後にプレビュー表示"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
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
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var currentStepIndex: Int {
        DJUploadStep.allCases.firstIndex(of: viewModel.draft.currentStep) ?? 0
    }

    private func progressFillColor(for step: DJUploadStep) -> Color {
        let index = DJUploadStep.allCases.firstIndex(of: step) ?? 0
        return index <= currentStepIndex ? RaverTheme.accent : RaverTheme.cardBorder
    }

    private func zoneDescription(_ zone: DJUploadImageZone) -> String {
        switch zone {
        case .avatar:
            return LT("头像会作为 DJ 卡片主图展示。", "Avatar becomes the main DJ card image.", "アバターはDJカードのメイン画像になります。")
        case .banner:
            return LT("横幅图可用于资料页头图展示。", "Banner can be used as the profile header image.", "バナーはプロフィール上部の画像に使われます。")
        case .proof:
            return LT("没有平台链接时，可上传证明身份的图片。", "Add a proof image when no official link is available.", "公式リンクがない場合は証明画像を追加します。")
        }
    }

    private func imageActionLabel(title: String, systemImage: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(RaverTheme.background)
            .frame(height: 56)
            .overlay {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                }
            }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stringListSection(
        title: String,
        subtitle: String,
        items: Binding<[String]>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    fieldTitle(title, isRequired: false)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    var next = items.wrappedValue
                    next.append("")
                    items.wrappedValue = next
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text(LT("添加", "Add", "追加"))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(RaverTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RaverTheme.card, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(RaverTheme.accent.opacity(0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if items.wrappedValue.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                    Text(LT("还没有内容，点击右侧 Add 添加。", "Nothing added yet. Tap Add to create one.", "まだありません。右側の Add から追加できます。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(items.wrappedValue.indices), id: \.self) { index in
                        HStack(alignment: .bottom, spacing: 10) {
                            uploadTextField(
                                title: "\(title) \(index + 1)",
                                text: Binding(
                                    get: {
                                        items.wrappedValue.indices.contains(index) ? items.wrappedValue[index] : ""
                                    },
                                    set: { newValue in
                                        var next = items.wrappedValue
                                        guard next.indices.contains(index) else { return }
                                        next[index] = newValue
                                        items.wrappedValue = next
                                    }
                                ),
                                showTitle: false
                            )
                            Button(role: .destructive) {
                                var next = items.wrappedValue
                                guard next.indices.contains(index) else { return }
                                next.remove(at: index)
                                items.wrappedValue = next
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.red)
                                    .frame(width: 32, height: 32)
                                    .background(RaverTheme.background, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(RaverTheme.cardBorder, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func linkField(_ title: String, _ keyPath: WritableKeyPath<DJUploadDraft, String>) -> some View {
        uploadTextField(
            title: title,
            text: textBinding(keyPath),
            keyboardType: .URL
        )
    }

    private func statField(_ title: String, _ keyPath: WritableKeyPath<DJUploadDraft, String>) -> some View {
        uploadTextField(
            title: title,
            text: textBinding(keyPath),
            keyboardType: .numberPad
        )
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func uploadTextField(
        title: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        axis: Axis = .horizontal,
        showTitle: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTitle {
                fieldTitle(title, isRequired: false)
            }
            TextField(title, text: text, axis: axis)
                .keyboardType(keyboardType)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(axis == .vertical ? 5 : 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldTitle(_ title: String, isRequired: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            if isRequired {
                Text("*")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var fieldBackground: some ShapeStyle {
        RaverTheme.card
    }

    private func inlineInfoCard(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(RaverTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
            )
    }

    private func textBinding(_ keyPath: WritableKeyPath<DJUploadDraft, String>) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath]
        } set: { value in
            viewModel.draft[keyPath: keyPath] = value
            viewModel.markDirty()
        }
    }

    private func arrayBinding(_ keyPath: WritableKeyPath<DJUploadDraft, [String]>) -> Binding<[String]> {
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

    private func localizedBinding(
        _ keyPath: WritableKeyPath<DJUploadDraft, EventUploadLocalizedFields>,
        language: EventUploadPreferredLanguage
    ) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].value(for: language)
        } set: { value in
            viewModel.draft[keyPath: keyPath].setValue(value, for: language)
            viewModel.markDirty()
        }
    }

    private func localizedEnglishFullBinding(
        _ keyPath: WritableKeyPath<DJUploadDraft, EventUploadLocalizedFields>
    ) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].enFull
        } set: { value in
            viewModel.draft[keyPath: keyPath].enFull = value
            viewModel.markDirty()
        }
    }

    private func localizedPrimaryFieldPlaceholder(for title: String) -> String {
        switch viewModel.draft.preferredLanguage {
        case .zh:
            return LT("输入\(title)", "Enter \(title)", "\(title)を入力")
        case .en:
            return "Enter \(title)"
        case .ja:
            return "\(title)を入力"
        }
    }

    private func localizedExpansionBinding(for key: String) -> Binding<Bool> {
        Binding {
            expandedLocalizedFieldKeys.contains(key)
        } set: { expanded in
            if expanded {
                expandedLocalizedFieldKeys.insert(key)
            } else {
                expandedLocalizedFieldKeys.remove(key)
            }
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

private struct DJLocalizedExpandableFieldSection: View {
    let title: String
    let isRequired: Bool
    let axis: Axis
    let includeEnglishFull: Bool
    @Binding var expanded: Bool
    let primaryPlaceholder: String
    let primaryBinding: Binding<String>
    let zhBinding: Binding<String>
    let enBinding: Binding<String>
    let jaBinding: Binding<String>
    let englishFullBinding: Binding<String>?
    let extraCount: Int
    let preferredLanguage: EventUploadPreferredLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                headerTitle
                Spacer(minLength: 8)
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(expanded ? LT("收起", "Collapse", "閉じる") : LT("多语言", "Languages", "多言語"))
                            .font(.caption.weight(.semibold))
                        if extraCount > 0 {
                            Text("\(extraCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RaverTheme.accent, in: Capsule())
                        }
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(extraCount > 0 ? RaverTheme.accent : RaverTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RaverTheme.card, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(extraCount > 0 ? RaverTheme.accent.opacity(0.28) : RaverTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            TextField(primaryPlaceholder, text: primaryBinding, axis: axis)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(axis == .vertical ? 5 : 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(RaverTheme.card)

            if expanded {
                VStack(spacing: 10) {
                    languageRow(title: LT("中文", "Chinese", "中国語"), binding: zhBinding, isPrimary: preferredLanguage == .zh)
                    languageRow(title: "English", binding: enBinding, isPrimary: preferredLanguage == .en)
                    languageRow(title: LT("日文", "Japanese", "日本語"), binding: jaBinding, isPrimary: preferredLanguage == .ja)
                    if includeEnglishFull, let englishFullBinding {
                        languageRow(title: LT("国家英文全称", "Country Full Name", "国名フル英語"), binding: englishFullBinding, isPrimary: false)
                    }
                }
                .padding(12)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private var headerTitle: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            if isRequired {
                Text("*")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
            }
        }
    }

    private func languageRow(title: String, binding: Binding<String>, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                if isPrimary {
                    Text(LT("当前默认", "Default", "既定"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(RaverTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RaverTheme.accent.opacity(0.12), in: Capsule())
                }
            }

            TextField(title, text: binding, axis: axis)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(axis == .vertical ? 4 : 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
