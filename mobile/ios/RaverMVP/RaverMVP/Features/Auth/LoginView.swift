import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    @State private var mode: AuthMode = .login
    @State private var username = "blackie"
    @State private var email = ""
    @State private var displayName = ""
    @State private var password = "123456"
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            Text("Raver")
                .font(.system(size: 42, weight: .bold, design: .rounded))
            Text("Mastodon + Matrix + SwiftUI MVP")
                .foregroundStyle(RaverTheme.secondaryText)

            VStack(spacing: 12) {
                Picker("模式", selection: $mode) {
                    ForEach(AuthMode.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                TextField("用户名", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if mode == .register {
                    TextField("邮箱", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("显示名（可选）", text: $displayName)
                        .padding(14)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                SecureField("密码", text: $password)
                    .padding(14)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    isLoading = true
                    Task {
                        if mode == .login {
                            await appState.login(username: username, password: password)
                        } else {
                            await appState.register(
                                username: username,
                                email: email,
                                password: password,
                                displayName: displayName
                            )
                        }
                        isLoading = false
                    }
                } label: {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .login ? "登录" : "注册并登录")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(
                    username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        password.isEmpty ||
                        (mode == .register && email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                        isLoading
                )

                Text("默认 Mock 模式。设置 `RAVER_USE_MOCK=0` 后会请求你的 BFF。")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            Spacer()
        }
        .padding(24)
        .foregroundStyle(RaverTheme.primaryText)
    }
}

private enum AuthMode: String, CaseIterable {
    case login
    case register

    var title: String {
        switch self {
        case .login: return "登录"
        case .register: return "注册"
        }
    }
}
