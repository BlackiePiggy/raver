import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UIKit
import Photos
import CoreImage.CIFilterBuiltins
import MapKit
import CoreLocation
import CoreText
import SDWebImage

private struct DJCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: DJShareCardPayload
}

private struct DJSharePreviewCard: View {
    let payload: DJShareCardPayload

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewImage
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if let badge = payload.badgeText?.nilIfBlank {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.djName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if let genre = payload.genreText?.nilIfBlank {
                    Text(genre)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var previewImage: some View {
        if let raw = payload.coverImageURL,
           let url = URL(string: raw),
           !raw.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        LinearGradient(
            colors: [RaverTheme.accent.opacity(0.95), Color(red: 0.19, green: 0.18, blue: 0.26)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "music.mic")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }
}

struct DiscoverDJsRootView: View {
    @EnvironmentObject private var appContainer: AppContainer
    private let onHorizontalDragStateChanged: ((Bool) -> Void)?

    init(onHorizontalDragStateChanged: ((Bool) -> Void)? = nil) {
        self.onHorizontalDragStateChanged = onHorizontalDragStateChanged
    }

    var body: some View {
        DJsModuleView(
            viewModel: DJsModuleViewModel(repository: appContainer.djListRepository),
            onHorizontalDragStateChanged: onHorizontalDragStateChanged
        )
    }
}

private struct JustifiedUILabelText: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    let lineSpacing: CGFloat

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.backgroundColor = .clear
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? UIScreen.main.bounds.width
        let fittingSize = uiView.sizeThatFits(
            CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: targetWidth, height: ceil(fittingSize.height))
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.baseWritingDirection = .natural
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing

        uiView.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

struct DJsModuleView: View {
    private enum DJsModuleSection: String, CaseIterable, Identifiable {
        case hot
        case spotlight

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hot:
                return LT("热度 DJ", "Hot DJs", "人気DJ")
            case .spotlight:
                return LT("精选", "Spotlight", "注目")
            }
        }
    }

    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @Environment(\.dismiss) private var dismiss
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight
    private let hotDJBatchSize = 25
    private let onHorizontalDragStateChanged: ((Bool) -> Void)?
    private let initialImportName: String?
    private let openImportOnAppear: Bool
    private let dismissAfterSuccessfulImport: Bool
    @StateObject private var viewModel: DJsModuleViewModel

    private var djImportRepository: DJImportRepository {
        appContainer.djImportRepository
    }

    private var djMediaRepository: DJMediaRepository {
        appContainer.djMediaRepository
    }

    @State private var selectedSection: DJsModuleSection = .spotlight
    @State private var errorMessage: String?
    @State private var djImportSuccessMessage: String?
    @State private var showDJImportSheet = false
    @State private var importMode: DJsImportMode = .spotify
    @State private var spotifySearchKeyword = ""
    @State private var spotifyCandidates: [SpotifyDJCandidate] = []
    @State private var isSearchingSpotify = false
    @State private var selectedSpotifyCandidate: SpotifyDJCandidate?
    @State private var spotifyDraftName = ""
    @State private var spotifyDraftAliases = ""
    @State private var spotifyDraftBio = ""
    @State private var spotifyDraftCountry = ""
    @State private var discogsSearchKeyword = ""
    @State private var discogsCandidates: [DiscogsDJCandidate] = []
    @State private var isSearchingDiscogs = false
    @State private var selectedDiscogsCandidate: DiscogsDJCandidate?
    @State private var isLoadingDiscogsDetail = false
    @State private var discogsDraftName = ""
    @State private var discogsDraftAliases = ""
    @State private var discogsDraftBio = ""
    @State private var discogsDraftCountry = ""
    @State private var discogsDraftInstagram = ""
    @State private var discogsDraftSoundcloud = ""
    @State private var discogsDraftTwitter = ""
    @State private var discogsDraftSpotifyID = ""
    @State private var discogsLinkedSpotifyKeyword = ""
    @State private var discogsLinkedSpotifyCandidates: [SpotifyDJCandidate] = []
    @State private var isSearchingDiscogsLinkedSpotify = false
    @State private var selectedDiscogsLinkedSpotifyCandidate: SpotifyDJCandidate?
    @State private var manualName = ""
    @State private var manualAliases = ""
    @State private var manualBio = ""
    @State private var manualCountry = ""
    @State private var manualInstagram = ""
    @State private var manualSoundcloud = ""
    @State private var manualTwitter = ""
    @State private var manualAvatarItem: PhotosPickerItem?
    @State private var manualBannerItem: PhotosPickerItem?
    @State private var manualAvatarData: Data?
    @State private var manualBannerData: Data?
    @State private var isImportingDJ = false
    @State private var didOpenInitialImport = false

    init(
        viewModel: DJsModuleViewModel,
        initialImportName: String? = nil,
        openImportOnAppear: Bool = false,
        dismissAfterSuccessfulImport: Bool = false,
        onHorizontalDragStateChanged: ((Bool) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        let normalizedInitialName = initialImportName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.initialImportName = normalizedInitialName?.isEmpty == false ? normalizedInitialName : nil
        self.openImportOnAppear = openImportOnAppear
        self.dismissAfterSuccessfulImport = dismissAfterSuccessfulImport
        self.onHorizontalDragStateChanged = onHorizontalDragStateChanged
        _importMode = State(initialValue: normalizedInitialName?.isEmpty == false ? .manual : .spotify)
        _manualName = State(initialValue: normalizedInitialName?.isEmpty == false ? (normalizedInitialName ?? "") : "")
    }

    var body: some View {
        ZStack(alignment: .top) {
            switch viewModel.phase {
            case .idle, .initialLoading:
                DiscoverGridSkeletonView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(
                        title: LT("DJ 列表加载失败", "DJs Failed to Load", "DJ一覧の読み込みに失敗しました"),
                        message: message
                    ) {
                        Task { await viewModel.reload() }
                    }
                    .padding(16)
                    .padding(.top, 96)
                }
            case .empty:
                ContentUnavailableView(LT("暂无 DJ", "暂无 DJ", "DJはまだありません"), systemImage: "music.mic")
                    .frame(maxWidth: .infinity, minHeight: 220)
            case .success:
                sectionContent
            }

            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if viewModel.isRefreshing {
                            InlineLoadingBadge(title: LT("正在更新 DJ 列表", "Updating DJs", "DJ一覧を更新中"))
                        }
                        if let bannerMessage = viewModel.bannerMessage {
                            ScreenStatusBanner(
                                message: bannerMessage,
                                style: .error,
                                actionTitle: LT("重试", "Retry", "再試行")
                            ) {
                                Task { await viewModel.reload() }
                            }
                        }
                    }
                } else if let activeErrorMessage {
                    Text(activeErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, topContentInset)
        }
        .background(RaverTheme.background)
        .task {
            await viewModel.loadIfNeeded()
            openInitialImportIfNeeded()
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedSection == .hot {
                djImportFloatingButton
            }
        }
        .navigationDestination(isPresented: $showDJImportSheet) {
            djImportSheet
        }
        .onDisappear {
            onHorizontalDragStateChanged?(false)
        }
        .onChange(of: manualAvatarItem) { _, item in
            Task { await loadManualPhoto(item, target: .avatar) }
        }
        .onChange(of: manualBannerItem) { _, item in
            Task { await loadManualPhoto(item, target: .banner) }
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { activeErrorMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                    viewModel.errorMessage = nil
                }
            }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(activeErrorMessage ?? "")
        }
    }

    @MainActor
    private func openInitialImportIfNeeded() {
        guard openImportOnAppear, !didOpenInitialImport else { return }
        didOpenInitialImport = true
        if let initialImportName {
            importMode = .manual
            manualName = initialImportName
        }
        showDJImportSheet = true
    }

    private var activeErrorMessage: String? {
        errorMessage ?? viewModel.errorMessage
    }

    private var filteredDJs: [WebDJ] {
        viewModel.filteredDJs
    }

    private var spotlightCarouselDJs: [WebDJ] {
        viewModel.spotlightCarouselDJs
    }

    @ViewBuilder
    private var sectionContent: some View {
        if spotlightCarouselDJs.isEmpty {
            ContentUnavailableView(LT("暂无 DJ", "暂无 DJ", "DJはまだありません"), systemImage: "music.mic")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            DJSpotlightCarouselSection(
                djs: spotlightCarouselDJs,
                onSelect: { tapped in
                    appPush(.djDetail(djID: tapped.id))
                },
                onHorizontalDragStateChanged: onHorizontalDragStateChanged
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var marqueeRows: [[WebDJ]] {
        let pool = Array(viewModel.djs.prefix(hotDJBatchSize))
        guard !pool.isEmpty else { return [] }

        return (0..<4).map { mod in
            let row = pool.enumerated().compactMap { index, item in
                index % 4 == mod ? item : nil
            }
            return row.isEmpty ? Array(pool.prefix(8)) : row
        }
    }

    private var topContentInset: CGFloat {
        14
    }

    private var marqueeWallHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        switch screenHeight {
        case ..<700:
            return 420
        case ..<800:
            return 470
        case ..<900:
            return 520
        default:
            return 560
        }
    }

    private var djImportFloatingButton: some View {
        Button {
            showDJImportSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(RaverTheme.accent)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, max(0, tabBarReservedHeight) + 24)
    }

    private var djImportSheet: some View {
        Form {
                Section(LT("导入方式", "导入方式", "取り込み方法")) {
                    Picker(LT("导入方式", "导入方式", "取り込み方法"), selection: $importMode) {
                        ForEach(DJsImportMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if importMode == .spotify {
                    Section(LT("搜索 Spotify DJ", "搜索 Spotify DJ", "Spotify DJを検索")) {
                        HStack(spacing: 8) {
                            TextField(LT("输入 DJ 名称", "输入 DJ 名称", "DJ名を入力"), text: $spotifySearchKeyword)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(true)
                                .onSubmit {
                                    Task { await searchSpotifyCandidates() }
                                }

                            Button(isSearchingSpotify ? LT("搜索中...", "Searching...", "検索中...") : LT("搜索", "Search", "検索")) {
                                Task { await searchSpotifyCandidates() }
                            }
                            .disabled(isSearchingSpotify || spotifySearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if isSearchingSpotify {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(LT("正在拉取 Spotify 候选列表...", "正在拉取 Spotify 候选列表...", "Spotify候補を取得中..."))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }

                    Section(LT("候选结果", "候选结果", "候補結果")) {
                        if spotifyCandidates.isEmpty {
                            Text(LT("暂无候选，可切换到手动导入。", "暂无候选，可切换到手动导入。", "候補がありません。手動取り込みに切り替えられます。"))
                                .font(.subheadline)
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            ForEach(spotifyCandidates) { candidate in
                                Button {
                                    applySpotifyCandidate(candidate)
                                } label: {
                                    spotifyCandidateRow(candidate, selectedSpotifyId: selectedSpotifyCandidate?.spotifyId)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let selected = selectedSpotifyCandidate {
                        Section(LT("确认导入信息", "确认导入信息", "取り込み情報を確認")) {
                            Text(LT("Spotify ID: \(selected.spotifyId)", "Spotify ID: \(selected.spotifyId)", "Spotify ID: \(selected.spotifyId)"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)

                            TextField(LT("DJ 名称", "DJ 名称", "DJ名"), text: $spotifyDraftName)
                            TextField(LT("别名（英文逗号分隔）", "别名（英文逗号分隔）", "別名（半角カンマ区切り）"), text: $spotifyDraftAliases)
                            TextField(LT("简介", "简介", "紹介"), text: $spotifyDraftBio, axis: .vertical)
                            TextField(LT("国家（可选）", "国家（可选）", "国（任意）"), text: $spotifyDraftCountry)

                            if let existingName = selected.existingDJName, !existingName.isEmpty {
                                Text(LT("检测到同名/同Spotify DJ：\(existingName)，导入时将合并更新，不会重复创建。", "Matched existing same-name/Spotify DJ: \(existingName). Import will merge update instead of creating duplicate.", "同名/同一SpotifyのDJ「\(existingName)」を検出しました。取り込み時に統合更新され、重複作成されません。"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                } else if importMode == .discogs {
                    Section(LT("搜索 Discogs Artist", "搜索 Discogs Artist", "Discogs Artistを検索")) {
                        HStack(spacing: 8) {
                            TextField(LT("输入 DJ 名称", "输入 DJ 名称", "DJ名を入力"), text: $discogsSearchKeyword)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(true)
                                .onSubmit {
                                    Task { await searchDiscogsCandidates() }
                                }

                            Button(isSearchingDiscogs ? LT("搜索中...", "Searching...", "検索中...") : LT("搜索", "Search", "検索")) {
                                Task { await searchDiscogsCandidates() }
                            }
                            .disabled(isSearchingDiscogs || discogsSearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if isSearchingDiscogs {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(LT("正在拉取 Discogs 候选列表...", "正在拉取 Discogs 候选列表...", "Discogs候補を取得中..."))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }

                    Section(LT("Discogs 候选结果", "Discogs 候选结果", "Discogs候補結果")) {
                        if discogsCandidates.isEmpty {
                            Text(LT("暂无候选，可继续搜索或切换到手动导入。", "暂无候选，可继续搜索或切换到手动导入。", "候補がありません。検索を続けるか手動取り込みに切り替えられます。"))
                                .font(.subheadline)
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            ForEach(discogsCandidates) { candidate in
                                Button {
                                    applyDiscogsCandidate(candidate)
                                } label: {
                                    discogsCandidateRow(candidate)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if selectedDiscogsCandidate != nil {
                        Section(LT("确认导入信息（支持二次修改）", "确认导入信息（支持二次修改）", "取り込み情報を確認（二次編集可）")) {
                            if isLoadingDiscogsDetail {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(LT("正在读取 Discogs 详情并自动填充...", "正在读取 Discogs 详情并自动填充...", "Discogs詳細を読み込んで自動入力中..."))
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                            }

                            TextField(LT("DJ 名称", "DJ 名称", "DJ名"), text: $discogsDraftName)
                            TextField(LT("别名（英文逗号分隔）", "别名（英文逗号分隔）", "別名（半角カンマ区切り）"), text: $discogsDraftAliases)
                            TextField(LT("简介", "简介", "紹介"), text: $discogsDraftBio, axis: .vertical)
                            TextField(LT("国家（可选）", "国家（可选）", "国（任意）"), text: $discogsDraftCountry)
                            TextField(LT("Instagram（可选）", "Instagram（可选）", "Instagram（任意）"), text: $discogsDraftInstagram)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            TextField(LT("SoundCloud（可选）", "SoundCloud（可选）", "SoundCloud（任意）"), text: $discogsDraftSoundcloud)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            TextField(LT("X/Twitter（可选）", "X/Twitter（可选）", "X/Twitter（任意）"), text: $discogsDraftTwitter)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            TextField(LT("Spotify ID（可选）", "Spotify ID（可选）", "Spotify ID（任意）"), text: $discogsDraftSpotifyID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)

                            if let selectedDiscogsCandidate,
                               let existingName = selectedDiscogsCandidate.existingDJName,
                               !existingName.isEmpty {
                                Text(LT("检测到同名 DJ：\(existingName)，导入时将合并更新，不会重复创建。", "Matched existing same-name DJ: \(existingName). Import will merge update instead of creating duplicate.", "同名DJ「\(existingName)」を検出しました。取り込み時に統合更新され、重複作成されません。"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }

                        Section(LT("关联 Spotify（可选）", "关联 Spotify（可选）", "Spotify連携（任意）")) {
                            HStack(spacing: 8) {
                                TextField(LT("搜索 Spotify 用于补全链接", "搜索 Spotify 用于补全链接", "リンク補完用にSpotifyを検索"), text: $discogsLinkedSpotifyKeyword)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(true)
                                    .onSubmit {
                                        Task { await searchDiscogsLinkedSpotifyCandidates() }
                                    }

                                Button(isSearchingDiscogsLinkedSpotify ? LT("搜索中...", "Searching...", "検索中...") : "搜索") {
                                    Task { await searchDiscogsLinkedSpotifyCandidates() }
                                }
                                .disabled(isSearchingDiscogsLinkedSpotify || discogsLinkedSpotifyKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            if isSearchingDiscogsLinkedSpotify {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(LT("正在搜索 Spotify...", "正在搜索 Spotify...", "Spotifyを検索中..."))
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                            }

                            if !discogsLinkedSpotifyCandidates.isEmpty {
                                ForEach(discogsLinkedSpotifyCandidates) { candidate in
                                    Button {
                                        applyDiscogsLinkedSpotifyCandidate(candidate)
                                    } label: {
                                        spotifyCandidateRow(
                                            candidate,
                                            selectedSpotifyId: selectedDiscogsLinkedSpotifyCandidate?.spotifyId
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if let selectedDiscogsLinkedSpotifyCandidate {
                                Text(LT("已关联 Spotify：\(selectedDiscogsLinkedSpotifyCandidate.name)", "Linked Spotify: \(selectedDiscogsLinkedSpotifyCandidate.name)", "関連Spotify: \(selectedDiscogsLinkedSpotifyCandidate.name)"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                } else {
                    Section(LT("手动填写 DJ 信息", "手动填写 DJ 信息", "DJ情報を手動入力")) {
                        TextField(LT("DJ 名称（必填）", "DJ 名称（必填）", "DJ名（必須）"), text: $manualName)
                        TextField(LT("别名（英文逗号分隔）", "别名（英文逗号分隔）", "別名（半角カンマ区切り）"), text: $manualAliases)
                        TextField(LT("国家（可选）", "国家（可选）", "国（任意）"), text: $manualCountry)
                        TextField(LT("Instagram（可选）", "Instagram（可选）", "Instagram（任意）"), text: $manualInstagram)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField(LT("SoundCloud（可选）", "SoundCloud（可选）", "SoundCloud（任意）"), text: $manualSoundcloud)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField(LT("X/Twitter（可选）", "X/Twitter（可选）", "X/Twitter（任意）"), text: $manualTwitter)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField(LT("简介（可选）", "简介（可选）", "紹介（任意）"), text: $manualBio, axis: .vertical)
                    }

                    Section(LT("图片（上传到 OSS 的 DJ 文件夹）", "图片（上传到 OSS 的 DJ 文件夹）", "画像（OSSのDJフォルダにアップロード）")) {
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $manualAvatarItem, matching: .images) {
                                Label(LT("选择头像", "选择头像", "アバターを選択"), systemImage: "person.crop.circle")
                            }
                            .buttonStyle(.bordered)

                            if let manualAvatarData, let image = UIImage(data: manualAvatarData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            }
                        }

                        HStack(spacing: 12) {
                            PhotosPicker(selection: $manualBannerItem, matching: .images) {
                                Label(LT("选择横幅", "选择横幅", "バナーを選択"), systemImage: "photo.rectangle")
                            }
                            .buttonStyle(.bordered)

                            if let manualBannerData, let image = UIImage(data: manualBannerData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 88, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }

                Section {
                    Button(isImportingDJ ? LT("导入中...", "Importing...", "取り込み中...") : LT("确认导入到 DJ 数据库", "Confirm import to DJ database", "DJデータベースへの取り込みを確認")) {
                        Task { await confirmDJImport() }
                    }
                    .disabled(isImportingDJ || isImportConfirmDisabled)
                }
            }
            .raverSystemNavigation(title: LT("导入 DJ", "导入 DJ", "DJを取り込み"))
            .scrollDismissesKeyboard(.interactively)
            .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
                get: { djImportSuccessMessage != nil },
                set: { if !$0 { djImportSuccessMessage = nil } }
            )) {
                Button(LT("确定", "OK", "OK"), role: .cancel) {
                    finishDJImportSuccessDismissal()
                }
            } message: {
                Text(djImportSuccessMessage ?? "")
            }
    }

    private var isImportConfirmDisabled: Bool {
        switch importMode {
        case .spotify:
            return selectedSpotifyCandidate == nil
                || spotifyDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .discogs:
            return selectedDiscogsCandidate == nil
                || discogsDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .manual:
            return manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @MainActor
    private func searchSpotifyCandidates() async {
        let keyword = spotifySearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            spotifyCandidates = []
            selectedSpotifyCandidate = nil
            return
        }

        isSearchingSpotify = true
        defer { isSearchingSpotify = false }

        do {
            let items = try await djImportRepository.searchSpotifyDJs(query: keyword, limit: 10)
            spotifyCandidates = items
            if let first = items.first {
                applySpotifyCandidate(first)
            } else {
                selectedSpotifyCandidate = nil
            }
        } catch {
            errorMessage = LT("Spotify 搜索失败：\(error.userFacingMessage ?? "")", "Spotify search failed: \(error.userFacingMessage ?? "")", "Spotify検索に失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    @MainActor
    private func searchDiscogsCandidates() async {
        let keyword = discogsSearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            discogsCandidates = []
            selectedDiscogsCandidate = nil
            return
        }

        isSearchingDiscogs = true
        defer { isSearchingDiscogs = false }

        do {
            let items = try await djImportRepository.searchDiscogsDJs(query: keyword, limit: 12)
            discogsCandidates = items
            if let first = items.first {
                applyDiscogsCandidate(first)
            } else {
                selectedDiscogsCandidate = nil
            }
        } catch {
            errorMessage = LT("Discogs 搜索失败：\(error.userFacingMessage ?? "")", "Discogs search failed: \(error.userFacingMessage ?? "")", "Discogs検索に失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    @MainActor
    private func searchDiscogsLinkedSpotifyCandidates() async {
        let keyword = discogsLinkedSpotifyKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            discogsLinkedSpotifyCandidates = []
            return
        }

        isSearchingDiscogsLinkedSpotify = true
        defer { isSearchingDiscogsLinkedSpotify = false }

        do {
            let items = try await djImportRepository.searchSpotifyDJs(query: keyword, limit: 8)
            discogsLinkedSpotifyCandidates = items
        } catch {
            errorMessage = LT("Spotify 搜索失败：\(error.userFacingMessage ?? "")", "Spotify search failed: \(error.userFacingMessage ?? "")", "Spotify検索に失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    private func applySpotifyCandidate(_ candidate: SpotifyDJCandidate) {
        selectedSpotifyCandidate = candidate
        spotifyDraftName = candidate.name
        spotifyDraftAliases = ""
        spotifyDraftCountry = ""
        if candidate.genres.isEmpty {
            spotifyDraftBio = ""
        } else {
            spotifyDraftBio = "Spotify genres: \(candidate.genres.prefix(4).joined(separator: ", "))"
        }
    }

    private func applyDiscogsCandidate(_ candidate: DiscogsDJCandidate) {
        selectedDiscogsCandidate = candidate
        discogsDraftName = candidate.name
        discogsDraftAliases = ""
        discogsDraftBio = ""
        discogsDraftCountry = ""
        discogsDraftInstagram = ""
        discogsDraftSoundcloud = ""
        discogsDraftTwitter = ""
        discogsDraftSpotifyID = ""
        selectedDiscogsLinkedSpotifyCandidate = nil
        discogsLinkedSpotifyCandidates = []
        discogsLinkedSpotifyKeyword = ""
        Task { await loadDiscogsCandidateDetail(artistId: candidate.artistId) }
    }

    private func applyDiscogsLinkedSpotifyCandidate(_ candidate: SpotifyDJCandidate) {
        selectedDiscogsLinkedSpotifyCandidate = candidate
        discogsDraftSpotifyID = candidate.spotifyId
    }

    @MainActor
    private func loadDiscogsCandidateDetail(artistId: Int) async {
        isLoadingDiscogsDetail = true
        defer { isLoadingDiscogsDetail = false }

        do {
            let detail = try await djImportRepository.fetchDiscogsDJArtist(id: artistId)
            if !detail.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                discogsDraftName = detail.name
            }
            discogsDraftAliases = buildDiscogsAliasesText(from: detail)
            discogsDraftBio = detail.profile ?? ""
            discogsDraftInstagram = pickSocialURL(from: detail.urls, hosts: ["instagram.com"]) ?? ""
            discogsDraftSoundcloud = pickSocialURL(from: detail.urls, hosts: ["soundcloud.com"]) ?? ""
            discogsDraftTwitter = pickSocialURL(from: detail.urls, hosts: ["twitter.com", "x.com"]) ?? ""
            if let linkedSpotify = selectedDiscogsLinkedSpotifyCandidate {
                discogsDraftSpotifyID = linkedSpotify.spotifyId
            }
        } catch {
            errorMessage = LT("读取 Discogs 详情失败：\(error.userFacingMessage ?? "")", "Failed to load Discogs detail: \(error.userFacingMessage ?? "")", "Discogs詳細の読み込みに失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    @ViewBuilder
    private func spotifyCandidateRow(_ candidate: SpotifyDJCandidate, selectedSpotifyId: String?) -> some View {
        HStack(spacing: 10) {
            Group {
                if let imageURL = AppConfig.resolvedURLString(candidate.imageUrl) {
                    ImageLoaderView(urlString: imageURL)
                        .background(Circle().fill(RaverTheme.card))
                } else {
                    Circle().fill(RaverTheme.card)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(LT("粉丝 \(candidate.followers)", "Followers \(candidate.followers)", "フォロワー \(candidate.followers)"))
                    Text(LT("热度 \(candidate.popularity)", "Popularity \(candidate.popularity)", "人気度 \(candidate.popularity)"))
                }
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)

                if let existingName = candidate.existingDJName, !existingName.isEmpty {
                    Text(LT("将合并到：\(existingName)", "Will merge into: \(existingName)", "\(existingName) に統合されます"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.orange)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if selectedSpotifyId == candidate.spotifyId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func discogsCandidateRow(_ candidate: DiscogsDJCandidate) -> some View {
        HStack(spacing: 10) {
            Group {
                if let thumb = AppConfig.resolvedURLString(candidate.thumbUrl) {
                    ImageLoaderView(urlString: thumb)
                        .background(Circle().fill(RaverTheme.card))
                } else if let cover = AppConfig.resolvedURLString(candidate.coverImageUrl) {
                    ImageLoaderView(urlString: cover)
                        .background(Circle().fill(RaverTheme.card))
                } else {
                    Circle().fill(RaverTheme.card)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)

                Text(LT("Discogs ID \(candidate.artistId)", "Discogs ID \(candidate.artistId)", "Discogs ID \(candidate.artistId)"))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)

                if let existingName = candidate.existingDJName, !existingName.isEmpty {
                    Text(LT("将合并到：\(existingName)", "Will merge into: \(existingName)", "\(existingName) に統合されます"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.orange)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if selectedDiscogsCandidate?.artistId == candidate.artistId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
        }
        .contentShape(Rectangle())
    }

    @MainActor
    private func confirmDJImport() async {
        switch importMode {
        case .spotify:
            await confirmSpotifyImport()
        case .discogs:
            await confirmDiscogsImport()
        case .manual:
            await confirmManualImport()
        }
    }

    @MainActor
    private func confirmSpotifyImport() async {
        guard let selected = selectedSpotifyCandidate else {
            errorMessage = LT("请先选择一个 Spotify DJ", "Please select a Spotify DJ first.", "先にSpotify DJを選択してください。")
            return
        }
        let finalName = spotifyDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = LT("DJ 名称不能为空", "DJ name cannot be empty.", "DJ名を入力してください。")
            return
        }

        let aliases = spotifyDraftAliases
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let bio = spotifyDraftBio.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = spotifyDraftCountry.trimmingCharacters(in: .whitespacesAndNewlines)

        isImportingDJ = true
        defer { isImportingDJ = false }

        do {
            let result = try await djImportRepository.importSpotifyDJ(
                input: ImportSpotifyDJInput(
                    spotifyId: selected.spotifyId,
                    name: finalName,
                    aliases: aliases.isEmpty ? nil : aliases,
                    bio: bio.isEmpty ? nil : bio,
                    country: country.isEmpty ? nil : country,
                    instagramUrl: nil,
                    soundcloudUrl: nil,
                    twitterUrl: nil,
                    isVerified: true
                )
            )
            switch result {
            case .submittedForReview:
                completeDJImportSuccess()
            case .imported:
                await viewModel.reload()
                completeDJImportSuccess(message: LT("DJ 信息已保存", "DJ saved", "DJ情報を保存しました"))
            }
        } catch {
            errorMessage = LT("导入失败：\(error.userFacingMessage ?? "")", "Import failed: \(error.userFacingMessage ?? "")", "取り込みに失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    @MainActor
    private func confirmDiscogsImport() async {
        guard let selected = selectedDiscogsCandidate else {
            errorMessage = LT("请先选择一个 Discogs DJ", "Please select a Discogs DJ first.", "先にDiscogs DJを選択してください。")
            return
        }
        let finalName = discogsDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = LT("DJ 名称不能为空", "DJ name cannot be empty.", "DJ名を入力してください。")
            return
        }

        let aliases = discogsDraftAliases
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let bio = normalizedOptionalString(discogsDraftBio)
        let country = normalizedOptionalString(discogsDraftCountry)
        let instagram = normalizedOptionalString(discogsDraftInstagram)
        let soundcloud = normalizedOptionalString(discogsDraftSoundcloud)
        let twitter = normalizedOptionalString(discogsDraftTwitter)
        let spotifyID = normalizedOptionalString(discogsDraftSpotifyID) ?? selectedDiscogsLinkedSpotifyCandidate?.spotifyId

        isImportingDJ = true
        defer { isImportingDJ = false }

        do {
            let result = try await djImportRepository.importDiscogsDJ(
                input: ImportDiscogsDJInput(
                    discogsArtistId: selected.artistId,
                    name: finalName,
                    aliases: aliases,
                    bio: bio,
                    country: country,
                    instagramUrl: instagram,
                    soundcloudUrl: soundcloud,
                    twitterUrl: twitter,
                    spotifyId: spotifyID,
                    isVerified: true
                )
            )
            switch result {
            case .submittedForReview:
                completeDJImportSuccess()
            case .imported:
                await viewModel.reload()
                completeDJImportSuccess(message: LT("DJ 信息已保存", "DJ saved", "DJ情報を保存しました"))
            }
        } catch {
            errorMessage = LT("Discogs 导入失败：\(error.userFacingMessage ?? "")", "Discogs import failed: \(error.userFacingMessage ?? "")", "Discogs取り込みに失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    @MainActor
    private func confirmManualImport() async {
        let finalName = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = LT("DJ 名称不能为空", "DJ name cannot be empty.", "DJ名を入力してください。")
            return
        }

        let aliases = manualAliases
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let country = normalizedOptionalString(manualCountry)
        let bio = normalizedOptionalString(manualBio)
        let instagram = normalizedOptionalString(manualInstagram)
        let soundcloud = normalizedOptionalString(manualSoundcloud)
        let twitter = normalizedOptionalString(manualTwitter)

        isImportingDJ = true
        defer { isImportingDJ = false }

        do {
            let result = try await djImportRepository.importManualDJ(
                input: ImportManualDJInput(
                    name: finalName,
                    spotifyId: nil,
                    aliases: aliases.isEmpty ? nil : aliases,
                    bio: bio,
                    country: country,
                    instagramUrl: instagram,
                    soundcloudUrl: soundcloud,
                    twitterUrl: twitter,
                    isVerified: true
                )
            )

            guard case .imported(let imported) = result else {
                completeDJImportSuccess()
                return
            }

            if let manualAvatarData {
                _ = try await djMediaRepository.uploadDJImage(
                    imageData: jpegDataForDJImport(from: manualAvatarData),
                    fileName: "dj-avatar-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    djID: imported.dj.id,
                    usage: "avatar"
                )
            }

            if let manualBannerData {
                _ = try await djMediaRepository.uploadDJImage(
                    imageData: jpegDataForDJImport(from: manualBannerData),
                    fileName: "dj-banner-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    djID: imported.dj.id,
                    usage: "banner"
                )
            }

            await viewModel.reload()
            completeDJImportSuccess(message: LT("DJ 信息已保存", "DJ saved", "DJ情報を保存しました"))
        } catch {
            errorMessage = LT("手动导入失败：\(error.userFacingMessage ?? "")", "Manual import failed: \(error.userFacingMessage ?? "")", "手動取り込みに失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    @MainActor
    private func completeDJImportSuccess(message: String = LT("DJ 信息已提交审核", "DJ submitted for review", "DJ情報を審査に送信しました")) {
        errorMessage = nil
        viewModel.errorMessage = nil
        djImportSuccessMessage = message
    }

    @MainActor
    private func finishDJImportSuccessDismissal() {
        djImportSuccessMessage = nil
        showDJImportSheet = false
        guard dismissAfterSuccessfulImport else { return }
        dismiss()
    }

    private func buildDiscogsAliasesText(from detail: DiscogsDJArtistDetail) -> String {
        var values: [String] = []
        values.append(contentsOf: detail.nameVariations)
        values.append(contentsOf: detail.aliases)
        values.append(contentsOf: detail.groups)
        if let realName = detail.realName, !realName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            values.append(realName)
        }

        var deduplicated: [String] = []
        var seen = Set<String>()
        let normalizedPrimary = detail.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for item in values {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard key != normalizedPrimary else { continue }
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            deduplicated.append(trimmed)
        }
        return deduplicated.joined(separator: ", ")
    }

    private func pickSocialURL(from urls: [String], hosts: [String]) -> String? {
        for raw in urls {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let parsed = URL(string: trimmed) else { continue }
            let host = parsed.host?.lowercased() ?? ""
            if hosts.contains(where: { host.contains($0.lowercased()) }) {
                return trimmed
            }
        }
        return nil
    }

    private enum ManualPhotoTarget {
        case avatar
        case banner
    }

    @MainActor
    private func loadManualPhoto(_ item: PhotosPickerItem?, target: ManualPhotoTarget) async {
        guard let item else {
            switch target {
            case .avatar:
                manualAvatarData = nil
            case .banner:
                manualBannerData = nil
            }
            return
        }
        do {
            let loaded = try await item.loadTransferable(type: Data.self)
            switch target {
            case .avatar:
                manualAvatarData = loaded
            case .banner:
                manualBannerData = loaded
            }
        } catch {
            errorMessage = LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像を読み込めませんでした。もう一度お試しください。")
        }
    }

    private func normalizedOptionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func jpegDataForDJImport(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }
}

private enum DJsImportMode: String, CaseIterable, Identifiable {
    case spotify
    case discogs
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spotify: return LT("Spotify 导入", "Import from Spotify", "Spotifyから取り込み")
        case .discogs: return LT("Discogs 导入", "Import from Discogs", "Discogsから取り込み")
        case .manual: return LT("手动导入", "Manual Import", "手動取り込み")
        }
    }
}

struct RankingBoardCoverCard: View {
    let board: RankingBoard
    private let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        GeometryReader { proxy in
            let imageSize = proxy.size.width // 正方形边长 = 容器宽度

            VStack(spacing: 0) {
                // ── 上半部分：正方形图片区 ──────────────────
                ZStack {
                    boardCoverLayer
                        .frame(width: imageSize, height: imageSize)
                        .clipped() // 裁剪超出正方形的图片内容
                }
                .frame(width: imageSize, height: imageSize)
                .contentShape(Rectangle()) // 点击区域限制在正方形内

                // ── 下半部分：文字信息区 ────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text(board.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(board.subtitle ?? board.defaultSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)

                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground)) // 或你想要的背景色
            }
        }
        .clipShape(cardShape)          // 整体圆角裁剪（同时裁展示和点击）
        .contentShape(cardShape)       // 确保点击区域也是圆角
        .overlay(
            cardShape
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var boardCoverLayer: some View {
        if let coverImageUrl = board.coverImageUrl {
            ImageLoaderView(urlString: coverImageUrl)
                .background(boardFallbackCover)
        } else {
            boardFallbackCover
        }
    }

    private var boardFallbackCover: some View {
        ZStack {
            boardGradient
            Circle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 90, height: 90)
                .blur(radius: 8)
                .offset(x: 36, y: -24)
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 120, height: 120)
                .blur(radius: 10)
                .offset(x: -44, y: 42)
            Text(board.shortMark)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }

    private var boardGradient: LinearGradient {
        switch board.id {
        case "djmag":
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.20, blue: 0.33), Color(red: 0.52, green: 0.12, blue: 0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "dongye":
            return LinearGradient(
                colors: [Color(red: 0.17, green: 0.53, blue: 0.98), Color(red: 0.11, green: 0.77, blue: 0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(red: 0.35, green: 0.35, blue: 0.40), Color(red: 0.15, green: 0.17, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct DJSpotlightCarouselSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let djs: [WebDJ]
    let onSelect: (WebDJ) -> Void
    let onHorizontalDragStateChanged: ((Bool) -> Void)?

    @State private var currentIndex: Int = 0
    @State private var carouselSelection: Int
    @State private var backgroundCurrentIndex: Int = 0
    @State private var backgroundOutgoingIndex: Int?
    @State private var backgroundSlideProgress: CGFloat = 0
    @State private var backgroundDirection: CGFloat = 1
    @State private var lastCarouselSelection: Int
    @State private var backgroundTransitionToken: Int = 0

    private let carouselLiftHeadroom: CGFloat = 60

    init(
        djs: [WebDJ],
        onSelect: @escaping (WebDJ) -> Void,
        onHorizontalDragStateChanged: ((Bool) -> Void)? = nil
    ) {
        self.djs = djs
        self.onSelect = onSelect
        self.onHorizontalDragStateChanged = onHorizontalDragStateChanged

        let initialSelection = djs.count >= 3 ? 2 : (djs.count > 1 ? 1 : 0)
        _carouselSelection = State(initialValue: initialSelection)
        _lastCarouselSelection = State(initialValue: initialSelection)
    }

    var body: some View {
        GeometryReader { rootProxy in
            let size = rootProxy.size

            ZStack(alignment: .top) {
                GeometryReader { proxy in
                    ZStack {
                        if let outgoingIndex = backgroundOutgoingIndex, djs.indices.contains(outgoingIndex) {
                            backgroundImage(for: djs[outgoingIndex], in: proxy.size)
                                .offset(x: -backgroundDirection * (1 - backgroundSlideProgress) * proxy.size.width)
                        }

                        if djs.indices.contains(backgroundCurrentIndex) {
                            backgroundImage(for: djs[backgroundCurrentIndex], in: proxy.size)
                                .offset(x: backgroundDirection * backgroundSlideProgress * proxy.size.width)
                        }
                    }
                    .clipped()
                }
                .overlay(
                    LinearGradient(
                        colors: bottomFadeColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    DJSpotlightBackgroundOverlay()
                }
                .onAppear {
                    backgroundCurrentIndex = currentIndex
                    lastCarouselSelection = carouselSelection
                }
                .onChange(of: carouselSelection) { _, newValue in
                    let previousSelection = lastCarouselSelection
                    lastCarouselSelection = newValue

                    let mappedIndex = realIndex(for: newValue)
                    let direction: CGFloat = newValue >= previousSelection ? 1 : -1

                    if mappedIndex != backgroundCurrentIndex {
                        startBackgroundTransition(to: mappedIndex, direction: direction)
                    }
                }

                RaverSnapCarousel(
                    spacing: 15,
                    trailingSpace: carouselTrailingSpace(for: size),
                    topInset: carouselLiftHeadroom,
                    selection: $carouselSelection,
                    index: $currentIndex,
                    items: djs,
                    onHorizontalDragStateChanged: onHorizontalDragStateChanged
                ) { dj, phase in
                    spotlightCard(for: dj, containerSize: size, phase: phase)
                }
                .frame(height: cardHeight(for: size) + carouselLiftHeadroom)
                .offset(y: carouselVerticalOffset(for: size))
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var bottomFadeColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.clear,
                RaverTheme.background.opacity(0.18),
                RaverTheme.background.opacity(0.46),
                RaverTheme.background.opacity(0.90),
                RaverTheme.background
            ]
        }

        return [
            Color.clear,
            Color.white.opacity(0.16),
            Color.white.opacity(0.40),
            Color(red: 0.985, green: 0.985, blue: 0.995).opacity(0.88),
            Color(red: 0.97, green: 0.97, blue: 0.985)
        ]
    }

    private var spotlightPrimaryTextColor: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.90)
    }

    private var spotlightSecondaryTextColor: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.72)
    }

    private var spotlightSectionHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        switch screenHeight {
        case ..<700:
            return 500
        case ..<800:
            return 560
        case ..<900:
            return 620
        default:
            return 680
        }
    }

    private func carouselTrailingSpace(for size: CGSize) -> CGFloat {
        size.height < 750 ? 108 : 148
    }

    private func cardHeight(for size: CGSize) -> CGFloat {
        min(size.height * 0.72, 560)
    }

    private func imageSide(for size: CGSize) -> CGFloat {
        let cardWidth = size.width - carouselTrailingSpace(for: size)
        return max(cardWidth - 30, 0)
    }

    private func carouselVerticalOffset(for size: CGSize) -> CGFloat {
        let imageTopPadding: CGFloat = 15
        let imageCenterInCard = imageTopPadding + (imageSide(for: size) / 2)
        let activeCardLift: CGFloat = 60
        let visualCenterAdjustment: CGFloat = -18
        return (cardHeight(for: size) / 2) - imageCenterInCard + activeCardLift + visualCenterAdjustment
    }

    private func realIndex(for selection: Int) -> Int {
        guard !djs.isEmpty else { return 0 }

        let mappedIndices: [Int]
        if djs.count >= 3 {
            mappedIndices = [djs.count - 2, djs.count - 1] + Array(djs.indices) + [0, 1]
        } else if djs.count > 1 {
            mappedIndices = [djs.count - 1] + Array(djs.indices) + [0]
        } else {
            mappedIndices = Array(djs.indices)
        }

        guard mappedIndices.indices.contains(selection) else {
            return max(0, min(currentIndex, djs.count - 1))
        }

        return mappedIndices[selection]
    }

    private func startBackgroundTransition(to newIndex: Int, direction: CGFloat) {
        guard backgroundCurrentIndex != newIndex else { return }

        backgroundTransitionToken += 1
        let token = backgroundTransitionToken

        backgroundOutgoingIndex = backgroundCurrentIndex
        backgroundCurrentIndex = newIndex
        backgroundDirection = direction
        backgroundSlideProgress = 1

        withAnimation(.easeInOut(duration: 0.42)) {
            backgroundSlideProgress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + ) {
            guard token == backgroundTransitionToken else { return }
            backgroundOutgoingIndex = nil
        }
    }

    @ViewBuilder
    private func backgroundImage(for dj: WebDJ, in size: CGSize) -> some View {
        Group {
            if let urlString = djSpotlightBackgroundURL(for: dj) {
                ImageLoaderView(
                    urlString: urlString,
                    resizingMode: .fill,
                    showsIndicator: false
                )
            } else {
                spotlightFallbackBackground(for: dj)
            }
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(1.08)
        .saturation(1.24)
        .contrast(1.06)
        .blur(radius: 18)
        .offset(y: -96)
    }

    @ViewBuilder
    private func spotlightCard(for dj: WebDJ, containerSize: CGSize, phase: RaverCarouselItemPhase) -> some View {
        GeometryReader { cardProxy in
            let imageSide = max(cardProxy.size.width - 30, 0)
            let textReveal = phase.revealProgress
            let textOffset = (1 - textReveal) * 26
            let textBlur = (1 - textReveal) * 10
            let textScale = 0.94 + (textReveal * 0.06)

            Button {
                onSelect(dj)
            } label: {
                VStack(spacing: 10) {
                    spotlightArtwork(for: dj)
                        .frame(width: imageSide, height: imageSide)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.24), radius: 34, x: 0, y: 22)
                        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
                        .shadow(color: Color.white.opacity(0.08), radius: 2, x: 0, y: 1)
                        .padding(.bottom, 15)

                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Text(dj.name)
                                .font(.title3.bold())
                            if dj.isVerified == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.30, green: 0.93, blue: 0.82))
                            }
                        }
                        .multilineTextAlignment(.center)

                        HStack(spacing: 14) {
                            Label(spotlightEventCountText(for: dj), systemImage: "calendar")
                            Label(spotlightSetCountText(for: dj), systemImage: "play.rectangle.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(spotlightSecondaryTextColor)

                        Text(spotlightSummary(for: dj))
                            .font(.callout)
                            .lineLimit(containerSize.height < 750 ? 2 : 3)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .padding(.horizontal)
                    }
                    .foregroundColor(spotlightPrimaryTextColor)
                    .opacity(textReveal)
                    .offset(y: textOffset)
                    .scaleEffect(textScale, anchor: .top)
                    .blur(radius: textBlur)
                    .transaction { transaction in
                        if phase.suppressRevealAnimation {
                            transaction.animation = nil
                        }
                    }
                    .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86), value: textReveal)

                    Spacer(minLength: 0)
                }
                .frame(width: cardProxy.size.width, height: cardProxy.size.height, alignment: .top)
            }
            .buttonStyle(.plain)
        }
        .frame(height: cardHeight(for: containerSize))
    }

    @ViewBuilder
    private func spotlightArtwork(for dj: WebDJ) -> some View {
        Group {
            if let urlString = djSpotlightArtworkURL(for: dj) {
                ImageLoaderView(
                    urlString: urlString,
                    resizingMode: .fill,
                    showsIndicator: false
                )
                .background(spotlightFallbackBackground(for: dj))
            } else {
                spotlightFallbackBackground(for: dj)
            }
        }
    }

    private func spotlightFallbackBackground(for dj: WebDJ) -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.21, blue: 0.46),
                Color(red: 0.16, green: 0.62, blue: 0.78),
                Color(red: 0.06, green: 0.11, blue: 0.26)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Text(initials(of: dj.name))
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }

    private func spotlightEventCountText(for dj: WebDJ) -> String {
        let eventCount = max(dj.eventCount ?? 0, dj.eventsCount ?? 0, dj.upcomingShows ?? 0)
        return LT("\(eventCount) 场活动", "\(eventCount) events", "\(eventCount)件のイベント")
    }

    private func spotlightSetCountText(for dj: WebDJ) -> String {
        let setCount = max(dj.setCount ?? 0, dj.setsCount ?? 0, dj.djSetCount ?? 0)
        return LT("\(setCount) 个 Sets", "\(setCount) sets", "\(setCount)件のSet")
    }

    private func spotlightSummary(for dj: WebDJ) -> String {
        if let bio = dj.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
            return bio
        }
        if let country = dj.country, !country.isEmpty {
            return LT("\(country) DJ，持续活跃在当下电子音乐现场。", "\(country)-based electronic artist with a strong current presence.", "\(country)のDJ。現在の電子音楽シーンで精力的に活動しています。")
        }
        return LT("持续活跃在当下电子音乐现场，值得继续深入探索。", "A standout electronic artist worth diving into.", "現在の電子音楽シーンで活躍している、さらに深く知りたいアーティストです。")
    }
}

private struct DJSpotlightBackgroundOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: primaryAtmosphereColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: verticalDepthColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: accentGlowColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .allowsHitTesting(false)
    }

    private var primaryAtmosphereColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black.opacity(0.20),
                Color(red: 0.01, green: 0.05, blue: 0.10).opacity(0.34),
                Color(red: 0.01, green: 0.03, blue: 0.08).opacity(0.58)
            ]
        }

        return [
            Color.white.opacity(0.06),
            Color(red: 0.88, green: 0.94, blue: 1.00).opacity(0.22),
            Color(red: 0.82, green: 0.89, blue: 0.98).opacity(0.34)
        ]
    }

    private var verticalDepthColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.clear,
                Color.black.opacity(0.12),
                Color.black.opacity(0.26)
            ]
        }

        return [
            Color.white.opacity(0.02),
            Color.white.opacity(0.08),
            Color(red: 0.92, green: 0.95, blue: 0.99).opacity(0.22)
        ]
    }

    private var accentGlowColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.82, blue: 0.92).opacity(0.10),
                Color.clear,
                Color(red: 0.10, green: 0.22, blue: 0.76).opacity(0.16)
            ]
        }

        return [
            Color(red: 0.52, green: 0.86, blue: 0.98).opacity(0.12),
            Color.clear,
            Color(red: 0.56, green: 0.68, blue: 0.98).opacity(0.12)
        ]
    }
}

private func djSpotlightArtworkURL(for dj: WebDJ) -> String? {
    if let avatar = AppConfig.resolvedDJAvatarURLString(dj.avatarOriginalUrl ?? dj.avatarUrl, size: .original),
       !avatar.isEmpty {
        return highResAvatarURL(avatar)
    }
    if let banner = AppConfig.resolvedURLString(dj.bannerUrl), !banner.isEmpty {
        return highResAvatarURL(banner)
    }
    return nil
}

private func djSpotlightBackgroundURL(for dj: WebDJ) -> String? {
    if let banner = AppConfig.resolvedURLString(dj.bannerUrl), !banner.isEmpty {
        return highResAvatarURL(banner)
    }
    if let avatar = AppConfig.resolvedDJAvatarURLString(dj.avatarOriginalUrl ?? dj.avatarUrl, size: .original),
       !avatar.isEmpty {
        return highResAvatarURL(avatar)
    }
    return nil
}

private func compactDJCount(_ value: Int) -> String {
    let absolute = abs(Double(value))
    let sign = value < 0 ? "-" : ""

    switch absolute {
    case 1_000_000...:
        return "\(sign)\(trimTrailingZero((absolute / 1_000_000).appLocalizedNumberText(maximumFractionDigits: 1)))M"
    case 1_000...:
        return "\(sign)\(trimTrailingZero((absolute / 1_000).appLocalizedNumberText(maximumFractionDigits: 1)))K"
    default:
        return value.appLocalizedNumberText()
    }
}

private func trimTrailingZero(_ value: String) -> String {
    if value.hasSuffix(".0") {
        return String(value.dropLast(2))
    }
    return value
}

private struct DJWebMarqueeWall: View {
    let rows: [[WebDJ]]
    let onSelect: (WebDJ) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = DJWebMarqueeMetrics.make(containerHeight: proxy.size.height, rowCount: max(1, rows.count))

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.04, blue: 0.08), Color(red: 0.02, green: 0.06, blue: 0.13), Color(red: 0.03, green: 0.02, blue: 0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.cyan.opacity(0.22))
                    .frame(width: metrics.glowPrimarySize, height: metrics.glowPrimarySize)
                    .blur(radius: metrics.glowPrimaryBlur)
                    .offset(x: -metrics.glowPrimaryOffsetX, y: -metrics.glowPrimaryOffsetY)

                Circle()
                    .fill(Color.purple.opacity(0.24))
                    .frame(width: metrics.glowSecondarySize, height: metrics.glowSecondarySize)
                    .blur(radius: metrics.glowSecondaryBlur)
                    .offset(x: metrics.glowSecondaryOffsetX, y: metrics.glowSecondaryOffsetY)

                VStack(spacing: metrics.rowSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        DJWebMarqueeRow(
                            items: row,
                            reverse: index % 2 == 1,
                            speed: speed(for: index),
                            rowHeight: metrics.rowHeight,
                            avatarSize: metrics.avatarSize,
                            avatarHorizontalSpacing: metrics.avatarHorizontalSpacing,
                            onSelect: onSelect
                        )
                    }
                }
                .padding(.top, metrics.topInset)
            }
        }
    }

    private struct DJWebMarqueeMetrics {
        let avatarSize: CGFloat
        let avatarHorizontalSpacing: CGFloat
        let rowHeight: CGFloat
        let rowSpacing: CGFloat
        let topInset: CGFloat
        let glowPrimarySize: CGFloat
        let glowPrimaryBlur: CGFloat
        let glowPrimaryOffsetX: CGFloat
        let glowPrimaryOffsetY: CGFloat
        let glowSecondarySize: CGFloat
        let glowSecondaryBlur: CGFloat
        let glowSecondaryOffsetX: CGFloat
        let glowSecondaryOffsetY: CGFloat

        static func make(containerHeight: CGFloat, rowCount: Int) -> DJWebMarqueeMetrics {
            let safeHeight = max(360, containerHeight)
            let avatar = max(54, min(74, safeHeight / 8.4))
            let rowHeight = avatar + 26
            let estimatedSpacing = (safeHeight - CGFloat(rowCount) * rowHeight - 20) / CGFloat(max(1, rowCount - 1))
            let rowSpacing = max(8, min(26, estimatedSpacing))
            let topInset = max(10, min(20, safeHeight * 0.03))
            return DJWebMarqueeMetrics(
                avatarSize: avatar,
                avatarHorizontalSpacing: max(6, min(12, avatar * 0.13)),
                rowHeight: rowHeight,
                rowSpacing: rowSpacing,
                topInset: topInset,
                glowPrimarySize: max(180, min(260, safeHeight * 0.42)),
                glowPrimaryBlur: max(60, min(86, safeHeight * 0.15)),
                glowPrimaryOffsetX: 110,
                glowPrimaryOffsetY: 96,
                glowSecondarySize: max(220, min(320, safeHeight * 0.52)),
                glowSecondaryBlur: max(70, min(98, safeHeight * 0.17)),
                glowSecondaryOffsetX: 132,
                glowSecondaryOffsetY: 152
            )
        }
    }

    private func speed(for rowIndex: Int) -> Double {
        switch rowIndex {
        case 0: return 34
        case 1: return 40
        case 2: return 36
        default: return 44
        }
    }
}

private struct DJWebMarqueeRow: View {
    let items: [WebDJ]
    let reverse: Bool
    let speed: Double
    let rowHeight: CGFloat
    let avatarSize: CGFloat
    let avatarHorizontalSpacing: CGFloat
    let onSelect: (WebDJ) -> Void

    @State private var rowWidth: CGFloat = 1

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let travel = CGFloat((elapsed * speed).truncatingRemainder(dividingBy: Double(max(rowWidth, 1))))
                let offset = reverse ? (-rowWidth + travel) : -travel

                HStack(spacing: 0) {
                    rowContent
                    rowContent
                }
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: offset)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: DJWebMarqueeWidthKey.self, value: proxy.size.width / 2.0)
                    }
                )
                .onPreferenceChange(DJWebMarqueeWidthKey.self) { value in
                    if value > 1 {
                        rowWidth = value
                    }
                }
            }
        }
        .frame(height: rowHeight)
        .clipped()
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                ForEach(items) { dj in
                    Button {
                        onSelect(dj)
                    } label: {
                        DJWebAvatar(dj: dj, size: avatarSize)
                            .padding(.horizontal, avatarHorizontalSpacing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DJWebAvatar: View {
    let dj: WebDJ
    let size: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let avatar = AppConfig.resolvedDJAvatarURLString(dj.avatarSmallUrl ?? dj.avatarUrl, size: .small) {
                    ImageLoaderView(urlString: lowResAvatarURL(avatar))
                        .background(fallback)
                } else {
                    fallback
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1.5))
            .shadow(color: Color.black.opacity(0.34), radius: 10, y: 4)

            Text(dj.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .frame(width: max(56, size + 16))
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.42, green: 0.22, blue: 0.78), Color(red: 0.15, green: 0.45, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials(of: dj.name))
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
    }
}

private struct DJWebCard: View {
    static let cardWidth: CGFloat = 168

    let dj: WebDJ
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                cover
                    .frame(width: Self.cardWidth, height: Self.cardWidth)
                    .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(dj.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if dj.isVerified == true {
                            Text("✓")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.green)
                        }
                    }

                    if let bio = dj.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(2)
                    }

                    if let country = dj.country, !country.isEmpty {
                        Label(country, systemImage: "globe")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Label(LT("\(dj.followerCount ?? 0) 粉丝", "\(dj.followerCount ?? 0) followers", "\(dj.followerCount ?? 0) フォロワー"), systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if dj.spotifyId != nil {
                            tag("Spotify", color: .green)
                        }
                        if dj.soundcloudUrl != nil {
                            tag("SoundCloud", color: .blue)
                        }
                        if dj.instagramUrl != nil {
                            tag("Instagram", color: .pink)
                        }
                    }
                    .lineLimit(1)
                }
                .padding(12)
                .frame(height: 170, alignment: .topLeading)
            }
            .frame(width: Self.cardWidth, height: Self.cardWidth + 170)
            .background(RaverTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var cover: some View {
        Group {
            if let avatar = AppConfig.resolvedDJAvatarURLString(dj.avatarOriginalUrl ?? dj.avatarUrl, size: .original) {
                ImageLoaderView(urlString: highResAvatarURL(avatar))
                    .background(fallbackCover)
            } else {
                fallbackCover
            }
        }
    }

    private var fallbackCover: some View {
        LinearGradient(
            colors: [Color(red: 0.42, green: 0.22, blue: 0.78), Color(red: 0.15, green: 0.45, blue: 1.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text("🎧")
                .font(.system(size: 52))
        )
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct DJWebMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

func initials(of name: String) -> String {
    let parts = name.split(separator: " ").prefix(2)
    if parts.isEmpty {
        return String(name.prefix(2)).uppercased()
    }
    return parts.compactMap { $0.first }.map(String.init).joined().uppercased()
}

private func lowResAvatarURL(_ url: String) -> String {
    url
        .replacingOccurrences(of: "ab6761610000e5eb", with: "ab6761610000f178")
        .replacingOccurrences(of: "ab67616100005174", with: "ab6761610000f178")
        .replacingOccurrences(of: "ab67616d0000b273", with: "ab67616d00004851")
        .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d00004851")
}

func highResAvatarURL(_ url: String) -> String {
    url
        .replacingOccurrences(of: "ab6761610000f178", with: "ab6761610000e5eb")
        .replacingOccurrences(of: "ab67616100005174", with: "ab6761610000e5eb")
        .replacingOccurrences(of: "ab67616d00004851", with: "ab67616d0000b273")
        .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273")
}

private struct DJDetailTabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [DJDetailView.DJDetailTab: CGRect] = [:]

    static func reduce(value: inout [DJDetailView.DJDetailTab: CGRect], nextValue: () -> [DJDetailView.DJDetailTab: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct DJDetailRepresentable: UIViewControllerRepresentable {
    let heroView: AnyView
    let djTitle: String
    let tabTitles: [String]
    let tabBarView: AnyView
    let tabPageViews: [AnyView]
    let selectedIndex: Int
    let pageProgress: CGFloat
    let onTabChange: (Int) -> Void
    let onPageProgress: (CGFloat) -> Void

    @EnvironmentObject private var appState: AppState

    func makeUIViewController(context: Context) -> DJDetailScrollViewController {
        let controller = DJDetailScrollViewController()
        controller.onTabIndexChange = { [weak coordinator = context.coordinator] index in
            coordinator?.relayTabChange(index)
        }
        controller.onPageProgressChange = { [weak coordinator = context.coordinator] progress in
            coordinator?.relayPageProgress(progress)
        }

        context.coordinator.scrollController = controller
        context.coordinator.onTabChange = onTabChange
        context.coordinator.onPageProgress = onPageProgress

        controller.update(
            heroView: wrapped(heroView),
            djTitle: djTitle,
            tabTitles: tabTitles,
            tabBarView: wrapped(tabBarView),
            tabPageViews: tabPageViews.map(wrapped),
            selectedIndex: selectedIndex,
            pageProgress: pageProgress,
            animatedSelection: false
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: DJDetailScrollViewController, context: Context) {
        context.coordinator.scrollController = uiViewController
        context.coordinator.onTabChange = onTabChange
        context.coordinator.onPageProgress = onPageProgress

        uiViewController.onTabIndexChange = { [weak coordinator = context.coordinator] index in
            coordinator?.relayTabChange(index)
        }
        uiViewController.onPageProgressChange = { [weak coordinator = context.coordinator] progress in
            coordinator?.relayPageProgress(progress)
        }

        uiViewController.update(
            heroView: wrapped(heroView),
            djTitle: djTitle,
            tabTitles: tabTitles,
            tabBarView: wrapped(tabBarView),
            tabPageViews: tabPageViews.map(wrapped),
            selectedIndex: selectedIndex,
            pageProgress: pageProgress,
            animatedSelection: true
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func wrapped(_ view: AnyView) -> AnyView {
        AnyView(view.environmentObject(appState))
    }

    final class Coordinator {
        weak var scrollController: DJDetailScrollViewController?
        var onTabChange: ((Int) -> Void)?
        var onPageProgress: ((CGFloat) -> Void)?

        func relayTabChange(_ index: Int) {
            onTabChange?(index)
        }

        func relayPageProgress(_ progress: CGFloat) {
            onPageProgress?(progress)
        }
    }
}

private final class DJDetailScrollViewController: UIViewController {
    var onTabIndexChange: ((Int) -> Void)?
    var onPageProgressChange: ((CGFloat) -> Void)?

    private let heroHeight: CGFloat = 360
    private let tabBarHeight: CGFloat = 52
    private let topBarHeight: CGFloat = 44

    private let pageViewController = EventDetailPageViewController()
    private let heroViewController = UIHostingController(rootView: AnyView(EmptyView()))
    private let tabBarViewController = UIHostingController(rootView: AnyView(EmptyView()))
    private let tabBarContainer = UIView()
    private let topOverlayView = UIView()
    private let titleLabel = UILabel()

    private var heroTopConstraint: NSLayoutConstraint!
    private var tabBarTopConstraint: NSLayoutConstraint!
    private var topOverlayHeightConstraint: NSLayoutConstraint!
    private var didSetupHierarchy = false

    private var pendingHeroView: AnyView?
    private var pendingTitle: String = ""
    private var pendingTabTitles: [String] = []
    private var pendingTabBarView: AnyView?
    private var pendingPageViews: [AnyView] = []
    private var pendingSelectedIndex: Int = 0
    private var pendingProgress: CGFloat = 0
    private var currentSelectedIndex: Int = 0
    private var isApplyingProgrammaticSelection = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(RaverTheme.background)
        heroViewController.view.backgroundColor = .clear
        tabBarViewController.view.backgroundColor = .clear
        pageViewController.view.backgroundColor = .clear
        tabBarContainer.backgroundColor = UIColor(RaverTheme.background)
        setupHierarchyIfNeeded()
        if #available(iOS 16.4, *) {
            heroViewController.safeAreaRegions = []
            tabBarViewController.safeAreaRegions = []
        }
        wireCallbacks()
        applyPendingState(animatedSelection: false)
        applyTopOverlayAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyPageInsets()
        updatePinnedHeader(forOffset: pageViewController.currentActiveOffset())
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        applyPageInsets()
        updatePinnedHeader(forOffset: pageViewController.currentActiveOffset())
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTopOverlayAppearance()
    }

    func update(
        heroView: AnyView,
        djTitle: String,
        tabTitles: [String],
        tabBarView: AnyView,
        tabPageViews: [AnyView],
        selectedIndex: Int,
        pageProgress: CGFloat,
        animatedSelection: Bool
    ) {
        pendingHeroView = heroView
        pendingTitle = djTitle
        pendingTabTitles = tabTitles
        pendingTabBarView = tabBarView
        pendingPageViews = tabPageViews
        pendingSelectedIndex = selectedIndex
        pendingProgress = pageProgress

        guard isViewLoaded else { return }
        applyPendingState(animatedSelection: animatedSelection)
    }

    private func setupHierarchyIfNeeded() {
        guard !didSetupHierarchy else { return }
        didSetupHierarchy = true

        addChild(pageViewController)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageViewController.view)
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        pageViewController.didMove(toParent: self)

        addChild(heroViewController)
        heroViewController.view.translatesAutoresizingMaskIntoConstraints = false
        heroViewController.view.clipsToBounds = true
        view.addSubview(heroViewController.view)
        heroTopConstraint = heroViewController.view.topAnchor.constraint(equalTo: view.topAnchor)
        NSLayoutConstraint.activate([
            heroTopConstraint,
            heroViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            heroViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heroViewController.view.heightAnchor.constraint(equalToConstant: heroHeight),
        ])
        heroViewController.didMove(toParent: self)

        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.clipsToBounds = true
        view.addSubview(tabBarContainer)

        addChild(tabBarViewController)
        tabBarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(tabBarViewController.view)
        tabBarTopConstraint = tabBarContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: heroHeight)
        NSLayoutConstraint.activate([
            tabBarTopConstraint,
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainer.heightAnchor.constraint(equalToConstant: tabBarHeight),

            tabBarViewController.view.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarViewController.view.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            tabBarViewController.view.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            tabBarViewController.view.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
        ])
        tabBarViewController.didMove(toParent: self)

        setupTopOverlay()
    }

    private func wireCallbacks() {
        pageViewController.onPageChange = { [weak self] index in
            guard let self else { return }
            currentSelectedIndex = index
            if !isApplyingProgrammaticSelection {
                onTabIndexChange?(index)
            }
        }

        pageViewController.onPageProgress = { [weak self] progress in
            self?.onPageProgressChange?(progress)
        }

        pageViewController.onActivePageVerticalOffsetChanged = { [weak self] offset in
            self?.updatePinnedHeader(forOffset: offset)
        }
    }

    private func applyPendingState(animatedSelection: Bool) {
        if let hero = pendingHeroView {
            heroViewController.rootView = hero
        }
        if let tabBar = pendingTabBarView {
            tabBarViewController.rootView = tabBar
        }

        titleLabel.text = pendingTitle
        _ = pendingTabTitles
        pageViewController.configure(with: pendingPageViews)
        applyPageInsets()

        if pendingSelectedIndex != currentSelectedIndex {
            currentSelectedIndex = pendingSelectedIndex
            isApplyingProgrammaticSelection = true
            pageViewController.setSelectedIndex(pendingSelectedIndex, animated: animatedSelection)
            let releaseDelay = animatedSelection ? 0.4 : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + releaseDelay) { [weak self] in
                self?.isApplyingProgrammaticSelection = false
            }
        } else {
            isApplyingProgrammaticSelection = false
        }

        onPageProgressChange?(pendingProgress)
        updatePinnedHeader(forOffset: pageViewController.currentActiveOffset())
    }

    private func applyPageInsets() {
        let topInset = heroHeight + tabBarHeight
        let bottomInset = view.safeAreaInsets.bottom + 20
        pageViewController.setContentInsets(top: topInset, bottom: bottomInset)
        topOverlayHeightConstraint.constant = pinnedTabTopLimit()
    }

    private func updatePinnedHeader(forOffset offset: CGFloat) {
        let clamped = min(max(offset, 0), heroHeight)
        heroTopConstraint.constant = -clamped

        let topLimit = pinnedTabTopLimit()
        let desiredTop = heroHeight - clamped
        tabBarTopConstraint.constant = max(topLimit, desiredTop)

        let pinStart = max(0, heroHeight - topLimit)
        let overlayProgress = min(max((offset - pinStart + 8) / 20, 0), 1)
        topOverlayView.alpha = overlayProgress
        titleLabel.alpha = overlayProgress
    }

    private func pinnedTabTopLimit() -> CGFloat {
        view.safeAreaInsets.top + topBarHeight
    }

    private func setupTopOverlay() {
        topOverlayView.translatesAutoresizingMaskIntoConstraints = false
        topOverlayView.alpha = 0
        topOverlayView.isUserInteractionEnabled = false
        view.addSubview(topOverlayView)

        topOverlayHeightConstraint = topOverlayView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            topOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            topOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topOverlayHeightConstraint,
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.alpha = 0
        topOverlayView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: topOverlayView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.widthAnchor.constraint(equalToConstant: 176),
        ])
    }

    private func applyTopOverlayAppearance() {
        let isDark = traitCollection.userInterfaceStyle != .light
        topOverlayView.backgroundColor = isDark
            ? .black
            : UIColor(RaverTheme.background)
        titleLabel.textColor = isDark
            ? .white
            : UIColor.black.withAlphaComponent(0.88)
    }
}

struct DJDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    private var djReadRepository: DJReadRepository {
        appContainer.djReadRepository
    }

    private var djLinkedContentRepository: DJLinkedContentRepository {
        appContainer.djLinkedContentRepository
    }

    private var djRankingRepository: DJRankingRepository {
        appContainer.djRankingRepository
    }

    private var djRelationRepository: DJRelationRepository {
        appContainer.djRelationRepository
    }

    private var djImportRepository: DJImportRepository {
        appContainer.djImportRepository
    }

    private var djCommandRepository: DJCommandRepository {
        appContainer.djCommandRepository
    }

    private var djMediaRepository: DJMediaRepository {
        appContainer.djMediaRepository
    }

    private var newsRepository: DiscoverNewsRepository {
        appContainer.discoverNewsRepository
    }

    let djID: String

    @State private var dj: WebDJ?
    @State private var sets: [WebDJSet] = []
    @State private var djEvents: [WebEvent] = []
    @State private var ratingUnits: [WebRatingUnit] = []
    @State private var rankingHonors: [DJHonorItem] = []
    @State private var watchedSetCount = 0
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var bannerMessage: String?
    @State private var bannerStyle: ScreenStatusBannerStyle = .error
    @State private var bannerAllowsRetry = true
    @State private var bannerDismissToken = UUID()
    @State private var errorMessage: String?
    @State private var selectedTab: DJDetailTab = .intro
    @State private var pageProgress: CGFloat = 0
    @State private var isTabSwitchingByTap = false
    @State private var tabSwitchUnlockWorkItem: DispatchWorkItem?
    @State private var tabFrames: [DJDetailTab: CGRect] = [:]
    @State private var pagerWidth: CGFloat = 1
    @State private var djNameLineCount: Int = 1
    @State private var showSpotifyImportSheet = false
    @State private var spotifySearchKeyword = ""
    @State private var spotifyCandidates: [SpotifyDJCandidate] = []
    @State private var isSearchingSpotify = false
    @State private var selectedSpotifyCandidate: SpotifyDJCandidate?
    @State private var spotifyDraftName = ""
    @State private var spotifyDraftAliases = ""
    @State private var spotifyDraftBio = ""
    @State private var reportTarget: ReportSheetTarget?
    @State private var spotifyDraftCountry = ""
    @State private var isImportingSpotifyDJ = false
    @State private var showDJEditSheet = false
    @State private var isSavingDJProfile = false
    @State private var editDJName = ""
    @State private var editDJAliases = ""
    @State private var editDJBio = ""
    @State private var editDJCountry = ""
    @State private var editDJSpotifyID = ""
    @State private var editDJAppleMusicID = ""
    @State private var editDJInstagram = ""
    @State private var editDJSoundcloud = ""
    @State private var editDJTwitter = ""
    @State private var editDJVerified = true
    @State private var editAvatarItem: PhotosPickerItem?
    @State private var editBannerItem: PhotosPickerItem?
    @State private var editAvatarData: Data?
    @State private var editBannerData: Data?
    @State private var relatedArticles: [DiscoverNewsArticle] = []
    @State private var isLoadingRelatedArticles = false
    @State private var historyEventSearchText = ""
    @State private var historyEventRegionFilter: DJEventRegionFilter = .all
    @State private var historyEventStartDate: Date?
    @State private var historyEventEndDate: Date?
    @State private var isCachingManualSnapshot = false
    @State private var manualCachedAt: Date?
    @State private var isHonorListExpanded = false
    @State private var djCardSharePresentation: DJCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: DJCardSharePresentation?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    fileprivate enum DJDetailTab: String, CaseIterable, Identifiable {
        case intro
        case posts
        case sets
        case events
        case ratings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .intro: return LT("简介", "Intro", "紹介")
            case .posts: return LT("动态", "Posts", "投稿")
            case .sets: return "Sets"
            case .events: return LT("活动", "Events", "イベント")
            case .ratings: return LT("打分", "Ratings", "評価")
            }
        }

        var themeColor: Color {
            switch self {
            case .intro: return Color(red: 0.27, green: 0.85, blue: 0.82)
            case .posts: return Color(red: 0.95, green: 0.30, blue: 0.38)
            case .sets: return Color(red: 0.30, green: 0.67, blue: 0.97)
            case .events: return Color(red: 0.98, green: 0.71, blue: 0.22)
            case .ratings: return Color(red: 0.58, green: 0.43, blue: 0.95)
            }
        }
    }

    private enum DJEventRegionFilter: String, CaseIterable, Identifiable {
        case all
        case domestic
        case international

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return LT("全部地区", "All", "すべての地域")
            case .domestic:
                return LT("国内", "Domestic", "国内")
            case .international:
                return LT("海外", "International", "海外")
            }
        }
    }

    private struct DJCurrentPerformanceSnapshot: Identifiable {
        let event: WebEvent
        let timeText: String

        var id: String { event.id }
    }

    private struct DJHonorItem: Identifiable, Hashable {
        enum Kind: String {
            case ranking
            case award
            case title
        }

        let id: String
        let kind: Kind
        let title: String
        let subtitle: String?
        let detail: String?
        let year: Int?
        let rank: Int?
        let rankingBoard: RankingBoard?
        let accentColor: Color

        var sortYear: Int { year ?? Int.min }
    }

    private static let heroLiveTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let heroLiveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    var body: some View {
        detailBody
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .raverImmersiveFloatingNavigationChrome(
            trailing: immersiveTrailingAction
        ) {
            dismiss()
        }
        .operationBannerHost()
        .sheet(item: $fullChatSharePresentation, content: fullChatShareSheet)
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, _ in
                showWidgetStatusBanner(message: LT("举报已提交", "Report submitted", "報告を送信しました"))
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .task {
            await refreshManualCacheState()
            await load()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay { sharePanelOverlay }
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
        .navigationDestination(isPresented: $showDJEditSheet) {
            djEditSheet
        }
        .navigationDestination(isPresented: $showSpotifyImportSheet) {
            spotifyImportSheet
        }
        .onChange(of: editAvatarItem) { _, item in
            Task { await loadDJEditPhoto(item, target: .avatar) }
        }
        .onChange(of: editBannerItem) { _, item in
            Task { await loadDJEditPhoto(item, target: .banner) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverRatingUnitDidUpdate)) { _ in
            Task { await reloadDJRatingUnits() }
        }
    }

    @ViewBuilder
    private var detailBody: some View {
        Group {
            switch phase {
            case .idle, .initialLoading:
                DJDetailSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(message: message) {
                        Task { await load() }
                    }
                }
                .padding(16)
                .padding(.top, 96)
            case .empty:
                ContentUnavailableView(LT("DJ 不存在", "DJ 不存在", "DJが存在しません"), systemImage: "person.crop.circle.badge.exclamationmark")
            case .success:
                successDetailBody
            }
        }
    }

    @ViewBuilder
    private var successDetailBody: some View {
        if let dj {
            ZStack(alignment: .top) {
                successDetailChrome(dj)
                detailTopStatusBanners
            }
            .ignoresSafeArea(edges: .top)
        } else {
            ContentUnavailableView(LT("DJ 不存在", "DJ 不存在", "DJが存在しません"), systemImage: "person.crop.circle.badge.exclamationmark")
        }
    }

    private func successDetailChrome(_ dj: WebDJ) -> some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width - 32, 0)
            RaverImmersiveDetailPagerChrome(
                title: dj.name,
                tabs: DJDetailTab.allCases,
                selectedTab: selectedTab,
                pageProgress: $pageProgress,
                namespace: "dj-detail",
                configuration: detailChromeConfiguration
            ) {
                heroSection(dj)
            } tabBar: {
                tabBar
            } content: { chrome in
                tabPager(dj, cardWidth: cardWidth, chrome: chrome)
            }
        }
    }

    private func fullChatShareSheet(_ presentation: DJCardSharePresentation) -> some View {
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
            DJSharePreviewCard(payload: presentation.payload)
        }
        .presentationDetents([.fraction(0.76), .large])
    }

    @ViewBuilder
    private var sharePanelOverlay: some View {
        if let presentation = djCardSharePresentation {
            SharePanelOverlay(
                isVisible: isShareMorePanelVisible,
                onBackdropTap: { dismissShareMorePanel() }
            ) {
                ShareActionPanel(
                    primaryActions: sharePrimaryActions(),
                    quickActions: shareMoreQuickActions(for: dj),
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

    @ViewBuilder
    private var detailTopStatusBanners: some View {
        if isRefreshing || bannerMessage != nil {
            VStack(alignment: .leading, spacing: 10) {
                if isRefreshing {
                    InlineLoadingBadge(title: LT("正在更新 DJ 详情", "Updating DJ details", "DJ詳細を更新中"))
                }
                detailErrorStatusBanner
            }
            .padding(.horizontal, 16)
            .padding(.top, 100)
        }
    }

    @ViewBuilder
    private var detailErrorStatusBanner: some View {
        if let bannerMessage {
            if bannerAllowsRetry {
                ScreenStatusBanner(
                    message: bannerMessage,
                    style: bannerStyle,
                    actionTitle: LT("重试", "Retry", "再試行")
                ) {
                    Task { await load() }
                }
            } else {
                ScreenStatusBanner(
                    message: bannerMessage,
                    style: bannerStyle
                )
            }
        }
    }

    private func load() async {
        guard !isLoading else { return }

        let hadContent = dj != nil
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            isLoadingRelatedArticles = true
            async let djTask = djReadRepository.fetchDJ(id: djID)
            async let setsTask = djLinkedContentRepository.fetchDJSets(djID: djID)
            async let eventsTask = djLinkedContentRepository.fetchDJEvents(djID: djID)
            async let ratingUnitsTask = djLinkedContentRepository.fetchDJRatingUnits(djID: djID)
            async let watchedCountTask = djLinkedContentRepository.fetchMyDJCheckinCount(djID: djID)
            async let relatedArticlesTask = fetchRelatedNewsArticlesForDJ(djID: djID)
            let loadedDJ = try await djTask
            let loadedSets = try await setsTask
            let loadedEvents = (try? await eventsTask) ?? []
            let loadedRatingUnits = (try? await ratingUnitsTask) ?? []
            let loadedWatchedCount = (try? await watchedCountTask) ?? 0
            let loadedRelatedArticles = (try? await relatedArticlesTask) ?? []
            let loadedRankingHonors = await loadRankingHonors(for: loadedDJ)

            dj = loadedDJ
            prepareDJEditDraft(from: loadedDJ)
            sets = loadedSets
            djEvents = loadedEvents
            ratingUnits = loadedRatingUnits
            rankingHonors = loadedRankingHonors
            watchedSetCount = loadedWatchedCount
            relatedArticles = loadedRelatedArticles
            isHonorListExpanded = false
            isLoadingRelatedArticles = false
            phase = .success
            bannerMessage = nil

            let snapshot = makeDJManualCacheSnapshot(
                dj: loadedDJ,
                sets: loadedSets,
                djEvents: loadedEvents,
                ratingUnits: loadedRatingUnits,
                relatedArticles: loadedRelatedArticles
            )
            await persistDJManualCacheSnapshot(snapshot, prefetchImages: false)
        } catch {
            let canFallback = isOfflineRecoverableError(error) || dj == nil
            if canFallback, let snapshot = await DJManualCacheStore.shared.loadSnapshot(djID: djID) {
                applyDJManualCacheSnapshot(snapshot)
                phase = .success
                if isRequestTimeoutError(error) {
                    showBannerMessageAutoDismiss(
                        LT("请求超时，已展示最新离线缓存版本。", "Request timed out. Showing latest offline cache version.", "リクエストがタイムアウトしました。最新のオフラインキャッシュを表示しています。"),
                        style: .warning
                    )
                } else {
                    showBannerMessageAutoDismiss(
                        LT("网络较弱，已展示 DJ 缓存数据。", "Network is weak. Showing cached DJ data.", "ネットワークが弱いため、DJのキャッシュデータを表示しています。"),
                        style: .warning
                    )
                }
            } else if hadContent {
                isLoadingRelatedArticles = false
                showBannerMessage(
                    error.userFacingMessage ?? LT("DJ 详情更新失败，请稍后重试", "Failed to refresh DJ details. Please try again later.", "DJ詳細を更新できませんでした。時間をおいて再試行してください。"),
                    style: .error,
                    allowsRetry: true
                )
                phase = .success
            } else {
                isLoadingRelatedArticles = false
                let message = error.userFacingMessage ?? LT("DJ 详情加载失败，请稍后重试", "Failed to load DJ details. Please try again later.", "DJ詳細を読み込めませんでした。時間をおいて再試行してください。")
                phase = .failure(message: message)
            }
        }
    }

    private func showBannerMessage(
        _ message: String,
        style: ScreenStatusBannerStyle,
        allowsRetry: Bool
    ) {
        bannerMessage = message
        bannerStyle = style
        bannerAllowsRetry = allowsRetry
    }

    private func showBannerMessageAutoDismiss(
        _ message: String,
        style: ScreenStatusBannerStyle
    ) {
        showBannerMessage(message, style: style, allowsRetry: false)
        let token = UUID()
        bannerDismissToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard bannerDismissToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                bannerMessage = nil
            }
        }
    }

    private func fetchRelatedNewsArticlesForDJ(djID: String) async throws -> [DiscoverNewsArticle] {
        try await newsRepository.fetchArticlesBoundToDJ(djID: djID, maxPages: 8)
    }

    private func reloadDJRatingUnits() async {
        ratingUnits = (try? await djLinkedContentRepository.fetchDJRatingUnits(djID: djID)) ?? []
        await persistCurrentDJManualCacheSnapshotIfPossible()
    }

    @MainActor
    private func refreshManualCacheState() async {
        try? await DJManualCacheStore.shared.clearExpiredSnapshots()
        manualCachedAt = await DJManualCacheStore.shared.loadSnapshot(djID: djID)?.cachedAt
    }

    @MainActor
    private func cacheDJManually() async {
        guard !isCachingManualSnapshot else { return }

        isCachingManualSnapshot = true
        defer { isCachingManualSnapshot = false }

        do {
            let djForCache = try await resolveDJForManualCache()
            async let setsTask = djLinkedContentRepository.fetchDJSets(djID: djID)
            async let eventsTask = djLinkedContentRepository.fetchDJEvents(djID: djID)
            async let ratingUnitsTask = djLinkedContentRepository.fetchDJRatingUnits(djID: djID)
            async let relatedArticlesTask = fetchRelatedNewsArticlesForDJ(djID: djID)

            let snapshot = makeDJManualCacheSnapshot(
                dj: djForCache,
                sets: (try? await setsTask) ?? sets,
                djEvents: (try? await eventsTask) ?? djEvents,
                ratingUnits: (try? await ratingUnitsTask) ?? ratingUnits,
                relatedArticles: (try? await relatedArticlesTask) ?? relatedArticles
            )

            await persistDJManualCacheSnapshot(snapshot, prefetchImages: true)
            applyDJManualCacheSnapshot(snapshot)
            errorMessage = LT("DJ 页面已缓存，弱网环境也可查看。", "DJ page cached. You can view it in weak-network conditions.", "DJページをキャッシュしました。弱いネットワークでも確認できます。")
        } catch {
            errorMessage = LT("缓存失败，请稍后重试。", "Caching failed. Please try again later.", "キャッシュに失敗しました。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func applyDJManualCacheSnapshot(_ snapshot: DJManualCacheSnapshot) {
        dj = snapshot.dj
        prepareDJEditDraft(from: snapshot.dj)
        sets = snapshot.sets
        djEvents = snapshot.djEvents
        ratingUnits = snapshot.ratingUnits
        Task {
            rankingHonors = await loadRankingHonors(for: snapshot.dj)
        }
        relatedArticles = snapshot.relatedNewsArticles
        isLoadingRelatedArticles = false
        manualCachedAt = snapshot.cachedAt
    }

    @MainActor
    private func resolveDJForManualCache() async throws -> WebDJ {
        if let latest = try? await djReadRepository.fetchDJ(id: djID) {
            return latest
        }
        if let dj {
            return dj
        }
        throw ServiceError.message(LT("DJ 详情加载失败，请稍后重试。", "Failed to load DJ details. Please try again later.", "DJ詳細を読み込めませんでした。時間をおいて再試行してください。"))
    }

    private func makeDJManualCacheSnapshot(
        dj: WebDJ,
        sets: [WebDJSet],
        djEvents: [WebEvent],
        ratingUnits: [WebRatingUnit],
        relatedArticles: [DiscoverNewsArticle]
    ) -> DJManualCacheSnapshot {
        DJManualCacheSnapshot(
            djID: dj.id,
            dj: dj,
            sets: sets,
            djEvents: djEvents,
            ratingUnits: ratingUnits,
            relatedArticles: relatedArticles.map(CachedDiscoverNewsArticle.init),
            cachedAt: Date()
        )
    }

    @MainActor
    private func persistDJManualCacheSnapshot(_ snapshot: DJManualCacheSnapshot, prefetchImages: Bool) async {
        await DJManualCacheStore.shared.saveSnapshot(snapshot)
        manualCachedAt = snapshot.cachedAt
        if prefetchImages {
            prefetchDJManualCacheImages(from: snapshot)
        }
    }

    @MainActor
    private func persistCurrentDJManualCacheSnapshotIfPossible() async {
        guard let dj else { return }
        let snapshot = makeDJManualCacheSnapshot(
            dj: dj,
            sets: sets,
            djEvents: djEvents,
            ratingUnits: ratingUnits,
            relatedArticles: relatedArticles
        )
        await persistDJManualCacheSnapshot(snapshot, prefetchImages: false)
    }

    private func prefetchDJManualCacheImages(from snapshot: DJManualCacheSnapshot) {
        let rawURLs = [
            snapshot.dj.avatarUrl,
            snapshot.dj.avatarSmallUrl,
            snapshot.dj.avatarMediumUrl,
            snapshot.dj.avatarOriginalUrl,
            snapshot.dj.bannerUrl
        ]
            + snapshot.sets.compactMap(\.thumbnailUrl)
            + snapshot.djEvents.compactMap(\.coverAssetURL)
            + snapshot.relatedArticles.compactMap(\.coverImageURL)

        let urls = rawURLs
            .compactMap(AppConfig.resolvedURLString)
            .compactMap(URL.init(string:))

        guard !urls.isEmpty else { return }
        SDWebImagePrefetcher.shared.prefetchURLs(urls)
    }

    private func isRequestTimeoutError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }

    private func isOfflineRecoverableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed:
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let recoverableCodes: Set<Int> = [
                NSURLErrorTimedOut,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorDNSLookupFailed,
            ]
            if recoverableCodes.contains(nsError.code) {
                return true
            }
        }

        return false
    }

    private func toggleFollow(_ item: WebDJ) async {
        do {
            dj = try await djRelationRepository.toggleDJFollow(djID: item.id, shouldFollow: !(item.isFollowing ?? false))
            await persistCurrentDJManualCacheSnapshotIfPossible()
            await appState.refreshUnreadMessages()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func searchSpotifyCandidates() async {
        let keyword = spotifySearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            spotifyCandidates = []
            selectedSpotifyCandidate = nil
            return
        }

        isSearchingSpotify = true
        defer { isSearchingSpotify = false }

        do {
            let items = try await djImportRepository.searchSpotifyDJs(query: keyword, limit: 10)
            spotifyCandidates = items
            if let first = items.first {
                applySpotifyCandidate(first)
            } else {
                selectedSpotifyCandidate = nil
            }
        } catch {
            errorMessage = LT("Spotify 搜索失败：\(error.userFacingMessage ?? "")", "Spotify search failed: \(error.userFacingMessage ?? "")", "Spotify検索に失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    private func applySpotifyCandidate(_ candidate: SpotifyDJCandidate) {
        selectedSpotifyCandidate = candidate
        spotifyDraftName = candidate.name
        spotifyDraftAliases = ""
        spotifyDraftCountry = ""
        if candidate.genres.isEmpty {
            spotifyDraftBio = ""
        } else {
            spotifyDraftBio = "Spotify genres: \(candidate.genres.prefix(4).joined(separator: ", "))"
        }
    }

    @ViewBuilder
    private func spotifyCandidateRow(_ candidate: SpotifyDJCandidate) -> some View {
        HStack(spacing: 10) {
            Group {
                if let imageURL = AppConfig.resolvedURLString(candidate.imageUrl) {
                    ImageLoaderView(urlString: imageURL)
                        .background(Circle().fill(RaverTheme.card))
                } else {
                    Circle().fill(RaverTheme.card)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(LT("粉丝 \(candidate.followers)", "Followers \(candidate.followers)", "フォロワー \(candidate.followers)"))
                    Text(LT("热度 \(candidate.popularity)", "Popularity \(candidate.popularity)", "人気度 \(candidate.popularity)"))
                }
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)

                if let existingName = candidate.existingDJName, !existingName.isEmpty {
                    Text(LT("将合并到：\(existingName)", "Will merge into: \(existingName)", "\(existingName) に統合されます"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.orange)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if selectedSpotifyCandidate?.spotifyId == candidate.spotifyId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
        }
        .contentShape(Rectangle())
    }

    @MainActor
    private func confirmSpotifyImport() async {
        guard let selected = selectedSpotifyCandidate else {
            errorMessage = LT("请先选择一个 Spotify DJ", "Please select a Spotify DJ first.", "先にSpotify DJを選択してください。")
            return
        }
        let finalName = spotifyDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = LT("DJ 名称不能为空", "DJ name cannot be empty.", "DJ名を入力してください。")
            return
        }

        let aliases = spotifyDraftAliases
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let bio = spotifyDraftBio.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = spotifyDraftCountry.trimmingCharacters(in: .whitespacesAndNewlines)

        isImportingSpotifyDJ = true
        defer { isImportingSpotifyDJ = false }

        do {
            let result = try await djImportRepository.importSpotifyDJ(
                input: ImportSpotifyDJInput(
                    spotifyId: selected.spotifyId,
                    name: finalName,
                    aliases: aliases.isEmpty ? nil : aliases,
                    bio: bio.isEmpty ? nil : bio,
                    country: country.isEmpty ? nil : country,
                    instagramUrl: nil,
                    soundcloudUrl: nil,
                    twitterUrl: nil,
                    isVerified: true
                )
            )
            showSpotifyImportSheet = false
            switch result {
            case .submittedForReview:
                OperationBannerCenter.shared.success(LT("DJ 信息已提交审核", "DJ submitted for review", "DJ情報を審査に送信しました"))
            case .imported(let result):
                errorMessage = result.action == "created"
                    ? LT("已导入 DJ：\(result.dj.name)", "DJ imported: \(result.dj.name)", "DJを取り込みました: \(result.dj.name)")
                    : LT("已更新 DJ：\(result.dj.name)", "DJ updated: \(result.dj.name)", "DJを更新しました: \(result.dj.name)")
                if result.dj.id == djID {
                    await load()
                }
            }
        } catch {
            errorMessage = LT("导入失败：\(error.userFacingMessage ?? "")", "Import failed: \(error.userFacingMessage ?? "")", "取り込みに失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    private func prepareDJEditDraft(from dj: WebDJ) {
        editDJName = dj.name
        editDJAliases = (dj.aliases ?? []).joined(separator: ", ")
        editDJBio = dj.bio ?? ""
        editDJCountry = dj.country ?? ""
        editDJSpotifyID = dj.spotifyId ?? ""
        editDJAppleMusicID = dj.appleMusicId ?? ""
        editDJInstagram = dj.instagramUrl ?? ""
        editDJSoundcloud = dj.soundcloudUrl ?? ""
        editDJTwitter = dj.twitterUrl ?? ""
        editDJVerified = dj.isVerified ?? true
        editAvatarItem = nil
        editBannerItem = nil
        editAvatarData = nil
        editBannerData = nil
    }

    @MainActor
    private func saveDJProfileEdits() async {
        guard let currentDJ = dj else { return }

        let finalName = editDJName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = LT("DJ 名称不能为空", "DJ name cannot be empty.", "DJ名を入力してください。")
            return
        }

        let aliases = editDJAliases
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        isSavingDJProfile = true
        defer { isSavingDJProfile = false }

        do {
            _ = try await djCommandRepository.updateDJ(
                id: currentDJ.id,
                input: UpdateDJInput(
                    name: finalName,
                    aliases: aliases,
                    bio: normalizedOptionalString(editDJBio),
                    country: normalizedOptionalString(editDJCountry),
                    spotifyId: normalizedOptionalString(editDJSpotifyID),
                    appleMusicId: normalizedOptionalString(editDJAppleMusicID),
                    instagramUrl: normalizedOptionalString(editDJInstagram),
                    soundcloudUrl: normalizedOptionalString(editDJSoundcloud),
                    twitterUrl: normalizedOptionalString(editDJTwitter),
                    isVerified: editDJVerified
                )
            )

            if let editAvatarData {
                _ = try await djMediaRepository.uploadDJImage(
                    imageData: jpegDataForDJImport(from: editAvatarData),
                    fileName: "dj-avatar-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    djID: currentDJ.id,
                    usage: "avatar"
                )
            }

            if let editBannerData {
                _ = try await djMediaRepository.uploadDJImage(
                    imageData: jpegDataForDJImport(from: editBannerData),
                    fileName: "dj-banner-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    djID: currentDJ.id,
                    usage: "banner"
                )
            }

            showDJEditSheet = false
            await load()
            errorMessage = LT("DJ 信息已更新", "DJ profile updated.", "DJプロフィールを更新しました。")
        } catch {
            errorMessage = LT("保存失败：\(error.userFacingMessage ?? "")", "Save failed: \(error.userFacingMessage ?? "")", "保存に失敗しました: \(error.userFacingMessage ?? "")")
        }
    }

    private enum DJEditPhotoTarget {
        case avatar
        case banner
    }

    @MainActor
    private func loadDJEditPhoto(_ item: PhotosPickerItem?, target: DJEditPhotoTarget) async {
        guard let item else {
            switch target {
            case .avatar:
                editAvatarData = nil
            case .banner:
                editBannerData = nil
            }
            return
        }

        do {
            let loaded = try await item.loadTransferable(type: Data.self)
            switch target {
            case .avatar:
                editAvatarData = loaded
            case .banner:
                editBannerData = loaded
            }
        } catch {
            errorMessage = LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像を読み込めませんでした。もう一度お試しください。")
        }
    }

    private func normalizedOptionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func jpegDataForDJImport(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }

    private func heroSection(_ dj: WebDJ) -> some View {
        let livePerformances = currentPerformanceSnapshots(for: dj)
        let hasLivePerformances = !livePerformances.isEmpty

        return ZStack(alignment: .top) {
            GeometryReader { geo in
                ZStack {
                    RaverTheme.card
                    if let imageURL = heroImageURL(for: dj) {
                        ImageLoaderView(urlString: imageURL)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .background(RaverTheme.card)
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.22, blue: 0.78), Color(red: 0.15, green: 0.45, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.40),
                    Color.black.opacity(0.76),
                    Color.black.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 0) {
                    if hasLivePerformances {
                        currentPerformanceBadges(livePerformances)
                            .padding(.bottom, 10)
                    }

                    HStack(alignment: .center, spacing: 10) {
                        aliasPillsRow(for: dj)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            Button((dj.isFollowing ?? false) ? LT("已关注", "Following", "フォロー中") : LT("关注", "Follow", "フォロー")) {
                                Task { await toggleFollow(dj) }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(
                                        (dj.isFollowing ?? false)
                                        ? Color(red: 0.2, green: 0.56, blue: 0.98).opacity(0.45)
                                        : Color(red: 0.2, green: 0.56, blue: 0.98)
                                    )
                            )
                            .buttonStyle(.plain)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)
                    }
                    .padding(.bottom, hasLivePerformances ? 8 : 6)

                    HStack(alignment: .center, spacing: 10) {
                        Text(dj.name)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            updateDJNameLineCount(name: dj.name, availableWidth: geo.size.width)
                                        }
                                        .onChange(of: geo.size.width) { _, newValue in
                                            updateDJNameLineCount(name: dj.name, availableWidth: newValue)
                                        }
                                        .onChange(of: dj.name) { _, newValue in
                                            updateDJNameLineCount(name: newValue, availableWidth: geo.size.width)
                                        }
                                }
                            )
                    }

                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(
                    minHeight: !hasLivePerformances
                        ? (djNameLineCount > 1 ? 85 : 70)
                        : (djNameLineCount > 1 ? 126 : 110),
                    alignment: .bottomLeading
                )
                .padding(.horizontal, 16)
                .padding(.bottom, !hasLivePerformances ? (djNameLineCount > 1 ? 40 : 8) : 18)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
        .zIndex(1)
    }

    @ViewBuilder
    private func currentPerformanceBadges(_ snapshots: [DJCurrentPerformanceSnapshot]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(snapshots) { snapshot in
                    currentPerformanceBadge(snapshot)
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func currentPerformanceBadge(_ snapshot: DJCurrentPerformanceSnapshot) -> some View {
        Button {
            appPush(.eventDetail(eventID: snapshot.event.id))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    LiveActivityBarsView(
                        color: Color(red: 0.18, green: 0.88, blue: 0.42),
                        barWidth: 2.8,
                        spacing: 2,
                        minHeight: 4,
                        maxHeight: 11,
                        cornerRadius: 1.4
                    )
                    .frame(width: 14, height: 11)

                    Text(localizedEventName(snapshot.event))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: 6) {
                    Text(LT("活动进行中", "Live now", "開催中"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(red: 0.30, green: 1.0, blue: 0.54))
                        .lineLimit(1)

                    Text(snapshot.timeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    private func currentPerformanceSnapshots(for dj: WebDJ) -> [DJCurrentPerformanceSnapshot] {
        let now = Date()
        var seenEventIDs = Set<String>()

        return djEvents
            .filter { event in
                guard seenEventIDs.insert(event.id).inserted else { return false }
                return eventIsOngoing(event, at: now) && eventLineupIncludesDJ(event, dj: dj)
            }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate { return lhs.startDate > rhs.startDate }
                return localizedEventName(lhs).localizedCaseInsensitiveCompare(localizedEventName(rhs)) == .orderedAscending
            }
            .map { event in
                DJCurrentPerformanceSnapshot(
                    event: event,
                    timeText: heroLiveEventTimeText(for: event)
                )
            }
    }

    private func eventIsOngoing(_ event: WebEvent, at date: Date) -> Bool {
        let normalizedStatus = event.status?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalizedStatus == "cancelled" || normalizedStatus == "canceled" {
            return false
        }
        if normalizedStatus == "ongoing" {
            return true
        }
        if normalizedStatus == "ended" || normalizedStatus == "upcoming" {
            return false
        }
        return event.startDate <= date && date <= event.endDate
    }

    private func eventLineupIncludesDJ(_ event: WebEvent, dj: WebDJ) -> Bool {
        event.lineupSlots.contains { slotIncludesDJ($0, dj: dj) }
    }

    private func heroLiveEventTimeText(for event: WebEvent) -> String {
        let calendar = Calendar.current
        if calendar.isDate(event.startDate, inSameDayAs: event.endDate) {
            return "\(Self.heroLiveTimeFormatter.string(from: event.startDate)) - \(Self.heroLiveTimeFormatter.string(from: event.endDate)) · \(Date.appLocalizedTimeZoneLabel())"
        }
        return "\(Self.heroLiveDateFormatter.string(from: event.startDate))-\(Self.heroLiveDateFormatter.string(from: event.endDate)) · \(Date.appLocalizedTimeZoneLabel())"
    }

    private func slotIncludesDJ(_ slot: WebEventLineupSlot, dj: WebDJ) -> Bool {
        let normalizedDJID = dj.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedDJID.isEmpty {
            let candidateIDs = ([slot.djId, slot.dj?.id].compactMap { $0 })
                + (slot.djIds ?? [])
                + (slot.djs ?? []).map(\.id)
            if candidateIDs.contains(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedDJID
            }) {
                return true
            }
        }

        let djNameKeys = Set(
            ([dj.name] + (dj.aliases ?? []))
                .map(normalizedDJLookupKey)
                .filter { !$0.isEmpty }
        )
        guard !djNameKeys.isEmpty else { return false }

        let act = EventLineupActCodec.parse(slot: slot)
        return act.performers.contains { performer in
            let performerKey = normalizedDJLookupKey(performer.name)
            if djNameKeys.contains(performerKey) {
                return true
            }
            let performerID = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !normalizedDJID.isEmpty && performerID == normalizedDJID
        }
    }

    private func localizedEventName(_ event: WebEvent) -> String {
        let localized = (event.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !localized.isEmpty {
            return localized
        }
        return event.name
    }

    private var immersiveTrailingAction: AnyView? {
        guard dj != nil else { return nil }
        return AnyView(
            Button {
                if let dj {
                    djCardSharePresentation = DJCardSharePresentation(
                        payload: makeDJShareCardPayload(from: dj)
                    )
                    isShareMorePanelVisible = false
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        )
    }

    private func dismissShareMorePanel(after: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            djCardSharePresentation = nil
            after?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
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
        _ payload: DJShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.shareMessageRepository.sendDJCardMessage(
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
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                errorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ共有連携は未接続です。")
            }
        ]
    }

    private func shareMoreQuickActions(for dj: WebDJ?) -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = []

        if dj?.canEdit == true {
            actions.append(
                SharePanelQuickAction(
                    title: LT("编辑", "Edit", "編集"),
                    systemImage: "square.and.pencil",
                    accentColor: Color(red: 0.99, green: 0.65, blue: 0.20)
                ) {
                    guard let currentDJ = dj else { return }
                    prepareDJEditDraft(from: currentDJ)
                    showDJEditSheet = true
                }
            )
        }

        if let dj {
            actions.append(
                SharePanelQuickAction(
                    title: LT("复制链接", "Copy Link", "リンクをコピー"),
                    systemImage: "link",
                    accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
                ) {
                    Task { await copyDJShareLink(dj) }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("查看二维码", "View QR", "QRを見る"),
                    systemImage: "qrcode",
                    accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
                ) {
                    Task { await openDJQRCode(dj) }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("查看海报", "View Poster", "海報を見る"),
                    systemImage: "photo.on.rectangle",
                    accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
                ) {
                    Task { await openDJPoster(dj) }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("保存海报", "Save Poster", "海報を保存"),
                    systemImage: "photo.badge.arrow.down",
                    accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
                ) {
                    Task { await saveDJPoster(dj) }
                }
            )
        }

        actions.append(
            SharePanelQuickAction(
                title: isCachingManualSnapshot ? LT("缓存中", "Caching", "キャッシュ中") : LT("缓存", "Cache", "キャッシュ"),
                systemImage: "arrow.down.circle",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                Task { await cacheDJManually() }
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("贡献信息", "Incorrect Info", "情報を修正"),
                systemImage: "info.circle",
                accentColor: Color(red: 0.96, green: 0.47, blue: 0.26)
            ) {
                openDJFeedbackEntry()
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                openDJReportEntry()
            }
        )

        return actions
    }

    private func shareTarget(for dj: WebDJ) -> ShareTarget {
        let subtitle = [normalizedDJGenres(dj).first, dj.country?.nilIfBlank]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let imageURL = heroImageURL(for: dj)
        return ShareTarget(
            type: .dj,
            id: dj.id,
            title: dj.name,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            imageURL: imageURL,
            canonicalURL: "https://raver.app/dj/\(dj.id)",
            deepLink: "raver://dj/\(dj.id)",
            fallbackURL: "https://raver.app/dj/\(dj.id)",
            previewType: "content_card",
            visibility: "public"
        )
    }

    @MainActor
    private func copyDJShareLink(_ dj: WebDJ) async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: shareTarget(for: dj))
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
    private func openDJQRCode(_ dj: WebDJ) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: dj), channel: "view_qr")
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openDJPoster(_ dj: WebDJ) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: dj), channel: "view_poster")
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
                        hintText: LT("DJ 海报由分享系统统一生成，艺人名称、摘要和二维码都会跟随短链保持一致。", "DJ posters are generated by the share system, so the artist name, summary, and QR code stay aligned with the short link.", "DJ海報は共有システムで生成され、アーティスト名、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveDJPoster(_ dj: WebDJ) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: dj), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            errorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }

    private func openDJFeedbackEntry() {
        // TODO: Wire to dedicated feedback route/page when available.
        errorMessage = LT("贡献信息入口即将开放，当前已记录该需求。", "Incorrect info entry is coming soon. We have recorded this request.", "情報修正の入口は近日公開予定です。この要望は記録しました。")
    }

    private func openDJReportEntry() {
        guard let dj else {
            errorMessage = LT("DJ 信息尚未加载完成。", "DJ details are still loading.", "DJ情報はまだ読み込み中です。")
            return
        }
        reportTarget = ReportSheetTarget(
            id: dj.id,
            type: .dj,
            title: dj.name,
            preview: dj.bio?.nilIfBlank ?? normalizedDJGenres(dj).joined(separator: " · "),
            targetUserID: dj.contributors?.first?.id,
            targetUserDisplayName: dj.contributors?.first?.displayName
        )
    }

    private var djEditSheet: some View {
        Form {
                Section(LT("基础信息", "基础信息", "基本情報")) {
                    TextField(LT("DJ 名称", "DJ 名称", "DJ名"), text: $editDJName)
                    TextField(LT("别名（英文逗号分隔）", "别名（英文逗号分隔）", "別名（半角カンマ区切り）"), text: $editDJAliases)
                    TextField(LT("简介", "简介", "紹介"), text: $editDJBio, axis: .vertical)
                    TextField(LT("国家", "国家", "国"), text: $editDJCountry)
                    Toggle(LT("认证 DJ", "认证 DJ", "認証DJ"), isOn: $editDJVerified)
                }

                Section(LT("平台信息", "平台信息", "プラットフォーム情報")) {
                    TextField(LT("Spotify ID", "Spotify ID", "Spotify ID"), text: $editDJSpotifyID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(LT("Apple Music ID", "Apple Music ID", "Apple Music ID"), text: $editDJAppleMusicID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(LT("Instagram URL", "Instagram URL", "Instagram URL"), text: $editDJInstagram)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(LT("SoundCloud URL", "SoundCloud URL", "SoundCloud URL"), text: $editDJSoundcloud)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(LT("X/Twitter URL", "X/Twitter URL", "X/Twitter URL"), text: $editDJTwitter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(LT("图片", "图片", "画像")) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $editAvatarItem, matching: .images) {
                            Label(LT("更换头像", "更换头像", "アバターを変更"), systemImage: "person.crop.circle")
                        }
                        .buttonStyle(.bordered)

                        if let editAvatarData, let image = UIImage(data: editAvatarData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else if let current = dj?.avatarUrl,
                                  let resolved = AppConfig.resolvedURLString(current) {
                            ImageLoaderView(urlString: resolved)
                                .background(Circle().fill(RaverTheme.card))
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        }
                    }

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $editBannerItem, matching: .images) {
                            Label(LT("更换横幅", "更换横幅", "バナーを変更"), systemImage: "photo.rectangle")
                        }
                        .buttonStyle(.bordered)

                        if let editBannerData, let image = UIImage(data: editBannerData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else if let current = dj?.bannerUrl,
                                  let resolved = AppConfig.resolvedURLString(current) {
                            ImageLoaderView(urlString: resolved)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(RaverTheme.card))
                            .frame(width: 88, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                Section {
                    Button(isSavingDJProfile ? LT("保存中...", "Saving...", "保存中...") : "保存 DJ 信息") {
                        Task { await saveDJProfileEdits() }
                    }
                    .disabled(isSavingDJProfile || editDJName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .raverSystemNavigation(title: LT("编辑 DJ", "编辑 DJ", "DJを編集"))
            .scrollDismissesKeyboard(.interactively)
    }

    private var spotifyImportFloatingButton: some View {
        Button {
            guard appState.session != nil else {
                errorMessage = LT("请先登录后再导入 Spotify DJ", "Please log in before importing Spotify DJ.", "Spotify DJを取り込むにはログインしてください。")
                return
            }
            showSpotifyImportSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(RaverTheme.accent)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, 24)
    }

    private var spotifyImportSheet: some View {
        Form {
                Section(LT("搜索 Spotify DJ", "搜索 Spotify DJ", "Spotify DJを検索")) {
                    HStack(spacing: 8) {
                        TextField(LT("输入 DJ 名称", "输入 DJ 名称", "DJ名を入力"), text: $spotifySearchKeyword)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .onSubmit {
                                Task { await searchSpotifyCandidates() }
                            }

                        Button(isSearchingSpotify ? LT("搜索中...", "Searching...", "検索中...") : "搜索") {
                            Task { await searchSpotifyCandidates() }
                        }
                        .disabled(isSearchingSpotify || spotifySearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if isSearchingSpotify {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LT("正在拉取 Spotify 候选列表...", "正在拉取 Spotify 候选列表...", "Spotify候補を取得中..."))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }

                Section(LT("候选结果", "候选结果", "候補結果")) {
                    if spotifyCandidates.isEmpty {
                        Text(LT("暂无候选，输入名称后点击搜索。", "暂无候选，输入名称后点击搜索。", "候補がありません。名称を入力して検索してください。"))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        ForEach(spotifyCandidates) { candidate in
                            Button {
                                applySpotifyCandidate(candidate)
                            } label: {
                                spotifyCandidateRow(candidate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let selected = selectedSpotifyCandidate {
                    Section(LT("确认导入信息", "确认导入信息", "取り込み情報を確認")) {
                        Text(LT("Spotify ID: \(selected.spotifyId)", "Spotify ID: \(selected.spotifyId)", "Spotify ID: \(selected.spotifyId)"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)

                        TextField(LT("DJ 名称", "DJ 名称", "DJ名"), text: $spotifyDraftName)
                        TextField(LT("别名（英文逗号分隔）", "别名（英文逗号分隔）", "別名（半角カンマ区切り）"), text: $spotifyDraftAliases)
                        TextField(LT("简介", "简介", "紹介"), text: $spotifyDraftBio, axis: .vertical)
                        TextField(LT("国家（可选）", "国家（可选）", "国（任意）"), text: $spotifyDraftCountry)

                        if let existingName = selected.existingDJName, !existingName.isEmpty {
                            Text(LT("检测到同名/同Spotify DJ：\(existingName)，导入时将合并更新，不会重复创建。", "Matched existing same-name/Spotify DJ: \(existingName). Import will merge update instead of creating duplicate.", "同名/同一SpotifyのDJ「\(existingName)」を検出しました。取り込み時に統合更新され、重複作成されません。"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Button(isImportingSpotifyDJ ? LT("导入中...", "Importing...", "取り込み中...") : LT("确认导入到 DJ 数据库", "Confirm import to DJ database", "DJデータベースへの取り込みを確認")) {
                            Task { await confirmSpotifyImport() }
                        }
                        .disabled(isImportingSpotifyDJ || spotifyDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .raverSystemNavigation(title: LT("Spotify 导入", "Spotify 导入", "Spotify取り込み"))
            .scrollDismissesKeyboard(.interactively)
    }

    private func heroImageURL(for dj: WebDJ) -> String? {
        if let avatar = AppConfig.resolvedDJAvatarURLString(dj.avatarOriginalUrl ?? dj.avatarUrl, size: .original),
           !avatar.isEmpty {
            return highResAvatarURL(avatar)
        }
        if let banner = AppConfig.resolvedURLString(dj.bannerUrl), !banner.isEmpty {
            return highResAvatarURL(banner)
        }
        return nil
    }

    private func makeDJShareCardPayload(from dj: WebDJ) -> DJShareCardPayload {
        let cleanedGenres = normalizedDJGenres(dj)
        let genreText = cleanedGenres.first.flatMap { $0.nilIfBlank }
        let countryText: String? = {
            let localized = dj.countryI18n?.text(for: AppLanguagePreference.current.effectiveLanguage)
            let normalizedLocalized = localized?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if let normalizedLocalized, !normalizedLocalized.isEmpty {
                return normalizedLocalized
            }
            return dj.country?.nilIfBlank
        }()
        return DJShareCardPayload(
            djID: dj.id,
            djName: dj.name,
            country: countryText,
            genreText: genreText,
            coverImageURL: heroImageURL(for: dj),
            badgeText: LT("艺人", "Artist", "アーティスト")
        )
    }

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(RaverTheme.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(RaverTheme.card)
        )
    }

    private func genreTag(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RaverTheme.primaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(RaverTheme.card)
            )
    }

    private func normalizedDJGenres(_ dj: WebDJ) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for raw in dj.genres ?? [] {
            let segments = raw
                .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for item in segments {
                let key = item.lowercased()
                guard seen.insert(key).inserted else { continue }
                result.append(item)
            }
        }
        return result
    }

    private func allHonorItems(for dj: WebDJ) -> [DJHonorItem] {
        var items = rankingHonors + explicitHonorItems(for: dj) + curatedFallbackHonors(for: dj)
        var seen = Set<String>()
        items = items.filter { seen.insert($0.id).inserted }
        return items.sorted {
            if $0.kind != $1.kind {
                return $0.kind == .ranking
            }
            if $0.sortYear != $1.sortYear {
                return $0.sortYear > $1.sortYear
            }
            if ($0.rank ?? Int.max) != ($1.rank ?? Int.max) {
                return ($0.rank ?? Int.max) < ($1.rank ?? Int.max)
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func explicitHonorItems(for dj: WebDJ) -> [DJHonorItem] {
        (dj.honors ?? []).map { honor in
            let category = honor.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let kind: DJHonorItem.Kind = category == "ranking" ? .ranking : (category == "title" ? .title : .award)
            return DJHonorItem(
                id: honor.stableID,
                kind: kind,
                title: honor.title,
                subtitle: honor.subtitle ?? honor.source,
                detail: honor.rank.map { LT("第 \($0) 名", "#\($0)", "\($0)位") },
                year: honor.year,
                rank: honor.rank,
                rankingBoard: nil,
                accentColor: honorAccentColor(for: kind)
            )
        }
    }

    private func curatedFallbackHonors(for dj: WebDJ) -> [DJHonorItem] {
        let names = ([dj.name] + (dj.aliases ?? [])).map(normalizedDJLookupKey)
        guard names.contains("skrillex") else { return [] }
        return [
            DJHonorItem(
                id: "curated-skrillex-grammy-awards",
                kind: .award,
                title: "Grammy Awards",
                subtitle: LT("多次获奖", "Multiple wins", "複数回受賞"),
                detail: LT("制作与电子音乐代表性奖项", "Major production and electronic music honors", "制作と電子音楽における主要受賞"),
                year: nil,
                rank: nil,
                rankingBoard: nil,
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ),
            DJHonorItem(
                id: "curated-skrillex-best-dance-electronic-album",
                kind: .award,
                title: "Best Dance/Electronic Album",
                subtitle: "Grammy Awards",
                detail: nil,
                year: nil,
                rank: nil,
                rankingBoard: nil,
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ),
            DJHonorItem(
                id: "curated-skrillex-best-dance-recording",
                kind: .award,
                title: "Best Dance Recording",
                subtitle: "Grammy Awards",
                detail: nil,
                year: nil,
                rank: nil,
                rankingBoard: nil,
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            )
        ]
    }

    private func honorAccentColor(for kind: DJHonorItem.Kind) -> Color {
        switch kind {
        case .ranking:
            return Color(red: 0.27, green: 0.85, blue: 0.82)
        case .award:
            return Color(red: 0.98, green: 0.71, blue: 0.22)
        case .title:
            return Color(red: 0.58, green: 0.43, blue: 0.95)
        }
    }

    private func loadRankingHonors(for dj: WebDJ) async -> [DJHonorItem] {
        do {
            let boards = try await djRankingRepository.fetchRankingBoards()
            var honors: [DJHonorItem] = []
            for board in boards where board.id.lowercased().contains("djmag") && !board.id.lowercased().contains("festival") {
                for year in board.years.sorted(by: >) {
                    let detail = try await djRankingRepository.fetchRankingBoardDetail(boardID: board.id, year: year)
                    if let entry = detail.entries.first(where: { rankingEntry($0, matches: dj) }) {
                        honors.append(
                            DJHonorItem(
                                id: "ranking-\(board.id)-\(year)-\(entry.rank)",
                                kind: .ranking,
                                title: board.title,
                                subtitle: year == detail.year
                                    ? LT("\(year) 年入榜", "Ranked in \(year)", "\(year)年ランクイン")
                                    : LT("入榜", "Ranked", "ランクイン"),
                                detail: LT("第 \(entry.rank) 名", "#\(entry.rank)", "\(entry.rank)位"),
                                year: detail.year,
                                rank: entry.rank,
                                rankingBoard: board,
                                accentColor: honorAccentColor(for: .ranking)
                            )
                        )
                    }
                }
            }
            return honors
        } catch {
            return []
        }
    }

    private func rankingEntry(_ entry: RankingEntry, matches dj: WebDJ) -> Bool {
        let djKeys = Set(
            ([dj.id, dj.name] + (dj.aliases ?? []))
                .map(normalizedDJLookupKey)
                .filter { !$0.isEmpty }
        )
        guard !djKeys.isEmpty else { return false }

        let entryKeys = Set(
            ([entry.dj?.id, entry.dj?.name, entry.name].compactMap { $0 } + (entry.dj?.aliases ?? []))
                .map(normalizedDJLookupKey)
                .filter { !$0.isEmpty }
        )
        return !djKeys.isDisjoint(with: entryKeys)
    }

    @ViewBuilder
    private func socialLinks(_ dj: WebDJ) -> some View {
        HStack(spacing: 8) {
            if let spotifyID = dj.spotifyId, !spotifyID.isEmpty {
                Button {
                    openURL(URL(string: "https://open.spotify.com/artist/\(spotifyID)")!)
                } label: {
                    socialChip("Spotify", color: .green)
                }
                .buttonStyle(.plain)
            }
            if let ig = dj.instagramUrl, let url = URL(string: ig) {
                Button {
                    openURL(url)
                } label: {
                    socialChip("Instagram", color: .pink)
                }
                .buttonStyle(.plain)
            }
            if let sc = dj.soundcloudUrl, let url = URL(string: sc) {
                Button {
                    openURL(url)
                } label: {
                    socialChip("SoundCloud", color: .orange)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        RaverScrollableTabBar(
            items: djDetailTabItems,
            selection: $selectedTab,
            progress: pageProgress,
            onSelect: { tab in
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                    selectedTab = tab
                }
            },
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            activeTextColor: RaverTheme.primaryText,
            inactiveTextColor: RaverTheme.secondaryText,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 17, weight: .regular)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(RaverTheme.background)
    }

    private var djDetailTabItems: [RaverScrollableTabItem<DJDetailTab>] {
        DJDetailTab.allCases.map { tab in
            RaverScrollableTabItem(id: tab, title: tab.title)
        }
    }

    @ViewBuilder
    private func tabPager(
        _ dj: WebDJ,
        cardWidth: CGFloat,
        chrome: RaverImmersiveDetailPagerContext<DJDetailTab>
    ) -> some View {
        RaverScrollableTabPager(
            items: djDetailTabItems,
            selection: $selectedTab,
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            showsTabBar: false,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 17, weight: .regular),
            progress: $pageProgress
        ) { tab in
            djTabPage(dj, cardWidth: cardWidth, tab: tab, chrome: chrome)
                .background(RaverTheme.background)
        }
    }

    @ViewBuilder
    private func djTabPage(
        _ dj: WebDJ,
        cardWidth: CGFloat,
        tab: DJDetailTab,
        chrome: RaverImmersiveDetailPagerContext<DJDetailTab>
    ) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                RaverImmersiveDetailOffsetMarker(
                    tabID: tab,
                    coordinateSpaceName: chrome.coordinateSpaceName(tab)
                )
                Color.clear
                    .frame(height: chrome.detailTopInset)

                VStack(alignment: .leading, spacing: 14) {
                    tabContent(dj, tab: tab)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .coordinateSpace(name: chrome.coordinateSpaceName(tab))
        .scrollBounceBehavior(.always)
        .contentShape(Rectangle())
    }

    private var detailChromeConfiguration: RaverImmersiveDetailPagerConfiguration {
        RaverImmersiveDetailPagerConfiguration(
            heroHeight: 360,
            tabBarOverlayHeight: 52,
            pinnedTopBarHeight: 44,
            titleRevealLead: 8,
            titleRevealDistance: 20,
            backgroundColor: RaverTheme.background
        )
    }

    @ViewBuilder
    private func tabContent(_ dj: WebDJ, tab: DJDetailTab) -> some View {
        switch tab {
        case .intro:
            introTabContent(dj)
        case .posts:
            relatedNewsTabContent
        case .sets:
            setsTabContent
        case .events:
            eventsTabContent
        case .ratings:
            ratingsTabContent
        }
    }

    @ViewBuilder
    private var relatedNewsTabContent: some View {
        if isLoadingRelatedArticles && relatedArticles.isEmpty {
            ProgressView(LT("正在加载相关资讯...", "正在加载相关资讯...", "関連ニュースを読み込み中..."))
                .padding(.vertical, 8)
        } else if relatedArticles.isEmpty {
            Text(LT("暂无相关资讯", "暂无相关资讯", "関連ニュースはありません"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            ForEach(Array(relatedArticles.enumerated()), id: \.element.id) { index, article in
                Button {
                    discoverPush(.newsDetail(articleID: article.id))
                } label: {
                    DiscoverNewsRow(article: article, showsSummary: false)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                if index < relatedArticles.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func introTabContent(_ dj: WebDJ) -> some View {
        HStack(spacing: 14) {
            infoPill(icon: "headphones", text: LT("已看 \(watchedSetCount) 场", "Watched \(watchedSetCount) sets", "視聴済み \(watchedSetCount)件"))
            if let country = dj.country, !country.isEmpty {
                infoPill(icon: "globe", text: country)
            }
            if dj.isVerified == true {
                infoPill(icon: "checkmark.seal.fill", text: LT("认证", "Verified", "認証済み"))
            }
        }

        let genreTags = normalizedDJGenres(dj)
        if !genreTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(genreTags, id: \.self) { genre in
                        genreTag(genre)
                    }
                }
            }
        }

        if let bio = dj.bio, !bio.isEmpty {
            JustifiedUILabelText(
                text: bio,
                font: UIFont.preferredFont(forTextStyle: .subheadline),
                color: UIColor(RaverTheme.secondaryText),
                lineSpacing: 2
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }

        socialLinks(dj)

        honorSection(for: dj)

        let contributorUsers = (dj.contributors ?? []).filter { !$0.username.isEmpty }
        if !contributorUsers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(LT("贡献者", "贡献者", "コントリビューター"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(contributorUsers) { user in
                        Button {
                            appPush(.userProfile(userID: user.id))
                        } label: {
                            HStack(spacing: 10) {
                                contributorUserAvatar(user, size: 28)
                                Text(user.shownName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            let contributorNames = (dj.contributorUsernames ?? []).filter { !$0.isEmpty }
            if !contributorNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LT("贡献者", "贡献者", "コントリビューター"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(contributorNames.joined(separator: "、"))
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.primaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func honorSection(for dj: WebDJ) -> some View {
        let honors = allHonorItems(for: dj)
        if !honors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.98, green: 0.71, blue: 0.22))
                    Text(LT("荣誉", "Honors", "受賞・実績"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer(minLength: 0)
                    if honors.count > 4 {
                        Button(isHonorListExpanded ? LT("收起", "Collapse", "閉じる") : LT("查看全部", "View all", "すべて見る")) {
                            withAnimation(.snappy(duration: 0.24, extraBounce: 0.02)) {
                                isHonorListExpanded.toggle()
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                        .buttonStyle(.plain)
                    }
                }

                let visibleHonors = Array(honors.prefix(isHonorListExpanded ? honors.count : 4))
                DJHonorFlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(visibleHonors) { honor in
                        if let board = honor.rankingBoard {
                            Button {
                                appPush(.rankingBoardDetail(board: board, year: honor.year))
                            } label: {
                                honorLabel(honor)
                            }
                            .buttonStyle(.plain)
                        } else {
                            honorLabel(honor)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RaverTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(RaverTheme.cardBorder, lineWidth: 0.8)
            )
        }
    }

    private func honorLabel(_ honor: DJHonorItem) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(honor.accentColor)
                .frame(width: 5, height: 5)
            honorLabelText(honor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(honor.accentColor.opacity(0.10))
        )
    }

    @ViewBuilder
    private func honorLabelText(_ honor: DJHonorItem) -> some View {
        switch honor.kind {
        case .ranking:
            if let year = honor.year, let rank = honor.rank {
                HStack(spacing: 3) {
                    Text("DJ MAG \(year)")
                        .foregroundStyle(RaverTheme.primaryText)
                    Text("#\(rank)")
                        .foregroundStyle(honorRankColor(rank))
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            } else {
                Text(honor.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
            }
        case .award, .title:
            Text(nonRankingHonorText(honor))
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(1)
        }
    }

    private func nonRankingHonorText(_ honor: DJHonorItem) -> String {
        if let subtitle = honor.subtitle?.nilIfBlank, subtitle != honor.title {
            return "\(honor.title) · \(subtitle)"
        }
        return honor.title
    }

    private func honorRankColor(_ rank: Int) -> Color {
        switch rank {
        case 1:
            return Color(red: 0.98, green: 0.71, blue: 0.22)
        case 2...10:
            return Color(red: 0.27, green: 0.85, blue: 0.82)
        default:
            return Color(red: 0.58, green: 0.43, blue: 0.95)
        }
    }

    @ViewBuilder
    private func contributorUserAvatar(_ user: WebUserLite, size: CGFloat) -> some View {
        if let avatar = AppConfig.resolvedURLString(user.avatarUrl) {
            ImageLoaderView(urlString: avatar)
                .background(Circle().fill(RaverTheme.card))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.card)
                .frame(width: size, height: size)
                .overlay(
                    Text(initials(of: user.username))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        }
    }

    @ViewBuilder
    private var setsTabContent: some View {
        if sets.isEmpty {
            Text(LT("暂无内容", "暂无内容", "コンテンツはまだありません"))
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 6)
        } else {
            ForEach(sets) { set in
                Button {
                    discoverPush(.setDetail(setID: set.id))
                } label: {
                    setRow(set)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var eventsTabContent: some View {
        if djEvents.isEmpty {
            Text(LT("暂无历史活动", "暂无历史活动", "過去イベントはまだありません"))
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 6)
        } else {
            historyEventsFilterPanel

            let filteredEvents = filteredDJEvents
            if filteredEvents.isEmpty {
                Text(LT("没有匹配的活动", "No matching events", "一致するイベントがありません"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            } else {
                ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                    Button {
                        appPush(.eventDetail(eventID: event.id))
                    } label: {
                        historyEventRow(event)
                    }
                    .buttonStyle(.plain)

                    if index < filteredEvents.count - 1 {
                        Rectangle()
                            .fill(RaverTheme.secondaryText.opacity(0.16))
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private var historyEventsFilterPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)

                TextField(LT("搜索活动名/地点/年份", "Search event/location/year", "イベント名/場所/年を検索"), text: $historyEventSearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                if !historyEventSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        historyEventSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )

            Picker(LT("地区筛选", "Region", "地域"), selection: $historyEventRegionFilter) {
                ForEach(DJEventRegionFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(LT("按开始时间筛选", "Filter by start date", "開始日で絞り込み"), isOn: historyEventStartDateToggleBinding)
                    .font(.subheadline)
                if historyEventStartDate != nil {
                    HStack(spacing: 8) {
                        Text(LT("开始于", "From", "開始"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Spacer(minLength: 0)
                        DatePicker("", selection: historyEventStartDateBinding, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }

                Toggle(LT("按结束时间筛选", "Filter by end date", "終了日で絞り込み"), isOn: historyEventEndDateToggleBinding)
                    .font(.subheadline)
                if historyEventEndDate != nil {
                    HStack(spacing: 8) {
                        Text(LT("结束于", "To", "終了"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Spacer(minLength: 0)
                        DatePicker("", selection: historyEventEndDateBinding, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
            }

            HStack(spacing: 8) {
                Text(historyEventFilterResultText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Spacer(minLength: 0)
                if hasActiveHistoryEventFilters {
                    Button(LT("清空筛选", "Clear", "絞り込みをクリア")) {
                        clearHistoryEventFilters()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RaverTheme.card)
        )
        .padding(.bottom, 6)
    }

    private var historyEventFilterResultText: String {
        LT("显示 \(filteredDJEvents.count) / \(djEvents.count) 场", "\(filteredDJEvents.count) of \(djEvents.count) shown", "\(djEvents.count)件中 \(filteredDJEvents.count)件を表示")
    }

    private var historyEventSearchQuery: String {
        historyEventSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveHistoryEventFilters: Bool {
        !historyEventSearchQuery.isEmpty
            || historyEventRegionFilter != .all
            || historyEventStartDate != nil
            || historyEventEndDate != nil
    }

    private var filteredDJEvents: [WebEvent] {
        djEvents.filter { event in
            historyEventMatchesSearch(event)
                && historyEventMatchesRegion(event)
                && historyEventMatchesDate(event)
        }
    }

    private var historyEventStartDateToggleBinding: Binding<Bool> {
        Binding(
            get: { historyEventStartDate != nil },
            set: { enabled in
                if enabled {
                    historyEventStartDate = historyEventStartDate ?? fallbackHistoryEventStartDate
                } else {
                    historyEventStartDate = nil
                }
            }
        )
    }

    private var historyEventEndDateToggleBinding: Binding<Bool> {
        Binding(
            get: { historyEventEndDate != nil },
            set: { enabled in
                if enabled {
                    historyEventEndDate = historyEventEndDate ?? fallbackHistoryEventEndDate
                } else {
                    historyEventEndDate = nil
                }
            }
        )
    }

    private var historyEventStartDateBinding: Binding<Date> {
        Binding(
            get: { historyEventStartDate ?? fallbackHistoryEventStartDate },
            set: { historyEventStartDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var historyEventEndDateBinding: Binding<Date> {
        Binding(
            get: { historyEventEndDate ?? fallbackHistoryEventEndDate },
            set: { historyEventEndDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var fallbackHistoryEventStartDate: Date {
        let base = djEvents.map(\.startDate).min() ?? Date()
        return Calendar.current.startOfDay(for: base)
    }

    private var fallbackHistoryEventEndDate: Date {
        let base = djEvents.map(\.startDate).max() ?? Date()
        return Calendar.current.startOfDay(for: base)
    }

    private var normalizedHistoryDateBounds: (start: Date?, end: Date?) {
        let calendar = Calendar.current
        let start = historyEventStartDate.map { calendar.startOfDay(for: $0) }
        let end = historyEventEndDate.map { calendar.startOfDay(for: $0) }
        if let start, let end, start > end {
            return (end, start)
        }
        return (start, end)
    }

    private func clearHistoryEventFilters() {
        historyEventSearchText = ""
        historyEventRegionFilter = .all
        historyEventStartDate = nil
        historyEventEndDate = nil
    }

    private func historyEventMatchesSearch(_ event: WebEvent) -> Bool {
        guard !historyEventSearchQuery.isEmpty else { return true }

        let year = String(Calendar.current.component(.year, from: event.startDate))
        let searchPool = [
            event.name,
            event.summaryLocation,
            event.city ?? "",
            event.country ?? "",
            event.nameI18n?.zh ?? "",
            event.nameI18n?.en ?? "",
            event.cityI18n?.zh ?? "",
            event.cityI18n?.en ?? "",
            event.countryI18n?.zh ?? "",
            event.countryI18n?.en ?? "",
            year
        ]

        return searchPool.contains { $0.localizedCaseInsensitiveContains(historyEventSearchQuery) }
    }

    private func historyEventMatchesRegion(_ event: WebEvent) -> Bool {
        switch historyEventRegionFilter {
        case .all:
            return true
        case .domestic:
            return historyEventRegionCategory(for: event) == .domestic
        case .international:
            return historyEventRegionCategory(for: event) == .international
        }
    }

    private func historyEventMatchesDate(_ event: WebEvent) -> Bool {
        let bounds = normalizedHistoryDateBounds
        let calendar = Calendar.current
        let eventStartDay = calendar.startOfDay(for: event.startDate)

        if let start = bounds.start, eventStartDay < start {
            return false
        }

        if let end = bounds.end {
            let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) ?? end.addingTimeInterval(24 * 60 * 60)
            if eventStartDay >= endExclusive {
                return false
            }
        }

        return true
    }

    private enum DJEventRegionCategory {
        case domestic
        case international
        case unknown
    }

    private func historyEventRegionCategory(for event: WebEvent) -> DJEventRegionCategory {
        if let rawCountryCode = event.locationPoint.flatMap(\.countryCode) {
            let countryCode = rawCountryCode
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if !countryCode.isEmpty {
                return countryCode == "CN" ? .domestic : .international
            }
        }

        let countryCandidates = [
            event.country,
            event.countryI18n?.zh,
            event.countryI18n?.en
        ]

        var hasKnownCountry = false
        for raw in countryCandidates {
            let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty else { continue }
            hasKnownCountry = true
            if isChinaCountryLabel(value) {
                return .domestic
            }
        }

        return hasKnownCountry ? .international : .unknown
    }

    private func isChinaCountryLabel(_ value: String) -> Bool {
        let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let compact = lowered.replacingOccurrences(of: " ", with: "")
        if compact == "cn"
            || compact == "china"
            || compact == "prc"
            || compact == "peoplesrepublicofchina"
            || compact == "people'srepublicofchina" {
            return true
        }
        return value.contains("中国")
    }

    @ViewBuilder
    private var ratingsTabContent: some View {
        if ratingUnits.isEmpty {
            Text(LT("暂无关联打分", "暂无关联打分", "関連評価はまだありません"))
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 6)
        } else {
            ForEach(ratingUnits) { unit in
                Button {
                    appPush(.ratingUnitDetail(unitID: unit.id))
                } label: {
                    djRatingUnitRow(unit)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func aliasPillsRow(for dj: WebDJ) -> some View {
        let aliases = (dj.aliases ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if aliases.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(aliases, id: \.self) { alias in
                        Text(alias)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.68, blue: 0.86))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.16))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color(red: 1.0, green: 0.62, blue: 0.83).opacity(0.55), lineWidth: 1)
                            )
                    }
                }
            }
            .layoutPriority(1)
        }
    }

    private func updateDJNameLineCount(name: String, availableWidth: CGFloat) {
        let width = max(availableWidth, 1)
        let font = UIFont.systemFont(ofSize: 34, weight: .bold)
        let rect = (name as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let computed = max(1, Int(ceil(rect.height / font.lineHeight)))
        let lineCount = min(computed, 2)
        if djNameLineCount != lineCount {
            djNameLineCount = lineCount
        }
    }

    private func selectDJDetailTab(_ tab: DJDetailTab) {
        let targetProgress = CGFloat(selectedIndex(for: tab))
        if selectedTab == tab, abs(pageProgress - targetProgress) < 0.001 {
            return
        }

        isTabSwitchingByTap = true
        tabSwitchUnlockWorkItem?.cancel()

        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.84)) {
            selectedTab = tab
            pageProgress = targetProgress
        }

        let unlockWorkItem = DispatchWorkItem {
            isTabSwitchingByTap = false
            tabSwitchUnlockWorkItem = nil
        }
        tabSwitchUnlockWorkItem = unlockWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: unlockWorkItem)
    }

    private var indicatorRect: CGRect? {
        guard !tabFrames.isEmpty else { return nil }
        let count = DJDetailTab.allCases.count
        guard count > 0 else { return nil }

        let clamped = min(max(pageProgress, 0), CGFloat(count - 1))
        let leftIndex = Int(floor(clamped))
        let rightIndex = min(leftIndex + 1, count - 1)
        let t = clamped - CGFloat(leftIndex)

        let leftTab = DJDetailTab.allCases[leftIndex]
        let rightTab = DJDetailTab.allCases[rightIndex]
        guard let leftFrame = tabFrames[leftTab], let rightFrame = tabFrames[rightTab] else {
            return nil
        }

        let baseX = leftFrame.minX + (rightFrame.minX - leftFrame.minX) * t
        let baseWidth = leftFrame.width + (rightFrame.width - leftFrame.width) * t
        let elastic = (1 - abs(0.5 - t) * 2) * 16
        return CGRect(x: baseX - elastic * 0.2, y: 0, width: baseWidth + elastic, height: 3)
    }

    private func selectedIndex(for tab: DJDetailTab) -> Int {
        DJDetailTab.allCases.firstIndex(of: tab) ?? 0
    }

    private func tabVisualState(for tab: DJDetailTab) -> Bool {
        let index = CGFloat(selectedIndex(for: tab))
        return abs(pageProgress - index) < 0.5
    }

    private func updatePageProgress(with offsets: [DJDetailTab: CGFloat]) {
        guard pagerWidth > 1 else { return }
        let progressCandidates: [(progress: CGFloat, distance: CGFloat)] = DJDetailTab.allCases.enumerated().compactMap { index, item in
            guard let minX = offsets[item] else { return nil }
            let progress = CGFloat(index) - (minX / pagerWidth)
            return (progress, abs(minX))
        }

        guard let best = progressCandidates.min(by: { $0.distance < $1.distance }) else { return }
        let clamped = min(max(best.progress, 0), CGFloat(max(0, DJDetailTab.allCases.count - 1)))
        pageProgress = clamped
    }

    private func socialChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.15))
            )
    }

    private func setRow(_ set: WebDJSet) -> some View {
        HStack(spacing: 10) {
            setCover(set)
                .frame(width: 116, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(set.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                Text(set.createdAt.appLocalizedYMDText())
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                if let venue = set.venue, !venue.isEmpty {
                    Text(venue)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    private func historyEventRow(_ event: WebEvent) -> some View {
        let locationText = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 4) {
            Text(event.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(2)

            Text(djHistoryEventDateText(event))
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)

            Text(locationText.isEmpty ? LT("地点待补充", "Location pending", "場所は未設定") : locationText)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func djRatingUnitRow(_ unit: WebRatingUnit) -> some View {
        let eventName = unit.event?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(alignment: .top, spacing: 10) {
            djRatingThumb(urlString: unit.imageUrl, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(unit.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if !eventName.isEmpty {
                    Text(LT("事件：\(eventName)", "Event: \(eventName)", "イベント: \(eventName)"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Text(
                    LT(
                        "评分 \(String(format: "%.1f", unit.rating)) · \(unit.ratingCount) 人",
                        "Rating \(String(format: "%.1f", unit.rating)) · \(unit.ratingCount) ratings",
                        "評価 \(String(format: "%.1f", unit.rating)) · \(unit.ratingCount)件"
                    )
                )
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.top, 2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RaverTheme.card)
        )
    }

    @ViewBuilder
    private func djRatingThumb(urlString: String?, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(urlString),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(RaverTheme.card)
                        .overlay(
                            Image(systemName: "star.bubble")
                                .font(.system(size: size * 0.32, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.9))
                        )
                )
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(RaverTheme.card)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "star.bubble")
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                )
        }
    }

    private func djHistoryEventDateText(_ event: WebEvent) -> String {
        event.startDate.appLocalizedDateRangeText(to: event.endDate)
    }

    @ViewBuilder
    private func setCover(_ set: WebDJSet) -> some View {
        if let thumbnail = AppConfig.resolvedURLString(set.thumbnailUrl) {
            ImageLoaderView(urlString: thumbnail)
                .background(RaverTheme.card)
        } else {
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.16, blue: 0.19), Color(red: 0.12, green: 0.12, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.title3)
                    .foregroundStyle(RaverTheme.secondaryText)
            )
        }
    }
}

private struct DJHonorFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let rows = arrangeRows(
            proposal: proposal,
            subviews: subviews
        )
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + CGFloat(max(0, rows.count - 1)) * rowSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = arrangeRows(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = item.size
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func arrangeRows(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> [DJHonorFlowLayoutRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [DJHonorFlowLayoutRow] = []
        var current = DJHonorFlowLayoutRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty && nextWidth > maxWidth {
                rows.append(current)
                current = DJHonorFlowLayoutRow()
            }
            current.items.append(DJHonorFlowLayoutItem(index: index, size: size))
            current.width = current.items.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

private struct DJHonorFlowLayoutRow {
    var items: [DJHonorFlowLayoutItem] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
}

private struct DJHonorFlowLayoutItem {
    let index: Int
    let size: CGSize
}
