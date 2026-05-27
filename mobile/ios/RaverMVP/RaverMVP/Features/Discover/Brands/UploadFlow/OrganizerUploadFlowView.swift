import SwiftUI

struct OrganizerUploadFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: OrganizerUploadFlowViewModel
    @State private var showExitConfirmation = false

    init(
        mode: OrganizerUploadMode = .create,
        initialBrand: WebLearnFestival? = nil,
        userID: String = "current"
    ) {
        _viewModel = StateObject(wrappedValue: OrganizerUploadFlowViewModel(
            mode: mode,
            initialBrand: initialBrand,
            userID: userID
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
            OrganizerUploadProgressHeader(currentStep: viewModel.draft.currentStep)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stepContent
                }
                .padding(16)
                .padding(.bottom, 84)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            OrganizerUploadBottomBar(
                canGoBack: viewModel.draft.currentStep.previous != nil,
                isFinalStep: viewModel.draft.currentStep == .review,
                isBusy: viewModel.isSubmitting,
                onBack: viewModel.goBack,
                onNext: viewModel.goNext
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
            placeholderStep(
                title: LT("媒体与证明", "Media & Proof", "メディアと証明"),
                body: LT("这里会对齐 event 上传的图片分区、draft 上传和 proof 素材策略。", "This step will align with the event flow for media zones, draft uploads, and proof handling.", "このステップではイベント投稿に合わせて画像ゾーン、下書きアップロード、証明素材処理を揃えます。")
            )
        case .basic:
            placeholderStep(
                title: LT("基础信息", "Basic Info", "基本情報"),
                body: LT("这里会填写名称、别名、国家、城市、成立年份与频率。", "This step will cover name, aliases, country, city, founded year, and frequency.", "このステップでは名称、別名、国、都市、設立年、開催頻度を入力します。")
            )
        case .profile:
            placeholderStep(
                title: LT("资料介绍", "Profile", "プロフィール"),
                body: LT("这里会接主办方介绍、tagline、多语言字段与审核说明。", "This step will handle intro, tagline, localized fields, and review-facing notes.", "このステップでは紹介文、タグライン、多言語項目、審査向け説明を扱います。")
            )
        case .links:
            placeholderStep(
                title: LT("官方链接", "Official Links", "公式リンク"),
                body: LT("这里会接官网与社媒链接，并校验链接格式。", "This step will connect website and social links with validation.", "このステップでは公式サイトとSNSリンクを接続し、形式検証を行います。")
            )
        case .relations:
            placeholderStep(
                title: LT("关联活动", "Related Events", "関連イベント"),
                body: LT("这里会接 event 搜索绑定，支持从活动上传流反向创建主办方。", "This step will support event binding and reverse entry from event upload.", "このステップではイベント紐付けと、イベント投稿からの逆導線を接続します。")
            )
        case .review:
            reviewStep
        }
    }

    private func placeholderStep(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(title: title, body: body)
            sectionCard(
                title: LT("当前草稿摘要", "Current Draft Summary", "現在の下書き概要"),
                body: OrganizerUploadMappers.summary(for: viewModel.draft).joined(separator: " · ").nilIfBlank
                    ?? LT("当前还没有足够的摘要信息。", "Not enough summary data yet.", "まだ十分な概要情報がありません。")
            )
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(
                title: LT("提交前检查", "Review Before Submit", "送信前の確認"),
                body: LT("这一版先完成流程骨架。下一阶段会在这里展示结构化 diff、图片归属、审核提示和我的发布状态说明。", "This first pass focuses on the flow skeleton. The next phase will show structured diffs, media ownership, review hints, and My Posts status guidance here.", "この初期版はフロー骨格の構築が中心です。次の段階で構造化差分、画像帰属、審査ヒント、マイ投稿状態案内をここに表示します。")
            )
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

            Button {
                viewModel.closeAfterSuccess()
            } label: {
                HStack {
                    Text(LT("返回主办方页", "Back to Organizers", "主催者ページへ戻る"))
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

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
