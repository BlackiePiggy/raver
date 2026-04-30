# Raver App 端后端概述（给后端工程师）

> 更新时间：2026-04-28  
> 适用范围：**仅聚焦 App 端**  
> 当前结论：**Web 端可以视为历史残留 / 废弃方向，不作为本次架构讨论重点**  
> 代码基线：基于当前仓库中 `server/`、`mobile/ios/RaverMVP/`、`mobile/flutter_raver_android/` 的现状整理

---

## 1. 这份文档的目的

我自己不擅长后端架构设计，所以希望把当前项目用工程语言讲清楚，方便后端工程师快速理解：

1. 这个项目从 App 用户视角到底在做什么
2. 当前后端真实落地成了什么样子
3. App 端实际上依赖哪些后端能力
4. 哪些地方已经有明确技术方向，哪些地方仍然需要架构建议

这份文档的目标不是 PRD，也不是数据库逐表说明，而是一份**面向后端架构讨论的项目上下文说明**。

---

## 2. 一句话说明项目

**Raver 是一个面向电子音乐爱好者的 App-first 平台。**

它不是单纯的活动列表工具，而是试图把下面几类能力放到同一个产品里：

1. 活动 / Festival / 演出发现与信息管理
2. DJ / 厂牌 / 曲风 / Set / Wiki 内容沉淀
3. 用户社区、动态 Feed、评论、关注、互动
4. 小队（Squad）和群聊关系
5. 私聊 / 群聊 / 推送通知
6. Check-in、评分、歌单、预报名等参与型功能

如果从用户心智上说，它更像：

- 一个电子音乐垂类内容社区
- 加上活动工具
- 再加上群组和聊天

而不是一个“网站 + 管理后台”的项目。

---

## 3. 产品范围：只看 App，不看 Web

### 3.1 当前我们真正关心的客户端

当前应该把系统理解为：

1. **iOS App 是当前主客户端**
2. **Android Flutter 版本计划复用同一套 BFF / 后端能力**
3. **Web 端不是核心方向，可以视为废弃或历史残留**

因此，这次和后端工程师讨论架构时，重点应该是：

- App 的登录体验
- App 的 Feed / 内容页
- App 的聊天和群组
- App 的通知和推送
- App 的媒体上传
- App 的内容模型与社交模型

而不是传统网站页由、SSR、SEO、CMS 之类话题。

### 3.2 一个容易混淆但很重要的点

仓库里有 `web/` 目录，也有 `LiveWebFeatureService` 这种命名，但它**不代表 Web 是当前产品核心**。

当前实际情况更像是：

- `SocialService` 承担 App 里的社交、聊天、通知、用户关系
- `WebFeatureService` 这个名字虽然历史上偏 “web”，但实际上在 iOS App 中承担了活动、DJ、Set、评分、Wiki 等“内容域”的 BFF 访问

也就是说，**App 端已经在实际消费大量 `/v1/*` 能力**，只是部分命名还保留着历史痕迹。

---

## 4. 从 App 用户视角，这个产品主要在做什么

下面这部分是最适合先让后端工程师建立业务理解的。

### 4.1 用户注册、登录、恢复会话

App 支持：

1. 用户名 + 密码登录
2. 手机号 + 短信验证码登录
3. 注册并自动登录
4. App 启动后基于 refresh token 恢复会话
5. 登录后拉取聊天 bootstrap 和个人态数据

这意味着后端不仅有“登录接口”，还要承担：

- access token / refresh token 生命周期管理
- 多端会话恢复
- 短信验证码发送和校验
- 登录后关联初始化动作

### 4.2 Feed / 社区

App 内有一个典型的社区流：

1. 查看推荐 / 关注 / 最新动态流
2. 搜索动态
3. 发动态
4. 编辑 / 删除动态
5. 点赞 / 取消点赞
6. 收藏 / 取消收藏
7. 转发 / 取消转发
8. 分享埋点
9. 不感兴趣隐藏
10. 评论、回复评论

这说明系统里不仅有内容存储，还存在：

- feed 排序模式
- 社交互动关系
- 行为埋点 / feed event
- 用户对内容的私有状态（like/save/hide/repost）

### 4.3 用户关系与个人主页

App 有比较完整的用户关系链：

1. 搜索用户
2. 查看用户主页
3. 关注 / 取消关注
4. 看某用户的动态
5. 看粉丝 / 关注 / 好友
6. 看自己的 like / repost / save 历史
7. 编辑自己的 profile 和头像

所以从后端视角看，这里不是简单 `users` 表，而是：

- 用户主资料
- follow graph
- profile privacy / 展示信息
- 用户主页聚合
- 行为历史查询

### 4.4 小队（Squad）和基于小队的社交

App 的一个明显产品特征是 squad：

1. 推荐小队
2. 我的小队
3. 查看小队详情
4. 加入小队
5. 离开小队
6. 解散小队
7. 创建小队
8. 上传小队头像
9. 修改我的小队设置
10. 队长 / 管理员管理小队资料
11. 修改成员角色
12. 移除成员

产品上，小队既是社交组织单位，也是聊天群体的来源之一。

这会直接影响后端设计：

- squad 是不是业务主实体
- squad 成员关系是不是权限源
- squad 与 IM 群是否 1:1 映射
- squad 生命周期如何同步到 IM

### 4.5 聊天与会话

聊天在 App 中不是附属功能，而是核心链路之一：

1. 登录后会获取 IM bootstrap
2. App 内可以拉取会话列表
3. 可以区分 direct / group conversation
4. 可以标记已读
5. 可以设置免打扰
6. 可以清空历史
7. 可以发起新私聊
8. 可以拉取历史消息
9. 可以发送文本、图片、视频、语音

当前代码基线显示：**聊天底层已经明确转向 Tencent IM**。

这意味着：

- Raver 后端不是自己实现消息实时分发
- Raver 后端是业务权威源和 IM 编排层
- 腾讯 IM 提供会话、收发、同步、未读等能力

### 4.6 通知与推送

App 已有一套明确的通知中心逻辑：

1. 拉取通知 inbox
2. 拉取未读数
3. 按通知项标记已读
4. 按通知类型批量标记已读
5. 注册设备 push token
6. 注销 / 失效设备 push token

通知类型从代码和数据模型看，不只包含点赞评论这类社区消息，还包括：

1. 社区互动
2. 聊天消息
3. 活动倒计时提醒
4. 每日活动摘要
5. 路线 / DJ 提醒
6. 关注 DJ 更新
7. 关注厂牌更新
8. 可能的运营 / 重大消息

因此通知中心更像一个**独立子系统**，而不是简单的 `notifications` 列表接口。

### 4.7 活动 / Festival 内容域

App 还有很重的活动内容域：

1. 查看活动列表
2. 推荐活动
3. 查看活动详情
4. 查看我发布的活动
5. 创建 / 编辑 / 删除活动
6. 上传活动图片
7. 从阵容图导入 lineup

活动模型里不仅有基础字段，还包含：

- 时间、地点、票档
- 阵容与排班
- 多语言字段
- 地理位置
- 外链和社媒链接
- 状态（upcoming / ongoing / ended / cancelled）

这部分说明系统不是单纯社交 App，而是强内容+结构化数据驱动的产品。

### 4.8 DJ / Set / Tracklist / 音乐内容域

App 里还有比较完整的 DJ 与 Set 体系：

1. DJ 列表与详情
2. DJ 关注状态与关注操作
3. 通过 Spotify / Discogs / SoundCloud 搜索补全 DJ 信息
4. 导入 DJ
5. 编辑 DJ
6. 上传 DJ 图片
7. 查看某 DJ 关联的 Sets 和 Events
8. DJ Set 列表、详情、我的 Sets
9. 创建 / 编辑 / 删除 DJ Set
10. 上传缩略图和视频
11. 维护 tracklist
12. 自动关联 tracks
13. 评论 Set

这意味着后端包含：

- UGC + 半结构化音乐数据
- 第三方音乐信息抓取 / 补全
- 资源上传
- 内容审核 / 数据质量问题

### 4.9 Check-in、评分、Wiki / Learn

App 里还有参与型和知识型模块：

1. Check-in
2. 打分事件 / 打分单位 / 评论
3. Learn Genres
4. Learn Labels
5. Learn Festivals
6. Rankings
7. My Publishes

这些说明平台目标并不只是“聊天 + feed”，而是在往电子音乐垂类社区平台走。

---

## 5. 当前后端真实落地形态

### 5.1 不是微服务，而是一个逐渐变大的业务单体

当前后端主服务可以理解为：

```text
Node.js + Express + TypeScript
Prisma + PostgreSQL
单一主服务进程
同时承载：
  - App BFF
  - 核心业务 API
  - 聊天编排
  - 通知中心
  - 定时任务
  - 媒体上传
```

也就是说，当前不是拆分后的架构，而是一个**App-first 的业务单体**。

### 5.2 当前主入口

服务主入口在：

- `server/src/index.ts`

从这里能看到它在一个进程里同时挂载了：

- `/api/*` 旧接口
- `/v1/*` 新 BFF / App 接口
- `/v1/im/tencent/*` IM 相关接口
- `/v1/notification-center/*` 通知中心接口

同时启动时还会直接拉起多个 scheduler / worker：

- event countdown scheduler
- daily digest scheduler
- route DJ reminder scheduler
- followed DJ update scheduler
- followed brand update scheduler
- notification outbox worker

这说明当前后端不只是“API Server”，还承担了**后台任务执行器**角色。

### 5.3 当前最应该被看作主线的接口层

如果只看 App，应该把 `/v1/*` 当成主线。

`/api/*` 可以看作历史阶段产物，至少在 App 侧不应该再作为未来主要契约。

### 5.4 当前持久化与外部依赖

当前主要依赖包括：

1. **PostgreSQL**：主数据库
2. **Prisma**：ORM 与 schema 入口
3. **腾讯云 IM**：聊天底层设施
4. **APNS**：iOS 推送投递
5. **短信服务**：当前代码里支持阿里云短信 / mock
6. **OSS / 本地 uploads**：媒体资源存储

这意味着后端同时面对三类状态：

1. 主业务数据状态
2. 外部 IM 系统状态
3. 推送 / 媒体 / 短信等外围系统状态

---

## 6. 当前 App 端后端能力的结构化拆分

为了便于讨论架构，我建议把当前系统拆成下面几个逻辑域来看。

### 6.1 Auth 域

主要职责：

1. 注册
2. 密码登录
3. 短信验证码登录
4. refresh token 刷新
5. logout / logout-all
6. 用户会话恢复

App 侧重要特点：

1. App 启动时会尝试恢复 session
2. refresh token 是一等公民，不是附属功能
3. 登录成功后，后续还要衔接 IM bootstrap 和 profile 状态

这部分已经不是“简单 JWT”那么轻了，而是会话系统。

### 6.2 Social / Feed 域

主要职责：

1. feed 获取与分页
2. 推荐 / 关注 / 最新模式
3. 动态创建 / 编辑 / 删除
4. 点赞 / 收藏 / 转发 / 隐藏
5. 评论 / 回复
6. feed 行为事件记录

它是 App 首页和社区感知的核心。

### 6.3 User Graph 域

主要职责：

1. 用户搜索
2. 用户 profile 聚合
3. 关注关系
4. followers / following / friends
5. 个人主页内容聚合
6. 我的互动历史

它是 feed、通知、聊天入口、小队邀请等多个域的基础依赖。

### 6.4 Squad 域

主要职责：

1. 小队创建和基础资料
2. 成员关系
3. 成员角色和权限
4. 小队加入 / 退出 / 解散
5. 小队与聊天群映射
6. 小队与推荐、活动、社区内容的关联

Squad 是业务域，不应只被看作聊天群壳子。

### 6.5 IM Integration 域

主要职责：

1. 为 App 发放 Tencent IM bootstrap
2. 同步用户到 Tencent IM
3. 同步 squad/group 到 Tencent IM
4. 提供 direct conversation 启动所需业务编排
5. 处理会话身份映射

当前代码显示，App 侧已经把以下能力交给 Tencent IM SDK：

1. 获取会话
2. 获取消息
3. 发文本
4. 发图
5. 发视频
6. 发语音
7. 已读
8. 免打扰
9. 清历史

所以 Raver 后端这层的职责更像：

- 业务主数据权威源
- IM 登录票据与同步层
- IM 生命周期编排层

### 6.6 Notification Center 域

主要职责：

1. 站内 inbox
2. 未读计数
3. push token 管理
4. 推送模板
5. 发送策略
6. 定时触发任务
7. 灰度、去重、静默时段、限流等治理

这部分的复杂度其实已经接近一个小型通知平台。

### 6.7 Content / Event / DJ / Set 域

主要职责：

1. 活动内容管理
2. DJ 内容管理
3. 音乐 Set 与 Tracklist
4. 第三方音乐元数据补全
5. UGC + 结构化内容混合管理
6. 评分、Wiki、榜单等扩展内容

这部分和传统社交系统很不一样，因为它带有强结构化内容平台属性。

### 6.8 Media 域

主要职责：

1. 头像上传
2. 动态图片 / 视频上传
3. 活动图上传
4. DJ 图上传
5. Set 缩略图 / 视频上传
6. wiki / rating 图片上传

当前看起来媒体能力分散在多个接口里，但从架构上它其实是一个横切域。

---

## 7. App 当前依赖的关键接口面

下面不是完整 OpenAPI，而是按 App 使用视角整理的关键接口簇。

### 7.1 认证与会话

- `POST /v1/auth/login`
- `POST /v1/auth/register`
- `POST /v1/auth/sms/send`
- `POST /v1/auth/sms/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `POST /v1/auth/logout-all`

### 7.2 社区 Feed

- `GET /v1/feed`
- `GET /v1/feed/search`
- `GET /v1/feed/posts/:id`
- `POST /v1/feed/posts`
- `PATCH /v1/feed/posts/:id`
- `DELETE /v1/feed/posts/:id`
- `POST /v1/feed/posts/:id/like`
- `DELETE /v1/feed/posts/:id/like`
- `POST /v1/feed/posts/:id/save`
- `DELETE /v1/feed/posts/:id/save`
- `POST /v1/feed/posts/:id/repost`
- `DELETE /v1/feed/posts/:id/repost`
- `POST /v1/feed/posts/:id/share`
- `POST /v1/feed/posts/:id/hide`
- `DELETE /v1/feed/posts/:id/hide`
- `GET /v1/feed/posts/:id/comments`
- `POST /v1/feed/posts/:id/comments`
- `POST /v1/feed/events`

### 7.3 用户与关系

- `GET /v1/users/search`
- `GET /v1/users/:id/profile`
- `GET /v1/users/:id/followers`
- `GET /v1/users/:id/following`
- `GET /v1/users/:id/friends`
- `GET /v1/users/:id/posts`
- `POST /v1/social/users/:id/follow`
- `DELETE /v1/social/users/:id/follow`
- `GET /v1/profile/me`
- `PATCH /v1/profile/me`
- `POST /v1/profile/me/avatar`
- `GET /v1/profile/me/likes`
- `GET /v1/profile/me/reposts`
- `GET /v1/profile/me/saves`

### 7.4 聊天与 IM

- `GET /v1/im/tencent/bootstrap`
- `POST /v1/chat/direct/start`

另外，App 会在客户端 SDK 内部完成：

- 会话拉取
- 历史消息拉取
- 发送文本 / 图片 / 视频 / 语音
- 已读 / 免打扰 / 清历史

也就是说，聊天真正的调用链是：

```text
App 登录 Raver
  -> Raver 返回业务 session
  -> App 请求 /v1/im/tencent/bootstrap
  -> Raver 返回 SDKAppID / UserID / UserSig
  -> App 登录 Tencent IM SDK
  -> 会话与消息主要走腾讯 IM
```

### 7.5 小队

- `GET /v1/squads/recommended`
- `GET /v1/squads/mine`
- `GET /v1/squads/:id/profile`
- `POST /v1/squads/:id/join`
- `POST /v1/squads/:id/leave`
- `POST /v1/squads/:id/disband`
- `POST /v1/squads`
- `POST /v1/squads/:id/avatar`
- `PATCH /v1/squads/:id/my-settings`
- `PATCH /v1/squads/:id/manage`
- `PATCH /v1/squads/:id/members/:memberUserId/role`
- `POST /v1/squads/:id/members/:memberUserId/remove`

### 7.6 通知中心

- `GET /v1/notification-center/inbox`
- `GET /v1/notification-center/inbox/unread-count`
- `POST /v1/notification-center/inbox/read`
- `POST /v1/notification-center/push-tokens`
- `DELETE /v1/notification-center/push-tokens`

### 7.7 活动 / DJ / Set / 内容域

App 还依赖大量内容接口，包括但不限于：

- `GET /v1/events`
- `GET /v1/events/recommendations`
- `GET /v1/events/:id`
- `POST /v1/events`
- `PATCH /v1/events/:id`
- `DELETE /v1/events/:id`
- `POST /v1/events/upload-image`
- `POST /v1/events/lineup/import-image`
- `GET /v1/djs`
- `GET /v1/djs/:id`
- `GET /v1/djs/spotify/search`
- `GET /v1/djs/discogs/search`
- `GET /v1/djs/soundcloud/search`
- `POST /v1/djs/spotify/import`
- `POST /v1/djs/discogs/import`
- `POST /v1/djs/manual/import`
- `PATCH /v1/djs/:id`
- `POST /v1/djs/upload-image`
- `GET /v1/djs/:id/sets`
- `GET /v1/djs/:id/events`
- `GET /v1/djs/:id/follow-status`
- `POST /v1/djs/:id/follow`
- `DELETE /v1/djs/:id/follow`
- `GET /v1/dj-sets`
- `GET /v1/dj-sets/:id`
- `POST /v1/dj-sets`
- `PATCH /v1/dj-sets/:id`
- `DELETE /v1/dj-sets/:id`
- `PUT /v1/dj-sets/:id/tracks`
- `POST /v1/dj-sets/:id/tracklists`
- `POST /v1/dj-sets/:id/auto-link`
- `POST /v1/dj-sets/upload-thumbnail`
- `POST /v1/dj-sets/upload-video`
- `GET /v1/dj-sets/:id/comments`
- `POST /v1/dj-sets/:id/comments`
- `PATCH /v1/comments/:id`
- `DELETE /v1/comments/:id`
- `GET /v1/checkins`
- `POST /v1/checkins`
- `PATCH /v1/checkins/:id`
- `DELETE /v1/checkins/:id`
- `GET /v1/rating-events`
- `GET /v1/rating-events/:id`
- `POST /v1/rating-events`
- `POST /v1/rating-events/from-event`
- `POST /v1/rating-events/:id/units`
- `PATCH /v1/rating-events/:id`
- `DELETE /v1/rating-events/:id`
- `GET /v1/rating-units/:id`
- `PATCH /v1/rating-units/:id`
- `DELETE /v1/rating-units/:id`
- `POST /v1/rating-units/:id/comments`
- `GET /v1/learn/genres`
- `GET /v1/learn/labels`
- `GET /v1/learn/festivals`
- `POST /v1/learn/festivals`
- `PATCH /v1/learn/festivals/:id`
- `GET /v1/learn/rankings`
- `GET /v1/learn/rankings/:boardId`
- `GET /v1/publishes/me`

这部分规模已经说明：**App 后端并不是“只服务聊天或 feed”**，而是同时支撑一个很完整的内容平台。

---

## 8. 聊天：历史方案与当前真实方向

这是最容易让工程师误判的地方，所以单独展开。

### 8.1 历史上出现过 OpenIM / 自建消息方向

仓库里仍然有不少 OpenIM 文档、脚本、压测报告、迁移计划。

如果只看这些历史资产，会误以为当前 App 聊天仍然是：

- OpenIM 为主
- 或者自建消息链路为主

### 8.2 但当前代码主线已经切到 Tencent IM

当前真实方向应理解为：

1. Raver 继续保留自己的业务主系统
2. Tencent IM 负责聊天基础设施
3. App 登录业务后，再拿 Tencent IM bootstrap
4. 会话和消息由 Tencent IM SDK 驱动
5. Raver 后端负责用户 / 小队 / 权限 / 通知 / 业务映射

### 8.3 当前推荐向后端工程师明确说明

可以直接告诉对方：

> 历史上我们探索过 OpenIM，但当前主线已经明确转向 Tencent IM。  
> 现在我更希望后端架构建议基于“Raver 业务主系统 + Tencent IM 作为聊天基础设施”的模式来讨论，而不是继续评估自建消息系统。

---

## 9. 通知系统：不要把它理解成普通消息表

从当前 `notification-center` 代码看，通知系统已经包含：

1. 站内 inbox
2. APNS push handler
3. outbox worker
4. 多个业务 scheduler
5. channel handler 抽象
6. dedupe key
7. 模板
8. 灰度策略
9. 限流策略
10. quiet hours

而且当前已经存在多类业务通知：

1. chat message
2. community interaction
3. event countdown
4. event daily digest
5. route DJ reminder
6. followed DJ update
7. followed brand update
8. major news

因此后端工程师应该把这里看成：

- 一个独立的通知中心模块
- 而不是一个 `notifications` REST 表读写接口

---

## 10. 重要数据模型：从 App 视角怎么理解

当前 Prisma schema 已经比较大，App 侧最值得优先理解的模型可以分成下面几组。

### 10.1 身份与会话

- `User`
- `AuthRefreshToken`
- `AuthSmsCode`
- `AuthPhoneAuthState`

### 10.2 社区与关系

- `Post`
- `PostLike`
- `PostRepost`
- `PostSave`
- `PostShare`
- `PostHide`
- `FeedEvent`
- `PostComment`
- `Follow`

### 10.3 小队与聊天关联

- `Squad`
- `SquadMember`
- `SquadInvite`
- `SquadActivity`
- `SquadAlbum`
- `SquadAlbumPhoto`
- `DirectConversation`
- `DirectConversationRead`
- `DirectMessage`
- `SquadMessage`

### 10.4 通知

- `NotificationSubscription`
- `DevicePushToken`
- `NotificationEvent`
- `NotificationInboxItem`
- `NotificationDelivery`
- `NotificationTemplate`
- `NotificationAdminConfig`

### 10.5 内容域

- `Event`
- `EventLineupSlot`
- `EventTicketTier`
- `DJ`
- `DJSet`
- `Tracklist`
- `Track`
- `TracklistTrack`
- `Label`
- `WikiFestival`
- `Checkin`
- `RatingEvent`
- `RatingUnit`
- `RatingComment`

### 10.6 第三方 IM / 历史迁移残留

- `OpenIMSyncJob`
- `OpenIMWebhookEvent`
- `OpenIMMessageReport`
- `OpenIMImageModerationJob`
- `OpenIMMessageMigration`

这组模型也再次说明：仓库有明显历史演进痕迹，后端架构建议里最好明确哪些保留、哪些下线、哪些归档。

---

## 11. 我对当前系统的理解：它本质上是什么

如果一定要给当前系统下一个偏后端的定义，我会这样描述：

> 这是一个以 App 为主、内容与社区混合驱动、带群组和聊天能力的业务单体。  
> 它的核心不是“内容网站”，也不是“纯 IM App”，而是电子音乐垂类场景下的内容平台 + 社交平台 + 群组平台。  
> 当前后端负责业务主数据、BFF 聚合、通知、媒体、调度和第三方 IM 编排；实时聊天底层正在明确外包给 Tencent IM。

---

## 12. 我希望后端工程师重点帮我看的问题

下面这些问题，是我最希望拿到架构建议的部分。

### 12.1 单体是否继续成立

当前项目作为业务单体继续演进是否合理？

如果合理，希望得到建议：

1. 单体内应该怎么按领域分层
2. controller / service / repository / domain 应该怎么划
3. 哪些模块最需要先做边界收敛

### 12.2 BFF 如何收敛

当前 `/api/*` 和 `/v1/*` 共存。

我更希望 App 未来只依赖一套稳定契约，所以想请教：

1. 是否应该明确 `/v1` 为唯一 App 契约
2. 旧 `/api` 如何迁移或冻结
3. App BFF 与内部业务服务层应该如何解耦

### 12.3 聊天相关边界如何划清

在 “Raver + Tencent IM” 模式下，希望后端工程师给建议：

1. 哪些数据应该以 Raver 为权威源
2. 哪些数据只放在 Tencent IM
3. squad、conversation、group、member role 怎么映射最稳
4. 业务侧是否还需要保留本地 direct/squad message 镜像

### 12.4 通知中心是否需要独立成子系统

通知中心已经有：

- inbox
- push
- scheduler
- outbox
- 模板
- 灰度与治理

我想请教：

1. 这部分继续留在主服务里是否合理
2. 是否应该拆成独立 worker / job system
3. 如何避免 API 服务与定时任务耦合得越来越重

### 12.5 媒体上传如何规范

当前媒体上传接口分散在多处业务域中。

想请教：

1. 是否应该抽成统一 media service / media module
2. 本地 uploads 与 OSS 的职责怎么收口
3. 未来如果要做审核、转码、清理、失败重试，应该怎么设计

### 12.6 内容域是否需要进一步模块化

当前内容域包含：

- events
- djs
- sets
- tracklists
- ratings
- learn/wiki
- labels/festivals/rankings

这部分越来越大，我想请教：

1. 这些是一个“大内容域”，还是应该再细拆
2. 外部数据抓取 / 导入能力是否应该单独做 ingestion/enrichment 模块
3. 哪些模型最可能在未来变成维护负担

### 12.7 可运维性和可观测性

如果未来真要面向真实用户增长，希望后端工程师建议：

1. 日志、监控、告警应该先补什么
2. scheduler / worker 是否需要可观测性增强
3. 第三方 IM、APNS、SMS、OSS 失败链路怎么做降级和追踪

---

## 13. 我目前最担心的几个架构风险

这是我个人的非专业判断，供后端工程师参考。

### 13.1 单进程承担太多职责

当前一个服务进程里既跑 API，又跑通知调度，又跑 worker，又做第三方编排。

风险是：

1. 复杂度继续上升
2. 故障面变大
3. 部署与扩缩容难以按职责拆分

### 13.2 历史路线残留较多

比如：

1. `/api` 与 `/v1` 共存
2. OpenIM 历史资产仍然很多
3. `WebFeatureService` 等命名带有历史包袱

风险是：

1. 新工程师很难快速理解真实主线
2. 后续容易继续在错误边界上迭代

### 13.3 聊天业务边界还容易混

一旦没有明确好：

1. 哪些由业务后端负责
2. 哪些由 Tencent IM 负责
3. 哪些需要业务镜像

就很容易出现：

- 逻辑重复
- 状态不一致
- 会话/成员/未读/推送之间责任不清

### 13.4 通知系统可能持续膨胀

通知中心已经超出“简单消息提醒”范围了。

如果没有提前设计好：

1. 发送流水
2. 重试机制
3. 幂等
4. 模板治理
5. 调度治理

后面会非常容易失控。

---

## 14. 我建议后端工程师先按什么心智来理解这个项目

我希望他不要把这个项目理解成：

1. 一个网站后端
2. 一个 CMS
3. 一个纯聊天后端
4. 一个简单活动列表服务

而应该理解成：

> 一个 App-first 的电子音乐垂类平台后端。  
> 它需要同时支撑内容结构化管理、社区互动、用户关系、小队组织、第三方 IM 编排、通知中心和媒体上传。  
> 当前更像一个在快速长大的业务单体，需要做的是模块化、边界澄清和系统收口，而不一定是一上来就微服务化。

---

## 15. 如果要一句话把需求发给后端工程师

可以直接这样说：

> 我现在做的是一个以 App 为主的电子音乐垂类平台，核心包含活动/Festival、DJ/厂牌/Set 内容库、社区 Feed、用户关注关系、小队、聊天、通知、Check-in 和评分。当前后端是 Node.js + Express + Prisma + PostgreSQL 的业务单体，App 主要依赖 `/v1` BFF；聊天底层正在明确收口到 Tencent IM，通知中心和定时任务还在主服务内。我希望你帮我从后端架构角度看一下：这个系统继续怎么做模块划分、BFF 收敛、聊天边界、通知中心、媒体、内容域分层，会比较稳。Web 端不是重点，可以忽略。 

---

## 16. 附：我整理这份文档时主要参考的代码位置

- `server/src/index.ts`
- `server/prisma/schema.prisma`
- `server/src/routes/bff.routes.ts`
- `server/src/routes/bff.web.routes.ts`
- `server/src/routes/tencent-im.routes.ts`
- `server/src/routes/notification-center.routes.ts`
- `server/src/services/tencent-im/*`
- `server/src/services/notification-center/*`
- `mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`
- `docs/TENCENT_IM_MIGRATION_MASTER_PLAN.md`

