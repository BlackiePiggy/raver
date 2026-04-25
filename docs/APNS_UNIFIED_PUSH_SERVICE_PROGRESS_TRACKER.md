# Raver 统一 APNs Push Service 进度追踪（可交接）

> 配套方案文档：`docs/APNS_UNIFIED_PUSH_SERVICE_IMPLEMENTATION_PLAN.md`
>
> 目的：持续记录“已完成/进行中/待完成”，并给出证据和下一步，保证任意同学接手时零歧义。
>
> 最后更新：2026-04-23（Asia/Kuala_Lumpur）

---

## 1. 总览看板

| 阶段 | 目标 | 状态 | 完成度 | 说明 |
|---|---|---|---:|---|
| Phase 0 | 打通与纠偏（能发、不错发、不串推） | Done | 100% | 已完成真机 APNs 成功投递与登出失活回归 |
| Phase 1 | 统一通知读写面 | In Progress | 85% | iOS 已切 notification-center/inbox*，并补自动回归脚本 |
| Phase 2 | Push Gateway 商用化（异步化） | In Progress | 25% | 已落地 outbox+worker 骨架（默认关闭） |
| Phase 3 | 策略与编排增强 | In Progress | 55% | 去重/频控/quiet hours 已有基础 |
| Phase 4 | 运营与可观测 | In Progress | 50% | admin status/deliveries 已有，告警体系待补 |

状态定义：`Not Started` / `In Progress` / `Blocked` / `Done`

---

## 2. 已完成事项（带证据）

### 2.1 统一通知中心骨架已落地

- 统一发布与治理服务已存在。
- 证据：
  - `server/src/services/notification-center/notification-center.service.ts`
  - `server/src/services/notification-center/notification-center.types.ts`

### 2.2 APNs Provider 基础能力已落地

- JWT 鉴权、HTTP/2 发送、失效 token 处理已实现。
- 证据：
  - `server/src/services/notification-center/notification-apns.handler.ts`
  - `server/.env.openim.example`（含 `NOTIFICATION_APNS_*`）

### 2.3 业务事件已统一接入 publish

- 社区互动：点赞/评论/关注。
- 聊天消息：私信/群聊。
- OpenIM webhook 事件桥接。
- 证据：
  - `server/src/routes/bff.routes.ts`
  - `server/src/routes/openim.routes.ts`
  - `server/src/services/squad.service.ts`

### 2.4 iOS token 注册链路已贯通

- App 启动申请权限，拿到 deviceToken 后发出事件。
- 登录态触发 token 上报服务端。
- 证据：
  - `mobile/ios/RaverMVP/RaverMVP/RaverMVPApp.swift`
  - `mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift`
  - `mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`

### 2.5 通知中心管理接口已存在

- 状态、投递明细、配置、模板管理接口可用。
- 证据：
  - `server/src/routes/notification-center.routes.ts`

### 2.6 APNs 真机配置与排障手册已固化

- 从 Apple Developer 配置到真机 E2E 验证命令已形成可复用 runbook。
- 证据：
  - `docs/APNS_REAL_DEVICE_SETUP_AND_E2E_RUNBOOK.md`

---

## 3. 当前阶段事项

### 3.1 P0：平台字段统一（Done）

- 问题：客户端上报 `ios_apns`，APNs 查询仅匹配 `ios/apns`。
- 影响：可能出现“token 有但推送不到”。
- 当前动作：已完成服务端归一化、APNs 平台兼容、历史归一脚本。
- 相关文件：
  - `mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift`
  - `server/src/services/notification-center/notification-center.service.ts`
  - `server/src/services/notification-center/notification-apns.handler.ts`

### 3.2 P0：登出 token 失活闭环（Done）

- 问题：已有 `deactivateDevicePushToken` 能力，但登出未调用。
- 影响：同设备切换账号可能串推。
- 当前动作：已完成 iOS 登出失活调用，并通过真机回归验证“登出后 APNs 不再命中”。
- 相关文件：
  - `mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift`
  - `mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`

### 3.3 P1：通知读取口径统一（In Progress）

- 问题：`/v1/notifications*`（旧）与 `/v1/notification-center/inbox*`（新）并存。
- 影响：体验与治理口径不一致。
- 当前动作：方案已明确，待执行映射/迁移。
- 相关文件：
  - `server/src/routes/bff.routes.ts`
  - `server/src/routes/notification-center.routes.ts`
  - `mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`

---

## 4. 阻塞与风险

| 编号 | 风险/阻塞 | 级别 | 影响 | 缓解动作 | 当前状态 |
|---|---|---|---|---|---|
| R-001 | APNs topic/environment 与包配置不一致 | High | 推送全量失败 | 用 admin/status + 真机联调校验 | Mitigated |
| R-002 | platform 历史脏数据导致漏推 | High | 部分用户收不到 | 增加兼容查询 + 一次性迁移脚本 | Closed |
| R-003 | 同步投递在峰值下放大接口延迟 | Medium | 业务接口不稳定 | Phase 2 引入 outbox + worker | Open |
| R-004 | 双轨通知接口导致前后端口径不一致 | Medium | badge 与列表不一致 | Phase 1 收口到 notification-center | Open |

---

## 5. 接下来 2 周执行计划（更新版）

## Week 1（P1）

1. 完成 `/v1/notifications*` 与 `notification-center/inbox*` 的兼容映射设计与实现。
2. 增加回归用例：通知列表、未读数、已读动作、badge 一致性。
3. 给 iOS 切换统一通知口径增加灰度开关与回滚步骤。

验收输出：
- 映射实现 PR
- iOS 联调记录
- 回滚开关说明

## Week 2（P2）

1. 设计并落地 outbox + worker 的最小可运行骨架（可先不全量切流）。
2. 明确 APNs 可恢复/不可恢复错误分类和重试策略。
3. 补充告警指标草案（失败率、队列积压、无效 token 比例）。

验收输出：
- 架构设计稿
- 数据表/状态机草案
- 观测指标清单

---

## 6. 变更日志（Chronological Log）

### 2026-04-23

- 新增统一实施方案文档：
  - `docs/APNS_UNIFIED_PUSH_SERVICE_IMPLEMENTATION_PLAN.md`
- 新增进度追踪文档（本文件）：
  - `docs/APNS_UNIFIED_PUSH_SERVICE_PROGRESS_TRACKER.md`
- 完成代码基线审查并确认关键差距：
  - `platform` 不一致
  - logout 未失活 token
  - 通知读取双轨
  - APNs 同步投递未异步化

### 2026-04-23（Phase 0 实施）

- 目标：
  - 修复平台标识不一致
  - 补齐登出 token 失活
  - 增加历史数据修正工具
- 实际完成：
  - 服务端 `registerDevicePushToken` 新增平台归一化：`ios/apns/ios_apns -> ios`，`android/fcm/android_fcm -> android`
  - 服务端 `deactivateDevicePushToken` 支持按平台别名集合批量失活（兼容历史值）
  - APNs handler token 查询新增 `ios_apns` 兼容
  - iOS 登录后上报平台统一改为 `ios`
  - iOS 登出时先调用 `deactivateDevicePushToken`，再执行 `logout`
  - 新增脚本 `notification:normalize-device-platforms`，用于历史 `device_push_tokens` 平台归一与去重合并
- 变更文件：
  - `server/src/services/notification-center/notification-center.service.ts`
  - `server/src/services/notification-center/notification-apns.handler.ts`
  - `server/src/scripts/notification-normalize-device-platforms.ts`
  - `server/package.json`
  - `mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift`
- 验证方式：
  - `pnpm --dir server build`
  - `pnpm --dir server prisma migrate deploy`
  - `pnpm --dir server notification:normalize-device-platforms`
  - `POST /v1/notification-center/admin/publish-test`（channels=`in_app,apns`）
  - `GET /v1/notification-center/admin/deliveries`
  - `GET /v1/notification-center/admin/status`
- 验证结果：
  - `pnpm --dir server build` 通过
  - 本地数据库迁移补齐 3 个未应用 migration（通知中心相关）
  - 归一脚本在无历史数据场景可安全退出（`no candidate rows found`）
  - 构造 3 条别名平台记录（`ios_apns/apns/ios`）后执行归一脚本，结果：`touchedGroups=1, updatedRows=1, deletedRows=2`
  - `/v1/notification-center/push-tokens` DELETE 以 `platform=ios` 成功失活归一后的 token（`updated=1`）
  - `publish-test` 结果：`in_app` 成功、`apns` 返回 `apns-disabled`（与当前配置一致）
  - `admin/deliveries` 可见同一 event 的 `in_app=sent`、`apns=failed(apns-disabled)` 记录
  - `admin/status` 显示 `apns.enabled=false`, `configured=false`
- 未解决问题：
  - 需真机验证 APNs 实际触达与多账号切换不串推
  - 当前环境未配置 APNs 凭证，无法完成真实 APNs 投递成功验证
- 下一步（可直接执行）：
  - 配置并启用 `NOTIFICATION_APNS_*`（Key ID / Team ID / Bundle ID / Private Key）
  - 在启用 APNs 后再次执行 `publish-test`，确认 `apns` 渠道从 `apns-disabled` 变为真实投递结果
  - 使用真机执行“同设备 A/B 账号切换 + 登出失活”回归用例并固化日志证据

### 2026-04-23（Phase 0 回归完成）

- 目标：
  - 完成真实 APNs 成功投递验证
  - 完成“登出失活 -> 不推送；重新登录 -> 可推送”闭环回归
- 实际完成：
  - `admin/status` 验证 APNs 已启用且配置完整：`enabled=true`, `configured=true`
  - `publish-test` 对 `uploadtester` 投递结果：`apns.success=true`, `token_sent=1`, `token_failed=0`
  - `admin/deliveries` 最新事件同时存在 `in_app=sent` 与 `apns=sent`
  - 真机回归通过：
    - 真机登出后再次发布：APNs 失败为 `no-active-device-token`
    - 真机重新登录后再次发布：APNs 恢复 `sent`
- 验证方式：
  - `POST /v1/notification-center/admin/publish-test`
  - `GET /v1/notification-center/admin/deliveries`
  - 真机手工回归（登录态切换）
- 验证结果：
  - Phase 0 目标达成，可标记完成
- 未解决问题：
  - 无 P0 阻塞
- 下一步（可直接执行）：
  - 进入 Phase 1：收口 `/v1/notifications*` 到 `notification-center` 统一读写口径

### 2026-04-23（交接文档增强）

- 目标：
  - 让 APNs 配置/验证流程可直接交接给新同学，无口头依赖
- 实际完成：
  - 新增真机 APNs 配置与排障手册，覆盖 Apple 后台、Xcode、`server/.env`、真机网络、E2E 命令与常见错误处理
  - 更新本进度文档阶段状态与“接下来两周计划”，从 P0 收尾切换到 P1/P2 主线
- 变更文件：
  - `docs/APNS_REAL_DEVICE_SETUP_AND_E2E_RUNBOOK.md`
  - `docs/APNS_UNIFIED_PUSH_SERVICE_PROGRESS_TRACKER.md`
- 验证方式：
  - 文档自查（步骤与实际键名一致）
  - 对照 `server/src/services/notification-center/notification-apns.handler.ts` 环境变量命名
- 验证结果：
  - 交接资料已具备“按文档即可复现”条件
- 未解决问题：
  - Phase 1 代码迁移尚未实施
- 下一步（可直接执行）：
  - 启动 `/v1/notifications*` 到 `notification-center` 的兼容映射开发与联调

### 2026-04-23（Phase 1 兼容映射落地）

- 目标：
  - 在不改 iOS 现有通知模型的前提下，把旧接口 `/v1/notifications*` 收口到统一通知中心数据源
- 实际完成：
  - `GET /v1/notifications` 改为读取 `notification_inbox`（`community_interaction`），并映射回旧客户端结构（`type/actor/text/target`）
  - `GET /v1/notifications/unread-count` 改为基于 `notification_inbox` 聚合未读统计（follow/like/comment/squad_invite）
  - `POST /v1/notifications/read` 改为优先按 inbox id 已读，同时支持按 `notificationType` 批量已读
  - 删除旧实现对 `follow/postLike/postComment/squadInvite + notification_read` 的读取依赖，避免双轨口径继续分叉
- 变更文件：
  - `server/src/routes/bff.routes.ts`
- 验证方式：
  - `cd server && pnpm build`
  - 静态检查确认旧通知聚合函数与旧 read 表读写逻辑已移除
  - 本地接口冒烟：
    - `GET /v1/notifications/unread-count`
    - `GET /v1/notifications?limit=5`
    - `POST /v1/notifications/read`（`notificationType=comment`）
- 验证结果：
  - `tsc` 编译通过
  - 旧通知接口已切换至 notification-center 数据源
  - 3 个接口均返回 200，响应结构与 iOS 现有模型兼容
- 未解决问题：
  - iOS 端目前仍调用旧路径（但已被后端兼容层兜底）
  - `notificationType` 批量已读的作用范围目前限定 `community_interaction` 分类
- 下一步（可直接执行）：
  - iOS `LiveSocialService` 切换到 `/v1/notification-center/inbox*` 直连
  - 增加端到端回归：通知列表、未读计数、单条已读、分类已读

### 2026-04-23（Phase 1 iOS 直连收口）

- 目标：
  - 将 iOS 通知读写从 `/v1/notifications*` 直切到 `/v1/notification-center/inbox*`
- 实际完成：
  - iOS `LiveSocialService` 已改为：
    - `fetchNotifications` -> `GET /v1/notification-center/inbox` + `GET /v1/notification-center/inbox/unread-count`
    - `fetchNotificationUnreadCount` -> `GET /v1/notification-center/inbox/unread-count`
    - `markNotificationRead` -> `POST /v1/notification-center/inbox/read`（`inboxId`）
    - `markNotificationsRead` -> `POST /v1/notification-center/inbox/read`（`notificationType`）
  - 新增 iOS 映射层：将 `notification-center` inbox item 映射为 `AppNotification`（兼容现有 UI 模型）
  - 服务端 `notification-center` 配套增强：
    - `/inbox/unread-count` 返回 `follows/likes/comments/squadInvites` 分项统计
    - `/inbox/read` 支持 `notificationType` 批量已读
- 变更文件：
  - `mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`
  - `server/src/routes/notification-center.routes.ts`
- 验证方式：
  - `cd server && pnpm build`
  - `GET /v1/notification-center/inbox/unread-count`
  - `POST /v1/notification-center/inbox/read`（`notificationType=comment`）
- 验证结果：
  - 服务端编译通过
  - 新接口返回结构满足 iOS 现有未读模型需求
- 未解决问题：
  - iOS 编译未在本轮命令行执行（建议在 Xcode 本地跑一轮）
- 下一步（可直接执行）：
  - 在真机端执行通知列表/已读交互回归

### 2026-04-23（Phase 1 自动化回归脚本）

- 目标：
  - 增加通知兼容接口自动回归，避免后续改动破坏旧接口契约
- 实际完成：
  - 新增脚本 `notification:compat:regression`：
    - 自动注册测试用户
    - 注入 `notification_inbox` 测试数据（follow/like/comment/squad_invite）
    - 校验旧接口：`/v1/notifications*`
    - 校验新接口：`/v1/notification-center/inbox/unread-count`、`/v1/notification-center/inbox/read`
    - 自动清理测试数据
- 变更文件：
  - `server/src/scripts/notification-compat-regression.ts`
  - `server/package.json`
- 验证方式：
  - `cd server && pnpm notification:compat:regression`
- 验证结果：
  - 脚本执行通过，关键断言全部通过
- 未解决问题：
  - 暂无
- 下一步（可直接执行）：
  - 将该脚本接入 CI（后续）

### 2026-04-23（Phase 2 outbox+worker 骨架）

- 目标：
  - 搭建异步派发骨架，避免 APNs 发送长期绑定在 publish 请求链路
- 实际完成：
  - `notificationCenterService.publish` 增加异步开关：
    - `NOTIFICATION_OUTBOX_ASYNC_ENABLED=true` 时，非 `in_app` 渠道写入 `notification_deliveries(status=queued)` 并返回 `queued-for-worker`
  - 新增 `dispatchQueuedEvents()`：批量拉取 queued event/delivery，调用现有 handler 派发并回写状态
  - 新增 outbox worker 调度器与单次运行脚本：
    - `startNotificationOutboxWorker()`
    - `pnpm notification:outbox:run`
  - 默认关闭，现网行为不变
- 变更文件：
  - `server/src/services/notification-center/notification-center.service.ts`
  - `server/src/services/notification-center/notification-outbox.scheduler.ts`
  - `server/src/services/notification-center/index.ts`
  - `server/src/index.ts`
  - `server/src/scripts/notification-outbox-run.ts`
  - `server/package.json`
  - `server/.env.openim.example`
- 验证方式：
  - `cd server && pnpm build`
  - `cd server && pnpm notification:outbox:run`
- 验证结果：
  - 编译通过
  - 在默认关闭配置下，worker run 报告 `enabled=false`（符合预期）
- 未解决问题：
  - 尚未开启 async 模式进行真实 queued->worker->delivered 链路压测
- 下一步（可直接执行）：
  - 在测试环境开启 `NOTIFICATION_OUTBOX_ASYNC_ENABLED=true` + `NOTIFICATION_OUTBOX_WORKER_ENABLED=true` 做灰度验证

### 2026-04-23（Phase 2 灰度验证脚本）

- 目标：
  - 提供可重复执行的 Outbox 异步灰度验收脚本，自动输出 PASS/FAIL
- 实际完成：
  - 新增脚本 `notification:outbox:gray-verify`，能力包括：
    - 管理员登录
    - 多轮 `publish-test`
    - 检查非 in_app 渠道是否返回 `queued-for-worker`
    - 轮询 `admin/deliveries` 校验 `queued -> sent/failed`
    - 校验 `admin/status` 队列卡住告警
    - 输出结构化报告 + 进程退出码（0/1）
- 变更文件：
  - `server/src/scripts/notification-outbox-gray-verify.ts`
  - `server/package.json`
  - `server/.env.openim.example`
  - `docs/DEV_PROXY_DB_RUNBOOK.md`
- 验证方式：
  - `cd server && pnpm notification:outbox:gray-verify`
- 验证结果：
  - 在当前环境得到预期失败：`apns` 渠道未返回 `queued-for-worker`，提示“async mode may be disabled”
  - 脚本能正确识别“未启用异步灰度”的状态，判定逻辑生效
- 未解决问题：
  - 需在测试环境开启 outbox async 后再跑一轮 PASS 验证
- 下一步（可直接执行）：
  - 按 runbook 开启 outbox async 配置并重启服务
  - 重新执行 `pnpm notification:outbox:gray-verify`，确认 `result=PASS`

---

## 7. 交接模板（每次推进后必须填）

复制以下模板追加到本文件末尾：

```md
### YYYY-MM-DD

- 目标：
- 实际完成：
- 变更文件：
  - path/a.ts
  - path/b.swift
- 验证方式：
- 验证结果：
- 未解决问题：
- 下一步（可直接执行）：
```

---

## 8. 接手人快速启动清单

1. 先读：
- `docs/APNS_UNIFIED_PUSH_SERVICE_IMPLEMENTATION_PLAN.md`
- `docs/APNS_UNIFIED_PUSH_SERVICE_PROGRESS_TRACKER.md`

2. 跑服务与检查接口：
- `cd server && pnpm build`
- 检查 `/v1/notification-center/admin/status`
- 检查 `/v1/notification-center/admin/deliveries`

3. 先做 P0 再做 P1：
- 平台标识统一
- logout token 失活
- APNs 端到端联调
