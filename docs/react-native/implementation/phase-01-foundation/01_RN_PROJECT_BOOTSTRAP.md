# RN Project Bootstrap Implementation Plan

> Status: Active  
> Phase: Phase 1 - RN 工程底座  
> Owner: Mobile / RN  
> Created: 2026-05-14  
> Updated: 2026-05-14

## 1. Scope

- [x] In scope: 使用 RN CLI 创建 iOS + Android 双端工程。
- [x] In scope: 工程路径固定为 `mobile/react_native_raver/app`。
- [x] In scope: 记录 RN CLI、TypeScript、iOS/Android、New Architecture 的首期基线。
- [x] In scope: 建立后续 AppProviders、navigation、theme、http、storage、query 的文件落点。
- [x] Out of scope: 本轮不实现业务页面。
- [x] Out of scope: 本轮不接 Tencent IM、Push、Widget、视频发布、小队定位。
- [x] Deferred: 完整 IM、小队实时定位、Widget、视频发帖、Tracklist 编辑器继续留在 `DEFERRED_BACKLOG.md`。

## 2. iOS Source

```text
mobile/ios/RaverMVP/RaverMVP/RaverMVPApp.swift
mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/AppCoordinator.swift
mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
mobile/ios/RaverMVP/RaverMVP/Application/DI/AppContainer.swift
mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift
mobile/ios/RaverMVP/RaverMVP/Core/AppConfig.swift
mobile/ios/RaverMVP/RaverMVP/Core/SessionTokenStore.swift
mobile/ios/RaverMVP/RaverMVP/Core/Theme.swift
```

## 3. Current iOS Behavior

- Entry: `RaverMVPApp.swift` 创建全局状态、依赖容器并渲染 `AppCoordinatorView`。
- Main states: 登录态、auth bootstrapping、语言、全局错误、system deep link event。
- Data source: 当前通过 `AppEnvironment` 创建 mock/live service，BFF 默认 `http://localhost:8787`。
- User actions: 启动、登录态判断、Deep Link 打开、错误弹窗关闭。
- Navigation: `AppCoordinatorView` 根据登录态切换 `LoginView` 或 `MainTabCoordinatorView`。
- Loading/empty/error: 启动期显示 loading，全局错误通过 alert。
- Native dependency: iOS 原生生命周期、Universal Link、Keychain/UserDefaults、APNs 后续接入。
- Known gaps: RN 工程尚不存在；需要先建立可运行的双端基座。

## 4. User Confirmations

- [x] RN 路线：RN CLI。
- [x] 首期目标：iOS + Android 双端并行复现。
- [x] 首期范围：按 Master Plan 推荐范围推进。
- [x] 状态管理：TanStack Query + Zustand。
- [x] BFF 策略：允许新增兼容型 RN BFF，不破坏 iOS 当前接口。

Decision:

```text
Create RN CLI app at mobile/react_native_raver/app.
Keep existing iOS Native as current reference.
Do not start from Expo Go.
```

## 5. RN Target

```text
mobile/react_native_raver/app/
  android/
  ios/
  src/
    app/
    navigation/
    features/
    shared/
    services/
    store/
    native/
    types/
```

## 6. Strategy

- Reuse: 复用当前后端 BFF、iOS 的 AppCoordinator/AppRouter/AppContainer 语义、RaverTheme 设计方向。
- Rebuild: RN app shell、navigation、state、repository、shared UI。
- Simplify: 首轮只建立脚手架和最小目录，不实现业务。
- Defer: Native IM/Push/Widget/Location/Video 先不接。

## 7. API / Repository

- Endpoint: 本轮不调用业务 API。
- Query key: 本轮只预留 QueryClient。
- Mutation: None.
- Mapper: None.
- Error handling: 后续在 `services/http/errors.ts` 统一。

## 8. Navigation

- Route: 本轮不落业务 route。
- Params: None.
- Deep link: 后续 `navigation/linking.ts`。
- Tab behavior: 后续 `navigation/MainTabs.tsx`。

## 9. State

- Server state: TanStack Query。
- Global state: Zustand。
- Local state: React state。
- Persisted state: Keychain/Keystore + MMKV。

## 10. UI Structure

```text
App
  AppProviders
    RootNavigator
```

本轮如 RN CLI 默认模板可运行，后续再替换为 Raver App Shell。

## 11. Implementation Checklist

- [x] RN CLI project created.
- [x] Project path is `mobile/react_native_raver/app`.
- [x] iOS directory generated.
- [x] Android directory generated.
- [x] TypeScript template present.
- [x] Package manager lockfile present.
- [x] Foundation dependencies installed: React Navigation, TanStack Query, Zustand, Zod.
- [x] iOS Pods installed.
- [x] Minimal `AppProviders -> RootNavigator` shell created.
- [x] README / docs updated.
- [x] Execution log updated.
- [x] `git status` checked.

## 12. Acceptance

- [x] `package.json` exists.
- [x] `ios/` exists.
- [x] `android/` exists.
- [x] RN app can install dependencies.
- [x] `npm run typecheck` passes.
- [x] `npm run lint` passes.
- [x] `npm test -- --runInBand` passes.
- [x] No unrelated current-line route changes introduced.

## 13. Risks / Rollback

- Risk: RN CLI version changes may produce different template files.
- Risk: Node 22 may expose package compatibility warnings; if it blocks CLI, use the template output and document the issue.
- Risk: CocoaPods install may need local Xcode/Ruby environment fixes.
- Result: CocoaPods install succeeded without needing the `127.0.0.1:7897` proxy.
- Result: npm audit reports 7 moderate vulnerabilities from the generated dependency tree; no forced audit fix was applied.
- Rollback: 删除 `mobile/react_native_raver/app` and reset this phase docs before first RN commit if scaffold fails beyond repair.
