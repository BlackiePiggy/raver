# Raver 时间与时区审计清单

审计日期：2026-05-15  
目标：所有上传/提交中涉及真实日期时间的字段必须声明时区；默认业务时区应为北京时间 `Asia/Shanghai`。所有展示出来的真实时间应按用户系统当前时区展示，并明确标注该时区，例如“东京时间”“洛杉矶时间”“北京时间”或 `Asia/Tokyo`。

## 统一规则建议

- 存储层：真实瞬时时间统一存 UTC/ISO instant，数据库 `DateTime` 字段保持可排序、可比较。
- 业务输入层：凡用户输入活动时间、演出时间、签到时间、录制时间、发布时间、封禁时间、过期时间，必须同时确定 `timeZone`。若缺省，使用 `Asia/Shanghai`。
- 活动/演出类时间：应保留活动当地时区字段。国内默认 `Asia/Shanghai`，海外活动允许指定 IANA 时区。
- 展示层：默认按系统/浏览器当前时区格式化，但展示旁边必须标注时区名或偏移，例如 `东京时间`、`洛杉矶时间`、`北京时间`、`Asia/Tokyo`、`UTC+09:00`。
- 相对时间：如“3 分钟前”可以不标注时区；但展开或 hover 的绝对时间应标注时区。
- 非真实日期时间：DJ set tracklist 的 `0:00`、`1:23:45` 是音频偏移，不应套用时区，但 UI 文案应叫“时间戳/播放位置/偏移”，避免误认为日期时间。

## 总体高风险发现

1. 默认活动时区仍是 `UTC`，不符合“默认北京时间”。
   - [server/src/utils/event-timezone.ts](/Users/blackie/Projects/raver/server/src/utils/event-timezone.ts:1)：`DEFAULT_EVENT_TIME_ZONE = 'UTC'`
   - [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:423)：`Event.timeZone @default("UTC")`
   - [server/prisma/migrations/20260515103000_add_event_time_zone/migration.sql](/Users/blackie/Projects/raver/server/prisma/migrations/20260515103000_add_event_time_zone/migration.sql:1)：迁移默认值为 `UTC`
   - [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts:4991)：创建活动缺省 `UTC`
   - [server/src/routes/content-submission.routes.ts](/Users/blackie/Projects/raver/server/src/routes/content-submission.routes.ts:263)：审核提交活动缺省 `UTC`

2. Web 多数时间展示使用浏览器本地时区但没有标注时区。
   - 典型模式：`new Date(value).toLocaleString('zh-CN')` 或 `toLocaleDateString('zh-CN')`
   - 影响页面包括活动列表、活动详情、我的发布、我的 Sets、通知、管理后台、评论、签到页等。

3. Web 活动发布/编辑页用 `new Date('YYYY-MM-DD')`、`getHours()`、`toTimeString()` 等浏览器本地时间逻辑构造活动时间，但没有显式 `timeZone` 输入。
   - 这会导致不同时区设备提交同一个日期时，服务端解释结果不一致。

4. iOS 有较完整的 `timeZone` 字段传递，但默认回退到 `TimeZone.current.identifier`，不符合“默认北京时间”。
   - 对“上传/提交”默认值应从系统时区改为 `Asia/Shanghai`，除非用户显式选择其他时区。

5. 服务端有一些对外文案直接 `toLocaleString`，受 Node 运行环境时区影响，且未标注时区。
   - 例如账号封禁通知到期时间。

## 数据库与模型字段

### 活动与阵容

- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:391)
  - `Event.startDate`、`Event.endDate`：真实活动起止时间。
  - `Event.timeZone`：已有字段，但默认 `UTC`，应改为 `Asia/Shanghai`。
  - `EventLineupSlot.startTime/endTime`、`EventTimetableSlot.startTime/endTime`：阵容/日程真实时间，需要随活动 `timeZone` 解析。
  - 建议：保留 UTC instant 存储，同时活动 `timeZone` 必填，默认 `Asia/Shanghai`。

### 用户行为与内容时间

- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:799)：`Checkin.attendedAt`
- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:1045)：`DJSet.recordedAt`
- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:1247)：`Post.displayPublishedAt`
- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:1502)：分享链接 `expiresAt`
- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:1606)：小队邀请 `expiresAt`
- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:1753)：上传记录 `uploadedAt`
- [server/prisma/schema.prisma](/Users/blackie/Projects/raver/server/prisma/schema.prisma:1890)：通知 `scheduledAt/dispatchedAt`

建议：这些字段如果由系统生成，可存 UTC 并展示时标注系统时区；如果由用户填写，应明确输入时区，默认 `Asia/Shanghai`。

## 服务端上传/提交入口

### 活动创建、编辑、审核

- [server/src/utils/event-timezone.ts](/Users/blackie/Projects/raver/server/src/utils/event-timezone.ts:1)
  - 当前默认 `UTC`。
  - 建议改为 `Asia/Shanghai`，并提供 `formatTimeZoneLabel`/`DEFAULT_DISPLAY_TIME_ZONE_LABEL` 等统一工具。

- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts:4991)
  - BFF Web 创建活动：`body.timeZone ?? body.timezone ?? body.eventTimeZone ?? 'UTC'`
  - 建议：缺省改为 `Asia/Shanghai`；返回活动数据时也返回 `timeZoneLabel` 或前端自行映射。

- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts:5357)
  - BFF Web 编辑活动：若未传时区，沿用 existing，否则 fallback `UTC`。
  - 建议：existing 为空时 fallback `Asia/Shanghai`。

- [server/src/controllers/event.controller.ts](/Users/blackie/Projects/raver/server/src/controllers/event.controller.ts:76)
  - legacy event controller 的 normalize 默认 `UTC`。
  - 建议：全部默认改为 `Asia/Shanghai`。

- [server/src/routes/content-submission.routes.ts](/Users/blackie/Projects/raver/server/src/routes/content-submission.routes.ts:263)
  - 审核流把活动 payload 解析为 `timeZone`，当前缺省 `UTC`。
  - 建议：缺省 `Asia/Shanghai`，并在审核后台展示 payload 时显示“提交时区”。

### 活动图片与阵容图片上传

- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts:1181)
- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts:1311)
- [server/src/routes/event.routes.ts](/Users/blackie/Projects/raver/server/src/routes/event.routes.ts:42)

这些上传使用 `Date.now()` 生成对象 key，只是唯一性时间戳，不直接展示。可不标注时区，但若后台展示“上传时间”，应使用 `uploadedAt/createdAt` 并标注系统时区。

### DJ Set 与 Tracklist

- [server/src/routes/djset.routes.ts](/Users/blackie/Projects/raver/server/src/routes/djset.routes.ts:79)
  - `recordedAt: recordedAt ? new Date(recordedAt) : undefined`
  - 建议：若前端允许填写录制日期/时间，必须传 `recordedAtTimeZone` 或复用默认 `Asia/Shanghai`；服务端需要明确 date-only 字符串如何解释。

- [web/src/components/DJSetUploader.tsx](/Users/blackie/Projects/raver/web/src/components/DJSetUploader.tsx:92)
- [web/src/components/TracklistUploadModal.tsx](/Users/blackie/Projects/raver/web/src/components/TracklistUploadModal.tsx:27)
  - `startTime/endTime` 是音频播放偏移秒数，不是日期时间。
  - 建议：UI 标签改为“播放时间戳/偏移”，不要标“北京时间”。

### 签到

- [server/src/controllers/checkin.controller.ts](/Users/blackie/Projects/raver/server/src/controllers/checkin.controller.ts:33)
- [server/src/routes/bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts:8783)
- [server/src/routes/checkins-v2.routes.ts](/Users/blackie/Projects/raver/server/src/routes/checkins-v2.routes.ts:603)

当前 `attendedAt` 用 `new Date(input)` 或默认 `new Date()`。  
建议：
- 若用户未指定，系统生成当前 instant，可直接存 UTC。
- 若用户选择了参加日期/时间，必须带 `timeZone`，默认 `Asia/Shanghai`。
- 展示签到时间时按系统时区展示并标注。

### 账号封禁、分享、邀请、通知

- [server/src/routes/account-enforcement.routes.ts](/Users/blackie/Projects/raver/server/src/routes/account-enforcement.routes.ts:80)
  - 服务端通知文案直接 `toLocaleString`，未指定时区，取 Node 环境默认时区。
  - 建议：如果这是发给具体用户的文案，应使用用户偏好时区或客户端系统时区展示，并在文案里标注该时区；只有在确实没有用户时区信息时，才退回 `Asia/Shanghai`。

- [server/src/services/share-link.service.ts](/Users/blackie/Projects/raver/server/src/services/share-link.service.ts:719)
- [server/src/services/squad.service.ts](/Users/blackie/Projects/raver/server/src/services/squad.service.ts:384)
- [server/src/services/notification-center/notification-center.service.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-center.service.ts:1947)

这些多为系统 TTL/状态时间，存储可保持 UTC；展示和通知文案需要标注时区。

## Web 前端展示清单

这些地方展示真实日期时间，但多数没有标注时区。

- [web/src/components/EventCard.tsx](/Users/blackie/Projects/raver/web/src/components/EventCard.tsx:27)
  - 活动卡片日期使用浏览器本地时区，方向对，但未显示时区。

- [web/src/app/events/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/page.tsx:51)
  - 活动列表日期拆分月/日，方向对，但未显示时区。

- [web/src/app/events/[id]/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/[id]/page.tsx:85)
  - 活动详情使用 `SCHEDULE_TZ` 格式化部分日程，方向上是在按指定时区渲染。
  - 风险：若产品规则改为“展示层一律跟用户系统时区”，这里需要统一为系统时区展示；如果保留“按活动时区展示日程”，则必须非常明确地显示“以下为活动当地时区”。

- [web/src/app/events/[id]/routine/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/[id]/routine/page.tsx:52)
  - routine 视图同样使用 `SCHEDULE_TZ`，需根据最终规则二选一：
    - 统一改成系统时区展示；
    - 或保留活动时区展示，但显式标注“活动当地时区”。
  - [web/src/app/events/[id]/routine/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/[id]/routine/page.tsx:820)：`new Date().toLocaleString('zh-CN')` 当前时间展示未标注。

- [web/src/app/events/my/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/my/page.tsx:90)
  - “发布时间”“活动时间”未标注时区。

- [web/src/app/my-publishes/page.tsx](/Users/blackie/Projects/raver/web/src/app/my-publishes/page.tsx:35)
  - `formatDateTime` 使用本地时区，展示“发布时间/活动时间”未标注。

- [web/src/app/my-sets/page.tsx](/Users/blackie/Projects/raver/web/src/app/my-sets/page.tsx:29)
  - DJ Set 上传时间未标注。

- [web/src/components/DJSetPlayer.tsx](/Users/blackie/Projects/raver/web/src/components/DJSetPlayer.tsx:501)
  - “视频上传时间”使用 `toLocaleString('zh-CN')`，未标注。

- [web/src/components/TracklistSelectorModal.tsx](/Users/blackie/Projects/raver/web/src/components/TracklistSelectorModal.tsx:93)
  - tracklist 创建日期展示未标注。

- [web/src/components/CommentSection.tsx](/Users/blackie/Projects/raver/web/src/components/CommentSection.tsx:175)
  - 相对时间可保留；超过 7 天 fallback 日期未标注时区。

- [web/src/app/notifications/page.tsx](/Users/blackie/Projects/raver/web/src/app/notifications/page.tsx:122)
  - 小队邀请时间未标注。

- [web/src/app/checkins/page.tsx](/Users/blackie/Projects/raver/web/src/app/checkins/page.tsx:58)
  - 签到时间未标注。

- [web/src/app/community/openim/page.tsx](/Users/blackie/Projects/raver/web/src/app/community/openim/page.tsx:20)
  - IM 管理页时间未标注。

- [web/src/app/admin/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/page.tsx:24)
- [web/src/app/admin/notification-center/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/notification-center/page.tsx:17)
- [web/src/app/admin/account-deletions/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/account-deletions/page.tsx:11)
- [web/src/app/admin/content-reports/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/content-reports/page.tsx:25)
- [web/src/app/admin/account-enforcements/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/account-enforcements/page.tsx:50)
  - 管理后台时间全部应统一用一个 formatter，展示当前系统时区标签。

建议新增 Web 工具：
- `getSystemTimeZone()`：`Intl.DateTimeFormat().resolvedOptions().timeZone`
- `formatDateTimeWithSystemZone(value, locale)`：按系统时区展示，并返回 `{ text, zoneLabel }`
- `zoneLabel` 不要写死中国时区；应按当前系统时区动态映射。`Asia/Shanghai` 可显示为“北京时间”，`Asia/Tokyo` 可显示为“东京时间”，其他时区至少显示 IANA 名称或 `UTC±HH:mm`。

## Web 前端上传/编辑入口

- [web/src/app/events/publish/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/publish/page.tsx:24)
  - `parseLocalDate` 使用 `new Date('YYYY-MM-DD')`。
  - 风险：JS 对 date-only 字符串按 UTC 解析，后续 `getFullYear/getMonth/getDate` 又按浏览器本地时区读，跨时区会偏一天。

- [web/src/app/events/publish/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/publish/page.tsx:63)
  - `buildLineupDateTime` 用浏览器本地时间生成无时区字符串 `YYYY-MM-DDTHH:mm:ss`，但没有提交 `timeZone`。
  - 建议：页面增加“活动时区”选择，默认 `Asia/Shanghai`，提交 `timeZone`。日期构造不要依赖浏览器本地时区。

- [web/src/app/events/my/[id]/edit/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/my/[id]/edit/page.tsx:39)
  - 编辑页同样使用浏览器本地时间拆装活动日期和阵容时间。
  - 建议：编辑页读取 event.timeZone，显示“当前活动时区”，默认北京时间；提交时带回。

- [web/src/app/admin/account-enforcements/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/account-enforcements/page.tsx:130)
  - 自定义封禁结束时间 `new Date(customEndsAt).toISOString()`，输入时区未标明。
  - 建议：表单显示“时间按系统时区/北京时间解释”，并提交明确时区或直接使用带偏移 ISO。

## iOS 客户端

### 统一格式化

- [mobile/ios/RaverMVP/RaverMVP/Core/Date+Formatting.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/Date+Formatting.swift:14)
  - `appDateFormatter(... timeZone: .current)` 默认系统时区。
  - 符合“展示和系统同一时区”，但 UI 文案未统一标注时区。
  - 建议增加 `AppTimeZoneLabel.currentDisplayName`，根据系统时区动态显示“东京时间/洛杉矶时间/北京时间”等。

- [mobile/ios/RaverMVP/RaverMVP/Core/Date+Formatting.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/Date+Formatting.swift:111)
  - `feedTimeText` 是相对时间，可不标注。

- [mobile/ios/RaverMVP/RaverMVP/Core/Date+Formatting.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/Date+Formatting.swift:118)
  - `chatTimeText` 只显示 `HH:mm`，未标注时区。
  - 聊天列表通常可接受，但长按/详情应显示带时区绝对时间。

### 活动编辑/上传

- [mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift:2731)
  - 编辑既有活动时：`event.timeZone ?? TimeZone.current.identifier`
  - 建议：无活动时区时 fallback `Asia/Shanghai`，不是系统时区。

- [mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift:2955)
  - 创建活动提交 `timeZone: eventTimeZoneIdentifier`，方向正确。

- [mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift:3052)
  - 编辑活动提交 `timeZone: eventTimeZoneIdentifier`，方向正确。

- [mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift:178)
  - 活动 start/end 用 `ISO8601DateFormatter` 发给后端。
  - 建议：确认 create/update payload 同时包含 `timeZone`，并在 UI 显示“活动时间按北京时间/活动时区保存”。

### iOS 展示

- [mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:604)
  - 活动日期展示未见时区标签。

- [mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift:1637)
  - 签到时间线按系统时区展示，未标注。

- [mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsView.swift:86)
  - 相对时间可不标注。

- [mobile/ios/RaverMVP/RaverMVP/Features/Profile/SettingsView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/SettingsView.swift:441)
  - 账号状态/报告时间 formatter 需要确认是否标注系统时区。

## 通知调度

- [server/src/services/notification-center/notification-event-countdown.scheduler.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-event-countdown.scheduler.ts:38)
- [server/src/services/notification-center/notification-event-daily-digest.scheduler.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-event-daily-digest.scheduler.ts:56)
- [server/src/services/notification-center/notification-followed-dj-update.scheduler.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-followed-dj-update.scheduler.ts:54)
- [server/src/services/notification-center/notification-followed-brand-update.scheduler.ts](/Users/blackie/Projects/raver/server/src/services/notification-center/notification-followed-brand-update.scheduler.ts:54)

这些模块已有 `timezone/preference.timezone` 设计，方向正确。需核查默认用户偏好是否为 `Asia/Shanghai`，而不是 `UTC`。

## 建议整改优先级

### P0 必改

- 把活动默认时区从 `UTC` 改为 `Asia/Shanghai`：schema、迁移、`event-timezone.ts`、BFF、content submission、legacy event controller。
- Web 活动发布/编辑页增加时区字段，默认“北京时间”，提交 `timeZone: 'Asia/Shanghai'`。
- Web 活动详情/日程页明确显示当前日程时区。

### P1 应改

- 建立 Web 统一时间格式化工具，替换所有 `toLocaleString/toLocaleDateString` 裸调用。
- 建立 iOS 统一时区标签工具，绝对时间展示统一追加系统时区。
- 签到、DJ Set 录制时间、账号封禁时间的用户输入表单补时区说明。

### P2 可后续优化

- 管理后台所有时间列统一显示 `YYYY-MM-DD HH:mm:ss (北京时间/系统时区)`。
- 相对时间 hover/详情展示绝对时间与时区。
- Tracklist UI 把“时间”文案统一成“播放时间戳/偏移”。

## 推荐验收清单

- 在系统时区为 `Asia/Shanghai`、`America/Los_Angeles`、`Europe/Berlin` 的环境分别创建同一个活动，确认日期和阵容时间一致。
- 创建活动不传 `timeZone` 时，数据库 `events.time_zone` 为 `Asia/Shanghai`。
- 所有 Web 绝对时间旁能看到当前系统时区名，而不是固定“北京时间”。
- iOS 活动创建默认业务时区为“北京时间”，但展示层仍跟随系统时区，且允许改为其他 IANA 时区。
- 签到、录制时间、封禁到期时间在前端展示时能看到时区标签。
