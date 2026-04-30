# 工程师 2 交接文档：后端 B（内容域 / 数据域）

> 角色定位：内容平台负责人  
> 你的职责是把 Raver 的“活动 + DJ + Set + 评分 + Wiki”这一整块做成真正可维护的内容系统

---

## 1. 你要负责什么

你负责的是 Raver 后端中最“内容平台化”的部分：

1. events
2. event lineup / ticket tiers
3. djs
4. dj external enrichment
5. dj sets
6. tracklists / tracks
7. checkins
8. ratings
9. learn / wiki
10. labels / festivals / rankings
11. 内容相关媒体上传

简单说：

> 你负责 Raver 里所有让它不像纯社交 App、而像电子音乐垂类平台的那一半系统。

---

## 2. 你先应该怎么理解项目

你不要把这部分理解成“几个内容表 + 几个管理接口”。

正确理解应该是：

1. Raver 不是单纯社区
2. 它有非常重的结构化内容模型
3. 内容和社区并不是两套孤立系统
4. 活动、DJ、Set、评分、Check-in、Wiki 是互相有关系的

所以你的工作不是单独加几个 CRUD，而是让这部分形成一个真正的内容域。

---

## 3. 你的模块边界

### 3.1 Events

你要拥有：

1. 活动列表 / 搜索 / 推荐
2. 活动详情
3. 活动创建 / 编辑 / 删除
4. 活动图片
5. lineup slots
6. ticket tiers
7. 地点与时间结构

关键代码：

- [server/src/controllers/event.controller.ts](/Users/blackie/Projects/raver/server/src/controllers/event.controller.ts)
- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts)
- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma)

核心模型：

- `Event`
- `EventLineupSlot`
- `EventTicketTier`

### 3.2 DJs

你要拥有：

1. DJ 列表 / 搜索 / 详情
2. DJ 导入与编辑
3. DJ 和 Events / Sets 的关联
4. 第三方数据补全
5. DJ 媒体资源

关键代码：

- [server/src/routes/dj.routes.ts](/Users/blackie/Projects/raver/server/src/routes/dj.routes.ts)
- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts)
- [server/src/services/spotify-artist.service.ts](/Users/blackie/Projects/raver/server/src/services/spotify-artist.service.ts)
- [server/src/services/discogs-artist.service.ts](/Users/blackie/Projects/raver/server/src/services/discogs-artist.service.ts)
- [server/src/services/soundcloud-artist.service.ts](/Users/blackie/Projects/raver/server/src/services/soundcloud-artist.service.ts)

核心模型：

- `DJ`
- `DJContributor`

### 3.3 DJ Sets / Tracklists

你要拥有：

1. set 列表 / 详情 / 我的 sets
2. 创建 / 编辑 / 删除 set
3. 缩略图 / 视频上传
4. tracks / tracklists
5. auto-link
6. set comments

关键代码：

- [server/src/services/djset.service.ts](/Users/blackie/Projects/raver/server/src/services/djset.service.ts)
- [server/src/services/comment.service.ts](/Users/blackie/Projects/raver/server/src/services/comment.service.ts)
- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts)

核心模型：

- `DJSet`
- `Tracklist`
- `Track`
- `TracklistTrack`
- `Comment`

### 3.4 Check-ins / Ratings

你要拥有：

1. check-in 创建 / 编辑 / 删除
2. 按 event / dj 聚合 check-in
3. rating events
4. rating units
5. rating comments

关键代码：

- [server/src/routes/checkin.routes.ts](/Users/blackie/Projects/raver/server/src/routes/checkin.routes.ts)
- [server/src/controllers/checkin.controller.ts](/Users/blackie/Projects/raver/server/src/controllers/checkin.controller.ts)
- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts)

核心模型：

- `Checkin`
- `RatingEvent`
- `RatingUnit`
- `RatingComment`

### 3.5 Learn / Wiki / Rankings

你要拥有：

1. genres
2. labels
3. festivals
4. rankings
5. 我的发布内容聚合

关键代码：

- [server/src/routes/label.routes.ts](/Users/blackie/Projects/raver/server/src/routes/label.routes.ts)
- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts)

核心模型：

- `Label`
- `WikiFestival`
- `WikiFestivalContributor`

---

## 4. 你最应该关注的架构问题

### 4.1 内容域边界仍然偏散

当前这部分能力有很多都堆在 `bff.web.routes.ts` 里。

你需要回答：

1. event / dj / set / rating / learn 是否应进一步分模块
2. 哪些可以抽 service / repository / domain 层
3. 哪些接口目前太像“一次性写法”

### 4.2 内容模型复杂但还不够收口

例如 event 模型已经包含：

1. 多语言
2. 场地位置
3. lineup
4. ticket tiers
5. 社交链接
6. 外部来源字段

这类模型最容易演化成“巨型实体”，你需要尽早给出治理方法。

### 4.3 第三方数据补全能力要不要单独抽离

当前 DJ 相关有 Spotify / Discogs / SoundCloud 补全逻辑。

你需要判断：

1. 这些 enrichment 能力是否应该作为单独模块存在
2. 导入与人工编辑的边界是什么
3. 哪些字段是权威源，哪些字段只是外部候选

### 4.4 媒体上传能力过于分散

当前内容相关的上传分散在：

1. event image
2. lineup import image
3. dj image
4. set thumbnail
5. set video
6. wiki image
7. rating image

你需要判断：

1. 是否要统一 media domain
2. 上传后的元数据如何管理
3. 是否需要后续扩展审核 / 转码 / 清理

---

## 5. 你入场后的前 4 周建议目标

### 第 1 周

1. 跑通服务
2. 读 `bff.web.routes.ts`
3. 梳理 events / djs / dj-sets / ratings / learn 的接口地图
4. 对照 Prisma schema 建立内容域认知

### 第 2 周

1. 把内容域拆成清晰模块图
2. 找出最危险的巨型 handler
3. 梳理 media upload 的现状

### 第 3 周

1. 给出 events / djs / sets 的结构收口方案
2. 给出 enrichment / import 的责任划分建议
3. 和 iOS 工程师 B 对齐详情页与编辑器契约

### 第 4 周

1. 形成中期内容域治理方案
2. 列出最需要补索引 / 调整模型 / 收拢接口风格的清单
3. 明确哪些内容域适合继续单体内模块化，哪些以后可能拆 worker

---

## 6. 你不应该优先分散精力的地方

以下内容不是你早期的首要目标：

1. auth / session 主流程
2. Tencent IM 客户端登录细节
3. notification-center 策略实现
4. App 壳层问题
5. Web 页面体验

---

## 7. 你重点要合作的人

### iOS 工程师 B

重点一起对齐：

1. event / dj / set detail schema
2. editor / uploader / import flow
3. media upload UX 所依赖的接口
4. ratings / checkins / learn 的表现层需要什么

### 后端工程师 A

重点一起对齐：

1. 统一鉴权
2. 统一分页 / envelope / error style
3. Prisma schema 改动节奏
4. 统一资源上传规范

---

## 8. 你阅读代码的起点

建议从下面这些文件开始读：

1. [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts)
2. [server/src/controllers/event.controller.ts](/Users/blackie/Projects/raver/server/src/controllers/event.controller.ts)
3. [server/src/services/djset.service.ts](/Users/blackie/Projects/raver/server/src/services/djset.service.ts)
4. [server/src/services/comment.service.ts](/Users/blackie/Projects/raver/server/src/services/comment.service.ts)
5. [server/src/services/spotify-artist.service.ts](/Users/blackie/Projects/raver/server/src/services/spotify-artist.service.ts)
6. [server/src/services/discogs-artist.service.ts](/Users/blackie/Projects/raver/server/src/services/discogs-artist.service.ts)
7. [server/src/services/soundcloud-artist.service.ts](/Users/blackie/Projects/raver/server/src/services/soundcloud-artist.service.ts)
8. [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma)

