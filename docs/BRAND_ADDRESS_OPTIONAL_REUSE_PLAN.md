# Brand 地址模型与 Event 复用改造方案

> Status: Draft
> Owner: Backend / Web Admin / iOS
> Last Updated: 2026-06-08
> Scope: `server/`, `web/`, `mobile/ios/`, `server/prisma/`, `docs/`

---

## 目标

给 `brand`（当前项目中对应 `WikiFestival / OrganizerStudio`）增加一套可选地址属性，地址模型与 `event` 当前主线地址模型保持一致：

- `manualLocation`
- `locationPoint`

并在 web 端实现：

- brand 创建 / 编辑流可填写这两部分地址
- 这套地址对 brand 来说是可选项，不强制必填
- event 创建 / 编辑流中，如果已绑定 brand，可一键使用该 brand 的地址信息
- event 仍然可以不使用 brand 地址，也可以使用后再继续改

当前阶段 brand 地址仍然主要作为：

- brand 自身的后台属性
- event 编辑流中的一个快捷复用来源

新增要求：

- iOS `brand` 创建 / 编辑流也需要补齐这套地址编辑能力
- iOS `event` 创建 / 编辑流也需要补齐“使用主办方地址”能力
- 仍然不要求 iOS 前台 brand 详情页展示 brand 地址

---

## 战略执行原则

### 1. 维持主线，不发散

- [x] 本次改造严格围绕 `brand 地址模型 + event 复用` 主线推进
- [x] 非主线问题只记录，不插队处理
- [x] 不顺手扩散到 brand 前台详情页、iOS brand 展示、brand 搜索排序等非必要范围
- [x] 若过程中遇到发散问题，只记录到本文档或后续尾项，主线完成后再收尾处理

### 2. 不做旧版本兼容负担

- [x] 按你当前项目阶段，默认允许直接切到新主线
- [x] 不以长期双写 / 双读 / 长期 fallback 为目标
- [x] 若出现临时兼容代码，只允许作为过渡修复，主线完成后应清理
- [x] 不用考虑旧版本线上兼容，直接一步到位并做好 migration 即可，因为当前线上没有用户

### 3. 复用 event 已有地址主线

- [x] brand 地址字段职责直接对齐 event
- [x] web 端尽量复用 event 已有 mapper / draft / UI 模式 / map picker 能力
- [x] 事件编辑流的“一键使用 brand 地址”按“拷贝值”语义实现，不建立运行时联动

---

## 当前项目现状确认

以下内容已基于代码确认：

- [x] brand 在数据层对应 `WikiFestival`
- [x] web 端 brand 创建 / 编辑入口对应 `OrganizerStudio`
- [x] `WikiFestival` 当前还没有 `manualLocation` / `locationPoint`
- [x] `OrganizerStudioDraft / mapper / validation / form` 当前也没有地址字段
- [x] event 已有完整地址主线：
  - [x] `manualLocation`
  - [x] `locationPoint`
  - [x] `locationPoint.manualSetAddressI18n`
- [x] event 编辑流已存在：
  - [x] 地图选点能力
  - [x] 多语言地址输入
  - [x] 只读结果块
  - [x] 主办方绑定 `wikiFestivalId`
- [x] event 当前搜索主办方只拿到 organizer 基础信息，不含 organizer 地址
- [x] iOS 前台品牌展示当前仍不需要消费 brand 地址
- [x] iOS brand/upload 与 event/upload 目前尚未对齐 brand 地址编辑 / 复用能力

---

## 本次改造范围

### In Scope

- [x] Prisma / DB：为 `WikiFestival` 增加 brand 地址字段
- [x] server brand create / update / fetch / list contract 对齐新字段
- [x] content submission brand 链路对齐新字段
- [x] web Organizer Studio 创建 / 编辑页增加可选地址编辑能力
- [x] web event 编辑流增加“一键使用主办方地址”
- [x] iOS OrganizerUploadFlow 增加可选 brand 地址编辑能力
- [x] iOS EventUploadFlow 增加“一键使用主办方地址”
- [x] 必要的 migration / script / regression / QA 文档

### Out Of Scope

- [ ] iOS brand 详情页展示地址
- [ ] brand 前台公开页面地址展示
- [ ] 基于 brand 地址的地图搜索、筛选、推荐
- [ ] event 自动持续跟随 brand 地址变化

---

## 核心设计结论

## 1. Brand 的终局地址字段

`WikiFestival` 新增：

- [x] `manualLocation Json?`
- [x] `locationPoint Json?`

字段职责与 event 对齐：

### `manualLocation`

- [x] `detailAddressI18n`
  - brand 手填详细地址原文
- [x] `formattedAddressI18n`
  - brand 对外规范化地址
  - 由 `detailAddress + city + country` 稳定生成

### `locationPoint`

- [x] `provider`
- [x] `sourceMode`
- [x] `providerPlaceId`
- [x] `poiId`
- [x] `adcode`
- [x] `location`
- [x] `nameI18n`
- [x] `addressI18n`
- [x] `formattedAddressI18n`
- [x] `manualSetAddressI18n`
- [x] `city`
- [x] `district`
- [x] `province`
- [x] `countryCode`
- [x] `providerMeta`

### 关键语义

- [x] brand 地址是可选项，不是必填项
- [x] brand 有地址，不代表 event 必须继承
- [x] event 使用 brand 地址时，是一次性拷贝，不是引用绑定
- [x] event 拷贝后仍按 event 自己的地址逻辑保存与展示

---

## 2. Brand 地址字段职责表

### 顶层已有字段继续保留

- [x] `country / countryI18n`
  - brand 所属国家基础信息
  - 继续作为 brand 基本资料字段存在
- [x] `city / cityI18n`
  - brand 所属城市基础信息
  - 继续作为 brand 基本资料字段存在

### 新增地址结构的职责

- [x] `manualLocation`
  - 代表 brand 的手填活动/场地地址真值
- [x] `locationPoint`
  - 代表 brand 的地图点位与场地展示真值

### 与 event 的关系

- [x] event 的 `manualLocation` / `locationPoint` 不直接引用 brand 的 JSON
- [x] event 点击“一键使用主办方地址”后，复制 brand 当前地址快照到 event draft
- [x] 之后用户对 event 的修改不会反写 brand
- [x] 之后 brand 的修改也不会自动推送到已创建 event

---

## 3. Event 里的“一键使用主办方地址”最终语义

前提：

- [x] event 当前已绑定 `wikiFestivalId`
- [x] 对应 brand 至少存在部分地址信息

按钮行为：

- [x] 在 event 编辑流“地点与时区”区域提供一个快捷入口
- [x] 文案建议：`使用主办方地址`
- [x] 点击后，将 brand 的以下字段拷贝到 event draft：
  - [x] `country / countryI18n`
  - [x] `city / cityI18n`
  - [x] `manualLocation`
  - [x] `locationPoint`
  - [x] `latitude / longitude` 由 `locationPoint.location` 同步到 event 顶层草稿
  - [x] `pickedPlaceName / pickedMapAddress` 同步成便于编辑态展示的辅助值
- [x] 若 brand 无地址，则按钮禁用或点击后给出明确提示
- [x] 拷贝后用户仍可手动继续改 event 地址
- [x] event 也可以完全不使用 brand 地址

不做的事：

- [x] 不做“始终跟随 brand 最新地址”
- [x] 不做“保存 event 时自动覆盖成 brand 地址”
- [x] 不做“brand 改了以后批量更新历史 event”

---

## 4. Web 端 brand 创建 / 编辑页的目标交互

目标：**尽量与 event 的地点编辑体验一致，但 brand 版全部可选。**

### UI 结构

- [x] 在 `OrganizerStudioForm` 中新增一个独立的“地点与地图”分区
- [x] 分区内部结构与 event 地点模块尽量一致：
  - [x] 地图选点卡片
  - [x] 场地展示地址（可选）
  - [x] 国家
  - [x] 城市
  - [x] 详细地址
  - [x] 只读结果块
- [x] 不引入 event 特有字段：
  - [x] 时区
  - [x] 活动日期
  - [x] event 专属状态说明

### 字段行为

- [x] 地图选点可选，不强制
- [x] 国家 / 城市 / 详细地址可选
- [x] `manualSetAddressI18n` 可选
- [x] 若填写了 `detailAddress + city + country`，则生成 `manualLocation.formattedAddressI18n`
- [x] 若只选了地图，则允许只有 `locationPoint`
- [x] 若用户清空地图绑定，只清掉 `locationPoint`
- [x] 若用户清空手填地址，只清掉 `manualLocation`

### 只读展示块

brand 页面也展示灰色只读结果块：

- [x] 最终 hand-made 地址：`manualLocation.formattedAddressI18n`
- [x] 最终地图格式化地址：`locationPoint.formattedAddressI18n`
- [x] 最终场地展示地址：`locationPoint.manualSetAddressI18n`

显示规则与 event 对齐：

- [x] `manualSetAddressI18n` 为空时，明确显示“未填写时回退到地图地址”

---

## 数据模型与 Contract 改造

## Phase 0. 方案冻结

- [x] 冻结 brand 新地址模型：
  - [x] `manualLocation`
  - [x] `locationPoint`
- [x] 冻结 event 复用语义：
  - [x] 一次性拷贝
  - [x] 不建立动态联动
- [x] 冻结当前阶段边界：
  - [x] 不做 iOS brand 展示
  - [x] 不做前台 brand 地址展示

## Phase 1. Prisma / Migration

### 目标

给 `WikiFestival` 增加与 event 对齐的地址结构。

### 待完成

- [x] 在 `server/prisma/schema.prisma` 的 `WikiFestival` 模型新增：
  - [x] `manualLocation Json? @map("manual_location")`
  - [x] `locationPoint Json? @map("location_point")`
- [x] 生成 migration
- [ ] 若需要，补充 brand 地址回填脚本占位
- [ ] 明确本次不要求历史品牌必须补数据，可允许为空

### 迁移原则

- [x] brand 现有 `country/city` 不自动强行生成 `manualLocation`
- [x] 只有用户后续显式编辑 brand 地址，才形成新地址结构
- [x] 避免写出“伪精确地址”

## Phase 2. Server Brand Contract 与读写链路

### 目标

让 brand 的 create / update / fetch 都支持新地址结构。

### BFF / route / mapper

- [x] `mapWikiFestival(...)` 返回：
  - [x] `manualLocation`
  - [x] `locationPoint`
- [x] `/v1/learn/festivals/:id` 返回这两个字段
- [x] `/v1/learn/festivals` 列表接口按需返回轻量地址摘要
  - [x] 至少 event 绑定搜索拿详情时需要可取到完整地址
- [x] `brandPayloadForValidation(...)` 合并已有 brand 地址字段
- [x] `validateBrandSubmissionPayload(...)` 接受地址字段，但不要求必填

### Content submission brand service

- [x] `normalizeBrandSubmissionPayload(...)` 纳入：
  - [x] `manualLocation`
  - [x] `locationPoint`
- [x] `createOrUpdateBrandFromSubmission(...)` 支持保存：
  - [x] `manualLocation`
  - [x] `locationPoint`
- [x] 统一使用与 event 对齐的地址 normalization 规则

### 服务端地址规则

- [x] 对 brand 复用 event 的 `formattedAddressI18n` 生成规则
- [x] brand `manualLocation.formattedAddressI18n` 也由服务端稳定生成
- [x] `locationPoint.manualSetAddressI18n` 保持显式可选
- [x] 不自动把 `manualSetAddressI18n` 强写成 `formattedAddressI18n`

## Phase 3. Web Organizer Studio 数据模型

### 目标

让 brand 草稿模型具备和 event 对齐的地址编辑能力。

### types / draft / mapper / validation

- [x] `OrganizerStudioDraft` 新增：
  - [x] `detailAddress`
  - [x] `manualSetAddress`
  - [x] `locationPoint`
  - [x] `pickedPlaceName`
  - [x] `pickedMapAddress`
  - [x] 可选：`latitude` / `longitude` 草稿镜像
- [x] `OrganizerStudioLoadedOrganizer` 新增：
  - [x] `manualLocation`
  - [x] `locationPoint`
- [x] `OrganizerStudioCreateInput / UpdateInput` 新增：
  - [x] `manualLocation`
  - [x] `locationPoint`
- [x] `hydrateOrganizerStudioDraftFromOrganizer(...)` 支持地址回填
- [x] `mapOrganizerStudioDraftToCreateInput(...)` 生成 brand 地址 payload
- [x] `mapOrganizerStudioDraftToUpdateInput(...)` 生成 brand 地址 payload
- [x] `validateOrganizerStudioDraft(...)`
  - [x] 不把地址设为必填
  - [x] 但若填了部分结构，可做最小一致性校验

### 需要复用的 event 逻辑

- [x] 多语言地址文本规范化
- [x] `formattedAddressI18n` 拼接逻辑
- [x] 地图点位 payload 结构
- [x] map picker 输出转草稿的映射逻辑

## Phase 4. Web Organizer Studio UI

### 目标

在 brand 创建 / 编辑页真正接上地址填写能力。

### 页面改造

- [x] `OrganizerStudioForm.tsx` 增加“地点与地图”分区
- [x] 复用现有 `EventLocationPickerModal`
- [x] brand 端也保留 native / legacy 地图版本切换能力
- [x] brand 端也支持：
  - [x] 地图选点
  - [x] 清除地图绑定
  - [x] 编辑场地展示地址
  - [x] 地址多语言 overlay

### 交互要求

- [x] brand 地址区全部可选
- [x] 没填任何内容也能提交
- [x] 只填一部分时界面有明确空态
- [x] 编辑成功后重新进入页面，地址字段要能正确回填

## Phase 5. Event 复用主办方地址

### 目标

event 编辑流能从已绑定 brand 快速复制地址。

### API / data needs

- [x] event 侧需要拿到绑定 organizer 的完整地址信息
- [x] 实现路径已冻结，按主线选择更简单的一种：

路径 A：

- [x] 在 event 页面已知 `wikiFestivalId` 后，额外请求 organizer detail

路径 B：

- [ ] 扩展 event organizer search / current organizer payload，直接带地址

### 推荐主线

- [x] 优先使用路径 A
  - 原因：改动边界更清晰
  - 避免把 catalog/search 结果变重
  - event 仅在需要时加载该 organizer 地址详情

### EventStudioForm 改造

- [x] 在“地点与时区”区增加快捷按钮：
  - [x] `使用主办方地址`
- [x] 仅当 `organizerFestivalId` 存在时展示
- [x] 若 brand 无可用地址：
  - [x] 按钮禁用或点击提示“主办方尚未配置地址”
- [x] 点击后复制到当前 event 草稿：
  - [x] `country`
  - [x] `city`
  - [x] `detailAddress`
  - [x] `manualSetAddress`
  - [x] `locationPoint`
  - [x] `latitude / longitude`
  - [x] `pickedPlaceName / pickedMapAddress`
- [x] 复制成功后给出轻量成功反馈

### 复制字段规则

- [x] `detailAddress`
  - 来自 brand `manualLocation.detailAddressI18n`
- [x] `manualSetAddress`
  - 来自 brand `locationPoint.manualSetAddressI18n`
  - 若为空，允许保持空，由 event 自己继续走原有回退展示规则
- [x] `pickedPlaceName`
  - 来自 brand `locationPoint.nameI18n`
- [x] `pickedMapAddress`
  - 来自 brand `locationPoint.formattedAddressI18n`
- [x] `country / city`
  - 优先 brand 顶层 `countryI18n / cityI18n`
  - 与 event 现有草稿结构保持一致

## Phase 6. QA / Regression / Docs

### 自动化

- [x] 为 brand 地址新增至少一组 server regression
- [x] 覆盖 brand create / update / fetch 回填
- [x] 覆盖 event “使用主办方地址”映射函数
- [x] 覆盖 brand 地图-only 地址 hydrate / mapper parity
- [x] 覆盖 brand 地图-only / 手填+地图 payload guardrails
- [x] 覆盖 “event 保存后不反写 brand / brand 后续修改不联动旧 event” 的 server 回归执行

### 手工验证

- [x] 新建 brand，不填地址，成功提交
- [x] 新建 brand，只填手填地址，成功提交并回显
- [x] 新建 brand，只选地图，成功提交并回显
- [x] 新建 brand，同时填手填地址和地图，成功提交并回显
- [x] 编辑 brand 修改 `manualSetAddressI18n`，重新进入后仍能看到
- [x] event 绑定该 brand 后，点击“使用主办方地址”，字段正确回填
- [x] event 使用 brand 地址后再手动修改，保存成功，且不影响 brand 原数据
- [x] brand 后续地址变化，不会自动改动旧 event

### 文档同步

- [x] 本文档持续勾选更新
- [x] 当前手工 QA 结果已同步到本文档
- [ ] 若最终 server 侧抽出 brand/event 共用地址工具，补一份简短设计说明

---

## 技术实现建议

## 1. 尽量抽共享地址工具，而不是复制粘贴整段逻辑

虽然你的目标是“直接把 event 那一套抄过来”，但为了减少后面 brand/event 两边再漂移，推荐：

- [ ] 保持 UI 交互尽量复用 event 现有组件
- [ ] 保持地址 normalization / formattedAddress 生成 / locationPoint 映射抽成共享 helper
- [ ] 避免 brand 再复制出第二套稍有差异的地址拼接规则

这不算发散，反而是主线收口的一部分。

## 2. Brand 不引入 event 专属概念

- [ ] brand 不需要时区
- [ ] brand 不需要活动日期
- [ ] brand 不需要 event 状态
- [ ] brand 只复用“地点编辑能力”，不复用 event 的业务语义

## 3. Event 使用 brand 地址时必须是可撤销的

- [ ] 使用主办方地址后，用户仍能：
  - [ ] 手改字段
  - [ ] 重新地图选点
  - [ ] 清除地图绑定
- [ ] 不应把 event 地址区锁死成只读

---

## 当前默认假设

以下假设用于本方案落地，若你后面想改，我再调整：

- [x] `brand` 地址采用与 `event` 同名结构：`manualLocation / locationPoint`
- [x] event “使用主办方地址”是一次性复制，不建立联动
- [x] brand 现有 `country / city` 基础资料继续保留，不因新增地址结构而删除
- [x] 当前阶段不要求任何 iOS brand 地址消费

---

## 执行顺序

建议严格按这个顺序推进：

1. [x] Prisma / migration
2. [x] server brand payload / fetch / submission
3. [x] web organizer-studio types / draft / mapper / validation
4. [x] web organizer-studio UI
5. [x] event 侧“一键使用主办方地址”
6. [ ] regression / 手工 QA / 文档勾选

---

## 主线完成判定

当以下条件全部满足时，本改造视为主线完成：

- [x] brand 数据库已支持 `manualLocation + locationPoint`
- [x] web brand 创建 / 编辑页可选填写并正确回显地址
- [x] event 在已绑定 brand 时可以一键复制其地址
- [x] event 复制后仍可独立编辑，不与 brand 联动
- [x] server / web regression 通过
- [x] 本文档 checklist 回填完成

---

## 当前收尾状态

- [x] brand 地址主线的 schema / server / web / event-copy 主链路已落地
- [x] brand 手填地址回显、`manualSetAddressI18n` 回显、event 使用 brand 地址回填已完成手工验证
- [x] event 回填验证已确认以下字段一起正确落入草稿：
  - [x] `country`
  - [x] `city`
  - [x] `detailAddress`
  - [x] `manualSetAddress`
  - [x] `locationPoint` 派生的只读结果块
- [x] 主线所需 brand 地图-only / 手填+地图 roundtrip 已有自动化覆盖
- [ ] 如需最终上线前体验确认，可再补一轮页面手工走查，但不再阻塞主线完成

## Phase 7. iOS 对齐执行清单

### 目标

让 iOS 端与已经完成的 web 主线保持一致，但仍只围绕：

- brand 地址编辑
- event 复用主办方地址

不扩散到 brand 前台展示。

### iOS Brand Upload

- [x] `OrganizerUploadDraft` 增加与 web 对齐的地址草稿字段：
  - [x] `detailAddress`
  - [x] `manualSetAddress`
  - [x] `locationPoint`
  - [x] `pickedPlaceName`
  - [x] `pickedMapAddress`
  - [x] `latitude / longitude`
- [x] `OrganizerUploadDraft.edit(from:)` 支持从 brand 地址回填
- [x] `OrganizerUploadMappers.createInput(from:)` 写出 `manualLocation / locationPoint`
- [x] `OrganizerUploadMappers.updateInput(from:)` 写出 `manualLocation / locationPoint`
- [x] `OrganizerUploadFlowView` 新增 brand 地址编辑 UI
- [x] iOS brand 地址区保持可选，不设必填
- [x] iOS brand 端展示 3 个只读地址结果块：
  - [x] `manualLocation.formattedAddressI18n`
  - [x] `locationPoint.formattedAddressI18n`
  - [x] `locationPoint.manualSetAddressI18n`

### iOS Event Upload

- [x] 在 `EventUploadFlowView` 的地点区增加 `使用主办方地址` 入口
- [x] 在 `EventUploadFlowViewModel` 中，当已绑定 `organizerFestivalID` 时可拉取 organizer 详情
- [x] 增加把 organizer 地址拷贝到 event draft 的 helper
- [x] 复制字段与 web 对齐：
  - [x] `country / city`
  - [x] `detailAddress`
  - [x] `manualSetAddress`
  - [x] `locationPoint`
  - [x] `latitude / longitude`
  - [x] `pickedPlaceName / pickedMapAddress`
- [x] organizer 无地址时给出明确提示
- [x] 复制后 event 仍然可继续手改，不建立联动

### iOS QA / 修复顺带项

- [x] 修复 EventUpload 第二页官网链接下方字段标题乱码问题
- [x] 确认该字段 placeholder 与 title 都恢复正常
- [ ] iOS brand 地址编辑提交流程可成功入库并重新回显
- [ ] iOS event 使用主办方地址后，草稿字段正确回填
- [x] `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -sdk iphonesimulator -configuration Debug build`
- [x] 已新增自动化补强：
  - [x] `web/tests/contracts/brand-address-parity.ts` 已覆盖 map-only brand 地址路径
  - [x] `server/src/scripts/brand-address-payload-guardrails.ts` 已覆盖 map-only / 手填+地图的服务端地址语义
  - [x] `server/src/scripts/brand-address-roundtrip-regression.ts` 已覆盖 map-only / 手填+地图真实入库后读回
  - [x] `server/src/scripts/brand-address-reuse-regression.ts` 已补上跨实体不联动回归脚本
- [x] 当前环境阻塞已解除：
  - [x] `brands:address-reuse:regression` 已改为使用更直接的 event 快照解耦验证，并通过 `DIRECT_URL` 优先连接执行成功
  - [x] 本地可执行自动化已通过：
    - [x] `pnpm --dir /Users/blackie/Projects/raver/web test:parity:event`
    - [x] `pnpm --dir /Users/blackie/Projects/raver/server brands:address:guardrails`
    - [x] `pnpm --dir /Users/blackie/Projects/raver/server brands:address:roundtrip`
    - [x] `pnpm --dir /Users/blackie/Projects/raver/server brands:address-reuse:regression`
    - [x] `pnpm --dir /Users/blackie/Projects/raver/server build`
