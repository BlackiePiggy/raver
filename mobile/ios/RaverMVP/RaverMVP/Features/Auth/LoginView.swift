import SwiftUI
import AVFoundation
import FirebaseAuth
import UIKit
import PhotosUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    private let onContinueBrowsing: (() -> Void)?

    @State private var loginMethod: LoginMethod = .email
    @State private var username = "uploadtester"
    @State private var password = ""
    @State private var email = ""
    @State private var emailCode = ""
    @State private var selectedPhoneCountry = PhoneCountryOption.defaultOption
    @State private var phoneNumber = ""
    @State private var smsCode = ""
    @State private var firebaseVerificationID = ""
    @State private var isLoading = false
    @State private var smsCooldownSeconds = 0
    @State private var smsCooldownTask: Task<Void, Never>?
    @State private var hasAgreedTerms = false
    @State private var showManualLogin = false
    @State private var showRegistrationProfile = false
    @State private var authNoticeMessage: String?
    @StateObject private var videoController = LoginBackgroundVideoController()
    @FocusState private var focusedField: ManualAuthField?

    init(onContinueBrowsing: (() -> Void)? = nil) {
        self.onContinueBrowsing = onContinueBrowsing
    }

    private enum ManualAuthField {
        case username
        case email
        case emailCode
        case phoneNumber
        case smsCode
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
                            continueBrowsing()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            continueBrowsing()
                        } label: {
                            Text(LT("先看看", "Preview", "先に見る"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.94))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                    .padding(.top, topBarTopPadding(proxy.safeAreaInsets.top))

                    Spacer(minLength: 24)

                    VStack(spacing: 16) {
                        centerBrandBadge(screenWidth: proxy.size.width)
                            .padding(.bottom, 6)

                        Button {
                            hasAgreedTerms.toggle()
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: hasAgreedTerms ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(hasAgreedTerms ? Color.white.opacity(0.96) : Color.white.opacity(0.56))
                                Text(LT("我同意《用户服务条款》《用户协议》《隐私政策》", "I agree to the User Terms of Service, User Agreement, and Privacy Policy", "利用規約、ユーザー契約、プライバシーポリシーに同意します"))
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.84))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("login.agreeTermsButton")

                        Button {
                            guard hasAgreedTerms else {
                                authNoticeMessage = LT("请先勾选并同意用户服务条款、用户协议和隐私政策。", "Please agree to the user terms, user agreement, and privacy policy first.", "先に利用規約、ユーザー契約、プライバシーポリシーに同意してください。")
                                return
                            }
                            authNoticeMessage = nil
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                showManualLogin.toggle()
                            }
                            videoController.resumeIfNeeded()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color.black.opacity(0.44))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(LT("邮箱或账号登录", "Email or Account Sign In", "メールまたはアカウントでログイン"))
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.96))
                                }
                            }
                            .frame(height: 54)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .accessibilityIdentifier("login.showManualButton")

                        Button {
                            openRegistrationProfile()
                        } label: {
                            Text(LT("注册新账号", "Create New Account", "新規登録"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .accessibilityIdentifier("login.openRegisterButton")

                        if showManualLogin {
                            manualLoginPanel
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: 430)

                    Spacer(minLength: 22)

                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.white.opacity(0.28))
                                .frame(height: 1)

                            Text(LT("其他登录方式", "Other sign-in methods", "その他のログイン方法"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Rectangle()
                                .fill(Color.white.opacity(0.28))
                                .frame(height: 1)
                        }

                        HStack {
                            Spacer()
                            thirdPartyButton(systemName: "apple.logo", style: .circle(Color.black.opacity(0.88)))
                            Spacer()
                        }
                    }
                    .frame(maxWidth: 430)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 22))
                }
                .padding(.horizontal, 24)
            }
            .foregroundStyle(.white)

            if let message = authNoticeMessage, !message.isEmpty {
                authFloatingNotice(message: message) {
                    authNoticeMessage = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .onAppear {
            appState.suppressGlobalErrorAlert = true
            if let message = appState.errorMessage, !message.isEmpty {
                authNoticeMessage = message
                appState.errorMessage = nil
            }
            videoController.start()
        }
        .onDisappear {
            videoController.stop()
            smsCooldownTask?.cancel()
            appState.errorMessage = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            videoController.resumeIfNeeded()
        }
        .onChange(of: showManualLogin) { _, _ in
            videoController.resumeIfNeeded()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                videoController.resumeIfNeeded()
            }
        }
        .fullScreenCover(isPresented: $showRegistrationProfile) {
            RegisterProfileView(hasAgreedTerms: $hasAgreedTerms)
                .environmentObject(appState)
                .interactiveDismissDisabled(true)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LT("收起", "Collapse", "閉じる")) {
                    focusedField = nil
                    dismissKeyboard()
                }
            }
        }
    }

    @ViewBuilder
    private var manualLoginPanel: some View {
        VStack(spacing: 10) {
            Picker(LT("登录方式", "Login Method", "ログイン方法"), selection: $loginMethod) {
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

            if loginMethod == .email {
                TextField(LT("邮箱", "Email", "メール"), text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .emailCode }
                    .padding(14)
                    .background(inputFieldBackground)
                    .accessibilityIdentifier("login.emailField")

                HStack(spacing: 10) {
                    TextField(LT("验证码", "Verification Code", "認証コード"), text: $emailCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .emailCode)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                            dismissKeyboard()
                        }
                        .padding(14)
                        .background(inputFieldBackground)
                        .accessibilityIdentifier("login.emailCodeField")

                    Button {
                        Task { await sendEmailCode(scene: "login") }
                    } label: {
                        Text(
                            smsCooldownSeconds > 0
                            ? "\(smsCooldownSeconds)s"
                            : LT("发送验证码", "Send Code", "コードを送信")
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
                    .disabled(isLoading || smsCooldownSeconds > 0 || !isValidEmail(email))
                    .accessibilityIdentifier("login.sendEmailCodeButton")
                }
            } else if loginMethod == .sms {
                manualPhoneNumberInput(
                    country: $selectedPhoneCountry,
                    phoneNumber: $phoneNumber,
                    accessibilityPrefix: "login"
                )
                HStack(spacing: 10) {
                    TextField(LT("验证码", "Verification Code", "認証コード"), text: $smsCode)
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
                            : LT("发送验证码", "Send Code", "コードを送信")
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
                TextField(LT("用户名", "Username", "ユーザー名"), text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.go)
                    .onSubmit {
                        focusedField = .password
                    }
                    .padding(14)
                    .background(inputFieldBackground)
            }

            if loginMethod == .account {
                SecureField(LT("密码", "Password", "パスワード"), text: $password)
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
                Task { await submitAuth() }
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

            Button {
                openRegistrationProfile()
            } label: {
                HStack(spacing: 6) {
                    Text(LT("还没有账号？注册", "No account yet? Register", "アカウントをお持ちでない方は登録"))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityIdentifier("login.registerFromManualButton")
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
        switch loginMethod {
        case .email:
            return isValidEmail(email)
                && !emailCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .account:
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
        case .sms:
            return !normalizedPhoneNumber(country: selectedPhoneCountry, phoneNumber: phoneNumber).isEmpty
                && !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var submitTitle: String {
        switch loginMethod {
        case .email:
            return LT("邮箱验证码登录", "Email Code Sign In", "メール認証でログイン")
        case .account:
            return LT("账号登录", "Sign In", "アカウントでログイン")
        case .sms:
            return LT("验证码登录", "SMS Sign In", "SMSでログイン")
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

    private func authFloatingNotice(message: String, onDismiss: @escaping () -> Void) -> some View {
        VStack {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.76, blue: 0.42))

                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("login.errorText")

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 26, height: 26)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LT("关闭", "Close", "閉じる"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 18, y: 8)
            .padding(.horizontal, 24)
            .padding(.top, 58)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }

    private func manualPhoneNumberInput(
        country: Binding<PhoneCountryOption>,
        phoneNumber: Binding<String>,
        accessibilityPrefix: String
    ) -> some View {
        HStack(spacing: 10) {
            phoneCountryMenu(country: country, background: inputFieldBackground, accessibilityPrefix: accessibilityPrefix)

            TextField(LT("手机号", "Phone Number", "電話番号"), text: phoneNumber)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .phoneNumber)
                .submitLabel(.next)
                .onSubmit { focusedField = .smsCode }
                .padding(14)
                .background(inputFieldBackground)
                .accessibilityIdentifier("\(accessibilityPrefix).phoneNumberField")
        }
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
            guard hasAgreedTerms else {
                authNoticeMessage = LT("请先勾选并同意用户服务条款、用户协议和隐私政策。", "Please agree to the user terms, user agreement, and privacy policy first.", "先に利用規約、ユーザー契約、プライバシーポリシーに同意してください。")
                return
            }
            authNoticeMessage = LT("第三方登录即将开放，先使用账号登录", "Third-party login is coming soon. Please use account login for now.", "外部ログインは準備中です。先にアカウントログインをご利用ください。")
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

    private func openRegistrationProfile() {
        focusedField = nil
        dismissKeyboard()
        appState.errorMessage = nil
        authNoticeMessage = nil
        showRegistrationProfile = true
    }

    private func continueBrowsing() {
        focusedField = nil
        dismissKeyboard()
        if let onContinueBrowsing {
            appState.errorMessage = nil
            authNoticeMessage = nil
            appState.suppressGlobalErrorAlert = false
            onContinueBrowsing()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                showManualLogin = false
            }
        }
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
            authNoticeMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }

        let normalizedPhone = normalizedPhoneNumber(country: selectedPhoneCountry, phoneNumber: phoneNumber)
        guard !normalizedPhone.isEmpty else {
            authNoticeMessage = LT("请先输入手机号", "Please enter phone number first.", "電話番号を入力してください。")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            firebaseVerificationID = try await sendFirebasePhoneCode(phoneNumber: normalizedPhone)
            authNoticeMessage = nil
        } catch {
            authNoticeMessage = error.userFacingMessage
            return
        }
        let countdown = 60
        startSmsCooldown(seconds: countdown)
    }

    private func sendEmailCode(scene: String) async {
        guard !isLoading else { return }
        if !hasAgreedTerms {
            authNoticeMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(normalizedEmail) else {
            authNoticeMessage = LT("请输入有效邮箱", "Please enter a valid email address.", "有効なメールアドレスを入力してください。")
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let expiresInSeconds = await appState.sendEmailAuthCode(email: normalizedEmail, scene: scene) else {
            authNoticeMessage = appState.errorMessage
            appState.errorMessage = nil
            return
        }
        authNoticeMessage = nil
        startSmsCooldown(seconds: min(120, max(1, expiresInSeconds)))
    }

    private func submitAuth() async {
        guard !isLoading else { return }
        if !hasAgreedTerms {
            authNoticeMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }

        isLoading = true
        defer { isLoading = false }

        if loginMethod == .email {
            await appState.loginWithEmailCode(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                code: emailCode.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            authNoticeMessage = appState.errorMessage
            appState.errorMessage = nil
            return
        }

        if loginMethod == .sms {
            await submitFirebasePhoneAuth()
            return
        }

        await appState.login(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        authNoticeMessage = appState.errorMessage
        appState.errorMessage = nil
    }

    private func sendFirebasePhoneCode(phoneNumber: String) async throws -> String {
        try await requestFirebasePhoneVerificationID(phoneNumber: phoneNumber)
    }

    private func submitFirebasePhoneAuth() async {
        let verificationID = firebaseVerificationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = smsCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !verificationID.isEmpty else {
            authNoticeMessage = LT("请先发送验证码", "Please send a verification code first.", "先に認証コードを送信してください。")
            return
        }
        guard !code.isEmpty else {
            authNoticeMessage = LT("请输入验证码", "Please enter the verification code.", "認証コードを入力してください。")
            return
        }

        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: code
            )
            let result = try await Auth.auth().signIn(with: credential)
            let idToken = try await result.user.getIDToken()
            await appState.loginWithFirebasePhoneIdToken(idToken)
            authNoticeMessage = appState.errorMessage
            appState.errorMessage = nil
        } catch {
            authNoticeMessage = error.userFacingMessage
        }
    }
}

private extension UIImage {
    func resizedForRegistrationAvatar(maxPixel: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > maxPixel else { return self }
        let scale = maxPixel / longest
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private struct FlexibleWrapLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = arrangeRows(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = item.size
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func arrangeRows(proposal: ProposedViewSize, subviews: Subviews) -> [FlexibleWrapLayoutRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [FlexibleWrapLayoutRow] = []
        var current = FlexibleWrapLayoutRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty && nextWidth > maxWidth {
                rows.append(current)
                current = FlexibleWrapLayoutRow()
            }
            current.items.append(FlexibleWrapLayoutItem(index: index, size: size))
            current.width = current.items.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

private struct FlexibleWrapLayoutRow {
    var items: [FlexibleWrapLayoutItem] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
}

private struct FlexibleWrapLayoutItem {
    let index: Int
    let size: CGSize
}

private struct RegisterProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Binding var hasAgreedTerms: Bool

    @State private var currentPage: RegisterPage = .emailVerification
    @State private var registerEmail = ""
    @State private var registerEmailCode = ""
    @State private var smsCooldownSeconds = 0
    @State private var smsCooldownTask: Task<Void, Never>?
    @State private var displayName = ""
    @State private var selectedBirthDate = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: Calendar(identifier: .gregorian).component(.year, from: Date()) - 18, month: 1, day: 1)
    ) ?? Date()
    @State private var registrationRegionCatalog = RegistrationRegionCatalog.load()
    @State private var selectedRegistrationCountryCode = "CN"
    @State private var selectedRegistrationRegionCode = "310000"
    @State private var selectedRegistrationCityCode = "310000"
    @State private var displayNameAvailability: DisplayNameAvailabilityState = .idle
    @State private var displayNameAvailabilityTask: Task<Void, Never>?
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedAvatarData: Data?
    @State private var selectedAvatarImage: UIImage?
    @State private var isSubmitting = false
    @State private var isLoadingOnboardingOptions = false
    @State private var isSavingOnboarding = false
    @State private var registrationErrorMessage: String?
    @State private var onboardingErrorMessage: String?
    @State private var onboardingGenres: [OnboardingGenreOption] = []
    @State private var onboardingBrands: [WebLearnFestival] = []
    @State private var onboardingDJs: [WebDJ] = []
    @State private var selectedGenreIDs: Set<String> = []
    @State private var selectedBrandIDs: Set<String> = []
    @State private var selectedDJIDs: Set<String> = []
    @State private var showWelcomeCard = false

    @FocusState private var focusedField: RegisterField?

    private enum RegisterField {
        case email
        case emailCode
        case displayName
    }

    private enum RegisterPage {
        case emailVerification
        case profile
        case preferences

        var index: Int {
            switch self {
            case .emailVerification: return 0
            case .profile: return 1
            case .preferences: return 2
            }
        }
    }

    private var compliancePolicy: RegionalCompliancePolicy {
        RegionalCompliance.activePolicy
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.05),
                    Color(red: 0.12, green: 0.10, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    emailVerificationPage
                        .frame(width: proxy.size.width, height: proxy.size.height)

                    profilePage
                        .frame(width: proxy.size.width, height: proxy.size.height)

                    preferencesPage
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .offset(x: -CGFloat(currentPage.index) * proxy.size.width)
                .animation(.interactiveSpring(response: 0.36, dampingFraction: 0.88), value: currentPage)
                .clipped()
            }

            if showWelcomeCard {
                welcomeOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }

            if let notice = registerFloatingNoticeMessage {
                registerFloatingNotice(message: notice) {
                    registrationErrorMessage = nil
                    onboardingErrorMessage = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .foregroundStyle(.white)
        .onChange(of: selectedAvatarItem) { _, newItem in
            Task { await loadSelectedAvatar(newItem) }
        }
        .onChange(of: displayName) { _, newValue in
            scheduleDisplayNameAvailabilityCheck(newValue)
        }
        .onDisappear {
            smsCooldownTask?.cancel()
            displayNameAvailabilityTask?.cancel()
        }
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LT("收起", "Collapse", "閉じる")) {
                    focusedField = nil
                    dismissKeyboard()
                }
            }
        }
    }

    private var emailVerificationPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                emailVerificationHeader
                emailVerificationFields
                termsToggle
                emailVerificationButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var profilePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                profileHeader
                avatarPicker
                profileFields
                submitButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var preferencesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                preferencesHeader

                if isLoadingOnboardingOptions && onboardingGenres.isEmpty && onboardingBrands.isEmpty && onboardingDJs.isEmpty {
                    onboardingLoadingView
                } else {
                    onboardingGenreSection
                    onboardingBrandSection
                    onboardingDJSection
                    onboardingSubmitButton
                }

            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: currentPage) {
            guard currentPage == .preferences else { return }
            await loadOnboardingOptionsIfNeeded()
        }
    }

    private var emailVerificationHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("register.backButton")

            VStack(alignment: .leading, spacing: 8) {
                Text(LT("验证邮箱", "Verify Email", "メールを確認"))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.98))
                Text(LT("先完成邮箱验证，下一步再补充头像和昵称。", "Verify your email first, then add your avatar and nickname.", "先にメールを確認し、次にアイコンとニックネームを入力します。"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                    Text(LT("取消注册", "Cancel Sign-up", "登録をキャンセル"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("register.cancelButton")

            VStack(alignment: .leading, spacing: 8) {
                Text(LT("完善资料", "Complete Profile", "プロフィールを完成"))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.98))
                Text(LT("邮箱已验证，请补充头像、昵称和年龄信息。", "Email verified. Add your avatar, nickname, and age details.", "メールを確認しました。アイコン、ニックネーム、年齢情報を入力してください。"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var preferencesHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Button {
                    presentWelcomeCard()
                } label: {
                    Text(LT("跳过", "Skip", "スキップ"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .disabled(isSavingOnboarding)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(LT("调好你的频率", "Tune Your Frequency", "好みをチューニング"))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.98))
                Text(LT("选几个你喜欢的风格、音乐节和 DJ。", "Pick a few genres, festivals, and DJs you like.", "好きなジャンル、フェス、DJを選んでください。"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedRegistrationCountry: RegistrationCountryRegion {
        registrationRegionCatalog.country(for: selectedRegistrationCountryCode)
    }

    private var selectedRegistrationRegion: RegistrationAdministrativeRegion {
        selectedRegistrationCountry.children.first(where: { $0.code == selectedRegistrationRegionCode })
        ?? selectedRegistrationCountry.children[0]
    }

    private var selectedRegistrationCity: RegistrationAdministrativeArea {
        selectedRegistrationRegion.children.first(where: { $0.code == selectedRegistrationCityCode })
        ?? selectedRegistrationRegion.children[0]
    }

    private var selectedRegistrationLocationValue: String {
        [
            selectedRegistrationCountry.code,
            selectedRegistrationRegion.code,
            selectedRegistrationCity.code,
        ].joined(separator: ":")
    }

    private func resetRegistrationRegionSelection(for country: RegistrationCountryRegion? = nil) {
        let resolvedCountry = country ?? selectedRegistrationCountry
        let region = resolvedCountry.children[0]
        selectedRegistrationRegionCode = region.code
        selectedRegistrationCityCode = region.children.first?.code ?? region.code
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
            HStack(spacing: 16) {
                avatarPreview

                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedAvatarImage == nil ? LT("上传头像", "Upload Avatar", "アイコンをアップロード") : LT("更换头像", "Change Avatar", "アイコンを変更"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.97))
                    Text(LT("上传头像", "Upload Avatar", "アイコンをアップロード"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(16)
            .background(fieldBackground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("register.avatarPicker")
    }

    private var avatarPreview: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 72, height: 72)

            if let selectedAvatarImage {
                Image(uiImage: selectedAvatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
            } else {
                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var emailVerificationFields: some View {
        VStack(spacing: 12) {
            TextField(text: $registerEmail, prompt: registerPlaceholder(LT("邮箱", "Email", "メール"))) {
                Text(LT("邮箱", "Email", "メール"))
            }
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .emailCode }
            .padding(15)
            .background(fieldBackground)
            .accessibilityIdentifier("register.emailField")

            HStack(spacing: 10) {
                TextField(text: $registerEmailCode, prompt: registerPlaceholder(LT("验证码", "Verification Code", "認証コード"))) {
                    Text(LT("验证码", "Verification Code", "認証コード"))
                }
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .emailCode)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                    dismissKeyboard()
                }
                .padding(15)
                .background(fieldBackground)
                .accessibilityIdentifier("register.emailCodeField")

                Button {
                    Task { await sendRegisterEmailCode() }
                } label: {
                    Text(
                        smsCooldownSeconds > 0
                        ? "\(smsCooldownSeconds)s"
                        : LT("发送验证码", "Send Code", "コードを送信")
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(fieldBackground)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting || smsCooldownSeconds > 0 || !isValidEmail(registerEmail))
                .accessibilityIdentifier("register.sendEmailCodeButton")
            }
        }
    }

    private var profileFields: some View {
        VStack(spacing: 12) {
            TextField(text: $displayName, prompt: registerPlaceholder(LT("昵称", "Nickname", "ニックネーム"))) {
                Text(LT("昵称", "Nickname", "ニックネーム"))
            }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .displayName)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                    dismissKeyboard()
                }
                .padding(15)
                .background(fieldBackground)
                .accessibilityIdentifier("register.displayNameField")

            Text(LT("昵称全平台唯一，不区分大小写，提交后进入审核。", "Nicknames are unique across the platform, case-insensitive, and reviewed after submission.", "ニックネームは全体で一意です。大文字小文字は区別されず、送信後に審査されます。"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .frame(maxWidth: .infinity, alignment: .leading)

            displayNameAvailabilityHint

            if compliancePolicy.requiresAgeDeclaration {
                birthDatePicker
            }

            registrationCityPicker
        }
    }

    @ViewBuilder
    private var displayNameAvailabilityHint: some View {
        switch displayNameAvailability {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.72)
                    .tint(.white.opacity(0.72))
                Text(LT("正在检测昵称", "Checking nickname", "ニックネームを確認中"))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.66))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("register.displayNameCheckingText")
        case .available:
            Label(LT("昵称可用", "Nickname available", "このニックネームは使用できます"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.55, green: 0.95, blue: 0.68))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("register.displayNameAvailableText")
        case .taken:
            Label(LT("昵称已被使用", "Nickname already taken", "このニックネームは既に使用されています"), systemImage: "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 1, green: 0.68, blue: 0.68))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("register.displayNameTakenText")
        case .invalid:
            Label(LT("昵称需要 2-24 个字符", "Nickname must be 2-24 characters", "ニックネームは2〜24文字で入力してください"), systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("register.displayNameInvalidText")
        case .failed:
            Label(LT("昵称检测失败，提交时会再次校验", "Could not check nickname. It will be checked again on submit.", "確認できませんでした。送信時に再確認します。"), systemImage: "wifi.exclamationmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("register.displayNameCheckFailedText")
        }
    }

    private var birthDatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(
                LT("出生日期", "Date of Birth", "生年月日"),
                selection: $selectedBirthDate,
                in: birthDateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .padding(15)
            .background(fieldBackground)
            .accessibilityIdentifier("register.birthDatePicker")

            Text(LT("出生日期仅用于年龄分级和未成年人安全保护。", "Date of birth is used only for age rating and minor safety protections.", "生年月日は年齢区分と未成年者保護のためにのみ使用されます。"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var registrationCityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LT("常驻城市", "Home City", "居住都市"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))

            VStack(spacing: 10) {
                Menu {
                    ForEach(registrationRegionCatalog.countries) { country in
                        Button(country.displayName) {
                            selectedRegistrationCountryCode = country.code
                            resetRegistrationRegionSelection(for: country)
                        }
                    }
                } label: {
                    registerPickerToken(
                        title: selectedRegistrationCountry.displayName,
                        icon: "globe.asia.australia.fill"
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Menu {
                        ForEach(selectedRegistrationCountry.children) { region in
                            Button(region.displayName) {
                                selectedRegistrationRegionCode = region.code
                                selectedRegistrationCityCode = region.children.first?.code ?? region.code
                            }
                        }
                    } label: {
                        registerPickerToken(
                            title: selectedRegistrationRegion.displayName,
                            icon: "map.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    Menu {
                        ForEach(selectedRegistrationRegion.children) { city in
                            Button(city.displayName) {
                                selectedRegistrationCityCode = city.code
                            }
                        }
                    } label: {
                        registerPickerToken(
                            title: selectedRegistrationCity.displayName,
                            icon: "location.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(LT("会用于后续优先推荐你附近和同地区的活动。", "Used later to prioritize nearby and regional events.", "今後、近隣や同じ地域のイベント推薦に使われます。"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func registerPickerToken(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(fieldBackground)
    }

    private var termsToggle: some View {
        Button {
            hasAgreedTerms.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: hasAgreedTerms ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(hasAgreedTerms ? Color.white.opacity(0.96) : Color.white.opacity(0.56))
                Text(LT("我同意《用户服务条款》《用户协议》《隐私政策》", "I agree to the User Terms of Service, User Agreement, and Privacy Policy", "利用規約、ユーザー契約、プライバシーポリシーに同意します"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("register.agreeTermsButton")
    }

    private var onboardingLoadingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            InlineLoadingBadge(title: LT("正在更新偏好选项", "Updating preference options", "好みの候補を更新中"))
                .tint(.white)

            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 88)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var onboardingGenreSection: some View {
        onboardingSelectionSection(
            title: LT("喜欢的风格", "Favorite Genres", "好きなジャンル"),
            subtitle: LT("来自流派树的不同层级", "Mixed from the genre tree", "ジャンルツリーから選出")
        ) {
            FlexibleWrapLayout(spacing: 8, lineSpacing: 8) {
                ForEach(onboardingGenres) { genre in
                    onboardingChip(
                        title: genre.name,
                        isSelected: selectedGenreIDs.contains(genre.id)
                    ) {
                        toggleGenreSelection(genre.id)
                    }
                }
            }
        }
    }

    private var onboardingBrandSection: some View {
        onboardingSelectionSection(
            title: LT("关注的电音节", "Festival Brands", "フォローするフェス"),
            subtitle: LT("关注后可收到相关动态", "Follow for future updates", "今後の更新を受け取れます")
        ) {
            VStack(spacing: 10) {
                ForEach(onboardingBrands.prefix(10)) { brand in
                    onboardingBrandRow(brand)
                }
            }
        }
    }

    private var onboardingDJSection: some View {
        onboardingSelectionSection(
            title: LT("喜欢的 DJ", "Favorite DJs", "好きなDJ"),
            subtitle: LT("从 SoundCloud 粉丝量 Top 100 中随机抽取", "Randomly picked from SoundCloud top 100", "SoundCloud上位100組からランダム選出")
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 10)], spacing: 10) {
                ForEach(onboardingDJs.prefix(18)) { dj in
                    onboardingDJCard(dj)
                }
            }
        }
    }

    private func onboardingSelectionSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.84))
                    .frame(width: 3, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                }
            }

            content()
        }
        .padding(.vertical, 6)
    }

    private func onboardingChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.9) : Color.white.opacity(0.88))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule().fill(isSelected ? Color.white.opacity(0.94) : Color.white.opacity(0.16))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(isSelected ? 0.0 : 0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func onboardingBrandRow(_ brand: WebLearnFestival) -> some View {
        let isSelected = selectedBrandIDs.contains(brand.id)
        return Button {
            toggleBrandSelection(brand.id)
        } label: {
            HStack(spacing: 12) {
                onboardingRemoteArtwork(urlString: brand.avatarUrl, fallbackIcon: "sparkles", size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(brand.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)
                    Text([brand.city, brand.country].filter { !$0.isEmpty }.joined(separator: " / "))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.82) : .white.opacity(0.42))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.9) : Color.clear)
                    )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: RectangleCornerRadii(
                        topLeading: 4,
                        bottomLeading: 4,
                        bottomTrailing: 20,
                        topTrailing: 20
                    ),
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: isSelected
                        ? [Color.white.opacity(0.26), Color.white.opacity(0.12)]
                        : [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.28))
                    .frame(width: 3)
            }
        }
        .buttonStyle(.plain)
    }

    private func onboardingDJCard(_ dj: WebDJ) -> some View {
        let isSelected = selectedDJIDs.contains(dj.id)
        return Button {
            toggleDJSelection(dj.id)
        } label: {
            VStack(spacing: 9) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 78, height: 78)
                            .blur(radius: 7)
                    }

                    onboardingRemoteArtwork(
                        urlString: AppConfig.resolvedDJAvatarURLString(dj.avatarSmallUrl ?? dj.avatarMediumUrl ?? dj.avatarUrl, size: .small),
                        fallbackIcon: "music.mic",
                        size: 64
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white.opacity(0.96) : Color.white.opacity(0.18), lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: isSelected ? Color.white.opacity(0.24) : Color.black.opacity(0.22), radius: isSelected ? 12 : 5, x: 0, y: 6)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.86))
                            .frame(width: 23, height: 23)
                            .background(Circle().fill(Color.white.opacity(0.96)))
                            .offset(x: 24, y: -24)
                            .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 3)
                    }
                }
                .frame(width: 86, height: 78)

                Text(dj.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.98) : .white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func onboardingRemoteArtwork(urlString: String?, fallbackIcon: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: size, height: size)

            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: fallbackIcon)
                            .font(.system(size: size * 0.34, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    private var onboardingSubmitButton: some View {
        Button {
            Task { await submitOnboardingPreferences() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                if isSavingOnboarding {
                    ProgressView().tint(.black)
                } else {
                    Text(LT("完成选择", "Finish", "完了"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.88))
                }
            }
            .frame(height: 54)
        }
        .buttonStyle(.plain)
        .disabled(isSavingOnboarding)
    }

    private var welcomeOverlay: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 94, height: 94)
                        .blur(radius: 1)
                    Image(systemName: "house.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }

                Text("这里是RaveHub，欢迎回家Raver！")
                    .font(.system(size: 25, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    enterApp()
                } label: {
                    Text(LT("点击进入", "Enter", "入る"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Color.white.opacity(0.94)))
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
            )
            .shadow(color: Color.white.opacity(0.14), radius: 30, x: 0, y: 0)
            .padding(.horizontal, 28)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submitRegistration() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canSubmit ? Color.white.opacity(0.92) : Color.white.opacity(0.22))
                if isSubmitting {
                    ProgressView().tint(.black)
                } else {
                    Text(LT("完成注册", "Complete Registration", "登録を完了"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(canSubmit ? Color.black.opacity(0.88) : Color.white.opacity(0.56))
                }
            }
            .frame(height: 54)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || isSubmitting)
        .accessibilityIdentifier("register.submitButton")
    }

    private var emailVerificationButton: some View {
        Button {
            Task { await verifyRegisterEmailAndContinue() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canVerifyEmail ? Color.white.opacity(0.92) : Color.white.opacity(0.22))
                if isSubmitting {
                    ProgressView().tint(.black)
                } else {
                    Text(LT("验证并继续", "Verify and Continue", "確認して続行"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(canVerifyEmail ? Color.black.opacity(0.88) : Color.white.opacity(0.56))
                }
            }
            .frame(height: 54)
        }
        .buttonStyle(.plain)
        .disabled(!canVerifyEmail || isSubmitting)
        .accessibilityIdentifier("register.verifyEmailButton")
    }

    private var canSubmit: Bool {
        currentPage == .profile
            && isValidEmail(registerEmail)
            && !registerEmailCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && displayNameAvailability.allowsSubmit
            && hasAgreedTerms
            && isAgeDeclarationAcceptable
    }

    private var canVerifyEmail: Bool {
        isValidEmail(registerEmail)
            && !registerEmailCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var registerFloatingNoticeMessage: String? {
        if let message = registrationErrorMessage, !message.isEmpty {
            return message
        }
        if let message = onboardingErrorMessage, !message.isEmpty {
            return message
        }
        return nil
    }

    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let earliest = calendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? now
        return earliest...now
    }

    private var selectedBirthYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: selectedBirthDate)
    }

    private var isAgeDeclarationAcceptable: Bool {
        guard compliancePolicy.requiresAgeDeclaration else { return true }
        return ageBand(for: selectedBirthDate) != .under13
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.34))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
    }

    private func registerPlaceholder(_ title: String) -> Text {
        Text(title).foregroundColor(.white.opacity(0.82))
    }

    private func registerFloatingNotice(message: String, onDismiss: @escaping () -> Void) -> some View {
        VStack {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.76, blue: 0.42))

                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 26, height: 26)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LT("关闭", "Close", "閉じる"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 18, y: 8)
            .padding(.horizontal, 24)
            .padding(.top, 58)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }

    private func ageBand(for birthDate: Date, now: Date = Date()) -> UserAgeBand {
        let calendar = Calendar(identifier: .gregorian)
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        let age = ageComponents.year ?? 0
        if age < compliancePolicy.minimumAge { return .under13 }
        if age < compliancePolicy.minorAgeThreshold { return .minor }
        return .adult
    }

    private func startSmsCooldown(seconds: Int) {
        smsCooldownTask?.cancel()
        smsCooldownTask = Task {
            for remaining in stride(from: seconds, through: 0, by: -1) {
                await MainActor.run {
                    smsCooldownSeconds = remaining
                }
                guard remaining > 0 else { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            await MainActor.run {
                smsCooldownSeconds = 0
            }
        }
    }

    private func sendRegisterEmailCode() async {
        guard !isSubmitting else { return }
        guard hasAgreedTerms else {
            registrationErrorMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }
        let normalizedEmail = registerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(normalizedEmail) else {
            registrationErrorMessage = LT("请输入有效邮箱", "Please enter a valid email address.", "有効なメールアドレスを入力してください。")
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        guard let expiresInSeconds = await appState.sendEmailAuthCode(email: normalizedEmail, scene: "register") else {
            registrationErrorMessage = appState.errorMessage
            return
        }

        registrationErrorMessage = nil
        startSmsCooldown(seconds: min(120, max(1, expiresInSeconds)))
    }

    private func verifyRegisterEmailAndContinue() async {
        guard !isSubmitting else { return }
        guard hasAgreedTerms else {
            registrationErrorMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }

        let normalizedEmail = registerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(normalizedEmail) else {
            registrationErrorMessage = LT("请输入有效邮箱", "Please enter a valid email address.", "有効なメールアドレスを入力してください。")
            return
        }

        let code = registerEmailCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            registrationErrorMessage = LT("请输入验证码", "Please enter the verification code.", "認証コードを入力してください。")
            return
        }

        registrationErrorMessage = nil
        focusedField = nil
        dismissKeyboard()
        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
            currentPage = .profile
        }
    }

    private func submitRegistration() async {
        guard !isSubmitting else { return }

        let resolvedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = registerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = registerEmailCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(normalizedEmail) else {
            registrationErrorMessage = LT("请先完成邮箱验证", "Please verify your email first.", "先にメール認証を完了してください。")
            return
        }
        guard !code.isEmpty else {
            registrationErrorMessage = LT("请输入验证码", "Please enter the verification code.", "認証コードを入力してください。")
            return
        }

        guard !resolvedDisplayName.isEmpty else {
            registrationErrorMessage = LT("请输入昵称", "Please enter nickname", "ニックネームを入力してください。")
            return
        }

        guard hasAgreedTerms else {
            registrationErrorMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }

        let birthYear = compliancePolicy.requiresAgeDeclaration ? selectedBirthYear : nil
        let regionCode = compliancePolicy.requiresAgeDeclaration ? compliancePolicy.region.rawValue : nil

        if compliancePolicy.requiresAgeDeclaration,
           ageBand(for: selectedBirthDate) == .under13 {
            registrationErrorMessage = LT("未达到本地区最低年龄要求，暂不能注册。", "You do not meet the minimum age requirement for this region.", "この地域の最低年齢要件を満たしていないため登録できません。")
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            appState.beginRegistrationOnboarding()
            try await appState.registerWithEmailCode(
                email: normalizedEmail,
                code: code,
                displayName: resolvedDisplayName,
                birthYear: birthYear,
                regionCode: regionCode
            )
            registrationErrorMessage = nil
        } catch {
            appState.finishRegistrationOnboarding()
            registrationErrorMessage = error.userFacingMessage
            return
        }

        registrationErrorMessage = nil

        Task {
            await saveRegistrationLocationInBackground(selectedRegistrationLocationValue)
        }

        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
            currentPage = .preferences
        }

        if let selectedAvatarData {
            let avatarData = selectedAvatarData
            if let userId = appState.session?.user.id,
               let localURL = try? LocalProfileAvatarCache.save(imageData: avatarData, userId: userId) {
                let localAvatarURL = localURL.absoluteString
                appState.updateCurrentUserAvatarURL(localAvatarURL)
                if let snapshot = appState.currentUserProfileSnapshot(avatarURL: localAvatarURL) {
                    NotificationCenter.default.post(name: .profileDidUpdate, object: snapshot)
                }
            }
            Task {
                await uploadRegistrationAvatarInBackground(avatarData)
            }
        }
    }

    private func loadOnboardingOptionsIfNeeded() async {
        guard !isLoadingOnboardingOptions else { return }
        guard onboardingGenres.isEmpty || onboardingBrands.isEmpty || onboardingDJs.isEmpty else { return }

        isLoadingOnboardingOptions = true
        defer { isLoadingOnboardingOptions = false }

        do {
            let options = try await appContainer.webService.fetchOnboardingPreferenceOptions()
            onboardingGenres = options.genres
            onboardingBrands = options.brands
            onboardingDJs = options.djs
            onboardingErrorMessage = nil
        } catch {
            onboardingErrorMessage = error.userFacingMessage ?? LT("推荐选项加载失败，请稍后重试。", "Could not load picks. Please try again later.", "おすすめを読み込めませんでした。時間をおいて再試行してください。")
        }
    }

    private func uploadRegistrationAvatarInBackground(_ avatarData: Data) async {
        do {
            let uploaded = try await appContainer.profileUserRepository.uploadMyAvatar(
                imageData: avatarData,
                fileName: "avatar-\(Int(Date().timeIntervalSince1970)).jpg",
                mimeType: "image/jpeg"
            )
            appState.updateCurrentUserAvatarURL(uploaded.avatarURL)
            NotificationCenter.default.post(
                name: .profileDidUpdate,
                object: appState.currentUserProfileSnapshot(avatarURL: uploaded.avatarURL)
            )
        } catch {
            onboardingErrorMessage = LT("头像上传失败，请稍后在个人主页重试", "Avatar upload failed. Please retry from your profile later.", "アイコンのアップロードに失敗しました。後ほどプロフィールから再試行してください。")
        }
    }

    private func saveRegistrationLocationInBackground(_ location: String) async {
        guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let profile = try await appContainer.profileUserRepository.fetchMyProfile()
            let updated = try await appContainer.profileUserRepository.updateMyProfile(
                input: UpdateMyProfileInput(
                    displayName: profile.displayName,
                    bio: profile.bio,
                    location: location,
                    tags: profile.tags,
                    isFollowersListPublic: profile.isFollowersListPublic,
                    isFollowingListPublic: profile.isFollowingListPublic
                )
            )
            appState.applyCurrentUserProfile(updated)
            NotificationCenter.default.post(name: .profileDidUpdate, object: updated)
        } catch {
            onboardingErrorMessage = LT("城市保存失败，请稍后在个人资料中更新", "Could not save city. Update it from your profile later.", "都市を保存できませんでした。後ほどプロフィールで更新してください。")
        }
    }

    private func submitOnboardingPreferences() async {
        guard !isSavingOnboarding else { return }
        isSavingOnboarding = true
        defer { isSavingOnboarding = false }

        do {
            let selectedGenres = onboardingGenres
                .filter { selectedGenreIDs.contains($0.id) }
                .map(\.name)

            let selectedDJList = onboardingDJs.filter { selectedDJIDs.contains($0.id) }

            if !selectedGenres.isEmpty {
                let profile = try await appContainer.profileUserRepository.fetchMyProfile()
                let mergedTags = Self.uniqueStrings(profile.tags + selectedGenres)
                let updated = try await appContainer.profileUserRepository.updateMyProfile(
                    input: UpdateMyProfileInput(
                        displayName: profile.displayName,
                        bio: profile.bio,
                        location: profile.location,
                        tags: mergedTags,
                        isFollowersListPublic: profile.isFollowersListPublic,
                        isFollowingListPublic: profile.isFollowingListPublic
                    )
                )
                appState.applyCurrentUserProfile(updated)
                NotificationCenter.default.post(name: .profileDidUpdate, object: updated)
            }

            for dj in selectedDJList {
                _ = try await appContainer.webService.toggleDJFollow(djID: dj.id, shouldFollow: true)
            }
            if !selectedDJIDs.isEmpty {
                NotificationCenter.default.post(name: .raverFollowedDJsDidMutate, object: nil)
            }

            if !selectedBrandIDs.isEmpty {
                let currentPreference = (try? await appContainer.socialService.fetchFollowedBrandUpdatePreference()) ?? .empty
                let mergedBrandIDs = Self.uniqueStrings(currentPreference.watchedBrandIds + Array(selectedBrandIDs))
                _ = try await appContainer.socialService.updateFollowedBrandUpdatePreference(
                    FollowedBrandUpdatePreferenceInput(
                        enabled: true,
                        reminderHours: nil,
                        timezone: nil,
                        channels: nil,
                        watchedBrandIds: mergedBrandIDs,
                        includeInfos: nil,
                        includeEvents: nil
                    )
                )
                NotificationCenter.default.post(name: .raverFollowedBrandsDidMutate, object: nil)
            }

            await RecommendEventsViewModel.prewarmDailyRecommendations(
                sessionUserID: appState.session?.user.id,
                recommendationRepository: appContainer.eventRecommendationRepository,
                listRepository: appContainer.eventListRepository,
                checkinRepository: appContainer.eventCheckinRepository
            )

            onboardingErrorMessage = nil
            presentWelcomeCard()
        } catch {
            onboardingErrorMessage = error.userFacingMessage ?? LT("保存失败，请稍后重试。", "Could not save. Please try again later.", "保存できませんでした。時間をおいて再試行してください。")
        }
    }

    private func toggleGenreSelection(_ id: String) {
        if selectedGenreIDs.contains(id) {
            selectedGenreIDs.remove(id)
        } else {
            selectedGenreIDs.insert(id)
        }
    }

    private func toggleBrandSelection(_ id: String) {
        if selectedBrandIDs.contains(id) {
            selectedBrandIDs.remove(id)
        } else {
            selectedBrandIDs.insert(id)
        }
    }

    private func toggleDJSelection(_ id: String) {
        if selectedDJIDs.contains(id) {
            selectedDJIDs.remove(id)
        } else {
            selectedDJIDs.insert(id)
        }
    }

    private func enterApp() {
        withAnimation(.easeInOut(duration: 0.26)) {
            showWelcomeCard = false
        }
        appState.finishRegistrationOnboarding()
        dismiss()
    }

    private func presentWelcomeCard() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            showWelcomeCard = true
        }
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    private func scheduleDisplayNameAvailabilityCheck(_ rawValue: String) {
        displayNameAvailabilityTask?.cancel()
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            displayNameAvailability = .idle
            return
        }
        guard candidate.count >= 2 && candidate.count <= 24 else {
            displayNameAvailability = .invalid
            return
        }

        displayNameAvailability = .checking
        displayNameAvailabilityTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            do {
                let result = try await appState.checkDisplayNameAvailability(candidate)
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    displayNameAvailability = result.available ? .available : .taken
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    displayNameAvailability = .failed
                }
            }
        }
    }

    private func loadSelectedAvatar(_ item: PhotosPickerItem?) async {
        guard let item else {
            selectedAvatarData = nil
            selectedAvatarImage = nil
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let preparedData = Self.preparedAvatarData(from: data)
            await MainActor.run {
                selectedAvatarData = preparedData
                selectedAvatarImage = UIImage(data: preparedData)
            }
        } catch {
            await MainActor.run {
                registrationErrorMessage = LT("头像读取失败，请重新选择", "Failed to read avatar. Please choose again.", "アイコンの読み込みに失敗しました。もう一度選択してください。")
            }
        }
    }

    private static func preparedAvatarData(from data: Data) -> Data {
        guard
            let image = UIImage(data: data),
            let resized = image.resizedForRegistrationAvatar(maxPixel: 512),
            let jpegData = resized.jpegData(compressionQuality: 0.78)
        else {
            return data
        }
        return jpegData
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private enum ThirdPartyButtonStyle {
    case circle(Color)
    case assetCircle(background: Color, imageScale: CGFloat)
    case assetRoundedRect
}

private enum LoginMethod: String, CaseIterable {
    case email
    case account
    case sms

    var title: String {
        switch self {
        case .email:
            return LT("邮箱", "Email", "メール")
        case .account:
            return LT("账号", "Account", "アカウント")
        case .sms:
            return LT("短信", "SMS", "SMS")
        }
    }
}

private enum RegisterAuthMethod: String, CaseIterable {
    case phone
    case email

    var title: String {
        switch self {
        case .phone:
            return LT("手机", "Phone", "電話")
        case .email:
            return LT("邮箱", "Email", "メール")
        }
    }
}

private enum DisplayNameAvailabilityState: Equatable {
    case idle
    case checking
    case available
    case taken
    case invalid
    case failed

    var allowsSubmit: Bool {
        switch self {
        case .available, .failed:
            return true
        case .idle, .checking, .taken, .invalid:
            return false
        }
    }
}

private struct PhoneCountryOption: Identifiable, Hashable {
    let id: String
    let code: String
    let localizedName: String
    let dialCode: String

    var menuTitle: String {
        "\(code) \(localizedName) \(dialCode)"
    }

    var compactTitle: String {
        "\(code) \(dialCode)"
    }

    static let all: [PhoneCountryOption] = [
        .init(id: "JP", code: "JPN", localizedName: LT("日本", "Japan", "日本"), dialCode: "+81"),
        .init(id: "CN", code: "CHN", localizedName: LT("中国大陆", "China Mainland", "中国本土"), dialCode: "+86"),
        .init(id: "US", code: "USA", localizedName: LT("美国", "United States", "米国"), dialCode: "+1"),
        .init(id: "CA", code: "CAN", localizedName: LT("加拿大", "Canada", "カナダ"), dialCode: "+1"),
        .init(id: "GB", code: "UK", localizedName: LT("英国", "United Kingdom", "英国"), dialCode: "+44"),
        .init(id: "KR", code: "KOR", localizedName: LT("韩国", "South Korea", "韓国"), dialCode: "+82"),
        .init(id: "SG", code: "SGP", localizedName: LT("新加坡", "Singapore", "シンガポール"), dialCode: "+65"),
        .init(id: "HK", code: "HKG", localizedName: LT("中国香港", "Hong Kong", "香港"), dialCode: "+852"),
        .init(id: "TW", code: "TWN", localizedName: LT("中国台湾", "Taiwan", "台湾"), dialCode: "+886"),
        .init(id: "AU", code: "AUS", localizedName: LT("澳大利亚", "Australia", "オーストラリア"), dialCode: "+61"),
        .init(id: "DE", code: "DEU", localizedName: LT("德国", "Germany", "ドイツ"), dialCode: "+49"),
        .init(id: "FR", code: "FRA", localizedName: LT("法国", "France", "フランス"), dialCode: "+33"),
        .init(id: "IT", code: "ITA", localizedName: LT("意大利", "Italy", "イタリア"), dialCode: "+39"),
        .init(id: "ES", code: "ESP", localizedName: LT("西班牙", "Spain", "スペイン"), dialCode: "+34"),
        .init(id: "NL", code: "NLD", localizedName: LT("荷兰", "Netherlands", "オランダ"), dialCode: "+31"),
    ]

    static let defaultOption: PhoneCountryOption = all[0]
}

private func normalizedPhoneNumber(country: PhoneCountryOption, phoneNumber: String) -> String {
    let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    if trimmed.hasPrefix("+") {
        let digits = trimmed.dropFirst().filter(\.isNumber)
        return digits.isEmpty ? "" : "+\(digits)"
    }
    let localDigits = trimmed.filter(\.isNumber)
    guard !localDigits.isEmpty else { return "" }
    let normalizedLocal = localDigits.hasPrefix("0") ? String(localDigits.dropFirst()) : String(localDigits)
    return "\(country.dialCode)\(normalizedLocal)"
}

private func validatePhoneNumber(country: PhoneCountryOption, phoneNumber: String) -> String? {
    let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return LT("请先输入手机号", "Please enter phone number first.", "電話番号を入力してください。")
    }

    let digits = trimmed.filter(\.isNumber)
    guard !digits.isEmpty else {
        return LT("手机号格式不正确，请只输入数字或带国家区号的号码。", "Invalid phone format. Use digits, optionally with country code.", "電話番号の形式が正しくありません。数字、または国番号付きで入力してください。")
    }

    switch country.id {
    case "CN":
        let localDigits: String
        if trimmed.hasPrefix("+") {
            guard digits.hasPrefix("86") else {
                return LT("中国大陆手机号请使用 +86 开头，或直接输入 11 位手机号。", "China Mainland phone numbers must start with +86 or be 11 local digits.", "中国本土の電話番号は +86 で始めるか、11桁で入力してください。")
            }
            localDigits = String(digits.dropFirst(2))
        } else if digits.hasPrefix("86"), digits.count == 13 {
            localDigits = String(digits.dropFirst(2))
        } else {
            localDigits = String(digits)
        }

        let pattern = #"^1[3-9]\d{9}$"#
        if localDigits.range(of: pattern, options: .regularExpression) == nil {
            return LT("中国大陆手机号应为 11 位，并以 13-19 号段开头，例如 13800138000。", "China Mainland numbers must be 11 digits starting with 13-19, e.g. 13800138000.", "中国本土の電話番号は 13〜19 で始まる11桁です。例: 13800138000")
        }
    case "JP":
        let localDigits: String
        if trimmed.hasPrefix("+") {
            guard digits.hasPrefix("81") else {
                return LT("日本手机号请使用 +81 开头，或直接输入 070/080/090 开头的号码。", "Japan mobile numbers must start with +81 or local 070/080/090.", "日本の携帯番号は +81、または 070/080/090 で入力してください。")
            }
            localDigits = "0" + digits.dropFirst(2)
        } else if digits.hasPrefix("81"), digits.count == 12 {
            localDigits = "0" + digits.dropFirst(2)
        } else {
            localDigits = String(digits)
        }

        let pattern = #"^(070|080|090)\d{8}$"#
        if localDigits.range(of: pattern, options: .regularExpression) == nil {
            return LT("日本手机号应为 070/080/090 开头的 11 位号码，例如 09012345678。", "Japan mobile numbers must be 11 digits starting with 070, 080, or 090, e.g. 09012345678.", "日本の携帯番号は 070/080/090 で始まる11桁です。例: 09012345678")
        }
    default:
        break
    }

    return nil
}

private func isValidEmail(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
    return trimmed.range(of: pattern, options: .regularExpression) != nil
}

private enum DevPhoneAuthBypass {
    static let code = "123456"

    static var isEnabled: Bool {
#if DEBUG
        if let env = ProcessInfo.processInfo.environment["RAVER_DEV_PHONE_AUTH_BYPASS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
            return ["1", "true", "yes", "on"].contains(env)
        }

        return AppConfig.runtimeMode == .mock
#else
        return false
#endif
    }

    static func verificationID(for phoneNumber: String) -> String {
        "dev-phone-auth:\(phoneNumber)"
    }

    static func idToken(for phoneNumber: String) -> String {
        "mock-firebase-phone:\(phoneNumber):ios-dev-register"
    }

    static func matches(verificationID: String, code: String) -> Bool {
        isEnabled
            && verificationID.hasPrefix("dev-phone-auth:")
            && code.trimmingCharacters(in: .whitespacesAndNewlines) == Self.code
    }
}

private func phoneCountryMenu<Background: View>(
    country: Binding<PhoneCountryOption>,
    background: Background,
    accessibilityPrefix: String
) -> some View {
    Menu {
        ForEach(PhoneCountryOption.all) { option in
            Button {
                country.wrappedValue = option
            } label: {
                Text(option.menuTitle)
            }
        }
    } label: {
        HStack(spacing: 6) {
            Text(country.wrappedValue.compactTitle)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white.opacity(0.94))
        .frame(minWidth: 92)
        .padding(.vertical, 14)
        .background(background)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("\(accessibilityPrefix).phoneCountryButton")
}

private func requestFirebasePhoneVerificationID(phoneNumber: String) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            guard let verificationID else {
                continuation.resume(throwing: ServiceError.invalidResponse)
                return
            }
            continuation.resume(returning: verificationID)
        }
    }
}

private struct LoginBackgroundVideoView: UIViewRepresentable {
    let player: AVPlayer

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
    let player = AVPlayer()
    private var shouldPlay = false
    private var appLifecycleObservers: [NSObjectProtocol] = []
    private var videoEndObserver: NSObjectProtocol?

    init() {
        configure()
        observeAppLifecycle()
    }

    deinit {
        appLifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        if let videoEndObserver {
            NotificationCenter.default.removeObserver(videoEndObserver)
        }
    }

    func start() {
        shouldPlay = true
        resumeIfNeeded()
    }

    func stop() {
        shouldPlay = false
        player.pause()
    }

    func resumeIfNeeded() {
        guard shouldPlay else { return }

        if player.currentItem == nil {
            configure()
        }

        player.isMuted = true
        player.play()
    }

    private func configure() {
        if let videoEndObserver {
            NotificationCenter.default.removeObserver(videoEndObserver)
            self.videoEndObserver = nil
        }

        player.isMuted = true
        player.actionAtItemEnd = .none
        player.preventsDisplaySleepDuringVideoPlayback = false

        guard let url = Bundle.main.url(forResource: "login-background-placeholder", withExtension: "mp4") else {
            return
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        videoEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.resumeIfNeeded()
            }
        }
    }

    private func observeAppLifecycle() {
        let notificationCenter = NotificationCenter.default
        let foregroundObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumeIfNeeded()
        }
        let activeObserver = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumeIfNeeded()
        }
        appLifecycleObservers = [foregroundObserver, activeObserver]
    }
}
