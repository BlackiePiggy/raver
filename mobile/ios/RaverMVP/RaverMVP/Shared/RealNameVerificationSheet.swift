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
            .navigationTitle(LL("实名认证"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("关闭", "Close")) {
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
                Text(LL("真实姓名"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                TextField(LL("请输入本人姓名"), text: $legalName)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .padding(14)
                    .background(fieldBackground)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(LL("身份证号"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                TextField(LL("请输入18位身份证号"), text: $idNumber)
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

            Text(LL("认证信息仅用于平台合规审核。审核通过后即可使用发布、评论、关注、私信等社交功能。"))
                .font(.footnote)
                .foregroundStyle(RaverTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                submit()
            } label: {
                Text(LL("提交认证"))
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
                Label(LL("资料已提交"), systemImage: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                Text(LL("我们会尽快完成审核。审核通过后，社交功能会自动开放。"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    private var verifiedContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(LL("认证已通过"), systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                Text(LL("你现在可以正常使用发布、评论、关注、私信等社交功能。"))
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
            errorMessage = LL("请输入真实姓名")
            return
        }

        guard normalizedIDNumber.count == 18 else {
            errorMessage = LL("请输入18位身份证号")
            return
        }

        errorMessage = nil
        appState.realNameVerificationStatus = .pending
        OperationBannerCenter.shared.success(LL("实名认证资料已提交"))
    }
}

extension RealNameVerificationStatus {
    var title: String {
        switch self {
        case .unverified:
            return LL("未实名认证")
        case .pending:
            return LL("认证审核中")
        case .verified:
            return LL("已实名认证")
        case .rejected:
            return LL("认证未通过")
        }
    }

    var description: String {
        switch self {
        case .unverified:
            return LL("使用社交功能前，需要先完成实名认证。")
        case .pending:
            return LL("你的实名认证资料正在审核中，请稍后查看结果。")
        case .verified:
            return LL("你的实名认证已通过，可以使用全部社交功能。")
        case .rejected:
            return LL("认证资料未通过，请核对后重新提交。")
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
        session != nil && realNameVerificationStatus == .verified
    }

    var socialFeatureUnavailableMessage: String {
        if session == nil {
            return L("请先登录后再使用社交功能", "Please sign in before using social features.")
        }
        return LL("请先完成实名认证")
    }
}
