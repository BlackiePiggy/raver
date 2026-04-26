import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        List {
                // 账号设置
                SwiftUI.Section(L("账号", "Account")) {
                    NavigationLink {
                        SettingsCurrentUserProfileLoaderView(repository: appContainer.profileSocialRepository) { profile in
                            EditProfileView(profile: profile, repository: appContainer.profileSocialRepository) { updated in
                                NotificationCenter.default.post(name: .profileDidUpdate, object: updated)
                            }
                        }
                    } label: {
                        HStack {
                            Label(L("编辑资料", "Edit Profile"), systemImage: "person.circle")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }

                    NavigationLink {
                        Text(L("账号安全", "Account Security"))
                    } label: {
                        Label(L("账号安全", "Account Security"), systemImage: "lock.shield")
                    }

                    NavigationLink {
                        Text(L("隐私设置", "Privacy Settings"))
                    } label: {
                        Label(L("隐私设置", "Privacy Settings"), systemImage: "hand.raised")
                    }
                }

                // 通知设置
                SwiftUI.Section(L("通知", "Notifications")) {
                    NavigationLink {
                        Text(L("推送通知", "Push Notifications"))
                    } label: {
                        Label(L("推送通知", "Push Notifications"), systemImage: "bell")
                    }

                    NavigationLink {
                        Text(L("消息提醒", "Message Alerts"))
                    } label: {
                        Label(L("消息提醒", "Message Alerts"), systemImage: "message")
                    }
                }

                // 内容偏好
                SwiftUI.Section(L("内容偏好", "Content Preferences")) {
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        HStack {
                            Label(L("主题设置", "Appearance"), systemImage: "circle.lefthalf.filled")
                            Spacer()
                            Text(appState.preferredAppearance.title)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }

                    NavigationLink {
                        Text(L("兴趣标签", "Interest Tags"))
                    } label: {
                        Label(L("兴趣标签", "Interest Tags"), systemImage: "tag")
                    }

                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        Label(L("语言设置", "Language"), systemImage: "globe")
                    }

                    NavigationLink {
                        Text(L("内容过滤", "Content Filter"))
                    } label: {
                        Label(L("内容过滤", "Content Filter"), systemImage: "eye.slash")
                    }
                }

                // 数据与存储
                SwiftUI.Section(L("数据与存储", "Data & Storage")) {
                    NavigationLink {
                        Text(L("缓存管理", "Cache Management"))
                    } label: {
                        Label(L("缓存管理", "Cache Management"), systemImage: "externaldrive")
                    }

                    NavigationLink {
                        Text(L("数据使用", "Data Usage"))
                    } label: {
                        Label(L("数据使用", "Data Usage"), systemImage: "chart.bar")
                    }

                    NavigationLink {
                        Text(L("下载设置", "Download Settings"))
                    } label: {
                        Label(L("下载设置", "Download Settings"), systemImage: "arrow.down.circle")
                    }
                }

                // 关于
                SwiftUI.Section(L("关于", "About")) {
                    NavigationLink {
                        Text(L("帮助中心", "Help Center"))
                    } label: {
                        Label(L("帮助中心", "Help Center"), systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        Text(L("服务条款", "Terms of Service"))
                    } label: {
                        Label(L("服务条款", "Terms of Service"), systemImage: "doc.text")
                    }

                    NavigationLink {
                        Text(L("隐私政策", "Privacy Policy"))
                    } label: {
                        Label(L("隐私政策", "Privacy Policy"), systemImage: "hand.raised.shield")
                    }

                    NavigationLink {
                        Text(L("关于我们", "About Us"))
                    } label: {
                        Label(L("关于我们", "About Us"), systemImage: "info.circle")
                    }

                    HStack {
                        Text(L("版本", "Version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                // 账号操作
                SwiftUI.Section {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Label(L("退出登录", "Log Out"), systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RaverTheme.background)
            .raverSystemNavigation(title: L("设置", "Settings"))
    }
}

private struct LanguageSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            SwiftUI.Section(L("显示语言", "Display Language")) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        appState.setPreferredLanguage(language)
                    } label: {
                        HStack {
                            Text(language.title)
                            Spacer()
                            if appState.preferredLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(RaverTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("语言设置", "Language"))
    }
}

private struct ThemeSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            SwiftUI.Section(L("显示主题", "Appearance")) {
                ForEach(AppAppearance.allCases) { appearance in
                    Button {
                        appState.setPreferredAppearance(appearance)
                    } label: {
                        HStack {
                            Text(appearance.title)
                            Spacer()
                            if appState.preferredAppearance == appearance {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(RaverTheme.accent)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("主题设置", "Appearance"))
    }
}

private struct SettingsCurrentUserProfileLoaderView<Content: View>: View {
    let repository: ProfileSocialRepository
    let content: (UserProfile) -> Content

    @State private var profile: UserProfile?
    @State private var errorMessage: String?

    init(
        repository: ProfileSocialRepository,
        @ViewBuilder content: @escaping (UserProfile) -> Content
    ) {
        self.repository = repository
        self.content = content
    }

    var body: some View {
        Group {
            if let profile {
                content(profile)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                    Button(L("重试", "Retry")) {
                        Task { await loadProfile(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(L("加载中...", "Loading..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            }
        }
        .task {
            await loadProfile(force: false)
        }
    }

    @MainActor
    private func loadProfile(force: Bool) async {
        if profile != nil && !force { return }
        do {
            profile = try await repository.fetchMyProfile()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
