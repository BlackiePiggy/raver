# Raver iOS 对标 `openim-ios-demo` 改造计划（分阶段执行版）

> 目标：在你现有 Raver iOS 项目中，按“可商用、可演进”的方式，分阶段对标 `openimsdk/openim-ios-demo` 的成熟聊天能力。
>
> 说明：本文既包含能力盘点，也包含你需要确认的“是否 1:1 复刻”清单；并内置进度勾选与执行日志区。

---

## 0. 参考依据（已分析）

- Demo 主仓库与功能总表：  
  `https://github.com/openimsdk/openim-ios-demo`  
  `https://raw.githubusercontent.com/openimsdk/openim-ios-demo/main/README.md`
- iOS 聊天 UI 分层（Chat/Contact/Conversation）：  
  `https://github.com/openimsdk/openim-ios-demo/tree/main/OUIIM/Classes`
- 核心层（Api/Core/Model/Utils/Widgets）：  
  `https://github.com/openimsdk/openim-ios-demo/tree/main/OUICore/Classes`
- 通话层（1v1 音视频）：  
  `https://github.com/openimsdk/openim-ios-demo/tree/main/OUICalling`
- 推送和地图配置：  
  `https://raw.githubusercontent.com/openimsdk/openim-ios-demo/main/CONFIGKEY.md`

## 0.1 强对标原则（你最新要求）

- 你已明确要求：**每个功能背后的实现逻辑都尽量按 openim-ios-demo 同构**，不仅是功能表面一致。
- 执行规则：
  - 先对齐 Demo 的“分层与状态机”，再做 UI 适配。
  - 不以“简单可用”替代“同类机制”，尤其是：
    - 消息生命周期（sending/sent/failed）
    - 实时监听链路（会话变化、新消息、输入状态）
    - 失败重试与本地替换（local echo -> server ack）
  - 所有差异点必须在本文记录“差异原因 + 风险 + 回补计划”。

---

## 1. Demo 能力地图（已拆解）

## 1.1 账号与登录
- 手机号/邮箱注册、验证码登录
- 个人资料查看/编辑
- 多语言
- 改密/忘记密码

## 1.2 联系人与关系链
- 好友搜索、申请、通过/拒绝、删除
- 好友备注
- 好友列表实时同步
- 黑名单（增删、限制消息、实时同步）

## 1.3 群组能力
- 建群/解散
- 申请入群、邀请入群、退群、移除成员
- 群资料更新与通知（含实时同步）
- 邀请审核、转让群主、成员搜索

## 1.4 会话与聊天
- 会话置顶、已读、免打扰
- 离线消息、漫游消息、多端同步、历史消息
- 消息删除、清空、复制
- 单聊输入中状态（Typing）
- 新成员可见历史消息

## 1.5 消息类型（客户端渲染层）
- 文本、图片、视频、语音、文件
- 表情、名片、位置
- 自定义消息（Custom）
- 系统提示/通知消息（SystemTips/Notice）

## 1.6 通话与推送
- 开源版支持 1v1 音视频
- 在线实时推送 + 离线推送（Getui/FCM）
- 地图位置能力（地图 Key 配置）

## 1.7 从代码结构可确认的成熟点
- 聊天域清晰分层：`Controller / Model / View / DataSource / InputView / AccessoryView`
- 会话设置与群设置独立：`ChatSetting` 模块
- 联系人域覆盖完整：`Add / FriendList / GroupApplication / GroupStructure / NewGroup / QRCode / User`
- 核心基础层完备：`IMController / Events / CallBack / Api / Utils / Widgets`

---

## 2. 你需要拍板的“1:1 复刻能力”清单（请勾选）

> 规则：
> - `[x]` = 你确认要做
> - `[ ]` = 暂不做
> - `~` = 做简化版（非 1:1）

## 2.1 P0（建议默认做）
- [x] 会话列表：置顶、免打扰、已读、未读实时同步
- [x] 聊天页：文本/图片/语音/视频/文件/表情
- [x] 输入状态（Typing）与发送态/失败重试
- [x] 单聊设置页（清空历史、免打扰、投诉/拉黑入口）
- [x] 群设置页（公告、成员管理、退群、解散、转让群主）
- [x] 群审批流（邀请审核/入群审核）
- [x] 联系人主页到私信/建群的闭环

## 2.2 P1（强烈建议）
- [x] 位置消息（地图）
- [x] 名片消息
- [x] 自定义卡片消息（活动卡片、DJ/Set 卡片）
- [x] 聊天搜索（会话内搜索 + 全局聊天搜索）
- [x] 多端登录策略（挤下线策略明确化）

## 2.3 P2（可后置）
- [x] 二维码加好友/入群
- [ ] 1v1 音视频通话
- [ ] 更细粒度的聊天主题/字号/可访问性设置

## 2.4 你当前业务特有（建议）
- [x] 聊天与社区未读统一红点聚合（99+）
- [x] 社区互动详情点击即清零（你已明确要求）
- [x] 全通知中心统一编排（聊天 + 社区 + 活动提醒）

---

## 3. Raver 当前到 Demo 的差距（面向改造）

## 3.1 已具备（你当前项目已有基础）
- OpenIM iOS SDK 已接入
- 会话/消息基础链路已打通
- 未读聚合框架已存在
- 通知中心方案已拆分并在推进

## 3.2 关键差距
- 聊天域模块化程度不够（Conversation/ChatSetting/Contact 没有完全产品化拆分）
- 消息类型的“统一渲染协议 + Cell 工厂”仍需强化
- 群管理能力虽有后端基础，但 iOS 端交互闭环还不完整
- 搜索、二维码、位置、名片、自定义卡片需统一规范
- 全链路观测（登录状态机、消息实时事件、失败重试）需标准化

---

## 4. 分阶段改造路线（执行版）

## Phase 0：能力冻结与对齐（1-2 天）
- 目标：冻结“要 1:1 的范围”，避免边做边改。
- 任务：
  - 完成第 2 节勾选
  - 输出《能力范围冻结表》
  - 定义验收口径（实时、稳定性、UI 一致性）
- 验收：
  - 范围冻结文档签字
  - P0/P1/P2 清晰

## 4.1 你已勾选能力的逐项落地（Demo 对标 + Raver 实施）

> 约定：以下仅列你已勾选能力。每个能力都给出 `openim-ios-demo` 的典型做法、你项目的具体落地步骤与验收口径。  
> 状态定义：`NotStarted / InProgress / Done / Blocked`

### F01 会话列表：置顶 / 免打扰 / 已读 / 未读实时同步
- Demo 实现方法（对标）：
  - `OUIIM/Classes/Conversation` 按会话事件驱动更新列表，不依赖固定轮询。
  - 使用 SDK 会话变更回调 + 未读总数回调，统一刷新排序与 badge。
- Raver 落地方案：
  - iOS：`OpenIMSession` 只保留实时事件驱动；`OpenIMChatStore` 作为单一会话真源（排序、未读、置顶）。
  - Server：仅保留会话管理与映射接口，不再承担“兜底轮询”职责。
  - UI：`MessagesHomeView + MainTabView` 统一读取 `OpenIMChatStore.unreadTotal`。
- 验收：
  - 双机在线时，会话列表最后一条、未读、置顶顺序在 1s 内同步。
  - App 前后台切换后不会退回“必须手动刷新才变化”。
- 状态：`InProgress`

## 4.2 Demo 代码级映射（持续补全）

### 已完成映射（第一批）
- Demo: `OUICore/Classes/Core/IMController.sendTextMessage / sendHelper`
  -> Raver: `OpenIMChatStore.sendMessage`（先插入 sending，本地回显；成功替换；失败标记 failed）
- Demo: `OUIIM/Classes/OIMUIChat/Controller/DefaultChatController.resend`
  -> Raver: `OpenIMChatStore.resendFailedMessage` + `ChatActionRouter.resend`
- Demo: `OIMConversationListener.onConversationUserInputStatusChanged`
  -> Raver: `OpenIMSession.inputStatusPublisher` + `ChatView` 输入中提示（当前 SDK 回调不可用时，转为 `typing` 消息事件化通道，且不入历史消息）
- Demo: `Message.status + StatusView`
  -> Raver: `ChatMessage.deliveryStatus + ChatView.deliveryStatusView`

### 待完成映射（下一批）
- Demo: `DefaultDataProvider` 历史消息分段加载与缓存策略
  -> Raver: 会话内历史消息分页与本地缓存结构化改造
- Demo: `ChatSetting` 单聊/群聊配置页拆分
  -> Raver: `Features/Messages/ChatSetting/*` 模块化
- Demo: `DefaultChatCollectionDataSource` 细粒度消息 Cell 工厂
  -> Raver: `MessageRenderRegistry` 扩展为类型化 renderer 工厂

### F02 聊天页：文本 / 图片 / 语音 / 视频 / 文件 / 表情
- Demo 实现方法（对标）：
  - `Chat/Cell` 体系按消息类型注册渲染器（CellController/DataSource）。
- Raver 落地方案：
  - iOS：引入 `MessageRenderRegistry`（消息类型 -> SwiftUI 渲染器）；先从文本与系统消息切入，再扩展媒体。
  - Server：透传 OpenIM 媒体消息元数据，保证消息体不丢字段。
- 验收：
  - 每类消息都支持发送成功、失败、重试、展示与点击预览。
- 状态：`InProgress`

### F03 输入状态（Typing）与发送态/失败重试
- Demo 实现方法（对标）：
  - Typing 用轻量事件，不入历史；发送态由本地消息状态机管理。
- Raver 落地方案：
  - iOS：`ChatActionRouter` 统一发送动作；为消息补充本地状态 `sending/sent/failed`。
  - OpenIM：Typing 通过 custom/typing event 发出并在会话头展示。
- 验收：
  - 对端输入中状态实时可见；发送失败可一键重发且不会重复插入。
- 状态：`InProgress`

### F04 单聊设置页（清空历史 / 免打扰 / 投诉或拉黑入口）
- Demo 实现方法（对标）：
  - `ChatSetting` 独立模块，用户配置项与会话页解耦。
- Raver 落地方案：
  - iOS：新增 `Features/Messages/ChatSetting/Direct` 页面并由会话右上角进入。
  - Server：拉黑/举报走现有 notification-center 与 openim-admin 模块联动。
- 验收：
  - 单聊设置变更立即反映在会话列表与通知行为。
- 状态：`InProgress`

### F05 群设置页（公告 / 成员管理 / 退群 / 解散 / 转让群主）
- Demo 实现方法（对标）：
  - 群设置与成员结构视图分离，管理动作全部走群 API 并回推系统消息。
- Raver 落地方案：
  - iOS：新增 `ChatSetting/Group`、成员管理页、转让与踢人操作面板。
  - Server：复用已打通 openim 群镜像接口（你此前 smoke 已通过）。
- 验收：
  - “提管理员/转让群主/踢人/解散”双端一致，且系统提示消息可见。
- 状态：`InProgress`

### F06 群审批流（邀请审核 / 入群审核）
- Demo 实现方法（对标）：
  - 联系人域提供申请列表，群主/管理员审批后会话即时变更。
- Raver 落地方案：
  - iOS：新增 `GroupApplications` 入口并显示待处理计数。
  - Server：将审批结果写入 openim webhook event，驱动客户端刷新。
- 验收：
  - 审批通过/拒绝后，申请列表与群成员列表同时正确变化。
- 状态：`NotStarted`

### F07 联系人主页 -> 私信 / 建群闭环
- Demo 实现方法（对标）：
  - 用户详情页直达 `start direct conversation`，并可邀请入群。
- Raver 落地方案：
  - iOS：在 `Profile/User` 增加强制主路径 CTA：发私信、邀请进群。
  - Server：复用 `/v1/chat/direct/start` 与群邀请 API。
- 验收：
  - 从任意用户主页进入，3 步内必达聊天。
- 状态：`InProgress`

### F08 位置消息（地图）
- Demo 实现方法（对标）：
  - 消息体承载经纬度与 POI，聊天页可展开地图预览。
- Raver 落地方案：
  - iOS：新增位置发送面板（地图选点 + reverse geocode）。
  - 配置：按 `CONFIGKEY.md` 管理地图 key，区分开发与生产。
- 验收：
  - 发送位置后可在聊天中看到静态预览并点击跳转地图。
- 状态：`NotStarted`

### F09 名片消息
- Demo 实现方法（对标）：
  - Card message 结构化展示用户头像、昵称、跳转行为。
- Raver 落地方案：
  - iOS：基于 `UserSummary` 封装名片消息 payload。
  - Server：名片 payload 统一 schema，避免后续兼容成本。
- 验收：
  - 点击名片直达用户主页；消息可转发。
- 状态：`NotStarted`

### F10 自定义卡片消息（活动卡片 / DJ/Set 卡片）
- Demo 实现方法（对标）：
  - `customElem` + 本地 schema 解析 + 对应渲染组件。
- Raver 落地方案：
  - iOS：定义 `raver.chat.card.v1` schema，类型含 `event|dj_set`。
  - Server：提供卡片摘要接口（标题、封面、时间、深链）。
- 验收：
  - 卡片可发送、展示、点击跳转；旧版本按降级文本显示。
- 状态：`NotStarted`

### F11 聊天搜索（会话内 + 全局）
- Demo 实现方法（对标）：
  - 本地索引 + SDK 历史消息检索结合，支持关键字与会话维度过滤。
- Raver 落地方案：
  - iOS：会话内搜索先做本地缓存检索，再补远端历史页。
  - Server：全局搜索由 BFF 聚合多会话结果并支持分页。
- 验收：
  - 关键字命中后可定位到消息上下文。
- 状态：`InProgress`

### F12 多端登录策略（挤下线）
- Demo 实现方法（对标）：
  - SDK 事件监听 `kickedOffline/tokenExpired`，前台明确提示并引导重登。
- Raver 落地方案：
  - iOS：`OpenIMSession` 建立登录状态机（single-flight、防重复 login）。
  - Server：token 更新策略统一，避免前后台切换触发 10102。
- 验收：
  - 前后台切换、多设备登录不再出现“无提示断流”。
- 状态：`InProgress`

### F13 二维码加好友 / 入群
- Demo 实现方法（对标）：
  - `QRCode` 模块统一解析 `user/group` 场景。
- Raver 落地方案：
  - iOS：新增扫码入口，解析后进入用户页或群邀请确认页。
  - Server：提供短链或二维码 payload 校验接口。
- 验收：
  - 扫码 2 步内完成加好友或发起入群申请。
- 状态：`NotStarted`

### F14 统一红点聚合（聊天 + 社区，99+）
- Demo 实现方法（对标）：
  - 会话未读与业务通知未读分层统计，再在 Tab 统一聚合展示。
- Raver 落地方案：
  - iOS：`AppState` 聚合 `openimUnread + communityUnread`，统一红色 badge，封顶 `99+`。
  - UI：会话内、列表页、TabBar 三处文案与颜色完全一致。
- 验收：
  - 所有入口 badge 规则一致，计数边界稳定。
- 状态：`InProgress`

### F15 社区互动详情点击即清零
- Demo 实现方法（对标）：
  - 通知明细进入即 mark-as-read（不是“看完才清零”）。
- Raver 落地方案：
  - iOS：进入 follow/like/comment 详情页时批量标记对应类型已读。
  - Server：`markNotificationsRead(type)` 幂等化。
- 验收：
  - 进入详情页后返回列表，badge 立即归零并与服务端一致。
- 状态：`InProgress`

### F16 全通知中心统一编排（聊天 + 社区 + 活动提醒）
- Demo 实现方法（对标）：
  - 消息通知与业务通知分源进入统一通知中心，由模板与规则驱动。
- Raver 落地方案：
  - Server：`notification-center` 模块统一模板、渠道、节流、审计。
  - iOS：按通知类型深链到会话、帖子、活动、DJ、Brand。
  - Web Admin：新增模板管理、发送策略、灰度开关。
- 验收：
  - 同一事件链路可追踪（生成 -> 推送 -> 点击 -> 落地页）。
- 状态：`InProgress`

## Phase 1：架构重整（3-5 天）
- 目标：把聊天域重构成可持续扩展的模块。
- 任务：
  - `Messages` 重拆为 `Conversation / Chat / ChatSetting / Contact`
  - 建立 `MessageRenderRegistry`（消息类型 -> 视图控制器）
  - 建立 `ChatActionRouter`（转发、撤回、复制、删除、举报）
  - 统一错误模型与重试策略
- 当前执行子项：
  - [x] 引入 `ChatMessageKind`（文本/图片/视频/语音/文件/表情/位置/名片/自定义/系统/typing）
  - [x] 新增 `ChatMessageRenderRegistry` 第一版并接入 `ChatView`
  - [x] 新增 `ChatActionRouter` 第一版（先打通 Copy 动作）
  - [x] 发送态/失败重试（`sending/sent/failed`）状态机
  - [x] 媒体消息真实渲染器（图片/视频/语音/文件）第一版
  - [x] 媒体消息发送入口第一版（相册图片/视频 -> OpenIM 发送链路）
  - [x] 媒体消息失败重发第一版（文本/图片/视频）
  - [x] 会话设置第一版（Chat Settings Sheet + 免打扰/清空历史接线）
  - [x] 会话设置/群设置页面拆分成独立模块（独立目录与动作接线）
  - [x] 媒体发送进度可视化（图片/视频上传进度百分比）
- 验收：
  - 新模块可独立编译
  - 主路径无回归（xcodebuild + 核心 UI smoke）

## Phase 2：会话与聊天主链路（5-8 天）
- 目标：把“像 Telegram/微信 的主观体验”先做稳。
- 任务：
  - 会话列表实时更新（排序、未读、置顶、免打扰）
  - 聊天窗口实时收发、已读回执、输入中
  - 离线回补策略（事件驱动补偿，不做固定轮询）
  - 会话页与聊天页的一致状态同步
- 当前执行子项：
  - [x] 前后台恢复优先自愈（避免反复 refresh bootstrap）
  - [x] 10102 重复登录防抖（`logging` 状态等待 + 状态机去抖）
  - [x] 双模拟器探针稳定化（`snapshot` + `digest overall` 判定）
  - [x] 自动注入消息脚本（`npm run openim:probe:send`）
  - [x] 双机实时链路全绿验收（手动双机：`realtime message received` 稳定，且无 `catchup/10102/unavailable`）
- 验收：
  - 双机前后台切换不再出现重复登录导致断流
  - 收到消息不需返回列表即可即时展示

## Phase 3：联系人与群管理闭环（5-8 天）
- 目标：补齐社交关系链与群治理。
- 任务：
  - 联系人列表、好友申请、黑名单
  - 建群、邀请、审批、踢人、禁言、退群、解散、转让群主
  - 群公告、群成员搜索、群昵称
  - 群设置页（对标 `ChatSetting`）
- 验收：
  - 群治理 smoke 脚本全绿
  - 后台状态与客户端展示一致

## Phase 4：消息类型扩展（4-7 天）
- 目标：补齐你业务所需消息类型。
- 任务：
  - 文件/位置/名片/系统消息渲染
  - 活动卡片、DJ/Set 卡片（Custom message schema）
  - 富媒体上传与下载体验（进度、失败重试、预览）
- 验收：
  - 每种消息类型均有发送、接收、渲染、失败回退路径

## Phase 5：通知与未读一体化（3-5 天）
- 目标：你要求的统一红点 + 系统通知全接入。
- 任务：
  - Tab 红点统一为红色计数，`99+` 封顶
  - 聊天/社区事件统一进入通知中心
  - 详情页进入即清零（按你的规则）
  - APNs/推送点击深链到位
- 验收：
  - 红点在列表/详情/返回路径一致
  - 通知点击可直达对应会话/内容

## Phase 6：商用加固（5-10 天）
- 目标：从“能用”到“可商用”。
- 任务：
  - 压测（并发、峰值消息、恢复时间）
  - 观测（登录状态机、消息延迟、失败率、重试率）
  - 灰度与回滚预案
  - 安全与合规（敏感词、审核、举报、审计日志）
- 验收：
  - 达到你设定的并发与稳定性阈值
  - SLO/告警与应急手册齐全

---

## 5. 工程落地（建议文件改动清单）

## iOS
- `mobile/ios/RaverMVP/RaverMVP/Features/Messages/Conversation/*`
- `mobile/ios/RaverMVP/RaverMVP/Features/Messages/Chat/*`
- `mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatSetting/*`
- `mobile/ios/RaverMVP/RaverMVP/Features/Contacts/*`
- `mobile/ios/RaverMVP/RaverMVP/Core/OpenIM/*`
- `mobile/ios/RaverMVP/RaverMVP/Core/NotificationCenter/*`

## Server
- `server/src/services/openim/*`
- `server/src/services/notification-center/*`
- `server/src/routes/openim.routes.ts`
- `server/src/routes/notification-center.routes.ts`

## Web Admin
- `web/src/app/admin/openim/*`
- `web/src/app/admin/notification-center/*`

---

## 6. 风险与规避

- 登录状态机重入导致 `10102`：  
  规避：single-flight + SDK login status precheck + 10102 自愈。
- 实时事件丢失导致 UI 不刷新：  
  规避：事件驱动补偿同步（前台恢复/点击通知/重连后一次性补拉）。
- 消息类型增长导致渲染膨胀：  
  规避：RenderRegistry + 协议化 CellController。
- 群治理权限错配：  
  规避：服务端权限为真源，客户端仅做展示与引导。

---

## 7. 进度勾选（执行中持续更新）

- [x] Phase 0 完成（能力范围冻结）
- [ ] Phase 1 完成（架构重整，进行中）
- [ ] Phase 2 完成（会话/聊天主链路）
- [ ] Phase 3 完成（联系人/群治理）
- [ ] Phase 4 完成（消息类型扩展）
- [ ] Phase 5 完成（通知与未读一体化）
- [ ] Phase 6 完成（商用加固）

---

## 8. 执行日志（按日期追加）

### 2026-04-22
- 初始化文档：完成 openim-ios-demo 能力映射、复刻清单、阶段计划。
- 你已完成复刻范围勾选：P0 全选，P1 全选，P2 仅二维码，业务特有 3 项全选。
- 已完成 Phase 0：范围冻结与验收口径冻结，后续按本文执行并实时写回。
- 新增“4.1 逐项落地”区，逐功能记录 Demo 对标方式、Raver 落地步骤、验收与状态。

### 2026-04-23
- 开始 Phase 1 架构执行，已落地以下代码：
  - `mobile/ios/RaverMVP/RaverMVP/Core/Models.swift`：新增 `ChatMessageKind` 与兼容解码逻辑。
  - `mobile/ios/RaverMVP/RaverMVP/Core/OpenIMSession.swift`：OpenIM 消息 -> `ChatMessageKind` 映射。
- 新增 OpenIM 实时注入脚本（用于双机探针复测，不依赖手工点按）：
  - 新增：`server/src/scripts/openim-probe-send.ts`
  - 新增 npm script：`npm run openim:probe:send`
  - 新增 env 模板：`server/.env.openim.example`（`OPENIM_PROBE_*`）
  - Runbook 更新：`docs/OPENIM_DUAL_SIM_BADGE_RUNBOOK.md` 增加“自动注入消息”流程。
- 验证：
  - `cd /Users/blackie/Projects/raver/server && npm run build`：通过。
  - `cd /Users/blackie/Projects/raver/server && npm run openim:probe:send`（未配 `OPENIM_PROBE_*`）按预期 fast-fail：`Missing required sender identifier`。
  - 双机 snapshot 复测目录 `openim-dual-sim-20260423-085548`：`sim1/sim2` 均 0 行；判定为“采集未完成样本”（未触发 snapshot 退出采集）。
  - 脚本改进：`openim_dual_sim_probe.sh` 在 `snapshot + summary` 下明确提示“退出前计数可能全 0”；新增 `OPENIM_PROBE_AUTO_STOP_SECONDS` 自动结束并触发采集。
  - Runbook 同步补充 snapshot 注意事项与 auto-stop 用法。
  - `mobile/ios/RaverMVP/RaverMVP/Features/Messages/Chat/Rendering/ChatMessageRenderRegistry.swift`：消息渲染注册中心 V1。
  - `mobile/ios/RaverMVP/RaverMVP/Features/Messages/Chat/Actions/ChatActionRouter.swift`：聊天动作路由 V1。
  - `mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift`：接入 registry + context menu copy action。
- 编译验证：
  - `xcodebuild -project ...` 失败（缺失 `MJExtension` 链接路径，属于 xcodeproj + pods 入口问题）。
  - `xcodebuild -workspace ...` 成功（作为当前权威构建入口）。
- 结论：当前改动已可编译，后续统一使用 workspace 验证。
- 根据你最新要求（“每个功能逻辑按 demo 一样”）新增 0.1 强对标原则与 4.2 代码级映射表。
- 已开始对齐 Demo 核心机制：
  - 消息发送状态机（sending/sent/failed）
  - 失败重发动作
  - 输入状态事件监听 + 输入中提示
- 新增编译修复：
  - `ChatActionRouter` 处理 `error.userFacingMessage` 可选值，修复 `ChatActionResult.failed(reason:)` 编译失败。
  - `OpenIMSession` 移除 closure 版 `onConversationUserInputStatusChanged` 参数接入（当前 SDK 头文件为 `[NSNumber]`，与预期模型不一致）。
- SDK 兼容性发现（关键记录）：
  - 当前工程使用 `OpenIMSDK 3.8.3-hotfix.12`。
  - Pod 源码中 `OIMCallbacker.m` 的 `onConversationUserInputStatusChanged` 实现为空，导致该回调链路不可依赖。
- 对齐 Demo 的替代落地（可商用路径）：
  - 在 `OpenIMChatStore` 将 `typing` 作为“实时事件”处理，而不是普通消息入库（不增加未读、不污染消息列表）。
  - 事件化 typing 直接驱动会话头“正在输入”提示，发送态/失败重试继续走消息状态机。
- 构建验证（最新）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`
- 新增媒体渲染与设置骨架：
  - `Core/Models.swift`：新增 `ChatMessageMediaPayload`，消息结构支持媒体元数据（url/缩略图/时长/文件名/大小）。
  - `Core/OpenIMSession.swift`：补齐 `OIMPictureElem/OIMVideoElem/OIMSoundElem/OIMFileElem` 到 `ChatMessage.media` 的映射。
  - `Features/Messages/Chat/Rendering/ChatMessageRenderRegistry.swift`：升级为真实媒体渲染：
    - 图片：缩略图气泡 + 全屏查看
    - 视频：封面 + 播放标识 + 全屏播放
    - 语音：播放/暂停气泡
    - 文件：文件卡片 + 可点击跳转
  - `Features/Messages/ChatView.swift`：顶部 `...` 改为统一聊天设置入口，新增 `ChatSettingsSheet`（免打扰 + 清空历史已接线，退群保留下一阶段）。
- 聊天设置动作接线（本轮）：
  - `Core/OpenIMSession.swift`：新增 `setConversationMuted`、`clearConversationHistory`。
  - `Core/SocialService.swift` / `Core/LiveSocialService.swift`：暴露并实现对应 service 接口。
  - `Core/OpenIMChatStore.swift`：新增 `clearMessages(for:)` 本地状态同步。
  - `ChatSettingsSheet`：免打扰 Toggle 触发 OpenIM `setConversationRecvMessageOpt`；清空聊天触发 OpenIM `clearConversationAndDeleteAllMsg` 并刷新本地会话状态。
- 构建验证（本轮追加）：
  - 命令同上（workspace 入口）
  - 结果：`BUILD SUCCEEDED`
- ChatSetting 模块化与退群链路补齐：
  - iOS：
    - 新增 `Features/Messages/ChatSetting/ChatSettingsSheet.swift`
    - 新增 `Features/Messages/ChatSetting/DirectChatSettingsSection.swift`
    - 新增 `Features/Messages/ChatSetting/GroupChatSettingsSection.swift`
    - `ChatView` 移除内联设置页，改为独立模块接入
    - `SocialService` / `LiveSocialService` / `MockSocialService` 新增 `leaveSquad(squadID:)`
    - `OpenIMChatStore` 新增 `removeConversation(conversationID:)`，退群后本地会话即时剔除
  - Server：
    - `server/src/routes/bff.routes.ts` 新增 `POST /v1/squads/:id/leave`
    - 退群流程包含：权限校验、DB 删除成员、系统消息写入、OpenIM 移除成员、失败回滚
  - 构建验证：
    - `xcodegen generate`（重新同步新文件到工程）
    - `xcodebuild -workspace ... -scheme RaverMVP ... build -quiet`：通过（仅 warning）
    - `cd server && npm run build`：通过
- 媒体发送链路（图片/视频）第一版补齐：
  - iOS：
    - `Core/OpenIMSession.swift`：新增
      - `sendImageMessage(conversationID:fileURL:)`
      - `sendVideoMessage(conversationID:fileURL:)`
      - 发送目标解析与统一发送 helper（对齐文本发送链路）
      - 视频发送时自动生成本地封面图（snapshot）并按文件扩展推断 MIME
    - `Core/SocialService.swift` / `Core/LiveSocialService.swift` / `Core/MockSocialService.swift`：新增媒体发送接口实现。
    - `Core/OpenIMChatStore.swift`：新增
      - `sendImageMessage(...)`
      - `sendVideoMessage(...)`
      并复用本地 `sending -> sent/failed` 状态机。
    - `Features/Messages/ChatView.swift`：
      - 聊天输入栏新增图片/视频选择按钮（`PhotosPicker`）
      - 选择后写入临时文件并走 OpenIM 媒体发送
      - 发送中态接入页面 loading 覆盖层
  - 构建验证：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
    - 结果：通过（仅 iOS 17 traitCollection 与 Pods deployment target warning）
- 群成员管理动作第一版接线（提管理员/降级成员/转让队长/移出成员）：
  - iOS Service：
    - `SocialService` 新增：
      - `updateSquadMemberRole(squadID:memberUserID:role:)`
      - `removeSquadMember(squadID:memberUserID:)`
    - `LiveSocialService` 对接 BFF：
      - `PATCH /v1/squads/:id/members/:memberUserId/role`
      - `POST /v1/squads/:id/members/:memberUserId/remove`
    - `MockSocialService` 同步实现角色变更与移除逻辑（包含 leader/admin 权限边界）。
  - iOS UI：
    - `SquadProfileViewModel` 新增成员动作方法：`updateMemberRole`、`removeMember`。
    - `SquadProfileView` 在成员头像增加长按菜单（context menu）：
      - 队长：设为管理员 / 降为成员 / 转让队长 / 移出小队
      - 管理员：移出普通成员
    - 移出成员使用确认对话框（confirmation dialog）。
  - 构建验证：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
    - 结果：通过（warning 同上）
- 媒体消息失败重发补齐（本轮）：
  - `OpenIMChatStore.resendFailedMessage` 已支持：
    - 文本：`sendMessage`
    - 图片：`sendImageMessage`
    - 视频：`sendVideoMessage`
  - 对图片/视频重发增加本地文件可用性校验（`file://` 或绝对路径存在），缺失时返回明确错误。
  - 构建验证：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
    - 结果：通过。
- BFF 管理动作脚本化回归入口（本轮）：
  - 新增：`server/src/scripts/openim-bff-squad-manage-smoke.ts`
  - 新增 npm script：`npm run openim:bff:squad-manage:smoke`
  - 脚本流程：
    1. 三个用户登录（队长/成员A/成员B）
    2. 建群（满足 3 人约束）
    3. 成员A 提管理员
    4. 转让队长给成员A
    5. 成员A 移出成员B
    6. 原队长退群
    7. 拉取 profile 校验最终 leader 与成员集合
  - 新增环境变量模板：`server/.env.openim.example`（`OPENIM_BFF_SMOKE_*`）
  - 构建验证：
    - `cd server && npm run build`：通过。
  - 运行入口可用性验证：
    - `npm run openim:bff:squad-manage:smoke`
    - 在未配置 `OPENIM_BFF_SMOKE_*` 时按预期 fast-fail（缺失必填 env），用于防止误跑空配置。
- 双模拟器日志可读性增强（本轮）：
  - 改造：`mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
    - 默认改为 `OPENIM_PROBE_LIVE_MODE=summary`（每 5 秒一行低噪声状态：`conn/rt/catchup/10102/unavail`）
    - 保留 `OPENIM_PROBE_LIVE_MODE=stream`（关键行流式输出）与 `OPENIM_PROBE_RAW_MODE=1`（原始日志）
    - 退出时自动生成 digest 结论
  - 新增：`mobile/ios/RaverMVP/scripts/openim_probe_digest.sh`
    - 自动读取最新 `docs/reports/openim-dual-sim-*`
    - 输出每个模拟器的链路判定：
      - 实时链路主导
      - 实时 + 补偿并存
      - 主要依赖 catchup
      - 可能重复登录冲突（10102）
      - 会话未建立（unavailable）
  - 文档更新：`docs/OPENIM_DUAL_SIM_BADGE_RUNBOOK.md` 增加新脚本与模式说明。
- 媒体发送进度链路打通（本轮）：
  - `OpenIMSession`：`sendImageMessage/sendVideoMessage` 新增 `onProgress` 回调，透传 SDK `sendMessage.onProgress`。
  - `LiveSocialService`：补齐进度版发送接口，实现 OpenIM 上传进度上抛。
  - `OpenIMChatStore`：发送图片/视频时支持 `onProgress(Double)`，统一 `0...1` 进度。
  - `ChatView`：发送媒体时展示线性进度条与百分比，完成后自动收起。
  - 构建验证：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
    - 结果：通过（仅既有 warning）。
- Phase 2 稳定性修复（本轮）：
  - 问题背景：
    - 双机测试中，前后台切换后出现 `10102 User has logged in repeatedly`，导致会话接口不可用或延迟恢复。
  - 修复点：
    - `OpenIMSession.loginIfNeeded` 增加 `sdkStatus == .logging` 稳态等待（短等待后仍 logging 则跳过重复 login，保持 `.connecting`，等待 SDK 自愈）。
    - `OpenIMSession` 在 `10102` 场景补充分支：若检测到 SDK 仍在 `logging`，按“进行中”处理，不再直接抛失败。
    - `waitForConnectionIfNeeded` 超时从 `1800ms` 提升到 `5000ms`，降低前后台恢复窗口内误判 unavailable。
    - `AppState.didBecomeActive` 增加 bootstrap 刷新门控：
      - OpenIM 已健康连接时不强制 refresh bootstrap；
      - 距离上次 refresh < 90s 时跳过，避免前后台频繁抖动触发重复登录。
  - 构建验证：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
    - 结果：通过（仅既有 warning）。
- Phase 2 前台自愈优先（本轮）：
  - `OpenIMSession` 新增 `recoverSessionAfterAppBecameActive()`：
    - SDK `logged` 且用户匹配：直接提升到 `.connected` 并重挂 realtime listeners；
    - SDK `logging`：保持 `.connecting`，不触发重复 login；
    - SDK `logout` 或用户不匹配：返回失败，交由 bootstrap refresh 处理。
  - `AppState.didBecomeActive` 改为：
    1. 先尝试 `openIMSession.recoverSessionAfterAppBecameActive()`；
    2. 仅当自愈失败且门控允许时才 `refreshOpenIMBootstrap`。
  - 目标：
    - 降低前后台切换触发的重复登录概率；
    - 减少无必要 bootstrap 调用，压低 `10102` 出现窗口。
  - 构建验证：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
    - 结果：通过（仅既有 warning）。
- Phase 2 `kickedOffline` 语义修正（本轮）：
  - 背景：
    - 历史日志中出现 `OpenIM state -> kickedOffline`，此前策略会自动触发 recovery，可能造成循环重连。
  - 调整：
    - `AppState.handleOpenIMStateChange` 中：
      - `tokenExpired`：保留自动恢复；
      - `kickedOffline`：取消自动恢复任务，改为用户可见提示（其他设备登录），避免重试风暴。
  - 价值：
    - 符合成熟 IM 客户端常见策略（被挤下线给出明确提示，不盲目自动重连）。
  - 构建验证：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
    - 结果：通过（仅既有 warning）。
- Phase 2 状态机去抖（本轮）：
  - `OpenIMSession`：
    - 新增 `setStateIfNeeded`，避免重复状态赋值；
    - `onConnecting` 回调在已 `connected` 时不再降级为 `connecting`；
    - `onConnectSuccess/onConnectFailure/onKickedOffline/onUserTokenExpired/onUserTokenInvalid` 全部改为去重状态更新；
    - `loginIfNeeded` 与前台自愈链路中的 `connecting/connected` 更新改为去重赋值。
  - `AppState`：
    - `handleOpenIMStateChange` 增加短路：状态未变化时直接返回，不重复触发恢复逻辑与日志。
  - 目标：
    - 降低 `connecting -> connected -> connecting -> connected` 抖动；
    - 减少重复 recovery 与误导性日志噪音。
  - 构建验证：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
    - 结果：通过（仅既有 warning）。
- 双机探针稳定性增强（本轮）：
  - `openim_dual_sim_probe.sh`：
    - 预创建 `sim1/sim2` 的 raw/focus/err 日志文件，避免缺文件导致误判；
    - 增加 `sim1.err.log/sim2.err.log`，将 `log stream` stderr 独立落盘；
    - 启动时补抓最近 20 秒历史日志（seed snapshot），减少“空白报告”概率；
    - 退出时若某侧 raw 日志仍为空，自动执行 `log show --last` 回填（默认 180 秒窗口）；
    - 结束 summary 时对空日志给出显式 warning（含 app-running-check 与 err tail）。
    - trap 增强：`INT/TERM/QUIT` 都会走统一收尾逻辑，避免异常中断后无 summary。
    - 新增 `OPENIM_PROBE_TRANSPORT=snapshot`：不依赖实时流，退出时一次性抓取窗口日志，适合双机流式采集不稳定场景。
    - 本机验证：`snapshot` 短跑可稳定产出双侧 raw 日志（均 > 0 行），`digest` 输出 `overall: 双侧日志有效`。
  - `openim_probe_digest.sh`：
    - 对“日志文件缺失”给出 `采集失败` 结论；
    - 输出每个 source 的行数，空日志时提示“采集管道未建立或无有效采样”。
    - 输出 `overall` 总结：任一侧 0 行即标记“部分无效”，禁止据此下业务结论。
    - 输出 `appEvents` 计数：任一侧 `appEvents=0` 也判定 `overall=部分无效`，避免把系统日志噪音误判为有效样本。
  - 本轮历史报告结论（你当前打开的目录）：
    - `openim-dual-sim-20260422-212445` / `220720`：双侧日志均为空，报告无效；
    - `openim-dual-sim-20260422-222001`：`SIM1` 有实时证据，`SIM2` 基本空采样；
    - `openim-dual-sim-20260423-064331`：`SIM1` 正常，`SIM2` 0 行（需补双侧交互复测）。

---

## 9. 持续执行记忆区（防丢上下文）

> 规则：每次继续推进前先看本节，避免重复劳动或遗漏关键背景。

### 9.1 当前冻结范围（最终）
- 做：F01-F16（见 4.1），其中音视频通话与主题定制暂不做。
- 强约束：
  - 不使用固定轮询作为常态链路。
  - OpenIM 为聊天主链路真源，不再回退 BFF 聊天兜底。
  - 红点统一为红色，封顶显示 `99+`。
  - 社区详情页“进入即清零”。

### 9.2 已完成
- Phase 0 范围冻结。
- OpenIM iOS 接入基础链路（初始化、登录、会话/消息基础流）已在之前迭代完成。
- 群镜像服务端基础能力（建群/提管理员/转让群主/踢人）已有 smoke 通过记录。

### 9.3 进行中
- Phase 1 架构重整：
  - 目标 1：消息渲染注册中心（MessageRenderRegistry）
  - 目标 2：聊天动作路由（ChatActionRouter）
  - 目标 3：错误模型与重试语义标准化
  - 最新进展：目标 1/2/3 基础能力已落地，已进入 Phase 2 稳定性收口（前后台恢复、10102 防重登、双机实时链路验收）。

### 9.4 下一次继续时的第一步
1. 基于 `xcworkspace` 跑一次构建，确认基线。
2. 跑双机探针并产出 digest：
   - `bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
   - `bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh`
3. 在探针期间执行自动注入：
   - `cd /Users/blackie/Projects/raver/server && OPENIM_PROBE_SESSION_TYPE=single OPENIM_PROBE_SENDER_IDENTIFIER=<sender> OPENIM_PROBE_RECEIVER_IDENTIFIER=<receiver> OPENIM_PROBE_MESSAGE_COUNT=5 npm run openim:probe:send`
4. 重点复测“后台 -> 前台”场景，确认不再出现 `10102` 且会话页实时收消息。
5. 复测通过后，将 Phase 2 的“前后台恢复 + 实时链路”子项在第 7 节更新勾选并落日志。

### 9.5 风险快照
- `10102 User has logged in repeatedly`：优先修状态机重入，不以轮询掩盖。
- 双机测试时模拟器启动不稳定：统一使用脚本固定 UDID + 启动前健康检查。
- `onConversationUserInputStatusChanged` 在当前 SDK 版本不可用：typing 先走消息事件化通道，后续评估 SDK 升级窗口。

---

## 10. 聊天数据存储对齐（Raver vs openim-ios-demo）

> 目的：把“聊天记录如何存、谁是真源、如何回放与恢复”标准化，避免后续功能继续堆在不稳定的数据层上。

### 10.1 Raver 当前存储模型（已落地）

- OpenIM SDK 本地数据库：
  - iOS 初始化时显式设置 `dataDir`，落在应用沙盒 `Application Support/OpenIM`。
  - 会话/消息读取主要走 SDK 本地库（不是 BFF 轮询拉取）。
- App 内存态：
  - `OpenIMChatStore` 维护会话列表、未读总数、会话消息缓存（内存态），用于 UI 实时渲染。
- 媒体临时文件：
  - 聊天选择器媒体走 `tmp` 临时目录；视频封面走独立临时目录。
- 服务端持久化：
  - 旧聊天表仍在（迁移期兼容/审计），但聊天主链路目标是 OpenIM。
  - OpenIM webhook、举报、审核任务表用于治理与追踪。

### 10.2 openim-ios-demo 存储模型（对标基线）

- OpenIM SDK 本地数据库作为聊天主真源（会话 + 历史消息）。
- 会话列表有轻量快照缓存（`UserDefaults`），用于冷启动更快出首屏。
- 当前会话消息集以内存 DataProvider 驱动，再按需从 SDK 历史分页补齐。
- 图片/媒体依赖成熟缓存层（内存 + 磁盘）与统一加载器。

### 10.3 差异与风险（必须收口）

- 差异 A：Raver 还缺“会话快照层”（类似 demo 的 ConversationStorage）。
  - 风险：冷启动首屏抖动，弱网下 `Loading conversation...` 体感明显。
- 差异 B：Raver 媒体缓存策略仍偏分散（tmp + 组件内处理）。
  - 风险：发送后状态清理不一致、缓存回收不可控。
- 差异 C：Raver 还没有独立的本地消息索引层（为会话内/全局搜索服务）。
  - 风险：后续搜索功能只能依赖远端补拉，体验和成本都不稳。
- 差异 D：UI 层仍有部分“视图更新中发布状态”警告。
  - 风险：可能诱发局部 loading 卡住或状态闪烁。

### 10.4 分阶段改造任务（存储专项）

- [x] S-0 存储现状盘点冻结（Raver 与 demo 对齐表）
- [x] S-1 会话快照缓存（冷启动秒开，V1 已落地）
  - iOS：新增 `ConversationSnapshotStore`（按用户隔离）。
  - 读取顺序：本地快照 -> SDK 本地库 -> 实时事件增量。
- [x] S-2 消息分页与本地窗口缓存重整（V1 已落地）
  - iOS：按会话维护分页游标与去重策略，避免重复插入/乱序刷新。
- [x] S-3 媒体缓存管理器（V1 已落地）
  - iOS：统一图片/视频/语音/文件缓存目录、TTL、清理策略、命中/淘汰指标日志。
- [x] S-4 搜索索引预埋（为 F11 做准备，V1 已落地）
  - iOS：会话内倒排索引 + 远端补偿查询接口抽象。
- [x] S-5 数据治理与容量策略（V1 已落地）
  - iOS：本地数据库与媒体缓存上限、清理策略、故障恢复手册。

### 10.5 存储专项验收标准

- 冷启动进入消息页，首屏会话列表在 300ms 内可见（快照命中场景）。
- 进入会话后不再出现“无限 Loading conversation...”。
- 媒体发送成功后，发送中态在消息状态变更后立即收敛，不残留。
- 前后台切换后，会话与消息均由 SDK 本地库 + 实时事件恢复，不依赖固定轮询。

### 10.6 执行日志（存储专项）

#### 2026-04-23（新增）
- 完成 Raver 与 openim-ios-demo 存储模型映射梳理并落文档。
- 明确当前聊天主真源为 OpenIM SDK 本地数据库，BFF 聊天兜底不作为目标路线。
- 新增存储专项任务清单 S-0 到 S-5，后续每次迭代按勾选推进并写回日志。
- 已实现 S-1（V1）：
  - `OpenIMChatStore` 新增按用户会话快照读写（`UserDefaults + JSONEncoder/Decoder.raver`）。
  - 会话加载顺序改为：优先恢复本地快照，再并发拉取 direct/group 并回写快照。
  - 构建验证通过：`xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP ... build -quiet`（exit 0）。
- 已实现 S-2（V1）：
  - `OpenIMChatStore` 新增会话级消息分页状态（`oldestClientMsgID / reachedBeginning / isLoadingOlder`）。
  - 历史拉取改为 `startClientMsgID` 分页：首屏 `start=nil`，上拉历史使用最旧消息 ID 继续拉取。
  - 消息合并统一走去重排序（按 `message.id` 去重），避免重复插入与乱序。
  - `OpenIMSession` 新增 `fetchMessagesPage(conversationID:startClientMsgID:count:)`，透传 OpenIM `isEnd`。
  - `LiveSocialService / MockSocialService` 已接入分页消息页模型（`ChatMessageHistoryPage`）。
  - `ChatView` 新增顶部历史触发与 older loading 指示，且滚动到底部逻辑改为仅监听“最新消息 ID”变化，避免分页时误滚底。
  - 构建验证通过：`xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`（exit 0）。
- S-2 热修（进入会话偶发不滚底）：
  - 现象：部分场景进入会话后未自动跳到最底部。
  - 根因：仅监听 `latestMessageID` 变化时，若进入会话前后“最后一条消息 ID 未变化”，`onChange` 不触发，导致不滚底。
  - 修复：`ChatView` 新增 `forceScrollBottomToken`，在“进入会话”和“首轮 loadMessages 完成后”各触发一次强制滚底；分页历史加载不触发该 token，因此不影响上滑阅读。
  - 验证：同一会话反复进入、带缓存进入、首屏加载完成后均可稳定落到底部；上滑分页时不会被拉回底部。

#### 2026-04-24（S-3：媒体缓存管理器 V1）
- iOS 落地：
  - `Features/Messages/UIKitChat/Support/ChatMediaTempFileStore.swift`
    - 从临时目录升级为统一缓存根目录：`Library/Caches/raver-chat-media-cache`；
    - 按类型分目录：`image/video/voice/file/other`；
    - 增加缓存清理策略：
      - TTL：7 天；
      - 容量上限：512MB（超限按最近访问时间淘汰）；
      - 清理节流：10 分钟最多执行一次。
    - 增加可观测性日志（DEBUG）：
      - `write / hit / miss / evict`（同时写入 probe log）。
  - `Features/Messages/UIKitChat/Support/DemoAlignedMediaSendCoordinator.swift`
    - 媒体选择后落盘按类型写入缓存目录（image/video），不再混用单一临时目录。
  - `Features/Messages/UIKitChat/RaverChatMediaResolver.swift`
    - 本地 `file://` / 绝对路径解析接入缓存解析器，缺失文件计为 miss，命中计为 hit。
  - `Features/Messages/UIKitChat/DemoAlignedMediaMessageCell.swift`
    - 本地媒体预览读取时补充访问打点（用于刷新最近访问时间，减少误淘汰）。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target warning）。

#### 2026-04-24（S-4：搜索索引预埋 V1）
- iOS 落地：
  - 新增 `Core/ChatMessageSearchIndex.swift`：
    - 定义本地索引与检索结果模型（`ChatMessageSearchResult`）；
    - 支持会话内倒排索引（英文 token + CJK 字符 token）；
    - 新增远端补偿接口抽象（`ChatMessageSearchRemoteDataSource`）。
  - `OpenIMChatStore` 接入索引生命周期：
    - 消息替换/合并时增量更新索引；
    - 清空会话/移除会话/重置时同步清理索引；
    - 新增 `searchMessages(query:conversationID:limit:remoteDataSource:)`（本地优先，结果不足再远端补偿）。
  - `RaverChatDataProvider` / `RaverChatController` 新增搜索透传接口，为后续 F11 UI 接线预留。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target warning）。

#### 2026-04-24（S-5：数据治理与容量策略 V1）
- iOS 落地：
  - 新增 `Core/OpenIMStorageGovernance.swift`：
    - 审计对象：`Application Support/OpenIM`、`Library/Caches/raver-chat-media-cache`、`Library/Caches/openim-probe.log`；
    - 审计节流：10 分钟；
    - 阈值：OpenIM 数据目录 `warn>=1GiB`、`critical>=2GiB`；
    - probe 日志大于 4MiB 自动裁剪到 1MiB。
  - `AppState` 接入治理触发：
    - 启动时强制审计；
    - `didBecomeActive` 按节流审计。
  - `ChatMediaTempFileStore` 新增治理接口：
    - `performMaintenance(force:)`；
    - `managedRootURL()`（用于审计统计）。
- Runbook：
  - 新增 [`docs/OPENIM_STORAGE_GOVERNANCE_RUNBOOK.md`](/Users/blackie/Projects/raver/docs/OPENIM_STORAGE_GOVERNANCE_RUNBOOK.md)。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target warning）。

#### 2026-04-23（Demo 对齐重构 A2 第一轮）
- 新增 UIKit 同构分层首版：
  - `RaverChatDataProvider`：封装 `OpenIMChatStore` 读写（首屏、分页、发送、已读）。
  - `RaverChatController`：封装会话状态机（initial loading / older loading / canLoadOlder / error）。
  - `RaverChatCollectionDataSource`：封装 collection view 的消息数据绑定与 cell 渲染分发。
  - `DemoAlignedMessageCell`：消息气泡 cell 独立成文件，便于后续多类型 cell 工厂化。
- `DemoAlignedChatViewController` 已改为“UI 容器 + 滚动策略”职责：
  - 通过 `chatController` 订阅消息与加载状态。
  - 上滑分页位置保持逻辑保留在 VC（UI 级别），发送动作由 controller 执行。
- 工程同步与验证：
  - 已执行 `xcodegen generate`，并重新集成 Pods。
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`
- 下一步：
  - 拆出 `RaverChatCollectionDataSource`（cell 注册与渲染解耦）；
  - 然后进入媒体 Cell 工厂对齐（图片/视频/语音/文件）。

#### 2026-04-23（Demo 对齐重构 A2/A3 第二轮）
- 已完成 `RaverChatCollectionDataSource` 解耦，并引入：
  - `RaverChatMessageCellFactory`
  - `DemoAlignedMediaMessageCell`
  - `RaverChatScrollCoordinator`
- 结果：
  - VC 中滚动策略与 cell 分发职责进一步收敛；
  - message kind 已分流到“文本类 cell / 媒体类 cell”。
- 构建验证：
  - `xcodegen generate` 后执行  
    `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`

#### 2026-04-23（Demo 对齐重构 A4 首轮）
- 已在 UIKit 聊天页补齐“历史阅读不打断”交互：
  - 离开底部显示“回到底部”按钮；
  - 新消息在用户离底部时累计提示为“`N` 条新消息”（`99+` 上限显示）；
  - 点击提示后滚底并清零计数。
- 已加固首次进入会话落底：
  - `viewDidAppear` 首次补偿滚底，避免极端时序导致初次未到最底部。
- 代码位置：
  - `Features/Messages/UIKitChat/DemoAlignedChatViewController.swift`
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`

#### 2026-04-23（Demo 对齐重构 A4/A3 继续）
- UIKit 输入区媒体发送入口已接入：
  - `DemoAlignedChatViewController` 新增图片/视频按钮（`PHPickerViewController`）。
  - 选取媒体后复制到临时目录，再调用 `chatController.sendImageMessage/sendVideoMessage` 发送。
  - 发送媒体期间禁用媒体按钮与发送按钮，防止重复提交。
- 失败重发链路已接入 UIKit：
  - 点击失败消息触发 `chatController.resendFailedMessage(messageID:)`；
  - 文案调整为“发送失败·点按重发”（文本/媒体 cell 一致）。
- 控制层封装补齐：
  - `RaverChatDataProvider`：新增 `sendImageMessage` / `sendVideoMessage` / `resendFailedMessage`。
  - `RaverChatController`：新增上述三类动作封装与错误收口。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（Demo 对齐重构 A3 继续：媒体缩略图 + 预览）
- UIKit 媒体 cell 渲染增强：
  - `DemoAlignedMediaMessageCell` 新增 image/video 缩略图显示；
  - video 增加播放 icon 和时长 badge；
  - 复用时增加异步加载防串图策略（render token + `sd_cancelCurrentImageLoad`）。
- 点击交互对齐：
  - 失败消息点击优先重发；
  - image/video 点击进入全屏预览（复用 `FullscreenMediaViewer`）。
- URL 规则收口：
  - 新增 `RaverChatMediaResolver`，统一处理 file path / file:// / 相对路径 / 远端 URL 映射，保持和 SwiftUI 渲染层一致。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅 Pods deployment target 警告）。

#### 2026-04-23（Demo 对齐重构 A4 继续：媒体发送进度）
- UIKit 输入区新增媒体上传进度反馈：
  - `DemoAlignedChatViewController` 增加 `UIProgressView + 百分比文本`；
  - 图片/视频发送时通过 `onProgress` 回调实时更新；
  - 发送完成或失败后自动收起进度区域并重置状态。
- 交互约束保持一致：
  - 发送期间媒体按钮与发送按钮禁用，防止重复提交。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（OpenIM 双机排障观测增强）
- 新增 App 内部文件日志通道（Debug）：
  - 新增 `Core/OpenIMProbeLogger.swift`，日志落盘到 `Library/Caches/openim-probe.log`。
  - `OpenIMSession` / `OpenIMChatStore` / `AppState` / `ConversationLoader` 调试日志同步写入文件，避免仅依赖 `simctl log stream`。
- 双机探针增强：
  - `openim_dual_sim_probe.sh` 增加 `OPENIM_PROBE_USE_APP_LOG=1`（默认开启）。
  - 探针开始时会清空双端 `openim-probe.log`，探针结束时自动合并到 `sim1.log/sim2.log` 再跑 digest。
- digest 增强：
  - `openim_probe_digest.sh` 纳入 `ConversationLoader` 事件统计，减少“无效采样”误判。
- 目标：
  - 解决 `simctl log stream` 空采集导致“看不到原因”的问题，确保双机复测每次都有可判定日志。

#### 2026-04-23（双机手测验收结果：通过）
- 你已完成手动双机回归，结果：
  - 稳定命中 `realtime message received`
  - 未出现补偿路径：`catchup messages changed / catchup conversations changed`
  - 未出现异常：`10102 / OpenIM ... unavailable`
- 结论：
  - 当前 OpenIM iOS 主链路在你的本地双机测试中已达到“实时主导、无补偿依赖、无重复登录冲突”的阶段性通过标准。

#### 2026-04-23（UIKit 聊天页键盘动画收口）
- `DemoAlignedChatViewController` 完成键盘弹收跟随优化：
  - 监听 `keyboardWillChangeFrame / keyboardWillHide` 并按系统动画参数同步布局；
  - 键盘动画期间仅在“接近底部/正在输入”场景自动贴底，避免打断历史阅读；
  - 输入开始时主动贴底，键盘收起后做一次短延迟稳态贴底，降低抖动。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A5 第一轮：UIKit 聊天设置入口打通）
- 在 `DemoAlignedChatViewController` 增加右上角聊天设置入口（`...`）。
- UIKit 聊天页已可直接拉起 `ChatSettingsSheet`，并与原 SwiftUI 聊天保持一致能力：
  - 免打扰、清空历史、退群；
  - 单聊查看用户主页；
  - 群聊查看小队主页、管理小队（进入后可继续执行管理员/队长相关动作）。
- 路由对齐：
  - `DemoAlignedChatView` 注入 `appPush` 与 `dismiss` 环境到 UIKit 容器；
  - 设置页跳转回调至主路由，避免 UIKit 与 SwiftUI 导航割裂。
- 退群后行为：
  - 设置页完成退群会关闭并退出当前会话页面，行为与 SwiftUI 版本一致。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A5 第二轮：管理员动作提示链路）
- 群聊设置页新增权限态提示：
  - 拉取 `SquadProfile` 后显示“我的身份（队长/管理员/成员）”；
  - 管理入口按权限可用性展示（无权限时禁用并提示）。
- 高风险动作收口：
  - 退群新增二次确认；
  - 队长退群被拦截时，弹窗提示并支持一键跳转“管理小队”执行转让。
- 目标达成：
  - 聊天路径内已具备“权限认知 -> 管理入口 -> 高权限动作引导”的完整闭环。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A5 第三轮：邀请审核入口对齐）
- 聊天设置页（群聊）新增“邀请审核”入口：
  - 从会话 `ChatSettingsSheet` 直达消息分类 `squadInvite`。
- 消息分类对齐：
  - `MessageAlertCategory` 已加入 `squadInvite`，消息页可直接查看小队邀请类未读。
- 结果：
  - 聊天路径中的审核入口已与消息中心统一，便于后续审批流扩展。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target + 现存 iOS17 deprecate 警告）。

#### 2026-04-23（A5 第四轮：解散小队链路闭环）
- Server 新增：
  - `POST /v1/squads/:id/disband`（仅队长）；
  - OpenIM 群解散调用（`dismiss_group`）与本地 squad 删除联动。
  - 注意：当前数据模型是级联删除，解散会删除该 squad 关联记录（含 squad 下 posts/messages 等）。
- iOS 新增：
  - `ChatSettingsSheet` 群聊设置页增加“解散小队（仅队长）”入口；
  - 解散二次确认 + 执行态 + 成功后退出会话。
- 构建验证：
  - `pnpm -C server build`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：Server 编译通过；iOS 构建通过（仅既有 warning）。

#### 2026-04-23（A6 第一轮：灰度与回滚能力）
- iOS 入口灰度策略升级：
  - `RAVER_CHAT_FORCE_LEGACY_CHAT_VIEW=1`：强制旧页（紧急回滚）
  - `RAVER_CHAT_FORCE_UIKIT_CHAT_VIEW=1`：强制新页
  - `RAVER_CHAT_UIKIT_ROLLOUT_PERCENT=0..100`：按用户稳定分桶放量
  - `RAVER_CHAT_UIKIT_ALLOWLIST_USER_IDS=<id1,id2,...>`：白名单放量
- 会话路由：
  - `ConversationLoaderView` 按 `AppConfig.shouldUseDemoAlignedChatUIKit(userID:)` 决策新旧聊天页。
- 文档：
  - 新增 [`docs/OPENIM_CHAT_UIKIT_ROLLOUT_RUNBOOK.md`](/Users/blackie/Projects/raver/docs/OPENIM_CHAT_UIKIT_ROLLOUT_RUNBOOK.md)
  - 更新 [`docs/OPENIM_DUAL_SIM_BADGE_RUNBOOK.md`](/Users/blackie/Projects/raver/docs/OPENIM_DUAL_SIM_BADGE_RUNBOOK.md) 增加“新旧页对照验收”章节。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

#### 2026-04-23（A6 第二轮：旧页重复逻辑去冗余）
- 媒体临时文件写入/复制逻辑收敛：
  - 新增共享模块 `ChatMediaTempFileStore`；
  - 旧 `ChatView` 与新 `DemoAlignedChatViewController` 统一复用，不再各自维护临时目录实现。
- 工程同步收口：
  - 执行 `xcodegen generate`，确保新增文件进入 `RaverMVP` target；
  - 消除 `cannot find 'ChatMediaTempFileStore' in scope` 构建问题。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

#### 2026-04-23（A6 第三轮：双机探针稳定性加固）
- 脚本收口：
  - `openim_dual_sim_probe.sh` 新增“设备掉线自愈”能力：
    - 采集前校验模拟器 boot 状态；
    - snapshot/backfill 采集前若设备非 booted 自动恢复并重拉起 App。
  - 新增 `OPENIM_PROBE_OPEN_SIM_WINDOWS=1` 可选项（默认关闭 UI 自动开窗，优先保证稳定采集）。
- 回归验证：
  - `OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=20 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
  - 本轮输出目录：`/Users/blackie/Projects/raver/docs/reports/openim-dual-sim-20260423-191756`
  - 结果：双端采集流程可完整结束，未再出现“SIM1 device is not booted 导致流程中断”。

#### 2026-04-23（A7 第一轮：单实现路由收口）
- iOS 路由收敛：
  - `AppConfig.shouldUseDemoAlignedChatUIKit` 改为默认返回新页；
  - 仅保留 `RAVER_CHAT_FORCE_LEGACY_CHAT_VIEW=1` 作为紧急回滚开关。
- 策略变化：
  - 旧的分桶灰度/白名单分流不再影响默认路径；
  - 新页成为唯一默认实现，旧页仅应急。
- 文档同步：
  - 更新 `OPENIM_CHATLAYOUT_DEMO_ALIGNMENT_PLAN.md`，新增 A7 阶段与进度勾选；
  - 更新 `OPENIM_CHAT_UIKIT_ROLLOUT_RUNBOOK.md`，从“灰度”切换为“默认发布+回滚”。

#### 2026-04-23（A7 第二轮：移除旧页路由分支）
- 会话入口改造：
  - `ConversationLoaderView` 移除 `ChatView` 分支，统一进入 `DemoAlignedChatView`。
- 配置收口：
  - 删除 `AppConfig.shouldUseDemoAlignedChatUIKit` 与相关解析逻辑，避免路由开关与真实行为不一致。
- 策略更新：
  - 运行时旧页回滚已取消；
  - 紧急止损改为代码级回滚（切回保留旧分支的稳定提交）。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

#### 2026-04-23（A7 第三轮：旧页主文件退役）
- 代码变更：
  - 删除 `Features/Messages/ChatView.swift`（旧页主实现）。
- 工程同步：
  - 先执行 `xcodebuild` 发现旧文件仍在 build input；
  - 执行 `xcodegen generate` 后重新构建通过。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

#### 2026-04-23（A7 第三轮第二批：遗留模块清理完成）
- 代码变更：
  - 删除 `Features/Messages/Chat/Rendering/ChatMessageRenderRegistry.swift`（仅旧页使用）；
  - 将 `Features/Messages/Chat/ChatMediaTempFileStore.swift` 迁移到 `Features/Messages/UIKitChat/Support/ChatMediaTempFileStore.swift`；
  - 旧 `Features/Messages/Chat` 目录完成退役。
- 工程同步：
  - 执行 `xcodegen generate`，清理 `project.pbxproj` 中旧文件残留引用。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

#### 2026-04-23（A3 继续：时间分隔与群聊 sender meta 首版）
- 代码变更：
  - `RaverChatCollectionDataSource` 引入 `RaverChatListItem`，支持插入 `timeSeparator` 与消息 presentation；
  - 时间分隔策略首版：首条、跨天、间隔 >= 5 分钟时插入分隔行；
  - 新增 `DemoAlignedTimeSeparatorCell`；
  - `DemoAlignedMessageCell` / `DemoAlignedMediaMessageCell` 新增群聊他人消息头像+昵称展示；
  - sender meta 折叠规则首版：同发送者且间隔 < 3 分钟不重复显示。
- 路由与会话联动：
  - `DemoAlignedChatViewController` 初始化/切换会话时同步 `conversationType` 到 data source；
  - `RaverChatMessageCellFactory` 改为按 `RaverChatListItem` 分发 cell。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A3/A4 继续：时间分隔本地化 + 发送状态胶囊）
- 代码变更：
  - `RaverChatCollectionDataSource`：
    - 时间分隔文案升级为 `Today/Yesterday` + 同年/跨年本地化格式；
    - 引入 `DateFormatter` 模板（`MMMdHHmm` / `yMMMdHHmm`）。
  - `DemoAlignedMessageCell`：
    - 将 `sending/failed` 从时间后缀抽离为独立状态胶囊；
    - `sent` 状态不展示胶囊。
  - `DemoAlignedMediaMessageCell`：
    - 与文本消息保持一致的状态胶囊策略（sending/failed/sent）。
- 体验变化：
  - 会话阅读时更容易区分“时间信息”和“发送状态”；
  - 失败消息状态在气泡内更显著，和点击重发动作关联更直观。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A3/A4 继续：轻量样式优化 + 弱网失败提示）
- 代码变更：
  - `DemoAlignedTimeSeparatorCell`：
    - 调整时间分隔视觉权重（更淡背景、更小字号、最小高度约束）。
  - `DemoAlignedMessageCell` / `DemoAlignedMediaMessageCell`：
    - 失败胶囊文案升级为“失败·点重试”；
    - 状态胶囊仅对本人消息展示（对端状态不显示）。
  - `DemoAlignedChatViewController`：
    - 在消息状态从非失败切换为失败时，展示输入区上方 2 秒提示条；
    - 提示文案“消息发送失败，点按气泡重试”，无阻断弹窗。
- 体验收益：
  - 弱网下可见性更高，同时不打断用户操作；
  - 失败状态与重试动作（点按消息）关联更加明确。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A4 继续：失败反馈去打断化 + probe 可观测性）
- 代码变更：
  - `DemoAlignedChatViewController`：
    - 文本发送失败、图片发送失败、视频发送失败、失败重试失败，统一改为顶部失败提示条；
    - 移除上述路径的弹窗提示（`UIAlertController`），减少弱网时中断感；
    - 新增 `OpenIMProbeLogger` 日志打点，关键关键词：
      - `send text failed`
      - `send image failed`
      - `send video failed`
      - `resend failed`
      - `send failure hint shown`
- 验证方式：
  - 双机 probe 结束后，用 `rg "send failure hint shown|send .* failed|resend failed"` 检索 `sim*.log` 或合并后的 app-probe 日志。
  - `openim_probe_digest.sh` 已增加失败摘要字段：`sendFailed / resendFailed / failureHint`，可直接一眼判断失败链路是否触发。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A3 收口：cluster 分组模型接入）
- 代码变更：
  - `RaverChatCollectionDataSource`：
    - `RaverChatMessagePresentation` 增加 `isClusterStart / isClusterEnd`；
    - 新增 `isSameCluster` 规则（同发送者、同方向、同日、间隔 < 3 分钟）；
    - sender meta 改为跟随 cluster 首条展示。
  - `RaverChatMessageCellFactory`：
    - 将 cluster 元数据传递到文本/媒体 cell。
  - `DemoAlignedMessageCell` / `DemoAlignedMediaMessageCell`：
    - 按 cluster 首尾控制气泡圆角（连续气泡效果）；
    - 按 cluster 首尾控制上下间距（中间消息更紧凑）。
- 体验收益：
  - 聊天气泡串联更接近成熟 IM；
  - 群聊中重复头像昵称减少，阅读效率更高。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A2 继续：失败提示 presenter 下沉）
- 代码变更：
  - 新增 `DemoAlignedSendFailureHintPresenter`：
    - 负责失败提示条的创建、展示、自动隐藏和 reset；
  - `DemoAlignedChatViewController`：
    - 移除失败提示条的 view/timer 细节实现；
    - 改为注入并调用 presenter。
- 工程同步：
  - `xcodegen generate`，将新增 presenter 文件纳入工程。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A2 继续：媒体 picker/读取下沉为协调器）
- 代码变更：
  - 新增 `DemoAlignedMediaSendCoordinator`：
    - 封装 `PHPicker` 展示、`NSItemProvider` 文件读取、`ChatMediaTempFileStore` 复制；
    - 对外通过回调输出 `image/video` 结果与错误消息。
  - `DemoAlignedChatViewController`：
    - 删除 `PHPickerViewControllerDelegate` 扩展和 `presentPicker/loadPickedFile` 等细节方法；
    - 改为注入 `mediaSendCoordinator`，仅在回调中触发发送动作。
- 收益：
  - VC 进一步收敛到“页面编排 + 路由”；
  - 媒体选择链路可独立迭代（权限、压缩、类型扩展）。
- 工程同步：
  - `xcodegen generate` 将新增协调器文件纳入工程。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

#### 2026-04-23（A2 继续：媒体发送动作 + 进度展示下沉）
- 代码变更：
  - 新增 `DemoAlignedMediaSendProgressPresenter`：
    - 管理发送中按钮禁用、alpha、进度条与文案。
  - 新增 `DemoAlignedMediaMessageSendCoordinator`：
    - 管理图片/视频发送调用与进度回调；
    - 失败写入 `OpenIMProbeLogger` 并触发失败提示。
  - `DemoAlignedChatViewController`：
    - 移除 `setMediaSendingState/updateMediaSendingProgress/sendPickedImage/sendPickedVideo` 细节；
    - 由 `mediaSendCoordinator` 负责选取，`mediaMessageSendCoordinator` 负责发送。
- 收益：
  - VC 进一步回归容器职责；
  - 发送链路可独立测试与扩展（压缩、重试策略、限流策略）。
- 工程同步：
  - `xcodegen generate` 将新增 presenter/coordinator 文件纳入工程。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：文本发送链路下沉）
- 代码变更：
  - 新增 `DemoAlignedTextSendCoordinator`：
    - 统一管理文本输入裁剪、发送按钮可用态、回车发送；
    - 发送失败时回填输入框并触发失败提示；
    - 写入 `send text failed` probe 日志。
  - `DemoAlignedChatViewController`：
    - 移除 `sendCurrentInput` 业务实现，改为 coordinator 驱动；
    - 输入框 `editingChanged`、`textFieldShouldReturn`、媒体发送状态变化都统一触发 `refreshSendButtonState()`；
  - `DemoAlignedMediaSendProgressPresenter`：
    - 不再直接依赖 `sendButton`，仅对外发布发送状态变化。
- 收益：
  - VC 继续瘦身，发送路径更接近 demo 的“输入区动作由独立模块编排”模式；
  - 文本发送与媒体发送的按钮状态不再分散管理。
- 工程同步：
  - `xcodegen generate`。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：消息点击动作链路下沉）
- 代码变更：
  - 新增 `DemoAlignedMessageActionCoordinator`：
    - 统一处理消息点击后的动作分流（失败重发 / 媒体预览）；
    - 重发失败时统一写 probe 日志并触发失败提示条。
  - `DemoAlignedChatViewController`：
    - 删除 `resendMessageIfNeeded`、`presentMediaPreviewIfNeeded` 两个实现方法；
    - `didSelectItemAt` 仅负责把消息点击事件转交 coordinator。
- 收益：
  - 会话页控制器进一步贴近 demo 的“容器 + 动作协调器”模式；
  - 点击动作逻辑不再散落在 VC，后续扩展（复制/撤回/转发）更容易。
- 工程同步：
  - `xcodegen generate`。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅编译 warning，无 error）。

#### 2026-04-24（A2 继续：分页触发与顶部 loading 下沉）
- 代码变更：
  - 新增 `DemoAlignedPaginationCoordinator`：
    - 负责顶部阈值触发历史分页；
    - 管理顶部 loading 指示器状态；
    - 增加“触发后需离开顶部再触发下一次”的节流机制。
  - `DemoAlignedChatViewController`：
    - 移除 `syncOlderLoadingIndicator`；
    - `scrollViewDidScroll` 中分页触发改为 `paginationCoordinator.handleScrollDidScroll`；
    - `chatController.$isLoadingOlder` 绑定改为 coordinator；
    - 会话切换复位时使用 `paginationCoordinator.reset()`。
- 收益：
  - 分页触发逻辑不再夹杂在滚动 UI 逻辑中；
  - 顶部 loading 与分页节流策略可独立调优。
- 工程同步：
  - `xcodegen generate`。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`（构建通过）。

#### 2026-04-24（A2 继续：Viewport 协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedViewportCoordinator`：
    - 键盘动画联动（含隐藏后 settle 再滚底）；
    - 回到底部浮层展示/隐藏、`99+` 新消息计数文案；
    - 回到底部按钮点击后的滚动与计数清零。
  - `DemoAlignedChatViewController`：
    - 删除 `pendingNewMessageCount`、`isJumpToBottomVisible`、`animateAlongKeyboard` 等本地实现；
    - 键盘通知与浮层状态更新逻辑统一改为 coordinator 调度。
  - `OpenIMSession`：
    - `currentBusinessUserIDSnapshot()` 增加 `#if canImport(OpenIMSDK)` 分支，修复无 SDK 编译路径下 `decodeRaverID` 作用域错误。
- 收益：
  - 会话页控制器继续变薄，键盘/视口状态不再分散；
  - 工程可在含 SDK 与不含 SDK 两种构建路径下稳定通过。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：设置页路由协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedChatRouteCoordinator`：
    - 统一处理聊天设置页弹出；
    - 统一处理 `appPush` 跳转与设置页关闭；
    - 统一处理“退群后回退/自定义离开会话回调”。
  - `DemoAlignedChatViewController`：
    - `handleSettingsTapped` 简化为协调器调用；
    - 会话上下文更新时统一同步给协调器。
- 收益：
  - 设置页路由细节从 VC 中移除；
  - 会话退出链路更集中、更易回归验证。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：消息应用协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedMessageApplyCoordinator`：
    - 封装消息 apply 流程（dataSource 更新 + reload + layout）；
    - 封装自动滚底判定；
    - 封装新增未读增量判定；
    - 封装“新失败消息”检测。
  - `DemoAlignedChatViewController`：
    - `applyMessagesFromController` 改为消费 `Outcome`；
    - 删除 VC 内 `hasNewFailedOutgoingMessage` 细节方法。
- 收益：
  - 会话渲染主循环逻辑从 VC 提炼成可复用/可测试模块；
  - VC 更接近“页面容器 + 协调器拼装”形态。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：滚动协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedMessageViewportScrollCoordinator`：
    - 管理 `scrollToBottom`；
    - 管理 `isNearBottom`；
    - 管理分页锚点 `capture/restore`；
    - 管理 `forceScrollOnNextApply` 触发。
  - `DemoAlignedChatViewController`：
    - 删除 VC 内部 `scrollToBottom` 方法；
    - 键盘联动、输入框聚焦、回到底部按钮、分页前后锚点恢复都改为协调器驱动。
  - `DemoAlignedMessageApplyCoordinator`：
    - 滚动判定逻辑切换为滚动协调器提供的能力，减少对 VC 细节依赖。
- 收益：
  - 滚动相关策略集中，后续调优（阈值、动画、分页恢复）更可控；
  - 会话主 VC 继续向“纯容器”收敛。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：ComposerAction 协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedComposerActionCoordinator`：
    - 统一处理发送按钮点击；
    - 统一处理图片/视频按钮点击；
    - 统一处理输入框 begin/end/return 行为。
  - `DemoAlignedChatViewController`：
    - 新增 `configureComposerActionCoordinator()` 注入发送、媒体、滚动、跳底 UI 所需依赖；
    - `@objc` 点击方法与 `UITextFieldDelegate` 仅保留事件转发。
- 收益：
  - 输入区行为链路集中管理，VC 继续减重；
  - 与 demo 的“控制器做组装、动作下沉到协调器”方向更一致。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：KeyboardLifecycle 协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedKeyboardLifecycleCoordinator`：
    - 统一管理键盘通知订阅生命周期；
    - 统一封装 `shouldStickToBottom` 判定；
    - 回调驱动 `viewportCoordinator` 的键盘动画处理。
  - `DemoAlignedChatViewController`：
    - 删除 `keyboardCancellables` 与本地键盘处理方法；
    - 新增 `configureKeyboardLifecycleCoordinator()` 完成依赖注入并启动订阅。
- 收益：
  - 键盘监听逻辑从 VC 剥离，页面容器职责更纯；
  - 后续输入态/typing 状态扩展时可直接复用生命周期协调器。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：ControllerBinding 协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedControllerBindingCoordinator`：
    - 接管 `chatController.$messages` 订阅，回调触发 `applyMessagesFromController()`；
    - 接管 `chatController.$isLoadingOlder` 订阅，回调更新顶部 loading 指示状态。
  - `DemoAlignedChatViewController`：
    - 移除 `cancellables` 与 `bindController()`；
    - 新增 `configureControllerBindingCoordinator()` 并在 `viewDidLoad` 启动。
- 修复记录：
  - 初版尝试在 `deinit` 调用 `@MainActor stop()`，触发编译错误（同步非隔离上下文调用主线程隔离方法）；
  - 已移除该调用，改为对象释放自动清理订阅。
- 收益：
  - 订阅绑定从 VC 解耦，主控制器继续瘦身；
  - 状态流与 UI 编排边界更清晰。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：ChatScreenLifecycle 协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedChatScreenLifecycleCoordinator`：
    - 负责会话页生命周期 `start`；
    - 负责 `updateConversation` 时的上下文切换流程（标题更新、列表类型更新、滚动/分页/提示状态复位、路由上下文同步、`chatController.updateContext`）。
  - `DemoAlignedChatViewController`：
    - `viewDidLoad` 改为通过生命周期协调器启动会话；
    - `updateConversation(...)` 改为委托协调器执行生命周期编排。
- 收益：
  - 会话生命周期逻辑从 VC 抽离，VC 进一步回归 UI 容器职责；
  - 生命周期策略可在单一协调器维护，降低后续改动风险。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：首屏稳定滚底状态迁移）
- 代码变更：
  - `DemoAlignedChatScreenLifecycleCoordinator`：
    - 新增内部状态 `hasPerformedInitialStableScroll`；
    - 新增 `handleViewDidAppear(hasMessages:)` 统一控制“仅首屏滚底一次”；
    - 在 `updateConversation` 时自动重置该状态。
  - `DemoAlignedChatViewController`：
    - 删除本地 `hasPerformedInitialStableScroll`；
    - `viewDidAppear` 改为消费协调器返回值决定是否滚底；
    - 移除对 `resetInitialStableScroll` 的依赖注入。
- 收益：
  - 入场滚动策略完全进入生命周期域，VC 进一步瘦身；
  - 行为保持不变且更易于后续做 demo 级别统一策略调整。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：ChatScreenAssembly 协调器下沉）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyCoordinator`：
    - 接收有序装配步骤 `steps`；
    - 执行完成后触发 `onAssembled`（用于启动会话生命周期）。
  - `DemoAlignedChatViewController`：
    - `viewDidLoad` 改为“创建装配协调器并执行”；
    - 新增 `configureChatScreenAssemblyCoordinator()`，把原有初始化顺序迁移为闭包步骤清单。
- 收益：
  - 初始化顺序统一收口，页面入口更简洁；
  - 后续加入新 coordinator 时只改装配清单，不打散主流程。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：装配命名步骤 + DEBUG 顺序断言）
- 代码变更：
  - `DemoAlignedChatScreenAssemblyCoordinator`：
    - 从 `[() -> Void]` 升级为 `[Step(id, action)]`；
    - 新增 `expectedOrder` 参数；
    - 在 `DEBUG` 环境增加“顺序不一致断言 + 重复 step id 断言”。
  - `DemoAlignedChatViewController`：
    - 装配清单改为显式命名步骤；
    - 增加 `expectedOrder` 常量作为调试断言基线。
- 收益：
  - 初始化流程具备可观测性，改动顺序时会在 debug 直接暴露；
  - 对新同学阅读/定位初始化链路更友好。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：`configure*` 方法分组重排）
- 代码变更：
  - `DemoAlignedChatViewController` 新增职责分区注释：
    - `UI Assembly`
    - `Coordinator Assembly`
    - `Message Rendering`
    - `User Actions`
  - `configureJumpToBottomButton`、`configureOlderLoadingIndicator` 移动到 UI 分区；
  - 其余私有方法按职责归类，未改动行为逻辑。
- 收益：
  - 代码浏览路径更清晰，排查时可快速进入对应职责区块；
  - 与 demo 风格的“结构清晰、职责分段”更一致。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：消息流程编排器下沉）
- 代码变更：
  - 新增 `DemoAlignedMessageFlowCoordinator`：
    - 统一管理本地消息缓存；
    - 承担历史分页加载编排（含分页锚点 capture/restore）；
    - 承担 `chatController.messages` 到 UI 状态的应用编排（调用 `DemoAlignedMessageApplyCoordinator` 并驱动 viewport 状态）。
  - `DemoAlignedChatViewController`：
    - 移除本地 `messages`；
    - 移除 `loadOlderMessagesIfNeeded`、`applyMessagesFromController`；
    - 分页与 controller binding 回调改为交给 `messageFlowCoordinator`。
  - `DemoAlignedChatScreenLifecycleCoordinator`：
    - 增加 `resetMessageFlowState` 回调并在会话切换时调用。
- 收益：
  - 消息流程逻辑从 VC 进一步剥离，VC 更纯粹地充当 UI 容器；
  - 消息链路状态一致性（切会话重置/首屏判定）更稳。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：失败反馈编排器下沉）
- 代码变更：
  - 新增 `DemoAlignedMessageFailureFeedbackCoordinator`：
    - 接管发送失败提示文案；
    - 接管自定义失败提示（如媒体选择器错误）；
    - 统一失败提示日志与 `reset`。
  - `DemoAlignedChatViewController`：
    - 删除 `showSendFailureHint()`；
    - 文本发送、媒体发送、消息重发、消息流失败检测的提示入口全部收口到 `messageFailureFeedbackCoordinator`；
    - 装配链路新增命名步骤 `message_failure_feedback_coordinator`（`send_failure_hint_presenter` 后）。
  - 生命周期复位：
    - `resetSendFailureHint` 回调改为触发 `messageFailureFeedbackCoordinator.reset()`。
- 收益：
  - 失败提示策略从 VC 剥离，进一步靠近 demo 风格的“VC 仅做 UI 编排”；
  - 后续替换提示样式（toast/banner）只需改单点协调器。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：媒体选择错误触发点下沉）
- 代码变更：
  - `DemoAlignedMediaSendCoordinator` 新增 `conversationIDProvider`，并把 picker 错误日志内聚到 coordinator；
  - 错误回调由 `onError(message)` 升级为 `onErrorFeedback(message, reason)`；
  - 对四类 picker 异常统一 reason：
    - `picker_file_representation_failed`
    - `picker_file_url_missing`
    - `picker_temp_copy_failed`
    - `picker_unsupported_media_type`
  - `DemoAlignedChatViewController` 删除 picker 错误日志，仅保留失败提示展示调用。
- 收益：
  - picker 错误链路从 VC 下沉到发送协调器，职责边界更清晰；
  - 失败事件 reason 结构化，后续日志检索与告警更容易。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：发送失败日志模板统一）
- 代码变更：
  - 新增 `DemoAlignedChatLogger` 统一输出聊天域失败日志；
  - 文本发送失败、图片/视频发送失败、重发失败、picker 错误四条链路全部切换到统一 logger。
- 收益：
  - 各 coordinator 内不再拼接重复日志字符串；
  - 后续要做日志字段升级（如 session id）时改动集中在单文件。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：`ChatContextProvider` 注入统一）
- 代码变更：
  - 新增 `DemoAlignedChatContextProvider` 作为会话上下文单点提供器；
  - 文本发送、媒体发送、媒体选择器、失败反馈、消息重发五个 coordinator 全部改为注入 `chatContextProvider`；
  - `DemoAlignedChatViewController` 增加装配步骤 `chat_context_provider`，并删去多处重复 `conversationIDProvider` 闭包。
- 修复记录：
  - 首次构建触发 actor 隔离错误（`conversationID` 在非隔离上下文访问）；
  - 已去掉 `ChatContextProvider` 的 `@MainActor` 标记后通过。
- 收益：
  - 注入参数显著减少，VC 组装噪音下降；
  - 会话上下文扩展能力（如后续 trace/session 字段）更集中。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：`FailureFeedbackActions` 注入统一）
- 代码变更：
  - 新增 `DemoAlignedFailureFeedbackActions`，统一管理失败提示动作；
  - 文本发送、媒体发送、消息重发、媒体选择器四条失败链路统一改为注入 `failureFeedbackActions`；
  - `DemoAlignedChatViewController` 增加装配步骤 `failure_feedback_actions`，并移除多处失败提示闭包重复注入。
- 收益：
  - 失败提示触发入口一致，VC 构造参数进一步简化；
  - 后续升级失败提示交互不需要修改多个发送 coordinator。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：`ChatLogEvent` 日志模型统一）
- 代码变更：
  - `DemoAlignedChatLogger` 新增 `DemoAlignedChatLogEvent` 枚举；
  - 所有聊天域日志先映射成事件，再统一由 `DemoAlignedChatLogger.log(_:)` 输出；
  - `DemoAlignedMessageFailureFeedbackCoordinator` 的直写日志全部切换为 logger 事件调用。
- 收益：
  - UIKitChat 内日志出口单点化，避免日志模板字符串分散；
  - 后续新增日志字段或改格式只需改 logger 一处。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：装配 guard 失败路径可观测性）
- 代码变更：
  - `DemoAlignedChatViewController` 新增 `reportAssemblyDependencyMissing(step:dependencies:)`；
  - 多处 `guard ... else { return }` 改为记录 `assemblyDependencyMissing` 日志并在 `DEBUG` 下断言。
- 覆盖范围：
  - 消息应用、失败反馈、媒体发送、文本发送、消息动作、消息流等核心装配步骤。
- 收益：
  - 装配依赖缺失不再“静默 return”，排查初始化问题更快；
  - 与既有 assembly 顺序断言配合，能同时覆盖“顺序错/依赖缺”两类问题。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Assembly Plan Builder 抽离）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyPlanBuilder`（含 actions + plan）；
  - 将 `DemoAlignedChatViewController` 内联的 `expectedOrder + steps` 定义迁移到 builder 文件；
  - VC 仅组装 `actions`，再由 builder 产出 plan 注入 `DemoAlignedChatScreenAssemblyCoordinator`。
- 收益：
  - 初始化配置表不再占据 VC 主体；
  - 变更装配顺序时只改 builder，回归点集中。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：装配依赖解析容器化）
- 代码变更：
  - `DemoAlignedChatViewController` 新增 `ContextFailureDependencies` 与 `MediaCoordinatorDependencies`；
  - 新增依赖解析函数，统一处理依赖缺失上报；
  - 媒体发送、文本发送、媒体消息发送、消息动作四个 configure 方法改为通过容器解析依赖。
- 收益：
  - 去重重复 `guard` 分支，装配代码更紧凑；
  - 依赖关系更清晰，后续扩展配置项更稳。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Assembly Action 枚举执行器）
- 代码变更：
  - `DemoAlignedChatScreenAssemblyPlanBuilder` 改为 `DemoAlignedChatScreenAssemblyAction` 枚举驱动；
  - 移除旧的 actions 闭包聚合结构体；
  - `DemoAlignedChatViewController` 新增 `performAssemblyAction(_:)`，统一处理 action -> configure 映射。
- 收益：
  - `configureChatScreenAssemblyCoordinator()` 进一步简化；
  - action 顺序定义与执行映射更清晰，可测试性更好。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Assembly Action 分组执行器）
- 代码变更：
  - `performAssemblyAction(_:)` 拆分为 `performUIAssemblyAction(_:)` 与 `performCoordinatorAssemblyAction(_:)`；
  - 未命中 action 统一上报 `assembly_action_dispatch` 缺失日志。
- 修复记录：
  - 拆分后首次编译报错（`collectionView` 分支缺少返回值），已修复并通过构建。
- 收益：
  - action 执行逻辑分层更清晰，VC 可读性提升；
  - 后续 action 扩展时冲突风险更低。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：未命中 Action 日志事件化）
- 代码变更：
  - `DemoAlignedChatLogEvent` 新增 `assemblyActionUnhandled`；
  - `performAssemblyAction(_:)` 未命中分支改为写入 `assemblyActionUnhandled` 并触发 DEBUG 断言。
- 收益：
  - 未命中 action 不再混用依赖缺失日志，告警语义更精确。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Assembly Dispatcher 独立执行器化）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyActionExecutor`（独立于 VC）；
  - `DemoAlignedChatViewController` 新增 `chatScreenAssemblyActionExecutor` 属性；
  - 删除 `performAssemblyAction(_:)`，`configureChatScreenAssemblyCoordinator()` 改为委托执行器执行 plan action；
  - 未命中 action 收口到 `handleUnhandledAssemblyAction(_:)`。
- 收益：
  - Assembly 总分发职责从 VC 迁出，进一步贴近 demo 风格的“VC 只做装配与路由”；
  - 为下一步下沉 UI/Coordinator 分组映射打好边界。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Action 分组映射独立化）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyActionHandlers`；
  - `DemoAlignedChatViewController` 删除 `performUIAssemblyAction(_:)` / `performCoordinatorAssemblyAction(_:)`；
  - 新增 `chatScreenAssemblyActionHandlers` 属性和 `configureChatScreenAssemblyActionHandlers()`；
  - assembly executor 通过 handlers 执行 UI/Coordinator action。
- 收益：
  - VC 内 action 分发表完全移除，结构更接近 demo 的“组装层 + 执行层”拆分；
  - 下一步可继续抽离 handlers 的依赖 wiring，减少 VC 闭包样板。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Handler Wiring 样板压缩）
- 代码变更：
  - `DemoAlignedChatViewController` 新增 `bindAssemblyAction(_:)`；
  - 新增 `makeChatScreenAssemblyActionHandlerDependencies()` 聚合 dependencies 构建；
  - `configureChatScreenAssemblyActionHandlers()` 仅保留单点装配调用。
- 收益：
  - 25 个 `[weak self]` 样板闭包从装配入口收敛；
  - 为下一步把 builder 外移到独立模块做准备。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Dependencies Builder Support 化）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyActionHandlerDependenciesFactory`；
  - VC 删除本地 dependencies builder，改为调用 factory；
  - VC 新增 `performAssemblyConfigurationAction(_:)` 作为私有 action 分发桥接。
- 收益：
  - handler dependencies 构建逻辑已移出 VC；
  - 继续保持 `configure*` 私有访问范围，不为外移改造放宽访问控制。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：配置分发双段化与覆盖校验）
- 代码变更：
  - `DemoAlignedChatViewController`：
    - `performAssemblyConfigurationAction(_:)` 改为 UI/Coordinator 双段私有分发并返回命中布尔值；
    - 未命中 action 统一进入 `handleUnhandledAssemblyAction(_:)`。
  - `DemoAlignedChatScreenAssemblyActionHandlerDependenciesFactory`：
    - 新增 `coveredActions`；
    - 新增 `DEBUG` 覆盖断言 `assertActionCoverage()`，校验与 `orderedActions` 集合一致。
- 修复记录：
  - 首次改造后 `make()` 中 `.init(...)` 触发编译器上下文推断错误；
  - 已改为显式 `return DemoAlignedChatScreenAssemblyActionHandlers.Dependencies(...)`。
- 收益：
  - 配置分发路径更清晰，action 漏配可在 DEBUG 构建期暴露。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：VC 内映射表替换 switch）
- 代码变更：
  - `DemoAlignedChatViewController` 新增：
    - `uiAssemblyConfigurationActions`
    - `coordinatorAssemblyConfigurationActions`
    - `performAssemblyConfigurationAction(_:from:)`
  - UI/Coordinator 两段分发函数改为映射表查找执行，移除大段 `switch`。
  - 新增 `DEBUG` 校验：
    - `assertAssemblyConfigurationActionCoverage()`，校验 VC 映射覆盖集合与 `orderedActions` 一致。
- 收益：
  - 分发逻辑从“条件分支”变成“数据映射”，维护成本更低；
  - 映射缺失可在 DEBUG 构建期暴露。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：配置映射 Mapper 类型化）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyConfigurationActionMapper`；
  - `DemoAlignedChatViewController` 新增 `assemblyConfigurationActionMapper`，由它承接 UI/Coordinator action 映射执行；
  - UI/Coordinator 分发函数改为委托 mapper；
  - 覆盖断言改为基于 mapper 的 `coveredActions`。
- 收益：
  - VC 从“持有两张映射表”收敛为“持有一个 mapper”；
  - 映射执行细节集中在 Support，后续演进空间更好。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Mapper Factory 化）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyConfigurationActionMapperFactory`；
  - `DemoAlignedChatViewController` 中 mapper 初始化改为 factory 生成（action-list + binder）；
  - VC 新增 `executeAssemblyConfigurationAction(_:)` 承接 action 执行。
- 收益：
  - VC 初始化噪音继续下降；
  - action 分组数据从 VC 内迁移到 Support，结构更清晰。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Assembly 配置执行链路收敛）
- 代码变更：
  - `DemoAlignedChatViewController` 删除 `assemblyConfigurationActionMapper` 与 `performAssemblyConfigurationAction(_:)`；
  - `executeAssemblyConfigurationAction(_:)` 改为唯一执行入口，并拆分为：
    - `executeUIAssemblyConfigurationAction(_:)`
    - `executeCoordinatorAssemblyConfigurationAction(_:)`
    - `executeCoordinatorContextAssemblyAction(_:)`
    - `executeCoordinatorMediaAssemblyAction(_:)`
    - `executeCoordinatorFlowAssemblyAction(_:)`
  - `configureChatScreenAssemblyActionHandlers()` 直接绑定到 `executeAssemblyConfigurationAction(_:)`。
- 清理项：
  - 删除 `Support/DemoAlignedChatScreenAssemblyConfigurationActionMapper.swift`
  - 删除 `Support/DemoAlignedChatScreenAssemblyConfigurationActionMapperFactory.swift`
- 收益：
  - action 执行路径由多层桥接简化为单层执行，VC 装配语义更直观；
  - 旧 mapper 路径退役，降低后续误维护风险。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Coordinator 执行分发三域化）
- 代码变更：
  - `DemoAlignedChatViewController` 将 `executeCoordinatorFlowAssemblyAction(_:)` 拆分为：
    - `executeCoordinatorScrollAssemblyAction(_:)`
    - `executeCoordinatorMessagePipelineAssemblyAction(_:)`
    - `executeCoordinatorRouteLifecycleAssemblyAction(_:)`
  - `executeCoordinatorAssemblyConfigurationAction(_:)` 改为按 5 段顺序分发（context/media/scroll/message-pipeline/route-lifecycle）。
- 收益：
  - Coordinator 执行逻辑颗粒度更细，VC 函数体积继续下降；
  - 为后续 Support 层分发表下沉预留了清晰边界。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Coordinator 主分发 Support 化）
- 代码变更：
  - 新增 `DemoAlignedChatScreenCoordinatorAssemblyActionDispatcher`；
  - `DemoAlignedChatViewController` 新增 `coordinatorAssemblyActionDispatcher` 属性；
  - `executeCoordinatorAssemblyConfigurationAction(_:)` 改为委托 dispatcher 执行。
- 收益：
  - coordinator 主分发编排从 VC 迁出到 Support，VC 继续变薄；
  - 后续若调整分发顺序或新增域，只需改 dispatcher。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：域内分发 map dispatcher 化）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyActionMapDispatcher`；
  - `DemoAlignedChatViewController` 中 UI + 5 个 coordinator 域的 action 执行，从 `switch` 改为 map dispatcher 查表执行。
- 收益：
  - 域内分发改为表驱动，新增 action 时改动更集中；
  - 与 coordinator 主 dispatcher 形成“编排层/执行层”清晰边界。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：dispatcher 聚合为 bundle）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyActionDispatcherBundle`；
  - `DemoAlignedChatViewController` 删除 6 个分散 dispatcher lazy 属性，改为单一 `assemblyActionDispatcherBundle`；
  - 各 `execute*AssemblyAction` 通过 bundle 访问对应 dispatcher。
- 收益：
  - VC 属性区块继续压缩，依赖结构更清晰；
  - 在不改行为的前提下进一步降低维护噪音。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：装配依赖解析 Support 化）
- 代码变更：
  - 新增 `DemoAlignedChatAssemblyDependencyResolver`，统一处理依赖缺失上报、context/media 依赖解析；
  - `DemoAlignedChatViewController` 删除本地 `ContextFailureDependencies` / `MediaCoordinatorDependencies` 与 3 个解析/上报函数；
  - 各 `configure*Coordinator` 改为通过 `assemblyDependencyResolver` 获取依赖。
- 收益：
  - VC 继续变薄，装配方法聚焦行为拼装；
  - 依赖缺失处理路径统一，后续增强只改 Support。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：dispatcher bundle Factory 化）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyActionDispatcherBundleFactory` 与 dependencies 类型；
  - `DemoAlignedChatViewController` 的 `assemblyActionDispatcherBundle` 改为调用 factory；
  - 删除 VC 内 `makeAssemblyActionDispatcherBundle()` 的分发表定义，改为 `makeAssemblyActionDispatcherBundleDependencies()` 注入闭包依赖。
- 收益：
  - action 映射定义集中到 Support，VC 进一步瘦身；
  - 后续 action 分组调整无需修改 VC 主体结构。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：装配闭包绑定压缩 + Composer/Keyboard Factory 下沉）
- 代码变更：
  - `DemoAlignedChatViewController` 新增 `bindAssemblyConfiguration(...)`，把 action->configure 的弱引用闭包统一收口；
  - 新增 `DemoAlignedComposerActionCoordinatorFactory`，`configureComposerActionCoordinator()` 改为 factory 注入；
  - 新增 `DemoAlignedKeyboardLifecycleCoordinatorFactory`，`configureKeyboardLifecycleCoordinator()` 改为 factory 注入。
- 收益：
  - VC 继续减重，coordinator wiring 从“闭包细节堆叠”收敛为“依赖装配”；
  - keyboard/composer 的闭包拼装与 UI 容器职责进一步解耦。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：MessageFlow/ControllerBinding Factory 下沉）
- 代码变更：
  - 新增 `DemoAlignedMessageFlowCoordinatorFactory`；
  - 新增 `DemoAlignedControllerBindingCoordinatorFactory`；
  - `DemoAlignedChatViewController` 的 `configureMessageFlowCoordinator()` / `configureControllerBindingCoordinator()` 改为工厂注入；
  - `message_flow_coordinator` 缺依赖上报改为 factory 内 guard + 回调上报。
- 收益：
  - VC message pipeline 组装路径继续简化，闭包 wiring 进一步迁出；
  - 后续若要扩展消息流/绑定策略，可集中在 Support 层演进。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：Route/Lifecycle Factory 下沉）
- 代码变更：
  - 新增 `DemoAlignedChatRouteCoordinatorFactory`；
  - 新增 `DemoAlignedChatScreenLifecycleCoordinatorFactory`；
  - `DemoAlignedChatViewController` 的 `configureChatRouteCoordinator()` / `configureChatScreenLifecycleCoordinator()` 改为 factory 注入。
- 收益：
  - route + lifecycle 闭包 wiring 集中到 Support，VC 装配噪音继续下降；
  - 会话切换时 title/dataSource/routeContext 等更新闭包的维护点统一。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。

#### 2026-04-24（A2 继续：Assembly Coordinator Factory 下沉）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyCoordinatorFactory`；
  - factory 内统一完成 `ActionHandlers` + `ActionExecutor` + `AssemblyCoordinator` 构建；
  - `DemoAlignedChatViewController` 删除：
    - `configureChatScreenAssemblyActionHandlers()`
    - `configureChatScreenAssemblyActionExecutor()`
    - `chatScreenAssemblyActionHandlers` / `chatScreenAssemblyActionExecutor` 属性。
- 收益：
  - assembly 装配链路从 VC 迁到 Support，VC 主体继续收敛为容器；
  - 后续装配策略调整可在单一 factory 内完成，减少改动扩散面。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：Assembly Configuration Executor 下沉）
- 代码变更：
  - 新增 `DemoAlignedChatScreenAssemblyConfigurationExecutor` 与对应 factory；
  - 执行器内部统一接管 UI + coordinator 域 action 分发与未命中回调；
  - `DemoAlignedChatViewController` 删除：
    - `assemblyActionDispatcherBundle`
    - `coordinatorAssemblyActionDispatcher`
    - 7 个 `execute*AssemblyAction` 分发函数（UI/各 coordinator 域）。
  - `executeAssemblyConfigurationAction(_:)` 收敛为单行：委托 `assemblyConfigurationExecutor.execute(action)`。
- 收益：
  - assembly action 执行编排进一步从 VC 下沉到 Support；
  - VC 复杂度继续下降，后续分发策略演进可在执行器内集中处理。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：Media/Text/MessageAction Factory 下沉）
- 代码变更：
  - 新增 `DemoAlignedMediaSendCoordinatorFactory`；
  - 新增 `DemoAlignedTextSendCoordinatorFactory`；
  - 新增 `DemoAlignedMediaMessageSendCoordinatorFactory`；
  - 新增 `DemoAlignedMessageActionCoordinatorFactory`；
  - `DemoAlignedChatViewController` 的：
    - `configureMediaSendCoordinator()`
    - `configureTextSendCoordinator()`
    - `configureMediaMessageSendCoordinator()`
    - `configureMessageActionCoordinator()`
    全部改为 factory 注入；
  - 依赖缺失由各 factory 内 guard + `onMissingDependencies` 回调统一上报。
- 收益：
  - 发送链路与消息点击链路的装配逻辑进一步迁出 VC；
  - 缺依赖处理路径一致化，减少 VC 内重复 guard 样板。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：MessageApply/Pagination/Viewport/FailureFeedback/MediaProgress Factory 下沉）
- 代码变更：
  - 新增 `DemoAlignedMessageApplyCoordinatorFactory`；
  - 新增 `DemoAlignedPaginationCoordinatorFactory`；
  - 新增 `DemoAlignedViewportCoordinatorFactory`；
  - 新增 `DemoAlignedMediaSendProgressPresenterFactory`；
  - 新增 `DemoAlignedMessageFailureFeedbackCoordinatorFactory`；
  - 新增 `DemoAlignedFailureFeedbackActionsFactory`；
  - `DemoAlignedChatViewController` 的：
    - `configureMessageApplyCoordinator()`
    - `configurePaginationCoordinator()`
    - `configureViewportCoordinator()`
    - `configureMediaProgressPresenter()`
    - `configureMessageFailureFeedbackCoordinator()`
    - `configureFailureFeedbackActions()`
    全部改为 factory 注入；
  - 缺依赖处理统一通过 `onMissingDependencies` 回调复用 `assemblyDependencyResolver.reportMissing(...)`。
- 收益：
  - 分页/视口/失败反馈/进度呈现装配全部迁出 VC；
  - coordinator 装配风格进一步统一，后续演进改动面更集中。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：ViewportScroll/HintPresenter/ChatContext Factory 下沉）
- 代码变更：
  - 新增 `DemoAlignedViewportScrollCoordinatorFactory`；
  - 新增 `DemoAlignedSendFailureHintPresenterFactory`；
  - 新增 `DemoAlignedChatContextProviderFactory`；
  - `DemoAlignedChatViewController` 的：
    - `configureViewportScrollCoordinator()`
    - `configureSendFailureHintPresenter()`
    - `configureChatContextProvider()`
    改为通过对应 factory 注入。
- 收益：
  - 常驻辅助对象装配路径与其他 coordinator 完全一致；
  - VC 继续瘦身，装配代码更可扫读、可维护。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

#### 2026-04-24（A2 继续：UI Assembly Factory 下沉）
- 代码变更：
  - 新增 `DemoAlignedChatUIAssemblyFactory`，统一承接：
    - `configureLayout`
    - `makeCollectionView`
    - `configureComposer`
    - `configureJumpToBottomButton`
    - `configureOlderLoadingIndicator`
  - `DemoAlignedChatViewController` 的对应 `configure*` 方法改为工厂注入调用；
  - `configureComposer()` 内 `mediaProgressHeightConstraint` 改为接收工厂返回；
  - `inputField.delegate = self` 保持在 VC 侧，确保输入行为一致。
- 收益：
  - VC 中大段 UIKit 构建与约束代码迁出，代码噪音明显下降；
  - UI 装配与流程编排职责进一步解耦，后续改 UI 更集中。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：`traitCollectionDidChange` deprecate、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：UI Factory 覆盖导航项与输入 delegate）
- 代码变更：
  - `DemoAlignedChatUIAssemblyFactory` 新增 `configureNavigationItems(...)`；
  - `DemoAlignedComposerAssemblyDependencies` 新增 `inputFieldDelegate`，并在 factory 内统一设置 `inputField.delegate`；
  - `DemoAlignedChatViewController`：
    - `configureNavigationItems()` 改为 factory 注入；
    - `configureComposer()` 中 `inputField.delegate = self` 改由 factory 处理。
- 收益：
  - 导航栏/输入框装配与其他 UI 组件一致下沉；
  - VC 继续减重，减少直接 UIKit 赋值点。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`traitCollectionDidChange` deprecate、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：缺依赖回调样板收口）
- 代码变更：
  - `DemoAlignedChatViewController` 新增 `makeMissingDependencyReporter(step:)` 私有 helper；
  - 将 9 处 `onMissingDependencies` 闭包改为统一 helper 注入：
    - `message_apply_coordinator`
    - `message_failure_feedback_coordinator`
    - `failure_feedback_actions`
    - `media_send_coordinator`
    - `media_progress_presenter`
    - `text_send_coordinator`
    - `media_message_send_coordinator`
    - `message_action_coordinator`
    - `message_flow_coordinator`
- 收益：
  - 缺依赖日志上报行为保持一致并减少重复闭包噪音；
  - VC 装配代码更聚焦依赖声明，后续继续拆分更顺滑。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：resolver/provider 闭包样板收口）
- 代码变更：
  - `DemoAlignedChatViewController` 新增：
    - `makeConversationIDResolver()`
    - `makeOnSendSucceededHandler()`
    - `makeOnSendFailureHintHandler()`
  - 复用上述 helper 替换重复闭包注入：
    - `assemblyDependencyResolver.conversationIDProvider`
    - `configureChatContextProvider().conversationIDResolver`
    - `configureTextSendCoordinator().onSendSucceeded`
    - `configureMediaMessageSendCoordinator().onSendSucceeded`
    - `configureMessageFlowCoordinator().onSendFailureHint`
- 收益：
  - 注入闭包风格统一，减少重复 `[weak self]` 模板；
  - VC 代码继续朝“容器 + 编排”职责收敛。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：装配绑定方法引用化）
- 代码变更：
  - `DemoAlignedChatViewController.bindAssemblyConfiguration` 改为接收方法引用签名：
    - `(DemoAlignedChatViewController) -> () -> Void`
  - `makeAssemblyActionDispatcherBundleDependencies()` 的 25 个装配项从闭包包装改为方法引用：
    - 例如 `bindAssemblyConfiguration(DemoAlignedChatViewController.configureLayout)`。
- 收益：
  - 装配映射语义保持一致，重复闭包模板进一步减少；
  - 分发表可读性提升，更接近“纯配置清单”。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：异步回调闭包收口）
- 代码变更：
  - `DemoAlignedChatViewController` 新增：
    - `makeOnLoadOlderHandler()`
    - `makeOnMediaPickedHandler()`
    - `handleMediaPicked(_:)`
  - 将两处内联异步闭包改为 helper 注入：
    - `configurePaginationCoordinator().onLoadOlder`
    - `configureMediaSendCoordinator().onPicked`
- 收益：
  - 装配段减少 `Task {}` + `switch` 嵌套细节；
  - 媒体发送回调与分页回调的行为入口集中，便于后续统一观测/扩展。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：ChatScreen 装配回调闭包收口）
- 代码变更：
  - `DemoAlignedChatViewController` 新增：
    - `bindActionHandler<Value>(...)`
    - `bindCallback(...)`
    - `startChatScreenLifecycleCoordinator()`
  - `assemblyConfigurationExecutor.onUnhandledAction` 改为方法引用绑定；
  - `configureChatScreenAssemblyCoordinator()` 的 3 处回调改为方法引用绑定：
    - `executeAssemblyConfigurationAction`
    - `onUnhandledAction`
    - `onAssembled`
- 收益：
  - ChatScreen 装配段继续去闭包样板，结构更接近“配置清单”；
  - 生命周期启动入口更集中，后续 A2 清尾更稳。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：UI/发送态闭包再压缩）
- 代码变更：
  - `configureCollectionView().registerCells` 改为方法引用绑定：
    - `bindActionHandler(DemoAlignedChatViewController.registerCollectionCells)`
  - `configureMediaProgressPresenter().onSendingStateChanged` 改为方法引用绑定：
    - `bindActionHandler(DemoAlignedChatViewController.handleMediaSendingStateChanged)`
  - `handleJumpToBottomTapped()` 改为显式 `scrollToBottom:` 参数绑定：
    - `bindActionHandler(DemoAlignedChatViewController.handleJumpToBottomAnimation)`
- 收益：
  - VC 内匿名闭包进一步下降，UI 和发送态行为入口更清晰；
  - 与前序“方法引用化”改造保持一致，便于统一维护。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：`make*` 闭包统一为方法引用绑定）
- 代码变更：
  - `DemoAlignedChatViewController` 新增：
    - `bindAsyncCallback(...)`
    - `bindValueProvider(...)`
  - 回调绑定改造：
    - `assemblyDependencyResolver.conversationIDProvider` 改为 `bindValueProvider(currentConversationID, fallback: "unknown")`；
    - `configureChatContextProvider().conversationIDResolver` 改为 `bindValueProvider(currentConversationID, fallback: "unknown")`；
    - `configurePaginationCoordinator().onLoadOlder` 改为 `bindAsyncCallback(loadOlderMessagesIfNeeded)`；
    - `configureMediaSendCoordinator().onPicked` 改为 `bindActionHandler(handleMediaPicked)`；
    - `configureTextSendCoordinator()/configureMediaMessageSendCoordinator().onSendSucceeded` 改为 `bindCallback(handleSendSucceeded)`；
    - `configureMessageFlowCoordinator().onSendFailureHint` 改为 `bindCallback(handleSendFailureHint)`；
  - 删除重复的 `makeConversationIDResolver/makeOnSendSucceeded/makeOnSendFailureHint/makeOnLoadOlder/makeOnMediaPicked`。
- 收益：
  - VC 装配层的闭包工厂模板进一步下降；
  - async/value/action 回调路径统一，后续 A2 尾部清理可预期性更高。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：MainActor 异步动作绑定统一）
- 代码变更：
  - `DemoAlignedChatViewController` 新增 `bindMainActorAsyncAction(...)`；
  - `configureMediaSendCoordinator().onPicked` 改为 `bindMainActorAsyncAction(handleMediaPicked)`；
  - `handleMediaPicked(_:)` 改为 `async` 方法，移除方法内部内联 `Task`；
  - `collectionView(_:didSelectItemAt:)` 改为通过 `bindMainActorAsyncAction(handleMessageTappedAction)` 触发；
  - 新增 `handleMessageTappedAction(_:) async`。
- 收益：
  - 媒体选择与消息点按链路统一为 MainActor 异步调度；
  - VC 内异步闭包噪音继续下降，装配语义更集中。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：缺依赖上报 step 类型化）
- 代码变更：
  - `DemoAlignedChatViewController` 新增 `MissingDependencyStep` 枚举，统一管理缺依赖上报 step；
  - `makeMissingDependencyReporter(step: String)` 改为 `bindMissingDependencyReporter(_ step: MissingDependencyStep)`；
  - `message_apply_coordinator / message_failure_feedback_coordinator / media_send_coordinator / text_send_coordinator / message_flow_coordinator` 等全部改为枚举注入。
- 收益：
  - 去掉字符串 step 手写，降低缺依赖日志 drift 风险；
  - VC 装配段继续减少样板，便于 A2 最终收口。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：resolver/provider 回调复用）
- 代码变更：
  - `DemoAlignedChatViewController` 新增复用回调属性：
    - `conversationIDProvider`
    - `onSendSucceededCallback`
    - `onSendFailureHintCallback`
  - `assemblyDependencyResolver` 与 `chatContextProvider` 改为共享 `conversationIDProvider`；
  - 文本/媒体发送成功回调改为共享 `onSendSucceededCallback`；
  - 消息流失败提示回调改为共享 `onSendFailureHintCallback`。
- 收益：
  - 重复 provider/callback 注入进一步减少，VC 装配段更紧凑；
  - 关键回调单点化，后续改行为时更不容易漏改。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：缺依赖 reporter 下沉到 Resolver）
- 代码变更：
  - `DemoAlignedChatAssemblyDependencyResolver` 新增：
    - `DemoAlignedChatAssemblyMissingDependencyStep`
    - `makeMissingDependencyReporter(for:)`
    - `reportMissing(step: DemoAlignedChatAssemblyMissingDependencyStep, ...)` 重载
  - `DemoAlignedChatViewController` 删除：
    - VC 内 `MissingDependencyStep`
    - `bindMissingDependencyReporter(...)`
  - `onMissingDependencies` 全部改为 resolver 注入的 `missingDependencyReporter(.xxx)`。
- 收益：
  - 缺依赖上报职责继续从 VC 下沉，VC 装配段更聚焦；
  - step + reporter 策略集中在 Support 层，减少后续维护分散点。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：装配依赖清单 bind 样板压缩）
- 代码变更：
  - `DemoAlignedChatViewController.makeAssemblyActionDispatcherBundleDependencies()` 引入局部 `let bind = bindAssemblyConfiguration`；
  - 清单内 `bindAssemblyConfiguration(...)` 统一改为 `bind(...)` 写法。
- 收益：
  - 装配清单更紧凑，重复样板进一步下降；
  - 行为保持不变，便于后续继续抽离。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：弱绑定器统一下沉）
- 代码变更：
  - `DemoAlignedChatViewController` 删除 6 个通用绑定方法：
    - `bindAssemblyConfiguration`
    - `bindActionHandler`
    - `bindMainActorAsyncAction`
    - `bindCallback`
    - `bindAsyncCallback`
    - `bindValueProvider`
  - 新增 `DemoAlignedWeakBinder`，统一弱引用绑定策略；
  - VC 内所有相关注入改为 `DemoAlignedWeakBinder.*(owner:self, ...)`。
- 收益：
  - VC 基础设施样板继续下降，装配段可读性更高；
  - 弱引用绑定策略集中，后续维护更一致。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：装配清单迁出 VC 主体）
- 代码变更：
  - `DemoAlignedChatViewController` 删除主类内 `makeAssemblyActionDispatcherBundleDependencies()`；
  - `assemblyConfigurationExecutor` 改为使用类外工厂：
    - `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.make(owner:)`；
  - 新增私有工厂类型承接 25 项 action->configure 清单映射；
  - 参与映射的 `configure*` 方法可见域收口为 `fileprivate`（仅当前文件）。
- 收益：
  - VC 主类进一步减重，装配清单从主逻辑中剥离；
  - 映射清单集中，后续迁入 `Support/` 独立文件更容易。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A2 继续：Dispatcher/WeakBinder 迁入 Support 文件）
- 代码变更：
  - 新增 Support 文件：
    - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.swift`
  - `DemoAlignedChatViewController`：
    - `assemblyConfigurationExecutor.dispatcherBundleDependencies` 改为调用
      `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.make(executeAction:)`；
    - 新增 `performAssemblyConfigurationAction(_:)` 作为 action 分发入口；
    - 删除 VC 文件内私有类型 `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory` 与 `DemoAlignedWeakBinder`。
  - 可见域调整：
    - 参与 action->configure 映射的 `configure*` 方法从 `fileprivate` 恢复为 `private`。
- 收益：
  - Dispatcher/WeakBinder 与 VC 主体彻底解耦，Support 分层更清晰；
  - VC 持续减重，装配职责更聚焦在注入与路由。
- 构建验证：
  - `xcodegen generate`（cwd: `/Users/blackie/Projects/raver/mobile/ios/RaverMVP`）
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`asset.duration` deprecate、`Metadata extraction skipped`）。

#### 2026-04-24（A2 清尾：移除 VC 内 `performAssemblyConfigurationAction`）
- 代码变更：
  - `DemoAlignedChatViewController` 删除 `performAssemblyConfigurationAction(_:)`（25 项 switch）；
  - 新增 `assemblyDispatcherBundleDependencies`，直接用 `DemoAlignedWeakBinder.assemblyConfiguration` 绑定 `configure*`；
  - `assemblyConfigurationExecutor` 直接消费 `DemoAlignedChatScreenAssemblyActionDispatcherBundleDependencies`，不再走 `executeAction -> switch` 中转。
- 收益：
  - Assembly 配置分发进一步下沉到 Support 执行器；
  - VC 责任面继续收缩，更贴近 demo 的容器化分层。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`asset.duration` deprecate、`Metadata extraction skipped`）。

#### 2026-04-24（OpenIM/BFF 默认端口收口：3901）
- 代码与脚本变更：
  - `server/src/scripts/openim-bff-squad-manage-smoke.ts` 默认 BFF 改为 `http://localhost:3901`；
  - `server/.env.openim.example` 默认 `OPENIM_BFF_BASE_URL` 改为 `http://localhost:3901`；
  - 本地脚本统一到 `3901`：
    - `restart-dev.sh`
    - `start-all.sh`
    - `check-status.sh`
    - `status.sh`
    - `start.sh`
- 文档示例变更：
  - `docs/OPENIM_LOCAL_DEV.md`
  - `docs/OPENIM_INTEGRATION_PLAN.md`
  - `docs/DEV_PROXY_DB_RUNBOOK.md`
  - `docs/TEST_ENV_DEPLOYMENT_PLAN.md`
- 结果：
  - OpenIM/BFF 关键默认源头与 iOS/Xcode 运行环境统一为 `3901`，降低端口回退污染风险。

#### 2026-04-24（A2 清尾：删除 `make(executeAction:)` 遗留路径）
- 代码变更：
  - `Support/DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.swift` 删除
    `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.make(executeAction:)`；
  - 保留 `DemoAlignedWeakBinder` 作为通用弱绑定工具。
- 收益：
  - Assembly dependencies 注入路径收敛为单实现；
  - A2 本轮“action 中转链路”遗留代码清理完成。

#### 2026-04-24（A2 清尾：VC 装配依赖清单收口）
- 代码变更：
  - `DemoAlignedChatViewController`：
    - `assemblyDispatcherBundleDependencies` 改为
      `makeAssemblyDispatcherBundleDependencies()`；
    - 新增 `bindAssemblyConfiguration(...)`；
    - 新增 `makeAssemblyDispatcherBundleDependencies()`，集中承载 25 项
      action->configure 绑定，移出属性区内联大表。
- 收益：
  - VC 属性段噪音明显下降，主类主体可读性更高；
  - A2 目标“VC 收敛为 UI 容器”本轮收口完成。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A3 第一刀：系统消息 Cell 对齐）
- 代码变更：
  - `RaverChatMessageCellFactory`：
    - 新增 `DemoAlignedSystemMessageCell` 注册；
    - 新增 `case .system` 分流到系统消息专用 Cell；
    - 其余分流保持：
      - `image/video/voice/file` -> `DemoAlignedMediaMessageCell`
      - default -> `DemoAlignedMessageCell`
  - `DemoAlignedTimeSeparatorCell.swift`：
    - 新增 `DemoAlignedSystemMessageCell`（居中胶囊、系统提示样式）。
  - `RaverChatCollectionDataSource`：
    - `updateMessages` 入口过滤 `typing` 消息，保持 typing 仅走输入状态展示，不渲染为历史气泡。
- 收益：
  - “系统消息”不再复用普通聊天气泡，视觉语义更接近 demo；
  - A3 的“文本/图片/视频/语音/文件/系统消息 Cell 同构”完成度提升并完成勾选。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A3 收口：发送态动效补齐）
- 代码变更：
  - `DemoAlignedMessageCell`：
    - sending 状态图标新增旋转动画；
    - sent/failed/reuse 场景统一停止动画并清理图标状态。
  - `DemoAlignedMediaMessageCell`：
    - 与文本 cell 对齐，补齐 sending 旋转动画；
    - sent/failed/reuse 场景统一停止动画并清理图标状态。
- 收益：
  - “发送中”状态更接近 OpenIM demo 的动态反馈；
  - cell 复用稳定性更好，不会残留上一条消息的发送动效。

#### 2026-04-24（A4 回归增强：分页与滚动可观测性）
- 代码变更：
  - `DemoAlignedPaginationCoordinator`：
    - 增加分页触发/复位与 loading 状态日志。
  - `RaverChatScrollCoordinator`：
    - 增加自动滚底决策日志（是否滚底 + 原因 + 输入条件）。
  - `DemoAlignedViewportCoordinator`：
    - 增加新消息累积、回到底部按钮 show/hide 与点击日志。
  - `DemoAlignedMessageFlowCoordinator`：
    - 增加历史分页加载 start/end 与 apply 结果日志（auto-scroll/pending/failure-hint）。
  - `openim_dual_sim_probe.sh`：
    - `FOCUS_REGEX` 增加 A4 日志前缀聚合。
  - `openim_probe_digest.sh`：
    - 增加 `paginationTrigger/autoScrollYes/autoScrollNo/jumpShow/jumpHide` 指标。
- 收益：
  - A4 验收不再依赖纯手眼判断，日志能直接解释“为什么没滚底/为什么显示回到底部按钮”；
  - 双机 probe 回归定位效率提升（弱网与分页场景可追溯）。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

#### 2026-04-24（A4 回归复测：90s 双机探针 + 自动注入）
- 执行：
  - `OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=90 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
  - `OPENIM_PROBE_SESSION_TYPE=single OPENIM_PROBE_SENDER_IDENTIFIER=blackie OPENIM_PROBE_RECEIVER_IDENTIFIER=uploadtester OPENIM_PROBE_MESSAGE_COUNT=5 OPENIM_PROBE_INTERVAL_MS=600 npm run openim:probe:send`
- 报告：
  - `/Users/blackie/Projects/raver/docs/reports/openim-dual-sim-20260424-192315`
- digest 摘要：
  - `overall: 双侧日志有效`
  - `SIM1`: realtime=10 / catchup=0 / login10102=0 / unavailable=0
  - `SIM2`: realtime=15 / catchup=0 / login10102=0 / unavailable=0
  - A4 指标：`paginationTrigger=0`，`autoScrollYes/No=0`，`jumpShow/Hide=0`（本轮未进行会话内上滑/回到底部交互）。
- 结论：
  - 实时链路与 red badge 更新链路继续稳定；
  - 需补一轮“会话内手势交互”专项回归（上滑到顶分页 + 回到底部按钮），用于完成 A4 分页证据闭环。

#### 2026-04-24（A4 回归复测补样：会话内手势交互）
- 执行：
  - `OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=90 OPENIM_PROBE_USE_APP_LOG=1 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
- 报告：
  - `/Users/blackie/Projects/raver/docs/reports/openim-dual-sim-20260424-212001`
- digest 摘要：
  - `overall: 双侧日志有效`
  - `SIM1`: realtime=5 / catchup=0 / login10102=0 / unavailable=0
  - `SIM2`: realtime=20 / catchup=0 / login10102=0 / unavailable=0
  - A4 指标：
    - `SIM1`: `paginationTrigger=0`，`autoScrollYes=14`，`autoScrollNo=21`，`jumpShow=8`，`jumpHide=8`
    - `SIM2`: `paginationTrigger=9`，`autoScrollYes=4`，`autoScrollNo=35`，`jumpShow=10`，`jumpHide=9`
- 结论：
  - A4 分页专项证据闭环完成（已出现 `paginationTrigger > 0` 与 jump 显隐/点击链路）；
  - 实时链路维持理想态（`catchup/login10102/unavailable` 均为 0）。

#### 2026-04-24（F11 第一刀：会话内搜索 UI 首版接线）
- 代码变更：
  - `DemoAlignedChatViewController`
    - 新增导航栏搜索入口（放大镜）；
    - 新增结果页 push、消息定位、定位失败提示；
    - 新增“命中不在当前窗口时，自动尝试一次上拉历史后再定位”回退逻辑。
  - 新增 `Support/DemoAlignedConversationSearchCoordinator.swift`
    - 搜索输入、执行、空结果提示、失败提示。
  - 新增 `Support/DemoAlignedChatSearchResultsViewController.swift`
    - 搜索结果列表与点击回跳定位。
  - `RaverChatCollectionDataSource`
    - 新增 `indexPath(forMessageID:)` 定位接口。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
  - 结果：`BUILD SUCCEEDED`（仅既有 Pods deployment target warning）。
- 阶段判断：
  - F11 从 `NotStarted` 进入 `InProgress`（会话内入口已接线，全局搜索待补齐）。

#### 2026-04-24（F11 第二刀：搜索结果关键词高亮）
- 代码变更：
  - `DemoAlignedChatSearchResultsViewController`
    - 对命中关键词应用高亮（accent 色 + semibold），提升结果可读性与确认效率。
- 阶段判断：
  - F11 会话内搜索体验进入“可用 + 可读”阶段，下一步转向全局搜索入口与分组展示。

#### 2026-04-24（F11 二轮收口：全局搜索入口 + 会话分组）
- 代码变更：
  - `MessagesHomeView`
    - 新增全局搜索入口（导航栏放大镜）；
    - 新增 `MessageGlobalSearchSheet`：
      - 全局搜索输入；
      - 按会话分组结果展示；
      - 点击结果后进入目标会话。
  - `MessagesViewModel`
    - 新增 `GlobalSearchSection`；
    - 新增 `searchGlobally(query:)`；
    - 新增全局搜索状态管理（loading/error/clear）。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。
- 阶段判断：
  - F11 已进入“会话内 + 全局入口 + 分组结果”可用态；
  - 下一步聚焦“全局结果点击后消息锚点定位”与专项探针回归。

#### 2026-04-24（F11 三轮收口：全局结果点击后消息锚点定位）
- 代码变更：
  - `OpenIMChatStore`
    - 新增 pending focus 存取：
      - `setPendingMessageFocus(messageID:conversationID:)`
      - `consumePendingMessageFocus(for:)`
    - 在 `reset/clearMessages/removeConversation` 时同步清理 pending focus。
  - `MessagesHomeView`（`MessageGlobalSearchSheet`）
    - 全局搜索结果点击时先写入 pending focus，再跳转目标会话。
  - `DemoAlignedChatViewController`
    - 在 `viewDidAppear` 增加 pending focus 消费；
    - 等待初次加载完成后执行 `revealMessage(withID:allowLoadOlder: true)`；
    - 目标消息不在当前窗口时自动补拉历史并重试定位。
- 构建验证：
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
    - 结果：`BUILD FAILED`（链接阶段缺失 `MJExtension/OpenIMSDK`，属于 project 入口差异）。
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
    - 结果：`BUILD SUCCEEDED`（仅既有 Pods deployment target warning）。
- 阶段判断：
  - F11 主路径已覆盖“会话内搜索 + 全局搜索 + 分组展示 + 结果点击定位”；
  - 下一步进入 A4 弱网回归与搜索专项探针补样。

#### 2026-04-24（F11 四轮收口：搜索专项探针可观测性）
- 代码/脚本变更：
  - `mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
    - `FOCUS_REGEX` 增加 `\[GlobalSearch\]`、`\[DemoAlignedSearch\]`。
  - `mobile/ios/RaverMVP/scripts/openim_probe_digest.sh`
    - 新增 F11 计数输出：
      - `searchGlobal trigger/submit/result/selected/failed`
      - `searchInConversation submit/result/empty/selected/failed`
      - `searchAnchor focusRequest/revealHit/revealMiss/loadOlder/pendingConsume/pendingReveal`
    - `key tail` 增加 `GlobalSearch/DemoAlignedSearch`。
  - iOS 业务日志补齐（供 probe 消费）：
    - `MessagesViewModel`、`MessagesHomeView`
    - `DemoAlignedConversationSearchCoordinator`
    - `DemoAlignedChatSearchResultsViewController`
    - `DemoAlignedChatViewController`
- 脚本验证：
  - `bash -n /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
  - `bash -n /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh`
  - 结果：通过。
- 阶段判断：
  - F11 探针链路已具备可观测性；
  - 剩余动作为补一轮“真实搜索操作”的 90 秒样本，把上述搜索指标打成非 0 证据。

#### 2026-04-24（A4 弱网回放：服务抖动自动回归）
- 自动回放能力：
  - 新增 `mobile/ios/RaverMVP/scripts/openim_a4_weaknet_replay.sh`：
    - 自动执行 probe + OpenIM 停机/恢复 + 消息注入 + digest；
    - 用于减少 A4 弱网链路手测成本。
  - `docs/OPENIM_DUAL_SIM_BADGE_RUNBOOK.md` 3.3 增补一键执行说明与参数。
- 有效样本：
  - `run`: `/Users/blackie/Projects/raver/docs/reports/openim-dual-sim-20260424-223332`
  - digest：`overall: 双侧日志有效`
  - `SIM1`: connected=1 / realtime=10 / catchup=0 / login10102=0 / unavailable=0
  - `SIM2`: connected=1 / realtime=18 / catchup=0 / login10102=0 / unavailable=0
  - 抖动证据：`OpenIM state -> failed("dial tcp 127.0.0.1:10001: connect: connection refused")`；恢复后 `state -> connected` 且 realtime 持续增长。
- 阶段判断：
  - A4 在“服务抖动恢复”维度通过；
  - 会话内 `send failure hint / resend` UI 证据可在下一轮常规回归补齐（当前样本该计数为 0）。
