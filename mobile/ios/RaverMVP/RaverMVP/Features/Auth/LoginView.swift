import SwiftUI
import AVFoundation
import FirebaseAuth
import UIKit
import PhotosUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    private let onContinueBrowsing: (() -> Void)?

    @State private var loginMethod: LoginMethod = .account
    @State private var username = "uploadtester"
    @State private var password = ""
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
    @State private var showTermsRequiredAlert = false
    @StateObject private var videoController = LoginBackgroundVideoController()
    @FocusState private var focusedField: ManualAuthField?

    init(onContinueBrowsing: (() -> Void)? = nil) {
        self.onContinueBrowsing = onContinueBrowsing
    }

    private enum ManualAuthField {
        case username
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
                                Text(LT("我同意《用户服务条款》《用户协议》《隐私政策》", "I agree to the User Terms of Service, User Agreement, and Privacy Policy", "利用規約、ユーザー契約、プライバシーポリシーに同意します"))
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
                                    Text(LT("一键登录", "One-Tap Sign In", "ワンタップでログイン"))
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
                            guard hasAgreedTerms else {
                                showTermsRequiredAlert = true
                                return
                            }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                showManualLogin.toggle()
                            }
                            videoController.resumeIfNeeded()
                        } label: {
                            Text(LT("其他手机号登录", "Use Another Phone Number", "別の電話番号でログイン"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
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
                        }
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        Text(LT("— 其他登录方式 —", "- Other sign-in methods -", "- その他のログイン方法 -"))
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
            videoController.start()
        }
        .onDisappear {
            videoController.stop()
            smsCooldownTask?.cancel()
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
        .alert(
            LT("请先同意用户条款", "Please Agree to the Terms", "利用規約に同意してください"),
            isPresented: $showTermsRequiredAlert
        ) {
            Button(LT("知道了", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(LT("选择其他手机号登录前，需要先勾选并同意用户服务条款、用户协议和隐私政策。", "Please check and agree to the user terms, user agreement, and privacy policy before using another phone number.", "別の電話番号でログインする前に、利用規約、ユーザー契約、プライバシーポリシーに同意してください。"))
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

            if loginMethod == .sms {
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
        switch loginMethod {
        case .account:
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
        case .sms:
            return !normalizedPhoneNumber(country: selectedPhoneCountry, phoneNumber: phoneNumber).isEmpty
                && !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var submitTitle: String {
        switch loginMethod {
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
            appState.errorMessage = LT("第三方登录即将开放，先使用账号登录", "Third-party login is coming soon. Please use account login for now.", "外部ログインは準備中です。先にアカウントログインをご利用ください。")
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
        showRegistrationProfile = true
    }

    private func continueBrowsing() {
        focusedField = nil
        dismissKeyboard()
        if let onContinueBrowsing {
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
            appState.errorMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }

        let normalizedPhone = normalizedPhoneNumber(country: selectedPhoneCountry, phoneNumber: phoneNumber)
        guard !normalizedPhone.isEmpty else {
            appState.errorMessage = LT("请先输入手机号", "Please enter phone number first.", "電話番号を入力してください。")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            firebaseVerificationID = try await sendFirebasePhoneCode(phoneNumber: normalizedPhone)
            appState.errorMessage = nil
        } catch {
            appState.errorMessage = error.userFacingMessage
            return
        }
        let countdown = 60
        startSmsCooldown(seconds: countdown)
    }

    private func submitAuth(oneTap: Bool) async {
        guard !isLoading else { return }
        if !hasAgreedTerms {
            appState.errorMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }

        isLoading = true
        defer { isLoading = false }

        if loginMethod == .sms {
            await submitFirebasePhoneAuth()
            return
        }

        await appState.login(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }

    private func sendFirebasePhoneCode(phoneNumber: String) async throws -> String {
        try await requestFirebasePhoneVerificationID(phoneNumber: phoneNumber)
    }

    private func submitFirebasePhoneAuth() async {
        let verificationID = firebaseVerificationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = smsCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !verificationID.isEmpty else {
            appState.errorMessage = LT("请先发送验证码", "Please send a verification code first.", "先に認証コードを送信してください。")
            return
        }
        guard !code.isEmpty else {
            appState.errorMessage = LT("请输入验证码", "Please enter the verification code.", "認証コードを入力してください。")
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
        } catch {
            appState.errorMessage = error.userFacingMessage
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

private struct RegisterProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Binding var hasAgreedTerms: Bool

    @State private var currentPage: RegisterPage = .phoneVerification
    @State private var selectedPhoneCountry = PhoneCountryOption.defaultOption
    @State private var phoneNumber = ""
    @State private var smsCode = ""
    @State private var firebaseVerificationID = ""
    @State private var verifiedFirebasePhoneIDToken = ""
    @State private var smsCooldownSeconds = 0
    @State private var smsCooldownTask: Task<Void, Never>?
    @State private var displayName = ""
    @State private var selectedBirthDate = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: Calendar(identifier: .gregorian).component(.year, from: Date()) - 18, month: 1, day: 1)
    ) ?? Date()
    @State private var displayNameAvailability: DisplayNameAvailabilityState = .idle
    @State private var displayNameAvailabilityTask: Task<Void, Never>?
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedAvatarData: Data?
    @State private var selectedAvatarImage: UIImage?
    @State private var isSubmitting = false
    @State private var registrationErrorMessage: String?

    @FocusState private var focusedField: RegisterField?

    private enum RegisterField {
        case phoneNumber
        case smsCode
        case displayName
    }

    private enum RegisterPage {
        case phoneVerification
        case profile
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
                    phoneVerificationPage
                        .frame(width: proxy.size.width, height: proxy.size.height)

                    profilePage
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .offset(x: currentPage == .phoneVerification ? 0 : -proxy.size.width)
                .animation(.interactiveSpring(response: 0.36, dampingFraction: 0.88), value: currentPage)
                .clipped()
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

    private var phoneVerificationPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                phoneVerificationHeader
                phoneVerificationFields
                termsToggle
                phoneVerificationButton
                errorText
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
                errorText
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var phoneVerificationHeader: some View {
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
                Text(LT("验证手机号", "Verify Phone", "電話番号を確認"))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.98))
                Text(LT("先完成手机号验证，下一步再补充头像和昵称。", "Verify your phone first, then add your avatar and nickname.", "先に電話番号を確認し、次にアイコンとニックネームを入力します。"))
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
                Text(LT("手机号已验证，请补充头像、昵称和年龄信息。", "Phone verified. Add your avatar, nickname, and age details.", "電話番号を確認しました。アイコン、ニックネーム、年齢情報を入力してください。"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

    private var phoneVerificationFields: some View {
        VStack(spacing: 12) {
            registerPhoneNumberInput(
                country: $selectedPhoneCountry,
                phoneNumber: $phoneNumber,
                accessibilityPrefix: "register"
            )

            HStack(spacing: 10) {
                TextField(text: $smsCode, prompt: registerPlaceholder(LT("验证码", "Verification Code", "認証コード"))) {
                    Text(LT("验证码", "Verification Code", "認証コード"))
                }
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .smsCode)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                    dismissKeyboard()
                }
                .padding(15)
                .background(fieldBackground)
                .accessibilityIdentifier("register.smsCodeField")

                Button {
                    Task { await sendRegisterSmsCode() }
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
                .disabled(isSubmitting || smsCooldownSeconds > 0 || normalizedRegisterPhoneNumber.isEmpty)
                .accessibilityIdentifier("register.sendSmsCodeButton")
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
                LT("出生年月日", "Date of Birth", "生年月日"),
                selection: $selectedBirthDate,
                in: birthDateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .padding(15)
            .background(fieldBackground)
            .accessibilityIdentifier("register.birthDatePicker")

            Text(LT("出生年月日仅用于年龄分级和未成年人安全保护。", "Date of birth is used only for age rating and minor safety protections.", "生年月日は年齢区分と未成年者保護のためにのみ使用されます。"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("register.agreeTermsButton")
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

    private var phoneVerificationButton: some View {
        Button {
            Task { await verifyRegisterPhoneAndContinue() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canVerifyPhone ? Color.white.opacity(0.92) : Color.white.opacity(0.22))
                if isSubmitting {
                    ProgressView().tint(.black)
                } else {
                    Text(LT("验证并继续", "Verify and Continue", "確認して続行"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(canVerifyPhone ? Color.black.opacity(0.88) : Color.white.opacity(0.56))
                }
            }
            .frame(height: 54)
        }
        .buttonStyle(.plain)
        .disabled(!canVerifyPhone || isSubmitting)
        .accessibilityIdentifier("register.verifyPhoneButton")
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = registrationErrorMessage, !error.isEmpty {
            Text(error)
                .font(.caption)
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("register.errorText")
        }
    }

    private var canSubmit: Bool {
        currentPage == .profile
            && !verifiedFirebasePhoneIDToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && displayNameAvailability.allowsSubmit
            && hasAgreedTerms
            && isAgeDeclarationAcceptable
    }

    private var canVerifyPhone: Bool {
        !normalizedRegisterPhoneNumber.isEmpty
            && !firebaseVerificationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hasAgreedTerms
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

    private var normalizedRegisterPhoneNumber: String {
        normalizedPhoneNumber(country: selectedPhoneCountry, phoneNumber: phoneNumber)
    }

    private var registerPhoneValidationError: String? {
        validatePhoneNumber(country: selectedPhoneCountry, phoneNumber: phoneNumber)
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

    private func registerPhoneNumberInput(
        country: Binding<PhoneCountryOption>,
        phoneNumber: Binding<String>,
        accessibilityPrefix: String
    ) -> some View {
        HStack(spacing: 10) {
            phoneCountryMenu(country: country, background: fieldBackground, accessibilityPrefix: accessibilityPrefix)

            TextField(text: phoneNumber, prompt: registerPlaceholder(LT("手机号", "Phone Number", "電話番号"))) {
                Text(LT("手机号", "Phone Number", "電話番号"))
            }
            .keyboardType(.phonePad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .phoneNumber)
            .submitLabel(.next)
            .onSubmit { focusedField = .smsCode }
            .padding(15)
            .background(fieldBackground)
            .accessibilityIdentifier("\(accessibilityPrefix).phoneNumberField")
        }
    }

    private func registerPlaceholder(_ title: String) -> Text {
        Text(title).foregroundColor(.white.opacity(0.82))
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

    private func sendRegisterSmsCode() async {
        guard !isSubmitting else { return }
        guard hasAgreedTerms else {
            registrationErrorMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }
        if let validationError = registerPhoneValidationError {
            registrationErrorMessage = validationError
            return
        }
        guard !normalizedRegisterPhoneNumber.isEmpty else {
            registrationErrorMessage = LT("请先输入手机号", "Please enter phone number first.", "電話番号を入力してください。")
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        if DevPhoneAuthBypass.isEnabled {
            firebaseVerificationID = DevPhoneAuthBypass.verificationID(for: normalizedRegisterPhoneNumber)
            smsCode = DevPhoneAuthBypass.code
            registrationErrorMessage = nil
            startSmsCooldown(seconds: 10)
            return
        }

        do {
            firebaseVerificationID = try await requestFirebasePhoneVerificationID(phoneNumber: normalizedRegisterPhoneNumber)
            registrationErrorMessage = nil
            startSmsCooldown(seconds: 60)
        } catch {
            registrationErrorMessage = error.userFacingMessage
        }
    }

    private func verifyRegisterPhoneAndContinue() async {
        guard !isSubmitting else { return }
        guard hasAgreedTerms else {
            registrationErrorMessage = LT("请先勾选并同意用户协议", "Please agree to the user terms first.", "先に利用規約への同意にチェックしてください。")
            return
        }
        if let validationError = registerPhoneValidationError {
            registrationErrorMessage = validationError
            return
        }
        guard !normalizedRegisterPhoneNumber.isEmpty else {
            registrationErrorMessage = LT("请先输入手机号", "Please enter phone number first.", "電話番号を入力してください。")
            return
        }

        let verificationID = firebaseVerificationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = smsCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !verificationID.isEmpty else {
            registrationErrorMessage = LT("请先发送验证码", "Please send a verification code first.", "先に認証コードを送信してください。")
            return
        }
        guard !code.isEmpty else {
            registrationErrorMessage = LT("请输入验证码", "Please enter the verification code.", "認証コードを入力してください。")
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        if DevPhoneAuthBypass.matches(verificationID: verificationID, code: code) {
            verifiedFirebasePhoneIDToken = DevPhoneAuthBypass.idToken(for: normalizedRegisterPhoneNumber)
            registrationErrorMessage = nil
            focusedField = nil
            dismissKeyboard()
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
                currentPage = .profile
            }
            return
        }

        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: code
            )
            let result = try await Auth.auth().signIn(with: credential)
            verifiedFirebasePhoneIDToken = try await result.user.getIDToken()
            registrationErrorMessage = nil
            focusedField = nil
            dismissKeyboard()
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
                currentPage = .profile
            }
        } catch {
            registrationErrorMessage = error.userFacingMessage
        }
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
            let resized = image.resizedForRegistrationAvatar(maxPixel: 1024),
            let jpegData = resized.jpegData(compressionQuality: 0.86)
        else {
            return data
        }
        return jpegData
    }

    private func submitRegistration() async {
        guard !isSubmitting else { return }

        let resolvedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        let idToken = verifiedFirebasePhoneIDToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !idToken.isEmpty else {
            registrationErrorMessage = LT("请先完成手机号验证", "Please verify your phone number first.", "先に電話番号認証を完了してください。")
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
            try await appState.loginWithFirebasePhoneIdTokenOrThrow(
                idToken,
                birthYear: birthYear,
                regionCode: regionCode,
                displayName: resolvedDisplayName
            )
        } catch {
            registrationErrorMessage = error.userFacingMessage
            return
        }

        registrationErrorMessage = nil

        if let selectedAvatarData {
            do {
                let uploaded = try await appContainer.profileUserRepository.uploadMyAvatar(
                    imageData: selectedAvatarData,
                    fileName: "avatar-\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
                appState.updateCurrentUserAvatarURL(uploaded.avatarURL)
                if let updatedProfile = try? await appContainer.profileUserRepository.fetchMyProfile() {
                    appState.applyCurrentUserProfile(updatedProfile)
                    NotificationCenter.default.post(name: .profileDidUpdate, object: updatedProfile)
                }
            } catch {
                registrationErrorMessage = LT("注册成功，但头像上传失败，请稍后在个人主页重试", "Registered, but avatar upload failed. Please retry from your profile later.", "登録は完了しましたが、アイコンのアップロードに失敗しました。後ほどプロフィールから再試行してください。")
            }
        }
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
    case account
    case sms

    var title: String {
        switch self {
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
