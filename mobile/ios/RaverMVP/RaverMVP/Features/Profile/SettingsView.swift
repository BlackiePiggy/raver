import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
                // 账号设置
                Section("账号") {
                    NavigationLink {
                        Text("编辑资料")
                    } label: {
                        Label("编辑资料", systemImage: "person.circle")
                    }

                    NavigationLink {
                        Text("账号安全")
                    } label: {
                        Label("账号安全", systemImage: "lock.shield")
                    }

                    NavigationLink {
                        Text("隐私设置")
                    } label: {
                        Label("隐私设置", systemImage: "hand.raised")
                    }
                }

                // 通知设置
                Section("通知") {
                    NavigationLink {
                        Text("推送通知")
                    } label: {
                        Label("推送通知", systemImage: "bell")
                    }

                    NavigationLink {
                        Text("消息提醒")
                    } label: {
                        Label("消息提醒", systemImage: "message")
                    }
                }

                // 内容偏好
                Section("内容偏好") {
                    NavigationLink {
                        Text("兴趣标签")
                    } label: {
                        Label("兴趣标签", systemImage: "tag")
                    }

                    NavigationLink {
                        Text("语言设置")
                    } label: {
                        Label("语言设置", systemImage: "globe")
                    }

                    NavigationLink {
                        Text("内容过滤")
                    } label: {
                        Label("内容过滤", systemImage: "eye.slash")
                    }
                }

                // 数据与存储
                Section("数据与存储") {
                    NavigationLink {
                        Text("缓存管理")
                    } label: {
                        Label("缓存管理", systemImage: "externaldrive")
                    }

                    NavigationLink {
                        Text("数据使用")
                    } label: {
                        Label("数据使用", systemImage: "chart.bar")
                    }

                    NavigationLink {
                        Text("下载设置")
                    } label: {
                        Label("下载设置", systemImage: "arrow.down.circle")
                    }
                }

                // 关于
                Section("关于") {
                    NavigationLink {
                        Text("帮助中心")
                    } label: {
                        Label("帮助中心", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        Text("服务条款")
                    } label: {
                        Label("服务条款", systemImage: "doc.text")
                    }

                    NavigationLink {
                        Text("隐私政策")
                    } label: {
                        Label("隐私政策", systemImage: "hand.raised.shield")
                    }

                    NavigationLink {
                        Text("关于我们")
                    } label: {
                        Label("关于我们", systemImage: "info.circle")
                    }

                    HStack {
                        Text("版本")
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
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RaverTheme.background)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
    }
}
