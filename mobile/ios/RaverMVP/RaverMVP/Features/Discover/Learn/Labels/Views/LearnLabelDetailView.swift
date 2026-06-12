import SwiftUI

struct LearnLabelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    let label: LearnLabel

    @State private var selectedHeroMedia: FullscreenMediaSelection?
    @State private var avatarLuminance: CGFloat?
    @State private var shareMorePresentation: LabelCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: LabelCardSharePresentation?
    @State private var reportTarget: ReportSheetTarget?
    @State private var errorMessage: String?
    @State private var genreTagLookup: LearnGenreTagLookup = .empty

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Button {
                            guard destinationURL(label.backgroundUrl) != nil else { return }
                            selectedHeroMedia = FullscreenMediaSelection(id: 0)
                        } label: {
                            headerBanner
                        }
                        .buttonStyle(.plain)
                    }
                    .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        Button {
                            let avatarIndex = destinationURL(label.backgroundUrl) == nil ? 0 : 1
                            guard destinationURL(label.avatarUrl) != nil else { return }
                            selectedHeroMedia = FullscreenMediaSelection(id: avatarIndex)
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: 98)
                                .overlay {
                                    headerAvatar
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(LearnAvatarLuminanceStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(y: -50)
                        .padding(.bottom, -50)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(label.name)
                                .font(.title3.weight(.black))
                                .foregroundStyle(RaverTheme.primaryText)
                            if let intro = label.introduction?.trimmingCharacters(in: .whitespacesAndNewlines), !intro.isEmpty {
                                LearnExpandableText(text: intro, collapsedLineLimit: 4)
                            }
                        }
                    }

                    if !displayGenres.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LT("Genres", "Genres", "ジャンル"))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            LearnWrapFlowLayout(items: displayGenres) { genre in
                                labelGenreTag(genre)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if hasFounderDisplay {
                            founderSection
                        }
                        LearnMetadataInfoRow(title: LT("国家", "Country", "国"), value: label.nation)
                        LearnMetadataInfoRow(title: LT("地区/时期", "Region / Era", "地域 / 時期"), value: label.locationPeriod)
                        LearnMetadataInfoRow(title: LT("联系邮箱", "Contact Email", "連絡先メール"), value: label.generalContactEmail)
                        LearnMetadataInfoRow(title: LT("Demo 提交", "Demo Submission", "Demo提出"), value: label.demoSubmissionDisplay ?? label.demoSubmissionUrl)
                        if hasFoundedAtDisplay {
                            LearnMetadataInfoRow(title: LT("创始时间", "Founded At", "創設日時"), value: foundedAtDisplay)
                        }
                    }

                    linksSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("厂牌详情", "厂牌详情", "レーベル詳細"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareMorePresentation = LabelCardSharePresentation(
                        payload: makeLabelShareCardPayload()
                    )
                    isShareMorePanelVisible = false
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .fullScreenCover(item: $selectedHeroMedia) { selection in
            FullscreenMediaViewer(items: labelPreviewItems, initialIndex: selection.id)
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try await sendSharePayload(
                        presentation.payload,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                LabelSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, _ in
                showWidgetStatusBanner(message: LT("举报已提交", "Report submitted", "報告を送信しました"))
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .task(id: label.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
        .task {
            do {
                genreTagLookup = try await LearnGenreTagLookupCache.shared.lookup(using: appContainer.webService)
            } catch {}
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(),
                        loadConversations: {
                            try await loadSharePanelConversations()
                        },
                        onSendToConversation: { conversation, note in
                            try await sendSharePayload(
                                presentation.payload,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                            conversation: conversation
                        )
                    } onMoreChats: {
                        dismissShareMorePanel {
                            fullChatSharePresentation = presentation
                        }
                    }
                }
                .onAppear {
                    withAnimation(.sharePanelPresentSpring) {
                        isShareMorePanelVisible = true
                    }
                }
            }
        }
        .operationBannerHost()
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
    }

    @ViewBuilder
    private var headerBanner: some View {
        if let url = destinationURL(label.backgroundUrl) {
            fallbackBanner
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
                .overlay {
                    bannerEdgeGradient
                }
        } else {
            fallbackBanner
                .overlay {
                    bannerEdgeGradient
                }
        }
    }

    @ViewBuilder
    private var headerAvatar: some View {
        if let url = destinationURL(label.avatarUrl) {
            fallbackAvatar
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackAvatar
        }
    }

    private var fallbackBanner: some View {
        LinearGradient(
            colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackAvatar: some View {
        ZStack {
            fallbackBanner
            Text(String(label.name.prefix(2)).uppercased())
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var displayGenres: [String] {
        if !label.genres.isEmpty {
            return label.genres
        }
        return label.genresPreview?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    @ViewBuilder
    private func labelGenreTag(_ genre: String) -> some View {
        if let genreID = genreTagLookup.genreID(forExactName: genre) {
            Button {
                discoverPush(.genreDetail(genreID: genreID))
            } label: {
                labelGenreTagLabel(genre)
            }
            .buttonStyle(.plain)
        } else {
            labelGenreTagLabel(genre)
        }
    }

    private func labelGenreTagLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(RaverTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(RaverTheme.background)
            .clipShape(Capsule())
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    private var labelPreviewItems: [FullscreenMediaItem] {
        var items: [FullscreenMediaItem] = []
        if let bannerURL = destinationURL(label.backgroundUrl) {
            items.append(FullscreenMediaItem(rawURL: bannerURL.absoluteString, index: items.count))
        }
        if let avatarURL = destinationURL(label.avatarUrl) {
            items.append(FullscreenMediaItem(rawURL: avatarURL.absoluteString, index: items.count))
        }
        return items
    }

    @ViewBuilder
    private var founderSection: some View {
        if !displayFounders.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(displayFounders) { founder in
                        founderCard(founder)
                    }
                }
                .padding(.trailing, 2)
            }
        }
    }

    @ViewBuilder
    private func founderCard(_ founder: LearnLabelFounder) -> some View {
        if let founderDj = founder.dj {
            Button {
                appPush(.djDetail(djID: founderDj.id))
            } label: {
                founderCardContent(
                    name: founderDisplayName(founder),
                    avatarURL: founderDj.avatarUrl,
                    isInteractive: true
                )
            }
            .buttonStyle(.plain)
        } else {
            founderCardContent(
                name: founderDisplayName(founder),
                avatarURL: nil,
                isInteractive: false
            )
        }
    }

    private func founderCardContent(
        name: String,
        avatarURL: String?,
        isInteractive: Bool
    ) -> some View {
        HStack(spacing: 10) {
            LearnLabelFounderAvatar(urlString: avatarURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(LT("创始人", "创始人", "創設者"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
            }
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var displayFounders: [LearnLabelFounder] {
        label.founders.filter { !founderDisplayName($0).isEmpty }
    }

    private func founderDisplayName(_ founder: LearnLabelFounder) -> String {
        let name = founder.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        return founder.dj?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var foundedAtDisplay: String {
        label.foundedAt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasFounderDisplay: Bool {
        !displayFounders.isEmpty
    }

    private var hasFoundedAtDisplay: Bool {
        !foundedAtDisplay.isEmpty
    }

    @ViewBuilder
    private var linksSection: some View {
        let hasLinks = destinationURL(label.facebookUrl) != nil
            || destinationURL(label.soundcloudUrl) != nil
            || destinationURL(label.musicPurchaseUrl) != nil
            || destinationURL(label.officialWebsiteUrl) != nil
            || destinationURL(label.demoSubmissionUrl) != nil
        if hasLinks {
            VStack(alignment: .leading, spacing: 10) {
                Text(LT("Links", "Links", "リンク"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                if let url = destinationURL(label.facebookUrl) {
                    LearnExternalLinkRow(icon: "person.2.fill", title: "Facebook", url: url)
                }
                if let url = destinationURL(label.soundcloudUrl) {
                    LearnExternalLinkRow(icon: "waveform", title: "SoundCloud", url: url)
                }
                if let url = destinationURL(label.musicPurchaseUrl) {
                    LearnExternalLinkRow(icon: "cart.fill", title: LT("音乐资产购买", "Music Asset Purchase", "音楽アセット購入"), url: url)
                }
                if let url = destinationURL(label.officialWebsiteUrl) {
                    LearnExternalLinkRow(icon: "globe", title: LT("官网", "Official", "公式サイト"), url: url)
                }
                if let url = destinationURL(label.demoSubmissionUrl) {
                    LearnExternalLinkRow(icon: "paperplane.fill", title: LT("Demo 提交", "Demo Submission", "Demo提出"), url: url)
                }
            }
        }
    }

    private var bannerEdgeGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.76), location: 0),
                .init(color: Color.clear, location: 0.28),
                .init(color: Color.clear, location: 0.66),
                .init(color: Color.black.opacity(0.82), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(label.avatarUrl) else {
            await MainActor.run {
                avatarLuminance = nil
            }
            return
        }
        let luminance = await LearnAvatarLuminanceStyling.luminance(for: avatarURL)
        await MainActor.run {
            avatarLuminance = luminance
        }
    }

    private func dismissShareMorePanel(after: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            after?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func makeLabelShareCardPayload() -> LabelShareCardPayload {
        let coverImageURL = AppConfig.resolvedURLString(label.backgroundUrl)
            ?? AppConfig.resolvedURLString(label.avatarUrl)
        let genreText = displayGenres.prefix(3).joined(separator: " / ").nilIfBlank
        return LabelShareCardPayload(
            labelID: label.id,
            labelName: label.name,
            country: label.nation?.nilIfBlank,
            genreText: genreText,
            coverImageURL: coverImageURL,
            badgeText: LT("厂牌", "Label", "レーベル")
        )
    }

    private func shareTarget() -> ShareTarget {
        let canonicalURL = "https://ravehub.top/label/\(label.id)"
        let coverImageURL = AppConfig.resolvedURLString(label.backgroundUrl)
            ?? AppConfig.resolvedURLString(label.avatarUrl)
        let subtitle = [
            label.nation?.nilIfBlank,
            displayGenres.prefix(3).isEmpty ? nil : displayGenres.prefix(3).joined(separator: " / ").nilIfBlank
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
        return ShareTarget(
            type: .label,
            id: label.id,
            title: label.name,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            imageURL: coverImageURL,
            canonicalURL: canonicalURL,
            deepLink: "raver://label/\(label.id)",
            fallbackURL: canonicalURL,
            previewType: "content_card",
            visibility: "public"
        )
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = appContainer.shareMessageRepository.fetchConversations(type: .direct)
        async let groups = appContainer.shareMessageRepository.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendSharePayload(
        _ payload: LabelShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.shareMessageRepository.sendLabelCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await appContainer.shareMessageRepository.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                errorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "Instagram",
                systemImage: "camera.circle.fill",
                accentColor: Color(red: 0.91, green: 0.30, blue: 0.48)
            ) {
                errorMessage = LT("Instagram 分享接口待接入。", "Instagram share hook is not connected yet.", "Instagram共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "复制链接",
                systemImage: "link.circle.fill",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                Task { await copyLabelShareLink() }
            }
        ]
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = []

        actions.append(
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openLabelPoster() }
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("缓存", "Cache", "キャッシュ"),
                systemImage: "arrow.down.circle",
                accentColor: Color(red: 0.38, green: 0.73, blue: 0.98)
            ) {
                errorMessage = LT("该页面缓存能力正在建设中。", "Caching for this page is under construction.", "このページのキャッシュ機能は現在構築中です。")
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("贡献信息", "Incorrect Info", "情報を修正"),
                systemImage: "info.circle",
                accentColor: Color(red: 0.96, green: 0.69, blue: 0.25)
            ) {
                errorMessage = LT("贡献信息入口即将开放，当前已记录该需求。", "Incorrect info entry is coming soon. We have recorded this request.", "情報修正の入口は近日公開予定です。この要望は記録しました。")
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.93, green: 0.32, blue: 0.36)
            ) {
                reportTarget = ReportSheetTarget(
                    id: label.id,
                    type: .label,
                    title: label.name,
                    preview: label.introduction?.nilIfBlank ?? label.genresPreview?.nilIfBlank,
                    targetUserID: nil,
                    targetUserDisplayName: nil
                )
            }
        )

        if let url = destinationURL(label.officialWebsiteUrl) {
            actions.append(
                SharePanelQuickAction(
                    title: LT("官网", "Official", "公式サイト"),
                    systemImage: "globe",
                    accentColor: Color(red: 0.53, green: 0.45, blue: 0.96)
                ) {
                    UIApplication.shared.open(url)
                }
            )
        }

        return actions
    }

    @MainActor
    private func copyLabelShareLink() async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: shareTarget())
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("已复制链接", "Link copied", "リンクをコピーしました")
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openLabelPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(), channel: "view_poster")
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("Label 海报由分享系统统一生成，名称、摘要和二维码都会跟随短链保持一致。", "Label posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "Label海報は共有システムで生成され、名称、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }
}
