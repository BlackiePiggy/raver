import SwiftUI

struct EventUploadBottomBar: View {
    let canGoBack: Bool
    let isFinalStep: Bool
    var isBusy: Bool = false
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Text(LT("上一步", "Back", "戻る"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RaverTheme.background)
            )
            .disabled(!canGoBack)
            .foregroundStyle(canGoBack ? RaverTheme.secondaryText : RaverTheme.secondaryText.opacity(0.55))

            Button(action: onNext) {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text(isFinalStep ? LT("提交", "Submit", "送信") : LT("下一步", "Next", "次へ"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .background(
                LinearGradient(
                    colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
            .disabled(isBusy)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            RaverTheme.card
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
