# iOS Repository Naming And Module Guide

> Status: Active  
> Owner: iOS Architecture  
> Last Updated: 2026-05-12  
> Applies To: `mobile/ios/RaverMVP/RaverMVP/`  
> Purpose: 为 iOS 架构收束建立 Repository 命名规范、模块落位规则和旧 Service 迁移方向。

## 1. 当前问题

当前 iOS 已经有 `Application`、`Core`、`Features`、`Shared`，并且部分 feature 已经出现 repository protocol，例如：

```text
DiscoverEventsRepository
DiscoverDJsRepository
DiscoverSetsRepository
DiscoverWikiRepository
DiscoverNewsRepository
CircleFeedRepository
MessagesRepository
ProfileSocialRepository
VirtualAssetRepository
```

但同时仍存在历史大 Service：

```text
SocialService
WebFeatureService
LiveSocialService
LiveWebFeatureService
MockSocialService
MockWebFeatureService
```

这些 Service 当前仍承担大量 API 访问能力，但名字已经不能准确表达领域边界。

目标不是马上删除它们，而是让新 ViewModel 逐步依赖更小、更清楚的 Repository protocol。

## 2. 目标分层

```text
RaverMVP/
  App/
  Core/
  DesignSystem/
  Modules/
  Infrastructure/
  Shared/
  Legacy/
```

当前迁移期可以继续保留现有 `Features/`，但新架构命名以 `Modules/` 为目标。

## 3. Repository 命名规则

### 3.1 基本规则

Repository protocol 使用领域名 + `Repository`：

```swift
protocol EventRepository {}
protocol DJRepository {}
protocol SetRepository {}
protocol FeedRepository {}
protocol MessageRepository {}
protocol SquadRepository {}
protocol NotificationRepository {}
protocol CheckinRepository {}
protocol VirtualAssetRepository {}
protocol ShareRepository {}
protocol SearchRepository {}
```

实现类命名：

```swift
final class LiveEventRepository: EventRepository {}
final class MockEventRepository: EventRepository {}
final class DisabledVirtualAssetRepository: VirtualAssetRepository {}
```

Adapter 命名：

```swift
struct EventRepositoryAdapter: EventRepository {}
```

当 adapter 只是包一层旧 service 时，可以保留 `Adapter` 后缀，表示迁移期适配层。

### 3.2 禁止继续扩大的命名

以下命名不再承载新增领域能力：

```text
SocialService
WebFeatureService
LiveSocialService
LiveWebFeatureService
Models.swift
WebFeatureModels.swift
```

允许短期做：

- 作为底层 API client
- 作为 compat adapter
- 承载旧调用直到迁移完成

不允许继续做：

- 新增无关领域 API
- 让新 ViewModel 直接依赖
- 继续扩大巨型 DTO 文件

## 4. 推荐 Repository 总表

| Repository | 负责 | 当前可适配来源 | 目标模块 |
| --- | --- | --- | --- |
| `AuthRepository` | 登录、注册、refresh、短信、会话恢复 | `SocialService` / auth methods | `Modules/Auth/Repositories/` |
| `UserRepository` | 用户资料、公开主页、关注列表、粉丝列表 | `SocialService`、`WebFeatureService` | `Modules/Profile/Repositories/` |
| `EventRepository` | 活动列表、详情、发布、lineup、timetable | `WebFeatureService`、Discover adapters | `Modules/Discover/Events/Repositories/` |
| `DJRepository` | DJ 列表、详情、关注、导入、外部搜索 | `WebFeatureService`、Discover adapters | `Modules/Discover/DJs/Repositories/` |
| `SetRepository` | Set 列表、详情、Tracklist、上传、评论 | `WebFeatureService`、Discover adapters | `Modules/Discover/Sets/Repositories/` |
| `WikiRepository` | Festival / Brand / Wiki 内容 | `WebFeatureService` | `Modules/Discover/Wiki/Repositories/` |
| `FeedRepository` | Feed、Post、点赞、收藏、转发、评论 | `SocialService`、`CircleFeedRepository` | `Modules/Feed/Repositories/` |
| `MessageRepository` | 会话、消息、已读、免打扰、聊天设置 | `SocialService`、`MessagesRepository` | `Modules/Messages/Repositories/` |
| `SquadRepository` | 小队、成员、邀请、线下活动、定位 | `SocialService` | `Modules/Squads/Repositories/` |
| `NotificationRepository` | 通知 inbox、未读、push token、偏好 | `SocialService` | `Modules/Notifications/Repositories/` |
| `CheckinRepository` | 打卡、MyCheckins、timeline、gallery、stats | `WebFeatureService` / future checkin client | `Modules/Checkins/Repositories/` |
| `VirtualAssetRepository` | 虚拟资产、装备、外观 | 已存在 `VirtualAssetRepository` | `Modules/VirtualAssets/Repositories/` |
| `ShareRepository` | 分享短链、二维码、打开埋点 | `ShareLinkService` | `Modules/Share/Repositories/` |
| `SearchRepository` | 全局搜索、最近搜索、搜索 telemetry | `WebFeatureService`、Search feature | `Modules/Search/Repositories/` |

## 5. Module 内部目标结构

每个模块目标结构：

```text
Modules/<Feature>/
  Views/
  ViewModels/
  Models/
  Repositories/
  UseCases/
  Coordinators/
  Components/
  Mappers/
```

迁移期可以保留现有 `Features/<Feature>` 目录。新文件应优先按目标结构放置，或在现有 Feature 下建立同名子目录。

## 6. ViewModel 依赖规则

目标：

```swift
final class EventDetailViewModel: ObservableObject {
    private let eventRepository: EventRepository
}
```

避免：

```swift
final class EventDetailViewModel: ObservableObject {
    private let webService: WebFeatureService
}
```

规则：

1. ViewModel 依赖 Repository protocol。
2. Repository implementation 可以暂时调用旧 service。
3. View 不直接调用 service。
4. View 不直接依赖 DTO。
5. DTO 到 ViewState 通过 mapper 或 ViewModel 转换。

## 7. 模型命名规则

| 类型 | 命名 | 用途 |
| --- | --- | --- |
| DTO | `EventDTO`、`FeedPostDTO` | 后端接口返回 |
| Domain Model | `Event`、`FeedPost` | App 内业务模型 |
| View State | `EventDetailViewState` | 页面展示状态 |
| Request | `CreatePostRequest` | API 请求体 |
| Mapper | `EventMapper` | DTO -> Domain / ViewState |

迁移期如果已有模型名字无法立即调整，先在新模块中避免继续扩大旧模型文件。

## 8. 旧 Service 迁移策略

### Step 1：建立 Repository Protocol

先为目标模块定义 protocol，不移动旧 service。

### Step 2：建立 Adapter

Adapter 内部调用旧 service：

```swift
struct EventRepositoryAdapter: EventRepository {
    let service: WebFeatureService
}
```

### Step 3：替换 ViewModel 依赖

ViewModel 从依赖 `WebFeatureService` 改为依赖 `EventRepository`。

### Step 4：拆分旧 Service

当某个领域调用全部迁移后，再把旧 service 中相关方法移动到独立 API client 或 repository implementation。

### Step 5：删除或降级旧入口

旧 service 最终只保留基础网络能力，或进入 `Legacy/`。

## 9. iOS 验证缓存规则

- iOS 编译验证使用固定 `-derivedDataPath /tmp/raver-xcodebuild-derived`。
- 默认保留 `/tmp/raver-xcodebuild-derived`，让 xcodebuild 复用增量编译缓存。
- 不把 DerivedData 当作普通临时文件清理；只有缓存损坏、需要验证 clean build 或用户明确要求时才删除。
- 其他一次性过程文件、日志导出、smoke test 临时文件仍应及时删除。

## 10. 当前优先迁移模块

| 优先级 | 模块 | 原因 |
| --- | --- | --- |
| P0 | Notifications | 边界清楚，后端也准备作为试点 |
| P0 | VirtualAssets | 已经有 Repository 形态 |
| P1 | Share | `ShareLinkService` 边界独立 |
| P1 | Messages | 已有 `MessagesRepository`，但 IM 复杂度高 |
| P1 | Feed | 已有 `CircleFeedRepository` |
| P2 | Squads | 涉及 IM 和 offline activity |
| P2 | Discover Events / DJs / Sets / Wiki | 当前聚合在 Discover，需要逐步拆细 |
| P3 | Auth / Profile | 影响全局状态，最后稳定收束 |

## 11. 禁止事项

- 不再新增新的巨型 `Service`。
- 不把新功能继续塞进 `Core/Models.swift`。
- 不让 View 直接调用 `SocialService` 或 `WebFeatureService`。
- 不在迁移 repository 时顺手重做 UI。
- 不在架构收束中新增产品外扩需求。

## 12. Phase 0 待办

- [ ] 为 Notifications 定义目标 repository protocol。
- [ ] 为 Share 定义 `ShareRepository`，并适配 `ShareLinkService`。
- [ ] 梳理 `WebFeatureService` 方法到 Event / DJ / Set / Wiki / Checkin / Search 的归属。
- [ ] 梳理 `SocialService` 方法到 Auth / User / Feed / Message / Squad / Notification 的归属。
