# 00. App Shell 与主 Tab

## iOS 来源

- `RaverMVPApp.swift`
- `Application/Coordinator/AppCoordinator.swift`
- `Application/Coordinator/MainTabCoordinator.swift`
- `Features/MainTabView.swift`
- `Core/AppState.swift`
- `Core/Theme.swift`

## Flutter 目标路径

```text
lib/app/app.dart
lib/app/bootstrap.dart
lib/app/router/app_router.dart
lib/features/shell/presentation/raver_shell_scaffold.dart
lib/features/shell/presentation/raver_floating_tab_bar.dart
```

## 页面职责

- App 启动后判断登录态。
- 未登录显示 Auth。
- 已登录进入四 Tab：Discover、Circle、Messages、Profile。
- 保留 Tab 状态。
- 根据 route metadata 控制底部 TabBar 显隐。
- 统一处理 Android back。

## 路由

```text
/login
/app/discover
/app/circle
/app/messages
/app/profile
```

公共详情页不挂在某个 Tab 下面，而是全局定义。

## UI 复刻

- 背景使用 `RaverTheme.background`。
- TabBar 复刻 iOS 胶囊毛玻璃视觉。
- 选中项使用紫色渐变胶囊和轻阴影。
- 未选中项使用 secondary text。
- Tab 内容底部预留 TabBar 高度。
- 键盘弹出时内容避免被底部区域遮挡。

## 状态模型

```text
AppBootstrapState
  booting
  unauthenticated
  authenticated(user)
  error(message)

ShellState
  selectedTab
  loadedTabs
  unreadMessages
```

## 实现步骤

1. 建 `AppBootstrap`，读取 token 和偏好。
2. 如果 token 存在，请求 `/v1/profile/me`。
3. 建 `GoRouter` redirect。
4. 建 `RaverShellScaffold`。
5. 建 `RaverFloatingTabBar`。
6. 接入 unread count provider。
7. 添加 route meta 的 `hideBottomBar`。
8. 补 Android back：详情 pop，Tab 根切 Discover 或退出确认。

## 测试

- 未登录启动进入 login。
- 登录后进入 Discover。
- 四 Tab 切换不重置列表。
- 详情页 TabBar 隐藏。
- Android back 行为符合矩阵。

