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
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    private let hotDJBatchSize = 25

    private var repository: DiscoverDJsRepository {
        appContainer.discoverDJsRepository
    }

    @State private var djs: [WebDJ] = []
    @State private var rankingBoards: [RankingBoard] = []
    @State private var isLoading = false
    @State private var isRefreshingHotBatch = false
    @State private var errorMessage: String?
    @State private var selectedSection: DJsModuleSection = .hot
    @State private var searchKeyword = ""
    @State private var selectedBoardForDetail: RankingBoard?
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

    var body: some View {
        ScrollView(showsIndicators: selectedSection == .rankings) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DJsModuleSection.allCases, id: \.self) { item in
                                    Button(item.title) {
                                        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.84)) {
                                            selectedSection = item
                                        }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedSection == item ? RaverTheme.accent : RaverTheme.card)
                                    .foregroundStyle(selectedSection == item ? Color.white : RaverTheme.primaryText)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scrollClipDisabled()
                        .defaultScrollAnchor(.leading)

                        Button {
                            discoverPush(
                                .searchInput(
                                    domain: .djs,
                                    initialQuery: searchKeyword
                                )
                            )
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .frame(width: 32, height: 32)
                                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(RaverTheme.secondaryText.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if selectedSection == .hot {
                        if isLoading && filteredDJs.isEmpty {
                            ProgressView(L("加载中...", "Loading..."))
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else if filteredDJs.isEmpty {
                            ContentUnavailableView(LL("暂无 DJ"), systemImage: "music.mic")
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            VStack(spacing: 14) {
                                DJWebMarqueeWall(rows: marqueeRows) { tapped in
                                    appPush(.djDetail(djID: tapped.id))
                                }
                                .frame(height: marqueeWallHeight)
                                .padding(.horizontal, -16)

                                Button {
                                    Task { await refreshRandomHotBatch() }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isRefreshingHotBatch {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "shuffle")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        Text(isRefreshingHotBatch ? L("换一批中...", "Refreshing...") : L("换一批 DJ", "Refresh DJs"))
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(RaverTheme.card)
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(isRefreshingHotBatch)
                            }
                        }
                    } else {
                        if isLoading && filteredRankingBoards.isEmpty {
                            ProgressView(L("加载榜单中...", "Loading rankings..."))
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else if filteredRankingBoards.isEmpty {
                            ContentUnavailableView(LL("暂无榜单"), systemImage: "list.number")
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(filteredRankingBoards) { board in
                                    Button {
                                        selectedBoardForDetail = board
                                    } label: {
                                        RankingBoardCoverCard(board: board)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 254)
                                    .clipped()
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, topContentInset)
                .padding(.bottom, 16)
            }
            .scrollDisabled(selectedSection == .hot)
            .background(RaverTheme.background)
            .task {
                await load()
            }
            .refreshable {
                await load()
            }
            .navigationDestination(item: $selectedBoardForDetail) { board in
                RankingBoardDetailView(board: board)
            }
            .overlay(alignment: .bottomTrailing) {
                if selectedSection == .hot {
                    djImportFloatingButton
                }
            }
            .navigationDestination(isPresented: $showDJImportSheet) {
                djImportSheet
            }
            .onChange(of: manualAvatarItem) { _, item in
                Task { await loadManualPhoto(item, target: .avatar) }
            }
            .onChange(of: manualBannerItem) { _, item in
                Task { await loadManualPhoto(item, target: .banner) }
            }
            .alert(L("提示", "Notice"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private var filteredDJs: [WebDJ] {
        djs
    }

    private var filteredRankingBoards: [RankingBoard] {
        rankingBoards
    }

    private var marqueeRows: [[WebDJ]] {
        let pool = Array(djs.prefix(hotDJBatchSize))
        guard !pool.isEmpty else { return [] }

        return (0..<4).map { mod in
            let row = pool.enumerated().compactMap { index, item in
                index % 4 == mod ? item : nil
            }
            return row.isEmpty ? Array(pool.prefix(8)) : row
        }
    }

    private var topContentInset: CGFloat {
        selectedSection == .hot ? 14 : 8
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

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            errorMessage = nil
            async let djsTask = repository.fetchDJs(page: 1, limit: hotDJBatchSize, search: nil, sortBy: "random")
            async let boardsTask = repository.fetchRankingBoards()
            let hotPage = try await djsTask
            djs = hotPage.items
            rankingBoards = try await boardsTask
            if djs.isEmpty {
                await refreshRandomHotBatch()
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func refreshRandomHotBatch() async {
        guard !isRefreshingHotBatch else { return }
        isRefreshingHotBatch = true
        defer { isRefreshingHotBatch = false }

        do {
            let page = try await repository.fetchDJs(page: 1, limit: hotDJBatchSize, search: nil, sortBy: "random")
            let nextBatch = page.items
            if !nextBatch.isEmpty {
                djs = nextBatch
            }
        } catch {
            errorMessage = error.userFacingMessage
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
        .padding(.bottom, 24)
    }

    private var djImportSheet: some View {
        Form {
                Section(LL("导入方式")) {
                    Picker(LL("导入方式"), selection: $importMode) {
                        ForEach(DJsImportMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if importMode == .spotify {
                    Section(LL("搜索 Spotify DJ")) {
                        HStack(spacing: 8) {
                            TextField(LL("输入 DJ 名称"), text: $spotifySearchKeyword)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(true)
                                .onSubmit {
                                    Task { await searchSpotifyCandidates() }
                                }

                            Button(isSearchingSpotify ? L("搜索中...", "Searching...") : L("搜索", "Search")) {
                                Task { await searchSpotifyCandidates() }
                            }
                            .disabled(isSearchingSpotify || spotifySearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if isSearchingSpotify {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(LL("正在拉取 Spotify 候选列表..."))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }

                    Section(LL("候选结果")) {
                        if spotifyCandidates.isEmpty {
                            Text(LL("暂无候选，可切换到手动导入。"))
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
                        Section(LL("确认导入信息")) {
                            Text(L("Spotify ID: \(selected.spotifyId)", "Spotify ID: \(selected.spotifyId)"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)

                            TextField(LL("DJ 名称"), text: $spotifyDraftName)
                            TextField(LL("别名（英文逗号分隔）"), text: $spotifyDraftAliases)
                            TextField(LL("简介"), text: $spotifyDraftBio, axis: .vertical)
                            TextField(LL("国家（可选）"), text: $spotifyDraftCountry)

                            if let existingName = selected.existingDJName, !existingName.isEmpty {
                                Text(L("检测到同名/同Spotify DJ：\(existingName)，导入时将合并更新，不会重复创建。", "Matched existing same-name/Spotify DJ: \(existingName). Import will merge update instead of creating duplicate."))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                } else if importMode == .discogs {
                    Section(LL("搜索 Discogs Artist")) {
                        HStack(spacing: 8) {
                            TextField(LL("输入 DJ 名称"), text: $discogsSearchKeyword)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(true)
                                .onSubmit {
                                    Task { await searchDiscogsCandidates() }
                                }

                            Button(isSearchingDiscogs ? L("搜索中...", "Searching...") : L("搜索", "Search")) {
                                Task { await searchDiscogsCandidates() }
                            }
                            .disabled(isSearchingDiscogs || discogsSearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if isSearchingDiscogs {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(LL("正在拉取 Discogs 候选列表..."))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }

                    Section(LL("Discogs 候选结果")) {
                        if discogsCandidates.isEmpty {
                            Text(LL("暂无候选，可继续搜索或切换到手动导入。"))
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
                        Section(LL("确认导入信息（支持二次修改）")) {
                            if isLoadingDiscogsDetail {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(LL("正在读取 Discogs 详情并自动填充..."))
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                            }

                            TextField(LL("DJ 名称"), text: $discogsDraftName)
                            TextField(LL("别名（英文逗号分隔）"), text: $discogsDraftAliases)
                            TextField(LL("简介"), text: $discogsDraftBio, axis: .vertical)
                            TextField(LL("国家（可选）"), text: $discogsDraftCountry)
                            TextField(LL("Instagram（可选）"), text: $discogsDraftInstagram)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            TextField(LL("SoundCloud（可选）"), text: $discogsDraftSoundcloud)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            TextField(LL("X/Twitter（可选）"), text: $discogsDraftTwitter)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            TextField(LL("Spotify ID（可选）"), text: $discogsDraftSpotifyID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)

                            if let selectedDiscogsCandidate,
                               let existingName = selectedDiscogsCandidate.existingDJName,
                               !existingName.isEmpty {
                                Text(L("检测到同名 DJ：\(existingName)，导入时将合并更新，不会重复创建。", "Matched existing same-name DJ: \(existingName). Import will merge update instead of creating duplicate."))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }

                        Section(LL("关联 Spotify（可选）")) {
                            HStack(spacing: 8) {
                                TextField(LL("搜索 Spotify 用于补全链接"), text: $discogsLinkedSpotifyKeyword)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(true)
                                    .onSubmit {
                                        Task { await searchDiscogsLinkedSpotifyCandidates() }
                                    }

                                Button(isSearchingDiscogsLinkedSpotify ? L("搜索中...", "Searching...") : "搜索") {
                                    Task { await searchDiscogsLinkedSpotifyCandidates() }
                                }
                                .disabled(isSearchingDiscogsLinkedSpotify || discogsLinkedSpotifyKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            if isSearchingDiscogsLinkedSpotify {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(LL("正在搜索 Spotify..."))
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
                                Text(L("已关联 Spotify：\(selectedDiscogsLinkedSpotifyCandidate.name)", "Linked Spotify: \(selectedDiscogsLinkedSpotifyCandidate.name)"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                    }
                } else {
                    Section(LL("手动填写 DJ 信息")) {
                        TextField(LL("DJ 名称（必填）"), text: $manualName)
                        TextField(LL("别名（英文逗号分隔）"), text: $manualAliases)
                        TextField(LL("国家（可选）"), text: $manualCountry)
                        TextField(LL("Instagram（可选）"), text: $manualInstagram)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField(LL("SoundCloud（可选）"), text: $manualSoundcloud)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField(LL("X/Twitter（可选）"), text: $manualTwitter)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField(LL("简介（可选）"), text: $manualBio, axis: .vertical)
                    }

                    Section(LL("图片（上传到 OSS 的 DJ 文件夹）")) {
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $manualAvatarItem, matching: .images) {
                                Label(LL("选择头像"), systemImage: "person.crop.circle")
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
                                Label(LL("选择横幅"), systemImage: "photo.rectangle")
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
                    Button(isImportingDJ ? L("导入中...", "Importing...") : L("确认导入到 DJ 数据库", "Confirm import to DJ database")) {
                        Task { await confirmDJImport() }
                    }
                    .disabled(isImportingDJ || isImportConfirmDisabled)
                }
            }
            .navigationTitle(LL("导入 DJ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("关闭", "Close")) {
                        showDJImportSheet = false
                    }
                    .disabled(isImportingDJ)
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
            let items = try await repository.searchSpotifyDJs(query: keyword, limit: 10)
            spotifyCandidates = items
            if let first = items.first {
                applySpotifyCandidate(first)
            } else {
                selectedSpotifyCandidate = nil
            }
        } catch {
            errorMessage = L("Spotify 搜索失败：\(error.userFacingMessage ?? "")", "Spotify search failed: \(error.userFacingMessage ?? "")")
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
            let items = try await repository.searchDiscogsDJs(query: keyword, limit: 12)
            discogsCandidates = items
            if let first = items.first {
                applyDiscogsCandidate(first)
            } else {
                selectedDiscogsCandidate = nil
            }
        } catch {
            errorMessage = L("Discogs 搜索失败：\(error.userFacingMessage ?? "")", "Discogs search failed: \(error.userFacingMessage ?? "")")
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
            let items = try await repository.searchSpotifyDJs(query: keyword, limit: 8)
            discogsLinkedSpotifyCandidates = items
        } catch {
            errorMessage = L("Spotify 搜索失败：\(error.userFacingMessage ?? "")", "Spotify search failed: \(error.userFacingMessage ?? "")")
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
            let detail = try await repository.fetchDiscogsDJArtist(id: artistId)
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
            errorMessage = L("读取 Discogs 详情失败：\(error.userFacingMessage ?? "")", "Failed to load Discogs detail: \(error.userFacingMessage ?? "")")
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
                    Text(L("粉丝 \(candidate.followers)", "Followers \(candidate.followers)"))
                    Text(L("热度 \(candidate.popularity)", "Popularity \(candidate.popularity)"))
                }
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)

                if let existingName = candidate.existingDJName, !existingName.isEmpty {
                    Text(L("将合并到：\(existingName)", "Will merge into: \(existingName)"))
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

                Text(L("Discogs ID \(candidate.artistId)", "Discogs ID \(candidate.artistId)"))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)

                if let existingName = candidate.existingDJName, !existingName.isEmpty {
                    Text(L("将合并到：\(existingName)", "Will merge into: \(existingName)"))
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
            errorMessage = L("请先选择一个 Spotify DJ", "Please select a Spotify DJ first.")
            return
        }
        let finalName = spotifyDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = L("DJ 名称不能为空", "DJ name cannot be empty.")
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
            let result = try await repository.importSpotifyDJ(
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
            showDJImportSheet = false
            await load()
            errorMessage = result.action == "created"
                ? L("已导入 DJ：\(result.dj.name)", "DJ imported: \(result.dj.name)")
                : L("已更新 DJ：\(result.dj.name)", "DJ updated: \(result.dj.name)")
        } catch {
            errorMessage = L("导入失败：\(error.userFacingMessage ?? "")", "Import failed: \(error.userFacingMessage ?? "")")
        }
    }

    @MainActor
    private func confirmDiscogsImport() async {
        guard let selected = selectedDiscogsCandidate else {
            errorMessage = L("请先选择一个 Discogs DJ", "Please select a Discogs DJ first.")
            return
        }
        let finalName = discogsDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = L("DJ 名称不能为空", "DJ name cannot be empty.")
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
            let result = try await repository.importDiscogsDJ(
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
            showDJImportSheet = false
            await load()
            errorMessage = result.action == "created"
                ? L("已导入 DJ：\(result.dj.name)", "DJ imported: \(result.dj.name)")
                : L("已更新 DJ：\(result.dj.name)", "DJ updated: \(result.dj.name)")
        } catch {
            errorMessage = L("Discogs 导入失败：\(error.userFacingMessage ?? "")", "Discogs import failed: \(error.userFacingMessage ?? "")")
        }
    }

    @MainActor
    private func confirmManualImport() async {
        let finalName = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = L("DJ 名称不能为空", "DJ name cannot be empty.")
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
            let imported = try await repository.importManualDJ(
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

            if let manualAvatarData {
                _ = try await repository.uploadDJImage(
                    imageData: jpegDataForDJImport(from: manualAvatarData),
                    fileName: "dj-avatar-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    djID: imported.dj.id,
                    usage: "avatar"
                )
            }

            if let manualBannerData {
                _ = try await repository.uploadDJImage(
                    imageData: jpegDataForDJImport(from: manualBannerData),
                    fileName: "dj-banner-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    djID: imported.dj.id,
                    usage: "banner"
                )
            }

            showDJImportSheet = false
            await load()
            errorMessage = imported.action == "created"
                ? L("已手动导入 DJ：\(imported.dj.name)", "DJ imported manually: \(imported.dj.name)")
                : L("已更新 DJ：\(imported.dj.name)", "DJ updated: \(imported.dj.name)")
        } catch {
            errorMessage = L("手动导入失败：\(error.userFacingMessage ?? "")", "Manual import failed: \(error.userFacingMessage ?? "")")
        }
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
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
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

private enum DJsModuleSection: CaseIterable {
    case hot
    case rankings

    var title: String {
        switch self {
        case .hot: return L("热度 DJ", "Hot DJs")
        case .rankings: return L("榜单", "Rankings")
        }
    }
}

private enum DJsImportMode: String, CaseIterable, Identifiable {
    case spotify
    case discogs
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spotify: return L("Spotify 导入", "Import from Spotify")
        case .discogs: return L("Discogs 导入", "Import from Discogs")
        case .manual: return L("手动导入", "Manual Import")
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

                    Label(L("\(dj.followerCount ?? 0) 粉丝", "\(dj.followerCount ?? 0) followers"), systemImage: "person.2")
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

private struct DJDetailPageOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [DJDetailView.DJDetailTab: CGFloat] = [:]

    static func reduce(value: inout [DJDetailView.DJDetailTab: CGFloat], nextValue: () -> [DJDetailView.DJDetailTab: CGFloat]) {
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
        topOverlayView.backgroundColor = UIColor.black
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
        titleLabel.textColor = .white
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
}

struct DJDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    private var djsRepository: DiscoverDJsRepository {
        appContainer.discoverDJsRepository
    }

    private var newsRepository: DiscoverNewsRepository {
        appContainer.discoverNewsRepository
    }

    let djID: String

    @State private var dj: WebDJ?
    @State private var sets: [WebDJSet] = []
    @State private var djEvents: [WebEvent] = []
    @State private var ratingUnits: [WebRatingUnit] = []
    @State private var watchedSetCount = 0
    @State private var isLoading = false
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

    fileprivate enum DJDetailTab: String, CaseIterable, Identifiable {
        case intro
        case posts
        case sets
        case events
        case ratings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .intro: return L("简介", "Intro")
            case .posts: return L("动态", "Posts")
            case .sets: return "Sets"
            case .events: return L("活动", "Events")
            case .ratings: return L("打分", "Ratings")
            }
        }
    }

    var body: some View {
        Group {
            if isLoading, dj == nil {
                ProgressView(L("加载 DJ 详情...", "Loading DJ details..."))
            } else if let dj {
                DJDetailRepresentable(
                    heroView: AnyView(heroSection(dj)),
                    djTitle: dj.name,
                    tabTitles: DJDetailTab.allCases.map(\.title),
                    tabBarView: AnyView(tabBar),
                    tabPageViews: DJDetailTab.allCases.map { tab in
                        AnyView(
                            VStack(alignment: .leading, spacing: 14) {
                                tabContent(dj, tab: tab)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 20)
                        )
                    },
                    selectedIndex: selectedIndex(for: selectedTab),
                    pageProgress: pageProgress,
                    onTabChange: { index in
                        guard !isTabSwitchingByTap else { return }
                        guard DJDetailTab.allCases.indices.contains(index) else { return }
                        selectDJDetailTab(DJDetailTab.allCases[index])
                    },
                    onPageProgress: { progress in
                        guard !isTabSwitchingByTap else { return }
                        let maxProgress = CGFloat(max(0, DJDetailTab.allCases.count - 1))
                        pageProgress = min(max(progress, 0), maxProgress)
                    }
                )
                .ignoresSafeArea(edges: .top)
            } else {
                ContentUnavailableView(LL("DJ 不存在"), systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            floatingTopBar
        }
        .task {
            await load()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
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

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            isLoadingRelatedArticles = true
            async let djTask = djsRepository.fetchDJ(id: djID)
            async let setsTask = djsRepository.fetchDJSets(djID: djID)
            async let eventsTask = djsRepository.fetchDJEvents(djID: djID)
            async let ratingUnitsTask = djsRepository.fetchDJRatingUnits(djID: djID)
            async let watchedCountTask = djsRepository.fetchMyDJCheckinCount(djID: djID)
            async let relatedArticlesTask = fetchRelatedNewsArticlesForDJ(djID: djID)
            dj = try await djTask
            if let loadedDJ = dj {
                prepareDJEditDraft(from: loadedDJ)
            }
            sets = try await setsTask
            djEvents = (try? await eventsTask) ?? []
            ratingUnits = (try? await ratingUnitsTask) ?? []
            watchedSetCount = (try? await watchedCountTask) ?? 0
            relatedArticles = (try? await relatedArticlesTask) ?? []
            isLoadingRelatedArticles = false
        } catch {
            isLoadingRelatedArticles = false
            errorMessage = error.userFacingMessage
        }
    }

    private func fetchRelatedNewsArticlesForDJ(djID: String) async throws -> [DiscoverNewsArticle] {
        try await newsRepository.fetchArticlesBoundToDJ(djID: djID, maxPages: 8)
    }

    private func reloadDJRatingUnits() async {
        ratingUnits = (try? await djsRepository.fetchDJRatingUnits(djID: djID)) ?? []
    }

    private func toggleFollow(_ item: WebDJ) async {
        do {
            dj = try await djsRepository.toggleDJFollow(djID: item.id, shouldFollow: !(item.isFollowing ?? false))
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
            let items = try await djsRepository.searchSpotifyDJs(query: keyword, limit: 10)
            spotifyCandidates = items
            if let first = items.first {
                applySpotifyCandidate(first)
            } else {
                selectedSpotifyCandidate = nil
            }
        } catch {
            errorMessage = L("Spotify 搜索失败：\(error.userFacingMessage ?? "")", "Spotify search failed: \(error.userFacingMessage ?? "")")
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
                    Text(L("粉丝 \(candidate.followers)", "Followers \(candidate.followers)"))
                    Text(L("热度 \(candidate.popularity)", "Popularity \(candidate.popularity)"))
                }
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)

                if let existingName = candidate.existingDJName, !existingName.isEmpty {
                    Text(L("将合并到：\(existingName)", "Will merge into: \(existingName)"))
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
            errorMessage = L("请先选择一个 Spotify DJ", "Please select a Spotify DJ first.")
            return
        }
        let finalName = spotifyDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = L("DJ 名称不能为空", "DJ name cannot be empty.")
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
            let result = try await djsRepository.importSpotifyDJ(
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
            errorMessage = result.action == "created"
                ? L("已导入 DJ：\(result.dj.name)", "DJ imported: \(result.dj.name)")
                : L("已更新 DJ：\(result.dj.name)", "DJ updated: \(result.dj.name)")
            if result.dj.id == djID {
                await load()
            }
        } catch {
            errorMessage = L("导入失败：\(error.userFacingMessage ?? "")", "Import failed: \(error.userFacingMessage ?? "")")
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
            errorMessage = L("DJ 名称不能为空", "DJ name cannot be empty.")
            return
        }

        let aliases = editDJAliases
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        isSavingDJProfile = true
        defer { isSavingDJProfile = false }

        do {
            _ = try await djsRepository.updateDJ(
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
                _ = try await djsRepository.uploadDJImage(
                    imageData: jpegDataForDJImport(from: editAvatarData),
                    fileName: "dj-avatar-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    djID: currentDJ.id,
                    usage: "avatar"
                )
            }

            if let editBannerData {
                _ = try await djsRepository.uploadDJImage(
                    imageData: jpegDataForDJImport(from: editBannerData),
                    fileName: "dj-banner-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    djID: currentDJ.id,
                    usage: "banner"
                )
            }

            showDJEditSheet = false
            await load()
            errorMessage = L("DJ 信息已更新", "DJ profile updated.")
        } catch {
            errorMessage = L("保存失败：\(error.userFacingMessage ?? "")", "Save failed: \(error.userFacingMessage ?? "")")
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
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
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
        ZStack(alignment: .top) {
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
                colors: [.clear, Color.black.opacity(0.40), RaverTheme.background.opacity(0.80)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        aliasPillsRow(for: dj)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            Button((dj.isFollowing ?? false) ? L("已关注", "Following") : L("关注", "Follow")) {
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

                            Button(LL("去活动打卡")) {
                                selectDJDetailTab(.events)
                                errorMessage = djEvents.isEmpty
                                    ? L("请在对应活动详情页完成打卡；当前暂未找到这位 DJ 的活动记录。", "Please check in from the related event detail page; no event record is currently found for this DJ.")
                                    : L("请进入对应活动详情页完成打卡，并在活动打卡里选择本场观看的 DJ。", "Please check in from the related event detail page and select this watched DJ in event check-in.")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(RaverTheme.accent)
                            )
                            .buttonStyle(.plain)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)
                    }
                    .padding(.bottom, 6)

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
                .frame(minHeight: djNameLineCount > 1 ? 85 : 70, alignment: .bottomLeading)
                .padding(.horizontal, 16)
                .padding(.bottom, djNameLineCount > 1 ? 40 : 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
        .zIndex(1)
    }

    private var floatingTopBar: some View {
        HStack {
            floatingCircleButton(systemName: "chevron.left") {
                dismiss()
            }

            Spacer()

            if dj?.canEdit == true {
                floatingCircleButton(systemName: "square.and.pencil") {
                    guard let currentDJ = dj else { return }
                    prepareDJEditDraft(from: currentDJ)
                    showDJEditSheet = true
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, topSafeAreaInset() + 6)
        .zIndex(10)
    }

    private func floatingCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var djEditSheet: some View {
        Form {
                Section(LL("基础信息")) {
                    TextField(LL("DJ 名称"), text: $editDJName)
                    TextField(LL("别名（英文逗号分隔）"), text: $editDJAliases)
                    TextField(LL("简介"), text: $editDJBio, axis: .vertical)
                    TextField(LL("国家"), text: $editDJCountry)
                    Toggle(LL("认证 DJ"), isOn: $editDJVerified)
                }

                Section(LL("平台信息")) {
                    TextField(L("Spotify ID", "Spotify ID"), text: $editDJSpotifyID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(L("Apple Music ID", "Apple Music ID"), text: $editDJAppleMusicID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(L("Instagram URL", "Instagram URL"), text: $editDJInstagram)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(L("SoundCloud URL", "SoundCloud URL"), text: $editDJSoundcloud)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(L("X/Twitter URL", "X/Twitter URL"), text: $editDJTwitter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(LL("图片")) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $editAvatarItem, matching: .images) {
                            Label(LL("更换头像"), systemImage: "person.crop.circle")
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
                            Label(LL("更换横幅"), systemImage: "photo.rectangle")
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
                    Button(isSavingDJProfile ? L("保存中...", "Saving...") : "保存 DJ 信息") {
                        Task { await saveDJProfileEdits() }
                    }
                    .disabled(isSavingDJProfile || editDJName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(LL("编辑 DJ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("关闭", "Close")) {
                        showDJEditSheet = false
                    }
                    .disabled(isSavingDJProfile)
                }
            }
            .scrollDismissesKeyboard(.interactively)
    }

    private var spotifyImportFloatingButton: some View {
        Button {
            guard appState.session != nil else {
                errorMessage = L("请先登录后再导入 Spotify DJ", "Please log in before importing Spotify DJ.")
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
                Section(LL("搜索 Spotify DJ")) {
                    HStack(spacing: 8) {
                        TextField(LL("输入 DJ 名称"), text: $spotifySearchKeyword)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .onSubmit {
                                Task { await searchSpotifyCandidates() }
                            }

                        Button(isSearchingSpotify ? L("搜索中...", "Searching...") : "搜索") {
                            Task { await searchSpotifyCandidates() }
                        }
                        .disabled(isSearchingSpotify || spotifySearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if isSearchingSpotify {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LL("正在拉取 Spotify 候选列表..."))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }

                Section(LL("候选结果")) {
                    if spotifyCandidates.isEmpty {
                        Text(LL("暂无候选，输入名称后点击搜索。"))
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
                    Section(LL("确认导入信息")) {
                        Text(L("Spotify ID: \(selected.spotifyId)", "Spotify ID: \(selected.spotifyId)"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)

                        TextField(LL("DJ 名称"), text: $spotifyDraftName)
                        TextField(LL("别名（英文逗号分隔）"), text: $spotifyDraftAliases)
                        TextField(LL("简介"), text: $spotifyDraftBio, axis: .vertical)
                        TextField(LL("国家（可选）"), text: $spotifyDraftCountry)

                        if let existingName = selected.existingDJName, !existingName.isEmpty {
                            Text(L("检测到同名/同Spotify DJ：\(existingName)，导入时将合并更新，不会重复创建。", "Matched existing same-name/Spotify DJ: \(existingName). Import will merge update instead of creating duplicate."))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Button(isImportingSpotifyDJ ? L("导入中...", "Importing...") : L("确认导入到 DJ 数据库", "Confirm import to DJ database")) {
                            Task { await confirmSpotifyImport() }
                        }
                        .disabled(isImportingSpotifyDJ || spotifyDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle(LL("Spotify 导入"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("关闭", "Close")) {
                        showSpotifyImportSheet = false
                    }
                    .disabled(isImportingSpotifyDJ)
                }
            }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(DJDetailTab.allCases) { tab in
                    Button {
                        selectDJDetailTab(tab)
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 17, weight: tabVisualState(for: tab) ? .semibold : .medium))
                            .foregroundStyle(tabVisualState(for: tab) ? RaverTheme.accent : Color.white.opacity(0.92))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            selectDJDetailTab(tab)
                        }
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DJDetailTabFramePreferenceKey.self,
                                value: [tab: geo.frame(in: .named("DJDetailTabs"))]
                            )
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .coordinateSpace(name: "DJDetailTabs")
        .overlay(alignment: .bottomLeading) {
            if let indicator = indicatorRect {
                Capsule()
                    .fill(RaverTheme.accent)
                    .frame(width: indicator.width, height: 3)
                    .offset(x: indicator.minX, y: 0)
                    .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.75), value: indicator.minX)
                    .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.72), value: indicator.width)
                    .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(DJDetailTabFramePreferenceKey.self) { value in
            tabFrames = value
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(RaverTheme.background)
    }

    @ViewBuilder
    private func tabPager(_ dj: WebDJ, cardWidth: CGFloat) -> some View {
        GeometryReader { proxy in
            TabView(selection: $selectedTab) {
                djTabPage(dj, cardWidth: cardWidth, tab: .intro)
                    .tag(DJDetailTab.intro)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DJDetailPageOffsetPreferenceKey.self,
                                value: [.intro: geo.frame(in: .named("DJDetailPager")).minX]
                            )
                        }
                    )
                djTabPage(dj, cardWidth: cardWidth, tab: .posts)
                    .tag(DJDetailTab.posts)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DJDetailPageOffsetPreferenceKey.self,
                                value: [.posts: geo.frame(in: .named("DJDetailPager")).minX]
                            )
                        }
                    )
                djTabPage(dj, cardWidth: cardWidth, tab: .sets)
                    .tag(DJDetailTab.sets)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DJDetailPageOffsetPreferenceKey.self,
                                value: [.sets: geo.frame(in: .named("DJDetailPager")).minX]
                            )
                        }
                    )
                djTabPage(dj, cardWidth: cardWidth, tab: .events)
                    .tag(DJDetailTab.events)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DJDetailPageOffsetPreferenceKey.self,
                                value: [.events: geo.frame(in: .named("DJDetailPager")).minX]
                            )
                        }
                    )
                djTabPage(dj, cardWidth: cardWidth, tab: .ratings)
                    .tag(DJDetailTab.ratings)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DJDetailPageOffsetPreferenceKey.self,
                                value: [.ratings: geo.frame(in: .named("DJDetailPager")).minX]
                            )
                        }
                    )
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .coordinateSpace(name: "DJDetailPager")
            .onAppear {
                pagerWidth = max(1, proxy.size.width)
                pageProgress = CGFloat(selectedIndex(for: selectedTab))
            }
            .onChange(of: proxy.size.width) { _, newValue in
                pagerWidth = max(1, newValue)
            }
            .onChange(of: selectedTab) { _, newValue in
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                    pageProgress = CGFloat(selectedIndex(for: newValue))
                }
            }
            .onPreferenceChange(DJDetailPageOffsetPreferenceKey.self) { values in
                updatePageProgress(with: values)
            }
        }
    }

    @ViewBuilder
    private func djTabPage(_ dj: WebDJ, cardWidth: CGFloat, tab: DJDetailTab) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                tabContent(dj, tab: tab)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.always)
        .contentShape(Rectangle())
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
            ProgressView(LL("正在加载相关资讯..."))
                .padding(.vertical, 8)
        } else if relatedArticles.isEmpty {
            Text(LL("暂无相关资讯"))
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
            infoPill(icon: "person.2", text: L("\(dj.followerCount ?? 0) 粉丝", "\(dj.followerCount ?? 0) followers"))
            infoPill(icon: "headphones", text: L("已看 \(watchedSetCount) 场", "Watched \(watchedSetCount) sets"))
            if let country = dj.country, !country.isEmpty {
                infoPill(icon: "globe", text: country)
            }
            if dj.isVerified == true {
                infoPill(icon: "checkmark.seal.fill", text: L("认证", "Verified"))
            }
        }

        socialLinks(dj)

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

        let contributorUsers = (dj.contributors ?? []).filter { !$0.username.isEmpty }
        if !contributorUsers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(LL("贡献者"))
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
                    Text(LL("贡献者"))
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
            Text(LL("暂无内容"))
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
            Text(LL("暂无历史活动"))
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 6)
        } else {
            ForEach(djEvents) { event in
                Button {
                    appPush(.eventDetail(eventID: event.id))
                } label: {
                    historyEventRow(event)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var ratingsTabContent: some View {
        if ratingUnits.isEmpty {
            Text(LL("暂无关联打分"))
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
        let locationText = [event.city, event.country, event.venueName]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 4) {
            Text(event.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(2)

            Text(djHistoryEventDateText(event))
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)

            Text(locationText.isEmpty ? L("地点待补充", "Location pending") : locationText)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
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
                    Text(L("事件：\(eventName)", "Event: \(eventName)"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Text(
                    L(
                        "评分 \(String(format: "%.1f", unit.rating)) · \(unit.ratingCount) 人",
                        "Rating \(String(format: "%.1f", unit.rating)) · \(unit.ratingCount) ratings"
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
