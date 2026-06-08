# Event 地址模型终局改造方案与执行清单

## 目标

将 `Event` 的地址模型从“顶层自由文本地址 + 手填地址 + 地图点地址并存”的旧模式，重构为以下终局模型：

- 删除顶层 `venueName`
- 删除顶层 `venueAddress`
- `manualLocation` 只承担“活动地址”真值：
  - `detailAddressI18n`
  - `formattedAddressI18n`
- `locationPoint` 同时承担：
  - 地图定位真值
  - 地图 POI 元数据
  - 场地字段 / map pin 稳定展示真值
- 新增 `locationPoint.manualSetAddressI18n`
- web / iOS / admin / share / widget / check-in / search 全部统一切换到新的地址职责模型

---

## 战略执行原则

### 1. 维持主线执行，不发散

- [x] 本次改造严格围绕地址模型主线推进：
  - 数据模型
  - contract
  - server 读写
  - web
  - iOS
  - migration
  - 验证
- [x] 改造过程中若发现额外问题：
  - 若是主线阻塞项，立即纳入当前阶段处理
  - 若不是主线阻塞项，只记录到本文档或后续清单，等主线完成后再继续处理
- [x] 不因为沿途发现的次要 UI、历史命名、顺手优化点而偏离主线

### 2. 不做旧版本兼容负担，直接全量切换

- [x] 当前线上无真实用户，本次改造默认允许全量切换到最新地址模型
- [x] 不以“兼容旧字段 / 双写 / 双读 / 长期 fallback”作为主线目标
- [x] 允许在数据库、contract、server、web、iOS 层直接删除旧字段并切换到新结构
- [x] fallback 只允许保留在当前阶段必要的过渡编译修复中
- [x] 一旦主线对应层完成切换，应继续清理该层残余 fallback，而不是长期保留

---

## 当前确认的终局语义

- [x] `venueName` 不再保留
- [x] `venueAddress` 不再保留
- [x] “活动地址”与“场地字段 / map pin 文案”是两条不同展示线
- [x] `manualLocation` 只承担“活动地址”真值
- [x] `locationPoint` 只承担“地图定位真值 + 场地展示真值”
- [x] `locationPoint.nameI18n` 允许保留 POI 名称
- [x] `locationPoint.nameI18n` 不再作为前台主展示地址
- [x] 新增 `locationPoint.manualSetAddressI18n`
- [x] `pickedPlaceName` / `pickedMapAddress` 仅保留为编辑态辅助字段

---

## 终局字段职责表

### 顶层保留字段

- `city`
  - 规范化城市文本
  - 用于生成 `manualLocation.formattedAddressI18n`
- `country`
  - 规范化国家文本
  - 用于生成 `manualLocation.formattedAddressI18n`
- `latitude` / `longitude`
  - 顶层兼容坐标
  - 可保留用于查询、兼容和部分只读场景
  - 地图主定位真值仍优先使用 `locationPoint.location`
- `manualLocation`
  - 活动地址真值
- `locationPoint`
  - 地图定位真值
  - 场地字段 / map pin 展示真值

### 删除字段

- `venueName`
  - 删除
  - 不再编辑
  - 不再入库
  - 不再返回
  - 不再参与展示 / 搜索 / 分享 / widget / check-in / 卡片文案
- `venueAddress`
  - 删除
  - 不再编辑
  - 不再入库
  - 不再返回
  - 不再参与展示 / 搜索 / 分享 / widget / check-in / 卡片文案

### `manualLocation` 职责

- `manualLocation.detailAddressI18n`
  - 用户手填的详细地址原文
  - 是“活动地址”生成的基础输入真值
- `manualLocation.formattedAddressI18n`
  - 对外统一展示的活动地址真值
  - 必须由 `detailAddress + city + country` 稳定生成
  - 不再由客户端临时自由拼接

### `locationPoint` 职责

- `locationPoint.provider`
  - 地图 provider 元数据
- `locationPoint.providerPlaceId` / `poiId` / `adcode` / `providerMeta`
  - 地图 POI 与 provider 元数据
- `locationPoint.location`
  - 地图 pin 位置真值
- `locationPoint.nameI18n`
  - POI 名称元数据
  - 允许保留
  - 不作为前台主展示地址
- `locationPoint.addressI18n`
  - provider 原始地址文本
  - 底层参考数据
- `locationPoint.formattedAddressI18n`
  - provider 原始格式化地址
  - 当 `manualSetAddressI18n` 为空时，作为场地展示回退值
- `locationPoint.manualSetAddressI18n`
  - 新终局字段
  - 代表用户手动指定的“场地字段 / map pin / 场地卡片”展示真值
  - 这是有 `locationPoint` 时的第一展示来源
- `locationPoint.city` / `district` / `province` / `countryCode`
  - 地图点区域元数据
  - 仅用于结构化地点信息，不参与前台主展示文案拼接

### 草稿态辅助字段

- `pickedPlaceName`
  - 地图选点时的临时 POI 名称
  - 仅服务编辑态 UI
  - 不作为最终持久化展示真值
- `pickedMapAddress`
  - 地图选点时的临时地址文案
  - 仅服务编辑态 UI
  - 不作为最终持久化展示真值

---

## 终局展示规则

### 1. 活动地址

- “活动地址”字段统一只展示 `manualLocation.formattedAddressI18n`
- `manualLocation.formattedAddressI18n` 必须由 `detailAddress + city + country` 稳定生成
- web / iOS / admin / share / search 不再各自自由拼接活动地址

### 2. 场地字段 / 场地卡片 / map pin 展示文案

- 若存在 `locationPoint`
  - 先使用 `locationPoint.manualSetAddressI18n`
  - 若为空，再使用 `locationPoint.formattedAddressI18n`
  - 到此结束
  - 不再 fallback 到 `manualLocation`
  - 不再 fallback 到 `city` / `country`
  - 不再 fallback 到旧 `venueName` / `venueAddress`
- 若不存在 `locationPoint`
  - 使用 `manualLocation.formattedAddressI18n`
  - 若为空，再使用 `manualLocation.detailAddressI18n`

### 3. 地图定位

- 地图定位优先使用 `locationPoint.location`
- 无 `locationPoint.location` 时，才允许回退到顶层 `latitude` / `longitude`

---

## 终局保存规则

- 用户编辑 `detailAddress` / `city` / `country` 时：
  - 统一更新 `manualLocation.detailAddressI18n`
  - 统一重新生成 `manualLocation.formattedAddressI18n`
- 用户地图选点时：
  - 保存 provider / place id / poi id / adcode / providerMeta
  - 保存 `locationPoint.location`
  - 保存 `locationPoint.nameI18n`
  - 保存 `locationPoint.addressI18n`
  - 保存 `locationPoint.formattedAddressI18n`
- 若当前 event 绑定了 `locationPoint`
  - 将用户当前最终确认的场地展示文案写入 `locationPoint.manualSetAddressI18n`
  - 当前阶段默认由编辑态 `detailAddress` 同步映射到 `locationPoint.manualSetAddressI18n`
- 任何保存链路都不得重新引入 `venueName` / `venueAddress`

---

## 分阶段执行清单

## Phase 0. 方案冻结

### 目标

冻结地址终局模型，避免继续围绕 `venueName` / `venueAddress` 打补丁。

### 待完成

- [x] 明确删除顶层 `venueName`
- [x] 明确删除顶层 `venueAddress`
- [x] 明确 `manualLocation` 仅承担“活动地址”真值
- [x] 明确 `locationPoint` 仅承担“地图定位真值 + 场地展示真值”
- [x] 明确新增 `locationPoint.manualSetAddressI18n`
- [x] 明确 `locationPoint.nameI18n` 仅保留 POI 名称元数据，不作为前台主展示地址
- [x] 明确草稿态 `pickedPlaceName` / `pickedMapAddress` 仅留在编辑态
- [x] 明确“活动地址”与“场地字段 / map pin 文案”是两套不同展示线

## Phase 1. 数据模型与 Contract

### 目标

在数据库、mutation contract、客户端数据模型层统一新地址结构。

### Prisma / DB

- [x] 从 `Event` 模型删除 `venueName`
- [x] 从 `Event` 模型删除 `venueAddress`
- [x] 为 `locationPoint` schema 增加 `manualSetAddressI18n`
- [x] 生成 Prisma migration
- [x] 明确历史数据迁移写法
- [x] 删除相关索引、只读脚本和 schema 注释中的旧字段引用
  - Prisma schema 与活跃主线脚本已不再依赖 `venueName` / `venueAddress`
  - 剩余旧字段引用仅存在于：
    - 历史 migration 文件
    - guardrail 拒绝性测试
    - 非当前主线的 legacy/实验性端代码
  - 以上不再构成最新地址模型主线依赖

### Event Mutation / API Contract

- [x] 更新 `docs/EVENT_MUTATION_SPEC.md`
- [x] 从 canonical location contract 中删除 `venueName`
- [x] 从 canonical location contract 中删除 `venueAddress`
- [x] 为 `EventLocationPoint` 增加 `manualSetAddressI18n`
- [x] 明确 `manualLocation.formattedAddressI18n` 的生成规则是服务端 / 共享 mapper 强约束
- [x] 明确 `locationPoint.manualSetAddressI18n` 的保存规则
- [x] 更新 golden fixtures

### 相关模型 / bridge / schema

- [x] web `Event` API 类型删除 `venueName` / `venueAddress`
- [x] web `EventStudioDraft` 删除 `venueName` / `venueAddress`
- [x] iOS `WebEvent` 删除 `venueName` / `venueAddress`
- [x] iOS `WebEventLocationPoint` 增加 `manualSetAddressI18n`
- [x] iOS `EventAdminContractBridge` 对齐新结构
- [x] Mock / fixture / bridge / generator 产物对齐新结构
- [x] `EventOverview / EventDetail` contract 正式补齐 `activityAddress / venueDisplayAddress`

## Phase 2. Server 读写链路统一

### 目标

让服务端成为地址语义的唯一权威，不再让 web / iOS 自己维护地址拼接规则。

### 写入链路

- [x] `event.controller` create / update 删除 `venueName` / `venueAddress`
- [x] content submission event service 删除 `venueName` / `venueAddress`
- [x] event admin contract guardrail 更新字段白名单与 clear 规则
- [x] 所有 event create / update / review / replay / import / seed / benchmark / repair 脚本删除旧字段写入
- [x] 服务端统一生成 `manualLocation.formattedAddressI18n`
- [x] 服务端统一写入 `locationPoint.manualSetAddressI18n`

### 读路径与派生 helper

- [x] 新增统一 helper：
  - [x] `activityAddress`
  - [x] `venueDisplayAddress`
- [x] `activityAddress` 规则：
  - [x] 仅取 `manualLocation.formattedAddressI18n`
- [x] `venueDisplayAddress` 规则：
  - [x] 有 `locationPoint` 时：`manualSetAddressI18n -> formattedAddressI18n`
  - [x] 无 `locationPoint` 时：`manualLocation.formattedAddressI18n -> detailAddressI18n`
- [x] 删除现有所有混合 `venueName / venueAddress / city / country / manualLocation / locationPoint` 乱拼逻辑

### BFF / 查询 / Payload

- [x] `bff.routes.ts` 删除旧 `resolveEventAddressText` 中对 `venueName` / `venueAddress` 的依赖
- [x] `bff.web.routes.ts` 删除 `venueName` / `venueAddress` 的 select 和 payload 输出
- [x] event list payload 加入统一地址字段或统一 helper 结果
- [x] event detail payload 加入统一地址字段或统一 helper 结果
- [x] admin catalog / admin detail / review payload 对齐
- [x] recommendations / related events / DJ event payload 对齐
- [x] share-link / deep-link payload 对齐
- [x] notification / runtime payload 对齐

### 搜索 / 检索 / 外围能力

- [x] global search 删除对 `venueName` 的搜索与评分依赖
- [x] event 搜索改为搜索：
  - [x] `manualLocation.detailAddressI18n`
  - [x] `manualLocation.formattedAddressI18n`
  - [x] `locationPoint.manualSetAddressI18n`
  - [x] `locationPoint.formattedAddressI18n`
  - [x] `locationPoint.nameI18n`
- [x] check-in / offline activity / projection / snapshot / poster / share-poster 删除旧字段依赖
- [x] 所有 event snapshot / diff / entity-change 逻辑对齐新字段

## Phase 3. Web 端改造

### 目标

web admin 与 public web 全部切到新地址模型。

### Event Studio / Admin 编辑

- [x] 删除基本信息页中的 `venueName` 输入框
- [x] 删除基本信息页中的 `venueAddress` 输入框
- [x] 保留 `detailAddress` 作为用户主要地址编辑输入
- [x] `pickedPlaceName` / `pickedMapAddress` 仅保留为地图浮层辅助态
- [x] 提交 mapper 删除 `venueName` / `venueAddress`
- [x] 提交 mapper 为 `locationPoint` 写入 `manualSetAddressI18n`
- [x] 草稿 hydrate / reset / diff / validation / dirty compare 全部删除旧字段
- [x] 地图选点回填逻辑对齐 provider 元数据、location、point formatted address、manualSetAddressI18n

### Public Web 展示

- [x] event list 页面不再展示 `venueName`
- [x] event card 不再展示 `venueName`
- [x] event detail 页面拆清：
  - [x] “活动地址”只走 `manualLocation.formattedAddressI18n`
  - [x] “场地 / 地图点展示”走 `venueDisplayAddress`
- [x] 其他 event 相关卡片、关联模块、绑定模块、目录模块统一清理旧字段

### Web 类型 / Client Helper

- [x] `web/src/lib/api/event.ts` 删除旧字段
- [x] 统一 web 端地址显示 helper，避免页面组件各自写 fallback
- [x] admin / public / search / review / relation 卡片全部改用统一 helper

## Phase 4. iOS 端改造

### 目标

iOS event 详情页、编辑页、上传流、分享卡片、聊天卡片、widget 与各种 event 摘要全部切到新地址模型。

### 数据模型

- [x] `WebEvent` 删除 `venueName`
- [x] `WebEvent` 删除 `venueAddress`
- [x] `WebEventLocationPoint` 增加 `manualSetAddressI18n`
- [x] `MockWebFeatureService` / contract bridge / fixtures 同步对齐

### Event 详情页

- [x] “活动地址”字段固定展示 `manualLocation.formattedAddressI18n`
- [x] 场地字段固定展示 `venueDisplayAddress`
- [x] map sheet `Marker(...)` 文案固定展示 `venueDisplayAddress`
- [x] map sheet 底部 `venueDisplayText` / `summaryLocation` 对齐新规则
- [x] open map query 对齐新规则
- [x] copy venue text 对齐新规则
- [x] share card payload 不再依赖旧 `venueName`

### 详情页展示规则细化

- [x] 若有 `locationPoint`
  - [x] 使用 `locationPoint.manualSetAddressI18n`
  - [x] 若为空使用 `locationPoint.formattedAddressI18n`
  - [x] 到此结束
- [x] 若无 `locationPoint`
  - [x] 使用 `manualLocation.formattedAddressI18n`
  - [x] 若为空使用 `manualLocation.detailAddressI18n`
- [x] “活动地址”与“场地 / map pin 文案”两条线分离实现

### 编辑页 / Upload Flow

- [x] 删除 `venueName` 输入框
- [x] 删除 `venueAddress` 输入框
- [x] 进入编辑页时不再 hydrate 旧字段
- [x] 地图选点结果保存 `locationPoint.nameI18n`
- [x] 地图选点结果保存 `locationPoint.formattedAddressI18n`
- [x] 由当前 `detailAddress` 同步生成 `locationPoint.manualSetAddressI18n`
- [x] upload draft / mapper / flow view / view model 全部删除旧字段
- [x] EventAdminContractBridge mutation payload 对齐新地址 contract

### iOS 外围能力

- [x] 聊天 event card 不再依赖 `payload.venueName`
- [x] profile event summary 不再依赖 `event.venueName`
- [x] countdown widget / selectable events sync / widget subtitle 对齐新地址字段
- [x] 其他 event 摘要、route、share、offline activity 入口全部核对

## Phase 5. Migration 与历史数据修复

### 目标

完成一次性全量迁移，不保留旧地址模型兼容逻辑。

### 数据迁移

- [x] 扫描所有 event 历史数据中的 `venueName` / `venueAddress` / `manualLocation` / `locationPoint`
- [x] 为存在 `manualLocation` 的记录补齐稳定的 `formattedAddressI18n`
- [x] 为存在 `locationPoint` 的记录补齐 `manualSetAddressI18n`
- [x] 若历史记录只有 `venueAddress` 没有 `manualLocation`，迁移到 `manualLocation.detailAddressI18n`
- [x] 若历史记录只有 `venueName`，只在需要时迁移入 `locationPoint.nameI18n` 或审计日志
- [x] 删除旧列后做一次数据完整性巡检

### 脚本 / 文档 / Fixture 清理

- [x] 更新 import / seed / backfill / regression 脚本
- [x] 更新数据库设计文档与 README
- [x] 更新 iOS / web parity 文档
- [x] 更新手工测试 checklist 与 golden payload

## Phase 6. 验证与验收

### Server

- [x] contract guardrail 覆盖新地址字段
- [x] 独立 `phase6-event-address-smoke` 在稳定 server 进程下跑通
  - 运行方式：`pnpm --dir /Users/blackie/Projects/raver/server build` 后使用 `PORT=3901 node dist/index.js`
  - 已实际验证通过：
    - `event detail`
    - `event list`
    - `admin catalog summary`
    - `event global search`
    - `share-links resolve`
    - `locationPoint -> manualLocation fallback`
- [x] 独立 `event-address-search-smoke` 已补充并实际通过
  - 已确认 event 搜索候选集与打分层都覆盖新地址字段：
    - `manualLocation.detailAddressI18n`
    - `manualLocation.formattedAddressI18n`
    - `locationPoint.manualSetAddressI18n`
    - `locationPoint.formattedAddressI18n`
    - `locationPoint.nameI18n`
- [x] `event-incremental-sync-regression` 已恢复到当前 schedule foundation，并完成 server 写链路主线回归
  - 已修正脚本 seed event 缺失 `weeks/eventDays` 的问题，避免新 schedule 基础模型下的假失败
  - 在稳定连接配置下已实际覆盖通过：
    - direct canonical update path
    - full payload incremental fill
    - full payload exact align
    - multi-week mixed update
    - create submission idempotency
    - legacy status submission replay compatibility
    - address normalization replay
    - create payload incremental fill
    - auto approval resume
    - phase-b failure recovery
- [x] create / update / review / replay / import / search / detail / list / share payload 测试通过
- [x] 新 helper 对旧混合拼接逻辑完成替换

### Web

- [x] Event Studio 创建 event 地址提交流程通过
- [x] Event Studio 编辑 event 地址提交流程通过
- [x] event list / card / detail / search 地址展示符合终局规则
- [x] admin event catalog / review / related modules 地址展示符合终局规则

### iOS

- [x] event detail：
  - [x] 活动地址正确
  - [x] 场地字段正确
  - [x] map pin 文案正确
  - [x] open map query 正确
- [x] event editor / upload flow 保存后回显正确
- [x] 聊天卡片 / widget / profile / share card 地址展示正确
- [x] build 与 contract decode 全量通过
- [x] generated Event contract 类型已补齐 `activityAddress / venueDisplayAddress`
- [x] 已补充 iOS 地址终局语义单测覆盖 `manualSet -> point formatted -> manualLocation` 规则
- [x] 已确认 iOS 地址主线验证入口为 `.xcworkspace` 而不是 `.xcodeproj`
- [x] `xcodebuild test -workspace ... -only-testing:RaverMVPTests/EventContractParityTests` 已实际通过
- [x] iOS 编辑态地址保真链路已验收通过：
  - 已保留已有 `locationPoint` 的 provider 原始多语言地址，不再因编辑页 hydrate / update 被 `pickedMapAddress` 单字符串覆盖
  - 已确认 update payload 会重建 `manualLocation.formattedAddressI18n` 与 `locationPoint.manualSetAddressI18n`
  - 已确认 `locationPoint.formattedAddressI18n` 继续保留 provider 原始格式化地址语义
- [x] 已修正 iOS `EventDetailView` 信息卡中的“活动地址”展示：
  - 之前该行错误使用 `event.unifiedAddress`，会把场地展示地址与活动地址混在一起
  - 当前已改为只展示 `event.eventActivityAddress`
  - 同页“场地”、map sheet marker 文案与 open map query 继续统一走 `venueDisplayAddress / resolveEventVenueMapQueryText(...)`

### 最终验收标准

- [x] 仓库活跃代码中不再存在 event 顶层 `venueName`
- [x] 仓库活跃代码中不再存在 event 顶层 `venueAddress`
- [x] “活动地址”统一只由 `manualLocation.formattedAddressI18n` 决定
- [x] “场地字段 / map pin 文案”统一只由 `locationPoint.manualSetAddressI18n -> locationPoint.formattedAddressI18n` 决定
- [x] 无 `locationPoint` 时，场地字段才回退到 `manualLocation`
- [x] POI 名称仅保留为元数据，不再作为前台主展示地址
- [x] web 与 iOS 对同一 event 的地址展示语义完全一致
- [x] 所有 create / edit / review / import / share / widget / search / check-in 链路完成对齐

### 当前阻塞记录

- [x] 已确认本轮 `xcodebuild` 首个真实失败不是地址模型主线，而是 iOS 工程依赖问题：
  - `DJsModuleView.swift:11` 缺少 `SDWebImage` 模块
  - 该问题先记录，不作为当前地址主线语义是否正确的判断依据
- [x] 本轮再次尝试仅跑 `RaverMVPTests/EventContractParityTests` 时，仍被同类 iOS 工程依赖问题阻塞：
  - 使用可用模拟器 `iPhone 17` 后，`xcodebuild test` 可进入正常编译链路
  - 但最终仍在 `Features/Messages/UIKitChat/*` 编译阶段失败，错误为 `No such module 'SDWebImage'`
  - 说明当前阻塞仍是全工程构建依赖，而不是本轮新增的地址主线测试逻辑先失败
- [x] 已确认本轮 `phase6:readonly:smoke` 不再阻塞于本地服务未启动，而是失败在与地址主线无关的历史 feed/post 断言：
  - `post detail boundDjIDs missing`
  - 地址相关断言已进入实际执行阶段，后续若要继续推进 Phase 6，可将该 smoke 拆分出独立的 event-address smoke，避免非主线模块阻塞地址验收
- [x] 已新增独立 `phase6-event-address-smoke`：
  - 覆盖 `event detail` / `event list` / `admin catalog summary` / `share-links resolve` / `locationPoint -> manualLocation fallback`
  - 已确认 `catalog-summary` 原先缺失 `manualLocation/locationPoint/cityI18n/countryI18n` select，现已补齐并开始返回地址字段
  - 当前已确认问题不是地址主线逻辑，而是开发态 `nodemon` 重启窗口会造成偶发 `ECONNREFUSED 127.0.0.1:3901`
  - 改用稳定 server 进程 `PORT=3901 node dist/index.js` 后，独立 smoke 已完整通过
  - 已确认 `event detail`、`event list`、`catalog-summary`、`share resolve` 与 `locationPoint -> manualLocation fallback` 全部符合当前主线断言
- [x] 已修复 `event-incremental-sync-regression` 在新 schedule foundation 下的脚本种子问题：
  - 之前 seed event 未创建 `weeks/eventDays`，导致 `createOrUpdateEventFromSubmission(...)` 在比对 existing state 时错误触发 `weeks 不能为空`
  - 当前脚本已补齐基础 `weeks/eventDays` seed，并恢复对 create / update / replay / address normalization 主线路径的实际验证价值
- [x] 当前 `event-incremental-sync-regression` 已在稳定连接配置下完整通过：
  - 为避免当前环境的 `DIRECT_URL` 瞬时网络波动影响长事务验证，本轮使用统一连接配置完成回归
  - 已确认本轮通过结果覆盖了地址主线相关的 create / update / replay / address normalization 写路径
  - 2026-06-08 已再次实际复跑通过：
    - 需要同时统一 `DATABASE_URL` / `DIRECT_URL` / `EVENT_SUBMISSION_TRANSACTION_URL` 到同一条 Supabase pooler 连接
    - 否则 `content-submission-event.service.ts` 会优先使用事务专用 URL，仍可能命中 `P1001`
- [x] web Event Studio 地址提交流程已补齐 parity 验证并通过：
  - `mapEventStudioDraftToCreateInput` 已覆盖 POI-backed create 地址写入
  - `mapEventStudioDraftToUpdateInput` 已覆盖清空地址、保留地址与编辑后重建地址真值
  - 已新增 `hydrate -> edit detailAddress -> update payload` 回归，确认：
    - `manualLocation.formattedAddressI18n` 会随编辑后的 `detailAddress` 重建
    - `locationPoint.manualSetAddressI18n` 会随编辑后的 `detailAddress` 重建
    - `locationPoint.formattedAddressI18n` 保留 provider 原始格式化地址，不被手填地址覆盖
  - 已修复 web mapper 先沿用旧 `locationPoint.manualSetAddressI18n`、导致编辑地址后场地展示真值不刷新的问题
- [x] iOS 地址主线代码已进一步对齐统一 helper：
  - 新增 `resolveEventVenueDisplayAddressText(...)`
  - 新增 `resolveEventActivityAddressText(...)`
  - 新增 `resolveEventVenueMapQueryText(...)`
  - `EventDetailView` 的场地文案与 Apple Maps query 已切到统一 helper 语义
- [x] 2026-06-08 已完成最新地址模型数据完整性巡检与修复：
  - 已将 `server/src/scripts/repair-event-formatted-addresses.ts` 重写为当前结构可执行的地址巡检脚本
  - 首次 dry-run 发现 `214` 条已带地址 event 中有 `194` 条需要补齐
  - 已执行 `--apply` 按最新地址规则补齐：
    - `manualLocation.formattedAddressI18n`
    - `locationPoint.manualSetAddressI18n`
  - 复跑巡检结果为：
    - `scanned: 214`
    - `repairable: 0`
- [x] 已补充 iOS 地址主线测试用例：
  - `venue map query` 优先使用 `manualSetAddressI18n -> formattedAddressI18n`
  - 当场地展示地址为空时，`venue map query` 才回退到 `locationPoint.nameI18n`
  - `EventUploadDraft.edit(event:)` 会分别 hydrate：
    - `detailAddress <- manualLocation.detailAddressI18n`
    - `pickedMapAddress <- locationPoint.formattedAddressI18n`
    - `pickedPlaceName <- locationPoint.nameI18n`
  - `EventUploadMappers.updateInput(from:)` 会在编辑已有 event 后重建：
    - `manualLocation.formattedAddressI18n`
    - `locationPoint.manualSetAddressI18n`
    - 同时保留 provider 原始 `locationPoint.formattedAddressI18n`
- [x] 已修复 iOS upload flow 新建场景的地图选点 provenance 丢失问题：
  - 之前 `EventUploadFlowViewModel.applyLocationPickerResult(...)` 只保留了坐标与辅助文本，导致 `EventUploadMappers.locationPoint(...)` 在无旧 `draft.locationPoint` 的新建场景下无法生成最终 `locationPoint`
  - 当前已在 iOS mapper 中补齐基于地图选点文本的 `mapkit/pin_drag` fallback locationPoint 生成逻辑，并补充 parity 断言锁定 `nameI18n / addressI18n / formattedAddressI18n / manualSetAddressI18n`
- [x] 已进一步修复 iOS 编辑已有 event 时的 `locationPoint` 保真问题：
  - 之前 mapper 仅在存在 provider provenance id 时才沿用旧 `draft.locationPoint`，导致部分历史 / fallback 点位在 update 时退化成只含单字符串的临时点位
  - 当前已改为：只要旧 `locationPoint` 仍含有效定位 / 地址 / 展示负载，就保留并归一化该对象，再仅重建 `manualSetAddressI18n`
- [x] 已将 iOS parity 测试断言对齐到最新地址终局语义：
  - `locationPoint.formattedAddressI18n` 按 provider 原始格式化地址处理，不再等同于活动地址拼接值
  - golden subset 比较已改为只校验主线语义必需字段，避免继续被旧 label / draft id / null 占位字段干扰
- [x] 已进一步完成 iOS upload flow 回显语义验收：
  - `EventUploadFlowViewModel.locationSummary` 已对齐到 `manualLocation.formattedAddressI18n` 语义
  - `EventUploadFlowViewModel.venueDisplaySummary` 已对齐到场地展示地址语义
  - upload flow 地图选点区块已优先回显 `venueDisplaySummary`
  - `xcodebuild test -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RaverMVPTests/EventContractParityTests -only-testing:RaverMVPTests/EventTimetableAIParsingTests` 已于 2026-06-08 实际通过
- [x] 已补充 iOS widget / profile 地址主线验收覆盖：
  - widget 倒计时写入入口已显式使用 `event.unifiedAddress` 作为 `venueDisplayAddress`
  - 已补充 `EventContractParityTests` 覆盖 widget snapshot 写入后的场地地址值
  - 已补充 `ProfileRecentCheckinPreview` 地址断言，确认 profile recent checkin 继续消费服务端给出的场地展示地址
- [x] 已补充 iOS 聊天卡片 / share card 地址主线验收覆盖：
  - 已补充 `EventShareCardPayload` 经 `MockSocialService.sendEventCardMessage(...)` 发出后再解码的链路断言
  - 已确认 event share card payload 中的 `venueDisplayAddress` 会原样进入聊天消息内容
  - 已于 2026-06-08 再次实际跑通 `EventContractParityTests + EventTimetableAIParsingTests`
- [x] 已确认 iOS 全工程 build 已恢复通过：
  - 已于 2026-06-08 实际执行 `xcodebuild build -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17'`
  - 结果为 `BUILD SUCCEEDED`
- [x] 已再次确认现有地址主线验证资产可实际跑通：
  - server：`pnpm --dir /Users/blackie/Projects/raver/server exec ts-node src/scripts/event-address-guardrails.ts`
  - web：`pnpm --dir /Users/blackie/Projects/raver/web test:parity:event`
  - server 增量回归：`pnpm --dir /Users/blackie/Projects/raver/server exec ts-node src/scripts/event-incremental-sync-regression.ts`

---

## 关键影响范围清单

### 数据库 / Contract / 服务端

- `/Users/blackie/Projects/raver/server/prisma/schema.prisma`
- `/Users/blackie/Projects/raver/docs/EVENT_MUTATION_SPEC.md`
- `/Users/blackie/Projects/raver/server/src/controllers/event.controller.ts`
- `/Users/blackie/Projects/raver/server/src/services/content-submission-event.service.ts`
- `/Users/blackie/Projects/raver/server/src/services/event-admin-contract-guardrail.service.ts`
- `/Users/blackie/Projects/raver/server/src/routes/bff.routes.ts`
- `/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts`
- `/Users/blackie/Projects/raver/server/src/services/global-search.service.ts`
- `/Users/blackie/Projects/raver/server/src/services/checkin-domain.ts`
- `/Users/blackie/Projects/raver/server/src/services/checkin-projection.ts`
- `/Users/blackie/Projects/raver/server/src/services/checkin-overview.ts`
- `/Users/blackie/Projects/raver/server/src/services/share-poster/localization.ts`
- `/Users/blackie/Projects/raver/server/src/services/share-poster/handlers/event-poster.ts`
- `/Users/blackie/Projects/raver/server/src/modules/entity-change/configs/event.change-config.ts`
- `/Users/blackie/Projects/raver/server/src/modules/entity-change/snapshots/event.snapshot.ts`
- `/Users/blackie/Projects/raver/server/src/scripts/event-admin-contract-guardrails.ts`
- `/Users/blackie/Projects/raver/server/src/scripts/repair-event-formatted-addresses.ts`
- `/Users/blackie/Projects/raver/server/prisma/import-events-archive-bilingual.ts`
- `/Users/blackie/Projects/raver/server/prisma/backfill-checkin-selections-snapshots.ts`

### Web

- `/Users/blackie/Projects/raver/web/src/lib/api/event.ts`
- `/Users/blackie/Projects/raver/web/src/lib/input-rules.ts`
- `/Users/blackie/Projects/raver/web/src/features/admin-content/event-studio/types.ts`
- `/Users/blackie/Projects/raver/web/src/features/admin-content/event-studio/draft.ts`
- `/Users/blackie/Projects/raver/web/src/features/admin-content/event-studio/mapper.ts`
- `/Users/blackie/Projects/raver/web/src/features/admin-content/event-studio/validation.ts`
- `/Users/blackie/Projects/raver/web/src/components/admin/EventStudioForm.tsx`
- `/Users/blackie/Projects/raver/web/src/components/EventCard.tsx`
- `/Users/blackie/Projects/raver/web/src/app/events/page.tsx`
- `/Users/blackie/Projects/raver/web/src/app/events/[id]/page.tsx`

### iOS

- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/Packages/RaverEventAdminContract/Sources/RaverEventAdminContract/Types.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/EventAdminContractBridge.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/MockWebFeatureService.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/Widget/WidgetSelectableEvent.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/Widget/WidgetSelectableEventsSyncService.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadDraft.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowView.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadMappers.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverCountdownWidgets/CountdownEventIntent.swift`

---

## 执行纪律

- 每完成一批改动，必须回到本文件勾选对应 checklist。
- 若中途新增受影响链路，先补入本文件，再继续开发。
- 若发现当前终局语义需要调整，先更新“终局字段职责表”和“终局展示规则”，再改代码。
