# Event 状态模型终局改造方案与执行清单

## 目标

将 `Event` 的状态模型从“数据库中混合持久化时间状态与业务状态”的旧模式，重构为以下终局模型：

- 持久化真值：
  - `isCancelled: boolean`
  - `visibility: visible | hidden`
- 非持久化返回字段：
  - `status: upcoming | ongoing | ended | cancelled`
- `status` 只作为服务端读时派生出来的展示态，不再写入数据库
- web / iOS / admin / recommendation / check-in / share-link 全部统一消费服务端派生状态

---

## 为什么这是终局最优解

### 1. 时间状态不应该持久化

`upcoming / ongoing / ended` 本质上是：

- 当前时间
- `startDate`
- `endDate`
- `timeZone`

共同计算出来的结果。

它不是人工维护真值，因此不应该写死在数据库里。

### 2. 取消状态应该单独持久化

“活动是否取消”是明确业务真值，应独立表达为：

- `isCancelled: boolean`

### 3. 可见性应该与业务状态解耦

`hidden` 不是时间状态，也不是取消状态，而是内容可见性控制。

它应独立表达为：

- `visibility: visible | hidden`

### 4. 读写职责彻底分离

最终职责应为：

- 数据库负责保存事实真值
- 服务端负责统一派生展示状态
- 前端和客户端只消费展示结果，不再各自补一套 fallback 规则

---

## 终局模型定义

### 持久化层

数据库最终应只保存：

- `isCancelled: boolean`
- `visibility: visible | hidden`

数据库不再保存：

- `upcoming`
- `ongoing`
- `ended`
- `active`
- `cancelled` 作为 `status` 文本
- `hidden` 作为 `status` 文本

### 返回层

服务端对外 API 返回：

- `status: upcoming | ongoing | ended | cancelled`
- `isCancelled: boolean`
- `visibility: visible | hidden`

其中：

1. 若 `isCancelled === true`，则 `status = cancelled`
2. 否则若当前时间 < `startDate`，则 `status = upcoming`
3. 否则若当前时间 > `endDate`，则 `status = ended`
4. 否则 `status = ongoing`

### 写入层

所有 event 创建、编辑、审核、导入、脚本写库只允许写：

- `isCancelled`
- `visibility`

不再允许任何链路写：

- `upcoming`
- `ongoing`
- `ended`
- `active`

---

## 当前阶段判断

当前仓库已经进入“终局切换收尾阶段”，不是从零开始。

### 已完成的终局推进成果

- [x] 已停止把 `upcoming / ongoing / ended` 作为长期真值写回数据库
- [x] 已建立统一的服务端状态派生 helper
- [x] web / iOS 主要读取链路已基本改为信任派生 `status`
- [x] 当前终局模型骨架已落地：
  - 持久化真值：`isCancelled` / `visibility`
  - 返回展示态：`status = upcoming / ongoing / ended / cancelled`
  - 旧数据库 `status` 与过渡返回 `persistedStatus` 已移除

### 当前仍未完全收尾的原因

当前模型仍存在以下问题：

- [x] `cancelled` 已不再通过文本 `status` 持久化
- [x] `hidden` 已不再与业务状态共用一个 `status` 字段
- [x] `persistedStatus` 已从对外模型移除
- [x] helper / 主线文档术语已完成收口

---

## 战略调整原则

从现在开始，这个任务不再以“把 `status(active/cancelled/hidden)` 做得更完整”为最终目标。

而是改为：

### 主目标

- 将当前过渡模型继续推进到终局模型：
  - `isCancelled`
  - `visibility`
  - 派生 `status`

### 次目标

- 保证新模型在 web / iOS / admin / 历史数据迁移后保持一致

### 执行原则

- 直接完成数据库迁移
- 直接切换所有读写链路到新真值字段
- 直接清理旧字段与旧兼容入口

说明：

- 当前项目不再保留“兼容上线 / 双读过渡 / 旧客户端兜底”作为主线要求
- 由于当前没有线上用户，event 状态模型按一次性全量迁移方案推进

---

## 分阶段路线图

## Phase 0. 方案冻结

### 目标

冻结终局模型，避免后续继续围绕过渡模型打补丁。

### 待完成

- [x] 明确终局模型为：
  - `isCancelled: boolean`
  - `visibility: visible | hidden`
  - `status` 仅作为返回派生字段
- [x] 明确 `visibility` 的默认值、枚举来源与 Prisma 表达方式
- [x] 明确旧 `status=hidden` 如何迁移到 `visibility=hidden`
- [x] 明确旧 `status=cancelled` 如何迁移到 `isCancelled=true`
- [x] 明确迁移期 API 是否同时返回：
  - `status`
  - `isCancelled`
  - `visibility`
  - `persistedStatus`（该过渡字段现已移除）

---

## Phase 1. 数据模型引入新真值字段

### 目标

在数据库层完成终局真值字段落地，并直接淘汰旧状态字段。

### Prisma / DB

- [x] 在 `Event` 模型新增 `isCancelled Boolean @default(false)`
- [x] 在 `Event` 模型新增 `visibility EventVisibility @default(visible)`
- [x] 明确 `visibility` 是否改成 enum
- [x] 生成 migration
- [x] 数据迁移：
  - [x] 旧 `status in ('cancelled', 'canceled')` -> `isCancelled = true`
  - [x] 旧 `status = 'hidden'` -> `visibility = 'hidden'`
  - [x] 其余 -> `isCancelled = false` 且 `visibility = 'visible'`
- [x] 删除旧 `status` 字段

### 风险控制

- [x] 明确 migration 是否可重复执行
  - Prisma `migrate deploy` 层面可重复执行：已应用 migration 会被 Prisma migration history 跳过
  - SQL 文件本体不是设计成“脱离 Prisma 单独反复执行”的幂等脚本，必须按 migration 序列线性应用
- [x] 明确全量迁移执行顺序
  - 先执行 `20260607190000_normalize_event_persisted_status`
  - 再执行 `20260607233000_add_event_cancellation_and_visibility_fields`
  - 最后执行 `20260607235900_drop_event_status_column`
  - 实际执行入口保持为 `pnpm phase6:cutover:db` / `pnpm prisma migrate deploy`

---

## Phase 2. 服务端读路径切换到新真值字段

### 目标

所有服务端读路径优先基于：

- `isCancelled`
- `visibility`

来计算返回结果，而不是基于过渡 `status(active/cancelled/hidden)`。

### 状态派生 helper

- [x] 重写统一 helper，使其签名转为基于：
  - `startDate`
  - `endDate`
  - `timeZone`
  - `isCancelled`
- [x] `visibility` 不参与时间态推导，只参与可见性过滤
- [x] 统一 helper 已只基于新真值字段工作
- [x] 旧过渡命名与残余 legacy 术语继续收口
  - event 主线 helper / guardrail 术语已统一到 `EventTruth` 语义，剩余主要是迁移说明性质的历史文档表述

### 查询过滤

- [x] `status=cancelled` -> `isCancelled = true`
- [x] `status=upcoming` -> `isCancelled = false` 且未来时间
- [x] `status=ongoing` -> `isCancelled = false` 且当前进行中
- [x] `status=ended` -> `isCancelled = false` 且已结束
- [x] `visibility=hidden` 单独走内容可见性过滤

### 需要继续核对的服务端接口

- [x] Event list API 已开始真正读取新字段
- [x] Event detail API 已开始真正读取新字段
- [x] Admin event catalog API 已开始真正读取新字段
- [x] Event recommendations API 已开始真正读取新字段
- [x] DJ related events API 已开始真正读取新字段
- [x] Check-in event status related API 已开始真正读取新字段
- [x] Share link / deep link 相关 event payload 已核对，不依赖旧持久化 `status`
- [x] Notification / runtime event payload 已核对，当前不依赖旧持久化 `status`

---

## Phase 3. 服务端写路径切换到新真值字段

### 目标

所有写库链路彻底停止写旧 `status` 真值。

### 事件创建 / 编辑 controller

- [x] create event 改为写：
  - `isCancelled`
  - `visibility`
- [x] update event 改为写：
  - `isCancelled`
  - `visibility`
- [x] 输入校验明确拒绝：
  - `upcoming`
  - `ongoing`
  - `ended`
  - `active`
- [x] 旧 event 状态兼容写入入口已清理，不再把旧语义写回任何综合 `status`

### 内容审核 / submission

- [x] `NormalizedEventSubmissionWriteInput` 改为持有：
  - `isCancelled`
  - `visibility`
- [x] 审核通过落库改为写新字段
- [x] submission comparable state 改为比较：
  - `isCancelled`
  - `visibility`
  - 时间字段
- [x] submission diff UI 改为：
  - 取消状态 diff
  - 可见性 diff
  - 时间字段 diff
  - event 审核页语义 diff 已覆盖上述主线字段
- [x] 历史 submission 重放 / 重试确保兼容
  - event submission 归一化入口已补 legacy `payload.status` -> `EventTruth` fallback，仅在未显式传 `isCancelled / visibility` 时生效
  - 该兼容已纳入 `server/src/scripts/event-status-guardrails.ts` 验证，覆盖 hidden / cancelled / explicit truth override / existing truth preserve

### 历史脚本 / 导入脚本

- [x] 所有导入脚本改为只写：
  - `isCancelled`
  - `visibility`
- [x] 历史脚本若保留，需标明“旧逻辑只读参考，不可再用于生产写库”
  - legacy event status fallback 已在 helper、submission replay 入口、regression script 与历史 migration 文件顶部显式标注为兼容/历史参考，不作为新生产写入范式

---

## Phase 4. API contract 与客户端模型正式切换

### 目标

contract 语义与终局模型一致。

### API contract

- [x] Event mutation contract 改为显式传：
  - `isCancelled`
  - `visibility`
- [x] Event response contract 明确返回：
  - `status`
  - `isCancelled`
  - `visibility`
- [x] `persistedStatus` 已作为历史过渡字段清理完成
- [x] `persistedStatus` 已从所有客户端链路中移除

### web

- [x] `EventStudioDraft` 已切换到：
  - `isCancelled`
  - `visibility`
- [x] Event Studio UI：
  - [x] 只编辑取消态
  - [x] 可编辑可见性
  - [x] 继续只读展示派生 `status`
- [x] 公共 `Event` 类型切换到终局字段
- [x] admin catalog / card / detail / search / bindings 不再依赖 `persistedStatus`

### iOS

- [x] `WebEvent` 增加：
  - `isCancelled`
  - `visibility`
- [x] `persistedStatus` 已完成移除
- [x] upload / admin bridge mutation 改为传新字段
- [x] 所有本地 fallback 判断优先走：
  - `isCancelled`
  - 否则时间推导

---

## Phase 5. 废弃旧持久化 status 字段

### 目标

彻底完成从旧持久化 `status` 到终局模型的迁移。

### 待完成

- [x] 所有读路径不再依赖旧 `status`
  - event 主读链路已不再接受 `active / hidden` 作为 event 状态过滤语义，旧 `status` 仅保留在 migration guardrail 映射说明中
- [x] 所有写路径不再写旧 `status`
- [x] 所有脚本不再写旧 `status`
- [x] 删除 `persistedStatus` 过渡返回字段
- [x] Prisma schema 废弃或移除旧 `status`
- [x] 生成最终清理 migration

---

## 当前代码基线对应关系

### 当前真实字段模型

- `isCancelled`（数据库层）：
  - `true`
  - `false`
- `visibility`（数据库层）：
  - `visible`
  - `hidden`
- `status`（返回层）：
  - `upcoming`
  - `ongoing`
  - `ended`
  - `cancelled`

### 这意味着什么

当前代码已经完成了：

- “时间态不再作为主要真值写库”
- “取消态与可见性已经从旧 `status` 中拆出并独立持久化”

但还没有完成：

- “所有 event 状态相关兼容命名、文档、脚本审计与测试验证完全收口”

---

## 接下来最应该优先做什么

这是当前最重要的战略顺序。

### 优先级 P0

- [x] 在 Prisma schema 中正式新增 `isCancelled` 与 `visibility`
- [x] 设计并落地 migration
- [x] 让服务端 helper 完成向新真值字段的终局切换

### 优先级 P1

- [x] 改 controller / submission / import 写路径，优先写新字段
- [x] 改 API contract，让 mutation 明确传 `isCancelled / visibility`

### 优先级 P2

- [x] 改 web Event Studio 与 iOS upload/admin bridge，切到新字段
- [x] 让 web / iOS 响应模型直接消费 `isCancelled / visibility`

### 优先级 P3

- [x] 清理 `persistedStatus`
- [x] 清理旧数据库 `status`
- [x] 完成最终迁移收口
  - Prisma schema、migration、server/helper、submission replay、contract fixtures、web/iOS 消费与 guardrails 已统一到终局模型

---

## 测试与验证

### 数据层

- [x] migration 后旧 event 数据：
  - [x] `cancelled` 正确迁移到 `isCancelled=true`
  - [x] `hidden` 正确迁移到 `visibility=hidden`
  - [x] 其他状态正确迁移到默认值
  - 以上映射规则已纳入 `server/src/scripts/event-status-guardrails.ts`

### 服务端

- [x] guardrail 脚本覆盖新的状态派生 helper
- [x] 覆盖边界：
  - [x] 开始前 1 秒
  - [x] 开始时刻
  - [x] 结束时刻
  - [x] 结束后 1 秒
- [x] 覆盖取消态优先级
- [x] 覆盖 hidden 可见性过滤
- [x] 覆盖不同时区与跨天 event
- [x] 覆盖推荐与筛选分桶

### web

- [x] event card 状态展示
- [x] event detail 状态展示
- [x] admin event catalog 状态统计与筛选
- [x] event studio 新字段提交 payload 校验
- [x] visibility 编辑与展示

### iOS

- [x] 推荐列表 status bucket 正常
- [x] event detail 与 DJ 关联 event 状态展示一致
- [x] mutation bridge 不再回写旧 `status`
- [x] 新字段终局解码方案

当前已通过 parity 覆盖：

- iOS mutation payload 不再编码旧 `status`
- 新服务端返回 `status + isCancelled + visibility` 时，展示态与 web/iOS 解析一致

---

## 部署策略

### 全量迁移顺序

1. 执行数据库 migration 与历史数据迁移
2. 发布服务端新读写链路
3. 发布 web / iOS 新 contract 消费
4. 校验所有 event 展示与筛选链路

---

## 明确不在本次任务中的内容

- `EventPerformance.status`
- 各类导入 job 的 `pending / running / failed / cancelled`
- notification、submission、review、media asset 等其他模型的状态字段

本任务只聚焦 `Event` 核心状态模型。

---

## 验收标准

- [x] 数据库中不再持久化 `upcoming / ongoing / ended / active / cancelled / hidden` 作为 event 综合状态真值
- [x] `isCancelled` 是唯一取消真值来源
- [x] `visibility` 是唯一可见性真值来源
- [x] `status` 完全由服务端派生
- [x] web 与 iOS 对同一 event 的状态展示完全一致
- [x] event 创建、编辑、审核、导入链路不再写旧综合 `status`
- [x] share-link / deeplink / recommendation / check-in / DJ related events 逻辑全部对齐
- [x] 旧 `persistedStatus` 与旧数据库 `status` 最终被移除

---

## 关键参考文件

### 数据模型

- `/Users/blackie/Projects/raver/server/prisma/schema.prisma`

### 服务端

- `/Users/blackie/Projects/raver/server/src/utils/event-status.ts`
- `/Users/blackie/Projects/raver/server/src/controllers/event.controller.ts`
- `/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts`
- `/Users/blackie/Projects/raver/server/src/services/content-submission-event.service.ts`

### web

- `/Users/blackie/Projects/raver/web/src/lib/api/event.ts`
- `/Users/blackie/Projects/raver/web/src/features/admin-content/event-studio/mapper.ts`
- `/Users/blackie/Projects/raver/web/src/features/admin-content/event-studio/types.ts`
- `/Users/blackie/Projects/raver/web/src/components/admin/EventStudioForm.tsx`
- `/Users/blackie/Projects/raver/web/src/components/EventCard.tsx`
- `/Users/blackie/Projects/raver/web/src/components/admin/EventCatalogPageClient.tsx`
- `/Users/blackie/Projects/raver/web/src/app/events/page.tsx`
- `/Users/blackie/Projects/raver/web/src/app/events/[id]/page.tsx`

### iOS

- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/EventAdminContractBridge.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Recommend/ViewModels/RecommendEventsViewModel.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/ViewModels/EventsModuleViewModel.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventPresentationSupport.swift`

---

## 备注

这份文档从现在开始以“终局模型”为基准，不再以当前过渡模型为终点。

后续每完成一项，请优先判断它是在：

- 缓解当前过渡风险
还是
- 真正推进终局模型

避免继续围绕 `persistedStatus` 或旧 `status(active/cancelled/hidden)` 做长期性增强。
