# 工程师 1 交接文档：后端 A（社交 / 小队 / IM / 通知基础设施）

> 角色定位：早期后端主心骨  
> 你的职责不是“接几个接口”，而是帮项目把 App 主线后端的边界真正立起来

---

## 1. 你要负责什么

你负责的是 Raver 后端里**最像产品骨架**的部分：

1. auth / session
2. feed / social graph
3. users / profile / follow
4. squads
5. chat 启动编排与 Tencent IM 业务接入
6. notification center
7. push token / unread / inbox
8. scheduler / outbox / 任务执行主链路

简单说：

> 你负责“用户每天最常走的 App 主路径”对应的后端，以及这些路径背后的系统边界。

---

## 2. 你先应该怎么理解这个项目

不要把它理解成：

1. 一个普通网站后端
2. 一个只有 CRUD 的社区接口集合
3. 一个纯聊天后端

你应该把它理解成：

> 一个 App-first 的电子音乐垂类产品后端。  
> 当前主客户端是 iOS。  
> 聊天底层正在收口到 Tencent IM。  
> Web 不是主线。  
> 你的目标是把用户、关系、小队、通知、聊天编排这条主干做成稳定骨架。

---

## 3. 当前系统真实情况

### 3.1 主服务形态

当前后端是一个 Node.js + Express + TypeScript + Prisma + PostgreSQL 的业务单体。

主入口：

- [server/src/index.ts](/Users/blackie/Projects/raver/server/src/index.ts)

从入口上看，它同时承载：

1. API/BFF
2. Tencent IM 路由
3. Notification Center 路由
4. 多个通知 scheduler
5. outbox worker

### 3.2 当前 App 主契约

对于你这个角色来说，应该把 `/v1/*` 视为主线契约。

旧的 `/api/*` 只当历史兼容背景，不要继续把它当演进主线。

### 3.3 聊天主线

当前聊天应理解为：

1. Raver 负责业务主数据
2. App 登录后向 Raver 获取 Tencent IM bootstrap
3. App 再登录 Tencent IM SDK
4. 会话与消息由 Tencent IM 负责
5. Raver 负责用户、squad、权限、通知、业务映射

历史上仓库里有 OpenIM 资产，但你应该把它视为历史包袱，而不是未来主线。

---

## 4. 你当前拥有的模块边界

### 4.1 Auth / Session

你要拥有：

1. 注册
2. 密码登录
3. 短信登录
4. refresh token
5. logout / logout-all
6. session expired 策略

关键代码：

- [server/src/routes/bff.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.routes.ts)
- [server/src/utils/auth.ts](/Users/blackie/Projects/raver/server/src/utils/auth.ts)
- [server/src/services/sms/sms-provider.ts](/Users/blackie/Projects/raver/server/src/services/sms/sms-provider.ts)

### 4.2 Feed / Social Graph

你要拥有：

1. `/v1/feed`
2. posts
3. likes
4. reposts
5. saves
6. shares
7. hides
8. comments
9. user search / profile / follow graph

关键代码：

- [server/src/routes/bff.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.routes.ts)
- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma)

核心模型：

- `Post`
- `PostLike`
- `PostRepost`
- `PostSave`
- `PostShare`
- `PostHide`
- `PostComment`
- `Follow`
- `FeedEvent`

### 4.3 Squads

你要拥有：

1. squad 创建 / 加入 / 退出 / 解散
2. squad 成员关系
3. squad 角色与管理
4. squad 与 group conversation 的映射

关键代码：

- [server/src/services/squad.service.ts](/Users/blackie/Projects/raver/server/src/services/squad.service.ts)
- [server/src/routes/bff.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.routes.ts)
- [server/src/routes/squad.routes.ts](/Users/blackie/Projects/raver/server/src/routes/squad.routes.ts)

### 4.4 Tencent IM 业务接入层

你要拥有：

1. bootstrap 发放
2. user sync
3. squad group sync
4. 业务 user id 和 IM user id 映射
5. 业务群生命周期和 IM 群生命周期的关系

关键代码：

- [server/src/routes/tencent-im.routes.ts](/Users/blackie/Projects/raver/server/src/routes/tencent-im.routes.ts)
- [server/src/services/tencent-im/tencent-im-config.ts](/Users/blackie/Projects/raver/server/src/services/tencent-im/tencent-im-config.ts)
- [server/src/services/tencent-im/tencent-im-token.service.ts](/Users/blackie/Projects/raver/server/src/services/tencent-im/tencent-im-token.service.ts)
- [server/src/services/tencent-im/tencent-im-user.service.ts](/Users/blackie/Projects/raver/server/src/services/tencent-im/tencent-im-user.service.ts)
- [server/src/services/tencent-im/tencent-im-group.service.ts](/Users/blackie/Projects/raver/server/src/services/tencent-im/tencent-im-group.service.ts)

### 4.5 Notification Center

你要拥有：

1. inbox
2. unread count
3. push token 管理
4. APNS handler
5. outbox
6. scheduler
7. dedupe / quiet hours / gray release / rate limit

关键代码：

- [server/src/routes/notification-center.routes.ts](/Users/blackie/Projects/raver/server/src/routes/notification-center.routes.ts)
- [server/src/services/notification-center/index.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/index.ts)
- [server/src/services/notification-center/notification-center.service.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-center.service.ts)

---

## 5. 你要优先解决的架构问题

### 5.1 `/v1` 主线收口

你需要主导回答：

1. `/api` 和 `/v1` 如何划界
2. 哪些旧接口冻结
3. App 未来是否只依赖 `/v1`

### 5.2 Auth 真正变成会话系统

你需要确认：

1. refresh token 生命周期
2. 多设备行为
3. session 失效策略
4. 短信验证码风控

### 5.3 Feed / Profile / Follow 的一致性

你需要让这些接口具备一致风格：

1. pagination
2. auth behavior
3. error model
4. envelope 结构
5. cursor / list semantics

### 5.4 Squad 与 Tencent IM 的边界

这是你最关键的系统设计题之一：

1. squad 是否是业务权威源
2. Tencent IM group 是否是投影 / 映射
3. 用户退队、踢人、解散、角色变化如何同步
4. 是否需要 reconcile 机制

### 5.5 Notification Center 的继续演进方式

你需要回答：

1. scheduler 是否继续留在主进程
2. outbox worker 是否应拆执行形态
3. 通知模板与治理如何避免继续散

---

## 6. 你入场后的前 4 周建议目标

### 第 1 周

1. 跑通本地服务和数据库
2. 熟悉 `server/src/index.ts`
3. 读完 `bff.routes.ts`、`tencent-im.routes.ts`、`notification-center.routes.ts`
4. 梳理 auth / social / squad / notification-center 的接口地图

### 第 2 周

1. 画出 auth / feed / user graph / squad / IM / notification 的模块边界
2. 识别最危险的几个“巨型路由块”
3. 提出第一版后端收口方案

### 第 3 周

1. 先治理 auth/session 主链路
2. 收拢 feed / profile / follow 的返回风格
3. 把 Tencent IM 与业务主数据边界文档化

### 第 4 周

1. 给出 notification-center 的中期演进建议
2. 给出 squad + IM 生命周期的一致性建议
3. 明确 `/v1` 作为 App 主契约的迁移计划

---

## 7. 你不应该在早期分散精力的地方

以下内容在早期不应成为你的主战场：

1. Web 站点体验
2. Android 客户端对接
3. 内容编辑器 UI 细节
4. Learn / Wiki 具体内容策略
5. OpenIM 历史资产的继续演进

---

## 8. 你要重点合作的人

### iOS 工程师 A

重点一起对齐：

1. 登录态
2. feed / profile / follow / squad 主链路
3. session expired 和 error model

### iOS 工程师 B

重点一起对齐：

1. Tencent IM bootstrap
2. unread / badge / notification inbox
3. push token 注册和 App 打开链路

### 后端工程师 B

重点一起对齐：

1. Prisma schema 改动纪律
2. 统一 API 风格
3. 统一媒体 / 上传 / 权限策略

---

## 9. 你阅读代码的起点

建议从下面这些文件开始读：

1. [server/src/index.ts](/Users/blackie/Projects/raver/server/src/index.ts)
2. [server/src/routes/bff.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.routes.ts)
3. [server/src/routes/tencent-im.routes.ts](/Users/blackie/Projects/raver/server/src/routes/tencent-im.routes.ts)
4. [server/src/routes/notification-center.routes.ts](/Users/blackie/Projects/raver/server/src/routes/notification-center.routes.ts)
5. [server/src/services/squad.service.ts](/Users/blackie/Projects/raver/server/src/services/squad.service.ts)
6. [server/src/services/tencent-im/tencent-im-token.service.ts](/Users/blackie/Projects/raver/server/src/services/tencent-im/tencent-im-token.service.ts)
7. [server/src/services/notification-center/notification-center.service.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-center.service.ts)
8. [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma)

