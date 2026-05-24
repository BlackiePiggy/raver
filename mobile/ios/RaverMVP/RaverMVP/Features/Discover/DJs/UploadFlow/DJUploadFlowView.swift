import SwiftUI
import PhotosUI
import UIKit

struct DJUploadFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: DJUploadFlowViewModel
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?
    @State private var proofItem: PhotosPickerItem?
    @State private var showExitConfirmation = false
    @State private var expandedLocalizedFieldKeys: Set<String> = []
    @State private var keyboardCandidateSpacing: CGFloat = 0

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
        rootContent
        .background(RaverTheme.background.ignoresSafeArea())
        .raverSystemNavigation(title: navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if viewModel.draft.dirty && viewModel.submitSuccess == nil {
                        showExitConfirmation = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .onAppear {
            viewModel.setDismissAction { dismiss() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                viewModel.saveDraft()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) {
                keyboardCandidateSpacing = 132
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.18)) {
                keyboardCandidateSpacing = 0
            }
        }
        .onDisappear {
            viewModel.handleDisappear()
        }
        .alert(LT("继续上次草稿？", "Continue Draft?", "前回の下書きを続けますか？"), isPresented: $viewModel.shouldConfirmRestoredDraft) {
            Button(LT("重新开始", "Start Over", "最初から"), role: .destructive) {
                Task { await viewModel.restartCreateDraft() }
            }
            Button(LT("继续草稿", "Continue", "続ける"), role: .cancel) {
                viewModel.continueRestoredDraft()
            }
        } message: {
            Text(restoredDraftMessage)
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.statusMessage != nil },
            set: { if !$0 { viewModel.statusMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.statusMessage ?? "")
        }
        .confirmationDialog(
            LT("保留草稿？", "Keep Draft?", "下書きを残しますか？"),
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button(LT("保存草稿并离开", "Save Draft & Leave", "下書きを保存して離れる")) {
                viewModel.saveDraftAndClose()
            }
            Button(LT("放弃草稿", "Discard Draft", "下書きを破棄"), role: .destructive) {
                Task { await viewModel.discardDraftAndClose() }
            }
            Button(LT("继续编辑", "Keep Editing", "編集を続ける"), role: .cancel) {}
        } message: {
            Text(LT("未提交的内容会保存在本地草稿中。", "Unsubmitted changes can be kept as a local draft.", "未送信の内容はローカル下書きとして保存できます。"))
        }
        .onChange(of: avatarItem) { _, item in Task { await loadPhoto(item, zone: .avatar) } }
        .onChange(of: bannerItem) { _, item in Task { await loadPhoto(item, zone: .banner) } }
        .onChange(of: proofItem) { _, item in Task { await loadPhoto(item, zone: .proof) } }
    }

    @ViewBuilder
    private var rootContent: some View {
        VStack(spacing: 0) {
            if let success = viewModel.submitSuccess {
                successView(success)
            } else {
                editorContent
            }
        }
    }

    private var editorContent:                                                                                                                                                                                                                                                                                                                                                                  some View {
        VStack(spacing: 0) {
            progressHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stepContent
                }
                .padding(16)
                .padding(.bottom, 84 + keyboardCandidateSpacing)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: keyboardCandidateSpacing)
                    .allowsHitTesting(false)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            bottomBar
        }
    }

    private var navigationTitle: String {
        viewModel.draft.isCreate
            ? LT("上传 DJ", "Upload DJ", "DJをアップロード")
            : LT("编辑 DJ", "Edit DJ", "DJを編集")
    }

    private var restoredDraftMessage: String {
        if case .edit = viewModel.draft.mode {
            return LT("已恢复上次未提交的 DJ 编辑草稿。", "Your previous unsaved DJ edit draft was restored.", "前回の未保存DJ編集下書きを復元しました。")
        }
        return LT("已恢复上次未提交的新建 DJ 草稿。", "Your previous unsent DJ draft was restored.", "未送信のDJ下書きを復元しました。")
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

    private func successView(_ success: DJUploadSubmitSuccess) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(RaverTheme.accent.opacity(0.14))
                    .frame(width: 92, height: 92)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(RaverTheme.accent, in: Circle())
            }

            VStack(spacing: 10) {
                Text(success.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text(success.message)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button {
                    viewModel.closeAfterSuccess()
                } label: {
                    HStack {
                        Text(LT("返回 DJ 页", "Back to DJs", "DJページへ戻る"))
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Text(LT("之后也可以在我的发布里查看和管理。", "You can review and manage this later from My Posts.", "後からマイ投稿で確認・管理できます。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
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
        DJUploadLinkField(
            title: title,
            text: textBinding(keyPath),
            platform: DJUploadLinkPlatform(title: title)
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
            viewModel.statusMessage = error.userFacingMessage ?? LT("图片读取失败", "Failed to read image", "画像を読み込めませんでした")
        }
    }
}

private extension DJUploadFlowView {
    func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

private struct DJUploadLinkPlatform {
    private static let logoBaseURL = "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/logos"

    let shortTitle: String
    let color: Color
    let systemImage: String?
    let logoURL: String?

    init(title: String) {
        let normalized = title.lowercased()

        if normalized.contains("spotify") {
            shortTitle = "S"
            color = Color(red: 0.12, green: 0.74, blue: 0.32)
            systemImage = "music.note"
            logoURL = "\(Self.logoBaseURL)/spotify.webp"
        } else if normalized.contains("apple") {
            shortTitle = "AM"
            color = Color(red: 0.98, green: 0.24, blue: 0.35)
            systemImage = "music.note.list"
            logoURL = "\(Self.logoBaseURL)/applemusic.webp"
        } else if normalized.contains("instagram") {
            shortTitle = "IG"
            color = Color(red: 0.92, green: 0.24, blue: 0.58)
            systemImage = "camera.fill"
            logoURL = "\(Self.logoBaseURL)/instagram.webp"
        } else if normalized.contains("facebook") {
            shortTitle = "f"
            color = Color(red: 0.08, green: 0.34, blue: 0.78)
            systemImage = nil
            logoURL = "\(Self.logoBaseURL)/facebook.webp"
        } else if normalized.contains("soundcloud") {
            shortTitle = "SC"
            color = Color(red: 1.00, green: 0.42, blue: 0.08)
            systemImage = "cloud.fill"
            logoURL = "\(Self.logoBaseURL)/soundcloud.webp"
        } else if normalized.contains("twitter") || normalized.contains("x/") {
            shortTitle = "X"
            color = Color(red: 0.12, green: 0.13, blue: 0.16)
            systemImage = nil
            logoURL = "\(Self.logoBaseURL)/x.webp"
        } else if normalized.contains("youtube") {
            shortTitle = "YT"
            color = Color(red: 0.96, green: 0.08, blue: 0.10)
            systemImage = "play.fill"
            logoURL = "\(Self.logoBaseURL)/youtube.webp"
        } else if normalized.contains("netease") {
            shortTitle = "NE"
            color = Color(red: 0.86, green: 0.08, blue: 0.10)
            systemImage = "record.circle.fill"
            logoURL = "\(Self.logoBaseURL)/neteasemusic.webp"
        } else if normalized.contains("qq") {
            shortTitle = "QQ"
            color = Color(red: 0.16, green: 0.58, blue: 0.98)
            systemImage = "music.quarternote.3"
            logoURL = "\(Self.logoBaseURL)/qqmusic.webp"
        } else if normalized.contains("website") {
            shortTitle = "WWW"
            color = Color(red: 0.44, green: 0.55, blue: 0.68)
            systemImage = "globe"
            logoURL = "\(Self.logoBaseURL)/website.webp"
        } else {
            shortTitle = "URL"
            color = RaverTheme.accent
            systemImage = "link"
            logoURL = nil
        }
    }
}

private struct DJUploadLinkField: View {
    let title: String
    @Binding var text: String
    let platform: DJUploadLinkPlatform

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle

            HStack(spacing: 10) {
                platformLogo
                inputContainer
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldTitle: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RaverTheme.secondaryText)
    }

    private var inputContainer: some View {
        HStack(spacing: 8) {
            TextField(title, text: $text)
                .keyboardType(.URL)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(1)

            actionButton(
                systemImage: "doc.on.clipboard",
                accessibilityLabel: LT("粘贴", "Paste", "貼り付け")
            ) {
                if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !pasted.isEmpty {
                    text = pasted
                }
            }

            actionButton(
                systemImage: "xmark.circle.fill",
                accessibilityLabel: LT("清空", "Clear", "クリア")
            ) {
                text = ""
            }
            .opacity(text.isEmpty ? 0.38 : 1)
            .disabled(text.isEmpty)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder.opacity(0.76), lineWidth: 1)
        )
    }

    private var platformLogo: some View {
        Group {
            if let logoURL = platform.logoURL {
                ImageLoaderView(urlString: logoURL, resizingMode: .fill, showsIndicator: false)
            } else if let symbol = platform.systemImage {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.card)
            } else {
                Text(platform.shortTitle)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.card)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private func actionButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(RaverTheme.secondaryText)
                .frame(width: 28, height: 28)
                .background(RaverTheme.background.opacity(0.86), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
