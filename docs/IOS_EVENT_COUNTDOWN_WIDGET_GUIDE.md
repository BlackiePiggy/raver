# iOS 关注活动倒计时 Widget 指导文档

## 1. 文档目标

本文档用于指导 `Raver iOS` 端实现“关注活动倒计时 Widget”功能，覆盖以下内容：

- 产品目标与范围定义
- 已确认需求与决策边界
- 信息架构与交互方案
- iOS 端技术落地方案
- 数据结构与同步机制
- 分阶段实施路线
- 验收标准、风险清单与回滚策略
- 可持续维护的进度跟踪模板

本文档默认面向以下工程：

- iOS 工程目录：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP`
- iOS 工程生成配置：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/project.yml`

---

## 2. 需求结论

以下内容已由产品方向拍板，后续实现以此为准。

### 2.1 功能定义

Widget 展示对象为：

- 用户手动点“关注/收藏”的 event
- 仅展示 `尚未开始` 的 event

不纳入第一版的对象：

- 已结束 event
- 仅 check-in 过但未关注的 event
- 仅购票但未关注的 event
- DJ、品牌、新闻等其他内容类型

### 2.2 第一版范围

第一版 Widget 范围如下：

- 支持尺寸：`Small + Medium`
- 支持模式：
  - `自动最近活动`
  - `手动指定活动`
- 文案风格：
  - 纯简洁风格
  - 标准文案：`距离 XXX 还有 X 天`
- 背景图优先级：
  - `coverImageUrl`
  - 若缺失则降级为 `lineupImageUrl`
- 点击跳转：
  - 统一跳转至该活动详情页
- 第一版不做：
  - Interactive Widget
  - Widget 内部按钮操作
  - Lock Screen Widget
  - 复杂动态文案切换

### 2.3 刷新策略

第一版刷新策略：

- App 打开后主动同步 Widget 数据
- WidgetKit Timeline 定时刷新

第一版不做：

- 远程 push 直接驱动 Widget 刷新
- Live Activity

### 2.4 数据接入要求

第一版要求：

- 必须接入真实“关注活动”数据
- 不接受纯 Mock 交付

这意味着第一版必须先打通：

- 用户关注活动列表读取
- “仅未开始活动”的过滤能力
- App 与 Widget Extension 间的数据共享

---

## 3. 产品目标

### 3.1 业务目标

通过桌面 Widget 提升以下能力：

- 提高用户对已关注活动的持续关注度
- 增强活动临近时的回访频率
- 将“活动详情页”作为高频入口前置到桌面
- 强化 Raver 的核心用户心智：`我关注的活动正在临近`

### 3.2 用户价值

用户无需打开 App，即可在桌面看到：

- 我最关心的活动是哪一个
- 距离开始还有多少天
- 活动主视觉是什么

### 3.3 成功标准

第一版上线后，建议以以下指标评估价值：

- Widget 添加率
- Widget 点击进入活动详情的 CTR
- 已添加 Widget 用户的次日 / 7 日活跃提升
- 被关注活动详情页的访问频次变化

---

## 4. 当前前置依赖评估

结合当前仓库现状，已有基础包括：

- iOS SwiftUI 主工程已存在
- 事件基础字段已存在：
  - `coverImageUrl`
  - `lineupImageUrl`
  - `startDate`
  - `venueName`
  - `city`
- iOS 最低版本为 `iOS 17`
- 项目采用 `xcodegen`，便于新增 Widget target

当前需要重点确认或补齐的部分：

### 4.0 当前代码仓库已确认现状

以下内容是当前仓库里已经存在的实现现状：

- iOS 端“收藏活动 / Favorites”入口已存在
- 当前“收藏活动”不是独立的 event follow 资源
- 当前实现链路是：
  - 用户点击活动星标
  - 创建一条 `type = event` 的 checkin
  - 且该 checkin 的 `note = "marked"`
- iOS 端通过“我的 checkins”筛出 `isMarkedCheckin == true` 的记录，再组装收藏活动列表
- iOS 端已具备活动详情路由能力：
  - `AppRoute.eventDetail(eventID:)`
  - `EventDetailView(eventID:)`
- iOS 端已具备系统 deeplink 映射入口
- 当前路由解析已支持 `event` host

这意味着第一版 Widget 所需的“真实关注活动数据”已经有可复用链路：

- 产品语义：`关注 / 收藏活动`
- 技术语义：`marked event checkin`

第一版文档与代码需要显式承认这层映射，避免和未来可能单独建设的“活动关注表”混淆。

### 4.1 关键依赖 A：真实“关注活动”接口

这是第一优先级依赖。

需要明确：

- iOS 端当前“收藏活动”页面的数据来源是什么
- 是否继续复用 `marked checkin` 作为 Widget 第一版真实来源
- 返回结果中是否已天然排除过期活动

当前仓库结论：

- 当前没有独立的 `favorite events` 资源接口
- 现有实现是：
  - 先调用“我的 checkins”
  - 再筛出 `type = event && note = marked`
  - 再按 eventID 逐条请求 event detail
- 当前“收藏活动”并没有天然过滤掉已开始或已结束活动

因此第一版 Widget 必须在 App 侧额外增加：

- “仅未开始活动”的二次过滤
- 用于 Widget 的轻量快照落盘
- 对 `marked` 数据链路的统一封装，避免 Widget 直接耦合 checkin 细节

### 4.2 关键依赖 B：深链到活动详情页

需要确保 Widget 点击时可以稳定打开：

- App
- 并直达对应 Event Detail 页面

若当前还没有统一 deep link 机制，需在本项目中补充。

当前仓库结论：

- App 内部路由已经支持 `event detail`
- `MainTabCoordinator` 中已存在系统 deeplink 解析入口
- 当前路由支持 `event` host，等价格式可解析为：
  - `scheme://event/{eventId}`
  - 或 path 归一化后首段为 `event`

但当前仍有一个待补项：

- `Info.plist` 中尚未看到显式 `CFBundleURLTypes`

因此第一版建议补齐一套正式、稳定的 Widget deeplink 规范：

- 推荐：`raver://event/{eventId}`

并确保：

- App URL Scheme 注册完成
- 从 Widget 点击进入 App 时可以真正触发该路由

### 4.3 关键依赖 C：共享存储

Widget Extension 无法直接读取主 App 内存状态，因此必须引入：

- `App Group`
- 共享缓存文件或 `UserDefaults(suiteName:)`

### 4.4 关键依赖 D：远程图片策略

Widget 背景图依赖远程 URL。

需要明确：

- 是由 Widget Extension 自己下载图片
- 还是由主 App 预先下载并共享本地缓存路径

第一版建议：

- 先由 Widget 直接读取远程 URL 并渲染
- 如性能或稳定性不理想，再升级为共享图片缓存方案

---

## 5. 需求边界与规则定义

### 5.1 “未开始活动”的判断规则

统一规则：

- 若 `event.startDate > 当前时间`，则视为未开始
- 若 `event.startDate <= 当前时间`，则不再展示

建议统一采用：

- 服务端返回 ISO8601 时间
- 客户端按用户本地时区计算剩余天数

### 5.2 剩余天数计算规则

第一版采用“自然日差值”而非精确小时差值：

- 同一天开始：`0 天`
- 明天开始：`1 天`
- 后天开始：`2 天`

由于文案格式已经拍板为 `距离 XXX 还有 X 天`，需明确：

- 是否允许 `还有 0 天`

当前已确认的产品规则：

- 若活动开始日在今天，仍显示 `距离 XXX 还有 0 天`

原因：

- 文案逻辑简单稳定
- Timeline 切换规则更清晰
- 避免第一版出现“今天 / 今晚”额外分支

### 5.3 自动最近活动模式

当用户选择 `自动最近活动` 时：

- 从关注活动列表中筛选所有未开始活动
- 按 `startDate` 升序排序
- 取第一条作为 Widget 主展示内容

### 5.4 手动指定活动模式

当用户选择 `手动指定活动` 时：

- Widget 配置页列出用户已关注且未开始的活动
- 用户选择其中一条后固定展示

若该活动后续开始或失效：

- 默认回退到 `自动最近活动`
- 并在下次配置时提示用户重新选择

### 5.5 空状态规则

若没有任何符合条件的活动，Widget 显示空状态：

- 标题：`暂无关注活动`
- 副文案：`去发现页收藏感兴趣的活动`

点击空状态时：

- 跳转 App 的活动发现页或活动列表页

如当前没有稳定深链到发现页，第一版可统一打开 App 首页，再由后续版本细化。

---

## 6. Widget 规格定义

### 6.1 Small Widget

用途：

- 突出单个重点活动
- 强调封面图和倒计时数字

建议信息层级：

1. 背景图
2. 剩余天数
3. 活动名
4. 简洁辅助文案

建议文案：

- 主文案：`距离 XXX`
- 次文案：`还有 X 天`

或单行组合：

- `距离 XXX 还有 X 天`

但由于活动名可能较长，视觉上更建议拆成两层。

建议 UI 结构：

- 整卡背景：`coverImageUrl`
- 图片缺失时：回退 `lineupImageUrl`
- 再缺失时：回退品牌渐变背景
- 图片上覆盖深色蒙层
- 右下或底部放倒计时数字块

### 6.2 Medium Widget

第一版建议仍聚焦 `1 个活动`，而不是并排展示多个活动。

原因：

- 你的产品目标是“当前最关注的一个活动倒计时”
- Medium 先做更完整的信息展示，比“一屏两卡”更稳
- 手动指定模式与自动最近模式都能复用同一数据结构

建议信息层级：

1. 背景图
2. 活动名
3. 倒计时文案
4. 日期 / 城市辅助信息

建议文案：

- `距离 XXX 还有 X 天`

辅助信息建议：

- `2026.08.14`
- `Shanghai`

### 6.3 第一版不做的布局

以下布局不进入第一版：

- Medium 双活动卡片
- 横向滑动
- 根据剩余天数自动切换成不同版式
- Widget 内按钮切换上一个 / 下一个活动

---

## 7. 用户流程

### 7.1 自动最近活动模式

1. 用户长按桌面添加 Raver Widget
2. 选择 `Small` 或 `Medium`
3. 进入配置页
4. 选择 `自动最近活动`
5. 系统保存配置
6. Widget 显示最近开始的已关注活动
7. 用户点击 Widget
8. App 打开并进入该活动详情页

### 7.2 手动指定活动模式

1. 用户长按桌面添加 Raver Widget
2. 选择 `Small` 或 `Medium`
3. 进入配置页
4. 选择 `手动指定活动`
5. 从关注活动列表中选中一个 event
6. 系统保存该 event ID
7. Widget 固定展示该活动
8. 用户点击 Widget
9. App 打开并进入该活动详情页

### 7.3 数据失效流程

若手动指定活动已开始、被取消关注、或数据不存在：

1. Widget 检测配置的 event 已无效
2. 自动尝试切换为最近未开始的关注活动
3. 若仍无数据，则展示空状态

---

## 8. 技术设计总览

第一版建议的技术方案如下：

### 8.1 技术栈

- `WidgetKit`
- `SwiftUI`
- `AppIntents`
- `App Group`
- 共享 JSON 缓存文件或共享 `UserDefaults`

### 8.2 推荐架构

建议新增以下模块：

- 主 App：
  - 负责登录态内真实关注活动数据拉取
  - 负责数据筛选、格式化、共享缓存落盘
  - 负责触发 Widget 刷新
- Widget Extension：
  - 读取共享数据
  - 根据用户配置渲染 Small / Medium
  - 处理空状态与失效回退逻辑

### 8.3 推荐数据流

1. 用户打开 App
2. App 请求关注活动接口
3. App 过滤未开始活动并排序
4. App 将 Widget 所需最小字段写入 App Group 共享存储
5. App 调用 `WidgetCenter.shared.reloadAllTimelines()`
6. Widget TimelineProvider 读取共享数据
7. 根据配置模式选取活动并渲染

---

## 9. 共享数据模型设计

建议不要把完整 Event 模型原样塞给 Widget，而是定义专用轻量模型。

### 9.1 Widget Event 数据模型

```swift
struct WidgetFollowedEvent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let startDateISO8601: String
    let endDateISO8601: String?
    let coverImageURL: String?
    let lineupImageURL: String?
    let city: String?
    let venueName: String?
    let deeplinkURL: String
    let lastSyncedAtISO8601: String
}
```

### 9.2 共享快照模型

```swift
struct WidgetFollowedEventsSnapshot: Codable {
    let version: Int
    let generatedAtISO8601: String
    let events: [WidgetFollowedEvent]
}
```

### 9.3 配置模型

```swift
enum CountdownWidgetMode: String, Codable {
    case automaticNearest
    case manualEvent
}

struct CountdownWidgetSelection: Codable {
    let mode: CountdownWidgetMode
    let manualEventID: String?
}
```

### 9.4 为什么要单独建模

好处：

- 避免 Widget 依赖主工程超大模型
- 减少解析与存储成本
- 降低主模型改动对 Widget 的影响
- 更适合做版本迁移

---

## 10. 共享存储方案

### 10.1 推荐方案

第一版推荐：

- `App Group + shared container JSON file`

建议原因：

- 结构清晰
- 可调试性强
- 容量比 `UserDefaults` 更稳
- 后续更适合增加版本号、时间戳与调试字段

### 10.2 App Group 命名建议

建议命名：

- `group.com.raver.mvp`

如未来需要区分正式 / 测试环境，可扩展：

- `group.com.raver.mvp.dev`
- `group.com.raver.mvp.prod`

### 10.3 文件路径建议

共享文件建议：

- `followed-events-widget-snapshot.json`

放在：

- `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`

### 10.4 写入原则

- 每次写入使用全量覆盖
- 写入前先构造完整快照
- 写入成功后再触发 Widget 刷新

### 10.5 读取失败兜底

若 Widget 读取快照失败：

- 输出空状态
- 不崩溃
- 记录日志便于排查

---

## 11. Widget 配置方案

由于你已确定支持：

- 自动最近活动
- 手动指定活动

第一版建议使用 `AppIntentConfiguration`。

### 11.1 配置项设计

建议配置项：

- `displayMode`
  - `automaticNearest`
  - `manualEvent`
- `selectedEvent`
  - 仅当 `manualEvent` 时生效

### 11.2 配置体验

用户在添加 Widget 时：

- 先选模式
- 若选手动，则展示可选活动列表

### 11.3 动态选项来源

动态活动列表应来自共享快照中的有效活动集合，而不是再次发网络请求。

原因：

- Widget 配置界面应尽量快
- 避免网络依赖导致配置页不稳定
- 与主 App 数据口径保持一致

---

## 12. 时间线与刷新策略

### 12.1 Timeline 刷新原则

第一版建议同时使用两类刷新：

- 主 App 数据刷新后主动触发 `reload`
- Widget 自身 Timeline 定时刷新

### 12.2 推荐刷新粒度

由于第一版按“天”显示倒计时，建议 Timeline 更新频率不要过高。

推荐：

- 每天本地时间 `00:05` 左右刷新一次
- 以及当前活动开始后尽快切到下一条或空状态

### 12.3 推荐策略

Timeline 可按以下关键时间点生成 entry：

- 当前时刻
- 次日凌晨
- 当前活动开始时间之后的短延迟点

这样可以保证：

- 跨天时剩余天数自动变化
- 活动开始后及时失效并切换

### 12.4 不建议的策略

第一版不建议：

- 每小时刷新
- 每 15 分钟刷新

原因：

- 文案精度只到“天”
- 过高刷新频率没有明显收益

---

## 13. 深链设计

### 13.1 点击跳转规则

用户点击 Small / Medium Widget 后：

- 统一打开活动详情页

### 13.2 URL 方案建议

建议使用统一深链格式：

```text
raver://events/{eventId}
```

或若已有 universal link 体系，也可兼容：

```text
https://raver.app/events/{eventId}
```

### 13.3 App 端解析逻辑

App 收到深链后需要：

1. 解析 event ID
2. 切换到活动模块
3. 打开 `EventDetailView`

### 13.4 空状态跳转

若 Widget 当前为无数据空状态：

- 点击可跳转至 `events` 列表页或发现页

---

## 14. UI 与视觉要求

### 14.1 背景图优先级

固定规则：

1. `coverImageUrl`
2. `lineupImageUrl`
3. 渐变占位背景

### 14.2 文案可读性

必须满足：

- 所有背景图上都加深色蒙层
- 活动名最多两行
- 倒计时数字与文案有足够对比度

### 14.3 图片异常处理

若图片拉取失败：

- 不显示破图
- 自动使用渐变背景

### 14.4 文本截断规则

活动名较长时：

- Small：最多 2 行
- Medium：最多 2 行
- 超出使用尾部截断

### 14.5 建议视觉方向

结合 Raver 场景，建议不要做过于通用的 iOS 默认卡片风格，而是保留电子音乐活动的沉浸感：

- 强对比封面图
- 深色玻璃感遮罩
- 倒计时数字更有张力
- 保持信息极简，不堆字段

---

## 15. 工程改造清单

### 15.1 Xcode 工程层

需要新增：

- 一个 Widget Extension target

建议命名：

- `RaverCountdownWidget`

需要修改：

- `project.yml`
- App entitlements
- Widget entitlements

### 15.2 Capabilities

主 App 与 Widget Extension 都需要开启：

- `App Groups`

### 15.3 主 App 侧新增模块建议

建议新增：

- `WidgetSync`
- `WidgetSharedModels`
- `WidgetDeepLinkRouter`

可选目录建议：

- `RaverMVP/Core/Widget/`

建议文件示例：

- `WidgetFollowedEvent.swift`
- `WidgetSnapshotStore.swift`
- `WidgetSyncService.swift`
- `WidgetDeepLink.swift`

### 15.4 Widget Extension 侧新增模块建议

建议文件示例：

- `RaverCountdownWidget.swift`
- `CountdownWidgetProvider.swift`
- `CountdownWidgetEntry.swift`
- `CountdownWidgetView.swift`
- `CountdownWidgetIntent.swift`

---

## 16. 接口与数据口径建议

### 16.1 需要的最小接口能力

第一版至少需要以下一种真实来源：

- `GET /v1/events/favorites`
- 或现有可复用的“收藏活动”接口

接口返回应包含：

- `id`
- `name`
- `startDate`
- `endDate`
- `coverImageUrl`
- `lineupImageUrl`
- `city`
- `venueName`

### 16.2 服务端过滤建议

建议服务端支持直接返回：

- 当前用户已关注活动
- 且仅未开始活动

原因：

- 客户端逻辑更简单
- Widget 数据口径更统一
- 避免不同端对“未开始”定义不一致

### 16.3 客户端二次兜底

即便服务端已经过滤，客户端仍应二次校验：

- 开始时间是否已过
- 必要字段是否缺失

---

## 17. 分阶段实施路线

以下路线以“真实可交付第一版”为目标，不走纯 Demo 路线。

### Phase 0：需求冻结与依赖确认

目标：

- 冻结产品规则
- 确认接口与深链依赖

任务：

- 确认“关注活动”接口与字段契约
- 确认活动详情页 deep link 方案
- 确认 App Group 命名
- 确认 Widget target 命名

完成标准：

- 文档内规则不再变动
- 技术实现不再存在方向分叉

### Phase 1：数据链路打通

目标：

- 让主 App 能拿到真实、可用于 Widget 的关注活动数据

任务：

- 打通已关注活动接口
- 实现“仅未开始活动”过滤
- 设计轻量 Widget 数据模型
- 实现 App Group 共享快照存储

完成标准：

- 本地可看到生成后的共享 JSON 快照
- 数据内容正确、排序正确

### Phase 2：Widget 基础框架搭建

目标：

- 新增 Widget Extension 并完成基础渲染

任务：

- 新增 Widget target
- 接入 `AppIntentConfiguration`
- 实现 TimelineProvider
- 实现 Small / Medium 静态渲染
- 实现空状态

完成标准：

- 模拟器中可成功添加 Widget
- 可读取共享数据并展示

### Phase 3：配置能力与跳转打通

目标：

- 完成自动 / 手动两种模式
- 完成点击跳转活动详情

任务：

- 配置模式选择
- 手动指定活动列表
- 活动失效回退逻辑
- 深链解析与活动详情跳转

完成标准：

- 手动指定能稳定生效
- 点击 Widget 能正确打开对应活动

### Phase 4：视觉打磨与异常处理

目标：

- 提升可读性和稳定性

任务：

- 背景蒙层调优
- 长标题截断优化
- 图片缺失 / 下载失败降级
- 日期跨天刷新验证

完成标准：

- Small / Medium 均达到可上线视觉质量
- 极端数据不破版

### Phase 5：测试、验收与上线准备

目标：

- 达到稳定交付标准

任务：

- 真机测试
- 冷启动与登录态测试
- 多账号切换测试
- 无网场景测试
- 文档补全

完成标准：

- 所有 P0 / P1 问题关闭
- 可进入发布流程

---

## 18. 建议排期

下面给一个偏稳妥的排期建议，可按 1 人开发估算。

### 18.1 理想排期

- 第 1 天：
  - Phase 0
  - Phase 1 启动
- 第 2 天：
  - 完成 Phase 1
  - 启动 Phase 2
- 第 3 天：
  - 完成 Phase 2
  - 启动 Phase 3
- 第 4 天：
  - 完成 Phase 3
  - 启动 Phase 4
- 第 5 天：
  - 完成 Phase 4
  - Phase 5 测试与收尾

### 18.2 更现实排期

若“关注活动真实接口”仍有不确定性，建议按 `1~2 周` 评估：

- 第 1 周：
  - 数据链路
  - Widget 基础框架
  - 自动最近活动模式
- 第 2 周：
  - 手动指定活动
  - 深链
  - 视觉打磨
  - 测试与修复

---

## 19. 验收标准

### 19.1 功能验收

- 可成功添加 `Small` Widget
- 可成功添加 `Medium` Widget
- 自动最近活动模式可正常工作
- 手动指定活动模式可正常工作
- 仅展示未开始的已关注活动
- 点击 Widget 可进入对应活动详情

### 19.2 展示验收

- 背景图优先使用 `cover`
- `cover` 缺失时降级为 `lineup`
- 两者都缺失时显示占位渐变背景
- 长活动名不破版
- 深浅背景下文案都清晰可读

### 19.3 稳定性验收

- 无关注活动时显示空状态
- 手动指定活动失效时可自动回退
- 跨天后剩余天数会自动更新
- 活动开始后不继续展示过期内容
- 无网络时仍可展示最近一次缓存结果

---

## 20. 测试清单

### 20.1 功能测试

- 添加 Small Widget
- 添加 Medium Widget
- 自动模式展示最近活动
- 手动模式展示指定活动
- 删除关注后 Widget 回退
- 活动开始后 Widget 切换

### 20.2 数据测试

- 只有 1 个关注活动
- 有多个关注活动
- 活动列表为空
- 活动缺少 cover
- 活动缺少 lineup
- 活动名称超长

### 20.3 生命周期测试

- App 首次登录后同步
- App 冷启动后同步
- 前后台切换后同步
- 切换账号后数据刷新
- 退出登录后清空共享快照

### 20.4 系统级测试

- 真机锁屏后观察刷新行为
- 不同系统语言环境
- 不同时区
- 深色 / 浅色模式

---

## 21. 风险清单

### 21.1 风险：关注活动接口不稳定

影响：

- Widget 无法接真实数据

应对：

- 在 Phase 0 明确唯一数据来源
- 若当前接口分散，先在 BFF 聚合统一返回

### 21.2 风险：Widget 远程图片不稳定

影响：

- 首屏展示质量不稳定

应对：

- 先做图片失败降级
- 后续必要时做共享图片缓存

### 21.3 风险：深链路由不完整

影响：

- 点击 Widget 后无法准确进入活动详情

应对：

- 将 deep link 打通列为 Phase 3 必做项

### 21.4 风险：账号切换导致脏数据

影响：

- Widget 可能展示上一个账号的活动

应对：

- 登录成功后全量重写快照
- 退出登录时清空共享数据

### 21.5 风险：时间口径不一致

影响：

- “还有 X 天”显示错误

应对：

- 使用统一的日期解析与天数计算方法
- 补充跨时区测试

---

## 22. 回滚策略

若第一版上线后发现严重问题，可按以下顺序降级：

1. 关闭手动指定模式，仅保留自动最近活动
2. 关闭图片背景，仅保留纯色或渐变底
3. 关闭 Medium，仅保留 Small
4. 临时隐藏 Widget 能力入口，待修复后恢复

---

## 23. 进度跟踪模板

以下模板建议直接复制到任务看板或周报中使用。

### 23.1 总体进度

| 模块 | 状态 | 负责人 | 计划完成时间 | 实际完成时间 | 备注 |
|---|---|---|---|---|---|
| 需求冻结 | 未开始 |  |  |  |  |
| 关注活动接口确认 | 未开始 |  |  |  |  |
| 深链方案确认 | 未开始 |  |  |  |  |
| App Group 配置 | 未开始 |  |  |  |  |
| 共享快照模型 | 未开始 |  |  |  |  |
| 主 App 数据同步 | 未开始 |  |  |  |  |
| Widget Target 搭建 | 未开始 |  |  |  |  |
| Small UI | 未开始 |  |  |  |  |
| Medium UI | 未开始 |  |  |  |  |
| 自动最近活动模式 | 未开始 |  |  |  |  |
| 手动指定活动模式 | 未开始 |  |  |  |  |
| 点击跳转详情 | 未开始 |  |  |  |  |
| 空状态与失效回退 | 未开始 |  |  |  |  |
| 真机测试 | 未开始 |  |  |  |  |
| 上线验收 | 未开始 |  |  |  |  |

状态建议统一使用：

- `未开始`
- `进行中`
- `阻塞`
- `已完成`

### 23.2 每日推进记录

| 日期 | 今日完成 | 当前阻塞 | 明日计划 |
|---|---|---|---|
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |

### 23.3 风险跟踪

| 风险 | 等级 | 当前状态 | 应对动作 | Owner |
|---|---|---|---|---|
| 关注活动接口不稳定 | P0 | 未处理 | 统一接口口径 |  |
| Deep Link 未打通 | P0 | 未处理 | 增补路由能力 |  |
| 远程图片不稳定 | P1 | 未处理 | 增加降级背景 |  |
| 账号切换脏数据 | P1 | 未处理 | 登录退出时清缓存 |  |

---

## 24. 建议的实施顺序

如果立刻开始做，我建议严格按这个顺序推进：

1. 先确认“关注活动真实接口”和字段口径
2. 再补 `deep link` 到活动详情页
3. 再做 `App Group + 共享快照`
4. 再创建 Widget target
5. 先做自动最近活动模式
6. 再做手动指定活动模式
7. 最后做视觉打磨和测试

不要反过来先做 UI。

原因：

- 这个功能的主要风险不在界面，而在数据链路和系统集成
- 先把数据与跳转打通，Widget 本身只是最后一层渲染

---

## 25. 后续版本建议

在第一版稳定后，可考虑第二版扩展：

- Lock Screen Widget
- Medium 双活动布局
- 即将开始时切换为更细粒度文案
- 交互式切换活动
- 票务状态联动
- 与通知偏好联动

但这些都不应影响第一版的收敛。

---

## 26. 结论

这个 Widget 功能非常适合作为 Raver 的 iOS 增强能力，因为它直接放大了你们最有情绪价值的一件事：`我关注的活动，正在越来越近`。

第一版的关键不是把 Widget 做花，而是把下面三件事做稳：

- 真实关注活动数据
- 活动详情深链
- App 与 Widget 的共享快照机制

只要这三件事打通，Small + Medium 的倒计时 Widget 就可以成为一个完整、可上线、可继续扩展的能力。
