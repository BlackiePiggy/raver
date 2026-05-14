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
ProfileUserRepository
ProfileContentRepository
ProfileCheckinRepository
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

### 2.1 Infrastructure 归位规则

`Infrastructure/` 用于承载 SDK、存储、缓存、日志、外部服务 adapter 等非页面业务能力。它不是新的业务模块，也不应该承接 ViewModel 编排。

当前 Phase 4 主线：

```text
Infrastructure/
  TencentIM/
    TencentIMIdentity.swift
    IMChatStore.swift
    ChatMessageSearchIndex.swift
    IMProbeLogger.swift
    IMStorageGovernance.swift
    Session/
      TencentIMSession.swift
    Media/
      ChatMediaTempFileStore.swift
      RaverChatMediaResolver.swift
  LegacyOpenIM/
    README.md
    IMSession.swift
```

约束：

- Tencent IM 当前主线能力进入 `Infrastructure/TencentIM/`。
- OpenIM 历史兼容能力进入 `Infrastructure/LegacyOpenIM/`，不再扩展新业务能力。
- `TencentIMSession` 位于 `Infrastructure/TencentIM/Session`；`AppState` 只持有 session 入口并负责应用状态 / bootstrap 协调。
- `TencentIMIdentity` 位于 `Infrastructure/TencentIM`，负责平台用户 / Squad ID 与 Tencent IM user/group ID 的转换。
- `Infrastructure` 不直接依赖具体页面 View；业务页面通过 Repository / Coordinator / Store 使用基础设施能力。

### 2.2 UIKit Chat 收束规则

`Features/Messages/UIKitChat/` 当前仍是迁移期 UIKit / SwiftUI 混合聊天实现，允许保留在 feature 内，但需要持续减少单个 View 文件承载协议、解析、路由、媒体、状态同步的情况。

当前 Phase 4 主线：

```text
Features/Messages/UIKitChat/
  ChatCardRouteTarget.swift
  ChatCustomCardCodec.swift
  RaverChatController.swift
  RaverChatDataProvider.swift
  TencentUIKitChatView.swift
```

约束：

- `ChatCardRouteTarget` 表达聊天自定义卡片点击后的业务路由目标，避免在 `TencentUIKitChatView` 内继续散落裸 `kind/id/perform` 逻辑。
- `ChatCustomCardCodec` 表达 IM 消息里真实传输的 custom card wire protocol；它和 `Features/Messages/CustomCards/ChatCustomCardRegistry.swift` 的产品登记状态不是同一个概念，不能混用命名或 raw value。
- `RaverChatDataProvider` / `ChatMessageRepository` 只承接消息传输、读取、typing、撤回、删除和业务卡片发送，不承接会话列表、聊天设置、Squad activity 或分享入口。
- 后续 custom card preview / renderer / registry 应继续从 `TencentUIKitChatView` 拆出，但不得顺手新增卡片类型、推荐逻辑或 UI 重设计。

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
| `ProfileUserRepository` | 当前用户资料、公开主页、关注列表、好友列表、follow toggle、头像上传、资料更新 | `SocialService`、`ProfileUserRepositoryAdapter` | `Modules/Profile/Repositories/` |
| `ProfileContentRepository` | 用户动态、互动历史、MySaves、MyPublishes、发布物删除 | `SocialService`、`WebFeatureService`、`ProfileContentRepositoryAdapter` | `Modules/Profile/Content/Repositories/` |
| `ProfileCheckinRepository` | 用户打卡列表、MyCheckins v2 overview/timeline/gallery、删除打卡 | `WebFeatureService`、`ProfileCheckinRepositoryAdapter` | `Modules/Checkins/Repositories/` |
| `UserRepository` | 旧命名候选；新代码优先用 `ProfileUserRepository` | `SocialService`、`WebFeatureService` | 后续删除或改名 |
| `EventListRepository` | 活动列表、分页、筛选 | `WebFeatureService`、`EventListRepositoryAdapter` | `Modules/Discover/Events/Repositories/` |
| `EventRecommendationRepository` | 推荐活动读取和 fallback 候选读取入口 | `WebFeatureService`、`EventRecommendationRepositoryAdapter` | `Modules/Discover/Events/Repositories/` |
| `EventReadRepository` | 活动详情读取 | `WebFeatureService`、`EventReadRepositoryAdapter` | `Modules/Discover/Events/Repositories/` |
| `EventCommandRepository` | 活动创建、编辑、删除 | `WebFeatureService`、`EventCommandRepositoryAdapter` | `Modules/Discover/Events/Repositories/` |
| `EventMediaRepository` | 活动封面、banner、lineup 图片导入等媒体能力 | `WebFeatureService`、`EventMediaRepositoryAdapter` | `Modules/Discover/Events/Repositories/` |
| `EventLiveDiscussionRepository` | 活动现场讨论评论读取、发布、点赞 | `SocialService`、`EventLiveDiscussionRepositoryAdapter` | `Modules/Discover/Events/Repositories/` |
| `EventDiscussionMediaRepository` | 活动讨论图片上传 | `WebFeatureService`、`EventMediaRepositoryAdapter` | `Modules/Discover/Events/Repositories/` |
| `RatingRepository` | rating event / rating unit 列表、读取、创建、编辑、删除、评论提交、封面上传、活动关联 rating 读取 | `WebFeatureService`、`RatingRepositoryAdapter` | `Modules/Ratings/Repositories/` |
| `EventCheckinRepository` | 活动标记、活动打卡、出勤打卡读取/创建/更新/删除 | `WebFeatureService`、`EventCheckinRepositoryAdapter` | `Modules/Checkins/Repositories/` |
| `EventRelatedContentRepository` | 活动关联 Set、后续关联内容读取 | `WebFeatureService`、`EventRelatedContentRepositoryAdapter` | `Modules/Discover/Events/Repositories/` |
| `DJListRepository` | DJ 列表、搜索、排序分页 | `WebFeatureService`、`DJListRepositoryAdapter` | `Modules/Discover/DJs/Repositories/` |
| `DJReadRepository` | DJ 详情读取 | `WebFeatureService`、`DJReadRepositoryAdapter` | `Modules/Discover/DJs/Repositories/` |
| `DJLinkedContentRepository` | DJ 关联 Set、活动、RatingUnit、我的 DJ 打卡数 | `WebFeatureService`、`DJLinkedContentRepositoryAdapter` | `Modules/Discover/DJs/Repositories/` |
| `DJRelationRepository` | DJ 关注 / 取消关注 | `WebFeatureService`、`DJRelationRepositoryAdapter` | `Modules/Discover/DJs/Repositories/` |
| `DJCommandRepository` | DJ 编辑 | `WebFeatureService`、`DJCommandRepositoryAdapter` | `Modules/Discover/DJs/Repositories/` |
| `DJRankingRepository` | Ranking boards 与榜单详情 | `WebFeatureService`、`DJRankingRepositoryAdapter` | `Modules/Rankings/Repositories/` |
| `DJImportRepository` | Spotify / Discogs / Manual DJ 搜索与导入 | `WebFeatureService`、`DJImportRepositoryAdapter` | `Modules/Discover/DJs/Repositories/` |
| `DJMediaRepository` | DJ 头像、封面等媒体上传 | `WebFeatureService`、`DJMediaRepositoryAdapter` | `Modules/Discover/DJs/Repositories/` |
| `SetListRepository` | Set 列表、排序分页、按 DJ 过滤 | `WebFeatureService`、`SetListRepositoryAdapter` | `Modules/Discover/Sets/Repositories/` |
| `SetReadRepository` | Set 详情读取 | `WebFeatureService`、`SetReadRepositoryAdapter` | `Modules/Discover/Sets/Repositories/` |
| `SetCommentRepository` | Set 评论读取与发布 | `WebFeatureService`、`SetCommentRepositoryAdapter` | `Modules/Discover/Sets/Repositories/` |
| `SetCommandRepository` | Set 创建、编辑、删除 | `WebFeatureService`、`SetCommandRepositoryAdapter` | `Modules/Discover/Sets/Repositories/` |
| `SetMediaRepository` | Set 封面 / 视频上传、视频预解析 | `WebFeatureService`、`SetMediaRepositoryAdapter` | `Modules/Discover/Sets/Repositories/` |
| `TracklistRepository` | Tracklist 列表、详情、创建、替换、自动链接 | `WebFeatureService`、`TracklistRepositoryAdapter` | `Modules/Discover/Sets/Repositories/` |
| `SetEventLookupRepository` | Set 绑定活动时的活动搜索 | `WebFeatureService`、`SetEventLookupRepositoryAdapter` | `Modules/Discover/Sets/Repositories/` |
| `WikiRepository` | Festival / Brand / Wiki 内容 | `WebFeatureService` | `Modules/Discover/Wiki/Repositories/` |
| `FeedStreamRepository` | Feed 流、分页、event-scoped feed | `SocialService`、`FeedStreamRepositoryAdapter` | `Modules/Feed/Repositories/` |
| `PostReadRepository` | 动态详情读取 | `SocialService`、`PostReadRepositoryAdapter` | `Modules/Feed/Repositories/` |
| `PostCommandRepository` | 发帖、编辑、删除 | `SocialService`、`PostCommandRepositoryAdapter` | `Modules/Feed/Repositories/` |
| `PostInteractionRepository` | 点赞、收藏、转发、隐藏、关注作者、分享统计 | `SocialService`、`PostInteractionRepositoryAdapter` | `Modules/Feed/Repositories/` |
| `PostCommentRepository` | 评论树读取与新增评论 | `SocialService`、`PostCommentRepositoryAdapter` | `Modules/Feed/Repositories/` |
| `PostMediaRepository` | 动态图片 / 视频上传 | `WebFeatureService`、`PostMediaRepositoryAdapter` | `Modules/Feed/Repositories/` |
| `FeedEventTrackingRepository` | Feed impression/open/like/save/share/hide 埋点 | `SocialService`、`FeedEventTrackingRepositoryAdapter` | `Modules/Feed/Repositories/` |
| `ConversationRepository` | 会话列表、会话置顶/隐藏、已读/未读、发起私聊 | `SocialService`、旧 `MessagesRepository` | `Modules/Messages/Repositories/` |
| `MessageNotificationRepository` | 消息通知、关注对象 inbox、未读入口 | `SocialService`、旧 `MessagesRepository` | `Modules/Messages/Repositories/` |
| `ChatMessageRepository` | 单个聊天窗口的消息拉取、发送、媒体消息、卡片消息、撤回、删除、已读、typing | `SocialService` via adapter | `Modules/Messages/Repositories/` |
| `ChatSettingsRepository` | 直聊设置、群聊资料、群成员、邀请设置 | `SocialService` via adapter | `Modules/Messages/Repositories/` |
| `SquadRepository` | 小队基础资料、成员、邀请 | `SocialService` | `Modules/Squads/Repositories/` |
| `SquadActivityRepository` | 小队线下活动生命周期、参与状态、活动邀请 | `SocialService` | `Modules/Squads/Repositories/` |
| `LocationSyncRepository` | 小队线下活动定位上传 | `SocialService` | `Modules/Squads/Repositories/` |
| `NotificationRepository` | 通知 inbox、未读、push token、偏好 | `SocialService` | `Modules/Notifications/Repositories/` |
| `CheckinRepository` | 打卡、MyCheckins、timeline、gallery、stats | `WebFeatureService` / future checkin client | `Modules/Checkins/Repositories/` |
| `VirtualAssetRepository` | 虚拟资产、装备、外观 | 已存在 `VirtualAssetRepository` | `Modules/VirtualAssets/Repositories/` |
| `ShareRepository` | 分享短链、二维码、打开埋点 | `ShareLinkService` | `Modules/Share/Repositories/` |
| `SearchRepository` | 全局搜索、最近搜索、搜索 telemetry | `WebFeatureService`、Search feature | `Modules/Search/Repositories/` |

## 4.1 Fat Repository 治理规则

Phase 3 的首要目标是让页面和 ViewModel 先脱离 `SocialService` / `WebFeatureService`。因此允许出现短期过渡型 repository adapter，但它们不能成为新的长期巨型对象。

以下情况出现任意两项时，该 repository 必须标记为拆分候选：

- 一个 repository 超过 25 个业务方法。
- 同时代理 `SocialService` 和 `WebFeatureService`，并且暴露多个业务域能力。
- 方法名覆盖 3 个以上领域名词，例如 profile、checkin、rating、event。
- 同时服务 3 个以上独立页面，并且页面之间不是同一业务域。
- repository 内开始出现跨领域编排逻辑，而不是简单转发旧 client。

拆分原则：

- Repository 按领域拥有数据访问能力，不按页面堆方法。
- 跨多个 repository 的页面流程放到 UseCase / Coordinator / ViewModel 组合层，不把编排塞进某一个 repository。
- 过渡 adapter 可以包旧 service，但 protocol 名必须表达目标领域。
- 新增能力优先进入目标小 repository，不继续扩大已经偏胖的过渡 repository。

新增方法准入规则：

- 如果方法只属于一个领域，进入该领域 repository，例如 `fetchDJ` 进入 DJ repository，`fetchDJSet` 进入 Set repository。
- 如果方法属于独立业务名词，但当前没有小 repository，先记录目标 repository，再决定是否允许短期放入过渡 adapter。
- 如果方法需要同时调用两个以上 repository，不放进 repository，改放 UseCase。
- 如果只是为了页面方便而把无关方法塞进同一个 repository，禁止合入。
- 如果新增方法会让某个过渡 repository 第三次跨域，必须同步在 tracker 写明拆分目标和后续 Phase。

当前拆分候选与目标归属：

| 当前过渡 repository | 已承载能力 | 后续拆分方向 |
| --- | --- | --- |
| `ProfileSocialRepository` | 已移除的过渡组合协议；仅作为历史迁移记录出现 | 已拆为 `ProfileUserRepository`、`ProfileContentRepository`、`ProfileCheckinRepository` |
| `DiscoverEventsRepository` | 已移除的过渡组合协议；仅作为历史迁移记录出现 | 已拆为 Event list/recommendation/read/command/media/discussion/checkin/related content 小 repository |
| `DiscoverDJsRepository` | 已移除的过渡组合协议；仅作为历史迁移记录出现 | 已拆为 DJ list/read/linked content/relation/command/ranking/import/media 小 repository |
| `DiscoverSetsRepository` | 已移除的过渡组合协议；仅作为历史迁移记录出现 | 已拆为 Set list/read/comment/command/media、Tracklist、Set event lookup 小 repository |
| `SquadProfileRepository` | squad profile、squad manage、avatar/flag upload | `SquadRepository`、`SquadMediaRepository`，IM/offline activity 留到 Phase 4 |
| `MessagesRepository` | conversations、message notifications、followed event/DJ/brand inbox、start direct conversation | Phase 4 已拆成 `ConversationRepository`、`MessageNotificationRepository`、`ChatSettingsRepository`、`ChatMessageRepository` |
| `ChatSettingsRepository` | direct settings、group settings、member management、invite settings | 后续按 direct settings / group settings / member management 继续拆小 |
| `ChatMessageRepository` | chat message transport、read、typing | 保持只做消息主线；不要承接会话列表、设置、Squad activity、分享入口或 custom card registry |
| `CircleFeedRepository` | 已移除的过渡组合协议；仅作为历史迁移记录出现 | 已拆为 FeedStream/PostRead/PostCommand/PostInteraction/PostComment/PostMedia/FeedEventTracking 小 repository |
| `ShareMessageRepository` | in-app card message sending | 保持为消息分享边界；post card 发送归这里，post share 统计仍归 `PostInteractionRepository` |

Phase 3 结束条件不是把所有过渡 repository 都拆干净，而是：

- 页面和 ViewModel 不再直接依赖巨型 service。
- 每个偏胖 repository 都在 tracker 中有拆分候选记录。
- 新增迁移不继续扩大偏胖 repository，除非是清除页面直连所需的短期适配。

当前执行约束：

- Phase 5 Feed 首刀只做协议边界和调用方依赖收窄，不做数据库迁移、不做物理目录大搬迁、不新增推荐 / 举报 / 商业化能力。
- Feed 已完成小 adapter physical split；`CircleFeedRepository` 已从 active code 移除，页面和 ViewModel 新增依赖必须选 Feed / Post 小协议。
- Feed 内的 IM 分享发送不归 Feed repository；`sendPostCardMessage` 归 `ShareMessageRepository`，`recordShare` 归 `PostInteractionRepository`。
- Phase 5 Events 已完成小 adapter physical split；`DiscoverEventsRepository` 已从 active code 移除，页面和 ViewModel 新增依赖必须选 `EventListRepository` / `EventReadRepository` / `EventCommandRepository` / `EventMediaRepository` / `EventLiveDiscussionRepository` / `EventCheckinRepository` 等小协议。
- `EventDetailView` 这类超大页面本批只收窄 repository getter，不做页面组件大拆分；`EventEditorView` 内部按 command/media/list/checkin 小协议访问，Learn 关联活动和 Squad 活动选择按 `EventListRepository` 访问。
- Rating 创建、读取、编辑、删除和封面上传归 `RatingRepository`；不要再引入 event-scoped rating 兼容命名，也不要挂回 `DiscoverEventsRepository` 或 Profile 侧 repository。
- 活动打卡/标记归 `EventCheckinRepository`，现场讨论归 `EventLiveDiscussionRepository`，活动详情读取归 `EventReadRepository`。
- Rating 的 IM 卡片分享仍归 `ShareMessageRepository`，不要把消息发送能力塞进 `RatingRepository`。
- Profile first cut 已拆出 `ProfileUserRepository`、`ProfileContentRepository`、`ProfileCheckinRepository`；页面和 ViewModel 新增依赖必须选小协议，不再直接声明 `ProfileSocialRepository`。
- Profile adapter physical split 已完成：`ProfileUserRepositoryAdapter` 只持有 `SocialService`，`ProfileContentRepositoryAdapter` 持有 `SocialService` + `WebFeatureService`，`ProfileCheckinRepositoryAdapter` 只持有 `WebFeatureService`。
- Rating editor 已归 `RatingRepository`，不得再把 rating image upload / rating update 能力放回 Profile adapter。
- Music 已完成小 adapter physical split；`DiscoverDJsRepository` / `DiscoverSetsRepository` 已从 active code 移除，页面和 ViewModel 新增依赖必须选 DJ / Set 小协议。
- DJ 榜单归 `DJRankingRepository`，DJ 外部导入归 `DJImportRepository`，Set 歌单归 `TracklistRepository`，Set 媒体归 `SetMediaRepository`，不要恢复 `DiscoverDJsRepository` / `DiscoverSetsRepository` 这类组合协议。
- Profile 编辑入口加载活动 / Set 时，优先复用 `EventReadRepository` / `SetReadRepository`，不再回退到 `WebFeatureService` 或宽组合 repository。
- Circle ID 的 DJ / Event picker 分别复用 `DJListRepository` / `EventListRepository`。
- Rating 创建和编辑的 Phase 3 过渡挂载已结束；Phase 5 后新增或迁移的 rating 能力必须直接进入 `RatingRepository`。
- IM、ChatSettings、UIKit chat、presence、location、Squad offline activity 不在 Phase 3 继续塞入通用 repository，进入 Phase 4 的 realtime / IM 边界重建。

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
| P1 | Feed | 已拆为 Feed / Post 小 repository |
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
