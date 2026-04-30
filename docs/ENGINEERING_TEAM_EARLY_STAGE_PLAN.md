# Raver 早期研发团队配置方案

> 更新时间：2026-04-28  
> 适用阶段：产品还在早期、App 为主、Web 非核心、Android 尚未正式并行推进  
> 结论先行：**早期建议先配 4 个核心工程师，不建议一开始就招更多**

---

## 1. 先说结论

如果我是从零组建这支研发队伍，我会建议你在早期先找：

1. **后端工程师 A：账号 / 社交 / 小队 / IM / 通知基础设施**
2. **后端工程师 B：活动 / DJ / Set / 评分 / Wiki 内容域**
3. **iOS 工程师 A：App 壳层 / 登录 / Feed / 用户关系 / 小队**
4. **iOS 工程师 B：聊天 / 会话 / 推送 / 内容详情与编辑链路**

也就是说：

> **4 个核心工程师 + 你自己做产品 owner / 项目 owner**

这是我认为当前阶段最合适的起步配置。

---

## 2. 为什么不是 2 个人，也不是 8 个人

### 2.1 为什么不是更少

如果只有 2-3 个工程师，会出现几个问题：

1. 后端没有人专门收敛系统边界，业务单体会继续野蛮增长
2. iOS 端聊天和内容两条线都很重，一个人很容易同时卡在 UI、BFF、IM SDK、推送上
3. 事件 / DJ / Set / 评分 / Wiki 这条内容链路本身已经是一个完整子系统
4. 通知中心和 Tencent IM 集成本身也足够吃掉一个偏后端强手的精力

### 2.2 为什么不是更多

如果一开始就招 6-8 个工程师，当前这个项目阶段反而容易出问题：

1. 边界还没完全收口，人一多就会互相踩模块
2. 你的主客户端还是 iOS，Android 还没进入正式并行开发期
3. Web 端不是主线，过早上 Web/全栈会稀释资源
4. 当前更需要的是“把主线跑通”，不是“铺开太多战线”

所以早期最优解不是“尽可能多找人”，而是**找少量但边界清晰的核心工程师**。

---

## 3. 为什么是这 4 个角色

### 3.1 后端工程师 A

这个角色负责系统的“业务骨架”和“系统边界”。

当前最需要有人真正盯住这些东西：

1. Auth / Session
2. Feed / 用户关系
3. Squad
4. Tencent IM bootstrap 与业务映射
5. Notification Center
6. Scheduler / worker / outbox
7. App 主线 BFF 契约一致性

如果这个角色缺失，系统会继续混成“什么都在一个 Express 文件里”。

### 3.2 后端工程师 B

这个角色负责“内容平台”部分。

Raver 不是纯社交 App，它还有非常重的内容域：

1. Events
2. DJ
3. DJ Set / Tracklist
4. Ratings
5. Learn / Wiki
6. Label / Festival / Rankings
7. 多媒体上传与第三方内容补全

这一块非常容易被低估，但实际上工作量已经接近半个产品。

### 3.3 iOS 工程师 A

这个角色负责 App 的“日常主使用路径”。

也就是用户每天最容易触达的部分：

1. App shell
2. 登录 / 注册 / 会话恢复
3. Feed
4. 用户主页
5. 搜索
6. Follow graph
7. Squad 基础页面

这个角色的目标是把“App 日常打开就能用”的体验稳定下来。

### 3.4 iOS 工程师 B

这个角色负责“高复杂度交互”和“深链路能力”。

最典型就是：

1. Tencent IM 集成
2. 会话列表与聊天页
3. 图片 / 视频 / 语音消息
4. 推送 / badge / deep link
5. 内容详情页与编辑发布链路
6. 媒体上传交互

这类能力看上去页面不多，但技术复杂度高，非常适合单独由一个强客户端工程师负责。

---

## 4. 为什么我不建议早期先招 Android 工程师

不是说 Android 不重要，而是**不是第一批最该上的人**。

原因很简单：

1. 当前主客户端明显还是 iOS
2. Android 路线虽然已有 Flutter 技术方案，但还没有进入稳定并行迭代阶段
3. 如果 BFF、聊天、通知、内容模型还在不断变，Android 工程师会被迫跟着反复吃接口变化
4. 先把 iOS 主线、BFF 契约、IM/通知边界打稳，再上 Flutter 会更省总成本

### 我建议的 Android 节奏

建议在下面条件满足后，再招第 5 位工程师做 Android / Flutter：

1. `/v1` BFF 契约基本稳定
2. iOS 登录、Feed、聊天、通知、活动内容链路已经跑通
3. Tencent IM 与通知中心的主方案已确认
4. 你已经决定 Android 要开始真正追平 iOS

---

## 5. 每个工程师的模块分工建议

### 工程师 1：后端 A

负责模块：

1. auth / session
2. social feed
3. user graph
4. squads
5. direct conversation 启动编排
6. Tencent IM 业务接入层
7. notification center
8. scheduler / outbox / push token

### 工程师 2：后端 B

负责模块：

1. events
2. djs
3. dj sets
4. tracklists
5. checkins
6. ratings
7. learn/wiki
8. labels/festivals/rankings
9. 内容导入与补全
10. 内容相关媒体上传

### 工程师 3：iOS A

负责模块：

1. app shell / coordinator / navigation
2. auth flow
3. feed
4. search
5. profile
6. follow graph
7. squad 基础页
8. 通用状态管理与 BFF 交互主链路

### 工程师 4：iOS B

负责模块：

1. Tencent IM 客户端集成
2. conversations / messages
3. message media send flow
4. notification opening / badge / deep link
5. event / dj / set detail
6. editor / upload / import 复杂交互

---

## 6. 这 4 个人之间应该怎么协作

### 后端 A 与 iOS A

这两个角色应该高频对齐：

1. 登录态
2. feed 契约
3. profile / follow / squad 的 BFF 响应
4. session expired 处理

### 后端 A 与 iOS B

这两个角色重点对齐：

1. Tencent IM bootstrap
2. squad 与 group 映射
3. notification-center
4. push token / unread / badge

### 后端 B 与 iOS B

这两个角色重点对齐：

1. event / dj / set detail schema
2. editor / upload / import API
3. 内容发布与编辑的媒体流
4. ratings / checkins / wiki 的交互模型

### 后端 A 与后端 B

这两个角色必须共同维护：

1. Prisma schema 的演进纪律
2. `/v1` 响应风格一致性
3. 统一鉴权 / 错误码 / 分页风格
4. 统一媒体与上传策略

---

## 7. 我建议的招聘顺序

如果你不是一次性招满 4 个，我建议顺序如下：

1. **后端工程师 A**
2. **iOS 工程师 A**
3. **iOS 工程师 B**
4. **后端工程师 B**

### 原因

#### 第一位先找后端 A

因为当前最需要有人把系统边界看住，不然客户端再怎么推进也会被后端混乱拖住。

#### 第二位找 iOS A

因为 iOS 是主客户端，必须尽快把登录、Feed、Profile 这些日常主路径稳定下来。

#### 第三位找 iOS B

因为聊天和推送链路的复杂度很高，不适合长期压在同一个 iOS 身上。

#### 第四位找后端 B

因为内容域很重，但在前 1-2 人还没到位之前，你更需要先把系统底盘和主路径跑通。

---

## 8. 每个人入场后的前 6 周目标

### 后端 A

1. 明确 `/v1` 是 App 主契约
2. 把 auth / session / social / squad / notification-center 主链路摸透
3. 梳理 Tencent IM 与业务主数据边界
4. 给出后端模块化收口方案

### 后端 B

1. 梳理 event / dj / set / ratings / learn 内容域
2. 收拢内容类接口风格
3. 明确媒体上传与内容导入链路
4. 识别最需要先治理的数据模型风险

### iOS A

1. 稳定登录、恢复会话、session expired 处理
2. 稳定 feed、profile、follow、search、squad 基础页
3. 统一 App shell / router / 状态管理协作方式
4. 降低日常主路径的 bug 密度

### iOS B

1. 稳定 Tencent IM 登录、会话、历史消息、发送链路
2. 跑通 badge / push open / deep link
3. 稳定内容详情页与编辑发布交互
4. 把媒体上传体验做顺

---

## 9. 早期不建议单独设岗的角色

下面这些我认为早期不必作为独立全职工程师角色先招：

1. Web 前端工程师
2. Android 工程师
3. 专职 DevOps 工程师
4. 专职数据工程师
5. 专职测试开发工程师

不是因为他们不重要，而是因为当前阶段还不该优先消耗 headcount 在这里。

如果需要，可以用：

1. 你自己 + 核心工程师临时顶一部分
2. 少量顾问 / 兼职 / 外包支持

---

## 10. 建议你现在就给每个工程师发什么文档

我已经为这 4 个角色各准备一份可交接文档，建议你直接发对应的 md：

1. 后端工程师 A：
   [docs/handoffs/ENGINEER_01_BACKEND_SOCIAL_IM_NOTIFICATION.md](/Users/blackie/Projects/raver/docs/handoffs/ENGINEER_01_BACKEND_SOCIAL_IM_NOTIFICATION.md)
2. 后端工程师 B：
   [docs/handoffs/ENGINEER_02_BACKEND_CONTENT_DATA.md](/Users/blackie/Projects/raver/docs/handoffs/ENGINEER_02_BACKEND_CONTENT_DATA.md)
3. iOS 工程师 A：
   [docs/handoffs/ENGINEER_03_IOS_APP_SHELL_SOCIAL.md](/Users/blackie/Projects/raver/docs/handoffs/ENGINEER_03_IOS_APP_SHELL_SOCIAL.md)
4. iOS 工程师 B：
   [docs/handoffs/ENGINEER_04_IOS_CHAT_CONTENT_DETAILS.md](/Users/blackie/Projects/raver/docs/handoffs/ENGINEER_04_IOS_CHAT_CONTENT_DETAILS.md)

如果后面你决定开始正式推进 Android，我建议再单独补第 5 份 Flutter 交接文档，而不是现在就把 Android 也拉进第一波。

