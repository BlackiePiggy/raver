# 多 Week 活动与 Timetable 识别统一数据模型改造方案

## 执行进度

### 0. 文档与追踪

- [x] 建立唯一正式方案文档
- [x] 将方案拆解为可执行 checkbox 清单
- [x] 后续每完成一个实际改造任务，立即回写本文件进度

### 1. 数据模型重构

- [x] 设计并落地统一 `schedule` 结构
- [x] 设计并落地统一 `weeks` 结构
- [x] 设计并落地统一 `eventDays` 结构
- [x] 删除 `description` marker 作为 multi-week 识别来源
- [x] 删除 `festivalDayIndex` 作为事件日正式主键
- [x] 将 `eventDayId` 设为活动日唯一主键

### 2. 数据库存储改造

- [x] 为活动主表补充 `schedule_mode / schedule_time_zone / day_rollover_hour`
- [x] 新增 `event_weeks` 结构化存储
- [x] 新增 `event_days` 结构化存储
- [x] 为 `event_performances` 增加 `event_day_id`
- [x] 为 `event_performances` 增加 `week_index / day_index_in_week / overall_day_index / local_date`
- [x] 完成数据库 migration 与 schema 对齐

### 3. 服务端事件接口改造

- [x] 升级 `POST /v1/events` 入参为 `schedule / weeks / eventDays`
- [x] 升级 `PATCH /v1/events/:id` 入参为 `schedule / weeks / eventDays`
- [x] 创建活动时校验 `multi_week` 必须携带完整 `weeks`
- [x] 创建活动时校验 `multi_week` 必须携带完整 `eventDays`
- [x] 更新活动时校验 `eventDayId` 与 week/day/date 冗余字段一致
- [x] 服务端拒绝只携带 `festivalDayIndex` 的 timetable 写入

### 4. 服务端 canonical timetable 改造

- [x] `normalizeSubmissionLineupSlots` 改为基于 `eventDayId` 归一化
- [x] slot UTC 时间改为由 `eventDayId -> localDate + normalized time` 推导
- [x] patch 模式 timetable 更新改为基于 `eventDayId`
- [x] canonical snapshot / sync 逻辑改为保留 `eventDayId`
- [x] 删除 `eventStartDate + festivalDayIndex` 推导 slot 日期的旧逻辑

### 5. iOS 上传草稿模型改造

 - [x] 重写 `EventUploadDraft` 的时间模型
 - [x] 用 `schedule / weeks / eventDays` 替代 `scheduleMode / weekRanges`
- [x] timetable draft slot 增加 `eventDayId`
- [x] timetable draft slot 增加 `weekIndex / dayIndexInWeek / overallDayIndex / localDate`
- [x] 编辑态回填改为从结构化 `weeks / eventDays` 恢复
- [x] 删除 iOS 侧 description marker 读写逻辑

### 6. iOS mapper 与提交链路改造

- [x] `CreateEventInput` mapper 改为输出 `schedule / weeks / eventDays`
- [x] `UpdateEventInput` mapper 改为输出 `schedule / weeks / eventDays`
- [x] timetable slot mapper 改为输出 `eventDayId`
- [x] 删除 iOS mapper 输出 `festivalDayIndex` 的旧逻辑
- [x] 本地校验改为校验 `eventDayId` 绑定完整性

### 7. iOS timetable AI 应用链路改造

- [x] Timetable AI context 改为传入 `schedule / weeks / eventDays`
- [x] Timetable AI 结果 schema 升级到 `raver_timetable_ai_v3`
- [x] iOS 解析 Timetable AI 结果时保留 `eventDayRef`
- [x] 应用 AI 结果到草稿时不再丢失 `weekIndex`
- [x] 应用 AI 结果到草稿时改为使用 `eventDayId`
- [x] 歧义日期识别结果改为阻止直接应用并提示确认

### 8. Coze prompt 与识别契约改造

- [ ] 用文档中的正式 prompt 替换现有 timetable prompt
- [x] 将上下文输入从 `eventStartDate / eventEndDate / weekRanges` 升级为 `schedule / weeks / eventDays`
- [x] 要求 Coze 输出 `eventDayRef`
- [x] 要求 Coze 在 `Weekend 1 Friday` 场景下解析为唯一具体日期
- [x] 要求 Coze 在歧义场景下输出 warning 而不是猜测

### 9. 多 Week 展示层改造

- [x] 活动列表卡片改为展示多个离散时间段
- [x] 活动详情页头部时间区改为展示多个离散时间段
- [x] 上传页 review 时间摘要改为展示多个离散时间段
- [x] 我的发布列表时间摘要改为展示多个离散时间段
- [x] 审核后台活动概览改为展示多个离散时间段
- [x] Share poster 时间文案改为展示多个离散时间段
- [x] 搜索结果活动时间摘要改为展示多个离散时间段
- [x] countdown / reminder 逻辑改为基于最近一个 `eventDay`

### 10. Timetable 展示与分组改造

- [x] 详情页 timetable 分组改为 `Week -> EventDay -> Stage`
- [x] 上传页 timetable 编辑改为 `Week -> EventDay -> Stage`
- [x] AI 识别结果页改为 `Week -> EventDay -> Stage`
- [x] 删除“全局 Day 1 / Day 2”作为多 week 主分组的旧语义
- [x] 保证 `Week 1 Friday` 与 `Week 2 Friday` 在 UI 上明确区分

### 11. 清理与验证

- [x] 清理仓库中 remaining `festivalDayIndex` 正式写入路径
- [x] 清理仓库中 remaining multi-week description marker 依赖
- [x] 补充服务端测试
- [x] 补充 iOS mapper 与草稿测试
- [x] 补充 Timetable AI 解析测试
- [x] 补充多 week 展示测试
- [ ] 用 Tomorrowland 双周末样例完整走通创建、编辑、识别、展示链路

### 最近完成

- [x] 已新增 Prisma schema 结构：`Event.scheduleMode`、`EventWeek`、`EventDay`、`EventPerformance.eventDayId/week/day/localDate`
- [x] 已新增数据库 migration：`20260528120000_add_event_weeks_and_event_days_unified_model`
- [x] 已扩展 server canonical timetable 类型，允许 slot/performance 携带 `eventDayId`
- [x] 已扩展 BFF 事件查询选择器与 `mapEvent` 输出，开始返回 `schedule / weeks / eventDays`
- [x] 已扩展 iOS 共享 `WebEvent` / `CreateEventInput` / `UpdateEventInput` / Timetable AI v3 基础模型
- [x] 已将 event 提交链路切到 `schedule / weeks / eventDays` 严格校验，并在创建/编辑时结构化落库存储
- [x] 已将 timetable 提交与 patch 归一化改为基于 `eventDayId -> localDate + wall-clock time`
- [x] 已将 `/events/:id/timetable` 正式写入入口升级为要求 `eventDayId`
- [x] 已将 iOS 上传页 Week timetable 编辑的日选项与时间锚点切到结构化 `eventDays`
- [x] 已将 iOS 详情页 timetable / route / checkin 分组优先切到 `eventDayId + eventDays`
- [x] 已将活动列表卡片日期摘要切到共享 `weeks / eventDays` 离散时间段 formatter
- [x] 已将活动详情页头部时间区切到多段离散周次日期展示，并在事件时区 / 设备时区不同时分别列出
- [x] 已将上传页 review 与时区预览的时间摘要切到离散周次日期展示
- [x] 已将我的发布活动列表时间摘要切到结构化 `weeks / eventDays` 离散时间段展示
- [x] 已将 widget countdown 存储与计算切到离散日期段，双周活动在两个周末之间不再误判为持续进行中
- [x] 已将全局搜索 events 结果 subtitle 改为基于 `weeks / eventDays` 输出离散周次日期摘要，并同步更新 mock 文案
- [x] 已将通知中心 event countdown / daily digest 候选筛选与提醒锚点切到离散 `eventDays`，双周活动在两个周末之间不再把空档期当作连续进行中
- [x] 已将 Share poster 活动时间文案切到离散 `weeks / eventDays` 日期摘要，海报不再使用连续 start/end/duration 语义
- [x] 已将 Festival Viewer 审核后台 event 提交概览切到离散 `weeks / eventDays` 日期摘要，review 列表与详情头部不再只显示连续 startDate
- [x] 已将 iOS Timetable AI 结果页筛选与卡片文案切到 `eventDayId + dayLabel + localDate`，AI 结果主分组改为 `Week -> EventDay -> Stage`
- [x] 已将 iOS 上传提交 mapper 与 patch timetable diff 正式输出 `schedule / weeks / eventDays + eventDayId`，并停止输出 `festivalDayIndex`
- [x] 已将 iOS 本地 timetable 校验补到 `eventDayId` 绑定完整性，缺失绑定时会阻止提交并提示重新选择日期
- [x] 已将 server timetable AI 回包补上 `eventDayRef` 归一化与 ambiguity warning 兜底；当 Coze 未唯一解析到 event day 时，iOS 结果页会阻止直接 Apply，并要求先人工确认到具体日期
- [x] 已确认 Coze prompt 继续由人工在 Coze 后台维护；代码侧正式发送的 timetable context 已升级为 `schedule / weeks / eventDays`
- [x] 已删除 BFF / legacy controller 中残留的 `eventStartDate + festivalDayIndex` slot 日期改写逻辑；legacy rebase 现改为按真实日期偏移保留 wall-clock time，不再把 `festivalDayIndex` 当作真实日期来源
- [x] 已将 iOS 编辑态 timetable 草稿回填切到优先按 `eventDayId / localDate / weekIndex+dayIndexInWeek / overallDayIndex` 解析结构化 `eventDays`，并去掉对 `festivalDayIndex` 的正式身份兜底
- [x] 已将 `EventUploadDraft` 升成以 `canonical schedule / weeks` 为正式存储、`scheduleMode / weekRanges` 为兼容视图的时间模型，并把周次编辑入口收敛到 draft helper
- [x] 已删除上传页 timetable 日选项在缺少结构化 eventDays 时回退成全局 `Day 1` 的旧文案，改为中性日期占位
- [x] 已将 `EventUploadDraft` 内部正式推导进一步切到 canonical `schedule / weeks` 真源，`scheduleMode / weekRanges` 仅保留为兼容回填视图；上传流已不再读取 description marker 决定 multi-week
- [x] 已将上传页与校验提示中残留的 `Day N` fallback 收口为 `eventDay.label / localDate / Week + date`，多 week 编辑与 AI 结果页不再以全局 `Day 1 / Day 2` 作为主语义
- [x] 已执行 `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`
- [x] 已再次执行 `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`
- [x] 已再次执行 `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`
- [x] 已再次执行 `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`
- [x] 已执行 `pnpm -C server prisma:generate`
- [x] 已执行 `pnpm -C server build`
- [x] 已再次执行 `pnpm -C server build`
- [x] 已将 server legacy event/timetable controller 的正式 slot 写入收口为 `eventDayId/week/day/localDate` 主链，`festivalDayIndex` 仅保留兼容读字段，不再作为新写入值回灌
- [x] 已补充 `server/src/scripts/event-multi-week-eventday-guardrails.ts`，覆盖 multi-week `schedule/weeks/eventDays` 契约、`eventDayId` 必填、legacy `festivalDayIndex` 禁止作为正式写入三类 guardrail
- [x] 已执行 `pnpm -C server events:multi-week:eventday:guardrails`
- [x] 已再次执行 `pnpm -C server build`
- [x] 已补充 `RaverMVPTests` unit test target，并将 `AuthenticatedRequestRunnerTests` 与 `EventUploadMultiWeekModelTests` 正式接入 shared scheme
- [x] 已新增并跑通 iOS 多 week 纯模型测试，覆盖 `EventUploadDraft` 结构化 eventDays 重绑、`EventUploadMappers.createInput` 输出 `schedule / weeks / eventDays + eventDayId`、`EventUploadValidation` 缺失 eventDay 绑定拦截
- [x] 已执行 `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:RaverMVPTests/EventUploadMultiWeekModelTests`
- [x] 已完成运行时代码审计：仓库内已无基于 `description` marker 判定 multi-week 的活跃逻辑；剩余命中仅为方案文档说明或与本任务无关的普通文本字段
- [x] 已新增并跑通 `EventTimetableAIParsingTests`，覆盖 `eventDayRef` 唯一解析保留、歧义 warning 保留、跨午夜 `25:00` -> 次日 `01:00` 解析
- [x] 已新增并跑通 `EventMultiWeekDisplayTests`，覆盖 structured `weeks` 多段离散展示、缺失 `weeks` 时按 `eventDays.weekIndex` 聚合、无结构化周信息时回退 `startDate/endDate`
- [x] 已将共享展示层在仅有 `eventDays` 反推多周摘要时的前缀收口为紧凑 `Week 1 / Weekend 1`，不再误用整条 `Week 1 Friday / Weekend 1 Friday`
- [x] 已执行 `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:RaverMVPTests/EventUploadMultiWeekModelTests -only-testing:RaverMVPTests/EventTimetableAIParsingTests -only-testing:RaverMVPTests/EventMultiWeekDisplayTests`

## 文档目标

本方案定义 `Raver` 对活动日程的唯一正式模型，解决以下问题：

- `multi-week` 活动被误当成普通 `multi-day` 处理
- `Week 1 / Day 1` 与 `Week 2 / Day 1` 在上传、回填、展示、识别链路中发生混淆
- Timetable AI 识别虽然能读出 `weekIndex`，但应用到事件草稿时被丢失
- 活动详情、活动卡片、审核后台、上传页对多周活动的时间展示仍沿用连续多日逻辑

本次方案要求一步到位，只保留一种数据模型，不保留旧链路兼容语义，不允许继续依赖：

- `description` 内 marker 判断 multi-week
- 仅靠 `startDate + festivalDayIndex` 推导具体日期
- 仅靠 `festivalDayIndex` 表达活动日

---

## 一、唯一正式模型

### 1.1 核心原则

今后所有活动日程统一采用三层结构：

1. `schedule`
2. `weeks`
3. `eventDays`

其中：

- `schedule` 表示活动整体时段定义
- `weeks` 表示一个活动由几个离散周段构成
- `eventDays` 表示真正可被 Timetable、打卡、详情页引用的“活动日”实体

`eventDays` 是唯一允许被 Timetable slot 直接引用的日实体。

### 1.2 标准事件结构

```json
{
  "schedule": {
    "mode": "multi_week",
    "timeZone": "Europe/Brussels",
    "dayRolloverHour": 6
  },
  "weeks": [
    {
      "weekIndex": 1,
      "label": "Weekend 1",
      "startDate": "2026-07-17",
      "endDate": "2026-07-19"
    },
    {
      "weekIndex": 2,
      "label": "Weekend 2",
      "startDate": "2026-07-24",
      "endDate": "2026-07-26"
    }
  ],
  "eventDays": [
    {
      "eventDayId": "w1d1",
      "weekIndex": 1,
      "dayIndexInWeek": 1,
      "overallDayIndex": 1,
      "label": "Weekend 1 Friday",
      "weekday": "friday",
      "date": "2026-07-17"
    },
    {
      "eventDayId": "w1d2",
      "weekIndex": 1,
      "dayIndexInWeek": 2,
      "overallDayIndex": 2,
      "label": "Weekend 1 Saturday",
      "weekday": "saturday",
      "date": "2026-07-18"
    },
    {
      "eventDayId": "w1d3",
      "weekIndex": 1,
      "dayIndexInWeek": 3,
      "overallDayIndex": 3,
      "label": "Weekend 1 Sunday",
      "weekday": "sunday",
      "date": "2026-07-19"
    },
    {
      "eventDayId": "w2d1",
      "weekIndex": 2,
      "dayIndexInWeek": 1,
      "overallDayIndex": 4,
      "label": "Weekend 2 Friday",
      "weekday": "friday",
      "date": "2026-07-24"
    },
    {
      "eventDayId": "w2d2",
      "weekIndex": 2,
      "dayIndexInWeek": 2,
      "overallDayIndex": 5,
      "label": "Weekend 2 Saturday",
      "weekday": "saturday",
      "date": "2026-07-25"
    },
    {
      "eventDayId": "w2d3",
      "weekIndex": 2,
      "dayIndexInWeek": 3,
      "overallDayIndex": 6,
      "label": "Weekend 2 Sunday",
      "weekday": "sunday",
      "date": "2026-07-26"
    }
  ]
}
```

### 1.3 字段约束

- `schedule.mode` 只能是 `single_day | multi_day | multi_week`
- `weeks` 在 `multi_week` 模式下必填，且至少 2 个
- `eventDays` 永远是完整展开后的真实活动日列表
- `eventDayId` 全局唯一，作为 Timetable、打卡、详情分组、AI 识别落点的唯一主键
- `overallDayIndex` 仅作为顺序字段，不得再作为唯一业务身份
- `festivalDayIndex` 退出事件主链路，不再作为正式输入输出字段

---

## 二、Timetable 的唯一正式模型

### 2.1 Timetable slot 结构

每条 Timetable slot 必须直接绑定到 `eventDayId`，不得只绑定 Day N。

```json
{
  "id": "slot_123",
  "lineupArtistId": "artist_123",
  "eventDayId": "w2d1",
  "weekIndex": 2,
  "dayIndexInWeek": 1,
  "overallDayIndex": 4,
  "localDate": "2026-07-24",
  "stageName": "Mainstage",
  "performerType": "solo",
  "performerNames": ["Martin Garrix"],
  "startTimeText": "23:30",
  "endTimeText": "25:00",
  "startAt": "2026-07-24T21:30:00.000Z",
  "endAt": "2026-07-24T23:00:00.000Z",
  "sortOrder": 1
}
```

### 2.2 关键规则

- `eventDayId` 是 Timetable slot 的唯一日维度主键
- `weekIndex/dayIndexInWeek/overallDayIndex/localDate` 是冗余校验字段，不是替代主键
- `startTimeText/endTimeText` 保持活动日 wall-clock 语义
- `24+` 小时格式仍然保留，用于表达“属于同一活动日但实际跨午夜”
- 如果某条演出属于 `Weekend 1 Friday` 的逻辑活动日，即使现实时间是次日 `01:00`，也仍挂在 `w1d1`

### 2.3 废弃规则

以下旧规则全部废弃：

- 仅传 `festivalDayIndex`
- 仅靠 `event.startDate + dayIndex` 算真实日期
- Timetable AI 结果里只保留 `weekIndex` 展示但应用时丢弃

---

## 三、多 Week 活动的时间展示规则

### 3.1 总原则

多 Week 活动不再按照连续多日活动展示。

必须按“多个离散时间段”展示。

### 3.2 正式展示文案

#### 单日

```text
2026-07-17
```

#### 连续多日

```text
2026-07-17 - 2026-07-19
```

#### 多 Week

```text
2026-07-17 - 2026-07-19 · 2026-07-24 - 2026-07-26
```

或者移动端紧凑版：

```text
Weekend 1: Jul 17-19
Weekend 2: Jul 24-26
```

### 3.3 必须适配的展示位置

以下所有位置都必须改成按 `weeks[]` 渲染，而不是按 `startDate/endDate` 渲染：

- 活动列表卡片
- 活动详情页头部时间区
- 上传页 review 页时间摘要
- 我的发布列表
- 审核后台活动概览
- Share poster 中活动时间文案
- Countdown / reminder 文案生成逻辑
- 搜索结果中的活动时间摘要

### 3.4 禁止出现的错误展示

以 Tomorrowland 为例，以下展示都视为错误：

- `2026-07-17 - 2026-07-26`
- `6 days`
- `Day 1 - Day 6`

因为这会把两个周末误表示为一个连续六日活动。

### 3.5 与倒计时能力的关系

如果需要计算最近一场活动日：

- 必须从 `eventDays` 中选取下一个未发生的 `date`
- 不得只以 `event.startDate` 作为唯一倒计时基准

---

## 四、活动上传与编辑的正式输入结构

### 4.1 Event 输入契约

创建和更新活动时，时间结构必须统一为：

```json
{
  "schedule": {
    "mode": "multi_week",
    "timeZone": "Europe/Brussels",
    "dayRolloverHour": 6
  },
  "weeks": [
    {
      "weekIndex": 1,
      "label": "Weekend 1",
      "startDate": "2026-07-17",
      "endDate": "2026-07-19"
    },
    {
      "weekIndex": 2,
      "label": "Weekend 2",
      "startDate": "2026-07-24",
      "endDate": "2026-07-26"
    }
  ],
  "eventDays": [
    {
      "eventDayId": "w1d1",
      "weekIndex": 1,
      "dayIndexInWeek": 1,
      "overallDayIndex": 1,
      "label": "Weekend 1 Friday",
      "weekday": "friday",
      "date": "2026-07-17"
    }
  ]
}
```

### 4.2 iOS Draft 必须修改

当前 iOS 侧如果按本方案改造，需要把草稿结构从：

- `startDate`
- `endDate`
- `weekRanges`
- `scheduleMode`
- `timetableSlots.dayIndex`

改为：

- `schedule`
- `weeks`
- `eventDays`
- `timetableSlots.eventDayId`
- `timetableSlots.weekIndex`
- `timetableSlots.dayIndexInWeek`
- `timetableSlots.overallDayIndex`
- `timetableSlots.localDate`

### 4.3 你需要同步修改的地方

如果你要按这个新模型运行，你自己的上传和识别链路必须同步做这些修改：

1. 事件创建/编辑接口的请求体要增加 `schedule/weeks/eventDays`
2. Timetable slot 提交不能再只传 `festivalDayIndex`
3. iOS 本地 draft 不能再只存 `weekRanges + dayIndex`
4. 旧的 `description` marker 逻辑要删除
5. 编辑回填必须从结构化 `weeks/eventDays` 恢复，而不是从 `startDate/endDate` 反推

---

## 五、活动详情与上传 UI 的正式交互规则

### 5.1 时间步骤

当选择 `multi_week` 时：

- 用户维护的是 `weeks`
- 系统自动生成对应 `eventDays`
- `eventDays` 不允许手写自由文本，只允许由 `weeks + weekday/date` 规则生成

### 5.2 Timetable 编辑步骤

Timetable 编辑页必须变成：

1. 先选 `Week`
2. 再选该 `Week` 下的 `Event Day`
3. 再编辑舞台和 slot

不可继续使用“全局 Day 1、Day 2、Day 3”的弱语义。

### 5.3 详情页时间表展示

详情页必须按：

1. `Week tab`
2. `Day tab`
3. `Stage section`

进行分组。

如果不想显示显式 tab，也至少要在分组标题中体现：

```text
Weekend 1 Friday
Weekend 2 Friday
```

而不是两个都叫 `Day 1`。

---

## 六、数据库与后端正式模型

### 6.1 建议数据落库

活动主数据新增：

- `schedule_mode`
- `schedule_time_zone`
- `day_rollover_hour`

新增 `event_weeks` 表：

- `id`
- `event_id`
- `week_index`
- `label`
- `start_date`
- `end_date`
- `sort_order`

新增 `event_days` 表：

- `id`
- `event_id`
- `event_day_id`
- `week_id`
- `week_index`
- `day_index_in_week`
- `overall_day_index`
- `label`
- `weekday`
- `date`
- `sort_order`

`event_performances` 新增并强制使用：

- `event_day_id`
- `week_index`
- `day_index_in_week`
- `overall_day_index`
- `local_date`

### 6.2 后端约束

- 不再接受只带 `festivalDayIndex` 的写入
- `eventDayId` 不存在则整单拒绝
- `eventDayId` 与 `weekIndex/dayIndexInWeek/localDate` 不一致则整单拒绝
- `multi_week` 活动如果没有 `weeks` 或 `eventDays` 则整单拒绝

### 6.3 服务端时间归一化

服务端应从：

- `eventDayId -> localDate`
- `normalizedStartTime/endTime`
- `event.timeZone`

推导真实 UTC 时间。

服务端不得再从：

- `eventStartDate + festivalDayIndex`

推导具体 slot 日期。

---

## 七、Timetable AI 识别正式 schema

### 7.1 新 schema 版本

Timetable AI 输出版本升级为：

```text
raver_timetable_ai_v3
```

原因：

- v2 仍以 `festivalDayIndex` 为中心
- v3 必须显式输出 `eventDayRef` 解析结果

### 7.2 正式 schema

```json
{
  "schemaVersion": "raver_timetable_ai_v3",
  "imageType": "timetable",
  "weeks": [
    {
      "weekIndex": 1,
      "weekLabel": "Weekend 1",
      "days": [
        {
          "dayIndexInWeek": 1,
          "dayLabel": "Friday",
          "weekday": "friday",
          "dateText": "2026-07-17",
          "eventDayRef": {
            "eventDayId": "w1d1",
            "weekIndex": 1,
            "dayIndexInWeek": 1,
            "overallDayIndex": 1,
            "date": "2026-07-17",
            "resolutionReason": "Matched from visible text 'Weekend 1 Friday' against provided eventDays",
            "confidence": 0.98
          },
          "stages": [
            {
              "stageName": "Mainstage",
              "order": 1,
              "slots": [
                {
                  "orderInStage": 1,
                  "performerType": "solo",
                  "performerNames": ["Artist A"],
                  "displayName": "Artist A",
                  "rawTimeText": "23:30 - 01:00",
                  "startTimeText": "23:30",
                  "endTimeText": "01:00",
                  "normalizedStartTime": "23:30",
                  "normalizedEndTime": "25:00",
                  "confidence": 0.94,
                  "notes": []
                }
              ]
            }
          ]
        }
      ]
    }
  ],
  "unparsedTexts": ["string"],
  "warnings": ["string"]
}
```

### 7.3 AI 识别必须遵守的解析原则

AI 的职责不是发明日期，而是：

1. 读取海报上真的写出来的 `Weekend 1`、`Friday`、`Day 2`、`W2` 等标记
2. 结合你传入的 `eventDays/weeks` 上下文解析到唯一 `eventDayId`
3. 输出解析理由和置信度

### 7.4 “Weekend 1 Friday” 如何确定具体日期

当海报只写：

```text
Weekend 1 Friday
```

且上下文传入：

- Week 1: `2026-07-17 - 2026-07-19`
- Week 2: `2026-07-24 - 2026-07-26`
- eventDays 中已有 `w1d1 = 2026-07-17`

则解析器必须确定：

- `weekIndex = 1`
- `weekday = friday`
- `matched eventDayId = w1d1`
- `matched date = 2026-07-17`

这不是猜测，而是确定性映射。

### 7.5 歧义规则

如果海报只写：

```text
Friday
```

而活动有两个 Friday：

- `w1d1`
- `w2d1`

则不得自动落成某个日期。

必须输出：

- `eventDayId = null`
- warning 标明 `Ambiguous Friday across multiple weeks`

并要求人工确认。

---

## 八、你当前 Coze prompt 的正式替换版本

以下 prompt 可直接替换你当前 Timetable Coze prompt。

使用方式说明：

- 这段 prompt 由你手动粘贴到 Coze 后台
- `Raver` 代码侧不会再额外拼接 prompt
- `Raver` 代码侧只负责把 `context_json` 对应的结构化上下文传进去
- 因此 Coze 后台保存的 prompt 内容，必须与这里保持一致

```text
You are parsing a festival timetable image into strict JSON.

Return ONLY valid JSON. No markdown. No explanation.

The following fields are already known from the event editor and MUST be treated as authoritative structured context:
- eventTimeZone
- dayRolloverHour
- schedule
- weeks
- eventDays

Use them only as parsing and resolution context.
Do not override them with guesses from the image.

Your task is to extract only what is visually present in the timetable image:
- visible week grouping if present
- visible day grouping if present
- visible stage names
- visible stage order
- slot order within each stage
- performer names
- time text

Identify the type of each performance using these rules:
- "solo": a single DJ or artist performing alone
- "b2b": two artists performing back-to-back together
- "b3b": three artists performing together

Use performer naming carefully:
- "DJ A b2b DJ B" => "b2b"
- "DJ A & DJ B" => "b2b"
- "DJ A + DJ B" => "b2b"
- "DJ A x DJ B" => "b2b"
- "DJ A b2b DJ B b2b DJ C" => "b3b"
- "DJ A & Friends" => "solo"

Critical time rule:
All slot times are interpreted in the event's local timezone context supplied externally.

You must output:
- rawTimeText
- startTimeText
- endTimeText
- normalizedStartTime
- normalizedEndTime

normalizedStartTime / normalizedEndTime are wall-clock times relative to the resolved logical event day.
If a slot belongs to the same logical event day but happens after midnight, use 24+ hour notation:
- 00:30 => 24:30
- 01:00 => 25:00
- 02:15 => 26:15

Do not output UTC timestamps.
Do not output backend payload.
Do not hallucinate hidden text.

Critical event day resolution rule:
You MUST resolve each visible day grouping to exactly one eventDay from the provided context whenever the visible text is sufficient.

Examples:
- "Weekend 1 Friday" => match the eventDay whose weekIndex=1 and weekday=friday
- "Week 2 Day 3" => match the eventDay whose weekIndex=2 and dayIndexInWeek=3
- "W1 Sat" => match weekIndex=1 and weekday=saturday

Additional resolution rules:
- Do NOT infer weekIndex only from visual order unless the image explicitly shows the week grouping or the provided eventDays make the mapping unique.
- Do NOT assume "Friday" means the first Friday if multiple Fridays exist in the provided eventDays.
- If the visible text is exactly "Weekend 1 Friday" and the provided context contains a unique matching eventDay, you MUST resolve it to that concrete `eventDayRef.eventDayId`.
- If the visible text is only "Friday" and the provided context contains multiple Friday eventDays, you MUST keep `eventDayRef.eventDayId = null` and add a warning such as `ambiguous day marker: Friday maps to multiple eventDays; manual confirmation required`.
- If dayLabel, weekday, and dateText disagree, prefer the combination that can be uniquely matched to a provided eventDay; otherwise set eventDayRef.eventDayId to null and add a warning.
- If the image shows only a stage timetable but no visible day marker, use the provided context only when the mapping is unique; otherwise mark it ambiguous.

If the visible text is insufficient or ambiguous, do NOT guess.
Set eventDayRef.eventDayId to null and add a warning.

Non-music performance filtering (CRITICAL):
Exclude the following non-music performances:
- Opening / Closing Ceremonies
- Intermezzo / transitional shows
- Fireworks / drone shows
- Theme shows that are not musical acts
- Interludes / intermissions
- Any short filler content that is clearly not a DJ or live music performance

If a slot's displayName contains keywords like:
- ceremony
- intermezzo
- fireworks
- theme show
- intermission
- interlude
- drone show

and its duration is under 15 minutes, EXCLUDE it.

Only include real music performances:
- DJ sets
- live acts
- b2b sessions
- band performances

JSON schema:
{
  "schemaVersion": "raver_timetable_ai_v3",
  "imageType": "timetable",
  "weeks": [
    {
      "weekIndex": 1,
      "weekLabel": "string or null",
      "days": [
        {
          "dayIndexInWeek": 1,
          "dayLabel": "string or null",
          "weekday": "monday|tuesday|wednesday|thursday|friday|saturday|sunday|null",
          "dateText": "YYYY-MM-DD or null",
          "eventDayRef": {
            "eventDayId": "string or null",
            "weekIndex": 1,
            "dayIndexInWeek": 1,
            "overallDayIndex": 1,
            "date": "YYYY-MM-DD or null",
            "resolutionReason": "string",
            "confidence": 0.0
          },
          "stages": [
            {
              "stageName": "string",
              "order": 1,
              "slots": [
                {
                  "orderInStage": 1,
                  "performerType": "solo|b2b|b3b",
                  "performerNames": ["string"],
                  "displayName": "string",
                  "rawTimeText": "string or null",
                  "startTimeText": "HH:mm or null",
                  "endTimeText": "HH:mm or null",
                  "normalizedStartTime": "HH:mm or 24+ format like 25:30 or null",
                  "normalizedEndTime": "HH:mm or 24+ format like 26:00 or null",
                  "confidence": 0.0,
                  "notes": ["string"]
                }
              ]
            }
          ]
        }
      ]
    }
  ],
  "unparsedTexts": ["string"],
  "warnings": ["string"]
}

Context information:
{{ context_json }}

Please analyze this festival timetable image and return the structured JSON according to the schema defined above.
```

### 8.1 Coze 后台粘贴后的自检清单

在 Coze 后台保存 prompt 后，至少确认以下几点：

1. prompt 中明确写了 `Return ONLY valid JSON`
2. prompt 中明确列出了 `schedule / weeks / eventDays`
3. prompt 中明确要求输出 `schemaVersion = raver_timetable_ai_v3`
4. prompt 中明确要求每个 day 节点输出 `eventDayRef`
5. prompt 中明确写了 “ambiguous => do NOT guess”
6. prompt 中明确写了 “`eventDayRef.eventDayId = null` and add a warning”
7. prompt 中明确保留 `normalizedStartTime / normalizedEndTime`
8. prompt 中没有继续引用 `festivalDayIndex`
9. prompt 中没有继续引用 `eventStartDate / eventEndDate / weekRanges` 作为正式上下文字段

### 8.2 你在 Coze 后台至少要跑的验收样例

把 prompt 替换完后，建议至少用下面 4 类样例做人工验收：

1. 唯一可解析周次样例
   - 图片文字：`Weekend 1 Friday`
   - 期望：输出 `eventDayRef.eventDayId = w1d1`
   - 期望：`warnings` 不包含 ambiguity

2. 同 weekday 跨双周歧义样例
   - 图片文字：`Friday`
   - 上下文里同时存在 `w1d1` 与 `w2d1`
   - 期望：`eventDayRef.eventDayId = null`
   - 期望：`warnings` 包含 ambiguous / manual confirmation 语义

3. 唯一日期样例
   - 图片文字：`2026-07-24`
   - 期望：解析到 `w2d1`
   - 期望：`resolutionReason` 体现来自可见日期文本

4. 跨午夜样例
   - 图片文字：`23:30 - 01:00`
   - 期望：`normalizedStartTime = 23:30`
   - 期望：`normalizedEndTime = 25:00`

### 8.3 Coze 输出不合格时的判定标准

以下任一情况都视为 Coze prompt 仍未调到位：

- 返回内容不是纯 JSON
- 仍返回旧 schema
- day 节点缺少 `eventDayRef`
- 多个 Friday 场景下仍直接猜成某个具体 `eventDayId`
- ambiguity 发生时没有 warning
- 跨午夜时间没有转成 24+ hour wall-clock 格式
- 继续输出或依赖 `festivalDayIndex`

---

## 九、你传给 Coze 的 context 也必须升级

你现在传的是：

- `eventStartDate`
- `eventEndDate`
- `eventTimeZone`
- `dayRolloverHour`
- `weekRanges`

按本方案，必须改成：

```json
{
  "eventTimeZone": "Europe/Brussels",
  "dayRolloverHour": 6,
  "schedule": {
    "mode": "multi_week"
  },
  "weeks": [
    {
      "weekIndex": 1,
      "label": "Weekend 1",
      "startDate": "2026-07-17",
      "endDate": "2026-07-19"
    },
    {
      "weekIndex": 2,
      "label": "Weekend 2",
      "startDate": "2026-07-24",
      "endDate": "2026-07-26"
    }
  ],
  "eventDays": [
    {
      "eventDayId": "w1d1",
      "weekIndex": 1,
      "dayIndexInWeek": 1,
      "overallDayIndex": 1,
      "label": "Weekend 1 Friday",
      "weekday": "friday",
      "date": "2026-07-17"
    },
    {
      "eventDayId": "w2d1",
      "weekIndex": 2,
      "dayIndexInWeek": 1,
      "overallDayIndex": 4,
      "label": "Weekend 2 Friday",
      "weekday": "friday",
      "date": "2026-07-24"
    }
  ],
  "knownStageNames": ["Mainstage", "Library"]
}
```

这一步非常关键，因为只有这样，AI 才能把 `Weekend 1 Friday` 稳定解析成具体日期。

### 9.1 当前代码侧与 Coze 的责任边界

- Coze 后台 prompt：你手动维护，使用本节文档里的正式版本
- `Raver` 服务端：只发送结构化 context，不再代码注入 prompt
- Coze 后台：你手动把本节 prompt 粘贴并保存后，`8.1` 的“替换现有 prompt”才能正式勾上
- `Raver` 服务端：对回包做 schema / eventDayRef / warning 归一化兜底
- iOS 上传页：若结果仍存在未唯一绑定到 `eventDayId` 的 slot，则阻止直接 Apply，要求人工确认

---

## 十、iOS / Web / Server 代码层必须做的改造

### 10.1 iOS

- 重写 `EventUploadDraft` 的时间模型
- 删除基于 `description` marker 的 multi-week 判断
- Timetable slot 改为绑定 `eventDayId`
- Timetable AI 应用结果时保留 `eventDayRef`
- 详情页 Week/Day 分组改为基于 `eventDayId`
- Review 页活动时间摘要改为多个时间段展示

### 10.2 Server

- `/v1/events` create/update 契约升级到 `schedule/weeks/eventDays`
- Timetable canonical model 升级到 `eventDayId`
- 删除 `festivalDayIndex` 作为正式写入入口
- Timetable import 结果归一化升级到 `raver_timetable_ai_v3`
- 识别后应用逻辑必须校验 `eventDayRef`

### 10.3 Web / Admin / Festival Viewer

- 编辑页时间模式改为结构化 `weeks/eventDays`
- 活动摘要改为多个时间段展示
- Timetable 编辑器改为 `Week -> EventDay -> Stage`
- 任何以 `festivalDayIndex` 为核心的逻辑全部替换

---

## 十一、严格拒绝的旧行为

本方案落地后，以下行为全部禁止：

- multi-week 活动只展示一个总起止日期
- `Week 2 Day 1` 继续映射成全局 `Day 1`
- AI 识别结果保留 `weekIndex` 但应用时丢失
- 继续使用 `festivalDayIndex` 作为事件日唯一身份
- 继续把 multi-week 信息藏在 `description` marker 里

---

## 十二、最终结论

这次改造的核心不是“再补一个 week 字段”，而是把：

- `week`
- `event day`
- `slot`

三者的关系彻底结构化。

只要 `eventDayId` 成为全链路唯一日主键，以下问题会同时消失：

- multi-week 被误当 multi-day
- Week 1 / Week 2 同名 Day 冲突
- Timetable AI 无法稳定落到具体日期
- 多周活动时间展示错误
- 编辑回填与详情页分组混乱

这应作为后续活动系统唯一正式模型执行，不再保留旧日程语义。
