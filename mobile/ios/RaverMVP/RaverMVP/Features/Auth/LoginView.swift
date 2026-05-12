import SwiftUI
import AVFoundation
import UIKit
import PhotosUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    @State private var loginMethod: LoginMethod = .account
    @State private var username = "uploadtester"
    @State private var password = ""
    @State private var phoneNumber = ""
    @State private var smsCode = ""
    @State private var isLoading = false
    @State private var smsCooldownSeconds = 0
    @State private var smsCooldownTask: Task<Void, Never>?
    @State private var hasAgreedTerms = false
    @State private var showManualLogin = false
    @State private var showRegistrationProfile = false
    @StateObject private var videoController = LoginBackgroundVideoController()
    @FocusState private var focusedField: ManualAuthField?

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
                                    Text(LL("一键登录"))
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
                            videoController.resumeIfNeeded()
                        } label: {
                            Text(LL("其他手机号登录"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .accessibilityIdentifier("login.showManualButton")

                        Button {
                            openRegistrationProfile()
                        } label: {
                            Text(LL("注册新账号"))
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

            if loginMethod == .sms {
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
                    .submitLabel(.go)
                    .onSubmit {
                        focusedField = .password
                    }
                    .padding(14)
                    .background(inputFieldBackground)
            }

            if loginMethod == .account {
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

            Button {
                openRegistrationProfile()
            } label: {
                HStack(spacing: 6) {
                    Text(LL("还没有账号？注册"))
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
            return !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var submitTitle: String {
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

    private func openRegistrationProfile() {
        focusedField = nil
        dismissKeyboard()
        showRegistrationProfile = true
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

    @State private var email = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedAvatarData: Data?
    @State private var selectedAvatarImage: UIImage?
    @State private var isSubmitting = false

    @FocusState private var focusedField: RegisterField?

    private enum RegisterField {
        case email
        case displayName
        case password
        case confirmPassword
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

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    avatarPicker
                    formFields
                    termsToggle
                    submitButton
                    errorText
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(.white)
        .onChange(of: selectedAvatarItem) { _, newItem in
            Task { await loadSelectedAvatar(newItem) }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("register.backButton")

            VStack(alignment: .leading, spacing: 8) {
                Text(LL("创建账号"))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.98))
                Text(LL("补充头像、昵称和登录信息，完成后即可进入 Raver。"))
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
                    Text(selectedAvatarImage == nil ? LL("上传头像") : LL("更换头像"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.97))
                    Text(LL("上传头像"))
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

    private var formFields: some View {
        VStack(spacing: 12) {
            TextField(text: $email, prompt: registerPlaceholder(LL("邮箱"))) {
                Text(LL("邮箱"))
            }
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .displayName }
                .padding(15)
                .background(fieldBackground)
                .accessibilityIdentifier("register.emailField")

            TextField(text: $displayName, prompt: registerPlaceholder(LL("昵称"))) {
                Text(LL("昵称"))
            }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .displayName)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding(15)
                .background(fieldBackground)
                .accessibilityIdentifier("register.displayNameField")

            Text(LL("昵称全平台唯一，不区分大小写，提交后进入审核。"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .frame(maxWidth: .infinity, alignment: .leading)

            SecureField(text: $password, prompt: registerPlaceholder(L("密码", "Password"))) {
                Text(L("密码", "Password"))
            }
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .confirmPassword }
                .padding(15)
                .background(fieldBackground)
                .accessibilityIdentifier("register.passwordField")

            SecureField(text: $confirmPassword, prompt: registerPlaceholder(LL("确认密码"))) {
                Text(LL("确认密码"))
            }
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                    dismissKeyboard()
                }
                .padding(15)
                .background(fieldBackground)
                .accessibilityIdentifier("register.confirmPasswordField")
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
                Text(LL("我同意《用户服务条款》《用户协议》《隐私政策》"))
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
                    Text(LL("完成注册"))
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

    @ViewBuilder
    private var errorText: some View {
        if let error = appState.errorMessage, !error.isEmpty {
            Text(error)
                .font(.caption)
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("register.errorText")
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
            && password == confirmPassword
            && hasAgreedTerms
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
                appState.errorMessage = L("头像读取失败，请重新选择", "Failed to read avatar. Please choose again.")
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

        let resolvedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !resolvedEmail.isEmpty else {
            appState.errorMessage = LL("请输入邮箱")
            return
        }

        guard !resolvedDisplayName.isEmpty else {
            appState.errorMessage = LL("请输入昵称")
            return
        }

        guard password.count >= 6 else {
            appState.errorMessage = LL("密码至少需要 6 位")
            return
        }

        guard password == confirmPassword else {
            appState.errorMessage = LL("两次输入的密码不一致")
            return
        }

        guard hasAgreedTerms else {
            appState.errorMessage = L("请先勾选并同意用户协议", "Please agree to the user terms first.")
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        await appState.register(
            email: resolvedEmail,
            password: password,
            displayName: resolvedDisplayName
        )

        if appState.errorMessage == nil, let selectedAvatarData {
            do {
                _ = try await appContainer.profileSocialRepository.uploadMyAvatar(
                    imageData: selectedAvatarData,
                    fileName: "avatar-\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
            } catch {
                appState.errorMessage = L("注册成功，但头像上传失败，请稍后在个人主页重试", "Registered, but avatar upload failed. Please retry from your profile later.")
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
            return L("账号", "Account")
        case .sms:
            return L("短信", "SMS")
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
