import SwiftUI
import AVFoundation
import UIKit

struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    @State private var mode: AuthMode = .login
    @State private var loginMethod: LoginMethod = .account
    @State private var username = "uploadtester"
    @State private var email = ""
    @State private var displayName = ""
    @State private var password = "123456"
    @State private var phoneNumber = ""
    @State private var smsCode = ""
    @State private var isLoading = false
    @State private var smsCooldownSeconds = 0
    @State private var smsCooldownTask: Task<Void, Never>?
    @State private var hasAgreedTerms = false
    @State private var showManualLogin = false
    @StateObject private var videoController = LoginBackgroundVideoController()
    @FocusState private var focusedField: ManualAuthField?

    private enum ManualAuthField {
        case username
        case phoneNumber
        case smsCode
        case email
        case displayName
        case password
    }

    var body: some View {
        ZStack {
            LoginBackgroundVideoView(player: videoController.player)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.54),
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.56),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showManualLogin = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            Task { await submitAuth(oneTap: true) }
                        } label: {
                            Text(LL("先看看"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.94))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || !hasAgreedTerms)
                    }
                    .padding(.top, topBarTopPadding(proxy.safeAreaInsets.top))

                    Spacer()

                    VStack(spacing: 14) {
                        centerBrandBadge(screenWidth: proxy.size.width)

                        Text("181****8835")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.98))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Button {
                            hasAgreedTerms.toggle()
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: hasAgreedTerms ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(hasAgreedTerms ? Color.white.opacity(0.96) : Color.white.opacity(0.56))
                                Text(LL("我同意《用户服务条款》《用户协议》《隐私政策》"))
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.84))
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("login.agreeTermsButton")

                        Button {
                            Task { await submitAuth(oneTap: true) }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color.black.opacity(0.38))
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(LL("一键登录/注册"))
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.96))
                                }
                            }
                            .frame(height: 54)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || !hasAgreedTerms)
                        .accessibilityIdentifier("login.oneTapButton")

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                showManualLogin.toggle()
                            }
                        } label: {
                            Text(LL("其他手机号登录"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .accessibilityIdentifier("login.showManualButton")

                        if showManualLogin {
                            manualLoginPanel
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        Text(LL("— 其他登录方式 —"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))

                        HStack(spacing: 34) {
                            thirdPartyButton(
                                assetName: "WeChatLoginIcon",
                                style: .assetCircle(
                                    background: Color(red: 0.18, green: 0.83, blue: 0.39),
                                    imageScale: 0.84
                                )
                            )
                            thirdPartyButton(assetName: "QQLoginIcon", style: .circle(Color(red: 0.92, green: 0.93, blue: 0.95)))
                            thirdPartyButton(systemName: "apple.logo", style: .circle(Color.black.opacity(0.88)))
                        }
                    }
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 22))
                }
                .padding(.horizontal, 24)
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            videoController.play()
        }
        .onDisappear {
            videoController.pause()
            smsCooldownTask?.cancel()
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .register {
                loginMethod = .account
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Collapse")) {
                    focusedField = nil
                    dismissKeyboard()
                }
            }
        }
    }

    @ViewBuilder
    private var manualLoginPanel: some View {
        VStack(spacing: 10) {
            Picker(LL("模式"), selection: $mode) {
                ForEach(AuthMode.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.14))
            )

            if mode == .login {
                Picker(L("登录方式", "Login Method"), selection: $loginMethod) {
                    ForEach(LoginMethod.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                )
            }

            if mode == .login, loginMethod == .sms {
                TextField(L("手机号（含区号）", "Phone Number (with country code)"), text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .phoneNumber)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .smsCode
                    }
                    .padding(14)
                    .background(inputFieldBackground)

                HStack(spacing: 10) {
                    TextField(L("验证码", "Verification Code"), text: $smsCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .smsCode)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                            dismissKeyboard()
                        }
                        .padding(14)
                        .background(inputFieldBackground)

                    Button {
                        Task { await sendSmsCode() }
                    } label: {
                        Text(
                            smsCooldownSeconds > 0
                            ? "\(smsCooldownSeconds)s"
                            : L("发送验证码", "Send Code")
                        )
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.22))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        isLoading
                            || smsCooldownSeconds > 0
                            || phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .accessibilityIdentifier("login.sendSmsCodeButton")
                }
            } else {
                TextField(LL("用户名"), text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(mode == .register ? .next : .go)
                    .onSubmit {
                        focusedField = mode == .register ? .email : .password
                    }
                    .padding(14)
                    .background(inputFieldBackground)
            }

            if mode == .register {
                TextField(LL("邮箱"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .displayName
                    }
                    .padding(14)
                    .background(inputFieldBackground)

                TextField(LL("显示名（可选）"), text: $displayName)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
                    .padding(14)
                    .background(inputFieldBackground)
            }

            if mode == .register || (mode == .login && loginMethod == .account) {
                SecureField(L("密码", "Password"), text: $password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                        dismissKeyboard()
                    }
                    .padding(14)
                    .background(inputFieldBackground)
            }

            Button {
                Task { await submitAuth(oneTap: false) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                    Text(submitTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.97))
                }
                .frame(height: 46)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmitManual || isLoading)
            .accessibilityIdentifier("login.manualSubmitButton")

            if let error = appState.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("login.errorText")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.26))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var canSubmitManual: Bool {
        if mode == .register {
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !password.isEmpty
                && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        switch loginMethod {
        case .account:
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
        case .sms:
            return !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var submitTitle: String {
        if mode == .register {
            return L("注册并登录", "Register & Sign In")
        }
        switch loginMethod {
        case .account:
            return L("账号登录", "Sign In")
        case .sms:
            return L("验证码登录", "SMS Sign In")
        }
    }

    private var inputFieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func centerBrandBadge(screenWidth: CGFloat) -> some View {
        let logoWidth = max(180, screenWidth * (2.0 / 3.0))

        if let badgeImage = UIImage(named: "LoginCenterBrand") {
            Image(uiImage: badgeImage)
                .resizable()
                .scaledToFit()
                .frame(width: logoWidth)
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        } else if let badgeURL = Bundle.main.url(forResource: "login-center-brand", withExtension: "png"),
                  let badgeImage = UIImage(contentsOfFile: badgeURL.path) {
            Image(uiImage: badgeImage)
                .resizable()
                .scaledToFit()
                .frame(width: logoWidth)
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        } else {
            VStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 102, height: 102)
                    .overlay {
                        Text("RH")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.42))
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)

                Text(RaverTheme.appName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.98))
            }
        }
    }

    @ViewBuilder
    private func thirdPartyButton(
        title: String? = nil,
        systemName: String? = nil,
        assetName: String? = nil,
        style: ThirdPartyButtonStyle
    ) -> some View {
        Button {
            appState.errorMessage = L("第三方登录即将开放，先使用账号登录", "Third-party login is coming soon. Please use account login for now.")
            withAnimation(.easeInOut(duration: 0.2)) {
                showManualLogin = true
            }
        } label: {
            switch style {
            case .circle(let bg):
                Circle()
                    .fill(bg)
                    .frame(width: 56, height: 56)
                    .overlay {
                        if let assetName {
                            Image(assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        } else if let title {
                            Text(title)
                                .font(.system(size: 26, weight: .heavy))
                                .foregroundStyle(.white)
                        } else if let systemName {
                            Image(systemName: systemName)
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
            case let .assetCircle(background, imageScale):
                Circle()
                    .fill(background)
                    .frame(width: 56, height: 56)
                    .overlay {
                        if let assetName {
                            Image(assetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: max(36, 56 * imageScale), height: max(36, 56 * imageScale))
                                .clipShape(Circle())
                        }
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
            case .assetRoundedRect:
                if let assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func topBarTopPadding(_ safeTop: CGFloat) -> CGFloat {
        max(10, min(20, safeTop - 24))
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func startSmsCooldown(seconds: Int) {
        let normalized = max(1, min(120, seconds))
        smsCooldownTask?.cancel()
        smsCooldownTask = Task {
            var remaining = normalized
            while remaining > 0, !Task.isCancelled {
                await MainActor.run {
                    smsCooldownSeconds = remaining
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }

            await MainActor.run {
                smsCooldownSeconds = 0
            }
        }
    }

    private func sendSmsCode() async {
        guard !isLoading else { return }
        if !hasAgreedTerms {
            appState.errorMessage = L("请先勾选并同意用户协议", "Please agree to the user terms first.")
            return
        }

        let normalizedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPhone.isEmpty else {
            appState.errorMessage = L("请先输入手机号", "Please enter phone number first.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        let expiresIn = await appState.sendLoginSmsCode(phoneNumber: normalizedPhone)
        guard let expiresIn else { return }
        let countdown = min(60, max(30, expiresIn / 2))
        startSmsCooldown(seconds: countdown)
    }

    private func submitAuth(oneTap: Bool) async {
        guard !isLoading else { return }
        if !hasAgreedTerms {
            appState.errorMessage = L("请先勾选并同意用户协议", "Please agree to the user terms first.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        if mode == .login {
            if loginMethod == .sms {
                await appState.loginWithSms(
                    phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    code: smsCode.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                return
            }

            await appState.login(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            return
        }

        let resolvedEmail: String
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, oneTap {
            let account = username.trimmingCharacters(in: .whitespacesAndNewlines)
            resolvedEmail = "\(account)@ravehub.app"
        } else {
            resolvedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        await appState.register(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            email: resolvedEmail,
            password: password,
            displayName: displayName
        )
    }
}

private enum ThirdPartyButtonStyle {
    case circle(Color)
    case assetCircle(background: Color, imageScale: CGFloat)
    case assetRoundedRect
}

private enum AuthMode: String, CaseIterable {
    case login
    case register

    var title: String {
        switch self {
        case .login: return L("登录", "Login")
        case .register: return L("注册", "Register")
        }
    }
}

private enum LoginMethod: String, CaseIterable {
    case account
    case sms

    var title: String {
        switch self {
        case .account:
            return L("账号", "Account")
        case .sms:
            return L("短信", "SMS")
        }
    }
}

private struct LoginBackgroundVideoView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

private final class LoginBackgroundVideoController: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init() {
        configure()
    }

    func play() {
        guard player.currentItem != nil else { return }
        player.play()
    }

    func pause() {
        player.pause()
    }

    private func configure() {
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.preventsDisplaySleepDuringVideoPlayback = false

        guard let url = Bundle.main.url(forResource: "login-background-placeholder", withExtension: "mp4") else {
            return
        }

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }
}
