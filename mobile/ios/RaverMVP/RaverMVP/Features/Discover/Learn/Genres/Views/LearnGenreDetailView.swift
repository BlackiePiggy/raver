import SwiftUI

struct LearnGenreDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appPush) private var appPush
    let genre: LearnGenreDetail

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection

                if !pathText.isEmpty {
                    Text(pathText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }

                if !descriptionText.isEmpty {
                    Text(descriptionText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                        .padding(.horizontal, 18)
                        .padding(.top, pathText.isEmpty ? 12 : 4)
                        .padding(.bottom, 4)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if !artistBindings.isEmpty {
                        sectionCard(
                            chromeless: true,
                            icon: "person.2.fill",
                            iconColor: .yellow,
                            title: LT("代表艺人", "Key Artists", "代表アーティスト")
                        ) {
                            artistGridView
                        }
                    }

                    if !soundCueTracks.isEmpty {
                        sectionCard(
                            chromeless: true,
                            icon: "music.note",
                            iconColor: .green,
                            title: LT("经典曲目", "Classic Tracks", "クラシック曲")
                        ) {
                            trackListView
                        }
                    }

                    if hasExternalLinks {
                        sectionCard(
                            chromeless: true,
                            icon: "link",
                            iconColor: .blue,
                            title: LT("延伸阅读", "Links", "関連リンク")
                        ) {
                            VStack(spacing: 10) {
                                if let wikipediaURL = resolvedExternalURL(genre.wikipediaURL) {
                                    LearnExternalLinkRow(
                                        icon: "book.closed",
                                        title: "Wikipedia",
                                        url: wikipediaURL
                                    )
                                }
                                if let spotifyTrackURL = resolvedExternalURL(genre.spotifyTrackURL) {
                                    LearnExternalLinkRow(
                                        icon: "music.note",
                                        title: "Spotify",
                                        url: spotifyTrackURL
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .raverImmersiveFloatingNavigationChrome {
            dismiss()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // 背景底色（确保左侧无图片区域是纯背景色）
            RaverTheme.background
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)

            // 图片层：铺满整个 hero 区域
            Group {
                if let resolved = AppConfig.resolvedURLString(genre.backgroundImageURL) {
                    ImageLoaderView(urlString: resolved, resizingMode: .fill, showsIndicator: false)
                } else {
                    fallbackHeroBackground
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)
            .clipped()
            // 核心：用径向渐变 mask 实现右上角扩散光晕效果
            .mask(
                GeometryReader { geo in
                    RadialGradient(
                        colors: [.black, .clear],
                        center: .init(x: 0.80, y: 0.05),
                        startRadius: geo.size.width * 0.05,
                        endRadius: geo.size.width * 0.55
                    )
                    // 横向拉伸让光晕更像椭圆，向左延伸更远
                    .scaleEffect(x: 1.0, y: 1.6, anchor: .topTrailing)
                }
            )
            // 右边缘主题色晕染（氛围光）
            .overlay(
                RadialGradient(
                    colors: [themeColor.opacity(0.28), .clear],
                    center: .init(x: 1.0, y: 0.0),
                    startRadius: 0,
                    endRadius: 160
                )
                .blendMode(.screen)
            )
            // 底部渐变融入背景色
            .overlay(
                LinearGradient(
                    colors: [.clear, RaverTheme.background],
                    startPoint: .init(x: 0.5, y: 0.58),
                    endPoint: .bottom
                )
            )

            // 文字层
            VStack(alignment: .leading, spacing: 6) {
                Text(genre.name)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                if let chineseName {
                    Text(chineseName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(RaverTheme.accent)
                }

                HStack(spacing: 8) {
                    if let origin = genre.origin?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !origin.isEmpty {
                        metaTag(label: LT("起源：", "Origin: ", "起源："), value: origin)
                    }
                    if let era = genre.era?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !era.isEmpty {
                        metaTag(label: nil, value: era)
                    }
                    if let bpm = genre.bpm?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !bpm.isEmpty {
                        metaTag(label: "BPM ", value: bpm)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(height: heroHeight)
    }

    private var heroHeight: CGFloat { 272 }

    // MARK: - Meta Tag
    // 对齐图1：深色半透明底 + 清晰边框描边

    private func metaTag(label: String?, value: String) -> some View {
        HStack(spacing: 0) {
            if let label {
                Text(label)
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            Text(value)
                .foregroundStyle(Color.white.opacity(0.90))
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.38))
        .overlay(
            Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }

    // MARK: - Fallback Hero Background

    private var fallbackHeroBackground: some View {
        ZStack {
            Color.black.opacity(0.95)
            LinearGradient(
                colors: [
                    themeColor.opacity(0.92),
                    themeColor.opacity(0.54),
                    Color.black.opacity(0.98)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            RadialGradient(
                colors: [themeColor.opacity(0.35), .clear],
                center: .topTrailing,
                startRadius: 18,
                endRadius: 220
            )
        }
    }

    // MARK: - Section Card
    // 对齐图1：卡片背景更深，边框更明显，间距稍紧凑

    private func sectionCard<Content: View>(
        chromeless: Bool = false,
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if !chromeless {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 28, height: 28)
                        .background(iconColor.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RaverTheme.primaryText)
            }
            content()
        }
        .padding(chromeless ? 0 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if chromeless {
                    Color.clear
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.11))
                }
            }
        )
        .overlay(
            Group {
                if chromeless {
                    Color.clear
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                }
            }
        )
    }

    // MARK: - Computed Properties

    private var chineseName: String? {
        let value = genre.nameI18n?.zh.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }
        guard value.caseInsensitiveCompare(genre.name.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame else {
            return nil
        }
        return value
    }

    private var themeColor: Color {
        LearnGenreThemePalette.color(for: genre)
    }

    private var descriptionText: String {
        localizedGenreText(genre.descriptionI18n, fallback: genre.description)
    }

    private var pathText: String {
        formattedPathText(genre.path, fallbackName: genre.name)
    }

    private var soundCueTracks: [LearnGenreSoundCueTrack] {
        genre.soundCueTracks ?? []
    }

    private var hasExternalLinks: Bool {
        resolvedExternalURL(genre.wikipediaURL) != nil || resolvedExternalURL(genre.spotifyTrackURL) != nil
    }

    private var artistBindings: [LearnGenreKeyArtistBinding] {
        let bindings = genre.keyArtistBindings ?? []
        if !bindings.isEmpty { return bindings }
        return (genre.keyArtists ?? []).map { LearnGenreKeyArtistBinding(name: $0, djId: nil, dj: nil) }
    }

    private func localizedGenreText(_ value: WebBiText?, fallback: String?) -> String {
        let localized = value?.text(for: AppLanguagePreference.current.effectiveLanguage)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !localized.isEmpty { return localized }
        return fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func formattedPathText(_ rawPath: String?, fallbackName: String) -> String {
        let segments = rawPath?
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        guard !segments.isEmpty else { return "" }

        var displaySegments: [String] = []
        var previousFullTokens: [String] = []
        var previousSegmentTokens: [String] = []

        for (index, rawSegment) in segments.enumerated() {
            let humanized = humanizeGenrePathSegment(rawSegment)
            var tokens = tokenizeGenrePathSegment(humanized)
            if let stripped = stripGenrePathPrefix(from: tokens, candidates: [previousFullTokens, previousSegmentTokens]) {
                tokens = stripped
            }

            var display = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if index == segments.count - 1 {
                let trimmedFallback = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedFallback.isEmpty {
                    display = trimmedFallback
                }
            }
            guard !display.isEmpty else { continue }

            displaySegments.append(display)
            previousSegmentTokens = tokenizeGenrePathSegment(display)
            previousFullTokens = tokenizeGenrePathSegment(displaySegments.joined(separator: " "))
        }

        return displaySegments.joined(separator: " › ")
    }

    private func humanizeGenrePathSegment(_ rawSegment: String) -> String {
        let collapsed = rawSegment
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        return collapsed.map { token in
            guard token != token.uppercased() else { return token }
            return token.prefix(1).uppercased() + token.dropFirst().lowercased()
        }
        .joined(separator: " ")
    }

    private func tokenizeGenrePathSegment(_ text: String) -> [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased() }
    }

    private func stripGenrePathPrefix(from tokens: [String], candidates: [[String]]) -> [String]? {
        let matchedCandidate = candidates
            .filter { candidate in
                !candidate.isEmpty
                && tokens.count > candidate.count
                && Array(tokens.prefix(candidate.count)) == candidate
            }
            .max(by: { $0.count < $1.count })

        guard let matchedCandidate else { return nil }
        return Array(tokens.dropFirst(matchedCandidate.count))
    }

    private func resolvedExternalURL(_ raw: String?) -> URL? {
        guard let raw, let resolved = AppConfig.resolvedURLString(raw), !resolved.isEmpty else { return nil }
        return URL(string: resolved)
    }

    // MARK: - Track List

    private var trackListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(soundCueTracks.enumerated()), id: \.element.id) { index, track in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .frame(width: 20, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        if !track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(track.artist)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    trackExternalLinks(track)
                        .padding(.trailing, 12)
                }
                .padding(.vertical, 10)

                if index < soundCueTracks.count - 1 {
                    Divider().opacity(0.12)
                }
            }
        }
    }

    @ViewBuilder
    private func trackExternalLinks(_ track: LearnGenreSoundCueTrack) -> some View {
        HStack(spacing: 8) {
            if let url = resolvedExternalURL(track.spotifyUrl) {
                Link(destination: url) {
                    Image("SpotifyIcon")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }
            if let url = resolvedExternalURL(track.appleMusicUrl) {
                Link(destination: url) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color(red: 0.93, green: 0.22, blue: 0.35), in: Circle())
                }
            }
            if let url = resolvedExternalURL(track.neteaseUrl) {
                Link(destination: url) {
                    Image("NeteaseIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                }
            }
            if let url = resolvedExternalURL(track.soundcloudUrl) {
                Link(destination: url) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.orange, in: Circle())
                }
            }
        }
    }

    // MARK: - Artist Grid

    private var artistGridView: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(artistBindings) { artist in
                Group {
                    if canOpenArtistDetail(artist) {
                        Button {
                            openArtistDetail(artist)
                        } label: {
                            artistGridItem(artist)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(LT("打开 DJ 详情", "Open DJ detail", "DJ詳細を開く"))
                    } else {
                        artistGridItem(artist)
                    }
                }
            }
        }
    }

    private func artistGridItem(_ artist: LearnGenreKeyArtistBinding) -> some View {
        VStack(spacing: 6) {
            Group {
                if let avatarURL = resolvedArtistAvatarURL(artist) {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            artistAvatarFallback(artist)
                        }
                    }
                } else {
                    artistAvatarFallback(artist)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

            Text(artist.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RaverTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .top)
    }

    private func artistAvatarFallback(_ artist: LearnGenreKeyArtistBinding) -> some View {
        ZStack {
            Color.white.opacity(0.08)
            Text(String(artist.name.prefix(2)).uppercased())
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }

    private func resolvedArtistAvatarURL(_ artist: LearnGenreKeyArtistBinding) -> URL? {
        guard let raw = artist.dj?.avatarUrl ?? artist.dj?.avatarMediumUrl else { return nil }
        guard let resolved = AppConfig.resolvedDJAvatarURLString(raw, size: .medium) else { return nil }
        return URL(string: resolved)
    }

    private func canOpenArtistDetail(_ artist: LearnGenreKeyArtistBinding) -> Bool {
        (artist.dj?.id.nilIfBlank ?? artist.djId?.nilIfBlank) != nil
    }

    private func openArtistDetail(_ artist: LearnGenreKeyArtistBinding) {
        guard let djID = (artist.dj?.id.nilIfBlank ?? artist.djId?.nilIfBlank) else { return }
        appPush(.djDetail(djID: djID))
    }
}
