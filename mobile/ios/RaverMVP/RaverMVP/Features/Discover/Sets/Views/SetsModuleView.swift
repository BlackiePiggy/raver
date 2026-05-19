import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import WebKit
import UIKit
import Photos
import CoreImage.CIFilterBuiltins
import MapKit
import CoreLocation
import CoreText

private struct SetCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: SetShareCardPayload
}

private struct SetSharePreviewCard: View {
    let payload: SetShareCardPayload

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewImage
                .frame(width: 84, height: 84 * 9 / 16)
                .overlay(alignment: .bottomLeading) {
                    if let badge = payload.badgeText?.nilIfBlank {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.58), in: Capsule())
                            .padding(.leading, 8)
                            .padding(.bottom, 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(payload.setTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if let metadataText {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metadataText: String? {
        let parts = [
            payload.djName?.nilIfBlank,
            payload.eventName?.nilIfBlank ?? payload.venue?.nilIfBlank
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
            colors: [Color(red: 0.10, green: 0.14, blue: 0.20), Color(red: 0.16, green: 0.24, blue: 0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }
}

struct SetsModuleView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var repository: SetListRepository {
        appContainer.setListRepository
    }

    @State private var sets: [WebDJSet] = []
    @State private var page = 1
    @State private var totalPages = 1
    @State private var sortBy = "latest"
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var bannerMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            if isRefreshing || bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新 Sets", "Updating sets", "Setを更新中"))
                    }
                    if let bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
                        ) {
                            Task { await reload() }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Group {
                switch phase {
                case .idle, .initialLoading:
                    DiscoverGridSkeletonView()
                case .failure(let message), .offline(let message):
                    ScrollView {
                        ScreenErrorCard(
                            title: LT("Sets 加载失败", "Sets Failed to Load", "Setの読み込みに失敗しました"),
                            message: message
                        ) {
                            Task { await reload() }
                        }
                        .padding(16)
                        .padding(.top, 72)
                    }
                case .empty:
                    ContentUnavailableView(
                        LT("暂无 Sets", "No sets yet", "Setはまだありません"),
                        systemImage: "waveform.path.ecg"
                    )
                case .success:
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(displayedSets) { set in
                                Button {
                                    discoverPush(.setDetail(setID: set.id))
                                } label: {
                                    DJSetGridCard(set: set)
                                }
                                .buttonStyle(.plain)
                            }

                            if page < totalPages {
                                Button(LT("加载更多", "Load More", "さらに読み込む")) {
                                    Task { await loadMore() }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .gridCellColumns(2)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .raverTabBarBottomPadding(16)
                    }
                    .refreshable {
                        await reload()
                    }
                }
            }
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    Menu {
                        Button(LT("最新", "最新", "最新")) {
                            sortBy = "latest"
                            Task { await reload() }
                        }
                        Button(LT("热门", "热门", "人気")) {
                            sortBy = "popular"
                            Task { await reload() }
                        }
                        Button(LT("Tracks", "Tracks", "曲目")) {
                            sortBy = "tracks"
                            Task { await reload() }
                        }
                    } label: {
                        Label(sortTitle, systemImage: "arrow.up.arrow.down.circle")
                    }
                    .labelStyle(.titleOnly)
                    .font(.subheadline)
                    .buttonStyle(.bordered)

                    Button {
                        discoverPush(.setCreate)
                    } label: {
                        Label(LT("发布", "发布", "公開"), systemImage: "plus")
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(RaverTheme.background)
        }
        .task {
            await reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverSetDidSave)) { _ in
            Task { await reload() }
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func reload() async {
        let hadContent = !sets.isEmpty
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
            page = 1
            totalPages = 1
            sets = []
        }
        defer { isRefreshing = false }
        await loadMore(reset: true)
    }

    private func loadMore(reset: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let requestedPage = reset ? 1 : page
            let result = try await repository.fetchDJSets(page: requestedPage, limit: 20, sortBy: sortBy, djID: nil)
            if reset {
                sets = result.items
            } else {
                sets.append(contentsOf: result.items)
            }
            totalPages = result.pagination?.totalPages ?? 1
            page = requestedPage + 1
            phase = sets.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            if error.isUserInitiatedCancellation {
                if sets.isEmpty, case .initialLoading = phase {
                    phase = .idle
                }
                return
            }
            let message = error.userFacingMessage ?? LT("Sets 加载失败，请稍后重试", "Failed to load sets. Please try again later.", "Setを読み込めませんでした。時間をおいて再試行してください。")
            if reset {
                phase = .failure(message: message)
            } else if !sets.isEmpty {
                bannerMessage = message
            } else {
                phase = .failure(message: message)
            }
        }
    }

    private var displayedSets: [WebDJSet] {
        sets
    }

    private var sortTitle: String {
        switch sortBy {
        case "popular": return LT("热门", "Popular", "人気")
        case "tracks": return "Tracks"
        default: return LT("最新", "Latest", "最新")
        }
    }
}

struct DJSetGridCard: View {
    let set: WebDJSet

    private var djLabel: String {
        if let name = set.dj?.name.nilIfBlank {
            return name
        }
        if let custom = set.customDjNames.first?.nilIfBlank {
            return custom
        }
        if let djID = set.djId?.nilIfBlank {
            return djID
        }
        return LT("未关联 DJ", "No DJ Linked", "DJ未関連")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // 1. 用底板作为主布局，严格锁定 16:9 的比例
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(RaverTheme.card)
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                // 2. 将异步加载的图片逻辑全部放入 overlay 中
                .overlay {
                    if let thumb = AppConfig.resolvedURLString(set.thumbnailUrl), !thumb.isEmpty {
                        ImageLoaderView(urlString: thumb)
                            .background(
                                Image(systemName: "video")
                                    .font(.title3)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            )
                    } else {
                        Image(systemName: "video")
                            .font(.title3)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                // 3. 裁剪掉 overlay 中超出 16:9 底板的视觉部分
                .clipped()

            Text(set.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

            HStack(spacing: 6) {
                // ... 你原来的头像和 DJ 名称代码保持不变即可 ...
                if let avatar = AppConfig.resolvedDJAvatarURLString(set.dj?.avatarSmallUrl ?? set.dj?.avatarUrl, size: .small),
                   !avatar.isEmpty {
                    ImageLoaderView(urlString: avatar)
                        .background(DefaultDJAvatarPlaceholderView(size: 18, backgroundColor: RaverTheme.card))
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                } else {
                    DefaultDJAvatarPlaceholderView(size: 18, backgroundColor: RaverTheme.card)
                }

                Text(djLabel)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.bottom, 6)
    }
}

struct DJSetDetailView: View {
    enum PlaybackMode {
        case video
        case audioOnly
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    private var setReadRepository: SetReadRepository {
        appContainer.setReadRepository
    }

    private var setCommentRepository: SetCommentRepository {
        appContainer.setCommentRepository
    }

    private var setCommandRepository: SetCommandRepository {
        appContainer.setCommandRepository
    }

    private var tracklistRepository: TracklistRepository {
        appContainer.tracklistRepository
    }

    private var setEventLookupRepository: SetEventLookupRepository {
        appContainer.setEventLookupRepository
    }

    let setID: String
    let playbackMode: PlaybackMode

    @State private var set: WebDJSet?
    @State private var comments: [WebSetComment] = []
    @State private var inputComment = ""
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var showTrackEditor = false
    @State private var bannerMessage: String?
    @State private var errorMessage: String?
    @State private var playbackTime: Double = 0
    @State private var playbackDuration: Double = 0
    @State private var pendingSeekTime: Double?
    @State private var activeTrackID: String?
    @State private var nativePlayerError: String?
    @State private var embeddedPlayerError: String?
    @StateObject private var nativePlayerSession = NativeVideoSession()
    @State private var isTracklistExpanded = false
    @State private var tracklists: [WebTracklistSummary] = []
    @State private var selectedTracklistID: String?
    @State private var currentTracklistInfo: WebTracklistDetail?
    @State private var currentTracks: [WebDJSetTrack] = []
    @State private var showTracklistSelector = false
    @State private var showTracklistUpload = false
    @State private var wheelDragTranslation: CGFloat = 0
    @State private var wheelManualShift = 0
    @State private var wheelLastHapticShift = 0
    @State private var wheelAutoRecenterTask: Task<Void, Never>?
    @State private var playerSeekDeltaSeconds: Double = 0
    @State private var showPlayerSeekIndicator = false
    @State private var hideSeekIndicatorTask: Task<Void, Never>?
    @State private var showPlayerVolumeIndicator = false
    @State private var hideVolumeIndicatorTask: Task<Void, Never>?
    @State private var playerVolumeLevel: Float = 1.0
    @State private var playerVolumeBaseLevel: Float?
    @State private var playerVolumeHapticStep = -1
    @State private var playerGestureAxis: PlayerGestureAxis = .undecided
    @State private var controlsVisible = true
    @State private var controlsAutoHideTask: Task<Void, Never>?
    @State private var isPlaybackPaused = true
    @State private var isTracklistHidden = false
    @State private var isScrubbingProgress = false
    @State private var relatedEvent: WebEvent?
    @State private var audioListenSetID: String?
    @State private var shareMorePresentation: SetCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: SetCardSharePresentation?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    init(setID: String, playbackMode: PlaybackMode = .video) {
        self.setID = setID
        self.playbackMode = playbackMode
    }

    private var isAudioOnlyMode: Bool {
        playbackMode == .audioOnly
    }

    private var immersiveTrailingAction: AnyView? {
        guard let _ = set else { return nil }
        return AnyView(
            RaverNavigationCircleIconButton(
                systemName: "ellipsis",
                style: .immersiveAdaptive
            ) {
                shareMorePresentation = SetCardSharePresentation(
                    payload: makeSetShareCardPayload()
                )
                isShareMorePanelVisible = false
            }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch phase {
                case .idle, .initialLoading:
                    SetDetailSkeletonView()
                case .failure(let message), .offline(let message):
                    ScrollView {
                        ScreenErrorCard(message: message) {
                            Task { await load() }
                        }
                    }
                    .padding(16)
                    .padding(.top, 96)
                case .empty:
                    ContentUnavailableView(LT("Set 不存在", "Set 不存在", "Setが存在しません"), systemImage: "waveform.badge.exclamationmark")
                case .success:
                    if let set {
                        GeometryReader { proxy in
                            if !isAudioOnlyMode, proxy.size.width > proxy.size.height {
                                landscapePlayerContent(for: set, in: proxy.size)
                            } else {
                                portraitDetailContent(for: set)
                            }
                        }
                        .onChange(of: playbackTime) { _, newTime in
                            syncActiveTrack(for: set, at: newTime)
                        }
                        .onDisappear {
                            hideSeekIndicatorTask?.cancel()
                            hideSeekIndicatorTask = nil
                            hideVolumeIndicatorTask?.cancel()
                            hideVolumeIndicatorTask = nil
                            wheelAutoRecenterTask?.cancel()
                            wheelAutoRecenterTask = nil
                            controlsAutoHideTask?.cancel()
                            controlsAutoHideTask = nil
                            nativePlayerSession.pause()
                            nativePlayerSession.reset()
                            if !isAudioOnlyMode {
                                forcePortraitOrientation()
                            }
                        }
                    } else {
                        ContentUnavailableView(LT("Set 不存在", "Set 不存在", "Setが存在しません"), systemImage: "waveform.badge.exclamationmark")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            if !isAudioOnlyMode {
                Color.black
                    .frame(maxWidth: .infinity)
                    .frame(height: topSafeAreaInset() + 8)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }

            if isRefreshing || bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新 Set 详情", "Updating set details", "Set詳細を更新中"))
                    }
                    if let bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
                        ) {
                            Task { await load() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, topSafeAreaInset() + 20)
            }

            if isAudioOnlyMode {
                RaverImmersiveFloatingTopBar(
                    onBack: handleImmersiveBack,
                    buttonStyle: .glass,
                    trailing: immersiveTrailingAction
                )
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RaverTheme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: Binding(
            get: { set != nil && showTrackEditor },
            set: { if !$0 { showTrackEditor = false } }
        )) {
            if let set {
                NavigationStack {
                    TracklistEditorView(
                        set: set,
                        currentTracklist: currentTracklistInfo,
                        selectedTracklistID: selectedTracklistID
                    ) {
                        Task { await load() }
                    }
                }
                .raverEnableCustomSwipeBack(edgeRatio: 0.2)
            }
        }
        .sheet(isPresented: Binding(
            get: { set != nil && showTracklistSelector },
            set: { if !$0 { showTracklistSelector = false } }
        )) {
            if let set {
                NavigationStack {
                    TracklistSelectorSheet(
                        set: set,
                        tracklists: tracklists,
                        selectedTracklistID: selectedTracklistID
                    ) { selectedID in
                        Task {
                            await switchTracklist(selectedID)
                        }
                    }
                }
                .raverEnableCustomSwipeBack(edgeRatio: 0.2)
            }
        }
        .sheet(isPresented: Binding(
            get: { set != nil && showTracklistUpload },
            set: { if !$0 { showTracklistUpload = false } }
        )) {
            if let set {
                NavigationStack {
                    UploadTracklistSheet(set: set) { uploaded in
                        Task {
                            await refreshTracklists()
                            await switchTracklist(uploaded.id)
                        }
                    }
                }
                .raverEnableCustomSwipeBack(edgeRatio: 0.2)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { audioListenSetID != nil },
                set: { if !$0 { audioListenSetID = nil } }
            )
            ) {
                if let audioSetID = audioListenSetID {
                    NavigationStack {
                        DJSetDetailView(setID: audioSetID, playbackMode: .audioOnly)
                    }
                    .raverEnableCustomSwipeBack(edgeRatio: 0.2)
                }
            }
        .onAppear {
            if !isAudioOnlyMode {
                AppOrientationLock.shared.allowLandscape()
            }
        }
        .onDisappear {
            if !isAudioOnlyMode {
                AppOrientationLock.shared.lockPortrait(force: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverSetDidSave)) { notification in
            let savedSetID = notification.object as? String
            guard savedSetID == nil || savedSetID == setID else { return }
            Task { await load() }
        }
        .task {
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
                SetSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
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
    private func portraitDetailContent(for set: WebDJSet) -> some View {
        if isAudioOnlyMode {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    audioHeroSection(for: set)

                    currentTrackPinnedCard(for: set)
                        .padding(.top, 2)
                        .padding(.bottom, isTracklistExpanded ? 8 : 10)

                    if isTracklistExpanded {
                        expandedTracklistSection(for: set)
                            .padding(.bottom, 10)
                    }

                    setDetailBodyContent(for: set, showPrimaryHeader: false)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
        } else {
            VStack(spacing: 0) {
                playerViewport(for: set, isFullscreen: false, reservedTrailingWidth: 0)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipped()

                currentTrackPinnedCard(for: set)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, isTracklistExpanded ? 8 : 10)

                if isTracklistExpanded {
                    expandedTracklistSection(for: set)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        setDetailBodyContent(for: set)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 18)
                }
            }
        }
    }

    @ViewBuilder
    private func setDetailBodyContent(for set: WebDJSet, showPrimaryHeader: Bool = true) -> some View {
        if showPrimaryHeader {
            Text(set.title)
                .font(.title3.bold())
                .foregroundStyle(RaverTheme.primaryText)

            if let dj = set.dj {
                Button {
                    appPush(.djDetail(djID: dj.id))
                } label: {
                    HStack(spacing: 8) {
                        if let avatar = AppConfig.resolvedDJAvatarURLString(dj.avatarSmallUrl ?? dj.avatarUrl, size: .small),
                           !avatar.isEmpty {
                            ImageLoaderView(urlString: avatar)
                                .background(Circle().fill(RaverTheme.card))
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(RaverTheme.card)
                                .frame(width: 22, height: 22)
                        }
                        Text(dj.name)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    Circle()
                        .fill(RaverTheme.card)
                        .frame(width: 22, height: 22)
                    Text(primaryDJLabel(for: set))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .font(.subheadline)
                }
            }
        }

        let linkedEventName = (set.eventName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let relatedEvent {
            Button {
                appPush(.eventDetail(eventID: relatedEvent.id))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                    Text(LT("Sets on：\(relatedEvent.name)", "Sets on: \(relatedEvent.name)", "\(relatedEvent.name) のSet"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
        } else if !linkedEventName.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                Text(LT("Sets on：\(linkedEventName)", "Sets on: \(linkedEventName)", "\(linkedEventName) のSet"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .lineLimit(1)
            }
        }

        if let playerError = nativePlayerError ?? embeddedPlayerError {
            VStack(alignment: .leading, spacing: 6) {
                Text(playerError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }

        Text(
            LT("\(sortedTracks(for: set).count) 首曲目 · \(set.viewCount) 次播放", "\(sortedTracks(for: set).count) tracks · \(set.viewCount) views", "\(sortedTracks(for: set).count)曲 · \(set.viewCount)回再生")
        )
        .font(.caption)
        .foregroundStyle(RaverTheme.secondaryText)

        contributorSection(for: set)
        commentsSection
    }

    @ViewBuilder
    private func audioHeroSection(for set: WebDJSet) -> some View {
        GeometryReader { proxy in
            let side = min(max(220, proxy.size.width * 0.72), 340)
            let activeTrack = sortedTracks(for: set).first(where: { $0.id == activeTrackID })

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.92),
                                Color(red: 0.08, green: 0.10, blue: 0.16),
                                Color.black.opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 14) {
                    audioArtwork(for: set, size: side)
                        .padding(.top, 18)

                    VStack(spacing: 4) {
                        Text(set.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        if let activeTrack {
                            Text(activeTrack.title)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.78))
                                .lineLimit(1)
                        } else {
                            Text(LT("音频收听模式", "Audio Listen Mode", "音声視聴モード"))
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.78))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let source = resolvedPlaybackSource(for: set) {
                    switch source {
                    case .native(let playableURL):
                        EmbeddedNativeAudioPlayer(
                            session: nativePlayerSession,
                            mediaURL: playableURL,
                            currentTime: $playbackTime,
                            duration: $playbackDuration,
                            pendingSeekTime: $pendingSeekTime,
                            isPaused: isPlaybackPaused,
                            onReady: {},
                            onPlaybackStateChanged: { paused in
                                if isPlaybackPaused != paused {
                                    isPlaybackPaused = paused
                                }
                            },
                            onError: { message in
                                nativePlayerError = message
                            }
                        )
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .allowsHitTesting(false)
                    case .youtube(let videoID):
                        SimpleYouTubeEmbedView(
                            videoID: videoID,
                            onError: { message in
                                embeddedPlayerError = message
                            }
                        )
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 430)
    }

    @ViewBuilder
    private func audioArtwork(for set: WebDJSet, size: CGFloat) -> some View {
        if let thumb = AppConfig.resolvedURLString(set.thumbnailUrl),
           !thumb.isEmpty,
           URL(string: thumb) != nil {
            ImageLoaderView(urlString: thumb)
                .background(audioArtworkFallback)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.42), radius: 16, x: 0, y: 8)
        } else {
            audioArtworkFallback
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.42), radius: 16, x: 0, y: 8)
        }
    }

    private var audioArtworkFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.18, blue: 0.28),
                    Color(red: 0.09, green: 0.11, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(RaverTheme.accent)
        }
    }

    @ViewBuilder
    private func audioTransportSection(for set: WebDJSet) -> some View {
        let total = max(1, resolvedDuration(for: set))
        let current = min(max(playbackTime, 0), total)

        VStack(spacing: 10) {
            HStack(spacing: 30) {
                Button {
                    applySeekDelta(-15, in: set)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                }
                .buttonStyle(.plain)

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaybackPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(RaverTheme.accent)
                        )
                        .shadow(color: RaverTheme.accent.opacity(0.38), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)

                Button {
                    applySeekDelta(15, in: set)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                }
                .buttonStyle(.plain)
            }

            Slider(
                value: Binding(
                    get: { min(max(playbackTime, 0), total) },
                    set: { seekToTime($0, in: set) }
                ),
                in: 0...total
            )
            .tint(RaverTheme.accent)

            HStack {
                Text(formatTrackTime(Int(current)))
                Spacer()
                Text(formatTrackTime(Int(total)))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func playerViewport(for set: WebDJSet, isFullscreen: Bool, reservedTrailingWidth: CGFloat) -> some View {
        if case .youtube = resolvedPlaybackSource(for: set) {
            playerSection(for: set)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
        GeometryReader { proxy in
            let interactiveWidth = max(40, proxy.size.width - reservedTrailingWidth)
            ZStack {
                playerSection(for: set)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                playerGestureLayer(for: set, reservedTrailingWidth: reservedTrailingWidth)

                if showPlayerSeekIndicator {
                    Text(playerSeekIndicatorText(for: set))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.58))
                        .clipShape(Capsule())
                        .position(
                            x: (interactiveWidth / 2) + 6,
                            y: proxy.size.height * 0.22
                        )
                }

                if showPlayerVolumeIndicator {
                    playerVolumeIndicatorOverlay
                        .position(
                            x: interactiveWidth / 2,
                            y: proxy.size.height / 2
                        )
                }

                playerControlsOverlay(
                    for: set,
                    isFullscreen: isFullscreen,
                    interactiveWidth: interactiveWidth
                )
                .opacity(controlsVisible ? 1 : 0)
                .allowsHitTesting(controlsVisible)
            }
            .animation(.easeInOut(duration: 0.2), value: controlsVisible)
            .onAppear {
                playerVolumeLevel = min(max(nativePlayerSession.player.volume, 0), 1)
                showControlsTemporarily()
            }
        }
        }
    }

    @ViewBuilder
    private func playerGestureLayer(for set: WebDJSet, reservedTrailingWidth: CGFloat) -> some View {
        GeometryReader { proxy in
            let interactiveWidth = max(40, proxy.size.width - reservedTrailingWidth)
            Color.clear
                .frame(width: interactiveWidth, height: proxy.size.height, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    togglePlayback()
                    showControlsTemporarily()
                }
                .onTapGesture {
                    handleSingleTapControls()
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            handlePlayerDragChanged(value, viewportHeight: proxy.size.height)
                        }
                        .onEnded { value in
                            handlePlayerDragEnded(value, in: set, viewportHeight: proxy.size.height)
                        }
                )
        }
    }

    @ViewBuilder
    private func playerControlsOverlay(for set: WebDJSet, isFullscreen: Bool, interactiveWidth: CGFloat) -> some View {
        let controlHitSize: CGFloat = 46
        let topHorizontalPadding: CGFloat = isFullscreen ? 100 : 12
        let topPadding: CGFloat = isFullscreen
            ? 10
            : 10
        ZStack {
            VStack {
                HStack {
                    setsPlayerOverlayIconButton(systemName: "chevron.left") {
                        handleImmersiveBack()
                    }

                    Spacer()

                    setsPlayerOverlayIconButton(systemName: "ellipsis") {
                        shareMorePresentation = SetCardSharePresentation(
                            payload: makeSetShareCardPayload()
                        )
                        isShareMorePanelVisible = false
                        showControlsTemporarily()
                    }
                }
                .padding(.horizontal, topHorizontalPadding)
                .padding(.top, topPadding)

                Spacer()
                VStack(spacing: 1) {
                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: isPlaybackPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.65), radius: 6, x: 0, y: 1)
                        }
                        .frame(width: controlHitSize, height: controlHitSize)
                        .contentShape(Circle())
                        .buttonStyle(.plain)

                        playerProgressScrubber(for: set)
                            .frame(height: 14)

                        if !isAudioOnlyMode {
                            Button {
                                if isFullscreen {
                                    forcePortraitOrientation()
                                } else {
                                    forceLandscapeOrientation()
                                }
                                showControlsTemporarily()
                            } label: {
                                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 34, height: 34)
                                    .shadow(color: Color.black.opacity(0.55), radius: 4, x: 0, y: 1)
                            }
                            .frame(width: controlHitSize, height: controlHitSize)
                            .contentShape(Circle())
                            .buttonStyle(.plain)
                        }
                    }
                    .offset(y: 16)

                    HStack {
                        Text(formatTrackTime(Int(playbackTime)))
                        Spacer()
                        Text(formatTrackTime(Int(max(1, resolvedDuration(for: set)))))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.leading, controlHitSize + 8)
                    .padding(.trailing, controlHitSize + 8)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 6)
                .frame(width: interactiveWidth, alignment: .leading)
                .padding(.leading, 2)
                .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private func playerProgressScrubber(for set: WebDJSet) -> some View {
        GeometryReader { geo in
            let total = max(1, resolvedDuration(for: set))
            let normalized = min(max(playbackTime / total, 0), 1)
            let thumbSize: CGFloat = isScrubbingProgress ? 12 : 10
            let trackHeight: CGFloat = isScrubbingProgress ? 5 : 4
            let effectiveWidth = max(1, geo.size.width - thumbSize)
            let thumbX = (effectiveWidth * normalized)
            let activeColor = isScrubbingProgress ? Color(red: 0.42, green: 0.24, blue: 0.78) : RaverTheme.accent

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(height: 3)

                Capsule()
                    .fill(activeColor)
                    .frame(width: max(trackHeight, thumbX + (thumbSize / 2)), height: trackHeight)

                Circle()
                    .fill(activeColor)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.35), radius: isScrubbingProgress ? 3 : 1, x: 0, y: 0)
                    .offset(x: thumbX)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbingProgress = true
                        let ratio = min(max(value.location.x / max(1, geo.size.width), 0), 1)
                        seekToTime(total * ratio, in: set)
                        showControlsTemporarily()
                    }
                    .onEnded { value in
                        let ratio = min(max(value.location.x / max(1, geo.size.width), 0), 1)
                        seekToTime(total * ratio, in: set)
                        isScrubbingProgress = false
                        scheduleControlsAutoHide()
                    }
            )
        }
    }

    private enum PlayerGestureAxis {
        case undecided
        case horizontal
        case vertical
    }

    private var playerVolumeLevelClamped: Float {
        min(max(playerVolumeLevel, 0), 1)
    }

    private var playerVolumeIconName: String {
        let level = playerVolumeLevelClamped
        if level <= 0.001 { return "speaker.slash.fill" }
        if level < 0.5 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    @ViewBuilder
    private var playerVolumeIndicatorOverlay: some View {
        let ratio = CGFloat(playerVolumeLevelClamped)

        HStack(spacing: 10) {
            Image(systemName: playerVolumeIconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.94))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 132, height: 6)

                if ratio > 0.001 {
                    Capsule()
                        .fill(RaverTheme.accent)
                        .frame(width: max(8, 132 * ratio), height: 6)
                }
            }
            .animation(.easeOut(duration: 0.15), value: ratio)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 16, x: 0, y: 6)
    }

    private func handlePlayerDragChanged(_ value: DragGesture.Value, viewportHeight: CGFloat) {
        if playerGestureAxis == .undecided {
            let horizontal = abs(value.translation.width)
            let vertical = abs(value.translation.height)
            guard max(horizontal, vertical) >= 8 else { return }
            playerGestureAxis = horizontal >= vertical ? .horizontal : .vertical
        }

        switch playerGestureAxis {
        case .horizontal:
            handlePlayerSeekDragChanged(value)
        case .vertical:
            handlePlayerVolumeDragChanged(value, viewportHeight: viewportHeight)
        case .undecided:
            break
        }
    }

    private func handlePlayerDragEnded(_ value: DragGesture.Value, in set: WebDJSet, viewportHeight: CGFloat) {
        switch playerGestureAxis {
        case .horizontal:
            handlePlayerSeekDragEnded(value, in: set)
        case .vertical:
            handlePlayerVolumeDragEnded(value, viewportHeight: viewportHeight)
        case .undecided:
            break
        }

        playerGestureAxis = .undecided
        playerVolumeBaseLevel = nil
    }

    private func handlePlayerSeekDragChanged(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        guard abs(horizontal) > abs(vertical) else { return }

        playerSeekDeltaSeconds = Double(horizontal / 8)
        showControlsTemporarily()
        if !showPlayerSeekIndicator {
            showPlayerSeekIndicator = true
        }
        hideSeekIndicatorTask?.cancel()
    }

    private func handlePlayerSeekDragEnded(_ value: DragGesture.Value, in set: WebDJSet) {
        let horizontal = value.predictedEndTranslation.width
        let vertical = value.predictedEndTranslation.height
        guard abs(horizontal) > abs(vertical) else {
            playerSeekDeltaSeconds = 0
            scheduleSeekIndicatorHide()
            return
        }

        let deltaSeconds = Double(horizontal / 8)
        applySeekDelta(deltaSeconds, in: set)
        playerSeekDeltaSeconds = 0
        scheduleSeekIndicatorHide()
    }

    private func handlePlayerVolumeDragChanged(_ value: DragGesture.Value, viewportHeight: CGFloat) {
        if playerVolumeBaseLevel == nil {
            playerVolumeBaseLevel = min(max(nativePlayerSession.player.volume, 0), 1)
        }

        let base = playerVolumeBaseLevel ?? 1
        let sensitivity = max(180, viewportHeight * 0.75)
        let delta = Float(-value.translation.height / sensitivity)
        let targetVolume = min(max(base + delta, 0), 1)

        nativePlayerSession.player.volume = targetVolume
        playerVolumeLevel = targetVolume
        showPlayerVolumeIndicator = true
        showControlsTemporarily()

        let currentStep = Int((targetVolume * 10).rounded())
        if currentStep != playerVolumeHapticStep {
            playerVolumeHapticStep = currentStep
            emitSelectionHaptic()
        }

        hideVolumeIndicatorTask?.cancel()
    }

    private func handlePlayerVolumeDragEnded(_ value: DragGesture.Value, viewportHeight: CGFloat) {
        if playerVolumeBaseLevel == nil {
            handlePlayerVolumeDragChanged(value, viewportHeight: viewportHeight)
        }
        scheduleVolumeIndicatorHide()
    }

    private func applySeekDelta(_ deltaSeconds: Double, in set: WebDJSet) {
        guard deltaSeconds != 0 else { return }
        let total = resolvedDuration(for: set)
        let upperBound = total > 0 ? total : Double.greatestFiniteMagnitude
        let target = min(max(playbackTime + deltaSeconds, 0), upperBound)
        seekToTime(target, in: set)
        emitSelectionHaptic()
    }

    private func seekToTime(_ target: Double, in set: WebDJSet) {
        playbackTime = target
        syncActiveTrack(for: set, at: target)
        if resolvedPlaybackSource(for: set) != nil {
            pendingSeekTime = target
        }
    }

    private func showControlsTemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
        }
        scheduleControlsAutoHide()
    }

    private func handleSingleTapControls() {
        if controlsVisible {
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible = false
            }
        } else {
            showControlsTemporarily()
        }
    }

    private func scheduleControlsAutoHide() {
        controlsAutoHideTask?.cancel()
        controlsAutoHideTask = nil

        controlsAutoHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controlsVisible = false
                }
            }
        }
    }

    private func setsPlayerOverlayIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 38, height: 38)
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 3)
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .buttonStyle(.plain)
    }

    private func emitSelectionHaptic() {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    private func scheduleSeekIndicatorHide() {
        hideSeekIndicatorTask?.cancel()
        hideSeekIndicatorTask = Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showPlayerSeekIndicator = false
            }
        }
    }

    private func scheduleVolumeIndicatorHide() {
        hideVolumeIndicatorTask?.cancel()
        hideVolumeIndicatorTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showPlayerVolumeIndicator = false
            }
        }
    }

    private func playerSeekIndicatorText(for set: WebDJSet) -> String {
        let total = resolvedDuration(for: set)
        let upperBound = total > 0 ? total : Double.greatestFiniteMagnitude
        let preview = min(max(playbackTime + playerSeekDeltaSeconds, 0), upperBound)
        let prefix = playerSeekDeltaSeconds >= 0 ? "+" : "-"
        return "\(prefix)\(Int(abs(playerSeekDeltaSeconds)))s  \(formatTrackTime(Int(preview)))"
    }

    private func togglePlayback() {
        isPlaybackPaused.toggle()
        showControlsTemporarily()
        emitSelectionHaptic()
    }

    private func forceLandscapeOrientation() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    }

    private func forcePortraitOrientation() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }

    private func isLandscapeInterface() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .interfaceOrientation
            .isLandscape ?? false
    }

    private func handleImmersiveBack() {
        if !isAudioOnlyMode, isLandscapeInterface() {
            forcePortraitOrientation()
            showControlsTemporarily()
            return
        }
        if !isAudioOnlyMode {
            forcePortraitOrientation()
        }
        dismiss()
    }

    @ViewBuilder
    private func landscapePlayerContent(for set: WebDJSet, in size: CGSize) -> some View {
        let wheelWidth = min(max(size.width * 0.34, 160), 320)
        let reservedWidth = isTracklistHidden ? 34.0 : wheelWidth
        ZStack(alignment: .topLeading) {
            playerViewport(for: set, isFullscreen: true, reservedTrailingWidth: reservedWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if isTracklistHidden {
                    collapsedTracklistOverlay(for: set, width: wheelWidth)
                } else {
                    trackWheelOverlay(for: set, width: wheelWidth)
                }
            }
            .ignoresSafeArea()

            if let playerError = nativePlayerError ?? embeddedPlayerError {
                VStack {
                    Spacer()
                    Text(playerError)
                        .font(.caption)
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.55))
                        .padding(.bottom, 14)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func trackWheelOverlay(for set: WebDJSet, width: CGFloat) -> some View {
        let tracks = sortedTracks(for: set)
        let activeIndex = resolvedActiveTrackIndex(in: tracks)
        let clampedShift = CGFloat(currentWheelShift(activeIndex: activeIndex, trackCount: tracks.count))

        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.36),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            if tracks.isEmpty {
                Text(LT("暂无 Tracklist", "暂无 Tracklist", "Tracklistはまだありません"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            } else {
                ZStack {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        let distance = CGFloat(index - activeIndex) - clampedShift
                        if abs(distance) <= 3.5 {
                            let prominence = max(0, 1 - min(abs(distance), 1))
                            let opacity = max(0.16, 1 - (abs(distance) * 0.24))
                            let scale = max(0.82, 1 - (abs(distance) * 0.09))

                            wheelTrackEntry(
                                track: track,
                                in: set,
                                prominence: prominence,
                                opacity: opacity
                            )
                                .frame(height: wheelStepHeight)
                                .scaleEffect(scale)
                                .rotation3DEffect(
                                    .degrees(Double(distance) * -12),
                                    axis: (x: 1, y: 0, z: 0),
                                    perspective: 0.65
                                )
                                .offset(y: distance * wheelStepHeight)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .clipped()
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    handleWheelDragChanged(value, tracks: tracks, activeIndex: activeIndex)
                }
                .onEnded { value in
                    handleWheelDragEnded(value, tracks: tracks, activeIndex: activeIndex, in: set)
                }
        )
        .onTapGesture {
            handleWheelTap(tracks: tracks, activeIndex: activeIndex, in: set)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    guard value.translation.width > 56 else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isTracklistHidden = true
                    }
                }
        )
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isTracklistHidden = true
                }
            } label: {
                Image(systemName: "chevron.compact.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.34))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .onAppear {
            wheelDragTranslation = 0
            wheelManualShift = 0
            wheelLastHapticShift = 0
            wheelAutoRecenterTask?.cancel()
            wheelAutoRecenterTask = nil
        }
    }

    @ViewBuilder
    private func collapsedTracklistOverlay(for set: WebDJSet, width: CGFloat) -> some View {
        let tracks = sortedTracks(for: set)
        let activeIndex = resolvedActiveTrackIndex(in: tracks)
        let activeTrack = tracks.indices.contains(activeIndex) ? tracks[activeIndex] : nil
        let title = activeTrack.map(wheelTrackTitle(for:)) ?? "Unknown Track"
        let djName = activeTrack.map { wheelDJInfo(for: $0, in: set).name } ?? primaryDJLabel(for: set)

        ZStack(alignment: .trailing) {
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    AnimatedEqualizerIcon(color: .white)
                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(
                            text: title,
                            fontSize: 10,
                            fontWeight: .semibold,
                            color: Color.white.opacity(0.92)
                        )
                        .frame(width: 138, alignment: .leading)

                        Text(djName)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)
                            .frame(width: 138, alignment: .leading)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.trailing, 14)
                .padding(.bottom, 12)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isTracklistHidden = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 56)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 5)
        }
        .frame(width: width)
    }

    private var wheelStepHeight: CGFloat {
        62
    }

    @ViewBuilder
    private func wheelTrackEntry(
        track: WebDJSetTrack,
        in set: WebDJSet,
        prominence: CGFloat,
        opacity: CGFloat
    ) -> some View {
        let titleSize: CGFloat = 12 + (prominence * 3.5)
        let subtitleSize: CGFloat = max(10, titleSize - 2.8)
        let info = wheelDJInfo(for: track, in: set)
        let isActive = activeTrackID == track.id

        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 5) {
                Text(wheelTrackTitle(for: track))
                    .font(.system(size: titleSize, weight: prominence > 0.75 ? .semibold : .medium))
                    .foregroundStyle(Color.white.opacity(opacity))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.trailing)
                if isActive {
                    AnimatedEqualizerIcon(color: activeTrackAccentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 6) {
                wheelTrackSourceLinks(for: track)

                Group {
                    if let avatarURL = info.avatarURL {
                        ImageLoaderView(urlString: avatarURL.absoluteString)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    } else {
                        Circle().fill(Color.white.opacity(0.18))
                    }
                }
                .frame(width: 14, height: 14)
                .clipShape(Circle())

                Text(info.name)
                    .font(.system(size: subtitleSize, weight: .regular))
                    .foregroundStyle(Color.white.opacity(max(0.16, opacity * 0.85)))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func wheelTrackSourceLinks(for track: WebDJSetTrack) -> some View {
        HStack(spacing: 6) {
            if let spotify = resolvedExternalURL(track.spotifyUrl) {
                Button {
                    openURL(spotify)
                } label: {
                    Image("SpotifyIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
            }

            if let netease = resolvedExternalURL(track.neteaseUrl) {
                Button {
                    openURL(netease)
                } label: {
                    Image("NeteaseIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func wheelTrackTitle(for track: WebDJSetTrack) -> String {
        let title = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return artist.isEmpty ? "Unknown Track" : artist
    }

    private func wheelDJInfo(for track: WebDJSetTrack, in set: WebDJSet) -> (name: String, avatarURL: URL?) {
        let matchedDJ = artistDJ(for: track.artist, in: set)
        let fallbackDJ = set.dj
        let nameFromTrack = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = matchedDJ?.name
            ?? fallbackDJ?.name
            ?? (nameFromTrack.isEmpty ? primaryDJLabel(for: set) : nameFromTrack)
        let avatarRaw = matchedDJ?.avatarUrl ?? fallbackDJ?.avatarUrl
        let avatarResolved = AppConfig.resolvedURLString(avatarRaw ?? "")
        let avatarURL = avatarResolved.flatMap { resolved in
            resolved.isEmpty ? nil : URL(string: resolved)
        }
        return (name, avatarURL)
    }

    private func primaryDJLabel(for set: WebDJSet) -> String {
        if let name = set.dj?.name.nilIfBlank {
            return name
        }
        if let custom = set.customDjNames.first?.nilIfBlank {
            return custom
        }
        if let djID = set.djId?.nilIfBlank {
            return djID
        }
        return LT("未关联 DJ", "No DJ Linked", "DJ未関連")
    }

    private func resolvedActiveTrackIndex(in tracks: [WebDJSetTrack]) -> Int {
        guard !tracks.isEmpty else { return 0 }
        if let activeTrackID,
           let index = tracks.firstIndex(where: { $0.id == activeTrackID }) {
            return index
        }
        return 0
    }

    private func clampedWheelShift(rawShift: Int, activeIndex: Int, trackCount: Int) -> Int {
        guard trackCount > 0 else { return 0 }
        let minShift = -activeIndex
        let maxShift = (trackCount - 1) - activeIndex
        return min(max(rawShift, minShift), maxShift)
    }

    private func handleWheelDragChanged(
        _ value: DragGesture.Value,
        tracks: [WebDJSetTrack],
        activeIndex: Int
    ) {
        guard tracks.count > 1 else { return }
        wheelAutoRecenterTask?.cancel()
        wheelAutoRecenterTask = nil
        wheelDragTranslation = value.translation.height
        let shift = currentWheelShift(activeIndex: activeIndex, trackCount: tracks.count)

        if shift != wheelLastHapticShift {
            wheelLastHapticShift = shift
            if shift != 0 {
                let feedback = UISelectionFeedbackGenerator()
                feedback.selectionChanged()
            }
        }
    }

    private func handleWheelDragEnded(
        _ value: DragGesture.Value,
        tracks: [WebDJSetTrack],
        activeIndex: Int,
        in _: WebDJSet
    ) {
        guard tracks.count > 1 else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                wheelDragTranslation = 0
            }
            wheelLastHapticShift = 0
            return
        }

        let predictedRawShift = wheelManualShift + Int((-value.predictedEndTranslation.height / wheelStepHeight).rounded())
        let shift = clampedWheelShift(rawShift: predictedRawShift, activeIndex: activeIndex, trackCount: tracks.count)
        wheelManualShift = shift

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            wheelDragTranslation = 0
        }
        wheelLastHapticShift = 0
        scheduleWheelAutoRecenter(activeIndex: activeIndex, trackCount: tracks.count)
    }

    private func handleWheelTap(
        tracks: [WebDJSetTrack],
        activeIndex: Int,
        in set: WebDJSet
    ) {
        guard !tracks.isEmpty else { return }
        let shift = currentWheelShift(activeIndex: activeIndex, trackCount: tracks.count)
        let targetIndex = activeIndex + shift
        guard tracks.indices.contains(targetIndex) else { return }
        let targetTrack = tracks[targetIndex]
        guard shift != 0 || targetTrack.id != activeTrackID else { return }

        wheelAutoRecenterTask?.cancel()
        wheelAutoRecenterTask = nil
        seekToTrack(targetTrack, in: set)
        wheelManualShift = 0
        wheelLastHapticShift = 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            wheelDragTranslation = 0
        }
    }

    private func currentWheelShift(activeIndex: Int, trackCount: Int) -> Int {
        let rawShift = wheelManualShift + Int((-wheelDragTranslation / wheelStepHeight).rounded())
        return clampedWheelShift(rawShift: rawShift, activeIndex: activeIndex, trackCount: trackCount)
    }

    private func scheduleWheelAutoRecenter(activeIndex: Int, trackCount: Int) {
        wheelAutoRecenterTask?.cancel()
        wheelAutoRecenterTask = nil

        let shift = currentWheelShift(activeIndex: activeIndex, trackCount: trackCount)
        guard shift != 0 else { return }

        wheelAutoRecenterTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    wheelManualShift = 0
                    wheelDragTranslation = 0
                }
                wheelLastHapticShift = 0
            }
        }
    }

    private func isMine(_ set: WebDJSet) -> Bool {
        set.uploadedById == appState.session?.user.id
    }

    private func makeSetShareCardPayload() -> SetShareCardPayload {
        let currentSet = set
        return SetShareCardPayload(
            setID: setID,
            setTitle: currentSet?.title ?? LT("未命名 Set", "Untitled Set", "無題のSet"),
            djID: currentSet?.dj?.id ?? currentSet?.djId,
            djName: currentSet?.dj?.name,
            eventName: currentSet?.eventName?.nilIfBlank,
            venue: currentSet?.venue?.nilIfBlank,
            coverImageURL: AppConfig.resolvedURLString(currentSet?.thumbnailUrl ?? ""),
            recordedAtISO8601: currentSet?.recordedAt.map {
                ISO8601DateFormatter().string(from: $0)
            },
            badgeText: LT("Set", "Set", "Set")
        )
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directTask = appContainer.shareMessageRepository.fetchConversations(type: .direct)
        async let groupTask = appContainer.shareMessageRepository.fetchConversations(type: .group)
        let direct = try await directTask
        let groups = try await groupTask
        return (direct + groups).sorted { lhs, rhs in
            let leftDate = lhs.updatedAt
            let rightDate = rhs.updatedAt
            if leftDate != rightDate {
                return leftDate > rightDate
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func sendSharePayload(
        _ payload: SetShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = note
        _ = try await appContainer.shareMessageRepository.sendSetCardMessage(
            conversationID: conversation.id,
            payload: payload
        )
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

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = []

        if let currentSet = set {
            actions.append(
                SharePanelQuickAction(
                    title: LT("复制链接", "Copy Link", "リンクをコピー"),
                    systemImage: "link",
                    accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
                ) {
                    Task { await copySetShareLink(currentSet) }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("查看二维码", "View QR", "QRを見る"),
                    systemImage: "qrcode",
                    accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
                ) {
                    Task { await openSetQRCode(currentSet) }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("查看海报", "View Poster", "海報を見る"),
                    systemImage: "photo.on.rectangle",
                    accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
                ) {
                    Task { await openSetPoster(currentSet) }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("保存海报", "Save Poster", "海報を保存"),
                    systemImage: "photo.badge.arrow.down",
                    accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
                ) {
                    Task { await saveSetPoster(currentSet) }
                }
            )
        }

        if !isAudioOnlyMode {
            actions.append(
                SharePanelQuickAction(
                    title: LT("听音频", "Listen Audio", "音声を聴く"),
                    systemImage: "headphones",
                    accentColor: RaverTheme.accent
                ) {
                    nativePlayerSession.pause()
                    isPlaybackPaused = true
                    audioListenSetID = setID
                    dismissShareMorePanel()
                }
            )
        }

        if appState.session != nil {
            actions.append(
                SharePanelQuickAction(
                    title: LT("上传 Tracklist", "Upload Tracklist", "Tracklistをアップロード"),
                    systemImage: "square.and.arrow.up",
                    accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
                ) {
                    showTracklistUpload = true
                    dismissShareMorePanel()
                }
            )
        }

        if let currentSet = set, isMine(currentSet) {
            actions.append(
                SharePanelQuickAction(
                    title: LT("编辑 Set", "Edit Set", "Setを編集"),
                    systemImage: "square.and.pencil",
                    accentColor: Color(red: 0.99, green: 0.65, blue: 0.20)
                ) {
                    dismissShareMorePanel {
                        discoverPush(.setEdit(setID: currentSet.id))
                    }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("编辑 Tracklist", "Edit Tracklist", "Tracklistを編集"),
                    systemImage: "text.badge.plus",
                    accentColor: Color(red: 0.91, green: 0.44, blue: 0.85)
                ) {
                    showTrackEditor = true
                    dismissShareMorePanel()
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("删除 Set", "Delete Set", "Setを削除"),
                    systemImage: "trash",
                    accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
                ) {
                    dismissShareMorePanel {
                        Task { await deleteSet() }
                    }
                }
            )
        }

        return actions
    }

    private func shareTarget(for set: WebDJSet) -> ShareTarget {
        let subtitle = [set.dj?.name.nilIfBlank, set.eventName?.nilIfBlank, set.venue?.nilIfBlank]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let canonicalURL = "https://ravehub.top/set/\(set.id)"
        let deepLink = "raver://set/\(set.id)"
        return ShareTarget(
            type: .set,
            id: set.id,
            title: set.title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            imageURL: AppConfig.resolvedURLString(set.thumbnailUrl ?? ""),
            canonicalURL: canonicalURL,
            deepLink: deepLink,
            fallbackURL: canonicalURL,
            previewType: "content_card",
            visibility: "public"
        )
    }

    @MainActor
    private func copySetShareLink(_ set: WebDJSet) async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: shareTarget(for: set))
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("已复制链接", "Link copied", "リンクをコピーしました"),
                conversation: nil
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openSetQRCode(_ set: WebDJSet) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: set), channel: "view_qr")
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
    private func openSetPoster(_ set: WebDJSet) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: set), channel: "view_poster")
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
                        hintText: LT("Set 海报由分享系统统一生成，标题、摘要和二维码都会跟随短链保持一致。", "Set posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "Set海報は共有システムで生成され、タイトル、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveSetPoster(_ set: WebDJSet) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: set), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"), conversation: nil)
        } catch {
            errorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }

    private func dismissShareMorePanel(after completion: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            shareMorePresentation = nil
            completion?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation?) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func load() async {
        guard !isLoading else { return }

        let hadContent = set != nil
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            relatedEvent = nil
            async let setTask = setReadRepository.fetchDJSet(id: setID)
            async let commentsTask = setCommentRepository.fetchSetComments(setID: setID)
            async let tracklistsTask = tracklistRepository.fetchTracklists(setID: setID)
            let loadedSet = try await setTask
            set = loadedSet
            relatedEvent = try? await resolveRelatedEvent(for: loadedSet)
            comments = try await commentsTask
            tracklists = try await tracklistsTask
            selectedTracklistID = nil
            currentTracklistInfo = nil
            currentTracks = loadedSet.tracks
            playbackTime = 0
            pendingSeekTime = nil
            playbackDuration = Double(max(0, loadedSet.duration ?? 0))
            controlsVisible = true
            isPlaybackPaused = false
            isTracklistHidden = false
            wheelManualShift = 0
            wheelDragTranslation = 0
            wheelLastHapticShift = 0
            wheelAutoRecenterTask?.cancel()
            wheelAutoRecenterTask = nil
            controlsAutoHideTask?.cancel()
            controlsAutoHideTask = nil
            nativePlayerError = nil
            embeddedPlayerError = nil
            phase = .success
            bannerMessage = nil
            syncActiveTrack(for: loadedSet, at: 0)
            nativePlayerSession.reset()
        } catch {
            let message = error.userFacingMessage ?? LT("Set 详情加载失败，请稍后重试", "Failed to load set details. Please try again later.", "Set詳細を読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    private func resolveRelatedEvent(for set: WebDJSet) async throws -> WebEvent? {
        let eventName = (set.eventName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eventName.isEmpty else { return nil }

        let page = try await setEventLookupRepository.fetchEvents(
            page: 1,
            limit: 200,
            search: eventName,
            eventType: nil,
            status: "all"
        )
        let normalized = eventName.lowercased()
        if let exact = page.items.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }) {
            return exact
        }
        return page.items.first
    }

    private var tracklistDisplayName: String {
        if selectedTracklistID == nil {
            return LT("默认 Tracklist", "Default Tracklist", "デフォルトTracklist")
        }
        if let title = currentTracklistInfo?.title, !title.isEmpty {
            return title
        }
        if let contributor = currentTracklistInfo?.contributor {
            return LT("\(contributor.shownName) 的版本", "\(contributor.shownName)'s version", "\(contributor.shownName) のバージョン")
        }
        return LT("用户版本 Tracklist", "User Tracklist Version", "ユーザー版Tracklist")
    }

    private func refreshTracklists() async {
        do {
            tracklists = try await tracklistRepository.fetchTracklists(setID: setID)
            if let selectedTracklistID,
               !tracklists.contains(where: { $0.id == selectedTracklistID }) {
                await switchTracklist(nil)
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func switchTracklist(_ tracklistID: String?) async {
        guard let set else { return }

        if tracklistID == nil {
            selectedTracklistID = nil
            currentTracklistInfo = nil
            currentTracks = set.tracks
            wheelManualShift = 0
            wheelDragTranslation = 0
            wheelLastHapticShift = 0
            wheelAutoRecenterTask?.cancel()
            wheelAutoRecenterTask = nil
            syncActiveTrack(for: set, at: playbackTime)
            return
        }

        guard let targetID = tracklistID else { return }
        do {
            let detail = try await tracklistRepository.fetchTracklistDetail(setID: set.id, tracklistID: targetID)
            currentTracklistInfo = detail
            selectedTracklistID = targetID
            currentTracks = detail.tracks
            wheelManualShift = 0
            wheelDragTranslation = 0
            wheelLastHapticShift = 0
            wheelAutoRecenterTask?.cancel()
            wheelAutoRecenterTask = nil
            syncActiveTrack(for: set, at: playbackTime)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @ViewBuilder
    private func playerSection(for set: WebDJSet) -> some View {
        if isAudioOnlyMode {
            audioPlayerSection(for: set)
        } else if let source = resolvedPlaybackSource(for: set) {
            switch source {
            case .native(let playableURL):
            EmbeddedNativeVideoPlayer(
                session: nativePlayerSession,
                videoURL: playableURL,
                currentTime: $playbackTime,
                duration: $playbackDuration,
                pendingSeekTime: $pendingSeekTime,
                isPaused: isPlaybackPaused,
                onReady: {},
                onPlaybackStateChanged: { paused in
                    if isPlaybackPaused != paused {
                        isPlaybackPaused = paused
                    }
                },
                onError: { message in
                    nativePlayerError = message
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .youtube(let videoID):
                SimpleYouTubeEmbedView(
                    videoID: videoID,
                    onError: { message in
                        embeddedPlayerError = message
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label(LT("无法直接播放该视频地址", "无法直接播放该视频地址", "この動画URLは直接再生できません"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
                Text(LT("当前支持 YouTube 链接和原生直连媒体地址（mp4/mov/webm/m3u8）。", "当前支持 YouTube 链接和原生直连媒体地址（mp4/mov/webm/m3u8）。", "現在はYouTubeリンクと直接再生可能なメディアURL（mp4/mov/webm/m3u8）に対応しています。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.black)
        }
    }

    @ViewBuilder
    private func audioPlayerSection(for set: WebDJSet) -> some View {
        if let source = resolvedPlaybackSource(for: set) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.92),
                        Color(red: 0.08, green: 0.10, blue: 0.16),
                        Color.black.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 10) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(RaverTheme.accent)
                    Text(LT("音频收听模式", "Audio Listen Mode", "音声視聴モード"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white)
                    Text(LT("已切换为节省流量的音频播放", "Switched to data-saving audio playback", "データ節約の音声再生に切り替えました"))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                switch source {
                case .native(let playableURL):
                    EmbeddedNativeAudioPlayer(
                        session: nativePlayerSession,
                        mediaURL: playableURL,
                        currentTime: $playbackTime,
                        duration: $playbackDuration,
                        pendingSeekTime: $pendingSeekTime,
                        isPaused: isPlaybackPaused,
                        onReady: {},
                        onPlaybackStateChanged: { paused in
                            if isPlaybackPaused != paused {
                                isPlaybackPaused = paused
                            }
                        },
                        onError: { message in
                            nativePlayerError = message
                        }
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                case .youtube:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label(LT("无法直接播放该视频地址", "无法直接播放该视频地址", "この動画URLは直接再生できません"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
                Text(LT("当前支持 YouTube 链接和原生直连媒体地址（mp4/mov/webm/m3u8）。", "当前支持 YouTube 链接和原生直连媒体地址（mp4/mov/webm/m3u8）。", "現在はYouTubeリンクと直接再生可能なメディアURL（mp4/mov/webm/m3u8）に対応しています。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.black)
        }
    }

    @ViewBuilder
    private func currentTrackPinnedCard(for set: WebDJSet) -> some View {
        let tracks = sortedTracks(for: set)
        if tracks.isEmpty {
            EmptyView()
        } else {
            let track = tracks.first(where: { $0.id == activeTrackID }) ?? tracks[0]
            let trackIndex = tracks.firstIndex(where: { $0.id == track.id }) ?? 0

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(tracklistDisplayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button(LT("选择版本", "选择版本", "バージョンを選択")) {
                        showTracklistSelector = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    if appState.session != nil {
                        Button(LT("上传", "上传", "アップロード")) {
                            showTracklistUpload = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    Button(isTracklistExpanded ? LT("收起", "Collapse", "閉じる") : LT("展开", "Expand", "展開")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isTracklistExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }

                trackRow(track: track, index: trackIndex, in: set, emphasized: true)
            }
        }
    }

    @ViewBuilder
    private func expandedTracklistSection(for set: WebDJSet) -> some View {
        let tracks = sortedTracks(for: set)
        if tracks.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(track: track, index: index, in: set, emphasized: false)
                                .id(track.id)
                        }
                    }
                }
                .frame(height: 230)
                .onChange(of: activeTrackID) { _, activeID in
                    guard let activeID else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(activeID, anchor: .top)
                    }
                }
                .onAppear {
                    guard let activeID = activeTrackID else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(activeID, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private func trackRow(track: WebDJSetTrack, index: Int, in set: WebDJSet, emphasized: Bool) -> some View {
        let isActive = activeTrackID == track.id
        let artistMatchedDJ = artistDJ(for: track.artist, in: set)
        let endTime = resolvedTrackEndTime(for: track, at: index, in: set)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                playbackStateIcon(for: track, at: index, in: set)
                Text("\(formatTrackTime(track.startTime))")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                if let endTime {
                    Text("~ \(formatTrackTime(Int(endTime)))")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                Spacer()
                Text(track.status.uppercased())
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isActive ? activeTrackTitleColor : RaverTheme.primaryText)
                        .lineLimit(1)

                    if let artistMatchedDJ {
                        Button {
                            appPush(.djDetail(djID: artistMatchedDJ.id))
                        } label: {
                            HStack(spacing: 6) {
                                if let avatar = AppConfig.resolvedDJAvatarURLString(
                                    artistMatchedDJ.avatarSmallUrl ?? artistMatchedDJ.avatarUrl,
                                    size: .small
                                ), !avatar.isEmpty {
                                    ImageLoaderView(urlString: avatar)
                                        .background(Circle().fill(RaverTheme.card))
                                    .frame(width: 18, height: 18)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(RaverTheme.card)
                                        .frame(width: 18, height: 18)
                                }
                                Text(artistMatchedDJ.name)
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(RaverTheme.card)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Image(systemName: "music.mic")
                                        .font(.system(size: 8))
                                        .foregroundStyle(RaverTheme.secondaryText)
                                )
                            Text(track.artist)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)

                if hasSourceLinks(track) {
                    sourceLinksRow(for: track)
                        .frame(width: 52, alignment: .trailing)
                        .padding(.bottom, 1)
                }
            }
        }
        .padding(.vertical, emphasized ? 8 : 10)
        .padding(.horizontal, emphasized ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? activeTrackBackgroundColor : RaverTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? activeTrackAccentColor.opacity(0.65) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            seekToTrack(track, in: set)
        }
    }

    @ViewBuilder
    private func sourceLinksRow(for track: WebDJSetTrack) -> some View {
        HStack(spacing: 8) {
            if let spotify = resolvedExternalURL(track.spotifyUrl) {
                Button {
                    openURL(spotify)
                } label: {
                    Image("SpotifyIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }

            if let netease = resolvedExternalURL(track.neteaseUrl) {
                Button {
                    openURL(netease)
                } label: {
                    Image("NeteaseIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hasSourceLinks(_ track: WebDJSetTrack) -> Bool {
        resolvedExternalURL(track.spotifyUrl) != nil || resolvedExternalURL(track.neteaseUrl) != nil
    }

    private func resolvedExternalURL(_ raw: String?) -> URL? {
        guard let raw = raw, let resolved = AppConfig.resolvedURLString(raw), !resolved.isEmpty else {
            return nil
        }
        return URL(string: resolved)
    }

    @ViewBuilder
    private func playbackStateIcon(for track: WebDJSetTrack, at index: Int, in set: WebDJSet) -> some View {
        if activeTrackID == track.id {
            AnimatedEqualizerIcon(color: activeTrackAccentColor)
        } else {
            Image(systemName: checklistSymbol(for: track, at: index, in: set))
                .foregroundStyle(checklistColor(for: track, at: index, in: set))
        }
    }

    @ViewBuilder
    private func contributorSection(for set: WebDJSet) -> some View {
        let effectiveTracklistContributor = currentTracklistInfo?.contributor ?? set.tracklistContributor
        if set.videoContributor != nil || effectiveTracklistContributor != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text(LT("贡献者", "贡献者", "コントリビューター"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)

                if let authorName = set.videoAuthorName?.trimmingCharacters(in: .whitespacesAndNewlines), !authorName.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LT("YouTube 发布人", "YouTube Publisher", "YouTube投稿者"))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(authorName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }

                if let video = set.videoContributor {
                    contributorRow(title: LT("视频贡献", "Video Contributor", "動画投稿者"), contributor: video)
                }
                if let tracklist = effectiveTracklistContributor {
                    let title = selectedTracklistID == nil
                        ? LT("Tracklist 贡献", "Tracklist Contributor", "Tracklist投稿者")
                        : LT("当前版本 Tracklist 贡献", "Current Version Contributor", "現在バージョンのTracklist投稿者")
                    contributorRow(title: title, contributor: tracklist)
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LT("评论", "评论", "コメント"))
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)

            if comments.isEmpty {
                Text(LT("暂无评论", "暂无评论", "コメントはまだありません"))
                    .foregroundStyle(RaverTheme.secondaryText)
            } else {
                ForEach(comments) { comment in
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            appPush(.userProfile(userID: comment.user.id))
                        } label: {
                            webUserAvatar(comment.user, size: 28)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.user.shownName)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(comment.content)
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(comment.createdAt.feedTimeText)
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            TextField(LT("写评论...", "写评论...", "コメントを書く..."), text: $inputComment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button(LT("发送评论", "发送评论", "コメントを送信")) {
                Task { await sendComment() }
            }
            .buttonStyle(CompactPrimaryButtonStyle())
            .disabled(inputComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func artistDJ(for artistName: String, in set: WebDJSet) -> WebDJ? {
        let target = normalizeName(artistName)
        if target.isEmpty {
            return nil
        }

        if let primary = set.dj {
            let normalizedPrimary = normalizeName(primary.name)
            if normalizedPrimary == target || target.contains(normalizedPrimary) || normalizedPrimary.contains(target) {
                return primary
            }
        }

        for item in set.lineupDjs {
            let normalized = normalizeName(item.name)
            if normalized == target || target.contains(normalized) || normalized.contains(target) {
                return item
            }
        }
        return nil
    }

    private func normalizeName(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "[^a-z0-9\\u4e00-\\u9fa5]+", with: "", options: .regularExpression)
    }

    private func sendComment() async {
        let content = inputComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        do {
            _ = try await setCommentRepository.addSetComment(setID: setID, input: CreateSetCommentInput(content: content, parentId: nil))
            inputComment = ""
            comments = try await setCommentRepository.fetchSetComments(setID: setID)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func deleteSet() async {
        do {
            try await setCommandRepository.deleteDJSet(id: setID)
            errorMessage = LT("Set 已删除，请返回列表刷新", "Set deleted. Please return to the list and refresh.", "Setは削除されました。リストに戻って更新してください。")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func formatTrackTime(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let h = safe / 3600
        let m = (safe % 3600) / 60
        let s = safe % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func sortedTracks(for set: WebDJSet) -> [WebDJSetTrack] {
        let sourceTracks = currentTracks.isEmpty ? set.tracks : currentTracks
        return sourceTracks.sorted { lhs, rhs in
            if lhs.startTime == rhs.startTime {
                return lhs.position < rhs.position
            }
            return lhs.startTime < rhs.startTime
        }
    }

    private func resolvedDuration(for set: WebDJSet) -> Double {
        if playbackDuration > 0 {
            return playbackDuration
        }
        if let duration = set.duration, duration > 0 {
            return Double(duration)
        }
        let tracks = sortedTracks(for: set)
        guard let last = tracks.last else { return 0 }
        return Double(max(last.endTime ?? last.startTime, last.startTime))
    }

    private func progressValue(for set: WebDJSet) -> Double {
        let total = resolvedDuration(for: set)
        guard total > 0 else { return 0 }
        return min(max(playbackTime / total, 0), 1)
    }

    private func resolvedTrackEndTime(for track: WebDJSetTrack, at index: Int, in set: WebDJSet) -> Double? {
        let tracks = sortedTracks(for: set)
        if let explicit = track.endTime, explicit > track.startTime {
            return Double(explicit)
        }
        if index + 1 < tracks.count {
            return Double(tracks[index + 1].startTime)
        }
        let total = resolvedDuration(for: set)
        return total > 0 ? total : nil
    }

    private func syncActiveTrack(for set: WebDJSet, at time: Double) {
        let tracks = sortedTracks(for: set)
        for (index, track) in tracks.enumerated() {
            let start = Double(track.startTime)
            let end = resolvedTrackEndTime(for: track, at: index, in: set) ?? Double.greatestFiniteMagnitude
            if time >= start && time < end {
                if activeTrackID != track.id {
                    activeTrackID = track.id
                }
                return
            }
        }
        if activeTrackID != nil {
            activeTrackID = nil
        }
    }

    private func seekToTrack(_ track: WebDJSetTrack, in set: WebDJSet) {
        let target = Double(track.startTime)
        playbackTime = target
        syncActiveTrack(for: set, at: target)
        if resolvedPlaybackSource(for: set) != nil {
            pendingSeekTime = target
        }
    }

    private func checklistSymbol(for track: WebDJSetTrack, at index: Int, in set: WebDJSet) -> String {
        if activeTrackID == track.id {
            return "waveform.circle.fill"
        }
        let end = resolvedTrackEndTime(for: track, at: index, in: set) ?? Double.greatestFiniteMagnitude
        if playbackTime >= end {
            return "checkmark.circle.fill"
        }
        return "circle"
    }

    private func checklistColor(for track: WebDJSetTrack, at index: Int, in set: WebDJSet) -> Color {
        if activeTrackID == track.id {
            return activeTrackAccentColor
        }
        let end = resolvedTrackEndTime(for: track, at: index, in: set) ?? Double.greatestFiniteMagnitude
        if playbackTime >= end {
            return .green
        }
        return RaverTheme.secondaryText
    }

    private var activeTrackBackgroundColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.92)
            : Color(red: 0.93, green: 0.90, blue: 0.98)
    }

    private var activeTrackAccentColor: Color {
        colorScheme == .dark
            ? RaverTheme.accent
            : Color(red: 0.61, green: 0.47, blue: 0.90)
    }

    private var activeTrackTitleColor: Color {
        colorScheme == .dark
            ? .white
            : Color(red: 0.29, green: 0.19, blue: 0.46)
    }

    private func resolvedPlaybackSource(for set: WebDJSet) -> DJSetPlaybackSource? {
        guard let resolved = AppConfig.resolvedURLString(set.videoUrl), !resolved.isEmpty else { return nil }
        if let videoID = YouTubeVideoIDParser.videoID(from: resolved, fallbackPlatform: set.platform, fallbackVideoID: set.videoId) {
            return .youtube(videoID)
        }
        if set.platform.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "youtube",
           let videoID = YouTubeVideoIDParser.videoID(from: set.videoId) {
            return .youtube(videoID)
        }
        if let direct = URL(string: resolved) {
            return .native(direct)
        }
        let encoded = resolved.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        if let encoded, let url = URL(string: encoded) {
            return .native(url)
        }
        return nil
    }

    @ViewBuilder
    private func contributorRow(title: String, contributor: WebContributorProfile) -> some View {
        Button {
            appPush(.userProfile(userID: contributor.id))
        } label: {
            HStack(spacing: 8) {
                contributorAvatar(contributor, size: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(contributor.shownName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func webUserAvatar(_ user: WebUserLite, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarUrl),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(webUserAvatarFallback(user, size: size))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            webUserAvatarFallback(user, size: size)
        }
    }

    private func webUserAvatarFallback(_ user: WebUserLite, size: CGFloat) -> some View {
        AvatarPlaceholderView(size: size, backgroundColor: RaverTheme.card)
    }

    @ViewBuilder
    private func contributorAvatar(_ user: WebContributorProfile, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarUrl),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(contributorAvatarFallback(user, size: size))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            contributorAvatarFallback(user, size: size)
        }
    }

    private func contributorAvatarFallback(_ user: WebContributorProfile, size: CGFloat) -> some View {
        AvatarPlaceholderView(size: size, backgroundColor: RaverTheme.card)
        .frame(width: size, height: size)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }
}

private struct AnimatedEqualizerIcon: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(height: animate ? 11 : 5, duration: 0.42, delay: 0)
            bar(height: animate ? 7 : 12, duration: 0.36, delay: 0.08)
            bar(height: animate ? 12 : 6, duration: 0.48, delay: 0.16)
        }
        .frame(width: 14, height: 14, alignment: .bottom)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }

    private func bar(height: CGFloat, duration: Double, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 2, height: height)
            .animation(
                .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animate
            )
    }
}

private struct MarqueeText: View {
    let text: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let color: Color

    private let gap: CGFloat = 16
    private let speed: CGFloat = 22
    @State private var textWidth: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let containerWidth = proxy.size.width
            let shouldScroll = textWidth > containerWidth + 2

            TimelineView(.animation(minimumInterval: 1 / 30, paused: !shouldScroll)) { context in
                let travel = max(1, textWidth + gap)
                let elapsed = CGFloat(context.date.timeIntervalSinceReferenceDate)
                let x = shouldScroll
                    ? -((elapsed * speed).truncatingRemainder(dividingBy: travel))
                    : 0

                HStack(spacing: gap) {
                    textLabel
                    if shouldScroll {
                        textLabel
                    }
                }
                .offset(x: x)
            }
        }
        .frame(height: fontSize + 2)
        .clipped()
    }

    private var textLabel: some View {
        Text(text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MarqueeWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            )
            .onPreferenceChange(MarqueeWidthPreferenceKey.self) { value in
                textWidth = value
            }
    }
}

private struct MarqueeWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum DJSetPlaybackSource: Equatable {
    case native(URL)
    case youtube(String)
}

private enum YouTubeVideoIDParser {
    private static let patterns: [String] = [
        #"(?:youtube\.com/watch\?v=|youtu\.be/)([A-Za-z0-9_-]{11})"#,
        #"youtube\.com/embed/([A-Za-z0-9_-]{11})"#,
        #"youtube\.com/shorts/([A-Za-z0-9_-]{11})"#,
        #"youtube-nocookie\.com/embed/([A-Za-z0-9_-]{11})"#
    ]

    static func videoID(from raw: String?, fallbackPlatform: String? = nil, fallbackVideoID: String? = nil) -> String? {
        if let candidate = normalizedVideoID(from: raw) {
            return candidate
        }

        let platform = fallbackPlatform?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if platform == "youtube", let candidate = normalizedVideoID(from: fallbackVideoID) {
            return candidate
        }

        return nil
    }

    private static func normalizedVideoID(from raw: String?) -> String? {
        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }
        if value.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil {
            return value
        }
        for pattern in patterns {
            if let range = value.range(of: pattern, options: .regularExpression) {
                let match = String(value[range])
                if let idRange = match.range(of: #"[A-Za-z0-9_-]{11}$"#, options: .regularExpression) {
                    return String(match[idRange])
                }
            }
        }
        return nil
    }
}

private final class NativeVideoSession: ObservableObject {
    let player: AVPlayer = AVPlayer()
    private(set) var currentURL: URL?
    private(set) var isAudioOnly: Bool = false

    func loadIfNeeded(url: URL, audioOnly: Bool = false) {
        guard currentURL?.absoluteString != url.absoluteString || isAudioOnly != audioOnly else { return }
        currentURL = url
        isAudioOnly = audioOnly
        let item = AVPlayerItem(url: url)
        if audioOnly {
            // Hint AVPlayer to prefer an audio-friendly stream profile when available.
            item.preferredPeakBitRate = 96_000
            if #available(iOS 15.0, *) {
                item.preferredMaximumResolution = CGSize(width: 320, height: 180)
            }
        }
        player.replaceCurrentItem(with: item)
    }

    func pause() {
        player.pause()
    }

    func reset() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentURL = nil
        isAudioOnly = false
    }
}

private struct EmbeddedNativeVideoPlayer: UIViewControllerRepresentable {
    let session: NativeVideoSession
    let videoURL: URL
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var pendingSeekTime: Double?
    let isPaused: Bool
    let onReady: () -> Void
    let onPlaybackStateChanged: (Bool) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        if #available(iOS 16.0, *) {
            controller.allowsVideoFrameAnalysis = false
        }
        controller.player = session.player
        session.loadIfNeeded(url: videoURL, audioOnly: false)
        context.coordinator.attachPlayer(session.player)
        context.coordinator.bindCurrentItemObserver()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        context.coordinator.parent = self
        if uiViewController.player !== session.player {
            uiViewController.player = session.player
        }
        session.loadIfNeeded(url: videoURL, audioOnly: false)
        context.coordinator.attachPlayer(session.player)
        context.coordinator.bindCurrentItemObserver()
        context.coordinator.seekIfNeeded()
        context.coordinator.ensurePlaybackState()
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.cleanup()
        uiViewController.player = nil
    }

    final class Coordinator: NSObject {
        var parent: EmbeddedNativeVideoPlayer
        private weak var player: AVPlayer?
        private var timeObserverToken: Any?
        private var statusObserver: NSKeyValueObservation?
        private weak var observedItem: AVPlayerItem?
        private var lastAppliedPausedState: Bool?

        init(parent: EmbeddedNativeVideoPlayer) {
            self.parent = parent
            self.lastAppliedPausedState = nil
        }

        func attachPlayer(_ player: AVPlayer) {
            guard self.player !== player else { return }
            if let existingPlayer = self.player, let token = timeObserverToken {
                existingPlayer.removeTimeObserver(token)
                timeObserverToken = nil
            }
            self.player = player
            timeObserverToken = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.35, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self else { return }
                self.parent.currentTime = max(0, time.seconds)
                self.parent.onPlaybackStateChanged(player.timeControlStatus != .playing)
                if let item = player.currentItem {
                    let total = item.duration.seconds
                    if total.isFinite && total > 0 {
                        self.parent.duration = total
                    }
                }
            }
        }

        func bindCurrentItemObserver() {
            guard let item = player?.currentItem else {
                observedItem = nil
                statusObserver = nil
                return
            }
            guard observedItem !== item else { return }
            observedItem = item
            statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    switch observedItem.status {
                    case .readyToPlay:
                        self.parent.onReady()
                        let value = observedItem.duration.seconds
                        if value.isFinite && value > 0 {
                            self.parent.duration = value
                        }
                        self.ensurePlaybackState()
                    case .failed:
                        let message = observedItem.error?.localizedDescription ?? LT("视频加载失败，请检查链接或上传文件", "Video loading failed. Please check the link or upload file.", "動画を読み込めません。リンクまたはアップロードファイルを確認してください。")
                        self.parent.onError(message)
                    default:
                        break
                    }
                }
            }
        }

        func seekIfNeeded() {
            guard let seconds = parent.pendingSeekTime else { return }
            let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
            player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            DispatchQueue.main.async {
                self.parent.pendingSeekTime = nil
            }
        }

        func ensurePlaybackState() {
            guard lastAppliedPausedState != parent.isPaused else { return }
            lastAppliedPausedState = parent.isPaused
            guard let player else { return }
            if parent.isPaused {
                player.pause()
            } else {
                player.play()
            }
        }

        func cleanup() {
            statusObserver = nil
            if let player, let token = timeObserverToken {
                player.removeTimeObserver(token)
            }
            timeObserverToken = nil
            observedItem = nil
            self.player = nil
        }
    }
}

private struct EmbeddedNativeAudioPlayer: UIViewRepresentable {
    let session: NativeVideoSession
    let mediaURL: URL
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var pendingSeekTime: Double?
    let isPaused: Bool
    let onReady: () -> Void
    let onPlaybackStateChanged: (Bool) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        session.loadIfNeeded(url: mediaURL, audioOnly: true)
        context.coordinator.attachPlayer(session.player)
        context.coordinator.bindCurrentItemObserver()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        session.loadIfNeeded(url: mediaURL, audioOnly: true)
        context.coordinator.attachPlayer(session.player)
        context.coordinator.bindCurrentItemObserver()
        context.coordinator.seekIfNeeded()
        context.coordinator.ensurePlaybackState()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cleanup()
        uiView.layer.sublayers?.removeAll()
    }

    final class Coordinator: NSObject {
        var parent: EmbeddedNativeAudioPlayer
        private weak var player: AVPlayer?
        private var timeObserverToken: Any?
        private var statusObserver: NSKeyValueObservation?
        private weak var observedItem: AVPlayerItem?
        private var lastAppliedPausedState: Bool?

        init(parent: EmbeddedNativeAudioPlayer) {
            self.parent = parent
            self.lastAppliedPausedState = nil
        }

        func attachPlayer(_ player: AVPlayer) {
            guard self.player !== player else { return }
            if let existingPlayer = self.player, let token = timeObserverToken {
                existingPlayer.removeTimeObserver(token)
                timeObserverToken = nil
            }
            self.player = player
            timeObserverToken = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.35, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self else { return }
                self.parent.currentTime = max(0, time.seconds)
                self.parent.onPlaybackStateChanged(player.timeControlStatus != .playing)
                if let item = player.currentItem {
                    let total = item.duration.seconds
                    if total.isFinite && total > 0 {
                        self.parent.duration = total
                    }
                }
            }
        }

        func bindCurrentItemObserver() {
            guard let item = player?.currentItem else {
                observedItem = nil
                statusObserver = nil
                return
            }
            guard observedItem !== item else { return }
            observedItem = item
            statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    switch observedItem.status {
                    case .readyToPlay:
                        self.parent.onReady()
                        let value = observedItem.duration.seconds
                        if value.isFinite && value > 0 {
                            self.parent.duration = value
                        }
                        self.ensurePlaybackState()
                    case .failed:
                        let message = observedItem.error?.localizedDescription
                            ?? LT("音频加载失败，请检查链接或上传文件", "Audio loading failed. Please check the link or upload file.", "音声を読み込めません。リンクまたはアップロードファイルを確認してください。")
                        self.parent.onError(message)
                    default:
                        break
                    }
                }
            }
        }

        func seekIfNeeded() {
            guard let seconds = parent.pendingSeekTime else { return }
            let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
            player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            DispatchQueue.main.async {
                self.parent.pendingSeekTime = nil
            }
        }

        func ensurePlaybackState() {
            guard lastAppliedPausedState != parent.isPaused else { return }
            lastAppliedPausedState = parent.isPaused
            guard let player else { return }
            if parent.isPaused {
                player.pause()
            } else {
                player.play()
            }
        }

        func cleanup() {
            statusObserver = nil
            if let player, let token = timeObserverToken {
                player.removeTimeObserver(token)
            }
            timeObserverToken = nil
            observedItem = nil
            self.player = nil
        }
    }
}

private struct SimpleYouTubeEmbedView: UIViewRepresentable {
    let videoID: String
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController.add(context.coordinator, name: Coordinator.consoleHandlerName)
        configuration.userContentController.addUserScript(Coordinator.consoleBridgeScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.load(videoID: videoID)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.webView = webView
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.load(videoID: videoID)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cleanup()
        webView.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let consoleHandlerName = "raverSimpleEmbed"
        static let consoleBridgeScript = WKUserScript(
            source: """
            (function() {
              if (window.__raverSimpleEmbedConsoleInstalled) { return; }
              window.__raverSimpleEmbedConsoleInstalled = true;
              function send(level, parts) {
                try {
                  window.webkit.messageHandlers.raverSimpleEmbed.postMessage({
                    level: level,
                    message: Array.prototype.slice.call(parts).map(function(item) {
                      if (typeof item === 'string') { return item; }
                      try { return JSON.stringify(item); } catch (_) { return String(item); }
                    }).join(' ')
                  });
                } catch (_) {}
              }
              ['log', 'warn', 'error'].forEach(function(level) {
                var original = console[level];
                console[level] = function() {
                  send(level, arguments);
                  if (typeof original === 'function') {
                    return original.apply(console, arguments);
                  }
                };
              });
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        var parent: SimpleYouTubeEmbedView
        weak var webView: WKWebView?
        private(set) var loadedVideoID: String?

        init(parent: SimpleYouTubeEmbedView) {
            self.parent = parent
        }

        func load(videoID: String) {
            guard loadedVideoID != videoID || webView?.url == nil else { return }
            loadedVideoID = videoID
            print("[RaverYouTubeSimpleEmbed] loading youtube-nocookie iframe videoID=\(videoID)")
            webView?.loadHTMLString(Self.html(videoID: videoID), baseURL: URL(string: "https://www.youtube-nocookie.com"))
        }

        func cleanup() {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.consoleHandlerName)
            webView?.navigationDelegate = nil
            webView?.uiDelegate = nil
            webView = nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url?.absoluteString ?? "nil"
            let target = navigationAction.targetFrame?.isMainFrame == true ? "main" : "subframe"
            print("[RaverYouTubeSimpleEmbed] action target=\(target) url=\(url)")
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            let url = navigationResponse.response.url?.absoluteString ?? "nil"
            if let http = navigationResponse.response as? HTTPURLResponse {
                print("[RaverYouTubeSimpleEmbed] response status=\(http.statusCode) url=\(url)")
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[RaverYouTubeSimpleEmbed] didFinish url=\(webView.url?.absoluteString ?? "nil") title=\(webView.title ?? "nil")")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[RaverYouTubeSimpleEmbed] didFail error=\(error.localizedDescription)")
            parent.onError(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[RaverYouTubeSimpleEmbed] didFailProvisional error=\(error.localizedDescription)")
            parent.onError(error.localizedDescription)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.consoleHandlerName else { return }
            if let body = message.body as? [String: Any] {
                let level = body["level"] as? String ?? "log"
                let text = body["message"] as? String ?? ""
                print("[RaverYouTubeSimpleEmbed] js \(level): \(text)")
            } else {
                print("[RaverYouTubeSimpleEmbed] js message: \(message.body)")
            }
        }

        private static func html(videoID: String) -> String {
            let cleanID = videoID
                .components(separatedBy: CharacterSet(charactersIn: "?&"))
                .first?
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;") ?? videoID
            let source = "https://www.youtube-nocookie.com/embed/\(cleanID)?playsinline=1&modestbranding=1&rel=0&enablejsapi=1&origin=https://www.youtube-nocookie.com"
            return """
            <html>
            <head>
                <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0">
                <style>
                    html, body {
                        width: 100%;
                        height: 100%;
                        margin: 0;
                        padding: 0;
                        overflow: hidden;
                        background: #000;
                    }
                    iframe {
                        display: block;
                        width: 100%;
                        height: 100%;
                        border: 0;
                        background: #000;
                    }
                </style>
            </head>
            <body>
                <script>
                    console.log('[RaverEmbedPage] local youtube-nocookie page loaded videoId=\(cleanID)');
                </script>
                <iframe
                    width="100%"
                    height="100%"
                    src="\(source)"
                    frameborder="0"
                    allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
                    allowfullscreen>
                </iframe>
            </body>
            </html>
            """
        }
    }
}

private struct EmbeddedYouTubePlayer: UIViewRepresentable {
    let videoID: String
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var pendingSeekTime: Double?
    let isPaused: Bool
    let onReady: () -> Void
    let onPlaybackStateChanged: (Bool) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController.add(context.coordinator, name: "raverPlayer")
        configuration.userContentController.addUserScript(EmbeddedYouTubePlayer.Coordinator.consoleBridgeScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        context.coordinator.webView = webView
        context.coordinator.load(videoID: videoID, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.load(videoID: videoID, in: webView)
        }
        context.coordinator.seekIfNeeded()
        context.coordinator.ensurePlaybackState()
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cleanup()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "raverPlayer")
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let consoleBridgeScript = WKUserScript(
            source: """
            (function() {
              function send(level, args) {
                try {
                  window.webkit.messageHandlers.raverPlayer.postMessage({
                    type: 'console',
                    level: level,
                    message: Array.prototype.slice.call(args).map(function(item) {
                      try {
                        if (typeof item === 'string') return item;
                        return JSON.stringify(item);
                      } catch (_) {
                        return String(item);
                      }
                    }).join(' ')
                  });
                } catch (_) {}
              }
              ['log', 'info', 'warn', 'error'].forEach(function(level) {
                var original = console[level];
                console[level] = function() {
                  send(level, arguments);
                  if (original) original.apply(console, arguments);
                };
              });
              window.addEventListener('error', function(event) {
                send('window-error', [event.message, event.filename, event.lineno, event.colno]);
              });
              window.addEventListener('unhandledrejection', function(event) {
                send('unhandled-rejection', [event.reason && event.reason.message ? event.reason.message : event.reason]);
              });
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        var parent: EmbeddedYouTubePlayer
        weak var webView: WKWebView?
        private(set) var loadedVideoID: String?
        private var isReady = false
        private var lastAppliedPausedState: Bool?
        private var lastSeekTime: Double?

        init(parent: EmbeddedYouTubePlayer) {
            self.parent = parent
        }

        func load(videoID: String, in webView: WKWebView) {
            log("load requested videoID=\(videoID)")
            if loadedVideoID == videoID, webView.isLoading || webView.url != nil {
                log("skip duplicate load videoID=\(videoID) currentURL=\(webView.url?.absoluteString ?? "nil") isLoading=\(webView.isLoading)")
                return
            }
            loadedVideoID = videoID
            isReady = false
            lastAppliedPausedState = nil
            lastSeekTime = nil
            webView.navigationDelegate = self
            webView.uiDelegate = self
            guard let url = Self.embedPageURL(videoID: videoID) else {
                log("failed to build embed URL for videoID=\(videoID)")
                parent.onError(LT("YouTube 视频链接无效。", "Invalid YouTube video link.", "YouTube動画リンクが無効です。"))
                return
            }
            var request = URLRequest(url: url)
            log("loading BFF embed page url=\(url.absoluteString)")
            webView.load(request)
        }

        func seekIfNeeded() {
            guard isReady, let seconds = parent.pendingSeekTime else { return }
            let target = max(0, seconds)
            guard lastSeekTime != target else { return }
            lastSeekTime = target
            evaluate("window.__raverYouTubeBridge && window.__raverYouTubeBridge.seekTo(\(target));")
            DispatchQueue.main.async {
                self.parent.pendingSeekTime = nil
            }
        }

        func ensurePlaybackState() {
            guard isReady, lastAppliedPausedState != parent.isPaused else { return }
            lastAppliedPausedState = parent.isPaused
            evaluate(parent.isPaused
                ? "window.__raverYouTubeBridge && window.__raverYouTubeBridge.pause();"
                : "window.__raverYouTubeBridge && window.__raverYouTubeBridge.play();")
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "raverPlayer",
                  let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String else { return }

            DispatchQueue.main.async {
                switch type {
                case "ready":
                    self.isReady = true
                    if let duration = payload["duration"] as? Double, duration.isFinite, duration > 0 {
                        self.parent.duration = duration
                    }
                    self.parent.onReady()
                    self.seekIfNeeded()
                    self.ensurePlaybackState()
                case "time":
                    if let time = payload["currentTime"] as? Double, time.isFinite {
                        self.parent.currentTime = max(0, time)
                    }
                    if let duration = payload["duration"] as? Double, duration.isFinite, duration > 0 {
                        self.parent.duration = duration
                    }
                case "state":
                    if let state = payload["state"] as? Int {
                        self.log("iframe api state=\(state)")
                        self.parent.onPlaybackStateChanged(state != 1)
                    }
                case "error":
                    let code = payload["code"].map { "\($0)" } ?? "unknown"
                    self.log("iframe api error code=\(code)")
                    self.parent.onError(LT("YouTube 播放器加载失败，请确认视频允许嵌入播放。", "YouTube player failed to load. Please confirm the video allows embedded playback.", "YouTubeプレーヤーを読み込めません。動画が埋め込み再生を許可しているか確認してください。"))
                case "console":
                    let level = payload["level"] as? String ?? "log"
                    let message = payload["message"] as? String ?? ""
                    self.log("js \(level): \(message)")
                default:
                    break
                }
            }
        }

        func cleanup() {
            evaluate("window.__raverYouTubeBridge && window.__raverYouTubeBridge.destroy && window.__raverYouTubeBridge.destroy();")
            isReady = false
            loadedVideoID = nil
            webView?.navigationDelegate = nil
            webView?.uiDelegate = nil
            webView = nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            log("didStartProvisionalNavigation url=\(webView.url?.absoluteString ?? "nil")")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url?.absoluteString ?? "nil"
            let target = navigationAction.targetFrame?.isMainFrame == true ? "main" : "subframe"
            log("decidePolicy action=\(navigationAction.navigationType.rawValue) target=\(target) url=\(url)")
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            let url = navigationResponse.response.url?.absoluteString ?? "nil"
            if let http = navigationResponse.response as? HTTPURLResponse {
                log("navigationResponse status=\(http.statusCode) url=\(url)")
            } else {
                log("navigationResponse url=\(url)")
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            log("didFinish url=\(webView.url?.absoluteString ?? "nil") title=\(webView.title ?? "nil")")
            installVideoBridge()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            log("didFail url=\(webView.url?.absoluteString ?? "nil") error=\(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            log("didFailProvisionalNavigation url=\(webView.url?.absoluteString ?? "nil") error=\(error.localizedDescription)")
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            log("webContentProcessDidTerminate url=\(webView.url?.absoluteString ?? "nil")")
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            log("createWebViewWith url=\(navigationAction.request.url?.absoluteString ?? "nil")")
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        private func installVideoBridge() {
            let script = """
            (function() {
              if (window.__raverYouTubeBridgeInstalled) { return "already-installed"; }
              function post(payload) {
                try { window.webkit.messageHandlers.raverPlayer.postMessage(payload); } catch (_) {}
              }
              function emitState(video) {
                post({ type: 'state', state: video.paused ? 2 : 1 });
              }
              function emitTime(video) {
                post({
                  type: 'time',
                  currentTime: Number(video.currentTime || 0),
                  duration: Number(video.duration || 0)
                });
              }
              function attach(video) {
                if (!video) { return false; }
                if (video.__raverBridgeAttached) { return true; }
                video.__raverBridgeAttached = true;
                window.__raverYouTubeBridgeInstalled = true;
                window.__raverYouTubeBridge = {
                  play: function() {
                    var p = video.play && video.play();
                    if (p && p.catch) { p.catch(function(err) { console.warn("video.play failed", err && err.message ? err.message : err); }); }
                  },
                  pause: function() { if (video.pause) video.pause(); },
                  seekTo: function(seconds) { video.currentTime = Math.max(0, Number(seconds || 0)); emitTime(video); },
                  destroy: function() {}
                };
                ["play", "playing", "pause", "seeking", "seeked", "timeupdate", "durationchange", "loadedmetadata"].forEach(function(name) {
                  video.addEventListener(name, function() {
                    emitState(video);
                    emitTime(video);
                  });
                });
                video.addEventListener("error", function() {
                  var mediaError = video.error;
                  post({ type: "error", code: mediaError && mediaError.code ? mediaError.code : "video-element-error" });
                });
                post({ type: 'ready', duration: Number(video.duration || 0) });
                emitState(video);
                emitTime(video);
                return true;
              }
              var attempts = 0;
              var timer = window.setInterval(function() {
                attempts += 1;
                var video = document.querySelector("video");
                if (attach(video)) {
                  window.clearInterval(timer);
                  console.log("Raver bridge attached to video element");
                  return;
                }
                if (attempts >= 80) {
                  window.clearInterval(timer);
                  console.warn("Raver bridge could not find video element");
                }
              }, 250);
              return "installing";
            })();
            """
            webView?.evaluateJavaScript(script) { _, error in
                if let error {
                    self.log("installVideoBridge js error=\(error.localizedDescription)")
                } else {
                    self.log("installVideoBridge dispatched")
                }
            }
        }

        private func log(_ message: String) {
            print("[RaverYouTubeEmbed] \(message)")
        }

        private static func embedPageURL(videoID: String) -> URL? {
            AppConfig.resolvedURLString("/v1/dj-sets/youtube-embed/\(videoID)").flatMap(URL.init(string:))
        }

        private static func html(videoID: String) -> String {
            let escapedVideoID = videoID
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let embedURL = "https://www.youtube.com/embed/\(escapedVideoID)?enablejsapi=1&playsinline=1&rel=0"
            return """
            <!doctype html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
              <meta name="referrer" content="strict-origin-when-cross-origin">
              <style>
                html, body, #player {
                  width: 100%;
                  height: 100%;
                  margin: 0;
                  padding: 0;
                  overflow: hidden;
                  background: #000;
                  border: 0;
                }
              </style>
            </head>
            <body>
              <iframe
                id="player"
                type="text/html"
                width="100%"
                height="100%"
                src="\(embedURL)"
                title="YouTube video player"
                frameborder="0"
                referrerpolicy="strict-origin-when-cross-origin"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowfullscreen
              ></iframe>
              <script src="https://www.youtube.com/iframe_api"></script>
              <script>
                var player;
                var poller;
                function post(payload) {
                  window.webkit.messageHandlers.raverPlayer.postMessage(payload);
                }
                function onYouTubeIframeAPIReady() {
                  player = new YT.Player('player', {
                    events: {
                      onReady: function() {
                        post({ type: 'ready', duration: player.getDuration() || 0 });
                        startPolling();
                      },
                      onStateChange: function(event) {
                        post({ type: 'state', state: event.data });
                      },
                      onError: function(event) {
                        post({ type: 'error', code: event.data });
                      }
                    }
                  });
                }
                function startPolling() {
                  if (poller) window.clearInterval(poller);
                  poller = window.setInterval(function() {
                    if (!player || !player.getCurrentTime) return;
                    post({
                      type: 'time',
                      currentTime: player.getCurrentTime() || 0,
                      duration: player.getDuration() || 0
                    });
                  }, 350);
                }
                function seekTo(seconds) {
                  if (player && player.seekTo) player.seekTo(Math.max(0, seconds), true);
                }
                function play() {
                  if (player && player.playVideo) player.playVideo();
                }
                function pause() {
                  if (player && player.pauseVideo) player.pauseVideo();
                }
                function destroy() {
                  if (poller) window.clearInterval(poller);
                  if (player && player.destroy) player.destroy();
                  player = null;
                }
              </script>
            </body>
            </html>
            """
        }
    }
}

private struct TracklistSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let set: WebDJSet
    let tracklists: [WebTracklistSummary]
    let selectedTracklistID: String?
    let onSelect: (String?) -> Void

    @State private var query = ""
    @State private var copiedID: String?

    private var filteredTracklists: [WebTracklistSummary] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return tracklists }
        return tracklists.filter { item in
            let title = (item.title ?? "").lowercased()
            let contributorName = item.contributor?.shownName.lowercased() ?? ""
            return title.contains(keyword)
                || contributorName.contains(keyword)
                || item.id.lowercased().contains(keyword)
        }
    }

    private func resolvedTracklistTitle(_ item: WebTracklistSummary) -> String {
        let trimmed = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return LT(
            "\(item.contributor?.shownName ?? "匿名") 的版本",
            "\(item.contributor?.shownName ?? "Anonymous")'s version",
            "\(item.contributor?.shownName ?? "匿名") のバージョン"
        )
    }

    private func copyTracklistID(_ id: String) {
        UIPasteboard.general.string = id
        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == id {
                copiedID = nil
            }
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    ContributorAvatar(
                        avatarURL: (set.tracklistContributor ?? set.videoContributor)?.avatarUrl,
                        fallback: (set.tracklistContributor ?? set.videoContributor)?.shownName ?? LT("官方", "Official", "公式")
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LT("默认 Tracklist", "默认 Tracklist", "デフォルトTracklist"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(set.tracklistContributor?.shownName ?? set.videoContributor?.shownName ?? LT("官方版本", "Official Version", "公式バージョン"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(LT("ID：默认", "ID: default", "ID: デフォルト"))
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        copyTracklistID("default")
                    } label: {
                        Image(systemName: copiedID == "default" ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    if selectedTracklistID == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(RaverTheme.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(nil)
                    dismiss()
                }
            }

            Section(LT("用户上传版本", "用户上传版本", "ユーザー投稿版")) {
                if filteredTracklists.isEmpty {
                    Text(query.isEmpty ? LT("暂无用户上传版本", "No user-uploaded versions yet", "ユーザー投稿版はまだありません") : LT("未找到匹配版本", "No matching versions found", "一致するバージョンが見つかりません"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(filteredTracklists) { item in
                        HStack(spacing: 10) {
                            ContributorAvatar(
                                avatarURL: item.contributor?.avatarUrl,
                                fallback: item.contributor?.shownName ?? "?"
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resolvedTracklistTitle(item))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(1)
                                Text(
                                    LT("\(item.trackCount) 首曲目 · \(item.createdAt.feedTimeText)", "\(item.trackCount) tracks · \(item.createdAt.feedTimeText)", "\(item.trackCount)曲 · \(item.createdAt.feedTimeText)")
                                )
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(LT("ID：\(item.id)", "ID: \(item.id)", "ID: \(item.id)"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                copyTracklistID(item.id)
                            } label: {
                                Image(systemName: copiedID == item.id ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)

                            if selectedTracklistID == item.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(RaverTheme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(item.id)
                            dismiss()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: LT("搜索 Tracklist / 用户 / ID", "Search Tracklist / User / ID", "Tracklist / ユーザー / IDを検索"))
        .raverSystemNavigation(title: LT("选择 Tracklist", "选择 Tracklist", "Tracklistを選択"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LT("关闭", "Close", "閉じる")) {
                    dismiss()
                }
            }
        }
    }
}

private struct UploadTracklistSheet: View {
    private enum ParseMode {
        case replace
        case append
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    private var repository: TracklistRepository {
        appContainer.tracklistRepository
    }

    let set: WebDJSet
    let onUploaded: (WebTracklistDetail) -> Void

    @State private var title = ""
    @State private var bulkText = ""
    @State private var rows: [TrackDraftRow] = []
    @State private var infoText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(LT("当前 Set 信息", "当前 Set 信息", "現在のSet情報")) {
                LabeledContent(LT("Set 标题", "Set Title", "Setタイトル"), value: set.title)
                LabeledContent(LT("Set ID", "Set ID", "Set ID"), value: set.id)
                LabeledContent(LT("当前默认歌曲数", "Default Track Count", "現在のデフォルト曲数"), value: "\(set.trackCount)")
            }

            Section(LT("Tracklist 标题", "Tracklist 标题", "Tracklistタイトル")) {
                TextField(LT("例如：我的版本", "例如：我的版本", "例: 自分のバージョン"), text: $title)
            }

            Section(LT("批量粘贴", "批量粘贴", "一括貼り付け")) {
                Text(LT("每行格式：`0:00~3:30 - 艺术家 - 歌曲名 | Spotify链接(可选) | 网易云链接(可选)`", "每行格式：`0:00~3:30 - 艺术家 - 歌曲名 | Spotify链接(可选) | 网易云链接(可选)`", "1行形式: `0:00~3:30 - アーティスト - 曲名 | Spotifyリンク(任意) | NetEaseリンク(任意)`"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                TextEditor(text: $bulkText)
                    .frame(minHeight: 200)
                    .font(.system(.footnote, design: .monospaced))
                HStack {
                    Button(LT("解析并替换", "解析并替换", "解析して置き換え")) {
                        parseBulkTracklist(.replace)
                    }
                    .buttonStyle(.bordered)

                    Button(LT("解析并追加", "解析并追加", "解析して追加")) {
                        parseBulkTracklist(.append)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(LT("从可视化生成文本", "从可视化生成文本", "ビジュアルからテキストを生成")) {
                        bulkText = TracklistDraftCodec.makeBulkText(from: rows)
                        infoText = LT("已用当前可视化内容刷新文本", "Refreshed text from current visual editor", "現在のビジュアル内容でテキストを更新しました")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }

            Section(LT("可视化编辑（\(rows.count)）", "Visual Editor (\(rows.count))", "ビジュアル編集（\(rows.count)）")) {
                if rows.isEmpty {
                    Text(LT("先粘贴文本并解析，或手动新增 Track。", "先粘贴文本并解析，或手动新增 Track。", "先にテキストを貼り付けて解析するか、手動でTrackを追加してください。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach($rows) { $row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(row.position)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Spacer()
                                Text(row.status.uppercased())
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }

                            TextField(LT("歌曲名", "歌曲名", "曲名"), text: $row.title)
                            TextField(LT("歌手", "歌手", "アーティスト"), text: $row.artist)
                            HStack {
                                TextField(LT("开始时间（如 0:00）", "开始时间（如 0:00）", "開始時間（例 0:00）"), text: $row.startText)
                                TextField(LT("结束时间（可选）", "结束时间（可选）", "終了時間（任意）"), text: $row.endText)
                            }
                            TextField(LT("Spotify 链接（可选）", "Spotify 链接（可选）", "Spotifyリンク（任意）"), text: $row.spotifyUrl)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField(LT("网易云链接（可选）", "网易云链接（可选）", "NetEaseリンク（任意）"), text: $row.neteaseUrl)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.vertical, 4)
                    }

                    .onDelete { indexSet in
                        rows.remove(atOffsets: indexSet)
                        rows = TracklistDraftCodec.reindex(rows)
                    }
                }

                Button {
                    rows.append(
                        TrackDraftRow(
                            position: rows.count + 1,
                            title: "",
                            artist: "",
                            startText: "0:00",
                            endText: "",
                            status: "released",
                            spotifyUrl: "",
                            neteaseUrl: ""
                        )
                    )
                } label: {
                    Label(LT("新增 Track", "新增 Track", "Trackを追加"), systemImage: "plus")
                }
            }

            if !infoText.isEmpty {
                Section {
                    Text(infoText)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
        .raverSystemNavigation(title: LT("上传我的 Tracklist", "上传我的 Tracklist", "自分のTracklistをアップロード"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? LT("上传中...", "Uploading...", "アップロード中...") : LT("上传", "Upload", "アップロード")) {
                    Task { await upload() }
                }
                .disabled(isSaving || rows.isEmpty)
            }
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func parseBulkTracklist(_ mode: ParseMode) {
        let parsedRows = TracklistDraftCodec.parseBulkRows(from: bulkText)
        guard !parsedRows.isEmpty else {
            infoText = LT("请先粘贴歌单文本", "Please paste tracklist text first", "先にTracklistテキストを貼り付けてください")
            return
        }

        switch mode {
        case .replace:
            rows = TracklistDraftCodec.reindex(parsedRows)
            infoText = LT("解析成功并替换：\(rows.count) 首", "Parsed and replaced: \(rows.count) tracks", "解析して置き換えました: \(rows.count)曲")
        case .append:
            let merged = rows + parsedRows
            rows = TracklistDraftCodec.reindex(merged)
            infoText = LT("解析成功并追加：共 \(rows.count) 首", "Parsed and appended: total \(rows.count) tracks", "解析して追加しました: 合計\(rows.count)曲")
        }
    }

    private func upload() async {
        let tracks = TracklistDraftCodec.buildCreateTracks(from: rows)
        guard !tracks.isEmpty else {
            errorMessage = LT("至少保留 1 首有效歌曲（需有歌曲名、歌手、开始时间）", "Keep at least one valid track (title, artist, start time required).", "有効な曲を少なくとも1件残してください（曲名、アーティスト、開始時間が必要）。")
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let uploaded = try await repository.createTracklist(
                setID: set.id,
                input: CreateTracklistInput(title: title.nilIfEmpty, tracks: tracks)
            )
            onUploaded(uploaded)
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct ContributorAvatar: View {
    let avatarURL: String?
    let fallback: String

    var body: some View {
        Group {
            if let avatarURL = AppConfig.resolvedURLString(avatarURL), !avatarURL.isEmpty {
                ImageLoaderView(urlString: avatarURL)
                    .background(fallbackAvatar)
            } else {
                fallbackAvatar
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(fallback.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            )
    }
}

struct DJSetEditorView: View {
    enum Mode {
        case create
        case edit(WebDJSet)

        var title: String {
            switch self {
            case .create: return LT("上传 Set", "Upload Set", "Setをアップロード")
            case .edit: return LT("编辑 Set", "Edit Set", "Setを編集")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    private var setCommandRepository: SetCommandRepository {
        appContainer.setCommandRepository
    }

    private var setMediaRepository: SetMediaRepository {
        appContainer.setMediaRepository
    }

    let mode: Mode
    let onSaved: () -> Void

    @State private var djId = ""
    @State private var selectedDJ: WebDJ?
    @State private var djSearchText = ""
    @State private var djSearchResults: [WebDJ] = []
    @State private var isSearchingDJs = false
    @State private var showDJBindingSheet = false
    @State private var title = ""
    @State private var videoUrl = ""
    @State private var description = ""
    @State private var venue = ""
    @State private var eventId = ""
    @State private var eventName = ""
    @State private var thumbnailUrl = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSaving = false
    @State private var isPreviewingVideo = false
    @State private var previewText = ""
    @State private var previewAuthorName = ""
    @State private var lastPreviewedVideoUrl = ""
    @State private var errorMessage: String?
    @State private var showEventBindingSheet = false
    @State private var rightsConfirmed = false

    var body: some View {
        Form {
                Section(LT("基础", "基础", "基本")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let selectedDJ {
                            HStack(spacing: 10) {
                                if let avatar = AppConfig.resolvedURLString(selectedDJ.avatarSmallUrl ?? selectedDJ.avatarUrl), !avatar.isEmpty {
                                    ImageLoaderView(urlString: avatar)
                                        .background(Circle().fill(RaverTheme.card))
                                        .frame(width: 28, height: 28)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(RaverTheme.card)
                                        .frame(width: 28, height: 28)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedDJ.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Text(LT("已关联 DJ", "Linked DJ", "関連付け済みDJ"))
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    self.selectedDJ = nil
                                    self.djId = ""
                                } label: {
                                    Text(LT("清除", "Clear", "クリア"))
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            Text(LT("未关联 DJ（可留空）", "No DJ linked (optional)", "DJ未関連（任意）"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Button {
                            showDJBindingSheet = true
                        } label: {
                            Label(LT("搜索并选择 DJ", "Search and Select DJ", "DJを検索して選択"), systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                    }
                    TextField(LT("标题", "标题", "タイトル"), text: $title)
                    TextField(LT("简介", "简介", "概要"), text: $description, axis: .vertical)
                    TextField(LT("场地", "场地", "会場"), text: $venue)

                    VStack(alignment: .leading, spacing: 8) {
                        if eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(LT("未绑定活动", "未绑定活动", "イベント未紐付け"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            Text(LT("已绑定活动：\(eventName)", "Bound Event: \(eventName)", "イベントに紐付け済み: \(eventName)"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(2)
                        }

                        HStack(spacing: 10) {
                            Button {
                                showEventBindingSheet = true
                            } label: {
                                Label(LT("绑定活动", "绑定活动", "イベントを紐付け"), systemImage: "magnifyingglass")
                            }
                            .buttonStyle(.bordered)

                            if !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(role: .destructive) {
                                    eventId = ""
                                    eventName = ""
                                } label: {
                                    Text(LT("清除", "清除", "クリア"))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section(LT("YouTube 视频", "YouTube 视频", "YouTube動画")) {
                    TextField(LT("粘贴 YouTube 视频链接", "Paste YouTube video link", "YouTube動画リンクを貼り付け"), text: $videoUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit {
                            Task { await preview() }
                        }
                        .onChange(of: videoUrl) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed != lastPreviewedVideoUrl {
                                previewText = ""
                                previewAuthorName = ""
                            }
                        }

                    if isPreviewingVideo {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(LT("正在解析 YouTube 信息...", "Parsing YouTube metadata...", "YouTube情報を解析中..."))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }

                    Button(LT("解析 YouTube 信息", "Parse YouTube Info", "YouTube情報を解析")) {
                        Task { await preview() }
                    }
                    .disabled(isPreviewingVideo || videoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !previewText.isEmpty || !previewAuthorName.isEmpty {
                        youtubePreviewCard
                    }

                    Toggle(isOn: $rightsConfirmed) {
                        Text(LT("我确认该 YouTube 视频来源合法且允许公开引用/嵌入。", "I confirm this YouTube video source is lawful and allows public reference/embedding.", "このYouTube動画の出典が合法で、公開参照/埋め込みが許可されていることを確認します。"))
                            .font(.caption)
                    }
                }

                Section(LT("封面", "封面", "カバー")) {
                    TextField(LT("封面 URL", "封面 URL", "カバーURL"), text: $thumbnailUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(LT("上传封面", "上传封面", "カバーをアップロード"), systemImage: "photo")
                    }
                }
            }
            .raverSystemNavigation(title: mode.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? LT("保存中...", "Saving...", "保存中...") : LT("保存", "Save", "保存")) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                prefillIfNeeded()
            }
            .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(LT("确定", "OK", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showEventBindingSheet) {
                SetEventBindingSheet(
                    initialEventID: eventId,
                    initialEventName: eventName
                ) { selectedEventID, selectedEventName in
                    eventId = selectedEventID ?? ""
                    eventName = selectedEventName
                }
                .environmentObject(appContainer)
            }
            .sheet(isPresented: $showDJBindingSheet) {
                DJSetDJBindingSheet(
                    selectedDJ: selectedDJ,
                    searchText: djSearchText,
                    searchResults: djSearchResults,
                    isSearching: isSearchingDJs,
                    onSearch: { keyword in
                        await searchDJs(keyword: keyword)
                    },
                    onSelect: { dj in
                        selectedDJ = dj
                        djId = dj.id
                    }
                )
            }
    }

    @ViewBuilder
    private var youtubePreviewCard: some View {
        let cover = thumbnailUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(RaverTheme.card)
                if !cover.isEmpty {
                    ImageLoaderView(urlString: cover)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(RaverTheme.accent)
                }
            }
            .frame(width: 116, height: 65)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                if !previewText.isEmpty {
                    Text(previewText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)
                }
                if !previewAuthorName.isEmpty {
                    Text(LT("发布人：\(previewAuthorName)", "Publisher: \(previewAuthorName)", "投稿者: \(previewAuthorName)"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
                if !cover.isEmpty {
                    Text(LT("封面已自动填充", "Cover auto-filled", "カバーを自動入力しました"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func prefillIfNeeded() {
        guard case .edit(let set) = mode else { return }
        if !title.isEmpty { return }

        djId = set.djId ?? ""
        selectedDJ = set.dj
        title = set.title
        videoUrl = set.videoUrl
        description = set.description ?? ""
        venue = set.venue ?? ""
        eventId = set.eventId ?? ""
        eventName = set.eventName ?? ""
        thumbnailUrl = set.thumbnailUrl ?? ""
        previewAuthorName = set.videoAuthorName ?? ""
        rightsConfirmed = true
    }

    private func preview() async {
        let url = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            errorMessage = LT("请先粘贴 YouTube 视频链接", "Please paste a YouTube video link first.", "先にYouTube動画リンクを貼り付けてください。")
            return
        }
        isPreviewingVideo = true
        defer { isPreviewingVideo = false }
        do {
            let data = try await setMediaRepository.previewVideo(videoURL: url)
            let parsedTitle = data["title"] ?? ""
            let platform = data["platform"] ?? ""
            let authorName = data["authorName"] ?? ""
            let parsedDescription = data["description"] ?? ""
            let parsedThumbnail = data["thumbnailUrl"] ?? ""

            guard platform.lowercased() == "youtube" else {
                errorMessage = LT("当前发布仅支持 YouTube 视频链接", "Only YouTube video links are supported for publishing now.", "現在の投稿はYouTube動画リンクのみ対応しています。")
                return
            }

            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !parsedTitle.isEmpty {
                title = parsedTitle
            }
            if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !parsedDescription.isEmpty {
                description = parsedDescription
            }
            if thumbnailUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !parsedThumbnail.isEmpty {
                thumbnailUrl = parsedThumbnail
            }

            previewText = [platform.uppercased(), parsedTitle].filter { !$0.isEmpty }.joined(separator: " · ")
            previewAuthorName = authorName
            lastPreviewedVideoUrl = url
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalVideo = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = LT("请填写标题", "Please fill in the title.", "タイトルを入力してください。")
            return
        }
        if finalVideo.isEmpty {
            errorMessage = LT("请填写 YouTube 视频链接", "Please provide a YouTube video link.", "YouTube動画リンクを入力してください。")
            return
        }
        guard rightsConfirmed else {
            errorMessage = LT("请先确认你拥有发布权利，或链接来源合法且可公开引用。", "Please confirm you have posting rights, or that the link source is lawful and publicly referenceable.", "投稿権利がある、またはリンク元が合法で公開参照可能であることを確認してください。")
            return
        }

        if YouTubeVideoIDParser.videoID(from: finalVideo) == nil {
            errorMessage = LT("当前仅支持合法的 YouTube 视频链接", "Only valid YouTube video links are supported right now.", "現在は有効なYouTube動画リンクのみ対応しています。")
            return
        }

        isSaving = true
        defer { isSaving = false }

        var finalThumb = thumbnailUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let selectedPhoto,
               let data = try await selectedPhoto.loadTransferable(type: Data.self) {
                let upload = try await setMediaRepository.uploadSetThumbnail(
                    imageData: data,
                    fileName: "set-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalThumb = upload.url
            }

            switch mode {
            case .create:
                let result = try await setCommandRepository.createDJSet(
                    input: CreateDJSetInput(
                        djId: selectedDJ?.id.nilIfBlank,
                        title: trimmedTitle,
                        videoUrl: finalVideo,
                        videoAuthorName: previewAuthorName.nilIfEmpty,
                        thumbnailUrl: finalThumb.nilIfEmpty,
                        description: description.nilIfEmpty,
                        venue: venue.nilIfEmpty,
                        eventId: eventId.nilIfEmpty,
                        eventName: eventName.nilIfEmpty,
                        recordedAt: nil,
                        rightsConfirmed: rightsConfirmed
                    )
                )
                if case .submittedForReview = result {
                    OperationBannerCenter.shared.success(LT("Set 信息已提交审核", "Set submitted for review", "Set情報を審査に送信しました"))
                }
            case .edit(let set):
                _ = try await setCommandRepository.updateDJSet(
                    id: set.id,
                    input: UpdateDJSetInput(
                        djId: selectedDJ?.id.nilIfBlank,
                        title: trimmedTitle,
                        videoUrl: finalVideo,
                        videoAuthorName: previewAuthorName.nilIfEmpty,
                        thumbnailUrl: finalThumb.nilIfEmpty,
                        description: description.nilIfEmpty,
                        venue: venue.nilIfEmpty,
                        eventId: eventId.nilIfEmpty,
                        eventName: eventName.nilIfEmpty,
                        recordedAt: set.recordedAt,
                        rightsConfirmed: rightsConfirmed
                    )
                )
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func searchDJs(keyword: String) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            djSearchResults = []
            djSearchText = ""
            return
        }
        djSearchText = trimmed
        isSearchingDJs = true
        defer { isSearchingDJs = false }
        do {
            let page = try await appContainer.webService.fetchDJs(page: 1, limit: 20, search: trimmed, sortBy: "name")
            djSearchResults = page.items
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct DJSetDJBindingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedDJ: WebDJ?
    let searchText: String
    let searchResults: [WebDJ]
    let isSearching: Bool
    let onSearch: (String) async -> Void
    let onSelect: (WebDJ) -> Void

    @State private var query: String

    init(
        selectedDJ: WebDJ?,
        searchText: String,
        searchResults: [WebDJ],
        isSearching: Bool,
        onSearch: @escaping (String) async -> Void,
        onSelect: @escaping (WebDJ) -> Void
    ) {
        self.selectedDJ = selectedDJ
        self.searchText = searchText
        self.searchResults = searchResults
        self.isSearching = isSearching
        self.onSearch = onSearch
        self.onSelect = onSelect
        _query = State(initialValue: searchText)
    }

    var body: some View {
        List {
            Section(LT("搜索 DJ", "Search DJ", "DJを検索")) {
                HStack(spacing: 8) {
                    TextField(LT("输入 DJ 名称", "Enter DJ name", "DJ名を入力"), text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await onSearch(query) } }
                    Button(LT("搜索", "Search", "検索")) {
                        Task { await onSearch(query) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }

                if isSearching {
                    ProgressView(LT("搜索 DJ 中...", "Searching DJs...", "DJを検索中..."))
                        .font(.caption)
                }
            }

            if let selectedDJ {
                Section(LT("当前关联", "Current Link", "現在の関連")) {
                    djRow(selectedDJ, isSelected: true)
                }
            }

            Section(LT("搜索结果", "Search Results", "検索結果")) {
                if searchResults.isEmpty {
                    Text(LT("搜索并选择一个 DJ，也可以留空发布。", "Search and select a DJ, or publish without one.", "DJを検索して選択できます。未選択でも投稿できます。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(searchResults) { dj in
                        Button {
                            onSelect(dj)
                            dismiss()
                        } label: {
                            djRow(dj, isSelected: selectedDJ?.id == dj.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .raverSystemNavigation(title: LT("选择 DJ", "Select DJ", "DJを選択"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LT("关闭", "Close", "閉じる")) {
                    dismiss()
                }
            }
        }
    }

    private func djRow(_ dj: WebDJ, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            if let avatar = AppConfig.resolvedURLString(dj.avatarSmallUrl ?? dj.avatarUrl), !avatar.isEmpty {
                ImageLoaderView(urlString: avatar)
                    .background(Circle().fill(RaverTheme.card))
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(RaverTheme.card)
                    .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(dj.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Text([dj.country?.nilIfBlank, (dj.genres ?? []).prefix(2).joined(separator: " / ").nilIfBlank].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(RaverTheme.accent)
            }
        }
    }
}

private struct SetEventBindingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    private var repository: SetEventLookupRepository {
        appContainer.setEventLookupRepository
    }

    let initialEventID: String
    let initialEventName: String
    let onSelected: (String?, String) -> Void

    @State private var searchText = ""
    @State private var manualEventName = ""
    @State private var events: [WebEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                if !initialEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section(LT("当前绑定", "当前绑定", "現在の紐付け")) {
                        Text(initialEventName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(2)
                    }
                }

                Section(LT("从活动库搜索并绑定", "从活动库搜索并绑定", "イベントライブラリから検索して紐付け")) {
                    TextField(LT("搜索活动名称", "Search event name", "イベント名を検索"), text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(LT("搜索中...", "Searching...", "検索中..."))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    } else if events.isEmpty {
                        Text(LT("没有找到匹配活动", "没有找到匹配活动", "一致するイベントが見つかりません"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        ForEach(events) { event in
                            Button {
                                onSelected(event.id, event.name)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(2)
                                    Text("\(event.startDate.appLocalizedYMDText()) · \(event.summaryLocation.isEmpty ? LT("地点待补充", "Location pending", "場所は未設定") : event.summaryLocation)")
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section(LT("库里没有时可手动输入", "库里没有时可手动输入", "ライブラリにない場合は手動入力できます")) {
                    TextField(LT("手动填写活动名称", "手动填写活动名称", "イベント名を手動入力"), text: $manualEventName)
                    Button(LT("使用手动名称", "使用手动名称", "手動名を使用")) {
                        let trimmed = manualEventName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSelected(nil, trimmed)
                        dismiss()
                    }
                    .disabled(manualEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .raverSystemNavigation(title: LT("绑定活动", "绑定活动", "イベントを紐付け"))
            .toolbar {
            }
            .task {
                manualEventName = initialEventName
                searchText = initialEventName
                await loadEvents(query: initialEventName)
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled else { return }
                    await loadEvents(query: newValue)
                }
            }
            .onDisappear {
                searchTask?.cancel()
                searchTask = nil
            }
            .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(LT("确定", "OK", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
    }

    @MainActor
    private func loadEvents(query: String) async {
        isLoading = true
        defer { isLoading = false }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let page = try await repository.fetchEvents(
                page: 1,
                limit: 100,
                search: trimmed.isEmpty ? nil : trimmed,
                eventType: nil,
                status: "all"
            )
            events = page.items
            errorMessage = nil
        } catch {
            events = []
            errorMessage = error.userFacingMessage
        }
    }
}

private struct TracklistEditorView: View {
    private enum ParseMode {
        case replace
        case append
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    private var repository: TracklistRepository {
        appContainer.tracklistRepository
    }

    let set: WebDJSet
    let currentTracklist: WebTracklistDetail?
    let selectedTracklistID: String?
    let onSaved: () -> Void

    @State private var rows: [TrackDraftRow] = []
    @State private var bulkText = ""
    @State private var bulkParseMessage = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(LT("当前 Tracklist 信息", "当前 Tracklist 信息", "現在のTracklist情報")) {
                LabeledContent(LT("名称", "Name", "名称"), value: resolvedTracklistTitle)
                LabeledContent(LT("Tracklist ID", "Tracklist ID", "Tracklist ID"), value: selectedTracklistID ?? "default")
                LabeledContent(LT("歌曲数量", "Track Count", "曲数"), value: "\(rows.count)")
                LabeledContent(LT("贡献者", "Contributor", "コントリビューター"), value: resolvedTracklistContributor)
            }

            Section(LT("当前歌单文本（已填充）", "当前歌单文本（已填充）", "現在のTracklistテキスト（入力済み）")) {
                Text(LT("每行格式：`0:00~3:30 - 艺术家 - 歌曲名 | Spotify链接(可选) | 网易云链接(可选)`", "每行格式：`0:00~3:30 - 艺术家 - 歌曲名 | Spotify链接(可选) | 网易云链接(可选)`", "1行形式: `0:00~3:30 - アーティスト - 曲名 | Spotifyリンク(任意) | NetEaseリンク(任意)`"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                TextEditor(text: $bulkText)
                    .frame(minHeight: 200)
                    .font(.system(.footnote, design: .monospaced))

                HStack {
                    Button(LT("解析并替换", "解析并替换", "解析して置き換え")) {
                        parseBulkTracklist(.replace)
                    }
                    .buttonStyle(.bordered)

                    Button(LT("解析并追加", "解析并追加", "解析して追加")) {
                        parseBulkTracklist(.append)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(LT("从可视化生成文本", "从可视化生成文本", "ビジュアルからテキストを生成")) {
                        bulkText = TracklistDraftCodec.makeBulkText(from: rows)
                        bulkParseMessage = LT("已用当前可视化内容刷新文本", "Refreshed text from current visual editor", "現在のビジュアル内容でテキストを更新しました")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }

            if !bulkParseMessage.isEmpty {
                Section {
                    Text(bulkParseMessage)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            Section(LT("可视化编辑（\(rows.count)）", "Visual Editor (\(rows.count))", "ビジュアル編集（\(rows.count)）")) {
                ForEach($rows) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("#\(row.position)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            Spacer()
                            Text(row.status.uppercased())
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        TextField(LT("歌曲名", "歌曲名", "曲名"), text: $row.title)
                        TextField(LT("歌手", "歌手", "アーティスト"), text: $row.artist)
                        HStack {
                            TextField(LT("开始时间（如 0:00）", "开始时间（如 0:00）", "開始時間（例 0:00）"), text: $row.startText)
                            TextField(LT("结束时间（可选）", "结束时间（可选）", "終了時間（任意）"), text: $row.endText)
                        }
                        TextField(LT("Spotify 链接（可选）", "Spotify 链接（可选）", "Spotifyリンク（任意）"), text: $row.spotifyUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField(LT("网易云链接（可选）", "网易云链接（可选）", "NetEaseリンク（任意）"), text: $row.neteaseUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    rows.remove(atOffsets: indexSet)
                    rows = TracklistDraftCodec.reindex(rows)
                }

                Button {
                    rows.append(
                        TrackDraftRow(
                            position: rows.count + 1,
                            title: "",
                            artist: "",
                            startText: "0:00",
                            endText: "",
                            status: "released",
                            spotifyUrl: "",
                            neteaseUrl: ""
                        )
                    )
                } label: {
                    Label(LT("新增 Track", "新增 Track", "Trackを追加"), systemImage: "plus")
                }
            }
        }
        .raverSystemNavigation(title: LT("编辑 Tracklist", "编辑 Tracklist", "Tracklistを編集"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? LT("保存中...", "Saving...", "保存中...") : LT("保存", "Save", "保存")) {
                    Task { await save() }
                }
                .disabled(isSaving || rows.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(LT("自动链接", "自动链接", "自動リンク")) {
                    Task { await autoLink() }
                }
            }
        }
        .onAppear {
            initializeRowsIfNeeded()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var resolvedTracklistTitle: String {
        if let title = currentTracklist?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if selectedTracklistID == nil {
            return LT("默认 Tracklist", "Default Tracklist", "デフォルトTracklist")
        }
        return LT("用户版本 Tracklist", "User Tracklist Version", "ユーザー版Tracklist")
    }

    private var resolvedTracklistContributor: String {
        if let contributor = currentTracklist?.contributor?.shownName, !contributor.isEmpty {
            return contributor
        }
        if let contributor = set.tracklistContributor?.shownName, !contributor.isEmpty {
            return contributor
        }
        return LT("官方", "Official", "公式")
    }

    private func initializeRowsIfNeeded() {
        guard rows.isEmpty else { return }
        let sourceTracks = currentTracklist?.tracks ?? set.tracks
        rows = sourceTracks.enumerated().map { index, track in
            TrackDraftRow(
                position: track.position > 0 ? track.position : index + 1,
                title: track.title,
                artist: track.artist,
                startText: TracklistDraftCodec.formatTime(max(0, track.startTime)),
                endText: track.endTime.map { TracklistDraftCodec.formatTime(max(0, $0)) } ?? "",
                status: track.status,
                spotifyUrl: track.spotifyUrl ?? "",
                neteaseUrl: track.neteaseUrl ?? ""
            )
        }
        if rows.isEmpty {
            rows = [
                TrackDraftRow(
                    position: 1,
                    title: "",
                    artist: "",
                    startText: "0:00",
                    endText: "",
                    status: "released",
                    spotifyUrl: "",
                    neteaseUrl: ""
                )
            ]
        }
        rows = TracklistDraftCodec.reindex(rows)
        bulkText = TracklistDraftCodec.makeBulkText(from: rows)
    }

    private func parseBulkTracklist(_ mode: ParseMode) {
        let parsedRows = TracklistDraftCodec.parseBulkRows(from: bulkText)
        guard !parsedRows.isEmpty else {
            bulkParseMessage = LT("未识别可用行，请检查格式后重试", "No valid lines recognized. Please check format and try again.", "有効な行を認識できません。形式を確認してもう一度お試しください。")
            return
        }
        switch mode {
        case .replace:
            rows = TracklistDraftCodec.reindex(parsedRows)
            bulkParseMessage = LT("解析成功并替换：\(rows.count) 首", "Parsed and replaced: \(rows.count) tracks", "解析して置き換えました: \(rows.count)曲")
        case .append:
            rows = TracklistDraftCodec.reindex(rows + parsedRows)
            bulkParseMessage = LT("解析成功并追加：共 \(rows.count) 首", "Parsed and appended: total \(rows.count) tracks", "解析して追加しました: 合計\(rows.count)曲")
        }
    }

    private func save() async {
        let tracks = TracklistDraftCodec.buildCreateTracks(from: rows)

        guard !tracks.isEmpty else {
            errorMessage = LT("至少保留 1 条有效 Track（需有歌曲名、歌手、开始时间）", "Keep at least one valid track (title, artist, start time required).", "有効なTrackを少なくとも1件残してください（曲名、アーティスト、開始時間が必要）。")
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await repository.replaceTracks(setID: set.id, tracks: tracks)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func autoLink() async {
        do {
            try await repository.autoLinkTracks(setID: set.id)
            errorMessage = LT("已触发自动链接", "Auto-link triggered.", "自動リンクを開始しました。")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct TrackDraftRow: Identifiable {
    let id = UUID()
    var position: Int
    var title: String
    var artist: String
    var startText: String
    var endText: String
    var status: String
    var spotifyUrl: String
    var neteaseUrl: String
}

private enum TracklistDraftCodec {
    private struct ParsedTrackLine {
        var startSeconds: Int
        var endSeconds: Int?
        var title: String
        var artist: String
        var status: String
        var spotifyUrl: String?
        var neteaseUrl: String?
    }

    static func parseBulkRows(from bulkText: String) -> [TrackDraftRow] {
        let lines = bulkText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let parsed = lines
            .compactMap(parseLine)
            .sorted(by: { $0.startSeconds < $1.startSeconds })

        guard !parsed.isEmpty else { return [] }

        let rows = parsed.enumerated().map { index, item in
            let fallbackEnd = index + 1 < parsed.count ? parsed[index + 1].startSeconds : nil
            let effectiveEnd = item.endSeconds ?? fallbackEnd
            return TrackDraftRow(
                position: index + 1,
                title: item.title,
                artist: item.artist,
                startText: formatTime(item.startSeconds),
                endText: effectiveEnd.map(formatTime) ?? "",
                status: normalizedStatus(item.status),
                spotifyUrl: item.spotifyUrl ?? "",
                neteaseUrl: item.neteaseUrl ?? ""
            )
        }
        return reindex(rows)
    }

    static func buildCreateTracks(from rows: [TrackDraftRow]) -> [CreateTrackInput] {
        struct ValidTrack {
            var title: String
            var artist: String
            var startTime: Int
            var endTime: Int?
            var status: String
            var spotifyUrl: String?
            var neteaseUrl: String?
        }

        let validRows: [ValidTrack] = rows.compactMap { row in
            let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = row.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !artist.isEmpty else { return nil }
            guard let start = parseTime(row.startText) else { return nil }
            return ValidTrack(
                title: title,
                artist: artist,
                startTime: max(0, start),
                endTime: parseTime(row.endText),
                status: normalizedStatus(row.status),
                spotifyUrl: normalizeURL(row.spotifyUrl),
                neteaseUrl: normalizeURL(row.neteaseUrl)
            )
        }

        guard !validRows.isEmpty else { return [] }

        return validRows.enumerated().map { index, row in
            let nextStart = index + 1 < validRows.count ? validRows[index + 1].startTime : nil
            let fallbackEnd = nextStart.flatMap { $0 > row.startTime ? $0 : nil }
            let finalEnd = row.endTime ?? fallbackEnd
            return CreateTrackInput(
                position: index + 1,
                startTime: row.startTime,
                endTime: finalEnd,
                title: row.title,
                artist: row.artist,
                status: row.status,
                spotifyUrl: row.spotifyUrl,
                neteaseUrl: row.neteaseUrl
            )
        }
    }

    static func reindex(_ rows: [TrackDraftRow]) -> [TrackDraftRow] {
        rows.enumerated().map { index, row in
            var next = row
            next.position = index + 1
            return next
        }
    }

    static func makeBulkText(from rows: [TrackDraftRow]) -> String {
        reindex(rows).map { row in
            let start = row.startText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0:00" : row.startText.trimmingCharacters(in: .whitespacesAndNewlines)
            let end = row.endText.trimmingCharacters(in: .whitespacesAndNewlines)
            let endPart = end.isEmpty ? "" : "~\(end)"
            let artist = row.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : row.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            var parts: [String] = ["\(start)\(endPart) - \(artist) - \(title)"]
            if let spotify = normalizeURL(row.spotifyUrl) {
                parts.append(spotify)
            }
            if let netease = normalizeURL(row.neteaseUrl) {
                parts.append(netease)
            }
            return parts.joined(separator: " | ")
        }
        .joined(separator: "\n")
    }

    static func parseTime(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed
            .split(separator: ":")
            .compactMap { Int($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return nil
    }

    static func formatTime(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let h = safe / 3600
        let m = (safe % 3600) / 60
        let s = safe % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private static func parseLine(_ line: String) -> ParsedTrackLine? {
        let pattern = #"^(\d{1,2}:\d{2}(?::\d{2})?)(?:\s*~\s*(\d{1,2}:\d{2}(?::\d{2})?))?\s*[-–]\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let startRange = Range(match.range(at: 1), in: line),
              let bodyRange = Range(match.range(at: 3), in: line) else {
            return nil
        }

        guard let startSeconds = parseTime(String(line[startRange])) else { return nil }
        let endRaw = Range(match.range(at: 2), in: line).map { String(line[$0]) }
        let endSeconds = endRaw.flatMap(parseTime)

        let body = String(line[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = body
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let mainRaw = segments.first else { return nil }

        let urlsInMain = extractURLs(from: mainRaw)
        var main = mainRaw
        for url in urlsInMain {
            main = main.replacingOccurrences(of: url, with: "")
        }
        main = main.trimmingCharacters(in: .whitespacesAndNewlines)

        let splitToken = " - "
        let splitIndex = main.range(of: splitToken)
        let rawArtist = splitIndex.map { String(main[..<$0.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? "Unknown"
        let rawTitle = splitIndex.map { String(main[$0.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? main
        guard !rawTitle.isEmpty else { return nil }

        let links = detectLinks(in: Array(segments.dropFirst()), fallbackSource: body)
        return ParsedTrackLine(
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            title: rawTitle,
            artist: rawArtist.isEmpty ? "Unknown" : rawArtist,
            status: inferStatus(main),
            spotifyUrl: links.spotify,
            neteaseUrl: links.netease
        )
    }

    private static func detectLinks(in segments: [String], fallbackSource: String) -> (spotify: String?, netease: String?) {
        var spotify: String?
        var netease: String?

        func apply(_ candidate: String) {
            let classified = classifyURL(candidate)
            if spotify == nil, let value = classified.spotify {
                spotify = value
            }
            if netease == nil, let value = classified.netease {
                netease = value
            }
        }

        for segment in segments {
            apply(segment)
        }

        for url in extractURLs(from: fallbackSource) {
            apply(url)
        }

        return (spotify, netease)
    }

    private static func classifyURL(_ raw: String) -> (spotify: String?, netease: String?) {
        let lower = raw.lowercased()
        var candidate = raw
        if lower.hasPrefix("spotify:") || lower.hasPrefix("netease:") || lower.hasPrefix("music163:") {
            if let idx = raw.firstIndex(of: ":") {
                candidate = String(raw[raw.index(after: idx)...])
            }
        } else if lower.hasPrefix("spotify=") || lower.hasPrefix("netease=") || lower.hasPrefix("music163=") {
            if let idx = raw.firstIndex(of: "=") {
                candidate = String(raw[raw.index(after: idx)...])
            }
        }

        guard let normalized = normalizeURL(candidate) else { return (nil, nil) }
        let normalizedLower = normalized.lowercased()
        if normalizedLower.contains("spotify.com") || normalizedLower.contains("spotify.link") {
            return (normalized, nil)
        }
        if normalizedLower.contains("music.163.com") || normalizedLower.contains("163cn.tv") || normalizedLower.contains("netease") {
            return (nil, normalized)
        }
        return (nil, nil)
    }

    private static func extractURLs(from text: String) -> [String] {
        let pattern = #"https?://[^\s|]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsrange).compactMap {
            guard let range = Range($0.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func normalizeURL(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"'(),;"))
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return trimmed
        }
        if trimmed.contains("open.spotify.com") || trimmed.contains("spotify.link")
            || trimmed.contains("music.163.com") || trimmed.contains("163cn.tv") {
            return "https://\(trimmed)"
        }
        return trimmed
    }

    private static func normalizedStatus(_ raw: String) -> String {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["released", "id", "remix", "edit"].contains(lowered) {
            return lowered
        }
        return "released"
    }

    private static func inferStatus(_ text: String) -> String {
        let normalized = text.lowercased()
        if normalized.contains("unreleased") || normalized.contains(" id ") || normalized.hasSuffix(" id") {
            return "id"
        }
        if normalized.contains(" remix") || normalized.contains("(remix") || normalized.contains(" flip") {
            return "remix"
        }
        if normalized.contains(" edit") || normalized.contains("(edit") {
            return "edit"
        }
        return "released"
    }
}
