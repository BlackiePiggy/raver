# 02. 架构与状态管理

## 目标

Flutter Android 的工程组织对齐 iOS 当前的 `MVVM + Coordinator + Repository + Service`。不要让 Widget 直接发请求，也不要让页面散落维护全局状态。

## iOS 对照

| iOS | Flutter |
|---|---|
| `AppContainer` | Riverpod provider graph |
| `AppState` | `AppStateNotifier` + global providers |
| `ObservableObject ViewModel` | `AsyncNotifier` / `Notifier` |
| `SocialService` / `WebFeatureService` | API client + repository |
| `Coordinator` / `AppRouter` | go_router + route metadata |
| `UseCase` structs | domain use case classes |

## 目标分层

```text
presentation
  screen/widget
  view_model
domain
  model
  repository interface
  use_case
data
  dto
  repository implementation
  api client
core
  config/networking/storage/router/design_system
```

## 状态归属规则

- App 级：登录态、用户、语言、主题、未读数、全局错误。
- Router 级：当前路由、Tab、sheet/fullscreen。
- Feature 级：列表分页、详情加载、表单、筛选条件。
- Widget 局部：输入框焦点、动画 controller、临时展开状态。

## Riverpod Provider 规划

```text
configProvider
secureStorageProvider
sharedPreferencesProvider
dioProvider
authApiProvider
discoverApiProvider
socialRepositoryProvider
webFeatureRepositoryProvider
appStateProvider
routerProvider
```

## ViewModel 规范

每个 ViewModel 必须提供：

- `build()` 或初始化加载逻辑
- `reload()`
- 用户动作方法，例如 `toggleFollow()`、`submitComment()`
- 明确的 loading/error/data 状态
- 请求并发保护：搜索和分页必须避免旧请求覆盖新请求

不要在 ViewModel 里：

- 直接读取 `BuildContext`
- 直接弹 sheet/dialog
- 手写 URL 拼接
- 持有可泄漏的 controller，除非提供 dispose

## UseCase 规范

适合抽 UseCase 的场景：

- 一个动作涉及多个 repository。
- 需要先上传再提交表单。
- 需要乐观更新与失败回滚。
- 需要复用到多个页面。

示例：

```text
LoginUseCase
FetchEventDetailUseCase
ToggleMarkedEventUseCase
CreatePostWithUploadsUseCase
SendMessageUseCase
```

## 复刻步骤

1. 建立 `core/config`、`core/networking`、`core/persistence`。
2. 建立 `app/di/providers.dart`。
3. 先实现 mock repositories，让 UI 能脱离 BFF 开发。
4. 每个 feature 从 domain model 开始，不直接把 DTO 暴露到 Widget。
5. 接 live BFF 时补 contract fixture test。

## 验收标准

- 页面 Widget 中没有 Dio/API client。
- 页面 Widget 不直接 new repository。
- ViewModel 可在 unit test 中用 mock repository 测试。
- 业务错误统一转成用户可读状态。
- session expired 能触发全局退登。

