import SwiftUI
import AVFoundation
import CoreLocation
import Foundation
import Photos
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    private var realNameEnforcementBinding: Binding<Bool> {
        Binding(
            get: { AppConfig.isRealNameEnforcementEnabled },
            set: { AppConfig.setRealNameEnforcementEnabled($0) }
        )
    }

    private var virtualAssetsEnabledBinding: Binding<Bool> {
        Binding(
            get: { AppConfig.virtualAssetsEnabled },
            set: { AppConfig.setVirtualAssetsEnabled($0) }
        )
    }

    var body: some View {
        List {
                // 账号设置
                Section(LT("账号", "Account", "アカウント")) {
                    NavigationLink {
                        SettingsCurrentUserProfileLoaderView(repository: appContainer.profileUserRepository) { profile in
                            EditProfileView(profile: profile, repository: appContainer.profileUserRepository) { updated in
                                NotificationCenter.default.post(name: .profileDidUpdate, object: updated)
                            }
                        }
                    } label: {
                        HStack {
                            Label(LT("编辑资料", "Edit Profile", "プロフィールを編集"), systemImage: "person.circle")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }

                    NavigationLink {
                        AccountSecuritySettingsView()
                    } label: {
                        Label(LT("账号安全", "Account Security", "アカウントの安全"), systemImage: "lock.shield")
                    }

                    NavigationLink {
                        LoginDevicesSettingsView()
                    } label: {
                        Label(LT("登录设备", "Login Devices", "ログイン端末"), systemImage: "desktopcomputer.and.iphone")
                    }

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label(LT("隐私设置", "Privacy Settings", "プライバシー設定"), systemImage: "hand.raised")
                    }

                    NavigationLink {
                        PermissionStatusSettingsView()
                    } label: {
                        Label(LT("权限管理", "Permissions", "権限管理"), systemImage: "switch.2")
                    }
                }

                // 通知设置
                Section(LT("通知", "Notifications", "通知")) {
                    NavigationLink {
                        PushNotificationSettingsView()
                    } label: {
                        Label(LT("推送通知", "Push Notifications", "プッシュ通知"), systemImage: "bell")
                    }

                    NavigationLink {
                        NotificationCategoryPreferencesView(service: appContainer.socialService)
                    } label: {
                        Label(LT("消息提醒", "Message Alerts", "メッセージ通知"), systemImage: "message")
                    }
                }

                // 内容偏好
                Section(LT("内容偏好", "Content Preferences", "コンテンツ設定")) {
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        HStack {
                            Label(LT("主题设置", "Appearance", "テーマ設定"), systemImage: "circle.lefthalf.filled")
                            Spacer()
                            Text(appState.preferredAppearance.title)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }

                    NavigationLink {
                        Text(LT("兴趣标签", "Interest Tags", "興味タグ"))
                    } label: {
                        Label(LT("兴趣标签", "Interest Tags", "興味タグ"), systemImage: "tag")
                    }

                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        Label(LT("语言设置", "Language", "言語設定"), systemImage: "globe")
                    }

                    NavigationLink {
                        Text(LT("内容过滤", "Content Filter", "コンテンツフィルター"))
                    } label: {
                        Label(LT("内容过滤", "Content Filter", "コンテンツフィルター"), systemImage: "eye.slash")
                    }
                }

                // 数据与存储
                Section(LT("数据与存储", "Data & Storage", "データとストレージ")) {
                    NavigationLink {
                        Text(LT("缓存管理", "Cache Management", "キャッシュ管理"))
                    } label: {
                        Label(LT("缓存管理", "Cache Management", "キャッシュ管理"), systemImage: "externaldrive")
                    }

                    NavigationLink {
                        Text(LT("数据使用", "Data Usage", "データ使用量"))
                    } label: {
                        Label(LT("数据使用", "Data Usage", "データ使用量"), systemImage: "chart.bar")
                    }

                    NavigationLink {
                        Text(LT("下载设置", "Download Settings", "ダウンロード設定"))
                    } label: {
                        Label(LT("下载设置", "Download Settings", "ダウンロード設定"), systemImage: "arrow.down.circle")
                    }
                }

#if DEBUG
                Section(LT("开发", "Development", "Development")) {
                    Toggle(isOn: realNameEnforcementBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(LT("实名认证限制", "Real-name verification limits", "本人確認制限"), systemImage: "person.text.rectangle")
                            Text(LT("关闭后，开发环境会绕过实名认证拦截；开启后恢复真实限制。", "Turn this off to bypass real-name verification in development. Turn it on to restore the real limits.", "オフにすると開発環境では本人確認の制限を回避します。オンにすると実際の制限に戻ります。"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }

                    Toggle(isOn: virtualAssetsEnabledBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(LT("虚拟资产装扮", "Virtual asset styling", "バーチャルアイテム装飾"), systemImage: "sparkles")
                            Text(LT("重启 App 后生效；关闭后装扮入口和展示会回退为普通头像/昵称。", "Takes effect after restarting the app. When off, styling entries and displays fall back to the normal avatar and nickname.", "App 再起動後に反映されます。オフにすると装飾入口と表示は通常のアイコン/ニックネームに戻ります。"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                }
#endif

                // 关于
                Section(LT("关于", "About", "情報")) {
                    NavigationLink {
                        Text(LT("帮助中心", "Help Center", "ヘルプセンター"))
                    } label: {
                        Label(LT("帮助中心", "Help Center", "ヘルプセンター"), systemImage: "questionmark.circle")
                    }

                    Link(destination: URL(string: "https://raver.app/legal/terms")!) {
                        Label(LT("服务条款", "Terms of Service", "利用規約"), systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://raver.app/legal/privacy")!) {
                        Label(LT("隐私政策", "Privacy Policy", "プライバシーポリシー"), systemImage: "hand.raised.shield")
                    }

                    Link(destination: URL(string: "https://raver.app/legal/data-requests")!) {
                        Label(LT("数据请求", "Data Requests", "データリクエスト"), systemImage: "tray.and.arrow.down")
                    }

                    NavigationLink {
                        Text(LT("关于我们", "About Us", "Raver について"))
                    } label: {
                        Label(LT("关于我们", "About Us", "Raver について"), systemImage: "info.circle")
                    }

                    HStack {
                        Text(LT("版本", "Version", "バージョン"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                // 账号操作
                Section {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Label(LT("退出登录", "Log Out", "ログアウト"), systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RaverTheme.background)
            .raverSystemNavigation(title: LT("设置", "Settings", "設定"))
    }
}

private struct LoginDevicesSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    @State private var sessions: [AuthSessionItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var revokingSessionID: String?
    @State private var isLoggingOutAll = false
    @State private var isShowingLogoutAllConfirmation = false

    var body: some View {
        List {
            Section {
                if sessions.isEmpty && !isLoading {
                    Text(LT("暂无登录设备。", "No login devices yet.", "ログイン端末はありません。"))
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(sessions) { item in
                        sessionRow(item)
                    }
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } header: {
                Text(LT("当前账号", "Current Account", "現在のアカウント"))
            } footer: {
                Text(LT("撤销设备后，该设备下次刷新登录状态时会退出。", "After revoking a device, it will be signed out the next time it refreshes its session.", "端末を取り消すと、次回セッション更新時にログアウトされます。"))
            }

            Section {
                Button(role: .destructive) {
                    isShowingLogoutAllConfirmation = true
                } label: {
                    HStack {
                        Label(LT("退出全部设备", "Log Out All Devices", "すべての端末からログアウト"), systemImage: "rectangle.stack.badge.minus")
                        Spacer()
                        if isLoggingOutAll {
                            ProgressView()
                        }
                    }
                }
                .disabled(isLoggingOutAll)
            } footer: {
                Text(LT("包括当前设备。完成后需要重新登录。", "This includes the current device. You will need to log in again.", "現在の端末も含まれます。完了後は再ログインが必要です。"))
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("登录设备", "Login Devices", "ログイン端末"))
        .task {
            await loadSessions()
        }
        .refreshable {
            await loadSessions()
        }
        .confirmationDialog(
            LT("退出全部设备", "Log Out All Devices", "すべての端末からログアウト"),
            isPresented: $isShowingLogoutAllConfirmation,
            titleVisibility: .visible
        ) {
            Button(LT("确认退出全部设备", "Log Out All Devices", "すべてログアウト"), role: .destructive) {
                Task { await logoutAllDevices() }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(LT("所有设备都会退出登录，包括当前设备。", "All devices will be signed out, including this one.", "現在の端末を含むすべての端末からログアウトします。"))
        }
    }

    private func sessionRow(_ item: AuthSessionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName(for: item))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(item.isActive ? RaverTheme.primaryText : RaverTheme.secondaryText)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(displayName(for: item))
                            .font(.subheadline.weight(.semibold))
                        if item.isCurrent {
                            Text(LT("当前设备", "Current", "現在"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(RaverTheme.accent.opacity(0.16)))
                                .foregroundStyle(RaverTheme.accent)
                        }
                        if !item.isActive {
                            Text(LT("已撤销", "Revoked", "取り消し済み"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.red.opacity(0.14)))
                                .foregroundStyle(.red)
                        }
                    }

                    Text(detailText(for: item))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    Text(LT("最近活跃", "Last Active", "最終利用") + ": " + formatDate(item.lastUsedAt ?? item.createdAt))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            if item.isActive {
                Button(role: item.isCurrent ? .destructive : nil) {
                    Task { await revoke(item) }
                } label: {
                    HStack {
                        Text(item.isCurrent ? LT("退出当前设备", "Log Out This Device", "この端末からログアウト") : LT("撤销此设备", "Revoke Device", "この端末を取り消す"))
                        if revokingSessionID == item.id {
                            ProgressView()
                        }
                    }
                }
                .disabled(revokingSessionID != nil)
            }
        }
        .padding(.vertical, 6)
    }

    private func loadSessions() async {
        guard appState.session != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await appContainer.socialService.fetchAuthSessions()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? LT("加载登录设备失败。", "Failed to load login devices.", "ログイン端末の読み込みに失敗しました。")
        }
    }

    private func revoke(_ item: AuthSessionItem) async {
        guard revokingSessionID == nil else { return }
        revokingSessionID = item.id
        defer { revokingSessionID = nil }
        do {
            let result = try await appContainer.socialService.revokeAuthSession(sessionID: item.id)
            errorMessage = nil
            if result.revokedCurrent {
                NotificationCenter.default.post(name: .raverSessionExpired, object: SessionExpirationReason.revoked)
                return
            }
            await loadSessions()
        } catch {
            errorMessage = error.userFacingMessage ?? LT("撤销设备失败。", "Failed to revoke device.", "端末の取り消しに失敗しました。")
        }
    }

    private func logoutAllDevices() async {
        guard !isLoggingOutAll else { return }
        isLoggingOutAll = true
        defer { isLoggingOutAll = false }
        let ok = await appState.logoutAllDevices()
        if !ok {
            errorMessage = appState.errorMessage
        }
    }

    private func displayName(for item: AuthSessionItem) -> String {
        let name = item.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        if item.clientType == "web_admin" { return LT("Web 后台", "Web Admin", "Web 管理") }
        if item.platform == "ios" { return "iPhone" }
        return item.clientType
    }

    private func detailText(for item: AuthSessionItem) -> String {
        [
            item.platform?.uppercased(),
            item.appVersion.map { "v\($0)" },
            item.ipAddressMasked,
        ]
        .compactMap { $0?.nilIfBlank }
        .joined(separator: " · ")
    }

    private func iconName(for item: AuthSessionItem) -> String {
        if item.platform == "ios" || item.clientType == "ios" {
            return "iphone"
        }
        if item.platform == "web" || item.clientType == "web_admin" || item.clientType == "web_public" {
            return "desktopcomputer"
        }
        return "questionmark.square"
    }

    private func formatDate(_ date: Date) -> String {
        Self.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct PrivacySettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appPush) private var appPush
    @State private var reports: [ContentReport] = []
    @State private var blockedUsers: [UserBlockListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var unblockingUserID: String?

    var body: some View {
        List {
            Section {
                if reports.isEmpty && !isLoading {
                    Text(LT("暂无举报记录。", "No reports yet.", "通報履歴はありません。"))
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(reports) { report in
                        reportRow(report)
                    }
                }
            } header: {
                Text(LT("我的举报记录", "My Reports", "自分の通報履歴"))
            } footer: {
                Text(LT("重复举报同一对象会更新补充说明，不会无限创建重复记录。", "Reporting the same item again updates the details instead of creating duplicate records.", "同じ対象を再度通報すると補足内容が更新され、重複記録は作成されません。"))
            }

            Section {
                if blockedUsers.isEmpty && !isLoading {
                    Text(LT("暂无拉黑用户。", "No blocked users.", "ブロック中のユーザーはいません。"))
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(blockedUsers) { item in
                        blockedUserRow(item)
                    }
                }
            } header: {
                Text(LT("拉黑列表", "Blocked Users", "ブロックリスト"))
            } footer: {
                Text(LT("解除拉黑后，对方可能重新通过私信或互动与你接触。", "After unblocking, the user may be able to contact or interact with you again.", "ブロックを解除すると、相手が再びメッセージや交流で接触できる場合があります。"))
            }

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("隐私设置", "Privacy Settings", "プライバシー設定"))
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func reportRow(_ report: ContentReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "flag")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.targetUser?.displayName ?? report.targetTypeTitle)
                        .font(.subheadline.weight(.semibold))
                    Text("\(report.targetTypeTitle) · \(report.reasonTitle)")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                Spacer()
                Text(report.statusTitle)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(report.status).opacity(0.14))
                    .foregroundStyle(statusColor(report.status))
                    .clipShape(Capsule())
            }

            if let detail = report.detail?.nilIfBlank {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(3)
            }

            if let note = report.resolutionNote?.nilIfBlank {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(3)
            }

            Text(Self.formatDate(report.updatedAt ?? report.createdAt))
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private func blockedUserRow(_ item: UserBlockListItem) -> some View {
        HStack(spacing: 12) {
            Button {
                appPush(.userProfile(userID: item.user.id))
            } label: {
                HStack(spacing: 10) {
                    userAvatar(item.user, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.user.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text("@\(item.user.username)")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(role: .destructive) {
                Task { await unblock(item) }
            } label: {
                if unblockingUserID == item.user.id {
                    ProgressView()
                } else {
                    Text(LT("解除", "Unblock", "解除"))
                }
            }
            .disabled(unblockingUserID != nil)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func userAvatar(_ user: UserSummary, size: CGFloat) -> some View {
        if let avatarURL = user.avatarURL?.nilIfBlank {
            ImageLoaderView(urlString: avatarURL)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.cardBorder)
                .frame(width: size, height: size)
                .overlay(
                    Text(String(user.displayName.prefix(1)).uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        }
    }

    @MainActor
    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let reportsTask = appState.service.fetchMyContentReports(limit: 50)
            async let blocksTask = appState.service.fetchBlockedUsers(limit: 100)
            reports = try await reportsTask
            blockedUsers = try await blocksTask
        } catch {
            errorMessage = error.userFacingMessage ?? LT("隐私设置加载失败，请稍后重试。", "Failed to load privacy settings. Please try again.", "プライバシー設定の読み込みに失敗しました。後でもう一度お試しください。")
        }
    }

    @MainActor
    private func unblock(_ item: UserBlockListItem) async {
        guard unblockingUserID == nil else { return }
        unblockingUserID = item.user.id
        defer { unblockingUserID = nil }
        do {
            _ = try await appState.service.unblockUser(userID: item.user.id)
            blockedUsers.removeAll { $0.user.id == item.user.id }
            OperationBannerCenter.shared.success(LT("已解除拉黑", "User unblocked", "ブロックを解除しました"))
        } catch {
            errorMessage = error.userFacingMessage ?? LT("解除拉黑失败，请稍后重试。", "Failed to unblock. Please try again.", "ブロック解除に失敗しました。後でもう一度お試しください。")
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "pending", "reviewing", "in_review":
            return .orange
        case "resolved", "accepted":
            return .green
        case "rejected", "closed":
            return RaverTheme.secondaryText
        default:
            return RaverTheme.accent
        }
    }

    private static func formatDate(_ date: Date) -> String {
        date.appLocalizedYMDHMText()
    }
}

@MainActor
private final class PushNotificationSettingsModel: ObservableObject {
    @Published private(set) var statusTitle = LT("正在检查", "Checking", "確認中")
    @Published private(set) var statusDescription = LT("正在读取系统通知权限状态。", "Reading system notification permission status.", "システム通知の権限状態を読み取っています。")
    @Published private(set) var canRequestPermission = false
    @Published private(set) var canOpenSystemSettings = false
    @Published var isRequesting = false

    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.apply(settings.authorizationStatus)
            }
        }
    }

    func requestPermission() {
        guard !isRequesting else { return }
        isRequesting = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.isRequesting = false
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                self?.refresh()
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func apply(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            statusTitle = LT("尚未开启", "Not Enabled Yet", "まだ有効ではありません")
            statusDescription = LT("开启后，Raver 会发送私信、互动、活动、审核/处罚/申诉等重要提醒；拒绝后仍可在站内通知查看。", "If enabled, Raver can send important alerts for messages, interactions, events, moderation, enforcement, and appeals. If declined, in-app notifications still remain available.", "有効にすると、Raver はメッセージ、交流、イベント、審査/処分/異議申し立てなどの重要なお知らせを送信できます。拒否してもアプリ内通知で確認できます。")
            canRequestPermission = true
            canOpenSystemSettings = false
        case .denied:
            statusTitle = LT("系统通知已关闭", "System Notifications Off", "システム通知がオフです")
            statusDescription = LT("你仍可在 App 内通知中心查看消息。若要接收系统推送，请前往 iOS 设置重新开启。", "You can still read notifications inside the app. To receive system push alerts, enable notifications again in iOS Settings.", "通知はアプリ内通知センターで確認できます。システムプッシュを受け取るには iOS 設定で再度有効にしてください。")
            canRequestPermission = false
            canOpenSystemSettings = true
        case .authorized:
            statusTitle = LT("已开启", "Enabled", "有効")
            statusDescription = LT("系统推送已开启。你仍可在后续通知偏好中细分私信、互动、活动和营销提醒。", "System push notifications are enabled. More granular preferences for messages, interactions, events, and marketing can be managed in future notification preferences.", "システムプッシュは有効です。通知設定でメッセージ、交流、イベント、マーケティング通知をさらに細かく管理できます。")
            canRequestPermission = false
            canOpenSystemSettings = true
        case .provisional:
            statusTitle = LT("临时通知已开启", "Provisional Notifications Enabled", "暫定通知が有効です")
            statusDescription = LT("iOS 当前允许静默或临时通知。你可以在系统设置中调整为完整提醒。", "iOS currently allows provisional notifications. You can switch to full alerts in system settings.", "iOS は現在、静かな通知または暫定通知を許可しています。システム設定で完全な通知に変更できます。")
            canRequestPermission = false
            canOpenSystemSettings = true
        case .ephemeral:
            statusTitle = LT("临时会话通知", "Ephemeral Notifications", "一時セッション通知")
            statusDescription = LT("当前通知授权由 iOS 临时会话管理。需要长期提醒时，请在系统设置中确认。", "Notification access is managed by an ephemeral iOS session. Confirm in system settings if you want persistent alerts.", "現在の通知権限は iOS の一時セッションで管理されています。継続的な通知が必要な場合はシステム設定で確認してください。")
            canRequestPermission = false
            canOpenSystemSettings = true
        @unknown default:
            statusTitle = LT("未知状态", "Unknown Status", "不明な状態")
            statusDescription = LT("无法读取系统通知权限，请前往 iOS 设置确认。", "Could not read notification permission status. Please check iOS Settings.", "システム通知の権限を読み取れません。iOS 設定で確認してください。")
            canRequestPermission = false
            canOpenSystemSettings = true
        }
    }
}

private struct PushNotificationSettingsView: View {
    @StateObject private var model = PushNotificationSettingsModel()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(model.statusTitle, systemImage: "bell.badge")
                        .font(.headline)
                    Text(model.statusDescription)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.vertical, 6)
            } header: {
                Text(LT("权限状态", "Permission Status", "権限状態"))
            }

            Section {
                if model.canRequestPermission {
                    Button {
                        model.requestPermission()
                    } label: {
                        HStack {
                            Label(LT("开启系统推送", "Enable System Push", "システムプッシュを有効にする"), systemImage: "bell.badge")
                            Spacer()
                            if model.isRequesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(model.isRequesting)
                }

                if model.canOpenSystemSettings {
                    Button {
                        model.openSystemSettings()
                    } label: {
                        Label(LT("打开 iOS 设置", "Open iOS Settings", "iOS 設定を開く"), systemImage: "gearshape")
                    }
                }
            } footer: {
                Text(LT("Raver 不会在首次启动时直接请求系统推送权限。你可以先使用站内通知，再按需要开启系统推送。", "Raver does not ask for system push permission on first launch. You can use in-app notifications first and enable system push when you need it.", "Raver は初回起動時に直接システムプッシュ権限を求めません。まずアプリ内通知を使い、必要に応じてシステムプッシュを有効にできます。"))
            }
        }
        .raverSystemNavigation(title: LT("推送通知", "Push Notifications", "プッシュ通知"))
        .onAppear {
            model.refresh()
        }
    }
}

private struct NotificationPreferenceGroup: Identifiable {
    let id: String
    let title: String
    let detail: String
    let categories: [String]
}

@MainActor
private final class NotificationCategoryPreferencesModel: ObservableObject {
    @Published var preferences: [String: Bool] = [:]
    @Published var isLoading = false
    @Published var savingGroupID: String?
    @Published var errorMessage: String?

    private let service: SocialService

    let groups: [NotificationPreferenceGroup] = [
        NotificationPreferenceGroup(
            id: "messages",
            title: LT("私信/群聊", "Direct & Group Chats", "メッセージ/グループチャット"),
            detail: LT("新私信、群聊和会话提醒。", "New direct messages, group chats, and conversation alerts.", "新しいメッセージ、グループチャット、会話通知。"),
            categories: ["chat_message"]
        ),
        NotificationPreferenceGroup(
            id: "interactions",
            title: LT("点赞评论", "Likes & Comments", "いいね・コメント"),
            detail: LT("点赞、评论、回复和社区互动。", "Likes, comments, replies, and community interactions.", "いいね、コメント、返信、コミュニティ交流。"),
            categories: ["community_interaction"]
        ),
        NotificationPreferenceGroup(
            id: "events",
            title: LT("活动", "Events", "イベント"),
            detail: LT("活动倒计时、每日摘要和签到提醒。", "Event countdowns, daily digests, and check-in reminders.", "イベントのカウントダウン、日次まとめ、チェックイン通知。"),
            categories: ["event_countdown", "event_daily_digest"]
        ),
        NotificationPreferenceGroup(
            id: "artists",
            title: LT("DJ/厂牌", "DJs & Brands", "DJ/レーベル"),
            detail: LT("关注 DJ、厂牌更新和路线提醒。", "Followed DJ, brand updates, and route reminders.", "フォロー中の DJ、レーベル更新、ルート通知。"),
            categories: ["route_dj_reminder", "followed_dj_update", "followed_brand_update"]
        ),
        NotificationPreferenceGroup(
            id: "enforcement",
            title: LT("审核/处罚/申诉", "Review, Enforcement & Appeals", "審査/処分/異議申し立て"),
            detail: LT("内容审核、账号处罚和申诉进度。", "Content reviews, account enforcement, and appeal progress.", "コンテンツ審査、アカウント処分、異議申し立ての進捗。"),
            categories: ["account_enforcement"]
        ),
        NotificationPreferenceGroup(
            id: "marketing",
            title: LT("营销", "Marketing", "マーケティング"),
            detail: LT("官方活动、产品更新和推广消息。", "Official campaigns, product updates, and promotional messages.", "公式キャンペーン、製品更新、プロモーション情報。"),
            categories: ["major_news"]
        )
    ]

    init(service: SocialService) {
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let items = try await service.fetchNotificationCategoryPreferences()
            preferences = Dictionary(uniqueKeysWithValues: items.map { ($0.category, $0.enabled) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isEnabled(_ group: NotificationPreferenceGroup) -> Bool {
        group.categories.allSatisfy { preferences[$0] ?? true }
    }

    func setEnabled(_ enabled: Bool, for group: NotificationPreferenceGroup) {
        for category in group.categories {
            preferences[category] = enabled
        }
        savingGroupID = group.id
        errorMessage = nil

        Task {
            do {
                let payload = group.categories.map {
                    NotificationCategoryPreference(category: $0, enabled: enabled)
                }
                let items = try await service.updateNotificationCategoryPreferences(
                    NotificationCategoryPreferencesInput(preferences: payload)
                )
                preferences = Dictionary(uniqueKeysWithValues: items.map { ($0.category, $0.enabled) })
            } catch {
                errorMessage = error.localizedDescription
                await load()
            }
            savingGroupID = nil
        }
    }
}

private struct NotificationCategoryPreferencesView: View {
    @StateObject private var model: NotificationCategoryPreferencesModel

    init(service: SocialService) {
        _model = StateObject(wrappedValue: NotificationCategoryPreferencesModel(service: service))
    }

    var body: some View {
        List {
            Section {
                if model.isLoading && model.preferences.isEmpty {
                    HStack {
                        ProgressView()
                        Text(LT("正在加载通知偏好…", "Loading notification preferences...", "通知設定を読み込み中..."))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                } else {
                    ForEach(model.groups) { group in
                        Toggle(isOn: Binding(
                            get: { model.isEnabled(group) },
                            set: { model.setEnabled($0, for: group) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(group.title)
                                    if model.savingGroupID == group.id {
                                        ProgressView()
                                            .scaleEffect(0.75)
                                    }
                                }
                                Text(group.detail)
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                        .disabled(model.savingGroupID != nil)
                    }
                }
            } header: {
                Text(LT("分类开关", "Category Switches", "カテゴリ別スイッチ"))
            } footer: {
                Text(LT("关闭某一类后，Raver 不再为该类发送站内通知或系统推送；审核、处罚、申诉等重要通知也可单独管理。", "When a category is off, Raver stops sending both in-app notifications and system push for that category. Review, enforcement, and appeal notices can also be managed separately.", "カテゴリをオフにすると、そのカテゴリのアプリ内通知とシステムプッシュは送信されません。審査、処分、異議申し立てなどの重要通知も個別に管理できます。"))
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("消息提醒", "Message Alerts", "メッセージ通知"))
        .task {
            await model.load()
        }
    }
}

private struct PermissionStatusItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let status: String
    let detail: String
}

private struct PermissionStatusSettingsView: View {
    @State private var items: [PermissionStatusItem] = []

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.systemImage)
                            .font(.title3)
                            .foregroundStyle(RaverTheme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 8)
                                Text(item.status)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(LT("权限状态", "Permission Status", "権限状態"))
            } footer: {
                Text(LT("Raver 会在你使用具体功能时先说明用途，再触发系统权限弹窗。拒绝权限后，仍会尽量保留手动输入、相册选择、文字消息或站内通知等替代路径。", "Raver explains why a permission is needed inside the relevant feature before showing the system prompt. If you decline, the app keeps alternatives such as manual input, photo library selection, text messages, or in-app notifications where possible.", "Raver は各機能内で用途を説明してからシステム権限ダイアログを表示します。拒否した場合も、手入力、写真選択、テキストメッセージ、アプリ内通知などの代替手段を可能な限り残します。"))
            }

            Section {
                Button {
                    openSystemSettings()
                } label: {
                    Label(LT("打开 iOS 设置", "Open iOS Settings", "iOS 設定を開く"), systemImage: "gearshape")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("权限管理", "Permissions", "権限管理"))
        .onAppear {
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        let locationManager = CLLocationManager()
        let locationStatus = locationManager.authorizationStatus
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let addPhotoStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let notificationStatus = settings.authorizationStatus
            Task { @MainActor in
                items = [
                    PermissionStatusItem(
                        id: "notifications",
                        title: LT("推送通知", "Push Notifications", "プッシュ通知"),
                        systemImage: "bell.badge",
                        status: notificationTitle(notificationStatus),
                        detail: LT("用于私信、群聊、互动、活动、审核/处罚/申诉等重要提醒；关闭后仍可查看站内通知。", "Used for important alerts such as DMs, group chats, interactions, events, moderation, enforcement, and appeals; in-app notifications remain available if disabled.", "メッセージ、グループチャット、交流、イベント、審査/処分/異議申し立てなどの重要通知に使用します。オフでもアプリ内通知は確認できます。")
                    ),
                    PermissionStatusItem(
                        id: "location",
                        title: LT("定位", "Location", "位置情報"),
                        systemImage: "location",
                        status: locationTitle(locationStatus),
                        detail: LT("用于发帖地点标签、活动地点和 Squad 位置共享；关闭后可继续手动搜索或输入地址。", "Used for post location tags, event locations, and Squad location sharing; if disabled, you can still search or enter addresses manually.", "投稿の場所タグ、イベント場所、Squad の位置共有に使用します。オフでも手動検索や住所入力を続けられます。")
                    ),
                    PermissionStatusItem(
                        id: "camera",
                        title: LT("相机", "Camera", "カメラ"),
                        systemImage: "camera",
                        status: captureTitle(cameraStatus),
                        detail: LT("用于拍摄头像、帖子或活动素材；关闭后可从相册选择已有图片。", "Used to capture avatars, posts, or event media; if disabled, you can choose existing images from the photo library.", "アイコン、投稿、イベント素材の撮影に使用します。オフでも写真ライブラリから既存画像を選べます。")
                    ),
                    PermissionStatusItem(
                        id: "microphone",
                        title: LT("麦克风", "Microphone", "マイク"),
                        systemImage: "mic",
                        status: microphoneTitle(microphoneStatus),
                        detail: LT("用于聊天语音或音频相关功能；关闭后仍可发送文字消息。", "Used for voice chat or audio features; if disabled, text messages remain available.", "音声チャットや音声関連機能に使用します。オフでもテキストメッセージは送信できます。")
                    ),
                    PermissionStatusItem(
                        id: "photos",
                        title: LT("相册", "Photos", "写真"),
                        systemImage: "photo.on.rectangle",
                        status: photoTitle(readWrite: photoStatus, addOnly: addPhotoStatus),
                        detail: LT("用于选择上传图片/视频或保存海报；可在 iOS 设置中改为有限访问或关闭。", "Used to choose photos/videos for upload or save posters; you can switch to limited access or disable it in iOS Settings.", "画像/動画のアップロード選択やポスター保存に使用します。iOS 設定で限定アクセスまたはオフに変更できます。")
                    ),
                ]
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func notificationTitle(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return LT("未请求", "Not Requested", "未要求")
        case .denied: return LT("已拒绝", "Denied", "拒否済み")
        case .authorized: return LT("已允许", "Allowed", "許可済み")
        case .provisional: return LT("临时允许", "Provisional", "暫定許可")
        case .ephemeral: return LT("临时会话", "Ephemeral", "一時セッション")
        @unknown default: return LT("未知", "Unknown", "不明")
        }
    }

    private func locationTitle(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return LT("未请求", "Not Requested", "未要求")
        case .restricted: return LT("受限制", "Restricted", "制限中")
        case .denied: return LT("已拒绝", "Denied", "拒否済み")
        case .authorizedAlways, .authorizedWhenInUse: return LT("已允许", "Allowed", "許可済み")
        @unknown default: return LT("未知", "Unknown", "不明")
        }
    }

    private func captureTitle(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return LT("未请求", "Not Requested", "未要求")
        case .restricted: return LT("受限制", "Restricted", "制限中")
        case .denied: return LT("已拒绝", "Denied", "拒否済み")
        case .authorized: return LT("已允许", "Allowed", "許可済み")
        @unknown default: return LT("未知", "Unknown", "不明")
        }
    }

    private func microphoneTitle(_ status: AVAudioSession.RecordPermission) -> String {
        switch status {
        case .undetermined: return LT("未请求", "Not Requested", "未要求")
        case .denied: return LT("已拒绝", "Denied", "拒否済み")
        case .granted: return LT("已允许", "Allowed", "許可済み")
        @unknown default: return LT("未知", "Unknown", "不明")
        }
    }

    private func photoTitle(readWrite: PHAuthorizationStatus, addOnly: PHAuthorizationStatus) -> String {
        if readWrite == .authorized || addOnly == .authorized {
            return LT("已允许", "Allowed", "許可済み")
        }
        if readWrite == .limited {
            return LT("有限访问", "Limited", "限定アクセス")
        }
        if readWrite == .denied || addOnly == .denied {
            return LT("已拒绝", "Denied", "拒否済み")
        }
        if readWrite == .restricted || addOnly == .restricted {
            return LT("受限制", "Restricted", "制限中")
        }
        return LT("未请求", "Not Requested", "未要求")
    }
}

private struct AccountSecuritySettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var appealingEnforcement: AccountEnforcement?
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: appState.accountEnforcementStatus.enforcementStatus.isLimited ? "exclamationmark.shield" : "checkmark.shield")
                        .foregroundStyle(appState.accountEnforcementStatus.enforcementStatus.isLimited ? .orange : .green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.accountEnforcementStatus.enforcementStatus.title)
                            .font(.headline)
                        Text(accountStatusSummary)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                    if appState.isLoadingAccountEnforcements {
                        ProgressView()
                    }
                }

                Button {
                    Task { await appState.refreshAccountEnforcements() }
                } label: {
                    Label(LT("刷新账号状态", "Refresh Status", "Refresh Status"), systemImage: "arrow.clockwise")
                }
            } header: {
                Text(LT("账号状态", "Account Status", "Account Status"))
            } footer: {
                Text(LT("账号处罚状态只对你本人可见。即使账号受限，你仍可查看设置、提交申诉和申请删除账号。", "Account enforcement status is only visible to you. Even when limited, you can still view settings, appeal, and request account deletion.", "Account enforcement status is only visible to you. Even when limited, you can still view settings, appeal, and request account deletion."))
            }

            Section(LT("当前处罚", "Current Enforcements", "Current Enforcements")) {
                if appState.accountEnforcements.isEmpty {
                    Text(LT("当前没有账号处罚记录。", "No account enforcement records.", "No account enforcement records."))
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(appState.accountEnforcements) { enforcement in
                        AccountEnforcementRow(
                            enforcement: enforcement,
                            appeal: latestAppeal(for: enforcement.id),
                            onAppeal: {
                                appealingEnforcement = enforcement
                            }
                        )
                    }
                }
            }

            if !appState.accountEnforcementAppeals.isEmpty {
                Section(LT("申诉记录", "Appeal History", "Appeal History")) {
                    ForEach(appState.accountEnforcementAppeals) { appeal in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(appeal.status.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(Self.formatDate(appeal.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Text(appeal.appealReason)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(3)
                            if let note = appeal.decisionNote?.nilIfBlank {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    isShowingDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        Label(LT("删除账号", "Delete Account", "アカウント削除"), systemImage: "person.crop.circle.badge.xmark")
                        Spacer()
                        if isDeletingAccount {
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeletingAccount)
            } footer: {
                Text(LT("删除账号会停用登录凭证、推送设备并清除个人资料。公开内容会按平台审核和法定留存策略处理。", "Deleting your account deactivates login credentials, push devices, and personal profile data. Public content is handled according to moderation and legal retention policies.", "Deleting your account deactivates login credentials, push devices, and personal profile data. Public content is handled according to moderation and legal retention policies."))
            }
        }
        .scrollContentBackground(.hidden)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("账号安全", "Account Security", "アカウントの安全"))
        .task {
            await appState.refreshAccountEnforcements()
        }
        .sheet(item: $appealingEnforcement) { enforcement in
            AccountEnforcementAppealSheet(enforcement: enforcement)
                .environmentObject(appState)
        }
        .confirmationDialog(
            LT("删除账号", "Delete Account", "アカウント削除"),
            isPresented: $isShowingDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button(LT("确认删除账号", "Delete Account", "アカウントを削除"), role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(LT("删除后你将退出登录，账号会被停用并清除个人资料。此操作不可撤销。", "You will be signed out. Your account will be deactivated and personal profile data will be cleared. This cannot be undone.", "削除後はログアウトされ、アカウントは無効化され個人情報が消去されます。この操作は元に戻せません。"))
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        _ = await appState.deleteAccount()
    }

    private var accountStatusSummary: String {
        let status = appState.accountEnforcementStatus
        if let nextReviewAt = status.nextReviewAt {
            return "\(LT("账号状态", "Account", "Account")): \(status.accountStatus.title) · \(LT("预计到期", "Expected end", "Expected end")): \(Self.formatDate(nextReviewAt))"
        }
        if status.enforcementStatus == .banned {
            return "\(LT("账号状态", "Account", "Account")): \(status.accountStatus.title) · \(LT("未设置到期时间", "No end time set", "No end time set"))"
        }
        if !status.scopes.isEmpty {
            return "\(LT("受限范围", "Limited scopes", "Limited scopes")): \(status.scopes.map(Self.scopeTitle(_:)).joined(separator: ", "))"
        }
        return "\(LT("账号状态", "Account", "Account")): \(status.accountStatus.title)"
    }

    private func latestAppeal(for enforcementID: String) -> AccountEnforcementAppeal? {
        appState.accountEnforcementAppeals.first { $0.enforcementId == enforcementID }
    }

    fileprivate static func scopeTitle(_ raw: String) -> String {
        switch raw {
        case "login": return LT("登录", "Login", "Login")
        case "post_create": return LT("发帖", "Posting", "Posting")
        case "comment_create": return LT("评论", "Comments", "Comments")
        case "message_send": return LT("私信", "Messages", "メッセージ")
        case "media_upload": return LT("上传媒体", "Media Upload", "Media Upload")
        case "event_create": return LT("创建活动", "Create Events", "Create Events")
        case "location_share": return LT("位置共享", "Location Sharing", "Location Sharing")
        case "profile_update": return LT("修改资料", "Profile Updates", "Profile Updates")
        case "squad_create": return LT("创建小队", "Create Squads", "Create Squads")
        default: return raw.replacingOccurrences(of: "_", with: " ")
        }
    }

    fileprivate static func formatDate(_ date: Date) -> String {
        date.appLocalizedYMDHMText()
    }
}

private struct AccountEnforcementRow: View {
    let enforcement: AccountEnforcement
    let appeal: AccountEnforcementAppeal?
    let onAppeal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(enforcement.type.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let status = enforcement.status {
                    Text(status.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            Text(enforcement.displayReason)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)

            if !enforcement.scopes.isEmpty {
                Text(enforcement.scopes.map(AccountSecuritySettingsView.scopeTitle(_:)).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            HStack {
                Text(dateRangeText)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                Spacer()
                if let appeal {
                    Text(appeal.status.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                } else if enforcement.isAppealable {
                    Button(LT("申诉", "Appeal", "異議申し立て")) {
                        onAppeal()
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var dateRangeText: String {
        let start = AccountSecuritySettingsView.formatDate(enforcement.startsAt)
        guard let endsAt = enforcement.endsAt else {
            return "\(start) - \(LT("永久", "Permanent", "Permanent"))"
        }
        return "\(start) - \(AccountSecuritySettingsView.formatDate(endsAt))"
    }
}

private struct AccountEnforcementAppealSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let enforcement: AccountEnforcement
    @State private var reason = ""
    @State private var contactEmail = ""
    @State private var attachmentText = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(LT("类型", "Type", "Type"), value: enforcement.type.title)
                    LabeledContent(LT("原因", "Reason", "Reason"), value: enforcement.displayReason)
                } header: {
                    Text(LT("处罚信息", "Enforcement", "Enforcement"))
                }

                Section {
                    TextEditor(text: $reason)
                        .frame(minHeight: 140)
                } header: {
                    Text(LT("申诉理由", "Appeal Reason", "Appeal Reason"))
                } footer: {
                    Text(LT("请说明你认为该处罚需要复核的原因。", "Explain why this enforcement should be reviewed.", "Explain why this enforcement should be reviewed."))
                }

                Section {
                    TextField(LT("邮箱（可选）", "Email (optional)", "Email (optional)"), text: $contactEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                } header: {
                    Text(LT("联系方式", "Contact", "Contact"))
                }

                Section {
                    TextField(LT("截图或资料链接，每行一个（可选）", "Screenshot or evidence links, one per line (optional)", "Screenshot or evidence links, one per line (optional)"), text: $attachmentText, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(LT("附件", "Attachments", "Attachments"))
                }
            }
            .navigationTitle(LT("提交申诉", "Submit Appeal", "Submit Appeal"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LT("取消", "Cancel", "キャンセル")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(LT("提交", "Submit", "送信"))
                        }
                    }
                    .disabled(isSubmitting || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let attachments = attachmentText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let success = await appState.submitAccountEnforcementAppeal(
            enforcementID: enforcement.id,
            input: AccountEnforcementAppealInput(
                appealReason: reason,
                contactEmail: contactEmail.nilIfBlank,
                attachments: attachments
            )
        )
        if success {
            dismiss()
        }
    }
}

private struct LanguageSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section(LT("显示语言", "Display Language", "表示言語")) {
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
        .raverSystemNavigation(title: LT("语言设置", "Language", "言語設定"))
    }
}

private struct ThemeSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section(LT("显示主题", "Appearance", "表示テーマ")) {
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
        .raverSystemNavigation(title: LT("主题设置", "Appearance", "テーマ設定"))
    }
}

private struct SettingsCurrentUserProfileLoaderView<Content: View>: View {
    let repository: ProfileUserRepository
    let content: (UserProfile) -> Content

    @State private var profile: UserProfile?
    @State private var errorMessage: String?

    init(
        repository: ProfileUserRepository,
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
                    Button(LT("重试", "Retry", "再試行")) {
                        Task { await loadProfile(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            } else {
                ProgressView(LT("加载中...", "Loading...", "Loading..."))
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
