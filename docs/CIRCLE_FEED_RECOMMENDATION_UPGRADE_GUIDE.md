# 圈子 Feed 推荐系统改造指导（可执行版）

> 文档日期：2026-04-23  
> 适用端：iOS + BFF（`/v1`）  
> 目标页面：圈子 `Post` Feed（推荐/关注/最新）

## 1. 背景与目标

当前圈子 Feed 已经完成了第一轮“小红书式社区”基础能力：

- 推荐/关注/最新三模式切换。
- 收藏、分享、不感兴趣闭环。
- 推荐理由展示位。
- 隐藏内容过滤。

但推荐系统仍偏“规则排序 + 聚合计数驱动”，缺少高质量行为信号回流（曝光、点击、停留），导致策略优化空间受限。

本次改造目标是：

1. 先把“埋点回流闭环”补齐，形成数据基础设施。  
2. 在不破坏现有线上能力的前提下，为后续“多路召回 + 精排 + 实验”铺路。  
3. 全过程保持可灰度、可回滚、可观测。

## 2. 当前能力基线（代码落点）

### 2.1 Feed 排序与模式

- `GET /v1/feed`：[`server/src/routes/bff.routes.ts`]( /Users/blackie/Projects/raver/server/src/routes/bff.routes.ts )
- 入口：`router.get('/feed', ...)`（约 1999 行）
- 推荐模式打分：`freshnessScore + engagementScore`（约 2145 行）
- 推荐理由：`recommendationReasonCode/recommendationReason`（约 829 行）

### 2.2 互动能力

- 收藏：`POST/DELETE /v1/feed/posts/:id/save`
- 分享：`POST /v1/feed/posts/:id/share`
- 不感兴趣：`POST/DELETE /v1/feed/posts/:id/hide`
- 文件：[`server/src/routes/bff.routes.ts`]( /Users/blackie/Projects/raver/server/src/routes/bff.routes.ts )（约 4847、4936、4982 行）

### 2.3 iOS 展示与交互

- Feed 入口：[`mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift`]( /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift )
- ViewModel：[`mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift`]( /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift )
- 卡片组件：[`mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift`]( /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift )
- 详情页：[`mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift`]( /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift )

### 2.4 推送与通知中台

已具备可复用基础设施（本次不重造）：

- 路由：[`server/src/routes/notification-center.routes.ts`]( /Users/blackie/Projects/raver/server/src/routes/notification-center.routes.ts )
- 服务：[`server/src/services/notification-center/notification-center.service.ts`]( /Users/blackie/Projects/raver/server/src/services/notification-center/notification-center.service.ts )
- 定时任务启动：[`server/src/index.ts`]( /Users/blackie/Projects/raver/server/src/index.ts )

## 3. 总体改造路线（按优先级）

### Phase 1（本轮先落地）：埋点回流闭环

目标：让推荐系统有“曝光/点击/行为”可用数据。

- 新增 `feed_events` 表，记录 Feed 行为事件。
- 新增 `POST /v1/feed/events` 埋点写入接口（支持匿名/登录态）。
- iOS 在 Feed 与详情关键路径上报事件。

### Phase 2：候选召回升级（多路召回）

目标：把推荐从“单源候选”升级为“多源候选”。

- 召回源：关注作者、关注 DJ、热门内容、相似内容、搜索召回。
- 合并候选后进入统一重排。

### Phase 3：排序策略升级（精排 + 打散）

目标：避免内容同质化，提升 CTR 与互动率。

- 引入去重打散（作者打散、实体打散、时间窗打散）。
- 引入负反馈惩罚（`hide reason` 分层）。
- 引入探索流量（Explore Bucket）。

### Phase 4：实验与运营化

目标：让策略优化“低风险、可回放、可对比”。

- 权重配置化。
- A/B 分桶。
- 运营可视化看板与告警。

## 4. Phase 1 详细设计（本次要落地）

## 4.1 事件模型

事件类型（首期）：

- `feed_impression`：卡片曝光（进入可视区域一次）。
- `feed_open_post`：点击卡片进入详情。
- `feed_like`：点赞点击。
- `feed_save`：收藏点击。
- `feed_share`：分享完成。
- `feed_hide`：不感兴趣提交。

事件公共字段：

- `userId`（可空，游客为空）
- `sessionId`（客户端会话 id）
- `eventType`
- `postId`（可空，部分全局事件可无）
- `feedMode`（`recommended/following/latest`）
- `position`（卡片在当前列表索引）
- `metadata`（JSON，扩展字段）
- `createdAt`

## 4.2 数据库模型

新增 Prisma 模型：

```prisma
model FeedEvent {
  id        String   @id @default(uuid())
  userId    String?  @map("user_id")
  sessionId String   @map("session_id")
  eventType String   @map("event_type")
  postId    String?  @map("post_id")
  feedMode  String?  @map("feed_mode")
  position  Int?
  metadata  Json?
  createdAt DateTime @default(now()) @map("created_at")

  user User? @relation(fields: [userId], references: [id], onDelete: SetNull)
  post Post? @relation(fields: [postId], references: [id], onDelete: SetNull)

  @@index([userId, createdAt])
  @@index([postId, createdAt])
  @@index([eventType, createdAt])
  @@index([sessionId, createdAt])
  @@map("feed_events")
}
```

并在 `User`、`Post` 上补 relation：

- `feedEvents FeedEvent[]`

## 4.3 BFF 接口设计

### `POST /v1/feed/events`

鉴权：`optionalAuth`（支持游客）

请求：

```json
{
  "sessionId": "7b9d4f0f-0f6f-4e75-92ee-c2ef4f5d3f26",
  "eventType": "feed_impression",
  "postID": "post_xxx",
  "feedMode": "recommended",
  "position": 3,
  "metadata": {
    "source": "feed_card"
  }
}
```

响应：

```json
{ "success": true }
```

校验规则：

- `sessionId` 必填，长度 1~128。
- `eventType` 必须在允许集合。
- `feedMode` 仅允许 `recommended/following/latest`（可空）。
- `position` 允许空；非空时应为 `>= 0`。
- `postID` 非空时需存在对应 Post，否则 404。

失败处理：

- 客户端“埋点失败不影响主流程”。
- 服务端记录错误日志，返回语义化 4xx/5xx。

## 4.4 iOS 接入策略

### 服务层

在 `SocialService` 增加：

- `recordFeedEvent(input: FeedEventInput) async throws`

`LiveSocialService`：请求 `POST /v1/feed/events`。

`MockSocialService`：本地吞掉（或暂存内存数组）。

### 模型层

新增 `FeedEventInput`：

- `sessionID`
- `eventType`
- `postID`
- `feedMode`
- `position`
- `metadata`

### Feed 页接入点

- `FeedView` 卡片 `onAppear`：上报 `feed_impression`（同一 post 每个会话只报一次）。
- 点击卡片进入详情：上报 `feed_open_post`。
- 点赞/收藏/隐藏：上报对应行为事件。
- 分享完成：复用已有分享完成时机，上报 `feed_share`。

### 详情页接入点

- 详情页点赞/收藏/隐藏/分享完成，同步上报事件。

### 去重策略

- 维护 `reportedImpressionPostIDs` 集合，避免滚动反复上报。
- `sessionID` 在 `FeedViewModel` 初始化时生成，模式切换不重置（同一页面会话）。

## 4.5 可观测与验收

上线前检查：

1. DB 中 `feed_events` 有持续新增。  
2. 不登录状态也能写入匿名事件（`user_id` 为空）。  
3. 点击/点赞/收藏/隐藏/分享事件数量与行为日志趋势一致。  
4. 接口失败不会影响 Feed 主链路。

SQL 快查示例：

```sql
select event_type, count(*)
from feed_events
where created_at > now() - interval '1 day'
group by event_type
order by count(*) desc;
```

## 5. Phase 2~4 实施纲要（后续）

## 5.1 Phase 2（召回）

- 在 `/v1/feed?mode=recommended` 内部增加候选源：
  - follow-author
  - follow-dj
  - trending
  - similar-item（后续可接向量检索）
- 每路候选带 `recallSource`，进入统一重排。

## 5.2 Phase 3（精排）

- 打散规则：
  - 同作者窗口限制。
  - 同实体（DJ/活动）窗口限制。
- 负反馈：
  - `author` 原因隐藏提升作者惩罚。
  - `seen_too_often` 提升重复惩罚。

## 5.3 Phase 4（实验）

- 已落地：
  - 参数模板化：`control`、`engagement_heavy`、`freshness_heavy` 三套权重模板。
  - 稳定分桶：按 `userId hash` 固定桶（游客默认 `control`）。
  - 联调覆盖：支持 query 覆盖 `expBucket=control|engagement_heavy|freshness_heavy`。
  - 响应透出：`recommended` 返回 `rankingExperiment.bucket/weightsVersion`。
  - 观测接口：`GET /v1/feed/experiments/summary`（admin）返回分桶事件计数与 CTR/互动率。
  - 埋点增强：`POST /v1/feed/events` 在推荐模式自动追加 `experimentBucket/weightsVersion` 到 `metadata`。
- 当前可调环境变量：
  - `FEED_AB_ENABLED`（默认 `true`）
  - `FEED_AB_CONTROL_PERCENT`（默认 `40`）
  - `FEED_AB_ENGAGEMENT_PERCENT`（默认 `30`，其余落到 `freshness_heavy`）
- 后续指标目标：CTR、详情进入率、收藏率、7日回访率。

## 6. 风险与回滚

风险：

- 事件量提升导致写入压力上升。
- 客户端滚动曝光可能造成过量埋点。

应对：

- 首期仅关键事件；曝光做会话去重。
- 接口写失败不影响主功能。

回滚策略：

- 客户端可下发开关停止上报。
- 服务端保留接口但可短路写入。
- 不改动现有 Feed 排序主逻辑，保证可快速回退。

## 7. 本次改造文件清单（Phase 1）

后端：

- `server/prisma/schema.prisma`
- `server/prisma/migrations/*_add_feed_events/migration.sql`
- `server/src/routes/bff.routes.ts`

iOS：

- `mobile/ios/RaverMVP/RaverMVP/Core/Models.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/MockSocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift`

## 8. 里程碑验收标准

Phase 1 完成标准：

- 埋点表、迁移、接口、iOS 接入全部落地。
- 后端 `pnpm build` 通过。
- iOS 编译至少通过 Swift 编译阶段（若受本地三方库缺失导致链接失败，需记录原因）。
- 提供事件统计 SQL 与人工验证步骤。

## 9. 当前实现进度（2026-04-23）

- `Phase 1` 已落地：`feed_events` 模型、迁移、`POST /v1/feed/events`、iOS 埋点触点均已接入。
- `Phase 2` 已落地核心骨架：`recommended` 改为多路召回（关注作者 / 关注 DJ / 行为相似 / 热门）后统一重排。
- `Phase 3` 已落地基础策略：加入作者/实体打散、隐藏反馈惩罚、探索位注入（`explore` 推荐理由）。
- `Phase 4` 已落地首版：权重模板配置化 + 稳定 A/B 分桶（`control/engagement_heavy/freshness_heavy`），并在 `recommended` 响应返回实验信息。
- `Phase 4` 已补充观测：新增管理员实验汇总接口，可按时间窗口查看各桶曝光、打开、点赞、收藏、分享、隐藏及比率。

后续建议聚焦：实验指标看板 + 权重在线调参 + 小流量灰度发布流程。
