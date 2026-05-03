# Raver iOS Event Countdown Widget V1 Execution Guide

## 1. Goal

为 Raver iOS 端实现一个商用级别的 Event Countdown Widget。第一版只做一个清晰能力：用户在 event 详情页把 event 加入 `widget countdown list`，桌面 Widget 通过系统配置选择 list 中的一个 event，并展示该 event 的图片背景、名称和时间状态。

本文档是本次开发的执行依据和进度记录。旧版 widget 文档不作为本方案依据。

## 2. Product Scope

### 2.1 V1 必做

- Event 详情页可以把当前 event 加入或移出 `widget countdown list`。
- Widget 配置页可以从 `widget countdown list` 中选择一个 event。
- Widget 背景图优先级：
  - `coverImageUrl`
  - `lineupImageUrl`
  - 本地渐变兜底背景
- Widget 在背景图上展示 event 名称和时间状态：
  - 未开始：`{eventName} 还有 X 天`
  - 进行中：`{eventName} Day X`
  - 已结束：`{eventName} 过去 X 天`
- Widget 点击后通过 deeplink 打开 event 详情页。
- 支持 iOS 17+ WidgetKit。
- 支持 `systemSmall` 和 `systemMedium`。

### 2.2 V1 不做

- Widget 内按钮交互。
- Lock Screen Widget。
- Live Activity。
- 后台远程推送驱动 Widget 刷新。
- Widget 内搜索全量 event。
- 自动推荐或轮播多个 event。

## 3. User Experience

### 3.1 App 内流程

1. 用户打开某个 event 详情页。
2. 点击分享/更多面板中的 `桌面倒计时`。
3. App 将该 event 写入共享的 countdown list，并缓存背景图。
4. 用户在 iOS 桌面添加 Raver Widget。
5. 长按 Widget 编辑，选择 countdown list 中的 event。
6. Widget 展示该 event 的倒计时/进行中/已结束状态。

### 3.2 Widget 状态

- `configured`: 已选择 event，且共享数据可读。
- `notConfigured`: 未选择 event。
- `missingData`: 已配置 event，但共享数据不存在或已被移除。
- `emptyList`: countdown list 为空。
- `fallbackImage`: event 无可用图片或图片缓存缺失。

### 3.3 文案规则

- V1 文案使用中文为主，保持短句以适配小尺寸 Widget。
- event 名称最多 2 行。
- 状态文案独立一行，增强可读性：
  - `还有 X 天`
  - `Day X`
  - `过去 X 天`
- 若以后接入多语言，文案由 Widget shared layer 提供本地化 key，不由业务页面拼接。

## 4. Time Rules

采用用户当前 Calendar 和本地时区计算自然日。

- `today < startDate.startOfDay`：未开始，`X = startDay - today`。
- `startDate.startOfDay <= today <= endDate.startOfDay`：进行中，`Day X = today - startDay + 1`。
- `today > endDate.startOfDay`：已结束，`X = today - endDay`。
- 若 `endDate < startDate`，Widget 兜底按单日活动处理，即 `endDate = startDate`。

示例：

- 5 月 3 日查看，活动 5 月 8 日开始：`还有 5 天`。
- 活动 5 月 1 日到 5 月 3 日，5 月 3 日查看：`Day 3`。
- 活动 5 月 1 日到 5 月 3 日，5 月 4 日查看：`过去 1 天`。

## 5. Architecture

### 5.1 分层

```text
RaverMVP App
  EventDetailView
    -> WidgetCountdownSyncService
       -> WidgetCountdownStore
       -> WidgetCenter.reloadTimelines

App Group Shared Container
  WidgetCountdown/events.json
  WidgetCountdown/images/{eventID}.jpg

Widget Extension
  Widget AppIntent Entity Query
    -> WidgetCountdownStore
  Timeline Provider
    -> WidgetCountdownStore
    -> WidgetCountdownTimelineState
  SwiftUI Widget View
```

### 5.2 扩展策略

未来新增更多 widget 时，不让业务页面直接耦合 WidgetKit：

- `Core/Widget` 保留为共享数据和同步边界。
- 每个 widget 功能拥有自己的 snapshot 文件和 schema version。
- Widget Extension 可以包含多个 Widget，但共享：
  - App Group 配置
  - Store 基础能力
  - Deeplink builder
  - 时间/状态计算工具

建议命名：

- 共享层：`WidgetCountdownEvent`, `WidgetCountdownSnapshot`, `WidgetCountdownStore`
- App 同步层：`WidgetCountdownSyncService`
- Extension 层：`RaverCountdownWidgets`

## 6. Data Contract

### 6.1 Snapshot

```swift
struct WidgetCountdownSnapshot: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let events: [WidgetCountdownEvent]
}
```

### 6.2 Event

```swift
struct WidgetCountdownEvent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String?
    let venueName: String?
    let startDate: Date
    let endDate: Date
    let preferredBackgroundURL: String?
    let cachedBackgroundImageRelativePath: String?
    let addedAt: Date
}
```

### 6.3 存储位置

- App Group ID：`group.com.raver.mvp`
- Snapshot：`Library/Application Support/WidgetCountdown/events.json`
- Images：`Library/Application Support/WidgetCountdown/images/{eventID}.jpg`

### 6.4 兼容性

- `schemaVersion = 1`。
- Widget 读取失败时不 crash，进入 `missingData` 或 `emptyList`。
- 后续 schema 升级通过新增 optional 字段优先，必要时做迁移函数。

## 7. Image Strategy

- App 侧添加 event 时下载并缓存背景图。
- Widget 优先读取本地缓存，避免 Widget 依赖网络。
- 下载失败时仍写入 event，使用户可以选择，只是 Widget 使用兜底背景。
- 图片裁剪为正方形 JPEG，写入缓存时限制为 `720x720`。
- Widget 读取缓存图时必须通过 ImageIO thumbnail 解码，并按 Widget 尺寸限制最大像素：
  - `systemSmall`: max pixel size `700`
  - `systemMedium`: max pixel size `900`
- 不允许在 Widget view 中直接用 `Data(contentsOf:) -> UIImage(data:)` 解码原图，避免触发 WidgetKit archival image area limit。
- 背景上叠加深色渐变遮罩，保证文字可读。

## 8. Widget Configuration

使用 iOS 17 `AppIntentConfiguration`：

- `SelectCountdownEventIntent`
- `CountdownEventEntity`
- `CountdownEventQuery`

Entity Query 从共享 snapshot 读取 countdown list。这样每个 Widget 实例都可以独立选择一个 event，后续也可以扩展更多配置项。

## 9. Deeplink

Widget 点击 URL：

```text
raver://event/{eventID}
```

App 需要在 `Info.plist` 注册 `raver` URL Scheme，并复用现有系统 deeplink 入口打开 event 详情页。

## 10. Refresh Strategy

- App 添加/移除 event 后调用 `WidgetCenter.shared.reloadAllTimelines()`。
- Timeline 每天刷新一次，并把下一次刷新安排在下一天 00:05 左右。
- Widget 读取 snapshot 是本地同步读，不做网络请求。

## 11. Acceptance Criteria

- Event 详情页可以添加/移除 countdown list event。
- 添加后 App Group 中存在 snapshot，且包含 event 的 start/end 日期。
- Widget 配置页可以看到刚添加的 event。
- Small/Medium Widget 都能展示：
  - 背景图
  - event 名称
  - 未开始/进行中/已结束三类状态
- 删除 list 中 event 后，Widget 不 crash，进入数据缺失态。
- 点击 Widget 可以打开 App 并进入对应 event 详情页。
- iOS 工程可以通过 xcodebuild 编译。

## 12. Progress

- [x] 需求重新定义，不沿用旧文档。
- [x] 当前 iOS 工程边界初步梳理。
- [x] 重构共享 countdown 数据模型。
- [x] 将 countdown store 改为 App Group 存储。
- [x] 同步服务写入 startDate/endDate 并触发 Widget reload。
- [x] 新增 Widget Extension 文件。
- [x] 新增 AppIntent 配置选择 event。
- [x] 新增 Widget UI 与时间状态计算。
- [x] 注册 `raver://` URL Scheme。
- [x] 纳入 `project.yml`。
- [x] 修复 WidgetKit 图片过大归档失败。
- [x] 编译验证。

## 13. Implementation Notes

- 当前工程最低 iOS 版本是 17.0，适合直接使用 AppIntent widget。
- 当前主 App 已有 App Group entitlement：`group.com.raver.mvp`。
- 当前主 App 已有 deeplink 路由解析能力，需要补齐 URL Scheme 注册。
- 当前 event model 已提供 `coverImageUrl`, `lineupImageUrl`, `startDate`, `endDate`。
- 2026-05-03 已验证 `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` 通过。
- 2026-05-03 Xcode 输出 `Widget archival failed due to image being too large` 的根因是 WidgetKit 归档视图时接收了 `2160x2160` 背景图，像素面积超过系统限制；已改为 Widget 侧读取时下采样，同时 App 侧新缓存图固定写入 `720x720`。
