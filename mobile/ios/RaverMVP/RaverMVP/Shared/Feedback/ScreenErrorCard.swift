import SwiftUI

struct ScreenErrorCard: View {
    var title: String = L("加载失败", "Load Failed")
    var message: String
    var retryTitle: String = L("重试", "Retry")
    var retryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.orange)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    if let retryAction {
                        Button(retryTitle, action: retryAction)
                            .buttonStyle(PrimaryButtonStyle())
                    }

                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule(style: .continuous)
                                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}
