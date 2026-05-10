import SwiftUI

struct SquadOfflineActivityBanner: View {
    let activity: SquadOfflineActivity
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                SquadOfflineEqualizerIcon(color: RaverTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.displayTitle ?? L("小队正在活动中", "Squad is active"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                    Text(L("小队 \(activity.participantCount) 人正在活动中", "\(activity.participantCount) squad members active"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.ultraThinMaterial, in: Capsule())
            .background(RaverTheme.card.opacity(0.86), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("进入小队线下活动", "Open squad offline activity"))
    }
}

struct SquadOfflineEqualizerIcon: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(height: animate ? 15 : 7, duration: 0.42, delay: 0)
            bar(height: animate ? 9 : 17, duration: 0.36, delay: 0.08)
            bar(height: animate ? 17 : 8, duration: 0.48, delay: 0.16)
        }
        .frame(width: 18, height: 18, alignment: .bottom)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }

    private func bar(height: CGFloat, duration: Double, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: 1.2)
            .fill(color)
            .frame(width: 3, height: height)
            .animation(
                .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animate
            )
    }
}
