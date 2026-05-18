# Event 地址统一展示改造计划（Manual + Map 双轨）

更新时间：2026-04-16 01:35（Asia/Shanghai）

## 1. 目标

在保持现有业务可用的前提下，完成以下改造：

1. 国家与城市保留一套共享字段（`country` / `city`）。
2. 详细地点保留两套：
   - 人工输入（主）
   - 地图定点（辅，`locationPoint`）
3. `festival-viewer` 和 iOS 端的“地址展示”统一为一个长字段（分隔符拼接），不再按层级拆成多段展示文本。
4. 后端落库结构升级，兼容历史数据，支持后续多地图扩展。

## 2. 数据模型方案（确认稿）

### 2.1 Event 表字段设计

共享字段：
- `country`（共享）
- `city`（共享）

人工详细（主）：
- 新增 `manual_location`（JSONB，Prisma 字段：`manualLocation`）
- 兼容同步：`venue_name` / `venue_address` 继续保留，用于旧链路兼容与快速查询

地图详细（辅）：
- 继续使用 `location_point`（JSONB，Prisma 字段：`locationPoint`）

### 2.2 `manualLocation` 结构

```json
{
  "name": "Boat Avenue Lakefront",
  "address": "THA Boat Avenue Lakefront, Phuket",
  "note": "Building B, 3F, Room 301",
  "formattedAddressI18n": {
    "zh": "泰国 · 普吉岛 · Boat Avenue Lakefront · Building B, 3F, Room 301",
    "en": "Thailand · Phuket · Boat Avenue Lakefront · Building B, 3F, Room 301"
  },
  "selectedAt": "2026-04-15T16:00:00.000Z"
}
```

说明：
- `name/address/note` 支持人工输入细节（含楼层、房间、补充备注）。
- `formattedAddressI18n` 用于直接展示。
- 国家/城市不在该对象重复存储，统一走共享字段。

### 2.3 统一展示字符串（两端统一）

展示拼接优先级：
1. `manualLocation.formattedAddressI18n`（按当前语言）
2. `manualLocation` 由 `name/address/note + city/country` 动态拼接
3. `locationPoint.formattedAddressI18n`（按当前语言）
4. `locationPoint.nameI18n + locationPoint.addressI18n + city/country`
5. 兜底 `venueName/venueAddress/city/country`

分隔符统一：` · `

## 3. 需要改造的文件清单（已排查）

### 3.1 后端（server）

1. `/Users/blackie/Projects/raver/server/prisma/schema.prisma`
2. `/Users/blackie/Projects/raver/server/prisma/migrations/*_add_event_manual_location`
3. `/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts`

### 3.2 festival-viewer（web 管理后台）

1. `/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/helpers/00-festival-core-utils.js`
2. `/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/helpers/20-lineup-sync-and-payload.js`
3. `/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/archive/00-asset-mapping.js`
4. `/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/event/location/00-location-state.js`
5. `/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/event/location/20-location-bind-and-sync.js`
6. `/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/save-sync/10-header-and-view-render.js`
7. `/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/event/10-archive-row-render.js`
8. `/Users/blackie/Projects/raver/scrapRave/festival-viewer/css/festival-viewer.css`（样式微调）

### 3.3 iOS

1. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift`
2. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`
3. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`
4. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
5. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
6. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`
7. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift`
8. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift`
9. `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift`

## 4. 分阶段执行路径

### 阶段 A：数据库与 API 模型升级
- 新增 `manual_location` 字段 + migration
- API create/update/list/detail 接入 `manualLocation`
- 与旧 `venueName/venueAddress` 双向兼容

### 阶段 B：festival-viewer 数据链路升级
- `manualLocation` 进入 normalize/map/payload/save
- 列表与详情展示改为统一地址长字段

### 阶段 C：iOS 模型与展示升级
- `WebEvent` 增加 `manualLocation/locationPoint` 结构体
- 新增统一地址计算属性
- 替换所有 Event 位置展示为统一地址字段

### 阶段 D：回归与兼容验证
- 历史数据（无 `manualLocation`）展示正确
- 仅手动/仅地图/两者并存场景都正确
- 编辑后再次打开回填正确

## 5. 实时进度看板（已重构）

### 5.1 历史阶段（已完成）

| ID | 阶段 | 状态 | 更新时间 | 备注 |
|---|---|---|---|---|
| A | 数据库与 API 模型升级 | Done | 2026-04-15 22:35 | 已接入 `manualLocation`（schema/migration/create/update/list/detail） |
| B | festival-viewer 数据链路升级 | Done | 2026-04-15 22:35 | 已完成 normalize/payload/map/header/detail 的统一地址展示 |
| C | iOS 模型与展示升级 | Done | 2026-04-15 22:35 | 已接入 `WebEvent.unifiedAddress` 并替换主要活动展示入口 |
| D | 回归与兼容验证 | In Progress | 2026-04-15 22:35 | 工程编译与测试已过；业务手工回归待你继续验收 |

### 5.2 新需求执行看板（当前以此为准）

| ID | 任务 | 状态 | 当前结论 | 下一步 |
|---|---|---|---|---|
| E0 | 全链路盘点与缺口定位 | Done | web + server + iOS 的新建/编辑/回填/展示已盘点完成，缺口明确 | 进入 E1 |
| E1 | web 表单分层改造（共享层+手填详细层+地图辅助层） | Done | 新增/编辑两处表单均已加入共享层与手填详细层，兼容字段隐藏 | 进入 E2 |
| E2 | web 采集/保存链路对齐（manualLocation 显式采集） | Done | `collectFestivalPayloadFromPanel` 已显式采集 `manualLocation`，并接入 `city/venueName/venueAddress` | 进入 E3 |
| E3 | iOS 编辑链路对齐（提交与回填） | Done | `EventEditorView` 已按 `manualLocation/locationPoint` 显式提交；prefill 优先结构化字段 | 进入 E4 |
| E4 | 轻量模型展示对齐 | Done | `CheckinEventLite`/`MyPublishEvent` 已接入统一地址策略；后端 `checkins`/`publishes/me` 事件载荷补齐 `manualLocation/locationPoint/venue*` | 进入 E5 |
| E5 | 端到端回归与验收 | In Progress | 自动化编译/测试已通过（server build + iOS build + viewer tests） | 执行人工回归清单并记录截图与结果 |

### 5.3 当前执行位（防迷失标记）

- 当前所在：`E5 In Progress`
- 已完成：`E0-E4`
- 阻塞项：无代码阻塞；等待你执行产品侧手工验收并回传问题

## 6. 更新日志

- 2026-04-15：创建本计划文档；完成全链路改造触点排查；进入阶段 A。
- 2026-04-15 22:35：完成阶段 A/B/C 的代码改造并更新进度：后端新增 `manual_location` 与 `manualLocation` 标准化链路；festival-viewer 改为统一地址展示（manual 优先、map 次之、旧字段兜底）；iOS 增加统一地址模型并替换活动相关展示文案。完成验证：`server tsc build`、`festival-viewer node --test`、`xcodebuild`（simulator Debug）。
- 2026-04-15 23:10：按“先盘点再执行”要求，新增第 7/8 节：补齐 web + server + iOS 的新建/编辑/回填/展示全链路触点、当前缺口与待确认执行清单。
- 2026-04-15 23:14：重构第 5 节进度看板为“历史阶段 + 新需求执行看板”，新增 `E0-E5` 任务状态、当前执行位、完成标准（DoD），用于后续持续跟踪。
- 2026-04-15 23:21：开始执行新需求并完成 `E1 + E2`：web 新增/编辑表单加入“共享基础层 + 手填详细层 + 地图辅助层”；保存采集改为显式写入 `manualLocation`；地图组合检索改为优先读取新字段。已通过 `node --check` 与 `festival-viewer node --test`（39/39）。
- 2026-04-16 01:35：完成 `E3 + E4`：iOS 编辑页提交与回填显式对齐 `manualLocation/locationPoint`；`WebFeatureModels` 抽出统一地址解析并复用到 `CheckinEventLite`、`MyPublishEvent`；后端 `checkins` 与 `publishes/me` 的 event 载荷补齐 `manualLocation/locationPoint/venueName/venueAddress`。验证通过：`npm run prisma:generate && npm run build`（server）、`xcodebuild`（iOS）、`node --test`（festival-viewer）。

## 7. 全链路盘点（新建 / 编辑 / 回填 / 展示）

本节是你要求的“查全查清楚”版本，覆盖 web 管理端、后端 API、iOS 端。

### 7.1 web 管理端（festival-viewer）

#### A. 新建活动入口

1. UI 入口与字段定义  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer.html`  
   关键位置：`#add-event-form-panel`（约 1140 行起）  
   当前可见字段：
   - 名称：`nameEn` / `nameZh`
   - 共享层：`sharedCity` / `sharedCountry`
   - 手填详细层：`manualLocationName` / `manualLocationAddress` / `manualLocationNote`
   - 地图定位：`locationPointJson`（隐藏字段 + 地图按钮）
   - 兼容层（隐藏）：`locationEn/locationZh/countryEn/countryZh`

2. 新建弹窗状态与提交  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/import/20-add-event-modal.js`  
   关键职责：
   - 初始化草稿：`ensureAddEventDraftFestival`（含 `manualLocation` 与 `locationPoint`）
   - 提交创建：`confirmAddEventCreate`
   - 复用保存采集函数：`collectFestivalPayloadFromPanel`

#### B. 编辑活动入口（事件列表）

1. 行内编辑弹窗字段定义  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/event/10-archive-row-render.js`  
   关键位置：`.fest-info-edit`  
   当前可见字段：
   - 共享层：`sharedCity` / `sharedCountry`
   - 手填详细层：`manualLocationName` / `manualLocationAddress` / `manualLocationNote`
   - `locationPointJson`（隐藏）
   - 兼容层（隐藏）：`locationEn/locationZh/countryEn/countryZh`

2. 编辑字段回填  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/save-sync/20-brand-binding-and-edit-fields.js`  
   关键职责：
   - 将 `info.city/country` 回填到 `sharedCity/sharedCountry`
   - 将 `info.manualLocation` 回填到 `manualLocationName/manualLocationAddress/manualLocationNote`
   - 将 `info.locationPoint` 写入隐藏字段 `locationPointJson`
   - 同步回填兼容层字段（隐藏）

3. 编辑保存采集  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/save-sync/00-collect-and-save.js`  
   关键职责：
   - 从 `sharedCity/sharedCountry` 采集共享层信息
   - 从 `manualLocationName/manualLocationAddress/manualLocationNote` 显式构建 `manualLocation`
   - 从 `locationPointJson` 或地图状态采集 `locationPoint`
   - 兼容缺失场景下回退 legacy 字段

#### C. 地图定位链路

1. 地图绑定与操作  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/event/location/20-location-bind-and-sync.js`  
   关键职责：
   - 按国家/城市/场所组合词搜索
   - 手动搜索 / 我的定位 / 清空定位
   - 读取与写入隐藏字段 `locationPointJson`

2. 地图弹窗与候选 POI  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/event/location/10-location-picker-modal.js`  
   关键职责：
   - POI 选择、候选列表、POI 详情展示
   - 点击候选切换右上角 POI 详情
   - 确认后回写统一 `locationPoint` 结构

#### D. Web 数据标准化与后端同步

1. 本地 normalize + 统一地址拼接  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/helpers/00-festival-core-utils.js`  
   关键职责：
   - `normalizeFestivalManualLocation`
   - `normalizeFestivalLocationPoint`
   - `formatFestivalUnifiedAddress`（展示优先级）

2. Upsert payload 构建  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/helpers/20-lineup-sync-and-payload.js`  
   关键职责：
   - `buildBackendEventUpsertPayload` 合并 `venueName/venueAddress` 与 `manualLocation/locationPoint`
   - 产出用于后端 create/update 的统一 payload

3. 持久化到后端  
   文件：`/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/helpers/30-backend-sync-persist.js`  
   关键职责：
   - 查找 existing event
   - create 或 update
   - 图片资产 patch

### 7.2 后端（server）链路盘点

1. 数据表与迁移  
- `/Users/blackie/Projects/raver/server/prisma/schema.prisma`：`Event.manualLocation`、`Event.locationPoint`
- `/Users/blackie/Projects/raver/server/prisma/migrations/20260415190000_add_event_manual_location/migration.sql`

2. API 入参与校验（create/update）  
文件：`/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts`  
关键职责：
- create：校验并归一化 `manualLocation`、`locationPoint`，写入 `events`
- update：支持部分字段 patch，支持 `manualLocation/locationPoint` 的清空与更新
- mapEvent：列表/详情返回时同时回传 `manualLocation/locationPoint`
- checkins/publishes：轻量 event 载荷补齐 `manualLocation/locationPoint/venueName/venueAddress`，供 iOS 轻量模型统一展示

### 7.3 iOS 端链路盘点

#### A. 入口（新建/编辑）

1. 入口路由  
文件：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`  
关键职责：
- 新建：`EventEditorView(mode: .create)`
- 编辑：先 `fetchEvent(id:)`，再 `EventEditorView(mode: .edit(event))`

#### B. 编辑页（字段、地图、提交）

1. 编辑表单字段  
文件：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`  
当前可见字段：
- `city`、`country`（共享层）
- `venueName`、`venueAddress`（手填详细层）
- 地图选点入口（MapKit）

2. 地图选点回填策略  
同文件关键逻辑：
- 选点后回填 `pickedLatitude/pickedLongitude/pickedMapAddress`
- 同步覆盖 `venueAddress`，可回填 `city/country/venueName`

3. 提交 payload（create/update）  
同文件 `save()` 关键逻辑：
- create/update 显式提交：`manualLocation`、`locationPoint`、`city/country/venueName/venueAddress/latitude/longitude`
- `manualLocation` 由 `venueName/venueAddress + city/country` 组合构建；`locationPoint` 由选点结果构建

4. 编辑回填  
同文件 `prefillIfNeeded()`：
- 优先从 `event.manualLocation/event.locationPoint` 回填 `venue/address/坐标`
- legacy 字段作为兜底回填来源

#### C. iOS 模型与展示

1. 事件模型与统一地址  
文件：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift`  
关键职责：
- `WebEvent` 已包含 `manualLocation/locationPoint`
- `WebEvent.unifiedAddress` 已按 manual > map > legacy 优先级展示

2. 活动地址展示使用点（主要）  
已改为使用 `event.unifiedAddress` 或 `event.summaryLocation` 的核心页面包括：
- `MainTabView.swift`
- `EventDetailView.swift`
- `EventPresentationSupport.swift`
- `DJsModuleView.swift`
- `LearnModuleView.swift`
- `ProfileView.swift`
- `MyPublishesView.swift`
- `MyCheckinsView.swift`
- `SetsModuleView.swift`
- `RecommendEventsModuleView.swift`
- `EventCalendarSupport.swift`

3. 补充说明  
- `CheckinEventLite` 与 `MyPublishEvent` 已扩展 `manualLocation/locationPoint/venue*` 并复用统一地址解析函数。
- 后端 `/v1/checkins` 与 `/v1/publishes/me` 已回传上述字段，避免轻量模型退化为仅 `city/country`。

### 7.4 问题状态说明（原“看不到分层输入”问题）

该问题已解决：

1. 新增与编辑表单均已展示“共享层 + 手填详细层 + 地图辅助层”。
2. 旧字段保留为兼容层并隐藏，不影响当前编辑体验。
3. 保存链路改为“显式采集 manualLocation”，不再仅靠 legacy 推导。

## 8. 剩余任务与下一阶段

### 8.1 当前剩余任务（E5）

1. Web 管理端人工回归：

给每个web端编辑活动信息处和新增活动信息处给一个手动给出定位的相关信息的填写入口。按下这个按钮会弹出一个填写表单，要求和主题外观相符合，然后里面应该按照数据库里面的字段格式一样，例如要给出来源、经纬度、地点名称等信息，这里你来帮我按照数据库中的字段补齐。这样我就可以手动去一些地图搜索，然后将搜索到的结果粘贴在这里面实现手动添加。然后还要增加一个按钮，是可以复用其他event的地址。例如我2025年的tomorrowland在一个地方举行，那么我2026年的tomorrowland也在同一个地方举行，那么此时我就可以直接点击复用按钮弹出一个窗口，这个窗口里面左边可以选择复用event来源，里面支持搜索所有给了定位信息的event，然后只支持单选一个事件。右边可以搜索全量event，包含已经添加定位信息的event和 未添加信息的event，然后可以单击列表中的事件加入批量复用列表。最后可以一键将右侧列表里面的定位信息全部复用左边选中的那个事件的定位信息。原本没有定位信息的event直接填写这个信息，原本有定位信息的直接覆盖。

- 新建 Event：仅共享层、仅手填详细层、仅地图点位、手填+地图并存
- 编辑 Event：修改后再次进入弹窗，检查共享层/手填层/地图层回填一致
- 地图绑定后刷新页面，确认 `locationPoint` 不丢失

2. iOS 端人工回归：
- 编辑已有 Event 并保存，确认再次打开仍能回填结构化地址
- `MainTab` / `EventDetail` / `MyCheckins` / `MyPublishes` 地址展示是否符合统一优先级
- 历史无 `manualLocation/locationPoint` 数据是否正常兜底显示

3. 联调回归记录沉淀：
- 建议在本文件追加“回归结果表”（场景、预期、结果、截图路径、结论）

### 8.2 下一阶段建议（E5 完成后）

1. 地址字段治理：
- 评估在 API 层提供 `displayAddress` 聚合字段，降低多端重复拼接逻辑

2. 多地图扩展准备：
- 将 `locationPoint.provider/sourceMode` 做白名单校验
- 完成 provider 维度的回归样例（AMap / MapKit）

3. 运维与质量保障：
- 增加 `manualLocation/locationPoint` 的契约测试（schema + API + iOS decode）
- 为关键保存链路补一条端到端自动化冒烟脚本

### 8.3 E5 完成标准（DoD）

1. 回归清单全通过，关键路径无回归。
2. 新建/编辑/重开回填在 web 与 iOS 两端表现一致。
3. 本文档进度看板与回归结论同步更新到最新状态。
