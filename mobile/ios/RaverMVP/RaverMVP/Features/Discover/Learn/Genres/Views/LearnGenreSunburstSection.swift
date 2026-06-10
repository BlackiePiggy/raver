import SwiftUI
import UIKit

struct LearnGenreSunburstSection: View {
    let genres: [LearnGenreTreeSummaryNode]
    let wikiRepository: DiscoverWikiRepository
    let bottomInset: CGFloat

    @Environment(\.appPush) private var appPush
    @Environment(\.discoverPush) private var discoverPush
    @State private var focusedId: String?
    @State private var selectedNode: GenreSunburstNode?
    @State private var rootNode: GenreSunburstNode?
    @State private var searchIndex: [GenreSunburstSearchItem] = []
    @State private var genreDetails: [String: LearnGenreDetail] = [:]
    @State private var detailLoadTask: Task<Void, Never>?
    @State private var preparationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = geometry.size.width >= 768 ? CGFloat(18) : CGFloat(10)
            let chartWidth = max(260, geometry.size.width - horizontalPadding * 2)
            let maxChartHeight = max(320, geometry.size.height - bottomInset - 112)
            let chartSize = min(chartWidth, maxChartHeight, geometry.size.width >= 768 ? 680 : 520)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    if let rootNode {
                        GenreSunburstSearchPanel(items: searchIndex) { item in
                            focusedId = item.id
                            selectedNode = item.node
                        }

                        GenreSunburstCanvasContainer(
                            rootNode: rootNode,
                            focusedId: $focusedId,
                            selectedNode: $selectedNode
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: chartSize)

                        GenreSunburstSelectionCard(
                            node: currentDisplayNode,
                            pathText: pathText(for: currentDisplayNode),
                            detail: currentGenreDetail,
                            onArtistTap: openArtistDetail,
                            onDetailTap: openGenreDetail
                        )
                    } else {
                        genreSunburstLoadingPlaceholder(chartSize: chartSize)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, bottomInset)
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { hideKeyboard() }
            )
            .scrollDismissesKeyboard(.interactively)
        }
        .task(id: genresPreparationKey) {
            await prepareGenreContent()
        }
        .onChange(of: focusedId) { _, _ in
            loadDetailIfNeeded()
        }
        .onChange(of: selectedNode?.id) { _, _ in
            loadDetailIfNeeded()
        }
        .onDisappear {
            preparationTask?.cancel()
            detailLoadTask?.cancel()
        }
    }

    private var currentDisplayNode: GenreSunburstNode {
        selectedNode
            ?? focusedId.flatMap { focusId in
                rootNode?.firstNode(withId: focusId)
            }
            ?? rootNode
            ?? LearnGenreSunburstBuilder.loadingRootNode
    }

    private var currentGenreDetail: LearnGenreDetail? {
        guard let rootNode, currentDisplayNode.id != rootNode.id else { return nil }
        return genreDetails[currentDisplayNode.id]
    }

    private func pathText(for node: GenreSunburstNode) -> String {
        guard let rootNode else { return "" }
        return node.pathDisplayText(root: rootNode)
    }

    private func loadDetailIfNeeded() {
        detailLoadTask?.cancel()
        guard let rootNode else { return }
        let node = currentDisplayNode
        guard node.id != rootNode.id else { return }
        guard genreDetails[node.id] == nil else { return }

        let repository = wikiRepository
        detailLoadTask = Task {
            do {
                let detail = try await repository.fetchLearnGenreDetail(id: node.id)
                await MainActor.run {
                    genreDetails[node.id] = detail
                }
            } catch {
                return
            }
        }
    }

    private func openArtistDetail(_ artist: LearnGenreKeyArtistBinding) {
        guard let djID = (artist.dj?.id.nilIfBlank ?? artist.djId?.nilIfBlank) else { return }
        appPush(.djDetail(djID: djID))
    }

    private func openGenreDetail() {
        guard let rootNode else { return }
        let node = currentDisplayNode
        guard node.id != rootNode.id else { return }
        discoverPush(.genreDetail(genreID: node.id, prefetchedGenre: genreDetails[node.id]))
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var genresPreparationKey: String {
        genres.map(\.id).joined(separator: "|")
    }

    private func prepareGenreContent() async {
        preparationTask?.cancel()
        detailLoadTask?.cancel()
        focusedId = nil
        selectedNode = nil
        genreDetails = [:]
        searchIndex = []
        rootNode = nil

        let snapshot = genres
        preparationTask = Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                let root = LearnGenreSunburstBuilder.makeRootNode(from: snapshot)
                let searchIndex = LearnGenreSunburstBuilder.makeSearchIndex(root: root)
                return (root, searchIndex)
            }.value

            guard !Task.isCancelled else { return }
            await MainActor.run {
                rootNode = prepared.0
                searchIndex = prepared.1
            }
        }

        await preparationTask?.value
        preparationTask = nil
    }

    @ViewBuilder
    private func genreSunburstLoadingPlaceholder(chartSize: CGFloat) -> some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(maxWidth: 560)
                .frame(height: 40)
                .redacted(reason: .placeholder)

            ZStack {
                GenreSunburstStaticRecordBackground()
                    .drawingGroup()
                    .opacity(0.55)

                ProgressView()
                    .controlSize(.regular)
            }
            .frame(maxWidth: .infinity)
            .frame(height: chartSize)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(height: 176)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 144, height: 26)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 14)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 220, height: 14)
                    }
                    .padding(18)
                }
                .redacted(reason: .placeholder)
        }
    }
}

private struct GenreSunburstCanvasContainer: View {
    @Environment(\.colorScheme) private var colorScheme
    let rootNode: GenreSunburstNode
    @Binding var focusedId: String?
    @Binding var selectedNode: GenreSunburstNode?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GenreSunburstCanvasView(
                root: rootNode,
                focusedId: $focusedId,
                selectedNode: $selectedNode
            )

            Button {
                focusedId = nil
                selectedNode = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(resetForeground)
                    .frame(width: 52, height: 52)
                    .background(resetBackground, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(resetStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.trailing, 6)
            .opacity((focusedId == nil && selectedNode == nil) ? 0.65 : 1)
        }
    }

    private var resetForeground: Color {
        colorScheme == .dark ? .white.opacity(0.92) : Color.black.opacity(0.78)
    }

    private var resetBackground: Color {
        colorScheme == .dark ? .black.opacity(0.34) : .white.opacity(0.78)
    }

    private var resetStroke: Color {
        colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.08)
    }
}

private struct GenreSunburstSelectionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let node: GenreSunburstNode
    let pathText: String
    let detail: LearnGenreDetail?
    let onArtistTap: (LearnGenreKeyArtistBinding) -> Void
    let onDetailTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(node.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Spacer(minLength: 8)

                if !isRootNode {
                    Button(action: onDetailTap) {
                        HStack(spacing: 4) {
                            Text(LT("查看详情", "Details", "詳細"))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .black))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(detailButtonText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(detailButtonBackground, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(detailButtonStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !pathText.isEmpty {
                Text(pathText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if !displayDescription.isEmpty {
                Text(displayDescription)
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            } else if detail == nil && !isRootNode {
                ProgressView()
                    .controlSize(.small)
            }

            if !infoItems.isEmpty {
                VStack(spacing: 10) {
                    ForEach(infoItems) { item in
                        GenreSunburstInfoTile(item: item, onArtistTap: onArtistTap)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.86)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.76) : Color.black.opacity(0.68)
    }

    private var accentText: Color {
        colorScheme == .dark
            ? Color(red: 0.46, green: 0.88, blue: 1.0).opacity(0.92)
            : Color.black.opacity(0.82)
    }

    private var detailButtonText: Color {
        colorScheme == .dark ? Color(red: 0.72, green: 0.94, blue: 1.0) : Color(red: 0.05, green: 0.37, blue: 0.48)
    }

    private var detailButtonBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color(red: 0.86, green: 0.97, blue: 1.0).opacity(0.88)
    }

    private var detailButtonStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    private var infoItems: [GenreSunburstInfoItem] {
        var items: [GenreSunburstInfoItem] = []

        let artistBindings = normalizedArtistBindings()
        if !artistBindings.isEmpty {
            items.append(GenreSunburstInfoItem(
                id: "artists",
                icon: "person.2.fill",
                title: LT("代表艺人", "Key artists", "代表アーティスト"),
                value: "",
                artists: artistBindings
            ))
        }

        if !displayExample.isEmpty {
            items.append(GenreSunburstInfoItem(
                id: "example",
                icon: "music.note",
                title: LT("声音线索", "Sound cue", "サウンド"),
                value: displayExample,
                artists: []
            ))
        }

        return items
    }

    private var isRootNode: Bool {
        node.id == LearnGenreSunburstBuilder.rootID
    }

    private var displayDescription: String {
        localizedGenreText(
            detail?.descriptionI18n ?? node.descriptionI18n,
            fallback: detail?.description ?? node.description
        )
    }

    private var displayExample: String {
        localizedGenreText(
            detail?.exampleI18n ?? node.exampleI18n,
            fallback: detail?.example ?? node.example
        )
    }

    private func normalizedArtistBindings() -> [LearnGenreKeyArtistBinding] {
        let bindings = detail?.keyArtistBindings ?? node.keyArtistBindings
        if !bindings.isEmpty {
            return bindings
        }

        return (detail?.keyArtists ?? node.keyArtists).map { LearnGenreKeyArtistBinding(name: $0, djId: nil, dj: nil) }
    }

    private func localizedGenreText(_ value: WebBiText?, fallback: String?) -> String {
        let localized = value?.text(for: AppLanguagePreference.current.effectiveLanguage)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !localized.isEmpty {
            return localized
        }
        return fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private struct GenreSunburstInfoItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let artists: [LearnGenreKeyArtistBinding]
}

private struct GenreSunburstInfoTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: GenreSunburstInfoItem
    let onArtistTap: (LearnGenreKeyArtistBinding) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(item.title)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(labelText)

            if !item.artists.isEmpty {
                GenreSunburstArtistCapsuleCloud(artists: item.artists, onArtistTap: onArtistTap)
            } else {
                Text(item.value)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(valueText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.04))
        )
    }

    private var labelText: Color {
        colorScheme == .dark
            ? Color(red: 0.62, green: 0.90, blue: 1.0).opacity(0.95)
            : Color.black.opacity(0.74)
    }

    private var valueText: Color {
        colorScheme == .dark ? .white.opacity(0.78) : Color.black.opacity(0.86)
    }
}

private struct GenreSunburstArtistCapsuleCloud: View {
    let artists: [LearnGenreKeyArtistBinding]
    let onArtistTap: (LearnGenreKeyArtistBinding) -> Void

    var body: some View {
        GenreSunburstFlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(artists) { artist in
                GenreSunburstArtistCapsule(artist: artist, onTap: onArtistTap)
            }
        }
    }
}

private struct GenreSunburstFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        guard maxWidth > 0 else {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            return CGSize(
                width: sizes.map(\.width).max() ?? 0,
                height: sizes.reduce(CGFloat(0)) { $0 + $1.height } + lineSpacing * CGFloat(max(0, sizes.count - 1))
            )
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct GenreSunburstArtistCapsule: View {
    @Environment(\.colorScheme) private var colorScheme
    let artist: LearnGenreKeyArtistBinding
    let onTap: (LearnGenreKeyArtistBinding) -> Void

    var body: some View {
        Group {
            if canOpenDetail {
                Button {
                    onTap(artist)
                } label: {
                    capsuleContent
                }
                .buttonStyle(.plain)
                .accessibilityHint(LT("打开 DJ 详情", "Open DJ detail", "DJ詳細を開く"))
            } else {
                capsuleContent
            }
        }
    }

    private var capsuleContent: some View {
        HStack(spacing: 7) {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        Circle().fill(avatarFallbackBackground)
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(avatarFallbackText)
                    }
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(Circle())

            Text(displayName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .frame(height: 32)
        .background(capsuleBackground, in: Capsule())
        .overlay(Capsule().stroke(capsuleStroke, lineWidth: 1))
    }

    private var canOpenDetail: Bool {
        (artist.dj?.id.nilIfBlank ?? artist.djId?.nilIfBlank) != nil
    }

    private var displayName: String {
        artist.dj?.name.nilIfBlank ?? artist.name
    }

    private var avatarURL: URL? {
        let resolved = AppConfig.resolvedDJAvatarURLString(
            artist.dj?.avatarMediumUrl ?? artist.dj?.avatarUrl,
            size: .medium
        )
        guard let resolved else { return nil }
        return URL(string: resolved)
    }

    private var textColor: Color {
        colorScheme == .dark ? .white.opacity(0.88) : Color.black.opacity(0.84)
    }

    private var capsuleBackground: Color {
        colorScheme == .dark ? .white.opacity(0.075) : .white.opacity(0.92)
    }

    private var capsuleStroke: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    private var avatarFallbackBackground: Color {
        colorScheme == .dark ? .white.opacity(0.16) : .black.opacity(0.08)
    }

    private var avatarFallbackText: Color {
        colorScheme == .dark ? .white.opacity(0.82) : .black.opacity(0.62)
    }
}

private struct GenreSunburstSearchPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    let items: [GenreSunburstSearchItem]
    let onSelect: (GenreSunburstSearchItem) -> Void

    @State private var text = ""
    @State private var candidates: [GenreSunburstSearchItem] = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(secondaryText)

                TextField(LT("搜索风格", "Search genres", "ジャンルを検索"), text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(primaryText)
                    .submitLabel(.done)
                    .focused($searchFieldFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(LT("收起", "Done", "閉じる")) {
                                searchFieldFocused = false
                            }
                        }
                    }

                if !text.isEmpty {
                    Button {
                        text = ""
                        searchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: 560)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(searchFieldBackground)
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.32 : 0.58)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(searchStroke, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.07),
                radius: colorScheme == .dark ? 0 : 12,
                x: 0,
                y: colorScheme == .dark ? 0 : 6
            )
            .frame(maxWidth: .infinity, alignment: .center)

            if !candidates.isEmpty {
                VStack(spacing: 8) {
                    ForEach(candidates) { item in
                        Button {
                            onSelect(item)
                            text = ""
                            candidates = []
                            searchFieldFocused = false
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.node.name)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(primaryText)
                                        .lineLimit(1)

                                    Text(item.pathText)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(secondaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(accentText)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .frame(maxWidth: 560)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(candidateBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .onChange(of: text) { _, value in
            scheduleSearch(for: value)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.86)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.58) : Color.black.opacity(0.50)
    }

    private var accentText: Color {
        colorScheme == .dark
            ? Color(red: 0.48, green: 0.88, blue: 1.0)
            : Color(red: 0.10, green: 0.48, blue: 0.78)
    }

    private var searchFieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.035) : Color.white.opacity(0.28)
    }

    private var searchStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.54)
    }

    private var candidateBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.78)
    }

    private func scheduleSearch(for value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            candidates = []
            return
        }

        let items = items
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

            let query = trimmed.lowercased()
            let result = await Task.detached(priority: .userInitiated) {
                GenreSunburstSearchItem.search(items: items, query: query)
            }.value

            guard !Task.isCancelled else { return }
            candidates = result
        }
    }
}
