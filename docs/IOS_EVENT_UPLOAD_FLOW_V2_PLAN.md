# iOS 活动上传流程 V2 落地方案

## 背景

当前 iOS 活动上传入口会进入 `EventEditorView`。它已经覆盖新增/编辑活动、封面/阵容图上传、时区、地图选点、舞台、阵容、票档等能力，但整体是一个长表单，字段密度高，用户需要一次性理解很多信息。附件 `event_upload_dark_v3.html` 提供的是一个 10 步移动端原型，适合拆解上传流程，但其中存在明显 Web 原型痕迹，例如 hover/cursor、固定 335px 手机容器、纯深色样式、步骤过碎、部分字段与当前 API/审核机制不完全一致。

本方案目标是先把新上传流程独立设计清楚，后续实现时能并行开发、灰度切换，不影响现有 `EventEditorView`。

## 目标

- 新建一套独立的 iOS 活动上传流程，命名建议为 `EventUploadFlow`，不直接改造旧 `EventEditorView`。
- 支持 light/dark 两套主题，全部使用 `RaverTheme` token，不复刻 HTML 中的固定深色变量。
- 适配 App 端交互习惯：无 hover，无 Web 状态栏假壳，使用系统导航、sheet、PhotosPicker、Map picker、DatePicker、Picker、底部固定操作区。
- 降低用户认知负担：从“长表单”改成“分组步骤 + 草稿保存 + 最终预览提交”。
- 保留项目现有能力：城市时区确认、地图选点、活动类型、舞台排序、阵容导入、轻量票务、内容审核返回。
- 对齐 `festival-viewer` 的六种图片分区：`poster / lineup / timetable / cover / map / other`。
- 为后续直接替换当前上传页做隔离：新增和编辑入口都切 route 或 feature flag，不迁移旧页面内部状态。

## 进度跟踪

- [x] 新建独立 `EventUploadFlow`，与旧 `EventEditorView` 路由隔离
- [x] 新增/编辑共用新上传 UI，并支持本地草稿恢复
- [x] 第一页六种图片分区、单列布局、仅相册上传、双主题适配
- [x] 基础信息页接入主办方绑定、时区绑定、详细地址与地图选点解耦
- [x] 活动时间页支持单日 / 多日 / 多 Week 与高级跨天切日设置
- [x] 时间表页支持 Week 维度编辑、舞台排序、节目折叠卡片编辑
- [x] 仅阵容页支持单独维护 lineup，并与 timetable 路径分离
- [x] 票务改为多票档录入，并新增提交前 review 页
- [x] 搜索绑定改为实时候选 + 行内反馈，移除输入时全局 alert 打断键盘
- [x] 编辑保存一致性补扫一轮：活动名、主办方、原文链接、时区、地图选点、详细地址回填与提交链路已对齐
- [x] 活动日期/时区逻辑改为对齐 festival-viewer：按活动时区解释 date-only，避免 Seoul 等时区出现选 6/13 保存后变 6/14
- [x] 多语言字段改为“默认仅编辑系统语言字段 + 可展开补充其他语言”，覆盖活动名称/城市/国家/详细地址
- [x] 提交 mapper 移除自动把默认语言复制到其他语言字段的逻辑；未手填的多语言字段保持为空
- [x] 时间表时间选择与展示改为显式使用活动时区，对齐 festival-viewer 的 wall-clock 语义
- [x] AI 时间表识别结果页改为默认折叠确认态，并支持行内 DJ 搜索、候选绑定、自动匹配与计时反馈
- [x] AI 时间表识别结果页的 Day 标签以 `festivalDayIndex` 为准展示为数字 Day，避免回显 weekday 文本
- [x] 地图选点确认改为优先保留用户点中的搜索候选，避免确认后被附近其他 POI 覆盖
- [x] 时间表跨日时间展示优化为“次日 HH:mm”，覆盖上传编辑页与 Coze 识别回填页
- [x] 时间表 DJ 卡片编辑态新增开始/结束“当日/次日”选择；Coze 返回 `25:00` 会转成“次日 01:00”继续编辑
- [x] 修复后端 lineupSlots 显式 Day 归一化抹掉“次日”偏移的问题，避免保存后回填成当日凌晨
- [x] 统一详情页时间表 list/timeline 与上传编辑页的次日时间文案：`次日00:00-02:00`、`23:30-次日01:30`
- [x] 补齐旧编辑页时间表摘要的次日文案，避免出现 `23:30-01:30 次日` 这类后缀式表达
- [x] Coze 时间表识别改为异步 job：创建任务立即返回 `jobId`，iOS sheet 轮询状态并保留 AI thinking 计时反馈
- [x] 新增 DJ 批量精确匹配接口，时间表 AI 一键匹配从多次串行 `/v1/djs` 改为一次轻量批量匹配
- [x] Coze workflow 后端默认超时从 120 秒提高到 300 秒；线上如配置 `COZE_WORKFLOW_TIMEOUT_MS` 需同步设置为 `300000` 或更高
- [ ] 对照 Discover「流派树」与 iOS 上传页继续细收搜索交互细节
- [ ] 继续做一轮真机/模拟器走查，收剩余排版与交互边角

## 不做的事

- 不在 V2 里直接删除或重构旧 `EventEditorView`。
- 不把 HTML 原型原样搬进 SwiftUI。
- 不新增后端字段前先假装支持。六种图片分区需要和 `festival-viewer` 当前同步模型对齐；如果 iOS 现有 BFF 只支持 `coverImageUrl` / `lineupImageUrl`，实现前需要补齐对应 asset API 或映射层。
- 不把所有高级信息强制填完；活动上传应允许“先发基本活动，再逐步补齐”。

## 推荐流程

HTML 原型是 10 步。我建议 App 端合并为 6 个主步骤，内部用可展开区域承载高级项：

1. **媒体与识别**
   - 必填：至少 1 张 `poster` 图片；不允许无图创建。`festival-viewer` 的新增活动也应参考同样校验。
   - 图片分区与 `festival-viewer` 完全对齐：`poster / lineup / timetable / cover / map / other`，每区支持多张。
   - AI 识别首版不实现，只保留按钮。按钮应有明显“智能感”：彩色渐变、微光边框、sparkles 图标、按下反馈，但点击后提示“即将支持”或进入占位说明。
   - App 适配：只使用照片选择器，不接拍照入口；图片卡片支持删除、排序、预览，不使用 hover。

2. **基础信息**
   - 活动名称必填。
   - 活动类型使用现有 `EventTypeOption`。
   - 活动简称可选，例如 `A State of Trance` 可填 `ASOT`，用于活动搜索命中。
   - 城市、国家、详细地址必填；地图坐标可选。
   - 不要求用户手动补齐多语言。根据系统语言决定当前填写哪个字段：中文系统优先写 zh，英文系统优先写 en，日文系统可写 ja/或先落到当前已有兼容字段；自动翻译/补齐以后再做。
   - AI 识别结果首版不落地，只保留入口。

3. **时间与时区**
   - 开始日期、结束日期必填。
   - 时区继续沿用当前逻辑：必须通过城市搜索候选确认，避免跨时区活动保存错误。
   - 多 Week 是核心需求，不能藏成边角能力。单日、多日、多 Week 都应在时间步骤内清楚选择。
   - 时间表必须支持跨天，例如 23:00-02:00。策略对齐 `festival-viewer`：使用 `dayRolloverHour`，默认建议 6 点；当结束时间不晚于开始时间时，按次日结束处理。

4. **地点**
   - 地图选点前移到基础信息步骤中，不再保留独立地点页。
   - 手动地址不是兜底，而是最低必填信息的一部分：城市、国家、详细地址必须填写。
   - 选点与详细地址解耦，只保存地图场地/坐标/地图地址，不覆盖用户手填详细地址。
   - UI 上展示一个可点击位置入口和坐标摘要，避免地图候选列表互相遮挡。

5. **时间表**
   - 舞台信息和 Timetable 独立为一个步骤。
   - 先维护舞台列表，排序规则与 `festival-viewer` 一致，影响详情页 timetable 展示顺序。
   - 时间表可以完全跳过；只有实际新增 timetable slot 时才校验条目完整性。舞台名留空时默认展示为“主舞台”。
   - TimeTable 先展示各 Week 总览卡，再进入对应 Week 的编辑页。
   - 每个节目都必须填写艺人、开始时间、结束时间；艺人确认后默认展示为非编辑态，减少页面占用。
   - 时间表支持跨天，继续沿用 `dayRolloverHour` 语义。

6. **仅阵容**
   - 单独提供一个只填写 lineup 的页面，用于未知舞台和具体演出时段时先补充阵容。
   - 支持手动添加 DJ、搜索绑定已有 DJ、设置 solo/b2b/group。
   - 阵容图识别进入草稿，不直接写入最终表单，继续沿用当前“导入草稿可编辑再应用”的安全设计。

7. **票务与提交**
   - 只做简单票务：多个可选票档、币种、跳转链接。
   - 购票链接保留独立一行输入。
   - 提交后根据 `CreateEventResult` 展示两种成功态：
     - 管理员直接创建：可返回活动页，也可进入活动详情。
     - 普通用户提交审核：展示审核中状态，提示“可在我的发布中查看进度”，并提供返回活动页。

## 页面结构

建议的 SwiftUI 结构：

```text
Features/Discover/Events/UploadFlow/
  EventUploadFlowView.swift
  EventUploadFlowViewModel.swift
  EventUploadDraft.swift
  EventUploadStep.swift
  EventUploadValidation.swift
  EventUploadMappers.swift
  EventUploadDraftStore.swift
  EventUploadAnalytics.swift
  Components/
    EventUploadProgressHeader.swift
    EventUploadBottomBar.swift
    EventUploadImagePickerCard.swift
    EventUploadFieldSection.swift
    EventUploadSuggestionRow.swift
    EventUploadReviewSection.swift
```

隔离原则：

- `EventUploadDraft` 是 V2 的唯一 UI 草稿模型。
- `EventUploadMappers` 负责把 draft 转成 `CreateEventInput` / `UpdateEventInput` / `EventLineupSlotInput`。
- 上传、创建活动仍通过现有 `EventCommandRepository`、`EventMediaRepository`、`DJListRepository`、`WebFeatureService`。
- 旧 `EventEditorView` 不依赖 V2，V2 也不反向调用旧 View。
- 新增和编辑都使用 `EventUploadFlowView`。编辑态由已有 `WebEvent` hydrate 成 draft，提交时走 update；新增态从空 draft 或本地草稿开始。
- 路由入口建议从 `.eventCreate` 切到：

```swift
if featureFlags.useEventUploadFlowV2 {
    EventUploadFlowView(mode: .create) { ... }
} else {
    EventEditorView(mode: .create) { ... }
}
```

编辑入口同理：

```swift
if featureFlags.useEventUploadFlowV2 {
    EventUploadFlowView(mode: .edit(event)) { ... }
} else {
    EventEditorView(mode: .edit(event)) { ... }
}
```

## 草稿模型

建议 draft 覆盖当前 `CreateEventInput` 所需字段，同时预留 UI-only 状态：

```text
EventUploadDraft
  media
    zones
      poster[]
      lineup[]
      timetable[]
      cover[]
      map[]
      other[]
  basic
    name
    abbreviation
    eventType
    localizedNameFields
    localizedCityFields
    localizedCountryFields
    localizedAddressFields
    preferredInputLanguage
  time
    startDate
    endDate
    timeZoneIdentifier
    selectedTimeZoneLookup
    scheduleMode: singleDay | multiDay | multiWeek
    isWeekScheduleEnabled
    dayRolloverHour
  location
    manualAddressZh / manualAddressEn
    latitude / longitude
    pickedMapAddress
    pickedPlaceName
  lineup
    stageEntries
    lineupSlots
    importDraft
  tickets
    ticketUrl
    ticketCurrency
    ticketPriceMin
    ticketPriceMax
  ui
    currentStep
    dirty
    validationErrors
    uploadProgress
```

本地草稿策略：

- 使用 `Codable` 保存表单 JSON，按 `eventUploadDraft.create.<userId>` 和 `eventUploadDraft.edit.<eventId>.<userId>` 区分。
- 图片不塞进 JSON。将待上传图片复制到 App sandbox 临时草稿目录，draft 只保存本地文件 URL、zone、排序、原始文件名、尺寸、mimeType。
- 自动保存触发：字段变更 debounce 1 秒、切后台、离开页面前。
- 草稿保留 14 天；提交成功后清理对应草稿；用户手动放弃时二次确认并删除。
- 新建活动只保留每个用户最近 1 份未提交草稿；如果再次进入上传页，先询问“继续上次草稿/重新开始”。
- 编辑活动每个 event id 独立保存，避免覆盖新增草稿。

## V2 首版接口字段

V2 新建和编辑活动仍走现有 BFF：

- `POST /v1/events`
- `PATCH /v1/events/:id`
- `POST /v1/events/upload-image`
- `GET /v1/event-timezones/search`
- `GET /v1/djs`

活动 create/update payload 首版覆盖：

- 基础：`name`、`abbreviation`、`eventType`、`city`、`cityI18n`、`country`、`countryI18n`
- 地点：`manualLocation`、`locationPoint`、`latitude`、`longitude`
- 时间：`startDate`、`endDate`、`timeZone`、`timeZoneCity`、`timeZoneProvince`、`timeZoneCountry`、`timeZoneStateAnsi`、`timeZoneLat`、`timeZoneLng`、`dayRolloverHour`
- 媒体：`coverImageUrl`、`lineupImageUrl`、`imageAssets`
- 阵容/时间表：`stageOrder`、`lineupSlots`
- 票务：`ticketUrl`、`ticketCurrency`、`ticketTiers`
- 状态：`status`

`imageAssets` 对齐 `festival-viewer` 六区：

- `poster`
- `lineup`
- `timetable`
- `cover`
- `map`
- `other`

后端 create 现在对所有角色强制 poster 资产；普通用户提交审核和管理员直发都不能创建无 poster 活动。编辑暂不强制 poster，用于兼容旧活动逐步补齐。

## 校验策略

每一步只校验“继续下一步必须知道的信息”，最终提交做全量校验。

## 当前执行进度

- [x] 新上传入口与编辑入口切到 `EventUploadFlowView`
- [x] 第 1 页改为单列图片上传，移除拍照与已上传图片的重新上传按钮
- [x] AI 入口移动到基础信息页顶部
- [x] 基础信息页接入主办方搜索绑定、原文链接单独一行、时区搜索前移
- [x] 地图选点前移到基础信息页，并移除地图页“附近推荐地点 / pin 周围 POI”遮挡层
- [x] 地图选点与手填详细地址解耦，地图结果只保存场地/坐标信息，不再覆盖详细地址
- [x] 活动周期页支持单日 / 多日 / 多 Week，并支持每个 Week 独立日期范围
- [x] 时间表页支持先维护舞台顺序，再按 Week 进入编辑
- [x] 时间表步骤改为完全可跳过；仅当用户实际填写 timetable 时，才要求舞台、时间与 Week 编辑
- [x] 只填 lineup 的页面与 timetable 页面拆开，保持两条独立录入路径
- [x] 纠正“lineup-only 自动推断 timetable 逻辑”的错误方向，恢复为与 festival-viewer 对齐的独立路径
- [x] 修复独立模块中的脏字符编译错误，恢复主工程可编译状态
- [x] 第 2 页：主办方 / 时区一旦绑定后，输入框进入显式锁定态，只能手动清除后重新搜索
- [x] 第 3 页：移除“周期概览”，跨天切日时间改为默认折叠的高级选项
- [x] 第 3 页：单日 / 多日 / 多 Week 模式按钮完成一轮更移动端化的视觉收紧
- [x] 第 3 页：多 Week 日期改为固定短格式 `yyyy/M/d` 展示，并改用独立选日面板避免样式跳变
- [x] 第 1 页：图片分区标题下的解释性文字已移除，保留更紧凑的单列上传卡片
- [x] 第 2 页：移除简介字段，替换为活动简称字段，并接入 event create/update payload
- [x] 第 2 页：活动简称已接入后端 event 字段与活动搜索，聚合搜索和活动列表搜索均可命中简称
- [x] 第 2 页：地图选点已移到详细地址下方，改为小按钮触发，并补齐绑定态展示
- [x] 编辑回填：时区搜索词优先保持英文 / ASCII，避免 `Hong Kong` 被回填成 `香港` 导致再次提交异常
- [x] lineup-only 数据结构支持 B2B / B3B 多成员：新增成员名与成员 DJ 绑定顺序字段，避免只保存第一个 DJ
- [x] iOS 阵容 tab / 编辑回填支持从 `lineupArtists.members / djs / memberDjIds / memberNames` 恢复多成员头像、名称与绑定态
- [x] 编辑保存一致性：`name` / `nameI18n` 已双写，避免只改当前语言后列表仍显示旧值
- [x] 编辑保存一致性：主办方手填与绑定都已进入 iOS create/update payload，`wikiFestivalId` 与 `organizerName` 可正确回填、改绑与清空
- [x] 编辑保存一致性：原文链接字段改为对齐后端 `sourceEventUrl`，编辑回填优先读取 `sourceEventUrl`，旧数据兼容回退 `officialWebsite`
- [x] 编辑保存一致性：上传流程在未提供“官网链接”UI 的前提下，不再在编辑提交时误覆盖后端 `officialWebsite`
- [x] 编辑保存一致性：时区、地图选点、详细地址、城市国家的回填与清空链路已再核查一轮，并保留解耦关系
- [x] 活动日期选择改造：Create / Update payload 提交日期时不再发本地时区 ISO 时间，而是像 festival-viewer 一样按活动时区编码为 `YYYY-MM-DD`
- [x] 活动日期显示改造：时间页日期选择器、Week 日期选择器、Week 摘要、review 日期摘要均切到活动时区显示
- [x] 活动日期回填改造：编辑已有 event 时，先按 event 自身时区归一化为 date-only 再进入表单，避免回填后日期偏移
- [x] 活动时区切换改造：切换城市时区时保留用户已选的“日历日期”不变，仅重新按新时区解释并提交
- [x] server canonical event artist 同步支持成员顺序、未绑定成员占位和成员名快照
- [x] festival-viewer 的 `lineupArtists` 归一化与后端映射支持 `memberNames` / `memberDjIds`
- [x] 活动上传链路中的 `lineupArtists` 已停止使用旧 `djIds`，统一迁移到 `memberDjIds / memberNames`
- [x] 活动时间表槽位主链路已开始统一到 `memberDjIds / memberNames`，server / festival-viewer / iOS mapper 已同步
- [x] 编辑活动提交流程已补齐 `lineupSlots` 更新映射，避免 timetable 编辑不生效
- [x] 第 1 页图片卡片继续收紧排版，与附件 html 的移动端层级更贴近（已按最新要求改回单列，并移除每个图名下的解释文字）
- [x] Week 时间表编辑页继续优化完成态卡片：已添加 DJ 展示为头像 + 名称 + 时间信息，减少编辑态挤占
- [x] Week 时间表编辑页继续优化操作流，改为与 lineup-only 一致的展开 / 确定 / 收起 / 编辑节奏
- [ ] lineup-only 页面继续向 festival-viewer 的纯阵容录入方式收口
- [x] lineup-only 页面已继续向附件 html 第 8 页靠一轮：补齐更清晰的概览头部、计数摘要、阵容卡分层和成员绑定状态展示
- [x] 第 5 页阵容概览已压缩成单行摘要，移除大面积统计块与说明文案
- [x] 第 5 页“添加阵容”已放到已添加内容下方，录入顺序更贴近附件 html
- [x] 第 5 页单个阵容单元支持“确定后收起成轻量卡片，点击编辑再展开”
- [x] 第 3 页：单日 / 多日 / 多 Week 模式已移除 icon 与解释性副文案；单日模式只保留一个日期选择器
- [x] 第 3 页：`跨天切日时间` 上方补齐 `高级选项` 小标题，括号说明拆成换行小字
- [x] 第 4 页：Week 时间表编辑页顶部已收敛为 `Week X + 时间跨度`，移除多余概览信息
- [x] 第 4 页：删除舞台时会同步清理相关 timetable 草稿，修复“已删光舞台仍提示至少添加 1 个舞台”的残留校验
- [x] 第 4 页：时间表校验不再强制必须存在舞台；空舞台名按“主舞台”归一，时间表为空时可直接下一步
- [x] 第 3 页：活动周期单日 / 多日 / 多 Week 卡片高度继续降低，单日日期选择器居中，并在日期附近展示当前绑定时区
- [x] 第 4 页：舞台支持上下移动排序，多个舞台不允许重名，多个空舞台会按“主舞台”重复拦截
- [x] 第 4 页：Week 编辑页的“在当前 Week 添加节目”按钮移到节目列表底部，新节目默认展开编辑
- [x] 第 6 页：票务改为可跳过的多票档数组，票档名称可选、价格必填；提交前检查拆成独立最后一步
- [x] 搜索体验：城市时区、主办方、DJ 绑定输入时会实时 debounce 给出候选结果
- [ ] 第 5 页轻量卡片继续细修：补充更像附件 html 的收起态密度、按钮对齐与层级节奏
- [ ] 最终再做一轮 Light / Dark 主题细节 polish
- [x] 完整 build 验证并回填本 md 的最终状态
- [x] iOS 连带页面（DJ 详情 / 活动详情 / 我的 checkins 等）残余 `slot.djIds` 引用全部清理并再次完成全量 build

- 媒体：`poster` 至少 1 张；无 poster 禁止进入最终提交。
- 基础信息：活动名称必填。
- 时间：开始/结束日期必填，结束不能早于开始，时区必须从候选确认。
- 地点：城市、国家、详细地址必填；地图坐标可选。
- 阵容：没有阵容可以跳过；如果已有 pending lineup entry，必须确认或删除。
- 时间表：支持跨天；`dayRolloverHour` 默认为 6，允许高级设置。
- 票务：URL 格式校验；票档可为空，新增票档后价格必须是合法数字，票档名称可选；币种标准化为大写。

## 主题与视觉

使用 `RaverTheme.background`、`RaverTheme.card`、`RaverTheme.cardBorder`、`RaverTheme.primaryText`、`RaverTheme.secondaryText`、`RaverTheme.accent`。

视觉优化建议：

- 不使用 HTML 里的全紫单色方案，紫色只做进度、主按钮和选中态。
- AI 按钮可例外使用多色渐变，但只作为单个智能入口，不扩大成整页色彩主题。
- 表单区域用系统背景 + 轻量 section，不做卡片套卡片。
- 底部操作区固定：左侧上一步/保存草稿，右侧下一步/提交。
- 进度条用“当前步骤 + 总步骤 + 可点击步骤列表”，不要 10 个小圆点挤满顶部。
- 文案贴近 App：少解释功能，多给动作和当前状态。
- Light 模式下避免浅紫大面积铺底；Dark 模式下避免所有层级都是接近黑色。
- 主题跟随系统，不在 V2 内额外做主题切换。

## HTML 原型取舍

保留：

- 分步上传的节奏。
- 媒体先行，帮助后续 AI 识别。
- 舞台、Week/Day、Timetable、Lineup、票务的完整信息结构。
- 最终成功态。

调整：

- 10 步合并为 6 步。
- 多 Week 从高级开关提升为核心选择。
- Timetable 不单独做多个编辑页，合并进 lineup slot。
- 图片类型对齐 `festival-viewer` 六区资产模型；`coverImageUrl` / `lineupImageUrl` 只作为兼容展示字段。
- Hover/cursor/固定手机壳全部移除。
- 顶部或媒体区保留 AI 按钮，但首版只做占位，不接识别能力。

## 与现有后端/API 的关系

当前 iOS 可用能力：

- `POST /v1/events`
- `PATCH /v1/events/:id`
- `POST /v1/events/upload-image`
- `POST /v1/events/lineup/import-image`
- `GET /v1/djs?search=`
- 城市时区搜索由 `webService.searchEventTimezones` 支撑。
- `festival-viewer` 的图片分区资产模型：`poster` -> backend type `other` + label `POSTER`，`lineup` -> `luall`，`timetable` -> `tt`，`cover` -> `cover`，`map` -> `other` + label `MAP`，`other` -> `other`。

需要注意的提交顺序：

1. 管理员直接发布：
   - 上传/准备六区图片资产。
   - 创建或更新 event。
   - 将图片资产绑定到 event，并同步主要兼容字段。
   - 成功页提供“返回活动页”和“查看活动”。
2. 普通用户提交审核：
   - 不直接创建公开 event。
   - 先上传图片到临时/审核可访问资产区，或由后端提供 content-submission 附件能力。
   - 提交 `ContentSubmission`，payload 包含活动字段、六区图片 asset 引用、lineup/timetable、票务。
   - 审核通过后由后台创建 event 并绑定资产。
   - 成功页提示“已提交审核，可在我的发布中查看进度”，主按钮返回活动页。

如果当前后端还没有“投稿携带六区图片资产”的能力，需要把它列为 V2 实现前置项，否则普通用户上传图片无法进入审核链路。

## 已确认决策

1. `poster` 图片必填，不允许无图创建；`festival-viewer` 新增活动也要补同等校验。
2. 图片逻辑对齐 `festival-viewer` 六区：`poster / lineup / timetable / cover / map / other`。
3. 六区图片都需要保存，展示和同步策略沿用 `festival-viewer`。
4. AI 识别首版不实现，只保留一个高质感智能按钮。
5. 管理员可直接发布；普通用户必须走审核。
6. 地点最低要求：城市、国家、详细地址；地图坐标可选。
7. 不要求用户补多语言；按系统语言决定写入哪个语言字段，自动补齐以后再做。
8. 多 Week 是核心需求。
9. Timetable 支持跨天，逻辑对齐 `festival-viewer` 的 `dayRolloverHour` 和结束时间次日处理。
10. 票务只做简单票价和跳转链接，不做库存/开售停售/售罄。
11. 草稿使用本地草稿，策略见上文。
12. 编辑页面也使用这一套 UI，编辑态要完整适配。
13. 发布/提交成功后可以选择返回活动页，并提示用户可在我的发布查看。
14. 需要埋点。
15. 主题跟随系统。

## 埋点建议

- `event_upload_v2_opened`：mode、source、hasDraft。
- `event_upload_v2_step_viewed`：step、mode。
- `event_upload_v2_step_completed`：step、duration、validationErrorCount。
- `event_upload_v2_ai_placeholder_tapped`：sourceStep。
- `event_upload_v2_draft_saved`：mode、imageCount、fieldCount。
- `event_upload_v2_submit_tapped`：mode、role、imageZoneCounts、hasLineup、hasTimetable、scheduleMode。
- `event_upload_v2_submit_succeeded`：mode、resultType(created/submittedForReview)、duration。
- `event_upload_v2_submit_failed`：mode、errorCode、failedStage。
- `event_upload_v2_abandoned`：mode、currentStep、hasDraft。

## 建议实施阶段

### Phase 1: 文档与确认

- 冻结 V2 首版字段范围。
- 明确新增/编辑都纳入 V2，但通过 feature flag 灰度，不一次性移除旧 `EventEditorView`。
- 明确普通用户审核投稿携带六区图片资产的后端方案。

### Phase 2: 骨架隔离

- 新建 `EventUploadFlow` 模块。
- 建 draft、step、validation、mapper。
- 接入 route feature flag，但默认关闭。

### Phase 3: 主要页面

- 图片、信息、周期、时间表、仅阵容、票务提交。
- 使用现有 repository，不改后端。
- 加本地草稿和离开确认。

### Phase 4: AI 与高级能力

- 首版只实现 AI 占位按钮和点击埋点。
- 后续再接海报识别/阵容图识别，导入结果进入可编辑草稿。
- 完善错误重试、上传进度、审核态。

### Phase 5: 切换与收尾

- Light/Dark 截图检查。
- 真机检查键盘、照片权限、地图权限、弱网重试。
- 灰度打开 V2 新增与编辑入口。
- 稳定后再移除旧入口或降低旧 `EventEditorView` 的可见性。

## 验收标准

- V2 和旧上传页可以通过一个入口开关切换。
- Light/Dark 下文字对比度、按钮状态、输入框边界清晰。
- 必填字段错误能定位到具体步骤。
- 用户中途退出会有草稿提示，不会静默丢失内容。
- 图片上传失败可重试，已填表单不丢失。
- 时区必须明确确认，跨时区日期预览清楚。
- 无阵容/无票务也能提交基础活动。
- 有阵容/票务时能在预览页完整检查。
- 审核态和直接发布态都有不同成功反馈。

## 落地进度 Checklist

> 执行规则：后续每完成一轮代码改动或验证，都同步更新本 checklist。未完成项保持 unchecked，完成项打勾，并在必要时补充结果说明。

### 本轮 UI 调整专项

- [x] 通用：键盘弹起时点击页面空白可收起键盘。
- [x] 第一页：去掉拍照上传，只保留相册选择。
- [x] 第一页：图片分区改为两列布局。
- [x] 第一页：`poster / lineup / timetable / cover / map / other` 中文化显示。
- [x] 第一页：AI 智能识别按钮移出，放到下一页。
- [x] 第一页：已上传图片项移除“重新上传”按钮，只保留继续添加、排序、删除。
- [x] 第一页：媒体卡、顶部进度条、底部操作区已完成一轮排版收紧和层级统一。
- [x] 第二页：顶部加入彩色 AI 一键补充按钮。
- [x] 第二页：时区搜索前移到基础信息页。
- [x] 第二页：地图选点入口前移到基础信息页。
- [x] 地图搜索地点时移除“移动 pin 展示 pin 周边 POI / 附近推荐地点”这一层，底部优先露出搜索候选结果。
- [x] 第二页：原文链接保留单独一行输入。
- [x] 第二页：主办方先支持名称输入，后续升级为搜索绑定。
- [x] 第二页：主办方已升级为搜索绑定交互，支持绑定 organizer / festival 词条并提交 `wikiFestivalId`。
- [x] 第三页：流程切换为单日 / 多日 / 多 Week，并支持多 Week 的每周起止日期。
- [x] 第五页：拆出独立 timetable 总览页，按 Week 展示入口卡片。
- [x] 第六页：拆出独立 lineup-only 页面，仅填写阵容。
- [x] 最后一页：购票链接保留单独一行输入。
- [x] 数据层：`timetableSlots / lineupOnlySlots` 已完成拆分，分别承载时间表与仅阵容数据。
- [x] 编辑态 hydrate：修复 `lineupArtists` 回填逻辑，按共享 `EventLineupActCodec` 解析到 lineup-only 草稿。
- [x] 第五页：Week 卡片点击后进入对应 Week 的时间表编辑页（sheet 形态首版已接入）。
- [x] Week 时间表编辑页：首版支持按舞台顺序切换。
- [x] Week 时间表编辑页：首版支持按 Day 维度切换和过滤节目。
- [x] Week 时间表编辑页：已填写完整的节目默认以折叠态展示，可展开继续编辑。
- [x] 第二页：主办方升级为真正的搜索绑定交互，并确认最终提交字段策略。
- [x] 第三页：周期页已完成一轮强化，补齐了周期概览、模式卡、双日期卡、week-card 和计数器式 rollover 区。
- [x] Week 时间表编辑页：排版已完成一轮强化，补齐了摘要卡、舞台/日期切换层级、节目列表头部与时间 badge。
- [x] Week 时间表编辑页：支持在当前 Week / 当前舞台 / 当前日期上下文下直接新增节目。
- [ ] Week 时间表编辑页：继续向附件 html 第 6 页做细节对齐和 polish。
- [x] Week 时间表编辑页：节目必须填写开始时间和结束时间，不能留空。
- [x] lineup-only 页面：已完成一轮排版强化，补齐了概览摘要、绑定统计和更紧凑的条目头部。
- [x] lineup-only 页面：继续向附件 html 第 8 页做了一轮细节对齐和 polish。
- [ ] lineup-only 页面：继续收最后一轮视觉细节，特别是搜索结果列表和成员卡纵向节奏。
- [x] timetable / lineup / 票务页已完成一轮统一视觉优化，强化了卡片层级、摘要区和提交前检查结构。
- [ ] timetable / lineup / 票务页继续做少量 Light / Dark 细节 polish。

### 0. 现状梳理与边界冻结

- [x] 阅读附件 HTML 原型，确认它是 10 步移动端流程草图，不直接搬进 App。
- [x] 阅读现有 iOS `EventEditorView`，确认当前新增/编辑活动能力和痛点。
- [x] 阅读 `festival-viewer` 图片分区逻辑，确认六区为 `poster / lineup / timetable / cover / map / other`。
- [x] 阅读 `festival-viewer` 时间表同步逻辑，确认跨天按 `dayRolloverHour` 和结束时间次日处理。
- [x] 收敛产品决策：poster 必填、普通用户审核、管理员直发、地点最低必填、多 Week 核心、AI 仅占位、主题跟随系统。
- [x] 冻结 V2 首版后端字段与接口清单。
- [x] 冻结 V2 首版 iOS route 切换策略：通过 `AppConfig.eventUploadFlowV2Enabled` 灰度切换，默认关闭，旧 `EventEditorView` 保持可回退。

### 1. 后端与 Web/Festival-Viewer 前置

- [x] 梳理当前 event create/update API 对六区图片资产的支持情况。
- [x] 设计普通用户审核投稿如何携带六区图片资产。
- [x] 若缺失，补齐 content-submission 附件或临时图片资产能力。
- [x] 对齐管理员直发：创建/更新 event 后能绑定六区图片资产。
- [x] 同步主要兼容字段：`coverImageUrl`、`lineupImageUrl` 等当前客户端仍依赖的字段。
- [x] 给 `festival-viewer` 新增活动补 `poster` 必填校验。
- [x] 给 `festival-viewer` 保存失败提示补足六区图片校验信息。
- [x] 增加后端/脚本级 guardrail，避免无 poster 活动被创建。
- [x] 普通用户活动投稿和审核通过落库要求 poster 资产，并保存 `imageAssets`。
- [ ] 验证管理员创建、普通用户审核、审核通过落库三条链路。

### 2. iOS V2 模块隔离

- [x] 新建 `Features/Discover/Events/UploadFlow/` 模块目录。
- [x] 新建 `EventUploadFlowView.swift`。
- [x] 新建 `EventUploadFlowViewModel.swift`。
- [x] 新建 `EventUploadDraft.swift`。
- [x] 新建 `EventUploadStep.swift`。
- [x] 新建 `EventUploadValidation.swift`。
- [x] 新建 `EventUploadMappers.swift`。
- [x] 新建 `EventUploadDraftStore.swift`。
- [x] 新建 `EventUploadAnalytics.swift`。
- [x] 新建 UploadFlow `Components/` 基础组件目录。
- [x] 保持旧 `EventEditorView` 可用，不把旧页面内部逻辑直接迁入 V2。
- [x] 接入新增/编辑 route feature flag，V2 默认关闭。

### 3. Draft、Hydration 与本地草稿

- [x] 定义 `EventUploadDraft` 的媒体六区模型。
- [x] 定义基础信息、时间、地点、阵容、票务、UI 状态子模型。
- [x] 实现 create 空草稿初始化。
- [x] 实现 edit 从 `WebEvent` hydrate 草稿。
- [x] 实现系统语言到输入字段的选择策略。
- [x] 实现草稿 `Codable` 存储。
- [x] 实现图片复制到 App sandbox 草稿目录。
- [x] 实现自动保存：字段变更 debounce 1 秒。
- [x] 实现切后台自动保存。
- [x] 实现离开页面前保存/放弃确认。
- [x] 修复“放弃草稿”后页面 `onDisappear` 又把内存草稿重新保存的问题。
- [x] 修复编辑活动时主办方 `wikiFestivalId` 未进入 update payload，导致绑定/解绑保存不生效的问题。
- [x] 修复编辑活动回填时把活动地图坐标误当成城市时区候选坐标，导致不改内容直提也触发 timezone mismatch 的问题。
- [x] 修复编辑活动详细地址仅从 `manualLocation.detailAddressI18n` 回填，历史数据只在 `formattedAddressI18n` 时显示为空的问题。
- [x] 修复编辑活动地图选点仅依赖顶层 `latitude/longitude` 回填，`locationPoint.location` 存在时绑定态丢失的问题。
- [x] 修复编辑活动多日事件重新进入时错误回填为单日模式的问题，并让舞台顺序优先尊重服务端 `stageOrder`。
- [x] 补齐地图选点绑定态清空入口，并让 edit 提交时能显式清空 `locationPoint / latitude / longitude`。
- [x] 修复编辑活动名称只更新 `name` 未同步 `nameI18n`，导致展示层继续被旧本地化名称覆盖的问题。
- [x] 实现草稿 14 天过期清理。
- [x] 实现提交成功后清理草稿。
- [x] 实现新建活动“继续上次草稿/重新开始”提示。
- [x] 实现编辑活动按 event id 独立草稿。

### 4. Step 1 媒体与 AI 占位

- [x] 实现六区图片上传 UI 骨架：poster、lineup、timetable、cover、map、other。
- [x] 实现每区多图选择。
- [x] 实现拍照入口。
- [x] 实现图片缩略图预览。
- [x] 实现图片删除。
- [x] 实现图片排序。
- [x] 实现图片替换。
- [x] 实现 `poster` 至少 1 张校验。
- [x] 实现 AI 占位按钮视觉：多色渐变、微光边框、sparkles 图标、按下反馈。
- [x] 实现 AI 占位按钮点击提示。
- [x] 实现 AI 占位按钮点击埋点。
- [ ] Light/Dark 检查媒体页视觉。

### 5. Step 2 基础信息

- [x] 实现活动名称输入和必填校验。
- [x] 实现活动类型选择，复用 `EventTypeOption`。
- [x] 实现活动简称输入，并接入 create/update 与聚合搜索。
- [x] 实现城市必填输入。
- [x] 实现国家必填输入。
- [x] 实现详细地址必填输入。
- [x] 按系统语言写入对应本地化字段。
- [x] 不要求用户手动补齐其他语言字段。
- [ ] Light/Dark 检查基础信息页视觉。

### 6. Step 3 时间与时区

- [x] 实现单日/多日/多 Week 模式选择。
- [x] 实现开始日期、结束日期选择。
- [x] 单日日期选择器居中展示，并在日期附近展示当前绑定时区。
- [x] 实现城市时区搜索，复用 `/v1/event-timezones/search`。
- [x] 城市时区输入时实时 debounce 展示候选结果。
- [x] 城市时区标题旁补充英文城市名搜索提示，例如香港使用 Hong Kong。
- [x] 实现新建活动必须从候选确认时区；编辑旧活动允许保留已有 timezone，修改时需重新搜索确认。
- [x] 实现跨时区日期预览。
- [x] 实现 `dayRolloverHour` 默认 6。
- [x] 实现高级设置调整 `dayRolloverHour`。
- [x] 实现结束日期早于开始日期校验。
- [ ] Light/Dark 检查时间页视觉。

### 7. Step 4 地点

- [x] 复用或适配 `EventLocationPickerSheet`。
- [x] 实现地图选点可选入口，接入现有 picker。
- [x] 地图选点与详细地址解耦，只保存场地/坐标/地图地址，不覆盖详细地址。
- [x] 展示位置摘要。
- [x] 支持无坐标但有手动地址提交。
- [ ] Light/Dark 检查地点页视觉。

### 8. Step 5 阵容与时间表

- [x] 实现舞台列表新增、删除。
- [x] 实现舞台列表排序。
- [x] 实现舞台重名拦截，多个空舞台按“主舞台”重复处理。
- [x] 实现 lineup 手动添加 DJ。
- [x] 实现 DJ 库搜索绑定。
- [x] DJ 名称输入时实时 debounce 展示候选结果。
- [x] 实现 solo/b2b/group act type。
- [x] 实现无阵容跳过。
- [x] 实现 timetable slot 的 day/stage/start/end 编辑；舞台为空时默认主舞台。
- [x] 实现多 Week 下 Week/Day 映射。
- [x] 实现跨天 slot：结束时间不晚于开始时间时按次日结束。
- [x] 实现 pending lineup entry 保存前必须确认或删除校验。
- [x] 保留阵容图识别入口但首版不接识别。
- [ ] Light/Dark 检查阵容时间表页视觉。

### 9. Step 6 票务、预览与提交

- [x] 实现多个票档手动添加。
- [x] 实现票档名称可选、票档价格校验。
- [x] 实现币种输入并标准化大写。
- [x] 实现票务跳转链接输入。
- [x] 实现 URL 格式校验。
- [x] 票务页和提交前检查页拆分为两个独立步骤。
- [x] 实现最终预览：媒体、基础、时间地点、阵容/舞台、票务。
- [x] 预览页错误能跳回对应步骤。
- [x] 管理员提交走直接创建/更新链路。
- [x] 普通用户提交走审核链路。
- [x] 成功页提供返回活动页。
- [x] 成功页提示可在我的发布查看。
- [ ] Light/Dark 检查预览与成功页视觉。

### 10. Mapper、API 与上传链路

- [x] Draft 映射到 `CreateEventInput`。
- [x] Draft 映射到 `UpdateEventInput`。
- [x] Draft 映射到六区图片资产 payload。
- [x] Draft 映射到 lineup slots。
- [x] Draft 映射到 timetable slots 并保留跨天语义。
- [x] Draft 映射到轻量票务字段。
- [x] 管理员 create 前上传图片并在创建 payload 中绑定图片资产。
- [x] 管理员 edit 后更新图片资产。
- [x] 普通用户提交审核 payload 包含全部必要字段和图片引用。
- [x] 上传失败后可重试且表单不丢失。
- [x] 弱网/超时错误有明确提示。

### 11. 路由切换与灰度

- [x] 增加 `eventUploadFlowV2Enabled` feature flag，支持 DEBUG UserDefaults 和 `RAVER_EVENT_UPLOAD_FLOW_V2_ENABLED` 环境变量。
- [x] Discover `.eventCreate` 默认直连 V2，活动列表右下角 + 不再进入旧页面。
- [x] Discover `.eventEdit` 默认直连 V2，编辑页使用同一套 V2 UI。
- [x] Profile 发布和我的发布编辑入口默认直连 V2。
- [x] 旧 `EventEditorView` 保留在代码中作为内部兜底，不再作为常规活动发布入口。
- [x] 成功保存后刷新活动列表/详情。
- [x] 返回活动页路径正确。

### 12. 埋点

- [x] 实现 `event_upload_v2_opened`。
- [x] 实现 `event_upload_v2_step_viewed`。
- [x] 实现 `event_upload_v2_step_completed`。
- [x] 实现 `event_upload_v2_ai_placeholder_tapped`。
- [x] 实现 `event_upload_v2_draft_saved`。
- [x] 实现 `event_upload_v2_submit_tapped`。
- [x] 实现 `event_upload_v2_submit_succeeded`。
- [x] 实现 `event_upload_v2_submit_failed`。
- [x] 实现 `event_upload_v2_abandoned`。

### 13. 测试与验证

- [ ] 单元测试：draft validation。
- [ ] 单元测试：create mapper。
- [ ] 单元测试：edit mapper。
- [ ] 单元测试：跨天 timetable mapper。
- [ ] 单元测试：draft store 保存/恢复/清理。
- [ ] 集成测试：管理员直接创建。
- [ ] 集成测试：普通用户提交审核。
- [ ] 集成测试：编辑已有活动。
- [ ] 集成测试：无 poster 禁止提交。
- [ ] 真机验证：照片权限。
- [ ] 真机验证：相机权限。
- [ ] 真机验证：地图权限。
- [ ] 真机验证：键盘遮挡与滚动。
- [ ] 真机验证：切后台恢复草稿。
- [ ] 截图检查：Light。
- [ ] 截图检查：Dark。
- [ ] 弱网验证：图片上传失败可重试。
- [x] iOS Debug simulator build 通过；当前剩余输出为既有 warning，未发现 V2 编译错误。
- [x] Step 2 基础信息页接入后再次通过 iOS Debug simulator build。
- [x] Step 3 时间与时区页接入后再次通过 iOS Debug simulator build。
- [x] Step 4 地点页接入后再次通过 iOS Debug simulator build。
- [x] Step 6 票务与预览页接入后再次通过 iOS Debug simulator build。
- [x] 媒体页相册多图选择、本地图片草稿保存、删除接入后再次通过 iOS Debug simulator build。
- [x] 媒体页缩略图预览接入后再次通过 iOS Debug simulator build。
- [x] 媒体图片排序和舞台排序接入后再次通过 iOS Debug simulator build。
- [x] 城市时区搜索确认和现有地图 picker 接入后再次通过 iOS Debug simulator build。
- [x] V2 create/edit 提交 mapper、六区图片资产编码、图片上传链路接入后再次通过 iOS Debug simulator build。
- [x] V2 提交成功页接入后再次通过 iOS Debug simulator build。
- [x] V2 手动阵容/时间表 slot、Week/Day 映射和跨天 mapper 接入后再次通过 iOS Debug simulator build。
- [x] V2 草稿 14 天过期清理和继续/重新开始提示接入后再次通过 iOS Debug simulator build。
- [x] V2 step completed 和 abandoned 埋点接入后再次通过 iOS Debug simulator build。
- [x] Profile/我的发布发布与编辑入口按 flag 切 V2、保存后刷新列表接入后再次通过 iOS Debug simulator build。
- [x] V2 阵容 DJ 库搜索绑定接入后再次通过 iOS Debug simulator build。
- [x] V2 媒体页拍照入口和相机权限文案接入后再次通过 iOS Debug simulator build。
- [x] V2 媒体页图片替换接入后再次通过 iOS Debug simulator build。
- [x] V2 时间页跨时区日期预览接入后再次通过 iOS Debug simulator build。
- [x] V2 切后台保存和离开前保存/放弃确认接入后再次通过 iOS Debug simulator build。
- [x] V2 字段变更 1 秒 debounce 自动保存接入后再次通过 iOS Debug simulator build。
- [x] V2 每页大标题下方说明文案移除，减少移动端页面占用。
- [x] 后端 create 对所有角色强制 poster 资产后通过 `pnpm build`。
- [x] V2 最终回归再次通过 iOS Debug simulator build。
- [x] 活动列表右下角 +、Discover 编辑、Profile 发布/编辑入口默认直连 V2 后再次通过 iOS Debug simulator build。
- [x] V2 第一页改为两列图片布局、仅支持相册选择、图片区中文文案后再次通过 iOS Debug simulator build。
- [x] V2 第二页接入 AI 一键补充按钮、时区搜索、地图入口、原文链接单独行、空白点击收键盘后再次通过 iOS Debug simulator build。
- [x] V2 step 结构改为 图片 / 信息 / 周期 / 时间表 / 阵容 / 票务 后再次通过 iOS Debug simulator build。
- [x] V2 第三页支持 multi-week 周范围编辑，每个 week 可单独维护起止日期后再次通过 iOS Debug simulator build。
- [x] V2 第五页拆出独立 timetable 总览与 lineup-only 页面后再次通过 iOS Debug simulator build。
- [x] `festival-viewer` 本轮 `memberDjIds / memberNames` 迁移后再次通过 `node --check`。
- [x] server 本轮 `memberDjIds / memberNames` 迁移后再次通过 `pnpm build`。
- [x] iOS 本轮 `memberDjIds / memberNames` 迁移后已清理连带页面的旧 `slot.djIds` 引用，并再次通过全量 build。
- [x] iOS 多语言展开输入与“只填当前语言不自动补齐其他语言”本轮改造后再次通过 iOS Debug simulator build。
- [x] 时间表页与仅阵容页 AI 入口样式已统一为基础信息页同款渐变按钮，并补充“可跳过”提示。
- [x] 时间表页 AI 识别正式接入：支持从草稿图片选择、上传本地草稿图、调用 Coze 时间表识别代理、在 sheet 内展示/编辑识别结果并增量写入 timetable。
- [x] 时间表页 AI 识别结果展示改为沿用现有 timetable 页面结构：先选 Week，再选 Day，再选舞台，下面继续沿用 Week 编辑页同款节目卡片节奏。
- [x] 时间表页 AI 识别结果新增一键匹配当前列表 DJ，并绑定 performer 级 DJ id / avatar。
- [x] 时间表页 AI 识别等待态改为更具科技感的 thinking 动效。
- [x] server 新增 `/v1/events/timetable/import-image` Coze 代理，透传 event 日期、时区、跨天切日与 Week 上下文，并通过 `pnpm build`。
- [x] iOS 时间表 AI 识别接入后再次通过 iOS Debug simulator build。
- [x] server 新增 `/v1/events/lineup/import-image/jobs` 与 `/v1/events/lineup/import-image/jobs/:jobId`，按 Coze lineup 工作流的 `image_url/file_type/context.preferred_language/known_dj_names` 格式提交异步识别任务。
- [x] server lineup AI 结果归一化为 flat `items` schema，不引入 sections，也不产生 timetable 的 stage/date/time 字段，并通过 `pnpm build`。
- [x] server Coze 配置拆分为 `COZE_TIMETABLE_WORKFLOW_*` 与 `COZE_LINEUP_WORKFLOW_*`，不再使用旧 `COZE_WORKFLOW_*` 兜底。
- [x] iOS WebFeatureService 新增 lineup AI 异步 job 创建与轮询模型。
- [x] V2 仅阵容页 AI 识别接入：支持从已上传图片选择、上传本地草稿图、调用 lineup Coze job、显示 thinking 动效与计时、在 sheet 内展示错误。
- [x] V2 仅阵容页 AI 识别结果使用现有仅阵容卡片节奏：默认确认态，可展开编辑、删除、搜索绑定 DJ。
- [x] V2 仅阵容页 AI 识别结果支持一键批量精确匹配 DJ，并按 performer 级写入 DJ id / avatar。
- [x] V2 仅阵容页 AI 识别确认后只增量写入 `draft.lineupOnlySlots`，不写入 timetable。
- [x] iOS lineup AI 接入后全量 Debug simulator build 通过；顺手修复了既有 `SocialService.swift` `Error` 到 `ServiceError` pattern match 的编译阻塞。

### 14. 收尾与切换

- [x] 更新相关开发文档。
- [x] 更新 QA 验收说明。
- [x] 新增活动入口直接切换到 V2。
- [x] 编辑活动入口直接切换到 V2。
- [ ] 观察埋点：完成率、失败率、放弃步骤。
- [ ] 修复灰度问题。
- [x] 默认启用 V2。
- [x] 旧 `EventEditorView` 暂时保留为内部兜底，不再作为常规发布/编辑入口。
