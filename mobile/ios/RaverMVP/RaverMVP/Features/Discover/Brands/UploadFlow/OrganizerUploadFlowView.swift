import PhotosUI
import SwiftUI
import UIKit

struct OrganizerUploadFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: OrganizerUploadFlowViewModel
    @State private var avatarItem: PhotosPickerItem?
    @State private var backgroundItem: PhotosPickerItem?
    @State private var posterItem: PhotosPickerItem?
    @State private var proofItems: [PhotosPickerItem] = []
    @State private var otherItems: [PhotosPickerItem] = []
    @State private var isShowingAvatarPicker = false
    @State private var isShowingBackgroundPicker = false
    @State private var isShowingPosterPicker = false
    @State private var isShowingProofPicker = false
    @State private var isShowingOtherPicker = false
    @State private var avatarSelectionChangeID = 0
    @State private var backgroundSelectionChangeID = 0
    @State private var posterSelectionChangeID = 0
    @State private var proofSelectionChangeID = 0
    @State private var otherSelectionChangeID = 0
    @State private var previewPresentation: OrganizerUploadImagePreviewPresentation?
    @State private var pendingCropSession: OrganizerUploadCropSession?
    @State private var showExitConfirmation = false
    @State private var showSubmitConfirmation = false
    @State private var isProfileLocalizationExpanded = false

    init(
        mode: OrganizerUploadMode = .create,
        initialBrand: WebLearnFestival? = nil,
        initialName: String? = nil,
        sourceContextID: String? = nil,
        userID: String = "current"
    ) {
        _viewModel = StateObject(wrappedValue: OrganizerUploadFlowViewModel(
            mode: mode,
            initialBrand: initialBrand,
            initialName: initialName,
            sourceContextID: sourceContextID,
            userID: userID
        ))
    }

    var body: some View {
        presentedContent
    }

    private var presentedContent: some View {
        previewWrappedContent
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
            .confirmationDialog(
                LT("确认提交主办方？", "Confirm Organizer Submission?", "主催者を送信しますか？"),
                isPresented: $showSubmitConfirmation,
                titleVisibility: .visible
            ) {
                Button(LT("确认提交", "Confirm Submit", "送信する")) {
                    viewModel.submitAfterConfirmation()
                }
                Button(LT("继续检查", "Keep Reviewing", "確認を続ける"), role: .cancel) {}
            } message: {
                Text(LT("确认后会立即发起主办方创建或编辑提交，后续状态会通过通知和我的发布更新。", "After confirmation, the organizer create or edit submission will start immediately. Later status updates will appear in notifications and My Posts.", "確認後、主催者の新規作成または編集送信を直ちに開始します。以降の状態更新は通知とマイ投稿で確認できます。"))
            }
    }

    private var previewWrappedContent: some View {
        lifecycleContent
            .fullScreenCover(item: $previewPresentation) { presentation in
                FullscreenMediaViewer(items: presentation.items, initialIndex: presentation.initialIndex)
            }
            .fullScreenCover(item: $pendingCropSession) { session in
                AppImageCropperSheet(
                    image: session.image,
                    aspectRatio: session.aspectRatio,
                    title: session.title,
                    onCancel: {
                        pendingCropSession = nil
                    },
                    onCrop: { croppedImage in
                        pendingCropSession = nil
                        Task { await applyCroppedImage(croppedImage, for: session.zone) }
                    }
                )
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $isShowingAvatarPicker, selection: avatarPickerSelection, matching: .images)
            .photosPicker(isPresented: $isShowingBackgroundPicker, selection: backgroundPickerSelection, matching: .images)
            .photosPicker(isPresented: $isShowingPosterPicker, selection: posterPickerSelection, matching: .images)
            .photosPicker(isPresented: $isShowingProofPicker, selection: proofPickerSelection, maxSelectionCount: 10, matching: .images)
            .photosPicker(isPresented: $isShowingOtherPicker, selection: otherPickerSelection, maxSelectionCount: 10, matching: .images)
    }

    private var lifecycleContent: some View {
        navigationWrappedContent
            .onAppear {
                viewModel.setDismissAction { dismiss() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background || phase == .inactive {
                    viewModel.saveDraft()
                }
            }
            .onDisappear {
                viewModel.handleDisappear()
            }
            .onChange(of: avatarSelectionChangeID) { _, _ in
                let item = avatarItem
                Task { await prepareAvatarPhotoForCropping(item) }
            }
            .onChange(of: backgroundSelectionChangeID) { _, _ in
                let item = backgroundItem
                Task { await loadSinglePhoto(item, zone: .background) }
            }
            .onChange(of: posterSelectionChangeID) { _, _ in
                let item = posterItem
                Task { await loadSinglePhoto(item, zone: .poster) }
            }
            .onChange(of: proofSelectionChangeID) { _, _ in
                let items = proofItems
                Task { await loadMultiplePhotos(items, zone: .proof) }
            }
            .onChange(of: otherSelectionChangeID) { _, _ in
                let items = otherItems
                Task { await loadMultiplePhotos(items, zone: .other) }
            }
    }

    private var avatarPickerSelection: Binding<PhotosPickerItem?> {
        Binding(
            get: { avatarItem },
            set: { newValue in
                avatarItem = newValue
                avatarSelectionChangeID += 1
            }
        )
    }

    private var backgroundPickerSelection: Binding<PhotosPickerItem?> {
        Binding(
            get: { backgroundItem },
            set: { newValue in
                backgroundItem = newValue
                backgroundSelectionChangeID += 1
            }
        )
    }

    private var posterPickerSelection: Binding<PhotosPickerItem?> {
        Binding(
            get: { posterItem },
            set: { newValue in
                posterItem = newValue
                posterSelectionChangeID += 1
            }
        )
    }

    private var proofPickerSelection: Binding<[PhotosPickerItem]> {
        Binding(
            get: { proofItems },
            set: { newValue in
                proofItems = newValue
                proofSelectionChangeID += 1
            }
        )
    }

    private var otherPickerSelection: Binding<[PhotosPickerItem]> {
        Binding(
            get: { otherItems },
            set: { newValue in
                otherItems = newValue
                otherSelectionChangeID += 1
            }
        )
    }

    private var navigationWrappedContent: some View {
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

    private var editorContent: some View {
        VStack(spacing: 0) {
            OrganizerUploadProgressHeader(
                currentStep: viewModel.draft.currentStep,
                hasIssue: { viewModel.hasIssue(for: $0) },
                isCompleted: { viewModel.isStepCompleted($0) },
                canNavigate: { viewModel.canNavigate(to: $0) },
                onSelect: { viewModel.jump(to: $0) }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    currentStepValidationCard
                    stepContent
                }
                .padding(16)
                .padding(.bottom, 56)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OrganizerUploadBottomBar(
                canGoBack: viewModel.draft.currentStep.previous != nil,
                isFinalStep: viewModel.draft.currentStep == .review,
                isBusy: viewModel.isSubmitting,
                onBack: viewModel.goBack,
                onNext: handlePrimaryAction
            )
        }
    }

    private var navigationTitle: String {
        viewModel.draft.isCreate
            ? LT("上传主办方", "Upload Organizer", "主催者をアップロード")
            : LT("编辑主办方", "Edit Organizer", "主催者を編集")
    }

    private var restoredDraftMessage: String {
        if case .edit = viewModel.draft.mode {
            return LT("已恢复上次未提交的主办方编辑草稿。", "Your previous organizer edit draft was restored.", "前回の主催者編集下書きを復元しました。")
        }
        return LT("已恢复上次未提交的新建主办方草稿。", "Your previous organizer draft was restored.", "前回の主催者下書きを復元しました。")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.draft.currentStep {
        case .media:
            mediaStep
        case .basic:
            basicStep
        case .profile:
            profileStep
        case .links:
            linksStep
        case .relations:
            relationsStep
        case .review:
            reviewStep
        }
    }

    @ViewBuilder
    private var currentStepValidationCard: some View {
        let issues = viewModel.validationIssues(for: viewModel.draft.currentStep)
        if !issues.isEmpty {
            formCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(LT("这一页还有待补充项", "This Step Still Needs Attention", "このステップには未完了項目があります"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                    }

                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        organizerInlineFeedbackRow(
                            message: issue.message,
                            systemImage: "circle.fill",
                            tint: .orange
                        )
                    }
                }
            }
        }
    }

    private var mediaStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(
                title: LT("媒体与主体证明", "Media & Proof", "メディアと証明"),
                body: LT(
                    "主视觉与审核证明先按 event 标准管理：头像必填，proof 仅审核可见，所有图片先归属到当前 draft。",
                    "Media follows the event standard: avatar is required, proof stays review-only, and all uploads belong to the current draft first.",
                    "画像はイベント基準に合わせます。アバターは必須、proof は審査専用で、すべての画像はまず現在の下書きに紐づきます。"
                )
            )

            singleImageCard(
                zone: .avatar,
                title: LT("头像", "Avatar", "アバター"),
                subtitle: LT("会作为主办方主图展示，建议使用清晰 Logo 或品牌主视觉。", "Used as the main organizer image. A clear logo or hero visual works best.", "主催者のメイン画像として表示されます。鮮明なロゴやキービジュアルがおすすめです。"),
                required: true
            )

            singleImageCard(
                zone: .background,
                title: LT("背景图", "Background", "背景"),
                subtitle: LT("用于详情页头图，可选但建议补充，以对齐 event 的视觉完整度。", "Used as the detail header image. Optional, but recommended for a fuller presentation.", "詳細ページのヘッダー画像です。任意ですが、見栄えを整えるため推奨です。"),
                required: false
            )

            singleImageCard(
                zone: .poster,
                title: LT("海报 / 主 KV", "Poster / Key Visual", "ポスター / キービジュアル"),
                subtitle: LT("用于补充海报、横版主视觉或品牌 KV。按 event 图片分区标准独立管理，方便后续审核和展示复用。", "Use this for posters, hero banners, or key visuals. It follows the event-style media partition so review and future presentation can reuse it cleanly.", "ポスター、横長ビジュアル、ブランド KV 用です。event と同じ画像分区で管理し、審査や後続表示で再利用しやすくします。"),
                required: false
            )

            multiImageCard(
                zone: .proof,
                title: LT("证明图", "Proof", "証明"),
                subtitle: LT("上传官网后台、票务后台、主办方社媒后台截图等，帮助审核确认主体真实性。", "Upload dashboard or official backend screenshots to help reviewers verify organizer ownership.", "公式管理画面やSNS管理画面のスクリーンショットなどをアップロードし、主体確認を補助します。"),
                reviewOnly: true
            )

            multiImageCard(
                zone: .other,
                title: LT("补充图", "Other Media", "補足画像"),
                subtitle: LT("可补充更多品牌素材，帮助审核和后续资料整理。", "Add extra brand assets to support review and later profile curation.", "審査や後続の資料整理に役立つ補足素材を追加できます。"),
                reviewOnly: false
            )
        }
    }

    private var basicStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(
                title: LT("基础信息", "Basic Info", "基本情報"),
                body: LT("先补齐主办方名称、别名、简称和基础地域信息。", "Start with organizer name, aliases, abbreviation, and location basics.", "まず主催者名、別名、略称、地域情報を入力します。")
            )

            localizedNameCard

            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    labeledField(
                        LT("主办方主名称", "Primary Name", "主催者の主名称"),
                        text: Binding(
                            get: { viewModel.draft.name },
                            set: { viewModel.updatePrimaryName($0) }
                        )
                    )

                    similarBrandCard

                    labeledField(LT("简称", "Abbreviation", "略称"), text: stringBinding(\.abbreviation))
                    labeledField(LT("别名（逗号分隔）", "Aliases (comma separated)", "別名（カンマ区切り）"), text: aliasesBinding)
                    HStack(spacing: 12) {
                        labeledField(LT("国家", "Country", "国"), text: stringBinding(\.country))
                        labeledField(LT("城市", "City", "City"), text: stringBinding(\.city))
                    }
                    HStack(spacing: 12) {
                        labeledField(LT("成立年份", "Founded Year", "設立年"), text: stringBinding(\.foundedYear))
                        labeledField(LT("举办频率", "Frequency", "開催頻度"), text: stringBinding(\.frequency))
                    }
                    labeledField(LT("一句话定位", "Tagline", "タグライン"), text: stringBinding(\.tagline))
                }
            }
        }
    }

    @ViewBuilder
    private var similarBrandCard: some View {
        let trimmedName = viewModel.draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass.circle")
                        .foregroundStyle(RaverTheme.accent)
                    Text(LT("相似主办方检查", "Similar Organizer Check", "類似主催者チェック"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Spacer()
                    if viewModel.isSearchingSimilarBrands {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if !viewModel.similarBrandResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LT("已发现可能重复的主办方，提交前建议先确认是否已存在。", "Possible duplicates were found. Check whether one already exists before submitting.", "重複の可能性がある主催者が見つかりました。送信前に既存かどうか確認してください。"))
                            .font(.caption)
                            .foregroundStyle(.orange)

                        ForEach(viewModel.similarBrandResults) { brand in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(brand.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(similarBrandMetaText(for: brand))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                } else if let message = viewModel.similarBrandFeedback.message {
                    organizerInlineFeedbackRow(
                        message: message,
                        systemImage: viewModel.similarBrandFeedback.isFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                        tint: viewModel.similarBrandFeedback.isFailure ? .orange : .green
                    )
                }
            }
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(
                title: LT("资料介绍", "Profile", "プロフィール"),
                body: LT("这一页现在支持主介绍与多语言简介补充，后续会继续接主办方类型、风格标签与审核提示。", "This step now supports the main profile text and localized introductions, with organizer type and style tags planned next.", "このステップでは主な紹介文と多言語紹介に対応し、次に主催者タイプやスタイルタグを接続します。")
            )

            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    labeledTextArea(
                        LT("主办方介绍", "Organizer Introduction", "主催者紹介"),
                        text: localizedIntroductionBinding(viewModel.draft.preferredLanguage),
                        minHeight: 150
                    )

                    OrganizerLocalizedExpandableFieldSection(
                        title: LT("多语言简介", "Localized Introductions", "多言語紹介"),
                        expanded: $isProfileLocalizationExpanded,
                        zhBinding: localizedIntroductionBinding(.zh),
                        enBinding: localizedIntroductionBinding(.en),
                        jaBinding: localizedIntroductionBinding(.ja),
                        extraCount: viewModel.draft.descriptionI18n.secondaryValueCount(excluding: viewModel.draft.preferredLanguage)
                    )

                    let introductionLength = viewModel.draft.primaryIntroduction.count
                    Text(
                        LT(
                            "当前长度 \(introductionLength) 字，可选填写，用于补充主办方介绍。",
                            "Current length: \(introductionLength). This field is optional and can be used to add organizer context.",
                            "現在の文字数は \(introductionLength) 字です。この項目は任意で、主催者紹介の補足に使えます。"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
    }

    private var linksStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(
                title: LT("官方链接", "Official Links", "公式リンク"),
                body: LT("这里先接官网与核心社媒链接，审核声明仍放在最后一步确认。", "This step currently covers the website and core social links, while review declarations stay on the final step.", "このステップでは公式サイトと主要SNSリンクを入力し、審査確認は最終ステップで行います。")
            )

            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    labeledField(LT("官网", "Official Website", "公式サイト"), text: stringBinding(\.officialWebsite), keyboard: .URL)
                    labeledField(LT("Instagram", "Instagram", "Instagram"), text: stringBinding(\.instagram), keyboard: .URL)
                    labeledField(LT("Facebook", "Facebook", "Facebook"), text: stringBinding(\.facebook), keyboard: .URL)
                    labeledField(LT("Twitter / X", "Twitter / X", "Twitter / X"), text: stringBinding(\.twitter), keyboard: .URL)
                    labeledField(LT("YouTube", "YouTube", "YouTube"), text: stringBinding(\.youtube), keyboard: .URL)
                    labeledField(LT("TikTok", "TikTok", "TikTok"), text: stringBinding(\.tiktok), keyboard: .URL)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(LT("补充链接", "Extra Links", "補足リンク"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            Spacer()
                            Button {
                                viewModel.draft.extraLinks.append(
                                    LearnFestivalLinkPayload(title: "", icon: "link", url: "")
                                )
                                viewModel.markDirty()
                                viewModel.saveDraft(immediate: false)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(LT("添加链接", "Add Link", "リンクを追加"))
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }

                        if viewModel.draft.extraLinks.isEmpty {
                            Text(LT("如果有官网之外的重要资料页、票务页或媒体报道，可以在这里补充。", "Add important profile pages, ticket pages, or media coverage here when needed.", "公式サイト以外の重要な資料ページ、チケットページ、メディア掲載などがあればここで補足できます。"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            ForEach(Array(viewModel.draft.extraLinks.indices), id: \.self) { index in
                                VStack(alignment: .leading, spacing: 10) {
                                    labeledField(
                                        LT("链接标题", "Link Title", "リンクタイトル"),
                                        text: extraLinkTitleBinding(index)
                                    )
                                    labeledField(
                                        LT("链接地址", "Link URL", "リンクURL"),
                                        text: extraLinkURLBinding(index),
                                        keyboard: .URL
                                    )
                                    HStack {
                                        Spacer()
                                        Button(role: .destructive) {
                                            viewModel.draft.extraLinks.remove(at: index)
                                            viewModel.markDirty()
                                            viewModel.saveDraft(immediate: false)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "trash")
                                                Text(LT("删除这条链接", "Delete This Link", "このリンクを削除"))
                                            }
                                            .font(.caption.weight(.semibold))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(RaverTheme.background)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var relationsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(
                title: LT("关联活动", "Related Events", "関連イベント"),
                body: LT("这里已经改成 event 搜索绑定卡片，可以直接搜索活动并加入当前主办方；重复绑定会自动去重。", "This step now uses searchable event binding cards so you can look up events and attach them directly to the organizer. Duplicate bindings are prevented automatically.", "このステップではイベント検索バインドカードに対応し、イベントを検索して主催者へ直接紐付けできます。重複紐付けは自動で防止されます。")
            )

            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LT("搜索活动", "Search Events", "イベント検索"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)

                        HStack(spacing: 10) {
                            TextField(
                                LT("输入活动名称", "Enter event name", "イベント名を入力"),
                                text: Binding(
                                    get: { viewModel.eventSearchQuery },
                                    set: { viewModel.updateEventSearchQuery($0) }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(RaverTheme.background)
                            )
                            .foregroundStyle(RaverTheme.primaryText)

                            Button {
                                Task { await viewModel.searchEvents() }
                            } label: {
                                HStack(spacing: 6) {
                                    if viewModel.isSearchingEvents {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "magnifyingglass")
                                    }
                                    Text(viewModel.isSearchingEvents
                                         ? LT("搜索中", "Searching", "検索中")
                                         : LT("搜索", "Search", "検索"))
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(RaverTheme.accent)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isSearchingEvents)
                        }
                    }

                    if viewModel.draft.boundEventIDs.isEmpty {
                        Text(LT("当前还没有绑定任何活动。", "No events are bound yet.", "まだ関連イベントはありません。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LT("当前已绑定", "Currently Bound", "現在の紐付け"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            ForEach(viewModel.draft.boundEventIDs, id: \.self) { eventID in
                                HStack(spacing: 8) {
                                    Text(viewModel.boundEventNameByID[eventID] ?? eventID)
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Button {
                                        viewModel.removeBoundEvent(id: eventID)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(RaverTheme.background, in: Capsule())
                            }
                        }
                    }

                    if viewModel.isSearchingEvents {
                        organizerInlineFeedbackRow(
                            message: LT("正在搜索活动…", "Searching events...", "イベントを検索中..."),
                            systemImage: "clock.arrow.circlepath",
                            tint: RaverTheme.secondaryText
                        )
                    } else if !viewModel.eventSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LT("搜索结果", "Search Results", "検索結果"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)

                            ForEach(viewModel.eventSearchResults.prefix(8)) { event in
                                Button {
                                    viewModel.toggleBoundEvent(event)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: viewModel.draft.boundEventIDs.contains(event.id) ? "checkmark.circle.fill" : "plus.circle")
                                            .font(.title3)
                                            .foregroundStyle(viewModel.draft.boundEventIDs.contains(event.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.name)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(RaverTheme.primaryText)
                                                .lineLimit(1)
                                            Text(organizerEventMetaText(for: event))
                                                .font(.caption2)
                                                .foregroundStyle(RaverTheme.secondaryText)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if let message = viewModel.eventSearchFeedback.message {
                        organizerInlineFeedbackRow(
                            message: message,
                            systemImage: viewModel.eventSearchFeedback.isFailure ? "exclamationmark.triangle.fill" : "info.circle.fill",
                            tint: viewModel.eventSearchFeedback.isFailure ? .orange : RaverTheme.secondaryText
                        )
                    }
                }
            }
        }
    }

    private var localizedNameCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(LT("多语言名称", "Localized Names", "多言語名称"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Picker(LT("主要语言", "Preferred Language", "主要言語"), selection: Binding(
                    get: { viewModel.draft.preferredLanguage },
                    set: {
                        viewModel.draft.preferredLanguage = $0
                        viewModel.markDirty()
                        viewModel.saveDraft(immediate: false)
                    }
                )) {
                    Text("ZH").tag(EventUploadPreferredLanguage.zh)
                    Text("EN").tag(EventUploadPreferredLanguage.en)
                    Text("JA").tag(EventUploadPreferredLanguage.ja)
                }
                .pickerStyle(.segmented)

                labeledField("ZH", text: localizedNameBinding(.zh))
                labeledField("EN", text: localizedNameBinding(.en))
                labeledField("JA", text: localizedNameBinding(.ja))
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(
                title: LT("提交前检查", "Review Before Submit", "送信前の確認"),
                body: LT(
                    "提交前再确认主名称、主视觉、proof 和官方链接。这里的内容会直接进入 brand 审核任务。",
                    "Confirm the organizer name, main media, proof, and official links before submitting. These values go directly into the brand review task.",
                    "送信前に主名称、メイン画像、proof、公式リンクを再確認します。ここでの内容はそのままブランド審査タスクに入ります。"
                )
            )

            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(LT("主办方概览", "Organizer Summary", "主催者概要"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)

                    if let heroImage = viewModel.draft.avatarImage ?? viewModel.draft.backgroundImage ?? viewModel.draft.posterImage {
                        organizerImageThumbnail(heroImage, height: 176)
                    }

                    reviewSummaryRow(LT("主名称", "Primary Name", "主名称"), value: viewModel.draft.primaryName)
                    reviewSummaryRow(
                        LT("地区", "Region", "地域"),
                        value: [viewModel.draft.country, viewModel.draft.city]
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .joined(separator: " · ")
                    )
                    reviewSummaryRow(LT("简称", "Abbreviation", "略称"), value: viewModel.draft.abbreviation)
                    reviewSummaryRow(LT("一句话定位", "Tagline", "タグライン"), value: viewModel.draft.tagline)
                    reviewSummaryRow(LT("介绍", "Introduction", "紹介"), value: viewModel.draft.primaryIntroduction)
                }
            }

            formCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LT("素材与审核信息", "Media & Review Info", "画像と審査情報"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)

                    reviewSummaryRow(
                        LT("图片统计", "Image Counts", "画像数"),
                        value: LT(
                            "头像 \(viewModel.draft.avatarImage == nil ? 0 : 1) · 背景 \(viewModel.draft.backgroundImage == nil ? 0 : 1) · 海报 \(viewModel.draft.posterImage == nil ? 0 : 1) · proof \(viewModel.draft.proofImages.count) · 补充 \(viewModel.draft.otherImages.count)",
                            "Avatar \(viewModel.draft.avatarImage == nil ? 0 : 1) · Background \(viewModel.draft.backgroundImage == nil ? 0 : 1) · Poster \(viewModel.draft.posterImage == nil ? 0 : 1) · Proof \(viewModel.draft.proofImages.count) · Other \(viewModel.draft.otherImages.count)",
                            "アバター \(viewModel.draft.avatarImage == nil ? 0 : 1) · 背景 \(viewModel.draft.backgroundImage == nil ? 0 : 1) · ポスター \(viewModel.draft.posterImage == nil ? 0 : 1) · proof \(viewModel.draft.proofImages.count) · 補足 \(viewModel.draft.otherImages.count)"
                        )
                    )
                    reviewSummaryRow(
                        LT("官方链接", "Official Links", "公式リンク"),
                        value: reviewLinkSummary
                    )
                    reviewSummaryRow(
                        LT("关联活动", "Related Events", "関連イベント"),
                        value: viewModel.draft.boundEventIDs.isEmpty
                            ? LT("当前未关联活动", "No related events yet", "関連イベントなし")
                            : viewModel.draft.boundEventIDs.joined(separator: ", ")
                    )
                    reviewSummaryRow(
                        LT("proof 摘要", "Proof Summary", "proof 概要"),
                        value: viewModel.draft.proofImages.isEmpty
                            ? LT("未上传 proof 图片", "No proof image uploaded", "proof 画像なし")
                            : LT("已上传 \(viewModel.draft.proofImages.count) 张，仅审核可见", "\(viewModel.draft.proofImages.count) uploaded, review only", "\(viewModel.draft.proofImages.count)枚アップロード済み、審査のみ表示")
                    )
                }
            }

            Toggle(
                LT("我确认拥有资料与图片的使用权", "I confirm I have rights to use the profile and images", "プロフィールと画像の利用権を確認します"),
                isOn: Binding(
                    get: { viewModel.draft.rightsConfirmed },
                    set: {
                        viewModel.draft.rightsConfirmed = $0
                        viewModel.markDirty()
                        viewModel.saveDraft()
                    }
                )
            )
            Toggle(
                LT("我确认提交身份真实且可接受审核", "I confirm the submission identity is authentic and reviewable", "提出者情報が真实で審査可能であることを確認します"),
                isOn: Binding(
                    get: { viewModel.draft.identityConfirmed },
                    set: {
                        viewModel.draft.identityConfirmed = $0
                        viewModel.markDirty()
                        viewModel.saveDraft()
                    }
                )
            )

            formCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LT("最终确认", "Final Confirmation", "最終確認"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(
                        LT(
                            "点击底部提交后，会先弹出最终确认。确认提交后，系统会按当前模式发起 brand 创建或编辑审核任务。",
                            "Tapping submit will open one final confirmation first. Once confirmed, the app will start the brand create or edit review submission for the current mode.",
                            "下部の送信を押すと、まず最終確認が表示されます。確認後、現在のモードに応じて brand の新規作成または編集審査送信を開始します。"
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    reviewSummaryRow(
                        LT("提交后去向", "What Happens Next", "送信後の流れ"),
                        value: LT(
                            "1. 进入处理中或直接发布\n2. 后续状态会在通知和我的发布里更新\n3. 若仍在审核中，event 侧会继续保留手填主办方名",
                            "1. It enters processing or publishes directly\n2. Later status updates appear in notifications and My Posts\n3. If review is still pending, the event flow keeps the manual organizer name",
                            "1. 処理中に入るか、そのまま公開されます\n2. 以降の状態更新は通知とマイ投稿に表示されます\n3. まだ審査中なら、event 側では手入力の主催者名を保持します"
                        )
                    )
                }
            }
        }
    }

    private var reviewLinkSummary: String {
        let rawValues = [
            viewModel.draft.officialWebsite,
            viewModel.draft.instagram,
            viewModel.draft.facebook,
            viewModel.draft.twitter,
            viewModel.draft.youtube,
            viewModel.draft.tiktok,
        ] + viewModel.draft.extraLinks.map { link in
            let title = link.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = link.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { return "" }
            return title.isEmpty ? url : "\(title): \(url)"
        }
        let values = rawValues
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty
            ? LT("当前未填写官方链接", "No official links yet", "公式リンクなし")
            : values.joined(separator: "\n")
    }

    private func reviewSummaryRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? LT("未填写", "Not provided", "未入力")
                 : value)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RaverTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func successView(_ success: OrganizerUploadSubmitSuccess) -> some View {
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

            EntityChangeResultPreviewCard(
                change: success.change,
                showsReviewPendingNotice: success.showsReviewPendingDiffNotice
            ) { changeLogID in
                appPush(.entityChangeDetail(changeLogID: changeLogID))
            }

            Text(LT("之后也可以在我的发布和通知中心里查看后续状态。", "You can also review later status updates from My Posts and notifications.", "後からマイ投稿と通知センターで状態更新を確認できます。"))
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                viewModel.closeAfterSuccess()
            } label: {
                HStack {
                    Text(LT("返回上一页", "Back", "前の画面に戻る"))
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
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RaverTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func labeledField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            TextField(title, text: text, axis: .vertical)
                .textInputAutocapitalization(keyboard == .URL ? .never : .sentences)
                .keyboardType(keyboard)
                .autocorrectionDisabled(keyboard == .URL)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(RaverTheme.background)
                )
                .foregroundStyle(RaverTheme.primaryText)
        }
    }

    private func labeledTextArea(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            TextField(title, text: text, axis: .vertical)
                .lineLimit(6...12)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(RaverTheme.background)
                )
                .foregroundStyle(RaverTheme.primaryText)
        }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<OrganizerUploadDraft, String>) -> Binding<String> {
        Binding(
            get: { viewModel.draft[keyPath: keyPath] },
            set: {
                viewModel.draft[keyPath: keyPath] = $0
                viewModel.markDirty()
                viewModel.saveDraft(immediate: false)
            }
        )
    }

    private func localizedNameBinding(_ language: EventUploadPreferredLanguage) -> Binding<String> {
        Binding(
            get: { viewModel.draft.nameI18n.value(for: language) },
            set: { newValue in
                viewModel.draft.nameI18n.setValue(newValue, for: language)
                if language == viewModel.draft.preferredLanguage {
                    viewModel.draft.name = newValue
                }
                viewModel.markDirty()
                viewModel.saveDraft(immediate: false)
            }
        )
    }

    private func localizedIntroductionBinding(_ language: EventUploadPreferredLanguage) -> Binding<String> {
        Binding(
            get: { viewModel.draft.descriptionI18n.value(for: language) },
            set: { newValue in
                viewModel.draft.descriptionI18n.setValue(newValue, for: language)
                if language == viewModel.draft.preferredLanguage {
                    viewModel.draft.introduction = newValue
                } else if viewModel.draft.introduction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.draft.introduction = viewModel.draft.primaryIntroduction
                }
                viewModel.markDirty()
                viewModel.saveDraft(immediate: false)
            }
        )
    }

    private var aliasesBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.aliases.joined(separator: ", ") },
            set: { newValue in
                viewModel.draft.aliases = newValue
                    .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "/" || $0 == "、" })
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                viewModel.markDirty()
                viewModel.saveDraft(immediate: false)
            }
        )
    }

    private func extraLinkTitleBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard viewModel.draft.extraLinks.indices.contains(index) else { return "" }
                return viewModel.draft.extraLinks[index].title
            },
            set: { newValue in
                guard viewModel.draft.extraLinks.indices.contains(index) else { return }
                viewModel.draft.extraLinks[index].title = newValue
                viewModel.markDirty()
                viewModel.saveDraft(immediate: false)
            }
        )
    }

    private func extraLinkURLBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard viewModel.draft.extraLinks.indices.contains(index) else { return "" }
                return viewModel.draft.extraLinks[index].url
            },
            set: { newValue in
                guard viewModel.draft.extraLinks.indices.contains(index) else { return }
                viewModel.draft.extraLinks[index].url = newValue
                viewModel.markDirty()
                viewModel.saveDraft(immediate: false)
            }
        )
    }

    private func singleImageCard(
        zone: OrganizerUploadImageZone,
        title: String,
        subtitle: String,
        required: Bool
    ) -> some View {
        let image = viewModel.draft.image(for: zone)
        let isUploading = viewModel.uploadingZones.contains(zone)
        let hasUploadFailure = viewModel.failedUploadZones.contains(zone)

        return formCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    if required {
                        Text("*")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    if isUploading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(RaverTheme.background)
                        .frame(height: 188)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    hasUploadFailure
                                        ? Color.orange.opacity(0.85)
                                        : (required && image == nil ? Color.red.opacity(0.6) : RaverTheme.cardBorder),
                                    lineWidth: 1
                                )
                        )

                    if let image {
                        Button {
                            presentPreview(for: zone, tappedImageID: image.id)
                        } label: {
                            organizerImageThumbnail(image, height: 188)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            presentImagePicker(for: zone)
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: hasUploadFailure ? "arrow.clockwise.circle.fill" : "photo.badge.plus")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(hasUploadFailure ? .orange : RaverTheme.accent)
                                Text(hasUploadFailure
                                     ? LT("重新选择并重传", "Choose Again to Retry", "再選択して再アップロード")
                                     : LT("选择图片", "Choose Image", "画像を選択"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                if hasUploadFailure {
                                    Text(LT("上一次上传失败，请重新选择图片后重试。", "The last upload failed. Choose the image again to retry.", "前回のアップロードに失敗しました。画像を再選択して再試行してください。"))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 188)
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)
                    }
                }

                if hasUploadFailure && image == nil {
                    organizerInlineFeedbackRow(
                        message: LT("当前图片尚未上传成功，重新选择后会再次发起上传。", "This image has not uploaded successfully yet. Choosing it again will retry the upload.", "この画像はまだ正常にアップロードされていません。再選択すると再度アップロードします。"),
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                }

                if image != nil {
                    HStack(spacing: 10) {
                        if hasUploadFailure {
                            Button {
                                Task { await viewModel.retryImageUpload(zone: zone) }
                            } label: {
                                imageActionButtonLabel(
                                    title: LT("重试上传", "Retry Upload", "再アップロード"),
                                    systemImage: "arrow.clockwise"
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isUploading)
                        }

                        Button {
                            presentImagePicker(for: zone)
                        } label: {
                            imageActionButtonLabel(
                                title: LT("替换图片", "Replace", "差し替え"),
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)

                        Button {
                            Task { await viewModel.removeImage(zone: zone) }
                        } label: {
                            imageActionButtonLabel(
                                title: LT("删除", "Delete", "削除"),
                                systemImage: "trash"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)
                    }
                }
            }
        }
    }

    private func multiImageCard(
        zone: OrganizerUploadImageZone,
        title: String,
        subtitle: String,
        reviewOnly: Bool
    ) -> some View {
        let images = viewModel.draft.images(for: zone)
        let isUploading = viewModel.uploadingZones.contains(zone)
        let hasUploadFailure = viewModel.failedUploadZones.contains(zone)

        return formCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    if reviewOnly {
                        Text(LT("仅审核可见", "Review Only", "審査のみ表示"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                    Text(LT("\(images.count) 张", "\(images.count) images", "\(images.count)枚"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    presentImagePicker(for: zone)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.accent)
                        Text(images.isEmpty ? LT("选择图片", "Choose Images", "画像を選択") : LT("继续添加", "Add More", "さらに追加"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Spacer()
                        if isUploading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isUploading)

                if hasUploadFailure {
                    organizerInlineFeedbackRow(
                        message: LT("部分图片上传失败。本地草稿已保留，可以直接重试上传或替换。", "Some images failed to upload. The local draft is kept, so you can retry or replace them directly.", "一部の画像のアップロードに失敗しました。ローカル下書きは保持されているため、そのまま再試行または差し替えできます。"),
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                }

                if images.isEmpty {
                    Text(reviewOnly
                        ? LT("当前还没有 proof 图片。没有官方链接时，至少补一张 proof 方便审核。", "No proof images yet. If you don't have official links, add at least one proof image.", "まだ proof 画像はありません。公式リンクがない場合は、審査のため少なくとも1枚追加してください。")
                        : LT("当前还没有补充图。", "No extra media yet.", "まだ補足画像はありません。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    presentPreview(for: zone, tappedImageID: image.id)
                                } label: {
                                    organizerImageThumbnail(image, height: 96)
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 8) {
                                    Button {
                                        viewModel.moveImage(id: image.id, in: zone, offset: -1)
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(RaverTheme.secondaryText)
                                            .frame(width: 28, height: 28)
                                            .background(RaverTheme.background, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(index == 0 || isUploading)

                                    Button {
                                        viewModel.moveImage(id: image.id, in: zone, offset: 1)
                                    } label: {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(RaverTheme.secondaryText)
                                            .frame(width: 28, height: 28)
                                            .background(RaverTheme.background, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(index == images.count - 1 || isUploading)

                                    Spacer(minLength: 0)
                                }

                                if image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank == nil {
                                    Button {
                                        Task { await viewModel.retryImageUpload(zone: zone, imageID: image.id) }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.clockwise")
                                            Text(LT("重试上传", "Retry", "再試行"))
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isUploading)
                                }

                                Button {
                                    Task { await viewModel.removeImage(zone: zone, imageID: image.id) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                        Text(LT("删除", "Delete", "削除"))
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func imageActionButtonLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(RaverTheme.primaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func organizerInlineFeedbackRow(message: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(message)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func organizerEventMetaText(for event: WebEvent) -> String {
        let location = [event.city, event.country]
            .compactMap { value -> String? in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: " · ")
        let dateText = organizerEventDateFormatter.string(from: event.startDate)
        return location.isEmpty ? dateText : "\(location) · \(dateText)"
    }

    private func similarBrandMetaText(for brand: WebLearnFestival) -> String {
        let segments = [
            brand.country.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            brand.city.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            brand.tagline.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        ].compactMap { $0 }
        return segments.isEmpty
            ? LT("已有线上主办方资料", "Existing organizer profile", "既存の主催者プロフィール")
            : segments.joined(separator: " · ")
    }

    private var organizerEventDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private func handlePrimaryAction() {
        if viewModel.draft.currentStep == .review {
            if viewModel.prepareSubmitConfirmation() {
                showSubmitConfirmation = true
            }
            return
        }
        viewModel.goNext()
    }

    private func organizerImageThumbnail(_ image: OrganizerUploadImageDraft, height: CGFloat) -> some View {
        Group {
            if let localFileURL = image.localFileURL,
               let uiImage = UIImage(contentsOfFile: localFileURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = organizerImageURL(for: image) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let loadedImage):
                        loadedImage
                            .resizable()
                            .scaledToFill()
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(RaverTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RaverTheme.background)
            Image(systemName: "photo")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(RaverTheme.accent)
        }
    }

    private func organizerImageURL(for image: OrganizerUploadImageDraft) -> URL? {
        guard let remoteURL = image.remoteURL,
              let resolved = AppConfig.resolvedURLString(remoteURL) ?? remoteURL.nilIfBlank else {
            return nil
        }
        return URL(string: resolved)
    }

    private func presentPreview(for zone: OrganizerUploadImageZone, tappedImageID: UUID) {
        let images = viewModel.draft.images(for: zone)
        let previewItems = images.enumerated().compactMap { index, image -> FullscreenMediaItem? in
            let rawURL: String?
            if let localFileURL = image.localFileURL {
                rawURL = localFileURL.absoluteString
            } else {
                rawURL = organizerImageURL(for: image)?.absoluteString
            }
            guard let rawURL else { return nil }
            return FullscreenMediaItem(rawURL: rawURL, index: index)
        }
        guard let selectedIndex = images.firstIndex(where: { $0.id == tappedImageID }),
              !previewItems.isEmpty else { return }
        previewPresentation = OrganizerUploadImagePreviewPresentation(items: previewItems, initialIndex: selectedIndex)
    }

    private func presentImagePicker(for zone: OrganizerUploadImageZone) {
        switch zone {
        case .avatar:
            isShowingAvatarPicker = true
        case .background:
            isShowingBackgroundPicker = true
        case .poster:
            isShowingPosterPicker = true
        case .proof:
            isShowingProofPicker = true
        case .other:
            isShowingOtherPicker = true
        }
    }

    @MainActor
    private func loadSinglePhoto(_ item: PhotosPickerItem?, zone: OrganizerUploadImageZone) async {
        defer {
            switch zone {
            case .avatar:
                avatarItem = nil
            case .background:
                backgroundItem = nil
            case .poster:
                posterItem = nil
            case .proof, .other:
                break
            }
        }
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            await viewModel.uploadImage(data, zone: zone)
        } catch {
            viewModel.statusMessage = error.userFacingMessage ?? LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像の読み込みに失敗しました。もう一度お試しください。")
        }
    }

    private func prepareAvatarPhotoForCropping(_ item: PhotosPickerItem?) async {
        guard let item else {
            await MainActor.run {
                avatarItem = nil
            }
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run {
                    avatarItem = nil
                    viewModel.statusMessage = LT("读取图片失败，请重新选择。", "Failed to read the image. Please choose again.", "画像の読み込みに失敗しました。もう一度選択してください。")
                }
                return
            }

            await MainActor.run {
                avatarItem = nil
                pendingCropSession = OrganizerUploadCropSession(
                    zone: .avatar,
                    image: image,
                    aspectRatio: CGSize(width: 1, height: 1),
                    title: LT("裁剪主办方头像", "Crop Organizer Avatar", "主催者アバターを切り抜く")
                )
            }
        } catch {
            await MainActor.run {
                avatarItem = nil
                viewModel.statusMessage = error.userFacingMessage ?? LT("读取图片失败，请重新选择。", "Failed to read the image. Please choose again.", "画像の読み込みに失敗しました。もう一度選択してください。")
            }
        }
    }

    private func applyCroppedImage(_ image: UIImage, for zone: OrganizerUploadImageZone) async {
        guard let data = image.raverEncodedImageData(compressionQuality: 0.95) else {
            await MainActor.run {
                viewModel.statusMessage = LT("图片裁剪失败，请重新选择。", "Image cropping failed. Please choose again.", "画像の切り抜きに失敗しました。もう一度選択してください。")
            }
            return
        }

        await viewModel.uploadImage(data, zone: zone)
    }

    @MainActor
    private func loadMultiplePhotos(_ items: [PhotosPickerItem], zone: OrganizerUploadImageZone) async {
        defer {
            switch zone {
            case .proof:
                proofItems = []
            case .other:
                otherItems = []
            case .avatar, .background, .poster:
                break
            }
        }
        guard !items.isEmpty else { return }
        do {
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                await viewModel.uploadImage(data, zone: zone)
            }
        } catch {
            viewModel.statusMessage = error.userFacingMessage ?? LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像の読み込みに失敗しました。もう一度お試しください。")
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct OrganizerLocalizedExpandableFieldSection: View {
    let title: String
    @Binding var expanded: Bool
    let zhBinding: Binding<String>
    let enBinding: Binding<String>
    let jaBinding: Binding<String>
    let extraCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
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
                    .background(RaverTheme.background, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(extraCount > 0 ? RaverTheme.accent.opacity(0.28) : RaverTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if expanded {
                VStack(spacing: 10) {
                    organizerLanguageTextArea(title: "ZH", binding: zhBinding)
                    organizerLanguageTextArea(title: "EN", binding: enBinding)
                    organizerLanguageTextArea(title: "JA", binding: jaBinding)
                }
                .padding(12)
                .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private func organizerLanguageTextArea(title: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            TextField(title, text: binding, axis: .vertical)
                .lineLimit(4...8)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(minHeight: 96, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(RaverTheme.card)
                )
                .foregroundStyle(RaverTheme.primaryText)
        }
    }
}

private struct OrganizerUploadImagePreviewPresentation: Identifiable {
    let id = UUID()
    let items: [FullscreenMediaItem]
    let initialIndex: Int
}

private struct OrganizerUploadCropSession: Identifiable {
    let id = UUID()
    let zone: OrganizerUploadImageZone
    let image: UIImage
    let aspectRatio: CGSize
    let title: String
}
