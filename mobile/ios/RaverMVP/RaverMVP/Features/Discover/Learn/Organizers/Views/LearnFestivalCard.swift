import SwiftUI

struct LearnFestivalCard: View {
    let festival: LearnFestival

    @State private var avatarLuminance: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            Color.clear
                .frame(height: 132)
        }
        .frame(maxWidth: .infinity)
        .overlay {
            bannerView
                .overlay {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: Color.black.opacity(0.45), location: 0.22),
                                    .init(color: Color.black.opacity(0.65), location: 0.62),
                                    .init(color: Color.black.opacity(0.82), location: 1.00)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 118, alignment: .bottom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .center, spacing: 12) {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 62)
                            .overlay {
                                avatarView
                                    .allowsHitTesting(false)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(LearnAvatarLuminanceStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(festival.name)
                                .font(.headline.weight(.black))
                                .foregroundStyle(Color.white)
                                .lineLimit(2)

                            Text(infoLine)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.86))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 20)
                }
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: festival.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let url = destinationURL(festival.backgroundUrl) {
            fallbackBanner
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackBanner
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = destinationURL(festival.avatarUrl) {
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
            Text(String(festival.name.prefix(2)).uppercased())
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var infoLine: String {
        let country = festival.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = festival.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let founded = festival.foundedYear.trimmingCharacters(in: .whitespacesAndNewlines)
        let freq = festival.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [country, city, founded, freq].filter { !$0.isEmpty }
        return parts.isEmpty ? LT("电子音乐节品牌", "Festival Brand", "電子音楽フェスブランド") : parts.joined(separator: " · ")
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(festival.avatarUrl) else {
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
}
