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

                VStack(alignment: .leading, spacing: 12) {
                    if !exampleText.isEmpty {
                        sectionCard(
                            icon: "record.circle",
                            iconColor: .orange,
                            title: LT("风格特征", "Characteristics", "特徴")
                        ) {
                            soundCueExampleView
                        }
                    }

                    if !soundCueTracks.isEmpty {
                        sectionCard(
                            icon: "music.note",
                            iconColor: .green,
                            title: LT("经典曲目", "Classic Tracks", "クラシック曲")
                        ) {
                            trackListView
                        }
                    }

                    if !artistBindings.isEmpty {
                        sectionCard(
                            icon: "person.2.fill",
                            iconColor: .yellow,
                            title: LT("代表艺人", "Key Artists", "代表アーティスト")
                        ) {
                            artistGridView
                        }
                    }

                    if hasMetadata {
                        sectionCard(
                            icon: "info.circle.fill",
                            iconColor: RaverTheme.accent,
                            title: LT("基础信息", "Key Facts", "基本情報")
                        ) {
                            VStack(spacing: 10) {
                                LearnMetadataInfoRow(title: LT("起源地", "Origin", "発祥地"), value: genre.origin)
                                LearnMetadataInfoRow(title: LT("年代", "Era", "年代"), value: genre.era)
                                LearnMetadataInfoRow(title: "BPM", value: genre.bpm)
                            }
                        }
                    }

                    if hasExternalLinks {
                        sectionCard(
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
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .raverImmersiveFloatingNavigationChrome {
            dismiss()
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(maxWidth: .infinity)

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
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: themeColor.opacity(0.00), location: 0.10),
                            .init(color: themeColor.opacity(0.24), location: 0.56),
                            .init(color: themeColor.opacity(0.78), location: 1.00)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.35),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            .frame(height: heroHeight)
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: RaverTheme.background, location: 0.38),
                        .init(color: RaverTheme.background.opacity(0.6), location: 0.58),
                        .init(color: .clear, location: 0.78)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                LinearGradient(
                    colors: [.clear, RaverTheme.background],
                    startPoint: .init(x: 0.5, y: 0.65),
                    endPoint: .bottom
                )
            )

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
            .padding(.top, 104)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: heroHeight)
    }

    private var heroHeight: CGFloat { 272 }

    private func metaTag(label: String?, value: String) -> some View {
        HStack(spacing: 0) {
            if let label {
                Text(label)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Text(value)
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .overlay(
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }

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

    private func sectionCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RaverTheme.primaryText)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RaverTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 0.5)
        )
    }

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
        genre.path?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: " › ") ?? ""
    }

    private var exampleText: String {
        localizedGenreText(genre.exampleI18n, fallback: genre.example)
    }

    private var soundCueTracks: [LearnGenreSoundCueTrack] {
        genre.soundCueTracks ?? []
    }

    private var hasMetadata: Bool {
        [genre.origin, genre.era, genre.bpm].contains { value in
            !(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }

    private var hasExternalLinks: Bool {
        resolvedExternalURL(genre.wikipediaURL) != nil || resolvedExternalURL(genre.spotifyTrackURL) != nil
    }

    private var artistBindings: [LearnGenreKeyArtistBinding] {
        let bindings = genre.keyArtistBindings ?? []
        if !bindings.isEmpty {
            return bindings
        }
        return (genre.keyArtists ?? []).map { LearnGenreKeyArtistBinding(name: $0, djId: nil, dj: nil) }
    }

    private func localizedGenreText(_ value: WebBiText?, fallback: String?) -> String {
        let localized = value?.text(for: AppLanguagePreference.current.effectiveLanguage)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !localized.isEmpty {
            return localized
        }
        return fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func resolvedExternalURL(_ raw: String?) -> URL? {
        guard let raw, let resolved = AppConfig.resolvedURLString(raw), !resolved.isEmpty else {
            return nil
        }
        return URL(string: resolved)
    }

    private var soundCueExampleView: some View {
        LearnExpandableText(text: exampleText, collapsedLineLimit: 4)
    }

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
                }
                .padding(.vertical, 10)

                if index < soundCueTracks.count - 1 {
                    Divider().opacity(0.12)
                }
            }

            if !exampleText.isEmpty && soundCueTracks.isEmpty {
                Text(exampleText)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineSpacing(3)
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
            } else if let url = resolvedExternalURL(track.soundcloudUrl) {
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

    private var artistGridView: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
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
