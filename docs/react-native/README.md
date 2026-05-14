# Raver React Native Reimplementation Documentation

> Status: Draft for execution  
> Owner: Mobile / Architecture  
> Created: 2026-05-14  
> Applies To: future `mobile/react_native_raver/`, current `mobile/ios/RaverMVP/`, `server/`, `web/`, `docs/`

## 0. 文档定位

这套文档用于指导用 React Native 复现当前 Raver App，而不是做一个简单壳应用。

Raver 当前主客户端是 iOS Native，已经形成了比较清晰的 `AppCoordinator + AppRouter + AppContainer + Repository + ViewModel` 结构。React Native 复现时应继承这些边界，并结合 RN 生态改造成：

```text
App Shell
  -> Navigation
  -> Feature modules
  -> View hooks / ViewModel hooks
  -> Repository
  -> API client / Native bridge
  -> Existing BFF / Tencent IM / APNs-compatible push
```

## 1. 推荐结论

Raver React Native 版推荐采用：

```text
Hybrid architecture
  = Feature-based business modules
  + Shared design system
  + Repository / API layer
  + Query cache for server data
  + Minimal global client state
  + Native bridge only where RN cannot cover product quality
```

不推荐：

- 不推荐纯 Screen-based：Raver 的帖子、活动、DJ、IM、小队、打卡、通知会大量跨页面复用。
- 不推荐纯 Redux 驱动：列表、详情和评论是服务端数据，不应该全部塞进全局 store。
- 不推荐机械 MVVM：可以使用 `useXxxViewModel` 组织复杂页面逻辑，但不需要为每个小组件硬拆三层。
- 不推荐 WebView 复刻：Web 当前定位是 Admin / CMS / fallback，不是 App-first 主体验。

## 2. 推荐阅读顺序

1. [Master Plan](./RAVER_REACT_NATIVE_MASTER_PLAN.md)
2. [Execution Route Guide](./EXECUTION_ROUTE_GUIDE.md)
3. [Execution Log](./EXECUTION_LOG.md)
4. [Deferred Backlog](./DEFERRED_BACKLOG.md)
5. [Foundation 01 - Environment And Bootstrap](./foundation/01_ENVIRONMENT_AND_BOOTSTRAP.md)
6. [Foundation 02 - Architecture And State](./foundation/02_ARCHITECTURE_AND_STATE.md)
7. [Foundation 03 - Navigation And Deep Links](./foundation/03_NAVIGATION_AND_DEEPLINKS.md)
8. [Foundation 04 - Design System And Shared UI](./foundation/04_DESIGN_SYSTEM_AND_SHARED_UI.md)
9. [Foundation 05 - Networking And BFF](./foundation/05_NETWORKING_AND_BFF.md)
10. [Foundation 06 - Storage Cache Offline](./foundation/06_STORAGE_CACHE_OFFLINE.md)
11. [Foundation 07 - Native Integrations](./foundation/07_NATIVE_INTEGRATIONS.md)
12. [Foundation 08 - Testing Release Quality](./foundation/08_TESTING_RELEASE_QUALITY.md)
13. [Feature Migration Matrix](./features/00_FEATURE_MIGRATION_MATRIX.md)
14. [Migration Path](./migration/01_IOS_TO_REACT_NATIVE_MIGRATION_PATH.md)
15. [Parity Checklist](./migration/02_PARITY_CHECKLIST.md)

## 3. 分册目录

### Execution

| 文档 | 负责内容 |
|---|---|
| `EXECUTION_ROUTE_GUIDE.md` | 每轮执行路线、需求确认、局部落地文档、checkbox、收口和防漂移规则 |
| `EXECUTION_LOG.md` | 执行日志、需求确认、路线决策、进度和风险 |
| `DEFERRED_BACKLOG.md` | 延期需求和路线漂移控制 |

### Foundation

| 文档 | 负责内容 |
|---|---|
| `01_ENVIRONMENT_AND_BOOTSTRAP.md` | RN 工程创建、依赖、环境变量、后端联调 |
| `02_ARCHITECTURE_AND_STATE.md` | Hybrid 架构、目录结构、状态边界、Feature 模块规则 |
| `03_NAVIGATION_AND_DEEPLINKS.md` | React Navigation、Tab、Stack、Modal、Deep Link、Universal Link |
| `04_DESIGN_SYSTEM_AND_SHARED_UI.md` | 主题、字体、Shared UI、长列表、空态、错误态 |
| `05_NETWORKING_AND_BFF.md` | API client、BFF envelope、鉴权、上传、分页、错误处理 |
| `06_STORAGE_CACHE_OFFLINE.md` | token、偏好、MMKV、Query cache、草稿、离线策略 |
| `07_NATIVE_INTEGRATIONS.md` | Tencent IM、Push、相册/相机、定位、Widget、Share、音视频 |
| `08_TESTING_RELEASE_QUALITY.md` | 单测、组件测试、E2E、性能、灰度、发布门禁 |

### Feature

| 文档 | 负责内容 |
|---|---|
| `00_FEATURE_MIGRATION_MATRIX.md` | 当前 iOS 功能到 RN feature 的完整映射 |
| `01_APP_AUTH_PROFILE.md` | App Shell、登录、用户、个人中心 |
| `02_DISCOVER_EVENTS_MUSIC.md` | Discover、活动、DJ、Set、资讯、Wiki |
| `03_COMMUNITY_FEED_CIRCLE.md` | Circle、Feed、帖子、评论、发帖、互动 |
| `04_MESSAGES_SQUADS_NOTIFICATIONS.md` | 消息、Tencent IM、小队、通知中心、深链 |
| `05_CHECKINS_RATINGS_ASSETS_SEARCH.md` | 打卡、评分、虚拟资产、搜索、分享 |

### Migration

| 文档 | 负责内容 |
|---|---|
| `01_IOS_TO_REACT_NATIVE_MIGRATION_PATH.md` | 从现有 iOS 主线迁移到 RN 的阶段、门禁和回滚 |
| `02_PARITY_CHECKLIST.md` | 页面、API、交互、性能和发布验收清单 |

## 4. 执行规则

- 每实现一个 RN feature，先读 feature 文档，再读涉及的 foundation 文档。
- 每个页面落地前必须确认：iOS 来源文件、RN 目标路径、路由、API、状态、Native 依赖、验收点。
- 如果 BFF 契约变化，必须同时更新 `foundation/05_NETWORKING_AND_BFF.md` 和对应 feature 文档。
- 如果 iOS 行为变化，先更新 feature migration matrix，再改 RN。
- RN 不是简单翻译 SwiftUI 文件。优先复刻产品行为、状态语义、数据契约和导航语义。
