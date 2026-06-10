import SwiftUI

private struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RaverTheme.cardBorder.opacity(0.7))
            .frame(width: width, height: height)
            .redacted(reason: .placeholder)
            .shimmeringPlaceholder()
    }
}

private struct ShimmeringPlaceholderModifier: ViewModifier {
    @State private var phase: CGFloat = -0.9

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.10),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .rotationEffect(.degrees(18))
                    .offset(x: proxy.size.width * phase)
                    .blendMode(.screen)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

private extension View {
    func shimmeringPlaceholder() -> some View {
        modifier(ShimmeringPlaceholderModifier())
    }
}

struct FeedSkeletonView: View {
    var count: Int = 4

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<count, id: \.self) { _ in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                SkeletonBlock(width: 44, height: 44, cornerRadius: 22)
                                VStack(alignment: .leading, spacing: 8) {
                                    SkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                                    SkeletonBlock(width: 100, height: 12, cornerRadius: 6)
                                }
                                Spacer()
                            }
                            SkeletonBlock(height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 16, cornerRadius: 8)
                            SkeletonBlock(width: 220, height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 180, cornerRadius: 20)
                            HStack {
                                SkeletonBlock(width: 72, height: 14, cornerRadius: 7)
                                Spacer()
                                SkeletonBlock(width: 130, height: 14, cornerRadius: 7)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }
}

struct SearchResultsSkeletonView: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                GlassCard {
                    HStack(spacing: 12) {
                        SkeletonBlock(width: 42, height: 42, cornerRadius: 21)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(width: 150, height: 16, cornerRadius: 8)
                            SkeletonBlock(width: 110, height: 12, cornerRadius: 6)
                        }
                        Spacer()
                        SkeletonBlock(width: 68, height: 32, cornerRadius: 16)
                    }
                }
            }
        }
        .padding(16)
    }
}

struct ProfileSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    SkeletonBlock(height: 250, cornerRadius: 0)

                    LinearGradient(
                        colors: [
                            .clear,
                            Color.black.opacity(0.30),
                            RaverTheme.background.opacity(0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    HStack(alignment: .top, spacing: 14) {
                        SkeletonBlock(width: 78, height: 78, cornerRadius: 39)
                        VStack(alignment: .leading, spacing: 9) {
                            SkeletonBlock(width: 170, height: 22, cornerRadius: 11)
                            HStack(spacing: 8) {
                                SkeletonBlock(width: 74, height: 24, cornerRadius: 8)
                                SkeletonBlock(width: 94, height: 24, cornerRadius: 8)
                            }
                            SkeletonBlock(width: 210, height: 15, cornerRadius: 7)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 26)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 24) {
                        ForEach(0..<4, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonBlock(width: index == 0 ? 34 : 42, height: 18, cornerRadius: 9)
                                SkeletonBlock(width: index == 0 ? 28 : 34, height: 12, cornerRadius: 6)
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        SkeletonBlock(width: 72, height: 26, cornerRadius: 10)
                        SkeletonBlock(width: 86, height: 26, cornerRadius: 10)
                        SkeletonBlock(width: 64, height: 26, cornerRadius: 10)
                    }

                    HStack(spacing: 10) {
                        SkeletonBlock(height: 44, cornerRadius: 14)
                        SkeletonBlock(height: 44, cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 16)

                VStack(spacing: 14) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SkeletonBlock(width: 130, height: 18, cornerRadius: 9)
                            HStack(spacing: 10) {
                                ForEach(0..<3, id: \.self) { _ in
                                    SkeletonBlock(height: 72, cornerRadius: 16)
                                }
                            }
                        }
                    }

                    ForEach(0..<2, id: \.self) { index in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    SkeletonBlock(width: 40, height: 40, cornerRadius: 20)
                                    VStack(alignment: .leading, spacing: 8) {
                                        SkeletonBlock(width: index == 0 ? 150 : 120, height: 16, cornerRadius: 8)
                                        SkeletonBlock(width: 96, height: 12, cornerRadius: 6)
                                    }
                                    Spacer()
                                }
                                SkeletonBlock(height: 16, cornerRadius: 8)
                                SkeletonBlock(width: index == 0 ? nil : 240, height: 16, cornerRadius: 8)
                                SkeletonBlock(height: index == 0 ? 150 : 112, cornerRadius: 18)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollIndicators(.hidden)
    }
}

struct EventDetailSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SkeletonBlock(height: 320, cornerRadius: 0)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 18) {
                        SkeletonBlock(width: 52, height: 18, cornerRadius: 9)
                        SkeletonBlock(width: 60, height: 18, cornerRadius: 9)
                        SkeletonBlock(width: 56, height: 18, cornerRadius: 9)
                        SkeletonBlock(width: 66, height: 18, cornerRadius: 9)
                    }
                    .padding(.top, 12)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SkeletonBlock(width: 110, height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(width: 220, height: 14, cornerRadius: 7)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SkeletonBlock(width: 96, height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 160, cornerRadius: 18)
                        }
                    }

                    GlassCard {
                        HStack(spacing: 12) {
                            SkeletonBlock(width: 38, height: 38, cornerRadius: 19)
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBlock(width: 72, height: 12, cornerRadius: 6)
                                SkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                            }
                            Spacer()
                            SkeletonBlock(width: 18, height: 18, cornerRadius: 9)
                        }
                    }
                }
                .padding(16)
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct DJDetailSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    SkeletonBlock(height: 300, cornerRadius: 0)
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.30), RaverTheme.background.opacity(0.98)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    HStack(alignment: .bottom, spacing: 14) {
                        SkeletonBlock(width: 86, height: 86, cornerRadius: 43)
                        VStack(alignment: .leading, spacing: 9) {
                            SkeletonBlock(width: 178, height: 24, cornerRadius: 12)
                            SkeletonBlock(width: 126, height: 15, cornerRadius: 7)
                            HStack(spacing: 8) {
                                SkeletonBlock(width: 58, height: 26, cornerRadius: 13)
                                SkeletonBlock(width: 72, height: 26, cornerRadius: 13)
                                SkeletonBlock(width: 64, height: 26, cornerRadius: 13)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonBlock(height: 46, cornerRadius: 14)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SkeletonBlock(width: 118, height: 18, cornerRadius: 9)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(width: 230, height: 14, cornerRadius: 7)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SkeletonBlock(width: 126, height: 18, cornerRadius: 9)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(0..<4, id: \.self) { _ in
                                        VStack(alignment: .leading, spacing: 8) {
                                            SkeletonBlock(width: 126, height: 84, cornerRadius: 16)
                                            SkeletonBlock(width: 96, height: 14, cornerRadius: 7)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SkeletonBlock(width: 110, height: 18, cornerRadius: 9)
                            ForEach(0..<2, id: \.self) { _ in
                                HStack(spacing: 12) {
                                    SkeletonBlock(width: 52, height: 52, cornerRadius: 12)
                                    VStack(alignment: .leading, spacing: 8) {
                                        SkeletonBlock(width: 160, height: 15, cornerRadius: 7)
                                        SkeletonBlock(width: 120, height: 12, cornerRadius: 6)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollIndicators(.hidden)
    }
}

struct GenreDetailSkeletonView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    SkeletonBlock(height: 272, cornerRadius: 0)

                    LinearGradient(
                        colors: [
                            .clear,
                            Color.black.opacity(0.18),
                            RaverTheme.background.opacity(0.96)
                        ],
                        startPoint: .init(x: 0.5, y: 0.58),
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 196, height: 36, cornerRadius: 12)
                        SkeletonBlock(width: 124, height: 17, cornerRadius: 8)

                        HStack(spacing: 8) {
                            SkeletonBlock(width: 94, height: 28, cornerRadius: 14)
                            SkeletonBlock(width: 72, height: 28, cornerRadius: 14)
                            SkeletonBlock(width: 66, height: 28, cornerRadius: 14)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }

                VStack(alignment: .leading, spacing: 0) {
                    SkeletonBlock(width: 188, height: 12, cornerRadius: 6)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 230, height: 14, cornerRadius: 7)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            SkeletonBlock(width: 90, height: 16, cornerRadius: 8)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ],
                                spacing: 12
                            ) {
                                ForEach(0..<8, id: \.self) { _ in
                                    VStack(spacing: 6) {
                                        SkeletonBlock(width: 56, height: 56, cornerRadius: 28)
                                        SkeletonBlock(width: 52, height: 12, cornerRadius: 6)
                                        SkeletonBlock(width: 44, height: 12, cornerRadius: 6)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .top)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            SkeletonBlock(width: 90, height: 16, cornerRadius: 8)

                            VStack(spacing: 0) {
                                ForEach(0..<3, id: \.self) { index in
                                    HStack(spacing: 12) {
                                        SkeletonBlock(width: 20, height: 14, cornerRadius: 7)

                                        VStack(alignment: .leading, spacing: 6) {
                                            SkeletonBlock(width: index == 0 ? 148 : 176, height: 14, cornerRadius: 7)
                                            SkeletonBlock(width: index == 2 ? 92 : 116, height: 12, cornerRadius: 6)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        HStack(spacing: 8) {
                                            SkeletonBlock(width: 20, height: 20, cornerRadius: 10)
                                            if index != 2 {
                                                SkeletonBlock(width: 20, height: 20, cornerRadius: 10)
                                            }
                                        }
                                        .padding(.trailing, 12)
                                    }
                                    .padding(.vertical, 10)

                                    if index < 2 {
                                        Divider().opacity(0.12)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            SkeletonBlock(width: 90, height: 16, cornerRadius: 8)

                            VStack(spacing: 10) {
                                SkeletonBlock(height: 44, cornerRadius: 12)
                                SkeletonBlock(height: 44, cornerRadius: 12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .raverImmersiveFloatingNavigationChrome {
            dismiss()
        }
    }
}

struct SetDetailSkeletonView: View {
    var body: some View {
        EventDetailSkeletonView()
    }
}

struct FollowListSkeletonView: View {
    var count: Int = 8

    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 48, height: 48, cornerRadius: 24)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                        SkeletonBlock(width: 96, height: 12, cornerRadius: 6)
                    }
                    Spacer()
                    SkeletonBlock(width: 78, height: 30, cornerRadius: 15)
                }
                .padding(.vertical, 8)
                .listRowBackground(RaverTheme.background)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct SquadProfileSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            SkeletonBlock(width: 72, height: 72, cornerRadius: 36)
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBlock(width: 180, height: 20, cornerRadius: 10)
                                SkeletonBlock(width: 150, height: 14, cornerRadius: 7)
                            }
                            Spacer()
                        }
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 220, height: 14, cornerRadius: 7)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBlock(width: 96, height: 16, cornerRadius: 8)
                        HStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                VStack(spacing: 6) {
                                    SkeletonBlock(width: 46, height: 46, cornerRadius: 23)
                                    SkeletonBlock(width: 56, height: 12, cornerRadius: 6)
                                }
                            }
                        }
                    }
                }

                ForEach(0..<3, id: \.self) { _ in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SkeletonBlock(width: 120, height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(width: 180, height: 14, cornerRadius: 7)
                        }
                    }
                }

                SkeletonBlock(height: 48, cornerRadius: 24)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }
}

struct CommentSectionSkeletonView: View {
    var count: Int = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(alignment: .top, spacing: 10) {
                    SkeletonBlock(width: 34, height: 34, cornerRadius: 17)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 120, height: 14, cornerRadius: 7)
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 200, height: 14, cornerRadius: 7)
                    }
                }
            }
        }
    }
}

struct ConversationListSkeletonView: View {
    var count: Int = 8

    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 48, height: 48, cornerRadius: 24)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 100, height: 12, cornerRadius: 6)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(RaverTheme.card)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct DiscoverGridSkeletonView: View {
    var count: Int = 6
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<count, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 118, cornerRadius: 0)
                        SkeletonBlock(width: 120, height: 15, cornerRadius: 7)
                        SkeletonBlock(width: 84, height: 12, cornerRadius: 6)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }
}

struct RecommendEventsSkeletonView: View {
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight

    var body: some View {
        GeometryReader { geometry in
            let horizontalInset: CGFloat = 16
            ZStack(alignment: .bottomLeading) {
                SkeletonBlock(height: max(geometry.size.height, 1), cornerRadius: 30)
                    .padding(.horizontal, horizontalInset)

                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.26),
                        Color.black.opacity(0.74)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .padding(.horizontal, horizontalInset)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        SkeletonBlock(width: 64, height: 26, cornerRadius: 13)
                        SkeletonBlock(width: 78, height: 26, cornerRadius: 13)
                    }
                    SkeletonBlock(width: 190, height: 17, cornerRadius: 8)
                    SkeletonBlock(width: 156, height: 15, cornerRadius: 7)
                    SkeletonBlock(width: 260, height: 42, cornerRadius: 12)
                    SkeletonBlock(width: 210, height: 42, cornerRadius: 12)
                }
                .padding(.horizontal, horizontalInset + 20)
                .padding(.bottom, 42)

                HStack(spacing: 4) {
                    SkeletonBlock(width: 28, height: 3, cornerRadius: 2)
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonBlock(width: 5, height: 3, cornerRadius: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 18)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, tabBarReservedHeight + 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RaverTheme.background)
    }
}

struct NewsListSkeletonView: View {
    var count: Int = 6

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            SkeletonBlock(width: 42, height: 18, cornerRadius: 6)
                            SkeletonBlock(width: 76, height: 12, cornerRadius: 6)
                        }
                        SkeletonBlock(height: 16, cornerRadius: 8)
                        SkeletonBlock(width: index.isMultiple(of: 2) ? 172 : 220, height: 16, cornerRadius: 8)
                        HStack(spacing: 10) {
                            SkeletonBlock(width: 86, height: 12, cornerRadius: 6)
                            SkeletonBlock(width: 36, height: 12, cornerRadius: 6)
                        }
                    }

                    Spacer(minLength: 0)

                    SkeletonBlock(width: 122, height: 82, cornerRadius: 6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if index < count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }
}

struct DJSpotlightSkeletonView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    SkeletonBlock(height: max(geometry.size.height * 0.58, 360), cornerRadius: 0)
                    Spacer(minLength: 0)
                }

                VStack(spacing: 14) {
                    Spacer(minLength: 0)
                    SkeletonBlock(width: min(geometry.size.width * 0.70, 280), height: min(geometry.size.width * 0.70, 280), cornerRadius: 34)
                    SkeletonBlock(width: 190, height: 24, cornerRadius: 12)
                    SkeletonBlock(width: 132, height: 15, cornerRadius: 7)
                    HStack(spacing: 10) {
                        SkeletonBlock(width: 88, height: 28, cornerRadius: 14)
                        SkeletonBlock(width: 104, height: 28, cornerRadius: 14)
                    }
                    SkeletonBlock(width: 250, height: 14, cornerRadius: 7)
                    SkeletonBlock(width: 210, height: 14, cornerRadius: 7)
                    HStack(spacing: 5) {
                        SkeletonBlock(width: 26, height: 4, cornerRadius: 2)
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonBlock(width: 5, height: 4, cornerRadius: 2)
                        }
                    }
                    .padding(.top, 8)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 28)
            }
        }
        .background(RaverTheme.background)
        .ignoresSafeArea(edges: .bottom)
    }
}

struct NotificationListSkeletonView: View {
    var count: Int = 8

    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { _ in
                HStack(alignment: .top, spacing: 12) {
                    SkeletonBlock(width: 30, height: 30, cornerRadius: 15)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 220, height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 100, height: 12, cornerRadius: 6)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(RaverTheme.card)
            }
        }
        .scrollContentBackground(.hidden)
    }
}
