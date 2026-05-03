# iOS 指定活动倒计时 Widget 指导文档

## 1. 文档目标

本文档用于指导 `Raver iOS` 端实现“指定活动倒计时 Widget”功能。

本文档覆盖：

- 产品范围与需求定义
- 用户流程与交互逻辑
- 数据模型与共享存储方案
- WidgetKit 落地方案
- 分阶段实施路线
- 验收标准与进度跟踪模板

适用工程：

- iOS 工程目录：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP`
- 工程生成配置：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/project.yml`

---

## 2. 当前版本目标

当前版本不实现：

- 自动选择最近关注活动
- 基于关注列表自动轮换活动
- 多活动并排展示

当前版本只实现：

- 用户手动指定一个活动
- Widget 固定展示该活动倒计时
- 支持 `Small + Medium`
- 点击后跳转该活动详情页

这是一版用来先跑通以下核心能力的 MVP：

- Widget 配置
- 单活动共享数据
- 倒计时展示
- Deeplink 跳转

---

## 3. 需求结论

### 3.1 核心功能

用户可以在 iOS 桌面添加 Raver Widget，并为每个 Widget 手动指定一个活动。

Widget 展示内容：

- 活动背景图
- 活动名称
- 倒计时文案：`距离 XXX 还有 X 天`

### 3.2 第一版范围

第一版范围如下：

- 支持尺寸：`Small + Medium`
- 支持模式：仅 `手动指定活动`
- 背景图优先级：
  - `coverImageUrl`
  - `lineupImageUrl`
  - 渐变占位背景
- 点击跳转：
  - 打开该活动详情页
- 不做：
  - 自动最近活动
  - 关注活动自动同步
  - Interactive Widget
  - Lock Screen Widget

### 3.3 文案规则

文案固定为：

- `距离 XXX 还有 X 天`

第一版不做“今天 / 明天 / 今晚”这类动态文案切换。

### 3.4 时间规则

采用自然日差值：

- 活动今天开始：显示 `0 天`
- 活动明天开始：显示 `1 天`
- 活动已开始：进入失效态

---

## 4. 产品定义

### 4.1 为什么先做“指定活动”

相比“自动最近关注活动”，先做指定活动有以下优势：

- 逻辑简单
- 用户预期稳定
- 不依赖“关注活动”定义
- 更适合先把 Widget 主链路跑通

### 4.2 用户心智

这不是“系统帮我挑一个活动”。

这是：

- `我把某个特别想看的活动钉在桌面上`

因此第一版的设计重点应是：

- 稳定
- 明确
- 可控

### 4.3 使用场景

典型使用场景：

- 用户对某个 festival 特别在意，想持续看倒计时
- 用户已经决定去某个活动，想把它固定到桌面
- 用户希望通过桌面小组件快速进入活动详情页

---

## 5. 用户流程

### 5.1 系统添加 Widget 流程

1. 用户长按桌面
2. 添加 Raver Widget
3. 选择 `Small` 或 `Medium`
4. 进入 Widget 配置页
5. 选择一个活动
6. Widget 保存该 `eventID`
7. Widget 展示该活动倒计时

### 5.2 点击 Widget 流程

1. 用户点击 Widget
2. App 被唤起
3. 通过 deeplink 打开活动详情页

### 5.3 App 内入口建议

建议在活动详情页增加一个入口：

- `添加到桌面倒计时`

该入口的作用不是直接替用户创建系统 Widget，而是：

- 将该活动加入“Widget 可选活动池”
- 让用户在系统配置页里更容易选到它

### 5.4 失效流程

若用户指定的活动已经开始：

1. Widget 不自动切换到别的活动
2. Widget 进入失效态
3. 提示用户重新选择活动

原因：

- 这是手动指定型 Widget
- 系统不应偷偷换成别的活动

---

## 6. 状态设计

第一版建议 Widget 仅存在以下 4 种状态。

### 6.1 正常态

条件：

- 已配置 `eventID`
- 能读取活动数据
- 活动尚未开始

展示：

- 背景图
- 活动名
- `距离 XXX 还有 X 天`

### 6.2 未配置态

条件：

- Widget 尚未配置活动

展示建议：

- 标题：`还未选择活动`
- 副文案：`请长按组件重新配置`

### 6.3 数据缺失态

条件：

- 已配置 `eventID`
- 但共享数据中找不到该活动

展示建议：

- 标题：`活动数据不可用`
- 副文案：`请重新选择倒计时活动`

### 6.4 已失效态

条件：

- 活动开始时间已到或已过去

展示建议：

- 标题：`该活动已开始`
- 副文案：`请重新选择倒计时活动`

---

## 7. 数据来源策略

### 7.1 第一版原则

第一版先不要依赖“关注活动”逻辑。

第一版的数据来源应该是：

- `Widget 可选活动池`

这个池子由主 App 维护，Widget 只读。

### 7.2 为什么不直接用全量活动

不建议 Widget 配置页直接读取全量活动列表。

原因：

- 用户选择成本高
- 系统配置页里检索体验有限
- 配置时不适合展示过多无关活动

### 7.3 推荐的数据来源

第一版推荐从以下来源构建“Widget 可选活动池”：

- 用户在活动详情页手动加入的活动

后续可扩展来源：

- 最近浏览活动
- 已收藏活动
- 已购票活动

### 7.4 第一版最小规则

建议：

- 用户点击 `添加到桌面倒计时` 后，将该活动写入共享池
- Widget 配置时从共享池中展示可选活动

---

## 8. 共享数据模型设计

第一版建议使用轻量模型，不直接复用完整 `WebEvent`。

### 8.1 单活动模型

```swift
struct WidgetSelectableEvent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let startDateISO8601: String
    let endDateISO8601: String?
    let coverImageURL: String?
    let lineupImageURL: String?
    let city: String?
    let venueName: String?
    let deeplinkURL: String
    let addedAtISO8601: String
}
```

### 8.2 共享池模型

```swift
struct WidgetSelectableEventsSnapshot: Codable {
    let version: Int
    let generatedAtISO8601: String
    let events: [WidgetSelectableEvent]
}
```

### 8.3 配置模型

```swift
struct SelectedEventWidgetConfiguration: Codable {
    let selectedEventID: String
}
```

### 8.4 为什么这样建模

好处：

- 减少 Widget 侧耦合
- 更容易做版本演进
- 存储结构清晰
- 后续加字段不会影响主模型

---

## 9. 共享存储方案

### 9.1 推荐方案

使用：

- `App Group`
- 共享 JSON 文件

### 9.2 App Group 建议

建议命名：

- `group.com.raver.mvp`

### 9.3 文件建议

建议文件名：

- `widget-selectable-events.json`

### 9.4 存储原则

- 主 App 负责写入
- Widget 只负责读取
- 每次写入采用全量覆盖

### 9.5 读取异常兜底

若读取失败：

- Widget 不崩溃
- 进入空态或数据缺失态

---

## 10. Widget 配置方案

### 10.1 配置方式

第一版建议使用：

- `AppIntentConfiguration`

### 10.2 配置项

第一版只保留一个配置项：

- `selectedEvent`

用户在配置页中选择某个活动后，系统保存其 `eventID`。

### 10.3 候选项来源

候选活动来源于共享池 `WidgetSelectableEventsSnapshot.events`。

不建议在 Widget 配置页直接发网络请求。

### 10.4 配置页体验要求

候选活动列表应满足：

- 只展示可选活动池中的内容
- 标题清晰可辨识
- 优先按 `addedAt` 倒序或 `startDate` 升序排列

第一版建议优先按：

- `addedAt` 倒序

原因：

- 用户刚加进来的活动更容易找到

---

## 11. 倒计时计算规则

### 11.1 规则定义

采用自然日差值：

- `remainingDays = startOfEventDay - startOfToday`

按天数展示，不展示小时和分钟。

### 11.2 文案拼装

固定输出：

- `距离 {eventName} 还有 {days} 天`

### 11.3 今天的活动

若活动开始日为今天：

- 显示 `0 天`

### 11.4 已开始活动

若 `event.startDate <= 当前时间`：

- 视为失效
- 不再显示正常倒计时文案

---

## 12. 时间线刷新策略

### 12.1 第一版策略

同时使用两类刷新：

- 主 App 写入共享池后主动刷新 Widget
- Widget Timeline 按日刷新

### 12.2 推荐刷新频率

由于只按天展示，建议：

- 每天凌晨后刷新一次
- 当前活动开始后尽快刷新一次

### 12.3 不建议的做法

第一版不建议：

- 高频按小时刷新
- 为了“X 天”文案每分钟刷新

---

## 13. Deeplink 设计

### 13.1 点击规则

点击 Widget 后：

- 统一打开该活动详情页

### 13.2 URL 规范建议

建议采用：

```text
raver://event/{eventId}
```

### 13.3 App 侧要求

App 需要具备：

- URL Scheme 注册
- URL 解析
- 跳转到 `EventDetailView(eventID:)`

### 13.4 空态点击行为

未配置态、数据缺失态、失效态建议：

- 点击打开 App 首页

第一版可不做复杂分流。

---

## 14. UI 规格

### 14.1 Small Widget

展示重点：

- 大图背景
- 活动名
- 倒计时文案

建议层级：

1. 背景图
2. 蒙层
3. 活动名
4. `还有 X 天`

### 14.2 Medium Widget

展示重点：

- 更完整的活动名
- 倒计时文案
- 日期 / 城市等辅助信息

建议层级：

1. 背景图
2. 活动名
3. `距离 XXX 还有 X 天`
4. `日期 + 城市`

### 14.3 背景图优先级

固定规则：

1. `coverImageUrl`
2. `lineupImageUrl`
3. 渐变占位背景

### 14.4 可读性规则

必须满足：

- 图上加深色蒙层
- 长标题最多两行
- 文案与背景对比清晰

---

## 15. App 内功能入口建议

### 15.1 入口位置

建议放在：

- `EventDetailView`

### 15.2 按钮文案

建议文案：

- `添加到桌面倒计时`

### 15.3 点击行为

用户点击后：

1. 将该活动写入 Widget 可选活动池
2. 提示用户去桌面添加或重新配置 Widget

### 15.4 第一版不做

第一版不做：

- 一键自动创建系统 Widget
- App 内直接控制某个现有 Widget 的配置

---

## 16. 工程改造清单

### 16.1 Xcode 层

需要新增：

- Widget Extension target

建议命名：

- `RaverSelectedEventCountdownWidget`

### 16.2 Capabilities

主 App 与 Widget Extension 都需要开启：

- `App Groups`

### 16.3 主 App 侧新增模块建议

建议新增目录：

- `RaverMVP/Core/Widget/`

建议文件：

- `WidgetSelectableEvent.swift`
- `WidgetSelectableEventsStore.swift`
- `WidgetSelectableEventsSyncService.swift`
- `WidgetDeepLink.swift`

### 16.4 Widget 侧建议文件

- `RaverSelectedEventCountdownWidget.swift`
- `SelectedEventCountdownProvider.swift`
- `SelectedEventCountdownEntry.swift`
- `SelectedEventCountdownView.swift`
- `SelectedEventCountdownIntent.swift`

---

## 17. 分阶段实施路线

### Phase 0：需求冻结

目标：

- 冻结“指定活动倒计时”规则

完成标准：

- 不再讨论自动关注逻辑
- 第一版仅围绕单活动展开

### Phase 1：共享池数据链路

目标：

- 让 App 能维护“Widget 可选活动池”

任务：

- 定义轻量活动模型
- 实现共享池 JSON 存储
- 在活动详情页增加“添加到桌面倒计时”
- 将活动写入共享池

完成标准：

- 本地能看到共享池快照文件
- 重复添加同一活动不会产生脏数据

### Phase 2：Widget 基础能力

目标：

- 创建 Widget Extension 并完成读取与展示

任务：

- 新增 Widget target
- 接入 `AppIntentConfiguration`
- 配置候选活动列表
- 实现 Small / Medium 展示

完成标准：

- 模拟器中可以添加 Widget
- 可以手动选中某个活动并展示

### Phase 3：倒计时与状态机

目标：

- 实现完整状态切换

任务：

- 正常态
- 未配置态
- 数据缺失态
- 已失效态
- Timeline 刷新

完成标准：

- 各状态可稳定显示且不崩溃

### Phase 4：Deeplink 打通

目标：

- 点击 Widget 后打开活动详情

任务：

- 注册 URL Scheme
- 补齐 `raver://event/{eventId}` 路由
- 验证从 Widget 打开 App 后的跳转

完成标准：

- 点击 Small / Medium 都能正确打开活动详情页

### Phase 5：测试与打磨

目标：

- 达到可交付标准

任务：

- 真机测试
- 图片缺失降级
- 长文案测试
- 跨天刷新测试

完成标准：

- P0 问题全部关闭

---

## 18. 推荐实施顺序

建议按以下顺序开发：

1. 先做共享池模型与共享存储
2. 再做活动详情页“添加到桌面倒计时”
3. 再建 Widget target
4. 再做配置页选活动
5. 再做倒计时渲染
6. 最后补 deeplink 与测试

不要先做复杂视觉稿。

---

## 19. 验收标准

### 19.1 功能验收

- 可成功添加 `Small` Widget
- 可成功添加 `Medium` Widget
- 可从配置页手动选择活动
- Widget 能稳定展示被选活动倒计时
- 点击后能进入活动详情页

### 19.2 状态验收

- 未配置活动时显示未配置态
- 活动不存在时显示数据缺失态
- 活动开始后显示已失效态
- 各状态下都不崩溃

### 19.3 展示验收

- 优先使用 `cover`
- `cover` 缺失时降级 `lineup`
- 图片异常时降级为占位背景
- 长标题不破版

---

## 20. 测试清单

### 20.1 功能测试

- 添加 Small Widget
- 添加 Medium Widget
- 选择活动后正确展示
- 更换活动后正确更新
- 点击进入活动详情页

### 20.2 状态测试

- 未配置活动
- 活动已被删除
- 活动已开始
- 活动名称超长

### 20.3 数据测试

- 同一活动重复加入共享池
- 多个活动加入共享池
- 共享池为空

### 20.4 系统级测试

- 冷启动 App 后同步
- 真机桌面展示
- 不同语言环境
- 跨天刷新

---

## 21. 风险与应对

### 21.1 风险：配置页可选活动为空

影响：

- 用户无法选择活动

应对：

- 必须优先完成 App 内“添加到桌面倒计时”入口

### 21.2 风险：图片加载不稳定

影响：

- Widget 视觉质量下降

应对：

- 先做背景降级兜底

### 21.3 风险：Deeplink 未真正注册

影响：

- 点击 Widget 无法打开详情页

应对：

- 将 URL Scheme 注册列为 Phase 4 必做项

### 21.4 风险：活动已失效但 Widget 未及时刷新

影响：

- 继续显示旧倒计时

应对：

- 在活动开始后关键时间点安排 Timeline 刷新

---

## 22. 进度跟踪模板

| 模块 | 状态 | 负责人 | 计划完成时间 | 实际完成时间 | 备注 |
|---|---|---|---|---|---|
| 需求冻结 | 未开始 |  |  |  |  |
| 共享池模型 | 未开始 |  |  |  |  |
| App Group 配置 | 未开始 |  |  |  |  |
| 活动详情页入口 | 未开始 |  |  |  |  |
| 共享池写入逻辑 | 未开始 |  |  |  |  |
| Widget Target 搭建 | 未开始 |  |  |  |  |
| Widget 配置选择器 | 未开始 |  |  |  |  |
| Small UI | 未开始 |  |  |  |  |
| Medium UI | 未开始 |  |  |  |  |
| 倒计时计算 | 未开始 |  |  |  |  |
| Deeplink 打通 | 未开始 |  |  |  |  |
| 失效态 | 未开始 |  |  |  |  |
| 真机测试 | 未开始 |  |  |  |  |

状态建议：

- `未开始`
- `进行中`
- `阻塞`
- `已完成`

---

## 23. 结论

“指定活动倒计时 Widget”是最适合作为第一版落地的方案，因为它先把 Widget 最难的三件事跑通了：

- 配置一个具体对象
- 共享这个对象的数据
- 点击后回到这个对象的详情页

等这条链路稳定后，再扩展到“自动选择最近关注活动”，风险会小很多，代码复用率也会更高。
