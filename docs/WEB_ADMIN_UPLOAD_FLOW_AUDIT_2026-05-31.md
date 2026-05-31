# Web Admin Upload Flow Audit

日期：2026-05-31

## 范围

本次只排查 Web 端以下全流程是否存在“编辑页拿不到数据”或“读到了但没法完整回填/提交”的问题：

- Event 上传 / 编辑
- DJ 上传 / 编辑
- News 上传 / 编辑
- 主办方 / Organizer / Festival
- 厂牌 / Label

重点看四段链路：

1. 详情接口是否把需要的数据取全
2. hydrate 是否把数据回填进 draft
3. mapper 是否把 draft 变成可提交 payload
4. 后端是否接收并落库

## 结论

### 已确认存在的问题

#### 1) Event 编辑页曾经读不到 timetable / lineup

根因是 Web BFF 的 event 详情查询缺少关系字段，导致 `mapEvent()` 之后 `lineupArtists` / `timetableSlots` 为空。

证据：

- `server/src/routes/bff.web.routes.ts`
  - `selectEventDetailForWeb` 之前没有把 `canonicalArtists`、`performances` 取全
  - `mapEventLineupArtists()` / `mapEventTimetableSlots()` 依赖这两组关系数据
- `web/src/features/admin-content/event-studio/draft.ts`
  - hydrate 现在已经开始优先使用真实 `event.eventDays`
  - timetable slot 会尝试按 `eventDayId` / `overallDayIndex` / `localDate` 回填

结论：

- 这条问题属于“详情没取到”，不是前端展示 bug
- 当前工作区里这条链路已经补上了

#### 2) Event 的 `venueName` 还没有完整打通

这是当前我查到的另一个同类断点。

现状：

- Web 表单里有 `venueName`
- `hydrateEventStudioDraftFromEvent()` 会回填 `event.venueName`
- 但提交 contract 里没有这个字段
- 后端提交落库逻辑里也没有看到对应写入

影响：

- Web 端可以显示 / 编辑这个输入框
- 但无法保证创建、编辑后能完整 round-trip

涉及文件：

- `web/src/features/admin-content/event-studio/types.ts`
- `web/src/features/admin-content/event-studio/draft.ts`
- `web/src/features/admin-content/event-studio/mapper.ts`
- `contracts/openapi/event-admin.v1.yaml`
- `server/src/services/content-submission-event.service.ts`

#### 3) `venueAddress`、`referenceLinks`、`socialLinks`、`sourceProvider` 属于“有数据但未统一进编辑器”的字段

这些字段在 event 详情里是能取到的，但 Web 编辑器当前没有形成完整的编辑闭环。

结论：

- 不是“拿不到”
- 更像是“后端有，前端未暴露成正式编辑项”
- 这类字段需要产品决策后再决定是否纳入编辑流

### 暂未发现同类阻断问题

#### DJ

DJ 详情、hydrate、mapper、提交链路整体是连通的。

结论：

- 没发现类似 event 那种“详情没取关系导致编辑页空数据”的问题

#### News

News 详情接口已经带上绑定关系，hydrate 也会回填：

- `boundDjIDs`
- `boundBrandIDs`
- `boundEventIDs`

结论：

- 没发现同类缺字段问题

#### 主办方 / Organizer / Festival

详情接口会返回 contributors 和图片资产，hydrate 也有对应回填。

结论：

- 没发现同类缺字段问题

#### 厂牌 / Label

详情接口会返回 founderDj，hydrate 也有对应回填。

结论：

- 没发现同类缺字段问题

## 现状判断

### Event

当前最需要处理的是：

1. 把 `venueName` 补成完整可提交字段
2. 决定 `venueAddress` 是否也要进入编辑流
3. 给 `venueName` / timetable / lineup 的回填与提交加回归测试

### 其他实体

当前没有发现和 event 一样的“详情没取够”类问题。

更可能存在的是“字段有，但编辑器没有做成正式能力”的产品缺口，不是数据链路断裂。

## 建议改造方案

### P0

#### Event 详情 / 编辑闭环补齐 `venueName`

需要同时改四层：

1. `contracts/openapi/event-admin.v1.yaml`
   - 在 `EventMutationBase` / `EventDetail` 补上 `venueName`
   - 如要支持编辑，也要补 `UpdateEventInput`

2. `contracts/generated/web/event-admin.ts`
   - 重新生成或同步 contract

3. `server/src/services/content-submission-event.service.ts`
   - 在 normalize / eventData 写入里增加 `venueName`
   - 如有更新逻辑，也要支持空值清除与保留

4. `web/src/features/admin-content/event-studio/mapper.ts`
   - 把 `draft.venueName` 正式映射到 create / update payload

5. 回归测试
   - 增加 `venueName` round-trip
   - 维持现有 `lineup/timetable` hydrate 回归

### P1

#### 明确 `venueAddress` 是否要成为编辑字段

两种方案二选一：

1. 作为只读展示字段
   - 只保留在详情和预览里
   - 不进入 draft / mapper / submit

2. 作为正式编辑字段
   - 补进 draft / mapper / contract / 落库
   - 同步补测试

### P1

#### 把 event 的 `referenceLinks` / `socialLinks` / `sourceProvider` 归类

需要先决定它们是：

- 只展示
- 可编辑
- 还是从源数据自动同步

否则容易出现“后端有值，前端看得到但改不了”的长期割裂。

### P2

#### 统一补一次横向回归

建议加一组最小回归测试，覆盖：

- Event：详情 hydrate 后 `eventDays` / `lineupArtists` / `timetableSlots` 不丢
- Event：`venueName` round-trip
- DJ：详情 hydrate / edit 不丢平台链接和图片
- News：绑定 DJ / brand / event 后可回填
- 主办方：contributor / imageAssets / links 可回填
- Label：founderDj 可回填

## 文件索引

- `server/src/routes/bff.web.routes.ts`
- `server/src/services/content-submission-event.service.ts`
- `contracts/openapi/event-admin.v1.yaml`
- `contracts/generated/web/event-admin.ts`
- `web/src/features/admin-content/event-studio/draft.ts`
- `web/src/features/admin-content/event-studio/mapper.ts`
- `web/src/features/admin-content/event-studio/types.ts`
- `web/tests/contracts/event-mapper-parity.ts`
- `web/src/features/admin-content/dj-studio/draft.ts`
- `web/src/features/admin-content/dj-studio/mapper.ts`
- `web/src/features/admin-content/news-studio/draft.ts`
- `web/src/features/admin-content/news-studio/mapper.ts`
- `web/src/features/admin-content/organizer-studio/draft.ts`
- `web/src/features/admin-content/organizer-studio/mapper.ts`
- `web/src/features/admin-content/label-studio/draft.ts`
- `web/src/features/admin-content/label-studio/mapper.ts`

## 备注

这份排查结论只针对 Web 端能力链路，不改 iOS。

如果要继续推进，建议下一步优先补 `venueName` 的合同、提交和测试，再决定 `venueAddress` 是否一起纳入编辑流。
