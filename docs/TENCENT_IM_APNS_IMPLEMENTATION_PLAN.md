# Raver 聊天 APN / 离线推送实施方案（Tencent IM First）

> 适用范围：`/Users/blackie/Projects/raver`
>
> 目标：优先采用 **Tencent IM 官方 APNs / Offline Push 能力** 完成聊天消息离线推送；仅在 Tencent IM 无法满足的场景下，再回退到 Raver 自建 APNs 通道。
>
> 文档定位：
> - 需求梳理
> - 产品待确认问题
> - 技术实施步骤
> - 开发流程与落地方法
> - 进度跟踪系统
>
> 最后更新：2026-05-01（Asia/Shanghai）

---

## 1. 结论先行

当前聊天 APN 能力建议采用以下策略：

1. **聊天消息离线推送主链路**
- 优先走 Tencent IM 官方 APNs / Offline Push。
- 原因：
  - 与 Tencent IM 会话、未读数、静音状态、消息发送链路天然一致
  - 少一层“消息先到腾讯，再复制到自家 APNs”的双写复杂度
  - 更接近常规 IM 的实现方式

2. **自建 APNs 的定位**
- 不作为聊天消息的第一优先方案
- 仅在以下情况作为补充：
  - 需要 Tencent IM 不支持的特殊 payload 结构
  - 需要统一承载非 IM 业务通知
  - 需要更复杂的频控、聚合、实验、运营治理
  - 需要做跨系统统一通知中心

3. **本期推荐范围**
- 先完成“消息类 APN”闭环
- 再决定是否扩展到：
  - 群邀请
  - 提及 / 回复
  - 群公告
  - 角色变更
  - 撤回同步提示

---

## 2. 当前代码现状

## 2.1 iOS 已具备能力

当前 iOS 已具备：

- 真机 APNs token 注册
  - [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/RaverMVPApp.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/RaverMVPApp.swift)
- token 上报到你自己的服务端
  - [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
  - [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift)
- 通知点击后，App 能收到系统通知 payload 并进行路由
  - `raverDidOpenSystemNotification`

## 2.2 服务端已具备能力

当前服务端已具备：

- 自建 APNs HTTP/2 发送器
  - [/Users/blackie/Projects/raver/server/src/services/notification-center/notification-apns.handler.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-apns.handler.ts)
- 设备 token 注册与失活
  - [/Users/blackie/Projects/raver/server/src/services/notification-center/notification-center.service.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-center.service.ts)
- APNs 管理接口与 outbox 能力
  - `/v1/notification-center/*`

## 2.3 聊天链路当前缺口

当前聊天发送链路里，Tencent IM 的离线推送字段还没有接上：

- [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
  - 发送消息时 `offlinePushInfo: nil`

这意味着：

- 聊天消息虽然能正常发到 Tencent IM
- 但 Tencent IM 官方离线推送文案链路并没有真正启用

当前已完成的基础接入：

- iOS 已在 Tencent IM 会话层接入 `setAPNSListener(...)`
- iOS 已在以下时机尝试调用 `setAPNS(config:succ:fail:)`
  - APNs token 更新后
  - Tencent IM 登录成功后
  - App 回前台并恢复 Tencent IM 会话后
- Tencent IM APNS `businessID` 现通过以下配置来源读取：
  - 环境变量 `RAVER_TENCENT_IM_APNS_BUSINESS_ID`
  - 或 iOS `Info.plist` 的 `TencentIMAPNSBusinessID`
- iOS 已接入自定义 badge bridge，避免 Tencent SDK 在后台直接把角标改回“仅聊天未读”

仍待完成：

- 每类消息发送时的 `offlinePushInfo`
- 系统通知点击后的 APN `ext` 深链解析
- 群公告 / 邀请 / 角色变更类 APN

---

## 3. Tencent IM 官方 APN 能力边界

基于本地 SDK 头文件可确认，Tencent IM 官方支持：

- `V2TIMManager+APNS.h`
  - `setAPNSListener(...)`
  - `setAPNS(config:succ:fail:)`
  - `V2TIMAPNSConfig`

- `V2TIMManager+Message.h`
  - `V2TIMOfflinePushInfo`
  - 核心字段包括：
    - `title`
    - `desc`
    - `ext`
    - `disablePush`
    - `ignoreIOSBadge`
    - `iOSSound`
    - `iOSInterruptionLevel`
    - `enableIOSBackgroundNotification`

也就是说，Tencent IM 官方方案可覆盖：

- 普通消息 APN
- 自定义标题 / 内容
- 深链扩展字段
- badge 是否累加
- 声音策略
- iOS 15+ interruption level
- 静音 / 免打扰的消息级控制

---

## 4. 常见 IM APN 需求清单

下面这份清单是按常见 IM 产品做法整理的，建议逐条确认。

## 4.1 基础消息离线推送

### 需求项

1. 私聊文本消息离线推送
2. 私聊图片 / 视频 / 语音 / 音频文件离线推送
3. 群聊文本消息离线推送
4. 群聊媒体消息离线推送
5. 自定义消息是否推送。例如app内的转发卡片类型，是要做的，不过可以留在后面这部分做了之后再进行。

### 推荐默认值

- 私聊：全部支持推送
- 群聊：全部支持推送
- 自定义消息：仅推用户可理解的类型，不推内部状态消息

## 4.2 推送内容展示

### 需求项

1. 私聊推送标题展示什么
- 推荐：发送者昵称

2. 私聊推送正文展示什么
- 推荐：消息摘要
  - 文本：原文
  - 图片：`[图片]`
  - 视频：`[视频]`
  - 语音：`[语音]`，带语音时长信息
  - 音频文件：`[音频]`，带文件名称
  - 文件：`[文件]`，现在不支持文件类型不用做

3. 群聊推送标题展示什么
- 推荐：群名

4. 群聊推送正文展示什么
- 推荐：`发送者名: 摘要`

5. 是否支持“隐私模式”
- 推荐：
  - 锁屏时仅显示“你收到一条新消息”
  - App 内提供开关，放在个人主页-更多里面，因为除了社交相关的apn还存在其他通知。

## 4.3 推送点击后的路由

### 需求项

1. 点私聊 APN 是否直达该私聊会话
2. 点群聊 APN 是否直达该群会话
3. 点通知时，如果用户未登录怎么办
4. 点通知时，如果该会话本地不存在怎么办

### 推荐默认值

- 已登录：直接进对应会话
- 未登录：先去登录，登录后恢复路由
- 会话不存在：显示会话不存在的通知

## 4.4 badge 与未读数

### 需求项

1. iOS App Icon badge 是否由 Tencent IM 自动维护
2. 是否允许忽略某些消息对 badge 的影响
3. 前台打开 App 后 badge 是否立即清零

### 已确认方案

- 采用 **方案 B：Raver 全站统一未读数**

具体定义：

- 会话列表未读 / 会话红点：
  - 只看 `Tencent unread`
- App 图标 badge：
  - `badge = Tencent unread + 其他通知未读`

其中“其他通知未读”至少包括：

- 点赞
- 评论
- 关注
- 小队邀请
- 群公告
- 群角色变更
- 以及后续纳入通知中心未读口径的其他站内通知

### 设计说明

这意味着：

- 聊天列表里的会话未读数，不一定和桌面 badge 一致
- 这是产品定义，不是 bug
- 前台打开app后，如果没有查看相应的消息，那么退出到手机桌面后，app的badge仍然应该保持未读数量

### 推荐补充规则

1. 打开聊天并读完会话
- 只减少 `Tencent unread`
- 不影响点赞 / 评论等通知未读

2. 打开通知中心并清掉通知未读
- 只减少“其他通知未读”
- 不影响聊天未读

3. badge 刷新时机
- 登录成功后刷新一次
- 收到新聊天消息后刷新
- 通知中心未读变化后刷新
- App 进入前台时兜底刷新一次

## 4.5 静音 / 免打扰

### 需求项

1. 私聊 `Mute Notifications` 是否应直接影响 APN
2. 群聊 `Mute Notifications` 是否应直接影响 APN

### 推荐默认值

- 私聊 mute：不发 APN
- 群聊 mute：不发 APN

## 4.6 特殊消息策略

### 需求项

1. 被 @ 时是否强提醒
2. 回复我时是否强提醒
3. 群公告是否推送
4. 群成员邀请是否推送
5. 角色变更（管理员 / 队长）是否推送
6. 撤回消息是否推送

### 推荐默认值

- `@我`：推送，且可考虑更高 interruption level
- 回复我：推送
- 群公告：推送
- 群邀请：仅和自己相关的推送
- 角色变更：仅和自己相关的推送
- 撤回：默认不额外发 APN，只在会话内同步

## 4.7 多端与在线状态

### 需求项

1. 用户在另一台 iPhone 正在线时，当前设备是否仍然收 APN
2. 用户在当前设备前台打开会话时，是否还发 APN
3. iPad / iPhone 多端如何处理

### 推荐默认值

- 当前设备前台打开对应会话：不需要 APN 横幅
- 当前账号在其他端在线：仍允许离线设备收 APN
- 多端 badge 统一按全站总未读计算

---

## 5. 需要你拍板的产品问题

下面这些是本方案里必须确认的点。我先给推荐值，你确认后就能进入开发。

| 编号 | 问题 | 推荐默认值 | 你需确认 |
|---|---|---|---|
| Q1 | 私聊锁屏是否展示正文 | 展示正文 | 是 / 否 |
| Q2 | 群聊锁屏是否展示 `发送者: 内容` | 是 | 是 / 否 |
| Q3 | 群消息被 mute 后，@我 是否仍然推送 | 是 | 是 / 否 |
| Q4 | 回复我是否提升通知级别 | 否，先普通 alert | 是 / 否 |
| Q5 | 是否启用 `time-sensitive` | 先不启用 | 是 / 否 |
| Q6 | 撤回消息是否发单独 APN | 否 | 是 / 否 |
| Q7 | 邀请入群是否走 Tencent IM APN 还是自建 APN | Tencent IM 优先 | 是 / 否 |
| Q8 | 群公告是否发 APN | 是 | 是 / 否 |
| Q9 | 是否做全局聊天隐私预览开关 | 第二期做 | 是 / 否 |
| Q10 | 多端登录时是否允许所有 iOS 设备都收 APN | 是 | 是 / 否 |

---

## 5.1 当前已确认的产品决定

以下口径已经确认，可直接作为开发默认值：

1. 私聊锁屏通知显示正文
2. 群聊锁屏通知显示 `发送者: 内容`
3. 群聊 mute 后，如果消息 `@我`，仍然推送
4. 群公告走 APN
5. 群邀请 / 群角色变更中，和自己相关的要通知
6. App 图标 badge 采用 **方案 B：Raver 全站统一未读数**

---

## 6. 总体技术路线

## 6.1 主路线

### 第一优先
- **Tencent IM 官方 APNs / Offline Push**

### 第二优先
- 当 Tencent IM 无法满足时
- 再走 Raver 自建 APNs 通知中心

## 6.2 选择原则

| 场景 | 推荐链路 |
|---|---|
| 私聊 / 群聊普通消息 | Tencent IM APNs |
| 私聊 / 群聊媒体消息 | Tencent IM APNs |
| @我 / 回复我 | Tencent IM APNs + 本地 ext 路由 |
| 群邀请 / 群角色变更 | 先 Tencent IM，必要时补自建 APNs |
| 非聊天业务通知 | 自建 notification-center APNs |

---

## 7. 具体开发步骤

## Phase A：打通 Tencent IM APNs 基线

### 目标
- 让 Tencent IM 官方离线推送真正生效

### 具体落实

1. iOS 在 APNs token 注册成功后，除了上报自家服务端，还要配置 Tencent IM APNS
- 入口：
  - [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/RaverMVPApp.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/RaverMVPApp.swift)
  - [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
- 使用：
  - `V2TIMManager.sharedInstance().setAPNSListener(...)`
  - `V2TIMManager.sharedInstance().setAPNS(config:succ:fail:)`
  - `V2TIMAPNSConfig`

2. 配置 Tencent 控制台 APNs certificate / business id
- 确认使用 APNs 直连模式
- 不走 TPNS 旧方案

3. 明确登录后、token 更新后、登出后的 APNs 配置时机
- 登录成功后：检查并设置 APNS config
- APNs token 刷新后：重新 setAPNS
- 登出后：按腾讯侧能力决定是否重置 / 清理

### 验收
- 私聊离线消息在真机锁屏状态可收到腾讯 IM APN
- 群聊离线消息在真机锁屏状态可收到腾讯 IM APN

## Phase B：消息发送链路补 offlinePushInfo

### 目标
- 所有聊天消息在发送时携带正确的离线推送描述

### 当前缺口
- 发送链路 `offlinePushInfo` 还是 `nil`

### 具体落实

在：
- [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)

统一补一个：
- `buildOfflinePushInfo(messageKind:conversationType:senderName:groupName:previewText:metadata:)`

并在所有发送分支里传给：
- `manager.sendMessage(... offlinePushInfo: info ...)`

### 推荐映射

| 消息类型 | 私聊 desc | 群聊 desc |
|---|---|---|
| 文本 | 原文 | `发送者: 原文` |
| 图片 | `[图片]` | `发送者: [图片]` |
| 视频 | `[视频]` | `发送者: [视频]` |
| 语音 | `[语音]` | `发送者: [语音]` |
| 音频文件 | `[音频]` | `发送者: [音频]` |
| 文件 | `[文件]` | `发送者: [文件]` |

`ext` 推荐带：
- `conversationID`
- `sdkConversationID`
- `peerID`
- `groupID`
- `conversationType`
- `messageID`
- `route = messages/chat`

### 验收
- 不同消息类型锁屏通知文案正确
- 点击通知能还原到正确聊天页

## Phase C：会话级静音与 APN 联动

### 目标
- `Mute Notifications` 真正影响消息 APN

### 具体落实

现有会话静音已经接到：
- `setC2CReceiveMessageOpt`
- `setGroupReceiveMessageOpt`

需要验证并收口：
- 私聊 mute 后，Tencent IM 是否不再发 APN
- 群聊 mute 后，Tencent IM 是否不再发 APN

如果 Tencent SDK 的会话接收选项不足以覆盖你的产品语义，则补一层：
- 发送时按会话状态动态 `disablePush`

### 验收
- 被 mute 的会话不再有 APN
- 取消 mute 后恢复 APN

## Phase D：通知点击路由闭环

### 目标
- 点击系统通知直达对应私聊 / 群聊

### 具体落实

现有入口：
- `raverDidOpenSystemNotification`

需要增加：
- 腾讯 APN `ext` payload 解析器
- 路由恢复器：
  - 未登录 -> 登录 -> 恢复
  - 已登录 -> 直接进入会话

### 验收
- 私聊通知点击后进入私聊页
- 群聊通知点击后进入群聊页

## Phase E：特殊消息策略

### 目标
- 补齐 IM 常见增强通知

### 可选能力

1. `@我`
2. 回复我
3. 群公告
4. 群邀请
5. 管理员 / 队长角色变更

### 实现方法

- 优先仍走 Tencent IM `offlinePushInfo`
- 如无法满足，则：
  - 用 Tencent 消息链做会话同步
  - 用自建 APNs 发特殊通知

---

## 8. 整体开发流程

推荐你后续都按这个流程推进：

### Step 1：先定义产品口径
- 一次只确认 1 个通知类型
- 明确：
  - 什么时候发
  - 发给谁
  - 标题展示什么
  - 内容展示什么
  - 点击后去哪里
  - 是否受 mute 影响

### Step 2：先用 Tencent 官方能力实现最小闭环
- 不先引入自建 APNs
- 先用：
  - `setAPNS`
  - `offlinePushInfo`
  - 会话接收选项

### Step 3：做真机 E2E 用例
- 前台
- 后台
- 锁屏
- 已登录
- 未登录
- 单端 / 多端

### Step 4：确认哪些点 Tencent 做不到
- 只有确认做不到，才补自建 APNs

### Step 5：回写文档和 tracker
- 每做完一项，都更新本文档里的进度表

---

## 9. 具体落实方法

## 9.1 iOS 侧

### 要改的重点

1. `RaverMVPApp.swift`
- 保持系统 APNs token 注册
- 增加 Tencent IM APNS config 设置触发链

2. `AppState.swift`
- 持有最新 APNs token
- 登录态 / token 更新时配置 Tencent APNS
- 发送消息时统一注入 `offlinePushInfo`
- 统一处理通知点击深链

3. 消息发送链
- 文本
- 图片
- 视频
- 语音
- 音频文件
- 文件

全部统一经过：
- `buildOfflinePushInfo(...)`

## 9.2 服务端

### 第一阶段
- 保持现有自建 APNs 不动
- 不先下掉
- 作为后备能力保留

### 第二阶段
- 若某些场景确认必须自建 APNs
- 再在 notification-center 里单独增加：
  - `chat_message_special`
  - `chat_group_invite`
  - `chat_group_role_changed`
  等 category

---

## 10. 进度跟踪系统

建议就用这张表推进，每一项都只允许三种状态：
- `Not Started`
- `In Progress`
- `Done`

## 10.1 主跟踪表

| ID | 任务 | 状态 | 负责人 | 验收标准 | 备注 |
|---|---|---|---|---|---|
| APN-01 | Tencent IM APNS token/config 接通 | Done | iOS 已接入 `setAPNSListener`、token 更新/登录成功/回前台恢复三处 `setAPNS`；badge bridge 已改成全站总未读口径 | 真机登录后 Tencent APNS 设置成功 | 待你提供真实 `RAVER_TENCENT_IM_APNS_BUSINESS_ID` 并真机联调 |
| APN-02 | 文本消息 offlinePushInfo | In Progress | iOS 文本消息已开始注入 `offlinePushInfo`，包含私聊/群聊 title、desc、`ext` 路由字段 | 私聊/群聊文本锁屏可收 | 待双账号真机后台验证 |
| APN-03 | 媒体消息 offlinePushInfo | Not Started |  | 图片/视频/语音锁屏文案正确 | |
| APN-04 | 文件消息 offlinePushInfo | Not Started |  | 音频文件/文件锁屏文案正确 | |
| APN-05 | 通知点击直达私聊 | Not Started |  | 点私聊通知直达会话 | |
| APN-06 | 通知点击直达群聊 | Not Started |  | 点群聊通知直达会话 | |
| APN-07 | 会话 mute 与 APN 联动 | Not Started |  | mute 后不再收 APN | |
| APN-08 | badge 策略统一 | Not Started |  | badge = Tencent unread + 其他通知未读 | |
| APN-09 | @我 / 回复我 增强策略 | Not Started |  | 命中时推送符合预期 | |
| APN-10 | 群邀请 / 群角色变更通知 | Not Started |  | 特殊场景通知闭环 | |
| APN-11 | 真机 E2E 回归集 | Not Started |  | 前台/后台/锁屏全通过 | |
| APN-12 | 是否需要自建 APNs 补位评估 | Not Started |  | 有结论和范围界定 | |

## 10.2 单项执行模板

每做一项，都按下面格式记录：

```md
### APN-XX 名称
- 状态：
- 开始日期：
- 代码改动：
- 真机验证：
- 剩余问题：
- 是否需要自建 APNs 兜底：
```

---

## 11. 推荐的近期执行顺序

如果现在立刻开始开发，我建议按这个顺序：

1. `APN-01` Tencent IM APNS token/config 接通
2. `APN-02` 文本消息 offlinePushInfo
3. `APN-05` / `APN-06` 通知点击路由
4. `APN-07` 会话 mute 与 APN 联动
5. `APN-03` / `APN-04` 媒体与文件消息文案
6. `APN-08` badge（按全站统一未读数）
7. `APN-09` / `APN-10` 特殊消息策略
8. `APN-12` 是否需要自建 APNs 补位评估

---

## 12. 我建议你先确认的最小产品集

为了让我们下一步能直接开工，请你优先确认下面这 6 件事：

1. 私聊锁屏是否显示正文
2. 群聊锁屏是否显示 `发送者: 内容`
3. 群 mute 后，@我 是否仍然推送
4. 群公告是否走 APN
5. 群邀请 / 角色变更是否走 APN
6. badge 已确认采用方案 B：Raver 全站统一未读数

如果这 6 项确认了，下一步就可以直接进入：
- `APN-01` 和 `APN-02`

---

## 13. 本文档对应的当前结论

截至当前，推荐结论是：

- **聊天 APN 第一阶段：只接 Tencent IM 官方 APNs**
- **自建 APNs：先不作为聊天主链路**
- **只有 Tencent IM 无法满足时，再引入自建 APNs 的补位通知**
- **badge 采用方案 B：Raver 全站统一未读数**

这能让聊天通知能力先最快成型，并且与当前 Tencent IM 会话、未读、静音逻辑保持最大一致。
