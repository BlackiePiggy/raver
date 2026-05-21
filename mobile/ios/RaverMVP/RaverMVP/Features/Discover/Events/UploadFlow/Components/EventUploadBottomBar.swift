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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canGoBack)

            Button(action: onNext) {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isFinalStep ? LT("提交", "Submit", "送信") : LT("下一步", "Next", "次へ"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(RaverTheme.accent)
            .disabled(isBusy)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(RaverTheme.card)
    }
}
