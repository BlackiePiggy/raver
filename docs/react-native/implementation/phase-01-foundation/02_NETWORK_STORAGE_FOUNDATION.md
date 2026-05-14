# Network Storage Foundation Implementation Plan

> Status: Active  
> Phase: Phase 1 - RN 工程底座  
> Owner: Mobile / RN  
> Created: 2026-05-14  
> Updated: 2026-05-14

## 1. Scope

- [x] In scope: 建立 HTTP request wrapper 和统一 `AppError`。
- [x] In scope: 建立 Keychain token storage wrapper。
- [x] In scope: 建立 MMKV preferences wrapper。
- [x] In scope: 安装 `react-native-keychain`、`react-native-mmkv`、`react-native-nitro-modules`。
- [x] Out of scope: 本轮不接真实 auth/profile/feed API。
- [x] Out of scope: 本轮不实现 refresh token 自动续期。
- [x] Deferred: API contract mapper 和 BFF 聚合接口在具体 feature 实现时再落地。

## 2. iOS Source

```text
mobile/ios/RaverMVP/RaverMVP/Core/AppConfig.swift
mobile/ios/RaverMVP/RaverMVP/Core/SessionTokenStore.swift
mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift
mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift
mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift
```

## 3. Current iOS Behavior

- Entry: `AppEnvironment` 创建 mock/live service。
- Main states: runtime mode、BFF base URL、token、feature flags。
- Data source: BFF 默认 `http://localhost:8787`，可通过环境变量和持久化配置覆盖。
- User actions: 登录后持久化 token，API 请求携带 token。
- Navigation: 网络和存储本身不直接触发导航，401 后续由 session layer 处理。
- Loading/empty/error: service 抛错，ViewModel 转换为页面态。
- Native dependency: token 需要安全存储；偏好配置可用 UserDefaults/MMKV。
- Known gaps: RN 侧尚未接 refresh token 与 session bootstrap。

## 4. User Confirmations

- [x] No extra confirmation needed.

Decision:

```text
Use fetch for the first HTTP wrapper.
Use Keychain/Keystore via react-native-keychain for token storage.
Use MMKV for preferences and lightweight persisted state.
```

## 5. RN Target

```text
src/services/http/errors.ts
src/services/http/client.ts
src/services/storage/secureStorage.ts
src/services/storage/preferencesStorage.ts
```

## 6. Strategy

- Reuse: iOS `AppConfig` 的 runtime/base URL/token 思路。
- Rebuild: RN HTTP wrapper、Keychain wrapper、MMKV wrapper。
- Simplify: 本轮不实现 refresh queue、request dedupe、multipart、retry。
- Defer: 401 session expired、API schema mapper、upload service。

## 7. API / Repository

- Endpoint: wrapper 支持任意 endpoint。
- Query key: None.
- Mutation: None.
- Mapper: `parseJsonResponse`。
- Error handling: `AppError`。

## 8. Navigation

- Route: None.
- Params: None.
- Deep link: None.
- Tab behavior: None.

## 9. State

- Server state: still TanStack Query in feature layer.
- Global state: future session store will consume secure storage.
- Local state: None.
- Persisted state: Keychain and MMKV wrappers.

## 10. Implementation Checklist

- [x] Dependencies installed.
- [x] iOS Pods installed with proxy after CocoaPods CDN timeout.
- [x] HTTP errors created.
- [x] HTTP client created.
- [x] Secure token storage created.
- [x] Preferences storage created.
- [x] Typecheck passes.
- [x] Lint passes.
- [x] Tests pass.
- [x] Docs updated.
- [x] Log updated.

## 11. Acceptance

- [x] `npm run typecheck` passes.
- [x] `npm run lint` passes.
- [x] `npm test -- --runInBand` passes.
- [x] `Podfile.lock` includes native storage dependencies.
- [x] No business route/API coupling introduced.

## 12. Risks / Rollback

- Risk: `react-native-mmkv` v4 requires `react-native-nitro-modules`.
- Risk: CocoaPods CDN timed out without proxy.
- Result: `127.0.0.1:7897` proxy was required for this pod install.
- Rollback: remove MMKV and Nitro dependencies, replace preferences with temporary JS storage only.

