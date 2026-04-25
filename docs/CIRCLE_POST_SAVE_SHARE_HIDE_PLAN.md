# 圈子 Post 收藏、分享、不感兴趣落地方案

> 状态：执行中（看板见 `docs/CIRCLE_POST_SAVE_SHARE_HIDE_EXECUTION.md`）  
> 优先级：P0 推荐流基础互动  
> 首期客户端：iOS  
> 范围：只覆盖普通动态 `Post` 的收藏、分享、不感兴趣，不覆盖 ID、打分、小队动态、活动资讯混排。  
> 目标：为圈子推荐流补齐强正反馈、传播反馈和负反馈，让后续推荐算法可以从单一时间排序升级为个性化排序。

## 1. 已确认需求

### 1.1 产品边界

- 圈子“小红书类型”本阶段主要指推荐算法，不要求第一期做视觉双列瀑布流。
- 推荐流只放普通动态 `Post`。
- 游客可以看推荐流和评论，但收藏、分享记录、不感兴趣等用户行为需要登录后才能沉淀到账号。
- 不做同城/附近推荐。
- 不统计视频播放、完播率、停留时长。
- 内容安全和举报治理上线前必须具备，但本方案只实现“不感兴趣”负反馈；举报、屏蔽、审核后台应作为并行必备能力单独落地。

### 1.2 评论约束

评论后续采用：

```text
主评论 + 二级回复
```

二级回复必须指明“谁回复谁”，例如：

```text
Alice：这个现场太炸了
Bob 回复 Alice：确实，drop 那段很强
Charlie 回复 Bob：你说的是第二首吗？
```

该评论能力不在本文实施范围内，但接口和推荐计分应继续使用 `commentCount` 作为互动信号。

## 2. 当前基础

### 2.1 已有能力

后端已经具备：

- `Post`：正文、媒体 URL、定位、绑定 DJ/厂牌/活动、点赞数、转发数、评论数。
- `PostLike`：点赞关系。
- `PostRepost`：转发关系。
- `PostComment`：普通评论。
- `GET /v1/feed`：当前按 `createdAt desc` 返回。
- `POST/DELETE /v1/feed/posts/:id/like`
- `POST/DELETE /v1/feed/posts/:id/repost`

iOS 已经具备：

- `FeedView` / `FeedViewModel`：动态列表和分页。
- `PostCardView`：卡片展示、点赞、转发、评论数。
- `PostDetailView`：动态详情、评论输入。
- `ComposePostView`：发布/编辑动态，支持最多 9 个图/视频。

### 2.2 缺口

当前缺少：

- 动态收藏关系和收藏数。
- 分享行为记录和分享数。
- 不感兴趣负反馈。
- Feed 返回当前用户是否已收藏。
- 推荐排序对收藏、分享、不感兴趣的使用。
- iOS 卡片上的收藏、分享、更多菜单。
- 个人主页或“我的”里的收藏动态入口。

## 3. 产品定义

### 3.1 收藏

收藏是强正反馈，用于：

- 用户后续在“我的收藏”查看。
- 推荐算法提升类似内容、类似作者、类似绑定 DJ/厂牌/活动的权重。
- 内容热度排序。

行为规则：

- 未登录用户点击收藏：提示登录。
- 已登录用户点击收藏：立即乐观更新 UI，失败后回滚。
- 同一用户对同一 Post 只能收藏一次。
- 再次点击取消收藏。
- 作者可以收藏自己的动态，默认允许，降低规则复杂度。

### 3.2 分享

分享是传播反馈，用于：

- 调起 iOS 系统分享面板。
- 后端记录分享行为，用于推荐和内容热度。
- 可选生成深链，后续支持从外部打开动态详情。

行为规则：

- 游客也可以调起系统分享。
- 登录用户分享成功后记录 `PostShare`。
- 未登录用户分享可以只调起系统面板，不强制登录；如果后端要统计匿名分享，可以记录匿名事件，但第一期不建议做。
- 只有分享面板完成后才记录分享；如果系统无法可靠判断完成状态，则在打开分享面板时记录一次 `intent`，完成回调时记录 `completed`。

### 3.3 不感兴趣

不感兴趣是负反馈，用于：

- 当前 Feed 立即移除该 Post。
- 后续推荐降低该 Post、作者、绑定实体、内容标签的权重。
- 不等同于举报，不触发审核处罚。

行为规则：

- 未登录用户点击不感兴趣：可以本地从当前列表移除，但不沉淀到账号；建议提示“登录后可优化推荐”。
- 已登录用户点击：后端记录，当前列表移除。
- 同一用户对同一 Post 只保留一条 hide 记录。
- 不感兴趣后，`recommended` 流不再返回该 Post；`latest` 流可选择继续隐藏，建议全模式隐藏，避免用户刚点完又看到。
- 提供理由选项，但理由不是必填。

首期理由：

```text
not_relevant      不感兴趣
seen_too_often    总是刷到
low_quality       内容质量低
author            不想看这个作者
other             其他
```

## 4. 数据库设计

### 4.1 Post 扩展字段

在 `Post` 增加聚合计数字段：

```prisma
model Post {
  // existing fields...
  saveCount   Int @default(0) @map("save_count")
  shareCount  Int @default(0) @map("share_count")
  hideCount   Int @default(0) @map("hide_count")

  saves       PostSave[]
  shares      PostShare[]
  hides       PostHide[]
}
```

说明：

- `saveCount` 用于卡片展示和热度排序。
- `shareCount` 用于热度排序，首期不一定展示。
- `hideCount` 不展示，只用于降权和风控观察。

### 4.2 PostSave

```prisma
model PostSave {
  id        String   @id @default(uuid())
  postId    String   @map("post_id")
  userId    String   @map("user_id")
  createdAt DateTime @default(now()) @map("created_at")

  post      Post     @relation(fields: [postId], references: [id], onDelete: Cascade)
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([postId, userId])
  @@index([postId])
  @@index([userId])
  @@index([createdAt])
  @@map("post_saves")
}
```

### 4.3 PostShare

```prisma
model PostShare {
  id        String   @id @default(uuid())
  postId    String   @map("post_id")
  userId    String?  @map("user_id")
  channel   String?  // system, copy_link, wechat, moments, etc.
  status    String   @default("completed") // intent, completed
  createdAt DateTime @default(now()) @map("created_at")

  post      Post     @relation(fields: [postId], references: [id], onDelete: Cascade)
  user      User?    @relation(fields: [userId], references: [id], onDelete: SetNull)

  @@index([postId])
  @@index([userId])
  @@index([createdAt])
  @@map("post_shares")
}
```

说明：

- 分享可以允许 `userId` 为空，用于未来匿名统计。
- 第一阶段 BFF 可以只允许登录记录；游客只做系统分享，不写库。
- `channel` 首期可以传 `system`。

### 4.4 PostHide

```prisma
model PostHide {
  id        String   @id @default(uuid())
  postId    String   @map("post_id")
  userId    String   @map("user_id")
  reason    String?  // not_relevant, seen_too_often, low_quality, author, other
  note      String?  @db.Text
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  post      Post     @relation(fields: [postId], references: [id], onDelete: Cascade)
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([postId, userId])
  @@index([postId])
  @@index([userId])
  @@index([reason])
  @@index([createdAt])
  @@map("post_hides")
}
```

### 4.5 User 关系补充

在 `User` 增加：

```prisma
postSaves  PostSave[]
postShares PostShare[]
postHides  PostHide[]
```

### 4.6 迁移文件建议

新增 migration：

```text
server/prisma/migrations/YYYYMMDDHHMMSS_add_post_save_share_hide/migration.sql
```

SQL 方向：

```sql
ALTER TABLE "posts"
  ADD COLUMN IF NOT EXISTS "save_count" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "share_count" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "hide_count" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS "post_saves" (...);
CREATE TABLE IF NOT EXISTS "post_shares" (...);
CREATE TABLE IF NOT EXISTS "post_hides" (...);
```

如果已有线上数据，迁移后执行一次计数回填：

```sql
UPDATE "posts" p
SET "save_count" = COALESCE(s.count, 0)
FROM (
  SELECT "post_id", COUNT(*)::int AS count
  FROM "post_saves"
  GROUP BY "post_id"
) s
WHERE p.id = s."post_id";
```

分享和不感兴趣同理。新表刚上线通常为空，可以不回填。

## 5. API 设计

### 5.1 Feed 返回字段扩展

`mapPost` 返回新增字段：

```json
{
  "saveCount": 12,
  "shareCount": 3,
  "isSaved": true,
  "isHidden": false
}
```

`isHidden` 通常不会返回 `true`，因为已隐藏内容应被 Feed 过滤；保留字段方便详情页和调试。

### 5.2 收藏接口

```text
POST   /v1/feed/posts/:id/save
DELETE /v1/feed/posts/:id/save
GET    /v1/profile/me/saves?cursor=&limit=
```

`POST /save`：

- 需要登录。
- 如果 Post 不存在，返回 404。
- 如果已经收藏，保持幂等，直接返回最新 Post。
- 成功后 `saveCount + 1`。

`DELETE /save`：

- 需要登录。
- 如果没有收藏，保持幂等，直接返回最新 Post。
- 成功删除后 `saveCount - 1`，用 `updateMany where saveCount > 0` 防止负数。

### 5.3 分享接口

```text
POST /v1/feed/posts/:id/share
```

请求：

```json
{
  "channel": "system",
  "status": "completed"
}
```

规则：

- 登录用户写入 `PostShare`。
- 如果未来需要匿名统计，可允许无登录写入匿名事件，但第一期建议 require auth，减少垃圾数据。
- 每次分享都记录一条，不做唯一约束。
- `status = completed` 时 `shareCount + 1`。
- `status = intent` 可只记录事件，不增加 `shareCount`。

响应：

```json
{
  "success": true,
  "shareCount": 4
}
```

也可以直接返回完整 `Post`，与点赞/转发接口保持一致。为了 iOS 替换方便，建议返回完整 `Post`。

### 5.4 不感兴趣接口

```text
POST   /v1/feed/posts/:id/hide
DELETE /v1/feed/posts/:id/hide
```

请求：

```json
{
  "reason": "not_relevant",
  "note": ""
}
```

`POST /hide`：

- 需要登录。
- 幂等 upsert。
- 第一次隐藏时 `hideCount + 1`。
- 已隐藏再次提交只更新 reason/note，不重复加计数。

`DELETE /hide`：

- 首期可以不做 UI，但接口建议保留，方便未来“撤销”。
- 删除 hide 记录后 `hideCount - 1`，防止负数。

响应：

```json
{
  "success": true,
  "hiddenPostId": "post_id"
}
```

### 5.5 Feed 过滤规则

`GET /v1/feed` 查询时，如果 viewer 已登录：

```typescript
where: {
  visibility: 'public',
  squadId: null,
  hides: {
    none: { userId: viewerId }
  }
}
```

如果游客：

- 不使用后端隐藏过滤。
- iOS 可以维护本地 `hiddenPostIds`，仅当前设备过滤。

### 5.6 推荐流模式预留

虽然本文只实现三个行为，但 API 应为推荐流预留：

```text
GET /v1/feed?mode=recommended
GET /v1/feed?mode=latest
GET /v1/feed?mode=following
```

第一期可以这样处理：

- `recommended`：规则排序。
- `latest`：原 `createdAt desc`。
- `following`：关注用户动态。

本方案新增的三个行为主要服务 `recommended`。

## 6. 后端实现计划

### 6.1 Prisma Schema

修改：

```text
server/prisma/schema.prisma
```

内容：

- `Post` 增加 `saveCount/shareCount/hideCount`。
- `Post` 增加 `saves/shares/hides` relations。
- `User` 增加 `postSaves/postShares/postHides` relations。
- 新增 `PostSave/PostShare/PostHide` models。

执行：

```bash
cd server
pnpm prisma generate
pnpm prisma migrate dev --name add_post_save_share_hide
```

如果项目当前用 npm/yarn，以实际包管理器为准。

### 6.2 BFF 工具函数

在 `server/src/routes/bff.routes.ts` 增加：

```typescript
const buildSavedPostMap = async (viewerId: string | undefined, postIds: string[]) => {}
const buildHiddenPostMap = async (viewerId: string | undefined, postIds: string[]) => {}
```

更新 `mapPost` 参数：

```typescript
const mapPost = (
  post,
  followingSet,
  likedPostIds,
  repostedPostIds,
  savedPostIds,
  hiddenPostIds
) => ({
  // existing...
  saveCount: post.saveCount,
  shareCount: post.shareCount,
  hideCount: post.hideCount, // 不建议客户端展示，可不返回
  isSaved: savedPostIds.has(post.id),
  isHidden: hiddenPostIds.has(post.id),
})
```

对外响应建议不返回 `hideCount`，除非管理后台需要。

### 6.3 更新所有 Post hydrate 路径

需要同步更新这些接口，避免字段缺失导致 iOS decode 失败：

- `GET /v1/feed`
- `GET /v1/feed/search`
- `GET /v1/feed/posts/:id`
- `POST /v1/feed/posts`
- `PATCH /v1/feed/posts/:id`
- `POST/DELETE /like`
- `POST/DELETE /repost`
- `GET /v1/users/:id/posts`
- `GET /v1/profile/me/likes`
- `GET /v1/profile/me/reposts`
- 新增 `GET /v1/profile/me/saves`

### 6.4 收藏事务

伪代码：

```typescript
router.post('/feed/posts/:id/save', optionalAuth, async (req, res) => {
  const userId = requireAuth(req as BFFAuthRequest, res);
  if (!userId) return;

  const postId = req.params.id;
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
  if (!post) return res.status(404).json({ error: 'Post not found' });

  await prisma.$transaction(async (tx) => {
    const existing = await tx.postSave.findUnique({
      where: { postId_userId: { postId, userId } },
    });

    if (!existing) {
      await tx.postSave.create({ data: { postId, userId } });
      await tx.post.update({
        where: { id: postId },
        data: { saveCount: { increment: 1 } },
      });
    }
  });

  return res.json(await hydratePostForViewer(postId, userId));
});
```

建议提取 `hydratePostForViewer(postId, viewerId)`，减少 like/repost/save 三类接口重复代码。

### 6.5 分享事务

```typescript
router.post('/feed/posts/:id/share', optionalAuth, async (req, res) => {
  const userId = requireAuth(req as BFFAuthRequest, res);
  if (!userId) return;

  const channel = normalizeShareChannel(req.body.channel);
  const status = normalizeShareStatus(req.body.status);

  await prisma.$transaction(async (tx) => {
    await tx.postShare.create({
      data: { postId, userId, channel, status },
    });

    if (status === 'completed') {
      await tx.post.update({
        where: { id: postId },
        data: { shareCount: { increment: 1 } },
      });
    }
  });

  return res.json(await hydratePostForViewer(postId, userId));
});
```

首期 channel 白名单：

```typescript
const allowedChannels = new Set(['system', 'copy_link', 'wechat', 'moments', 'other']);
```

### 6.6 不感兴趣事务

```typescript
router.post('/feed/posts/:id/hide', optionalAuth, async (req, res) => {
  const userId = requireAuth(req as BFFAuthRequest, res);
  if (!userId) return;

  const reason = normalizeHideReason(req.body.reason);
  const note = normalizeHideNote(req.body.note);

  await prisma.$transaction(async (tx) => {
    const existing = await tx.postHide.findUnique({
      where: { postId_userId: { postId, userId } },
    });

    if (existing) {
      await tx.postHide.update({
        where: { id: existing.id },
        data: { reason, note },
      });
    } else {
      await tx.postHide.create({
        data: { postId, userId, reason, note },
      });
      await tx.post.update({
        where: { id: postId },
        data: { hideCount: { increment: 1 } },
      });
    }
  });

  res.json({ success: true, hiddenPostId: postId });
});
```

### 6.7 推荐排序使用

推荐分第一期不做复杂模型，先在候选池内规则排序：

```text
baseScore =
  likeCount * 1
+ commentCount * 3
+ repostCount * 4
+ saveCount * 5
+ shareCount * 4
- hideCount * 8
+ freshnessScore
+ authorFollowBoost
+ interestMatchBoost
```

行为权重解释：

- 收藏比点赞更强，说明用户愿意以后再看。
- 分享和转发都强，但分享可能代表外部传播。
- 不感兴趣是强负反馈，对该内容和相似内容都应降权。

首期可以先只保证：

- 已隐藏 Post 不返回。
- `hideCount` 高的 Post 全局降权。
- `saveCount/shareCount` 高的 Post 升权。

## 7. iOS 实现计划

### 7.1 Models

修改：

```text
mobile/ios/RaverMVP/RaverMVP/Core/Models.swift
```

`Post` 增加：

```swift
var saveCount: Int
var shareCount: Int
var isSaved: Bool
```

是否加 `isHidden`：

- Feed 普通列表不需要展示。
- 如果为了调试和详情状态一致，可以加 `var isHidden: Bool = false`。

注意：`Post` 是 `Codable`，所有 mock 数据也要补字段，否则编译或 decode 会失败。

### 7.2 SocialService

修改：

```text
mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift
mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift
mobile/ios/RaverMVP/RaverMVP/Core/MockSocialService.swift
```

新增协议：

```swift
func toggleSave(postID: String, shouldSave: Bool) async throws -> Post
func recordShare(postID: String, channel: String, status: String) async throws -> Post
func hidePost(postID: String, reason: String?) async throws
func fetchMySaveHistory(cursor: String?) async throws -> ActivityPostPage
```

Live 实现：

```swift
func toggleSave(postID: String, shouldSave: Bool) async throws -> Post {
    try await request(
        path: "/v1/feed/posts/\(postID)/save",
        method: shouldSave ? "POST" : "DELETE"
    )
}

func recordShare(postID: String, channel: String, status: String) async throws -> Post {
    try await request(
        path: "/v1/feed/posts/\(postID)/share",
        method: "POST",
        body: ["channel": channel, "status": status]
    )
}

func hidePost(postID: String, reason: String?) async throws {
    let body = ["reason": reason ?? "not_relevant"]
    let _: GenericSuccessResponse = try await request(
        path: "/v1/feed/posts/\(postID)/hide",
        method: "POST",
        body: body
    )
}
```

### 7.3 PostCardView

修改：

```text
mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift
```

新增入参：

```swift
let onSaveTap: (() -> Void)?
let onShareTap: (() -> Void)?
let onMoreTap: (() -> Void)?
```

互动区建议变为：

```text
喜欢 | 评论 | 收藏 | 分享 | 更多
```

如果空间不足：

```text
喜欢 | 评论 | 收藏 | 更多
```

分享放在“更多”菜单里也可以。推荐首期卡片直接展示收藏，分享和不感兴趣放更多菜单。

更多菜单：

```swift
Menu {
    Button {
        onShareTap?()
    } label: {
        Label(LL("分享"), systemImage: "square.and.arrow.up")
    }

    Button(role: .destructive) {
        onHideTap?()
    } label: {
        Label(LL("不感兴趣"), systemImage: "eye.slash")
    }
} label: {
    Image(systemName: "ellipsis")
}
```

### 7.4 FeedViewModel

修改：

```text
mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift
```

新增：

```swift
func toggleSave(post: Post) async
func hide(post: Post, reason: String?) async
func mergeSharedPost(_ post: Post)
```

逻辑：

- 收藏：调用 API 后 `replace(updated)`。
- 分享：分享面板成功回调后调用 `recordShare`，再 `replace(updated)`。
- 不感兴趣：先从 `posts` 移除，接口失败时可以恢复原位置，或者提示失败后刷新。

推荐实现：

```swift
func hide(post: Post, reason: String?) async {
    guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
    let removed = posts.remove(at: index)
    do {
        try await repository.hidePost(postID: post.id, reason: reason)
    } catch {
        posts.insert(removed, at: min(index, posts.count))
        self.error = error.userFacingMessage
    }
}
```

游客本地隐藏：

- 如果 `appState.session == nil`，可以不走 API，直接 `posts.remove`。
- 记录到 `UserDefaults` 的 `circle.feed.localHiddenPostIds.v1`，下次刷新继续过滤。

### 7.5 分享面板

项目里已有系统分享能力可参考活动路线分享。如果没有通用组件，新增：

```swift
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let completion: ((Bool) -> Void)?
}
```

分享内容首期：

```text
\(post.author.displayName) 在 Raver 发布了一条动态：
\(post.content.prefix(80))
https://raver.app/posts/\(post.id)
```

如果正式域名未定，先用：

```text
AppConfig.webBaseURL/posts/:id
```

或只分享文本，不阻塞功能上线。

分享回调：

```swift
completionWithItemsHandler = { _, completed, _, _ in
    completion?(completed)
}
```

只有 `completed == true` 时调用 `recordShare(status: "completed")`。

### 7.6 PostDetailView

详情页也要同步支持：

- 收藏按钮。
- 分享按钮。
- 不感兴趣入口。

因为用户可能从搜索、个人主页、通知进入详情页，不能只在 Feed 卡片支持。

详情页隐藏后的行为：

- 点击不感兴趣后返回上一页。
- 通过 NotificationCenter 通知 Feed 移除对应 Post。

建议新增通知：

```swift
.circlePostDidSaveUpdate
.circlePostDidHide
```

或复用现有 `.circlePostDidUpdate`，隐藏使用 `.circlePostDidDelete` 不合适，因为内容并未删除。

### 7.7 我的收藏入口

在“我的”或“我的发布”附近新增：

```text
我的收藏
```

页面数据：

```text
GET /v1/profile/me/saves
```

列表复用 `PostCardView`。

空状态：

```text
暂无收藏动态
看到喜欢的内容，点收藏后会出现在这里
```

## 8. 推荐算法接入方式

本阶段不要求完整推荐系统，但要保证新增行为能被未来排序使用。

### 8.1 当前可立即生效

推荐流查询时：

- 排除用户自己隐藏的 Post。
- 高 `hideCount` 内容全局降权。
- 高 `saveCount/shareCount` 内容升权。

### 8.2 用户兴趣更新

收藏：

```text
提升作者权重
提升 boundDjIDs 权重
提升 boundBrandIDs 权重
提升 boundEventIDs 权重
提升文本标签/风格词权重
```

分享：

```text
略低于收藏或接近收藏
提升内容热度
提升作者传播权重
```

不感兴趣：

```text
降低该 Post
降低作者权重
降低绑定实体权重
如果 reason = author，则显著降低作者
如果 reason = seen_too_often，则降低重复作者/重复实体频率
```

### 8.3 推荐解释

虽然本方案暂不实现“推荐解释”，但数据上应支持未来展示：

```text
因为你收藏过 Techno 相关动态
因为你常看这个 DJ 的内容
因为你关注的人也收藏了
```

收藏和分享是推荐解释的重要来源；不感兴趣只用于过滤和降权，不向用户展示具体算法细节。

## 9. 安全与治理要求

用户已确认上线前必须具备内容安全。本文只实现“不感兴趣”，但必须注意：

```text
不感兴趣 != 举报
不感兴趣不进入审核队列
举报必须单独设计
```

首期至少需要并行具备：

- 动态举报。
- 评论举报。
- 作者屏蔽或拉黑。
- 管理员隐藏/删除动态。
- 管理员隐藏/删除评论。
- 敏感词基础拦截。

不感兴趣的 `reason = low_quality` 只能作为内容质量信号，不能替代举报。

## 10. 埋点与日志

虽然不做视频统计，但应记录基础业务日志，方便排查：

- save create/delete。
- share completed。
- hide create/update/delete。
- API 错误日志。
- Feed 返回条数和过滤条数。

建议日志不要记录用户输入全文；`PostHide.note` 如果未来开放文本说明，需要纳入敏感信息处理。

## 11. 测试清单

### 11.1 后端

- 未登录收藏返回 401。
- 收藏不存在 Post 返回 404。
- 重复收藏不重复增加 `saveCount`。
- 取消未收藏 Post 不报错，`saveCount` 不变负数。
- 分享 completed 增加 `shareCount`。
- 分享 intent 不增加 `shareCount`。
- 不感兴趣第一次增加 `hideCount`。
- 重复不感兴趣只更新 reason，不重复增加 `hideCount`。
- 已隐藏 Post 不出现在 `GET /v1/feed?mode=recommended`。
- `GET /v1/profile/me/saves` 分页正确。
- 删除 Post 后 save/share/hide 级联删除。

### 11.2 iOS

- Feed 卡片收藏状态正确。
- 收藏乐观更新成功。
- 收藏失败回滚或提示。
- 分享面板可打开。
- 分享完成后数量更新。
- 取消分享不记录 completed。
- 不感兴趣后当前卡片立即消失。
- 游客点击收藏提示登录。
- 游客点击不感兴趣本地移除。
- 详情页收藏/分享/不感兴趣与 Feed 状态同步。
- 我的收藏列表可加载更多。

### 11.3 回归

- 点赞、转发、评论数不受影响。
- 发帖、编辑、删除不受影响。
- 搜索结果 Post decode 不失败。
- 个人主页 Post decode 不失败。
- 通知跳转详情不失败。

## 12. 分阶段实施

### Phase 1：数据库和 BFF

1. 新增 Prisma models 和 migration。
2. 更新 `mapPost` 返回 `saveCount/shareCount/isSaved`。
3. 新增收藏接口。
4. 新增分享接口。
5. 新增不感兴趣接口。
6. Feed 过滤 hidden posts。
7. 新增我的收藏列表接口。

### Phase 2：iOS 基础交互

1. 更新 `Post` model。
2. 更新 `SocialService`、`LiveSocialService`、`MockSocialService`。
3. `PostCardView` 增加收藏和更多菜单。
4. `FeedViewModel` 增加收藏/分享/隐藏逻辑。
5. `PostDetailView` 增加同等入口。
6. 分享面板接入。

### Phase 3：个人收藏和状态同步

1. 增加“我的收藏”页面。
2. 收藏/隐藏状态通过 NotificationCenter 同步到 Feed、详情、个人页、搜索页。
3. 游客本地隐藏缓存。

### Phase 4：推荐排序接入

1. `recommended` mode 使用 save/share/hide 权重。
2. 保留 `latest` 作为时间排序兜底。
3. 添加推荐排序调试日志。
4. 后续再接推荐解释、话题、瀑布流等能力。

## 13. 建议文件改动范围

后端：

```text
server/prisma/schema.prisma
server/prisma/migrations/*_add_post_save_share_hide/migration.sql
server/src/routes/bff.routes.ts
```

iOS：

```text
mobile/ios/RaverMVP/RaverMVP/Core/Models.swift
mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift
mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift
mobile/ios/RaverMVP/RaverMVP/Core/MockSocialService.swift
mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift
mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift
mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift
mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift
mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift
```

可选新增：

```text
mobile/ios/RaverMVP/RaverMVP/Features/Profile/SavedPostsView.swift
mobile/ios/RaverMVP/RaverMVP/Shared/ActivityShareSheet.swift
```

## 14. 验收标准

上线验收必须满足：

- 普通 `Post` 可收藏、取消收藏。
- 普通 `Post` 可调起系统分享，登录用户分享完成后服务端记录。
- 普通 `Post` 可标记不感兴趣，标记后推荐流不再出现。
- `GET /v1/feed` 返回收藏状态，不破坏现有点赞/转发/评论。
- 游客可以继续浏览 Feed 和详情。
- 游客不能写入账号级收藏/隐藏/分享记录。
- iOS Feed、详情、搜索、个人主页使用同一套 Post decode，不出现字段缺失崩溃。
- 删除动态后相关收藏、分享、不感兴趣记录自动清理。
- 推荐排序至少使用 `saveCount/shareCount/hideCount` 做基础升降权。

## 15. 暂不做事项

本方案不做：

- 瀑布流 UI。
- 媒体元数据表。
- 视频封面生成。
- 推荐解释展示。
- 热门话题。
- 同城/附近。
- 活动现场内容。
- 视频播放统计/完播率。
- ID、打分、小队动态混排。
- 评论二级回复实现。
- 举报审核完整后台。

这些能力可以在收藏、分享、不感兴趣稳定后继续推进。
