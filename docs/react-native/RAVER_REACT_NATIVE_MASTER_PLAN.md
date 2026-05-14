# Raver React Native Master Plan

> Status: Draft for execution  
> Created: 2026-05-14  
> Purpose: 总体说明为什么 Raver 适合用 Hybrid RN 架构复现、目标目录、迁移阶段、风险和验收门禁。

## 0. 当前项目判断

Raver 是围绕电子音乐场景的 App-first 垂直社交平台。当前已存在：

- iOS Native 主客户端：`mobile/ios/RaverMVP/`
- Node.js + Express + TypeScript + Prisma 后端：`server/`
- Next.js Web/Admin/CMS/fallback：`web/`
- Tencent IM 主线
- Notification Center + APNs 主线
- Check-in v2 projection read model 主线
- Flutter Android 复刻文档，可作为移动端复刻思路参考

React Native 复现的目标不是替换后端，也不是复用 Web 页面，而是复现 App-first 客户端。

## 1. 架构选择

推荐：

```text
Hybrid
  + Feature-based modules
  + Repository layer
  + Query cache
  + Minimal global store
  + Native bridge for high-risk capability
```

原因：

- Raver 的业务域天然模块化：Discover、Events、DJs、Sets、Circle、Feed、Messages、Squads、Profile、Check-ins、Notifications、Search。
- 当前 iOS 已经有 Repository 和 Coordinator 方向，RN 可以平滑继承，而不是从 Screen-based 重新堆页面。
- 内容流、评论、搜索、通知、IM 会大量依赖分页、缓存、重试和刷新，适合 Query cache，而不是全塞 Redux。
- IM、Push、Widget、媒体上传、定位、播放器属于移动端复杂能力，需要保留 Native bridge 策略。

## 2. RN 技术基线

建议首选：

```text
React Native CLI 或 Expo Dev Client
TypeScript
React Navigation
TanStack Query
Zustand 或 Redux Toolkit
MMKV
FlashList
React Hook Form
Zod
Sentry
Detox 或 Maestro
```

选择建议：

| 选项 | 建议 | 原因 |
|---|---|---|
| Expo Go | 不建议作为主线 | Tencent IM、Push、Widget、原生播放器和 Native bridge 很快会超出 Expo Go 范围 |
| Expo Dev Client | 可选推荐 | 兼顾工程效率和自定义原生模块 |
| RN CLI | 可选推荐 | 原生集成自由度最高，适合 IM/Widget/Push 很重的路线 |
| TypeScript | 必须 | Raver API 和页面状态复杂，强类型是长期维护基础 |
| TanStack Query | 推荐 | 处理服务端数据、缓存、分页、重试、失效刷新 |
| Zustand | 推荐轻量全局状态 | session、language、theme、unread、runtime config |
| Redux Toolkit | 团队偏规范时可选 | 如果多人协作需要强约束和 devtool，可替代 Zustand |

## 3. 目标工程目录

建议新工程路径：

```text
mobile/react_native_raver/
  app/
    android/
    ios/
    src/
      app/
      navigation/
      features/
      shared/
      services/
      store/
      types/
      native/
    package.json
    tsconfig.json
```

`src/` 目标结构：

```text
src/
  app/
    App.tsx
    providers/
      AppProviders.tsx
      QueryProvider.tsx
      ThemeProvider.tsx
    bootstrap/
      initApp.ts
      initSession.ts
      initAnalytics.ts
    config/
      env.ts
      featureFlags.ts

  navigation/
    RootNavigator.tsx
    AuthNavigator.tsx
    MainTabs.tsx
    routeTypes.ts
    linking.ts
    navigationRef.ts

  features/
    auth/
    discover/
    events/
    djs/
    sets/
    circle/
    feed/
    comments/
    messages/
    squads/
    notifications/
    profile/
    checkins/
    ratings/
    virtualAssets/
    search/
    share/

  shared/
    ui/
    components/
    hooks/
    theme/
    utils/
    assets/
    i18n/
    feedback/

  services/
    api/
    http/
    storage/
    analytics/
    push/
    im/
    media/
    location/
    share/

  store/
    sessionStore.ts
    appPreferenceStore.ts
    unreadStore.ts

  native/
    modules/
    ios/
    android/

  types/
    api.ts
    route.ts
    domain.ts
```

## 4. iOS 到 RN 的概念映射

| iOS 当前概念 | RN 目标概念 |
|---|---|
| `RaverMVPApp.swift` | `src/app/App.tsx` |
| `AppCoordinatorView` | `RootNavigator` + session bootstrap |
| `MainTabCoordinatorView` | `MainTabs` + root stack |
| `AppRouter` / `AppRoute` | typed route params + navigation helpers |
| `AppContainer` | providers + repository factories |
| `SocialService` / `WebFeatureService` | API clients + repositories |
| `ObservableObject ViewModel` | feature hooks / view model hooks |
| `RaverTheme` | theme tokens + ThemeProvider |
| `SessionTokenStore` | secure storage + session store |
| `NotificationRepository` | notification API + push token service |
| Tencent IM Swift integration | Native module + JS facade |
| Widget Extension | native widget target, later phase |

## 5. 迁移阶段

### Phase 0: 决策与基线

- 明确 RN 是新移动端主线还是跨端补充。
- 决定 Expo Dev Client 或 RN CLI。
- 冻结首期范围：建议只做 App Shell、Auth、Discover、Events、DJ、Sets、Circle Feed、Post Detail、Profile。
- 建立 API contract snapshot。

### Phase 1: 工程底座

- 创建 RN 工程。
- 接入 TypeScript、路径别名、lint、format、test。
- 建立 AppProviders、navigation、theme、http、storage、query client。
- 跑通 mock/live runtime。

### Phase 2: 登录与主导航

- 复刻 iOS 登录态切换。
- 实现 AuthStack / MainTabs / RootStack。
- 实现 token 持久化、refresh、401 session expired。
- 接入 Deep Link 的路由解析骨架。

### Phase 3: Discover 和内容基础

- Discover 首页。
- 活动列表/详情/收藏。
- DJ 列表/详情/关注。
- Set 列表/详情/Tracklist/播放器基础。
- 全局搜索基础。

### Phase 4: 社区核心

- Circle 首页。
- Feed 流。
- PostCard。
- Post Detail。
- 评论、点赞、收藏、分享、隐藏。
- 发帖和媒体上传。

### Phase 5: Profile / Check-in / Rating

- 我的主页、公开主页、编辑资料。
- 我的发布、关注、收藏。
- Check-in v2 页面。
- Rating 页面。
- 虚拟资产展示基础。

### Phase 6: Messages / Squads / Notifications

- Tencent IM bootstrap。
- 会话列表。
- Chat UI 第一版。
- Squad profile / offline activity。
- Notification Center inbox / unread / push token。

### Phase 7: Native polish and release

- Push、Universal Link、Share Sheet、Widget、播放器、定位权限。
- 性能调优：启动、列表、图片、内存。
- E2E 和灰度发布。
- 与 iOS parity checklist 对齐。

## 6. 首期 MVP 范围建议

首期不要试图一次复刻全部 Raver。建议切出可上线闭环：

```text
Auth
Main tabs
Discover home
Events list/detail/favorite
DJs list/detail/follow
Sets list/detail
Circle feed
Post detail/comment/like/save
Profile me/public
Notifications inbox basic
Deep link read-only routing
```

延后：

- 完整 Tencent IM 聊天体验
- Widget Extension
- 高级虚拟资产渲染
- 小队线下定位协同
- 内容编辑后台能力
- 活动路线规划复杂交互
- Tracklist 编辑器

## 7. 主要风险

| 风险 | 影响 | 处理 |
|---|---|---|
| Tencent IM RN SDK 能力不足 | 消息体验受限 | 先评估官方/社区 SDK，不满足则做原生 Native module |
| iOS 行为持续变化 | RN 追不上主线 | 每个 feature 先锁 iOS source commit 和 parity checklist |
| BFF 契约不稳定 | 客户端重复返工 | 建立 `services/api/contracts` 和 fixture tests |
| 长列表性能 | Feed/评论卡顿 | 使用 FlashList、稳定 item size、图片预取和骨架态 |
| Native 能力过多 | RN 工程复杂度上升 | 分期接入，首期只做必要桥接 |
| 纯复刻导致体验不适配 Android | Android 用户体验差 | 视觉复刻品牌，交互尊重平台习惯 |

## 8. 验收门禁

每个 feature 必须满足：

- 页面可从主导航和 Deep Link 到达。
- loading、empty、error、refresh、pagination 完整。
- API 类型、错误处理、鉴权一致。
- 和 iOS 同一场景下核心文案、信息层级、交互结果一致。
- 关键列表在中端设备上滚动稳定。
- 单元测试覆盖 repository mapper 和 view model hooks。
- 至少一个 E2E 覆盖主路径。

## 9. 官方资料备注

本方案采用当前 RN 生态主线：React Native New Architecture、React Navigation、TanStack Query/RTK Query 等。执行前应再次确认所选 RN/Expo 版本与 Tencent IM、Push、MMKV、FlashList 等原生依赖兼容。

参考资料：

- React Native 0.76 起新架构默认启用：<https://reactnative.dev/blog/2024/10/23/release-0.76-new-architecture>
- Expo SDK 55 以后新架构不可关闭：<https://docs.expo.dev/guides/new-architecture/>
- React Navigation 嵌套路由注意事项：<https://reactnavigation.org/docs/nesting-navigators>
- React Navigation linking 配置：<https://reactnavigation.org/docs/configuring-links>
- TanStack Query React Native 注意事项：<https://tanstack.com/query/latest/docs/react/>
