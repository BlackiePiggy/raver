import SwiftUI

enum RealNameVerificationStatus: String, Codable {
    case unverified
    case pending
    case verified
    case rejected
}

struct RealNameVerificationSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var legalName = ""
    @State private var idNumber = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    statusHero

                    if appState.realNameVerificationStatus == .verified {
                        verifiedContent
                    } else if appState.realNameVerificationStatus == .pending {
                        pendingContent
                    } else {
                        formContent
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(RaverTheme.background)
            .navigationTitle(LT("实名认证", "Real-Name Verification", "実名認証"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("关闭", "Close", "閉じる")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var statusHero: some View {
        VStack(spacing: 14) {
            Image(systemName: appState.realNameVerificationStatus.badgeIconName)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(
                    LinearGradient(
                        colors: appState.realNameVerificationStatus.badgeGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )

            VStack(spacing: 6) {
                Text(appState.realNameVerificationStatus.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Text(appState.realNameVerificationStatus.description)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LT("真实姓名", "Legal Name", "本名"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                TextField(LT("请输入本人姓名", "Enter your legal name", "本人の名前を入力してください"), text: $legalName)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .padding(14)
                    .background(fieldBackground)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(LT("身份证号", "Identity Document Number", "身分証番号"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                TextField(LT("请输入18位身份证号", "Enter an 18-character identity number", "18桁の身分証番号を入力してください"), text: $idNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .padding(14)
                    .background(fieldBackground)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.95, green: 0.25, blue: 0.30))
            }

            Text(LT("认证信息仅用于平台合规审核。审核通过后即可使用发布、评论、关注、私信等社交功能。", "Verification information is used only for platform compliance review. After approval, you can use posting, comments, follows, DMs, and other social features.", "認証情報はプラットフォームのコンプライアンス審査にのみ使用します。承認後、投稿、コメント、フォロー、DMなどを利用できます。"))
                .font(.footnote)
                .foregroundStyle(RaverTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                submit()
            } label: {
                Text(LT("提交认证", "Submit Verification", "認証を送信"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.55)
        }
    }

    private var pendingContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(LT("资料已提交", "Information Submitted", "資料を送信しました"), systemImage: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                Text(LT("我们会尽快完成审核。审核通过后，社交功能会自动开放。", "We will review it as soon as possible. Social features will unlock automatically after approval.", "できるだけ早く審査します。承認後、ソーシャル機能は自動で利用可能になります。"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private var verifiedContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(LT("认证已通过", "Verification Approved", "認証済み"), systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                Text(LT("你现在可以正常使用发布、评论、关注、私信等社交功能。", "You can now use posting, comments, follows, DMs, and other social features normally.", "投稿、コメント、フォロー、DMなどのソーシャル機能を通常通り利用できます。"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private var canSubmit: Bool {
        !legalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && normalizedIDNumber.count == 18
    }

    private var normalizedIDNumber: String {
        idNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(RaverTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
            )
    }

    private func submit() {
        let name = legalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = LT("请输入真实姓名", "Please enter your legal name", "本名を入力してください")
            return
        }

        guard normalizedIDNumber.count == 18 else {
            errorMessage = LT("请输入18位身份证号", "Please enter an 18-character identity number", "18桁の身分証番号を入力してください")
            return
        }

        errorMessage = nil
        appState.realNameVerificationStatus = .pending
        OperationBannerCenter.shared.success(LT("实名认证资料已提交", "Real-name verification submitted", "実名認証資料を送信しました"))
    }
}

extension RealNameVerificationStatus {
    var title: String {
        switch self {
        case .unverified:
            return LT("未实名认证", "Not Verified", "未認証")
        case .pending:
            return LT("认证审核中", "Verification Pending", "認証審査中")
        case .verified:
            return LT("已实名认证", "Verified", "実名認証済み")
        case .rejected:
            return LT("认证未通过", "Verification Rejected", "認証未承認")
        }
    }

    var description: String {
        switch self {
        case .unverified:
            return LT("使用社交功能前，需要先完成实名认证。", "Complete real-name verification before using social features.", "ソーシャル機能を使う前に実名認証を完了する必要があります。")
        case .pending:
            return LT("你的实名认证资料正在审核中，请稍后查看结果。", "Your real-name verification is under review. Please check again later.", "実名認証資料は審査中です。後ほど結果をご確認ください。")
        case .verified:
            return LT("你的实名认证已通过，可以使用全部社交功能。", "Your real-name verification has been approved. All social features are available.", "実名認証が承認され、すべてのソーシャル機能を利用できます。")
        case .rejected:
            return LT("认证资料未通过，请核对后重新提交。", "Verification was rejected. Please check your information and submit again.", "認証資料が承認されませんでした。確認して再送信してください。")
        }
    }

    var badgeIconName: String {
        switch self {
        case .unverified:
            return "person.text.rectangle.fill"
        case .pending:
            return "clock.fill"
        case .verified:
            return "checkmark.seal.fill"
        case .rejected:
            return "exclamationmark.triangle.fill"
        }
    }

    var badgeGradientColors: [Color] {
        switch self {
        case .unverified:
            return [Color(red: 0.45, green: 0.45, blue: 0.50), RaverTheme.secondaryText]
        case .pending:
            return [Color(red: 0.96, green: 0.62, blue: 0.20), Color(red: 0.84, green: 0.42, blue: 0.12)]
        case .verified:
            return [Color(red: 0.20, green: 0.74, blue: 0.48), RaverTheme.accent]
        case .rejected:
            return [Color(red: 0.92, green: 0.24, blue: 0.32), Color(red: 0.60, green: 0.10, blue: 0.18)]
        }
    }
}

extension AppState {
    var canUseSocialFeatures: Bool {
        guard session != nil else { return false }
        if !AppConfig.isRealNameEnforcementEnabled {
            return session?.user.ageBand == .adult
        }
        return realNameVerificationStatus == .verified
    }

    var socialFeatureUnavailableMessage: String {
        if session == nil {
            return LT("请先登录后再使用社交功能", "Please sign in before using social features.", "ソーシャル機能を使うにはログインしてください。")
        }
        if !AppConfig.isRealNameEnforcementEnabled {
            return LT("年满 18 岁后才可以发言", "You must be 18 or older to post or comment.", "投稿やコメントは18歳以上のみ利用できます。")
        }
        return LT("请先完成实名认证", "Please complete real-name verification first.", "先に実名認証を完了してください")
    }

    var shouldPresentRealNameVerificationUI: Bool {
        AppConfig.isRealNameEnforcementEnabled
    }
}
