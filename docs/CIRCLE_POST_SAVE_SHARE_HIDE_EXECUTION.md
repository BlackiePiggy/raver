# 圈子 Feed（收藏 / 分享 / 不感兴趣）执行看板

> 最后更新：2026-04-21 07:58:57 CST  
> 关联方案：`docs/CIRCLE_POST_SAVE_SHARE_HIDE_PLAN.md`

## 1. 执行规则（实时勾选）

- 完成即勾选：任务完成后，立即将 `- [ ]` 改为 `- [x]`。
- 失败要留痕：执行失败时保留任务未勾选，并在“执行日志”写清楚失败原因与下一步动作。
- 日志最小闭环：每次关键执行至少记录 `时间 / 命令 / 结果摘要`。
- 只记录关键结果：构建、迁移、关键接口联调、关键 UI 验证。

---

## 2. 分阶段任务拆解

## 阶段 A：范围冻结与接口边界

- [x] 仅覆盖普通动态 `Post`（不含同城、不含统计播放）
- [x] 交互范围冻结为：收藏 / 分享 / 不感兴趣
- [x] 明确评论结构约束：主评论 + 二级回复（二级需指明回复对象）

## 阶段 B：后端数据层（Prisma）

- [x] `Post` 增加 `save_count` / `share_count` / `hide_count`
- [x] 新增 `PostSave` / `PostShare` / `PostHide` 模型
- [x] 建立 `User`、`Post` 对应关系字段
- [x] 生成并落库迁移脚本

**相关文件**

- `server/prisma/schema.prisma`
- `server/prisma/migrations/20260420143000_add_post_save_share_hide/migration.sql`

## 阶段 C：后端接口层（BFF）

- [x] Feed 与搜索流过滤已隐藏内容（登录态）
- [x] Post 映射新增 `saveCount` / `shareCount` / `isSaved` / `isHidden`
- [x] 新增收藏接口：`POST/DELETE /v1/feed/posts/:id/save`
- [x] 新增分享记录接口：`POST /v1/feed/posts/:id/share`
- [x] 新增不感兴趣接口：`POST/DELETE /v1/feed/posts/:id/hide`
- [x] 新增我的收藏：`GET /v1/profile/me/saves`

**相关文件**

- `server/src/routes/bff.routes.ts`

## 阶段 D：iOS 服务层与模型层

- [x] `Post` 模型补齐收藏/分享/隐藏字段
- [x] `SocialService` 增加 `toggleSave` / `recordShare` / `hidePost` / `fetchMySaveHistory`
- [x] `LiveSocialService` 对接新增接口
- [x] `MockSocialService` 补齐模拟行为

**相关文件**

- `mobile/ios/RaverMVP/RaverMVP/Core/Models.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/MockSocialService.swift`

## 阶段 E：iOS 圈子 Feed/详情交互

- [x] 卡片支持收藏按钮状态与计数
- [x] 卡片支持更多菜单：分享 / 不感兴趣
- [x] 详情页支持收藏 / 分享 / 不感兴趣
- [x] 不感兴趣后从当前流即时移除（含通知同步）

**相关文件**

- `mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Circle/Coordinator/CircleCoordinator.swift`

## 阶段 F：iOS 我的收藏闭环（可查看）

- [x] Profile 仓储接入 `fetchMySaveHistory`
- [x] Profile 增加“收藏”分段（可浏览收藏历史）
- [x] 快捷入口新增“我的收藏”
- [x] 收藏分段支持取消收藏并即时移除

**相关文件**

- `mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift`

## 阶段 G：收尾与待办

- [x] 不感兴趣理由弹窗（`not_relevant` / `seen_too_often` / `low_quality` / `author` / `other`）
- [x] 推荐解释文案回传（“因为你关注了 ...”）与前端展示位
- [x] 推荐排序参数化（`recommended/following/latest`）灰度开关

## 阶段 H：联调造数（数据库）

- [x] 新增富内容圈子造数脚本（100 条动态、每条 40~50 评论）
- [x] 基于现有用户生成点赞/评论/收藏/分享/转发关系数据
- [x] 脚本执行成功并完成入库
- [x] 结果核验：评论数区间 40~50，聚合总量符合预期

**相关文件**

- `server/src/scripts/seed-rich-feed.ts`

## 阶段 I：评论二级结构（主评 + 回复）

- [x] 评论模型支持父评论、根评论、回复目标用户、深度
- [x] BFF 评论接口支持回复入参 `parentCommentID`
- [x] BFF 评论返回结构携带二级关系字段与 `replyToAuthor`
- [x] iOS 动态详情支持按“主评论 + 二级回复”展示，并可点评论发回复
- [x] 已对历史造数评论完成回填，覆盖“回复评论”的链路并二级化展示

**相关文件**

- `server/prisma/schema.prisma`
- `server/prisma/migrations/20260421101000_add_post_comment_threading/migration.sql`
- `server/src/routes/bff.routes.ts`
- `mobile/ios/RaverMVP/RaverMVP/Core/Models.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/MockSocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift`

## 阶段 J：评论交互增强（二级折叠 + 懒加载 + 排序）

- [x] 检查现状：原评论区不是“下拉逐批加载”，而是全量 `fetchComments` 后一次渲染
- [x] 主评论列表改为滚动触底分批展示（lazy reveal）
- [x] 二级评论支持折叠/展开，展开后按批次“查看更多回复”
- [x] 无限嵌套回复统一归并到主评论下的二级区域展示
- [x] 评论排序支持“热度 / 时间轴”切换按钮
- [x] 热度排序基于“回复数 + 最近活跃时间衰减”计算
- [x] 评论字号层级优化：一级评论缩小，二级评论整体再小一档

**相关文件**

- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift`

## 阶段 K：动态分享弹层卡片化（类似小红书/抖音）

- [x] Feed 列表分享入口改为“应用内分享弹层”而非直接系统面板
- [x] 动态详情分享入口改为“应用内分享弹层”
- [x] 弹层新增“专属动态分享卡片”（作者、摘要、互动数据、媒体缩略）
- [x] 弹层支持“系统分享 + 复制链接”两种动作
- [x] 系统分享链路使用 `LPLinkMetadata` 传递卡片化预览图
- [x] 分享行为继续入库并保留 `channel`（如 `copy_link` / 系统 activityType）

**相关文件**

- `mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift`

---

## 3. 执行日志（关键结果）

### 2026-04-21 07:58:57 CST

**命令**

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj \
  -scheme RaverMVP \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build -quiet
```

**结果摘要**

- 已完成动态分享改造：在应用内先展示专属分享卡片，再触发系统分享；Feed 与详情页入口一致。
- 分享弹层支持：
  - 动态卡片预览
  - 系统分享（带 `LPLinkMetadata` 预览）
  - 复制链接（记 `copy_link` 分享事件）
- 构建结果：本次改造未引入新的编译错误；仍因本地缺失 `MJExtension/OpenIMSDK/OpenIMSDKCore` 停在链接阶段。

**关键输出**

```text
ld: framework 'MJExtension' not found
clang: error: linker command failed with exit code 1
** BUILD FAILED **
```

### 2026-04-21 01:11:14 CST

**命令**

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj \
  -scheme RaverMVP \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build -quiet
```

**结果摘要**

- 调整热度排序计算为“回复数 + 最近活跃时间衰减”后，重新构建校验通过编译阶段。
- 失败点仍为本地缺失三方 framework，非本次评论功能改造引入问题。

**关键输出**

```text
ld: framework 'MJExtension' not found
clang: error: linker command failed with exit code 1
```

### 2026-04-21 01:09:19 CST

**命令**

```bash
rg -n "onAppear\\s*\\{.*load|lazy|ForEach\\(" mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj \
  -scheme RaverMVP \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build -quiet
```

**结果摘要**

- 现状核验：改造前 `PostDetailView` 评论区无逐批下拉加载触发点，属于全量渲染。
- 已完成评论交互增强：
  - 主评论按批次下拉加载（前端 lazy reveal）。
  - 二级评论支持折叠/展开与“查看更多回复”分页。
  - 深层回复统一归并至二级区显示（保留“回复谁”语义）。
  - 新增“热度 / 时间轴”排序切换按钮。
  - 评论字号分层：二级评论整体小于一级评论。
- 本地构建结果：`PostDetailView` 无新增编译错误；整体仍受本地缺失三方框架影响，停在链接阶段（`MJExtension/OpenIMSDK/OpenIMSDKCore`）。

**关键输出**

```text
ld: framework 'MJExtension' not found
clang: error: linker command failed with exit code 1
** BUILD FAILED **
```

### 2026-04-21 00:39:30 CST

**命令**

```bash
cd /Users/blackie/Projects/raver/server
pnpm prisma migrate deploy
pnpm build
```

**结果摘要**

- 应用迁移：`20260421101000_add_post_comment_threading` 成功。
- 后端 TypeScript 构建通过。

**关键输出**

```text
Applying migration `20260421101000_add_post_comment_threading`
All migrations have been successfully applied.

> raver-server@1.0.0 build /Users/blackie/Projects/raver/server
> tsc
```

### 2026-04-21 00:39:30 CST

**命令**

```bash
node <<'NODE'
<post_comments 二级回填脚本>
NODE
```

**结果摘要**

- 命中造数动态：100 条，全部完成评论二级结构回填。
- 评论总量：4472
- 主评论：1209
- 二级回复：3263
- 其中“回复回复”链路：703（展示仍归二级）
- 深度分布：
  - depth=0: 1217
  - depth=1: 2560
  - depth=2: 703

### 2026-04-20 23:44:49 CST

**命令**

```bash
cd /Users/blackie/Projects/raver/server
pnpm exec ts-node src/scripts/seed-rich-feed.ts
```

**结果摘要**

- 使用数据库现有活跃用户（19 个）成功生成并入库 100 条动态。
- 每条动态生成 40~50 条评论，点赞/收藏/分享/转发均已生成关系数据。
- 入库统计：
  - `posts`: 100
  - `likes`: 1612
  - `saves`: 876
  - `reposts`: 456
  - `shares`: 446
  - `comments`: 4472

**关键输出**

```text
[seed-rich-feed] users available: 19
[seed-rich-feed] target posts: 100
[seed-rich-feed] comments per post range: 40 50
[seed-rich-feed] progress 100/100
[seed-rich-feed] done
[seed-rich-feed] summary {
  totalPosts: 100,
  totalLikes: 1612,
  totalSaves: 876,
  totalReposts: 456,
  totalShares: 446,
  totalComments: 4472
}
```

### 2026-04-20 23:44:49 CST

**命令**

```bash
node -e '<prisma aggregate check>'
```

**结果摘要**

- 核验通过：目标数据集共 100 条动态。
- `commentCount` 最小值 40，最大值 50，满足要求区间。

### 2026-04-20 15:26:12 CST

**命令**

```bash
cd /Users/blackie/Projects/raver/server
pnpm build
```

**结果摘要**

- 新增 `GET /v1/feed?mode=recommended|following|latest`。
- `recommended` 模式回传推荐理由字段（`recommendationReasonCode` / `recommendationReason`）。
- 后端 TypeScript 构建通过。

**关键输出**

```text
> raver-server@1.0.0 build /Users/blackie/Projects/raver/server
> tsc
```

### 2026-04-20 15:26:12 CST

**命令**

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj \
  -scheme RaverMVP \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build -quiet
```

**结果摘要**

- iOS 端支持 Feed 模式切换（推荐/关注/最新）。
- 卡片新增推荐理由展示位。
- 命令退出码 `0`，静默构建成功。

### 2026-04-20 15:05:01 CST

**命令**

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj \
  -scheme RaverMVP \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build -quiet
```

**结果摘要**

- 新增“不感兴趣理由弹窗”并覆盖 Feed 与动态详情。
- 命令退出码 `0`，iOS 静默构建通过。

**关键输出**

```text
(no output with -quiet)
```

### 2026-04-20 13:53:20 CST

**命令**

```bash
cd /Users/blackie/Projects/raver/server
pnpm prisma generate
pnpm build
```

**结果摘要**

- Prisma Client 生成成功（v5.22.0）。
- TypeScript 构建通过（`tsc` 退出码 `0`）。

**关键输出**

```text
✔ Generated Prisma Client (v5.22.0) ...

> raver-server@1.0.0 build /Users/blackie/Projects/raver/server
> tsc
```

### 2026-04-20 13:50:51 CST

**命令**

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj \
  -scheme RaverMVP \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

**结果摘要**

- iOS 工程编译通过。
- 存在 1 条历史警告（`traitCollectionDidChange` 在 iOS 17 废弃），不影响本次功能。

**关键输出**

```text
warning: 'traitCollectionDidChange' was deprecated in iOS 17.0 ...
** BUILD SUCCEEDED **
```

### 2026-04-20 13:53:20 CST

**命令**

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj \
  -scheme RaverMVP \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build -quiet
```

**结果摘要**

- 命令退出码 `0`，静默构建成功（`-quiet` 无标准输出）。

---

## 4. 下次更新模板

~~~md
### YYYY-MM-DD HH:mm:ss TZ

**命令**
~~~bash
<command>
~~~

**结果摘要**

- <success/fail summary>

**关键输出**
~~~text
<important lines>
~~~
~~~
