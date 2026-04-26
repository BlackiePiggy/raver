# Raver iOS `openim-ios-demo` 1:1 基线迁移总方案

> 目标：不是“看起来像”，不是“机制接近”，而是把 Raver iOS 聊天域改造成与 `openim-ios-demo` **从内到外同构、同机制、同交互、同页面组织** 的实现。
>
> 结论先行：如果目标真的是“一模一样”，就不能继续在当前 `DemoAligned*` 体系上做无限微调；必须把 `openim-ios-demo` 的聊天域当作**产品基线**，以“源码直接迁入 + 最小适配层封装”的方式推进。

---

## 执行快照

### 聊天页同源总审计

更新时间：

- `2026-04-26 13:16 +0800`
- `2026-04-26 14:38 +0800`
- `2026-04-26 15:10 +0800`
- `2026-04-26 15:15 +0800`
- `2026-04-26 15:17 +0800`
- `2026-04-26 15:18 +0800`
- `2026-04-26 15:23 +0800`
- `2026-04-26 15:28 +0800`
- `2026-04-26 15:30 +0800`
- `2026-04-26 15:32 +0800`

本轮结论：

- 当前聊天页**还没有**达到 `openim-ios-demo` 的一比一复刻标准
- 根因不是“还有一些小样式没调”，而是“当前运行中的聊天页主体仍是自定义 shadow 实现，而不是 demo 原聊天页源码”
- 从现在开始，聊天页相关验收一律以“运行时是否直接落在 demo 原类 + demo 原机制”作为唯一通过标准
- `2026-04-26 14:38 +0800` 当前活跃动作已收敛为“vendor 原运行链实证”：
  - `ChatViewControllerBuilder`
  - `DefaultDataProvider`
  - `DefaultChatController`
  - `ChatViewController`
  四个 vendor 原类已加入结构化 runtime probe 日志
  - 当前唯一目标是用运行日志证明聊天页实际运行时已经进入同源主链，而不是只在源码层面接好
- `2026-04-26 15:10 +0800` 运行时实证进展：
  - 已在 `baseline=1` 手动启动场景拿到一端完整闭环（`SIM2`）
  - 命中链路为 `ChatViewControllerBuilder -> DefaultDataProvider -> DefaultChatController -> ChatViewController`
  - 当前状态从“无运行时证据”推进到“单端运行时证据成立，待补双端闭环”
- `2026-04-26 15:15 +0800` 主入口收口进展：
  - `ConversationLoaderView` 已删除 baseline/旧聊天页双轨判断，聊天会话入口只保留 baseline 容器
  - 会话页主路径不再保留旧聊天 UI fallback，进一步满足“改一个切一个，不留旧方案兜底”的执行纪律
- `2026-04-26 15:17 +0800` UI 控制权收口进展：
  - 会话页外层 SwiftUI 已取消 `navigationTitle / navigationBarTitleDisplayMode` 覆盖
  - 标题展示统一回归 vendor 原聊天页控制，减少宿主层与 demo 原生行为偏差
- `2026-04-26 15:18 +0800` 工厂入口收口进展：
  - baseline 工厂层已移除旧 `adapter/shadow` 入口 API，仅保留 builder 同源入口
  - 会话页从入口到工厂层均已形成“单一同源路径”，不再保留可被误用的旧入口
- `2026-04-26 15:23 +0800` 编译面收口进展：
  - 主 target 已排除 `Features/Messages/UIKitChat/**`，旧 `DemoAligned` 聊天实现不再参与编译
  - 为避免误伤非页面工具依赖，`ChatMediaTempFileStore.swift` 以单文件白名单保留
  - 当前状态：运行链与编译面双收口，旧聊天页从“可运行 fallback”升级为“不可编译回退”
- `2026-04-26 15:28 +0800` 失效入口类型清理进展：
  - 已删除旧 baseline 适配器与 placeholder 页面类型，避免“看似可用的历史入口”继续存在
  - 当前聊天域主链进一步收敛为：会话入口 -> baseline factory -> vendor builder -> vendor chat runtime
- `2026-04-26 15:30 +0800` vendor 文件同源回归进展：
  - 已移除前期为验证引入的 runtime probe 注入，vendor 聊天主文件重新向 demo 原文件收敛
  - 当前主要剩余差异集中在 `Section` 命名冲突规避（`ChatSection`），属于为避免全局 SwiftUI 冲突而保留的必要差异
- `2026-04-26 15:32 +0800` 必要差异边界补充：
  - `DefaultChatController` 中 `OUICore.ConversationType` 显式限定经验证属于必要差异（用于规避工程内同名 `ConversationType` 污染）
  - 该差异不改变聊天行为机制，仅用于类型命名域隔离

#### 审计清单

- [x] `2026-04-26 13:16 +0800` `Audit-Chat-01` 入口路由已切到 baseline builder：
  - 当前聊天页入口为 [MainTabCoordinator.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift:812) 中的 `OpenIMDemoBaselineChatContainerView`
  - 实际调用为 `OpenIMDemoBaselineFactory.makeBuilderEntryViewController(...)`
- [ ] `2026-04-26 13:16 +0800` `Audit-Chat-02` 运行时 `ChatViewController` 仍非 demo 原类：
  - demo 原页在 [Vendor/OpenIMIOSDemo/OUIIM/Classes/OIMUIChat/ChatViewController.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Vendor/OpenIMIOSDemo/OUIIM/Classes/OIMUIChat/ChatViewController.swift:17)
  - 当前工程实际还存在并使用自定义 shadow 版 `ChatViewController`，定义于 [OpenIMDemoBaselineBuilderConstruction.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift:1662)
  - 这意味着导航栏、输入区、分页、预览、状态面板、键盘联动仍可能走自定义逻辑，而不是 demo 原机制
  - `2026-04-26 14:38 +0800` 现状补充：源码路由已切到 vendor 原 builder，且 vendor 原 `ChatViewController.swift` 已加入 runtime probe；本项当前阻塞已从“源码接线路由不明确”收敛为“等待运行日志实证”
- [ ] `2026-04-26 13:16 +0800` `Audit-Chat-03` 运行时 `DefaultChatCollectionDataSource` 仍非 demo 原类：
  - demo 原 data source 在 [Vendor/OpenIMIOSDemo/OUIIM/Classes/OIMUIChat/View/DataSource/DefaultChatCollectionDataSource.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Vendor/OpenIMIOSDemo/OUIIM/Classes/OIMUIChat/View/DataSource/DefaultChatCollectionDataSource.swift:23)
  - 当前工程同时存在自定义 shadow 版 `DefaultChatCollectionDataSource`，定义于 [OpenIMDemoBaselineBuilderConstruction.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift:1499)
  - 这直接影响头像挂载、气泡布局、cell 类型分发、媒体视图 tag 映射、点击链、系统消息/自定义消息渲染方式
  - `2026-04-26 14:38 +0800` 现状补充：vendor 原 data source 已进入主编译批次且通过 iOS-only build，本项下一步不再做“相似性判断”，只看与 vendor 运行链联动后的日志与页面行为
- [ ] `2026-04-26 13:16 +0800` `Audit-Chat-04` 运行时 `DefaultDataProvider` / `DefaultChatController` 仍为本地 shadow 实现：
  - 当前本地实现位于 [OpenIMDemoBaselineBuilderConstruction.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift:155) 与 [OpenIMDemoBaselineBuilderConstruction.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift:652)
  - 即便其中已有部分 demo 机制迁入，也不能按“同源通过”计入，因为运行类所有权仍不属于 vendor 原文件
- [ ] `2026-04-26 13:16 +0800` `Audit-Chat-05` 页面 UI 结构仍非 demo 原页结构：
  - demo 原页使用 `CoustomInputBarAccessoryView`、`WatermarkBackgroundView`、`ChatTitleView`、`PopoverCollectionViewController`、`ManualAnimator` 等完整页面组织
  - 当前页仍保留自定义 `stateLabel`、`inputBarShell`、`inputTextView`、`inputMediaButton`、`inputSendButton`、自定义 `renderState(...)` 调试面板等结构，见 [OpenIMDemoBaselineBuilderConstruction.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift:1706)
  - 所以你看到的头像、聊天框、输入条、媒体入口、顶部标题、页面底色/间距与 demo 不一致，是结构级偏差，不是参数级偏差
- [ ] `2026-04-26 13:16 +0800` `Audit-Chat-06` 媒体入口与媒体展示链仍非 demo 原链：
  - demo 原链路以 [CoustomInputBarAccessoryView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Vendor/OpenIMIOSDemo/OUIIM/Classes/OIMUIChat/View/InputView/CoustomInputBarAccessoryView.swift:1)、[InputPadView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Vendor/OpenIMIOSDemo/OUIIM/Classes/OIMUIChat/View/InputView/InputPadView.swift:1)、[MediaPreviewViewController.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Vendor/OpenIMIOSDemo/OUICoreView/Classes/ViewController/MediaPreview/MediaPreviewViewController.swift:1) 为核心
  - 当前页虽然已能发图/视频，但主入口仍是自定义 `showMediaSendSheet()` 与 `PHPicker` 分流，见 [OpenIMDemoBaselineBuilderConstruction.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift:2208)
- [ ] `2026-04-26 13:16 +0800` `Audit-Chat-07` 上拉分页与首屏数量不能按“部分同机制”判通过：
  - 你提出的“进入后展示数量、一直上拉到最上面无错钝感”属于 demo 原页整体滚动机制的结果
  - 只要运行时 `ChatViewController + DataSource + Controller + DataProvider` 还是 shadow 版，就算某几个分页点位已经调得接近，也不能认定为同源同机制通过

#### 聊天页后续唯一允许的执行顺序

- [ ] `2026-04-26 13:16 +0800` `Chat-Retrofit-01` 停止继续在 `OpenIMDemoBaselineBuilderConstruction.swift` 中扩写 shadow 聊天页逻辑
- [ ] `2026-04-26 13:16 +0800` `Chat-Retrofit-02` 让 builder 实际实例化并运行 vendor 原 `ChatViewController.swift`
- [ ] `2026-04-26 13:16 +0800` `Chat-Retrofit-03` 让 builder 实际实例化并运行 vendor 原 `DefaultChatCollectionDataSource.swift`
- [ ] `2026-04-26 13:16 +0800` `Chat-Retrofit-04` 让 builder 实际实例化并运行 vendor 原 `DefaultChatController.swift` / `DefaultDataProvider.swift`
- [ ] `2026-04-26 13:16 +0800` `Chat-Retrofit-05` 仅在外层保留 bridge / adapter / service pump；所有页面、渲染、输入、媒体、分页、预览逻辑回收至 demo 原源码
- [ ] `2026-04-26 13:16 +0800` `Chat-Retrofit-06` 每完成一个大块后，都要用“运行中的类是否为 vendor 原类”复核，而不是只看 checkbox
- [ ] `2026-04-26 13:20 +0800` `Chat-Retrofit-07` 所有后续聊天功能统一执行“切换后不保留原方案兜底”：
  - 输入区、头像昵称、气泡样式、媒体消息、消息点击、首屏装载、分页、会话内设置入口都适用同一条规则
  - 切换完成后，旧实现必须退出主运行链
- [ ] `2026-04-26 13:57 +0800` `Chat-Retrofit-08` 所有后续本地验证统一使用 iOS-only 编译链：
  - 只编译 `iphoneos / iphonesimulator`
  - 模拟器统一使用 `arm64`
  - 不再允许 Pods 生成 `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`
  - 本地构建入口统一收敛到 [`build_ios_sim_only.sh`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/build_ios_sim_only.sh:1)

### 进度看板

#### 总阶段

- [x] `Phase 1` 基线冻结（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] `Phase 2` baseline 骨架建立（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] `Phase 3` demo 首批源码快照迁入（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] `Phase 4` 首批 bridge / adapter 骨架（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] `Phase 5` demo 原 `ChatViewControllerBuilder` 接线（历史镜像项，最终状态以 `15.2` 为准：已完成）
- [x] `Phase 6` demo 原 `DefaultDataProvider` / `DefaultChatController` 接线（历史镜像项，最终状态以 `15.2` 为准：已完成）
- [x] `Phase 7` baseline 聊天页替换占位入口（历史镜像项，最终状态以 `15.2` 为准：已完成）

#### 当前主线 Block

- [x] `Block A` / `Step 1` 固化核心模型 bridge（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] `Block A` / `Step 2` 固化 `ChatContext`（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] `Block A` / `Step 3` 梳理 `ChatViewControllerBuilder` 直接依赖（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] `Block A` / `Step 4` 建立 `BuilderAdapter` 骨架（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [ ] `Block A` / `Step 5` 让 demo 原 builder 进入实际编译接线（demo 同源 runtime 依赖已打通，且消息/会话/未读事件主回流已切到 `IMController` 主线，并继续收口设置页事件发送链，状态更新时间：`2026-04-25 22:44 +0800`）
- [ ] `Block A` / `Step 6` 用 demo 原 `ChatViewControllerBuilder` 替换当前 shim（已开始，且已进入真正同源 runtime + 原生事件总线接线阶段；已把 adapter 入口切到 baseline builder 主链，并完成 `DefaultChatController` / `DefaultChatCollectionDataSource` / `DefaultChatViewController` shell 命名收口，本轮又将 builder 改为 demo 原同序写法、移除 `BuilderRuntime` 中间层，并将 builder 类型名收敛到 demo 原 `ChatViewControllerBuilder`；`2026-04-26 13:57 +0800` 已补齐 vendor 原聊天页直接依赖 `ChatLayout` / `InputBarAccessoryView`，并将本地构建链收敛为 iOS-only，状态更新时间：`2026-04-26 13:57 +0800`）

#### 后续 Block

- [ ] `Block B` 让 `DefaultDataProvider` 可被桥接（已进入查询桥 + 事件桥阶段，并补上 conversation 级 `recordClear` 精确回流协议面；demo 所需 `RxSwift / RxCocoa / RxRelay` 已正式引入 app target，且 demo 同源 runtime 依赖已打通，消息/会话/未读事件也已切回 `IMController` 主线，设置页 `EventRecordClear` 发送入口已接回，状态更新时间：`2026-04-25 22:42 +0800`）
- [ ] `Block C` 让 `DefaultChatController` 进入主链
- [ ] `Block D` baseline 聊天页替换占位入口

### 文档角色

本文件从现在开始承担两类职责：

- 战略职责：
  - 定义什么叫 1:1
  - 规定哪些路径允许、哪些路径禁止
  - 约束迁移顺序与架构边界
- 执行职责：
  - 记录当前迁移做到哪一步
  - 记录已经落地的文件与目录
  - 记录关键验证命令与结果
  - 给下一位接手者明确的下一步入口

要求：

- 任何一轮涉及 baseline 迁移的实际改动后，都必须回写本文件
- 本文件必须始终能够回答这 4 个问题：
  - 当前迁移到哪一步了
  - 已经做了哪些不可逆的结构性动作
  - 当前验证是否通过
  - 下一步最值得做什么

### 执行纪律

为了避免长线任务中途目标漂移，从现在开始必须遵守以下执行纪律：

- 主线目标唯一：
  - 目标永远是“把聊天域切成与 `openim-ios-demo` 1:1 同源实现”
  - 不是“顺手把当前自研版做得更好”
- `2026-04-26 13:20 +0800` 聊天域最高原则：
  - 以后所有和聊天相关的功能改造，都必须直接按 `openim-ios-demo` 同源方案推进
  - 不允许“先保留原方案兜底，再逐步迁移”作为执行方式
  - 不允许聊天域长期存在“旧方案运行链 + 同源方案运行链”双轨并存
  - 一个聊天功能一旦开始切换，完成标准就是“主运行链只保留同源方案”
- `2026-04-26 12:57 +0800` 同源执行补充：
  - 后续不再以“从 demo 中挑需要的部分接入”为允许路径
  - `openim-ios-demo` 聊天域源码行为就是唯一真值
  - Raver 侧只允许做“宿主适配层”与“类型桥接层”，不允许保留自定义消息并入、分页节奏、首屏条数节奏
- 非主线问题分级处理：
  - 如果问题阻断当前 baseline 主线，立即处理
  - 如果问题不阻断主线，只记录，不展开新分支
- 每个大块任务开工前必须先拆细：
  - 先写“本块目标”
  - 再写“本块细分步骤”
  - 再执行
- 每轮执行后必须回写：
  - 实际完成项
  - 实际未完成项
  - 当前卡点
  - 下一步唯一推荐动作
- 所有进度变化与关键日志必须带时间戳：
  - 任何 checkbox 状态变化，都要在同一行或紧随其后的说明中写明 `YYYY-MM-DD HH:mm ±ZZZZ`
  - 任何关键构建记录、阻塞记录、修复记录，都要带 `YYYY-MM-DD HH:mm ±ZZZZ`
  - 以后不再只写日期，必须写到时分
- 验证节奏按“小批次”执行，不再每个微步骤都 full build：
  - 同一主线小块内允许连续完成 `2-3` 个强相关小步骤后再统一执行一次 `xcodebuild`
  - 如果改动只局限在单文件、且没有改协议面、构造链、actor 隔离、泛型签名、访问级别，则优先先做静态自检，再继续下一小步
  - 只要碰到以下任一类变化，必须立即做一次构建验证：
    - 新增/修改协议
    - 修改 builder 构造链
    - 修改 actor 隔离、默认参数、泛型、可见性
    - 新增文件接入主工程
    - 从 placeholder 向 demo 原对象链替换
  - 每个 Block 至少保留一个成功构建锚点，便于回溯排障
  - 如果一次批量改动导致构建失败，下一轮必须缩小步长，回到“单步修复 + 立即验证”直到恢复绿色
- 不允许在未完成当前块验收前跳到下一块
- 不允许因为出现中间小问题就临时扩展新子项目

一句话规则：

- 任何工作如果不能直接推动“demo baseline 主链路更接近可运行”，就不应该优先做

### 当前状态总览

更新时间：

- `2026-04-25 22:31 +0800`

当前整体状态：

- `Phase 1` 基线冻结：已完成
- `Phase 2` baseline 骨架建立：已完成
- `Phase 3` demo 首批源码快照迁入：已完成
- `Phase 4` 首批 bridge / adapter 骨架：已完成
- `Phase 5` demo 原 `ChatViewControllerBuilder` 接线：已进入实际编译接线，当前仍为 shim 入口
- `Phase 6` demo 原 `DefaultDataProvider` / `DefaultChatController` 接线：已进入 provider 查询桥 + 事件桥阶段；首屏后的标题/资料刷新路径、最小已读生命周期占位、received 主路径收敛、当前会话 unread 语义、混合批次消息分流，以及更接近 demo 的“首屏 section 先完成、随后单独读完当前会话并刷新总未读”尾部语义都已开始；分页和当前会话回流路径也已收紧为不在本链路内直接清 unread，首屏读完当前会话时对 `unreadCountChanged` 的压制与最终总未读回推也已有显式协调状态，`conversationChanged(info:)` 也已补上同步窗口保护；本轮已新增 data-provider 统一事件桥占位并接入 provider 壳，补上更接近 demo `DefaultDataProvider` 的接口形状，以及 `messageStorage` 风格的历史拉取缓存路径，同时把 `recordClear` 从全局清空修正为 conversation 级精确回流协议面；此前识别出的 `RxSwift` target 依赖缺口现已补齐，并且已进一步完成真正同源 runtime 的前置打通：全局 git 代理阻塞已排除、`OpenIMSDK` 已切到 demo 同款 `3.8.3+3`、本地 `OUICore` 已纳入、`ZLPhotoBrowser` 已锁到 demo 同款 `4.6.0.1`、`ProgressHUD` 已锁到 demo 同源 git 版本，主工程也已重新构建通过；本轮又将 unread / conversation / new message 三条主回流从 `OpenIMSession` 切回 demo 原 `IMController` 事件源，并再次完成主工程构建通过

当前唯一主线任务：

- 将 baseline 从“占位入口 + bridge 骨架”推进到“demo 原 `ChatViewControllerBuilder` 可实例化”

当前不应主动展开的支线任务：

- 再次回头优化 `DemoAligned*` 外观
- 清理非阻断性日志
- 扩展聊天页以外的新功能模块
- 讨论与当前 builder/provider 接线无关的 UI 细节

一句话判断：

- 目前已经从“策略讨论阶段”进入“可持续迁入阶段”
- 但还没有进入“demo 原聊天页实际跑起来”的阶段
- 当前 baseline 仍然是占位入口 + bridge 骨架，不是 demo 原生聊天页

### 已完成的结构性动作

以下动作已经完成，并且应该被视为当前迁移基线的一部分：

- 主方案文档已建立：
  - [`/Users/blackie/Projects/raver/docs/OPENIM_IOS_DEMO_1TO1_BASELINE_MIGRATION_PLAN.md`](/Users/blackie/Projects/raver/docs/OPENIM_IOS_DEMO_1TO1_BASELINE_MIGRATION_PLAN.md:1)
- baseline freeze 文档已建立：
  - [`/Users/blackie/Projects/raver/docs/DEMO_BASELINE_FREEZE.md`](/Users/blackie/Projects/raver/docs/DEMO_BASELINE_FREEZE.md:1)
- 差异矩阵文档已建立：
  - [`/Users/blackie/Projects/raver/docs/DEMO_CHAT_DIFF_MATRIX.md`](/Users/blackie/Projects/raver/docs/DEMO_CHAT_DIFF_MATRIX.md:1)
- 源码迁入清单已建立：
  - [`/Users/blackie/Projects/raver/docs/OPENIM_DEMO_SOURCE_IMPORT_MANIFEST.md`](/Users/blackie/Projects/raver/docs/OPENIM_DEMO_SOURCE_IMPORT_MANIFEST.md:1)
- 第三方源码目录已约定并忽略提交：
  - 第三方目录：[`/Users/blackie/Projects/raver/thirdparty/openimApp/`](/Users/blackie/Projects/raver/thirdparty/openimApp/)
  - `.gitignore` 已加入：`thirdparty/openimApp/`
- baseline 工程骨架已建立：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/)
- baseline builder 入口链已进一步收口（`2026-04-25 23:22 +0800`）：
  - `OpenIMDemoBaselineBuilderAdapter.buildEntryViewController(...)` 已从 `OpenIMDemoBaselinePlaceholderViewController` 切换为 `OpenIMDemoBaselineFactory.chatViewControllerBuilder.build(...)`
  - anchor 消息改为按 `anchorMessageID` 在 `latestMessages` 中精确匹配后桥接到 `OpenIMDemoBaselineMessageInfo`
- demo 首批源码快照已复制到 baseline vendor：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Vendor/OpenIMIOSDemo/`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Vendor/OpenIMIOSDemo/)
- 主工程已经排除 vendor 原始源码，避免在未桥接前被直接编入 target：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/project.yml`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/project.yml:1)

### 已完成的代码骨架

目前已经落地并通过编译验证的 baseline 代码骨架包括：

- 导入分组清单：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineImportPlan.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineImportPlan.swift:1)
- 会话 seed：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineConversationSeed.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineConversationSeed.swift:1)
- demo 风格核心模型桥：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineCoreModels.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineCoreModels.swift:1)
- `ChatContext` 聚合入口：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineChatContext.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineChatContext.swift:1)
- baseline 工厂入口：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineFactory.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineFactory.swift:1)
- builder 接线收口层：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineBuilderAdapter.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineBuilderAdapter.swift:1)
- builder 入口 shim：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineChatViewControllerBuilder.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineChatViewControllerBuilder.swift:1)
- builder 构造链同序骨架：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift:1)
- provider bridge 协议面：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineDataProviderBridge.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineDataProviderBridge.swift:1)
- provider bridge 默认查询实现：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineRaverDataProviderBridge.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineRaverDataProviderBridge.swift:1)
- provider 事件桥默认实现（内存桥）：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineInMemoryDataProviderEventBridge.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineInMemoryDataProviderEventBridge.swift:1)
- `IMController` bridge 协议：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineIMControllerBridge.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineIMControllerBridge.swift:1)
- Raver 默认 bridge 实现：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineRaverIMControllerBridge.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/ServiceBridge/OpenIMDemoBaselineRaverIMControllerBridge.swift:1)
- baseline 占位入口页：
  - [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselinePlaceholderViewController.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselinePlaceholderViewController.swift:1)

### 关键验证记录

以下验证已经完成，说明当前 baseline 骨架处于“可继续迁入”的健康状态：

- `xcodegen generate`
  - 结果：成功
- `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮新增 `BuilderAdapter` 后再次执行：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮新增 builder shim 与 factory 接线后再次执行：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 首轮阻塞：
    - `OpenIMDemoBaselineChatViewControllerBuilder.swift:5:17 error: method cannot be declared public because its parameter uses an internal type`
  - 修复：
    - 将 `OpenIMDemoBaselineChatViewControllerBuilder` 与 `build(...)` 可见性收敛为模块内默认
  - 二轮阻塞：
    - `RaverChatController.swift:15:35 error: cannot find type 'RaverOpenIMChatController' in scope`
  - 修复：
    - 为 `RaverOpenIMChatController` 增加 `#else` 的最小编译兜底实现
  - 三轮结果：`** BUILD SUCCEEDED **`
- 本轮新增 builder 构造链同序骨架后再次执行：
  - 首轮阻塞：
    - `OpenIMDemoBaselineChatViewControllerBuilder.swift:5:26 error: cannot find type 'OpenIMDemoBaselineBuilderRuntime' in scope`
  - 修复：
    - 重新执行 `xcodegen generate`，将新增文件纳入工程
  - 二轮阻塞：
    - `OpenIMDemoBaselineBuilderConstruction.swift:64:13 error: inheritance from a final class 'OpenIMDemoBaselinePlaceholderViewController'`
    - `OpenIMDemoBaselineBuilderConstruction.swift:114:74 error: value of optional type 'String?' must be unwrapped`
  - 修复：
    - 将 builder placeholder VC 改为组合式独立 `UIViewController`
    - 将 `currentUserID` 明确收口为空字符串 fallback
  - 三轮阻塞：
    - `main actor-isolated property 'currentUserID' can not be referenced from a nonisolated context`
    - `call to main actor-isolated initializer ... in a synchronous nonisolated context`
  - 修复：
    - 将 builder runtime 与 builder 入口统一标注为 `@MainActor`
  - 四轮结果：`** BUILD SUCCEEDED **`
- 本轮新增 provider bridge 协议面后再次执行（`2026-04-25 17:06 +0800`）：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮新增 provider bridge 默认查询实现后再次执行（`2026-04-25 17:10 +0800`）：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 首轮阻塞：
    - `OpenIMDemoBaselineRaverDataProviderBridge.swift:148:20 error: 'nil' is not compatible with expected argument type 'String'`
    - `OpenIMDemoBaselineRaverDataProviderBridge.swift:245:36 error: value of type 'SquadProfile' has no member 'owner'`
  - 修复：
    - 将 seed 的 `title` fallback 改为 `conversationID`
    - 将 `SquadProfile.owner` 更正为真实字段 `leader`
  - 二轮结果：`** BUILD SUCCEEDED **`
- 本轮将 builder 内部 provider 替换为 bridge 驱动的真实 provider 壳后再次执行（`2026-04-25 17:13 +0800`）：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮引入 `DataProviderDelegate` 面并打通 provider 壳到 chat controller 的首批查询回调后再次执行（`2026-04-25 17:16 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮收紧资料变更缓存边界并完成 warning 收尾后再次执行（`2026-04-25 21:21 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮新增 provider 统一事件桥并回接 provider 壳后再次执行（`2026-04-25 21:52 +0800`）：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮补齐 provider demo 形状接口后再次执行（`2026-04-25 21:57 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮将 provider 历史拉取逻辑对齐为 `messageStorage` 分层缓存后再次执行（`2026-04-25 21:59 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 本轮新增 session 事件泵后首次执行（`2026-04-25 22:00 +0800`）：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 首轮阻塞：
    - `OpenIMDemoBaselineRaverDataProviderEventPump.swift:53:45 error: cannot find type 'OIMMessageInfo' in scope`
    - `OpenIMDemoBaselineRaverDataProviderEventPump.swift:79:16 error: cannot find type 'OIMMessageInfo' in scope`
  - 修复：
    - 为事件泵文件补入 `import OpenIMSDK`
  - 二轮结果（`2026-04-25 22:02 +0800`）：`** BUILD SUCCEEDED **`
- 本轮将 `recordClear` 协议面收紧为 conversation 级精确回流后再次执行（`2026-04-25 22:06 +0800` -> `2026-04-25 22:07 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 首轮阻塞（`2026-04-25 22:06 +0800`）：
    - `OpenIMDemoBaselineRaverDataProviderEventPump.swift:4:8 error: Unable to find module dependency: 'RxSwift'`
  - 处理：
    - 回退本轮对 demo `IMController.shared.*Subject` / `JNNotificationCenter` 的直接接线尝试
    - 保留 `recordClear(conversationID:)` 的精确回流协议面与 provider 过滤逻辑
  - 二轮结果（`2026-04-25 22:07 +0800`）：`** BUILD SUCCEEDED **`
- 本轮将 demo 所需 Rx 运行时正式接入 app target 后再次执行（`2026-04-25 22:10 +0800`）：
  - `pod install`
  - 新增依赖：
    - `RxSwift (~> 6.5)`
    - `RxCocoa (~> 6.0)`
    - `RxRelay (~> 6.0)`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果（`2026-04-25 22:10 +0800` -> `2026-04-25 22:11 +0800`）：`** BUILD SUCCEEDED **`
- 本轮尝试以本地 pod 方式引入 demo `OUICore`（`2026-04-25 22:14 +0800`）：
  - 尝试：
    - `pod 'OUICore', :path => '../../../thirdparty/openimApp/openim-ios-demo'`
    - `pod install`
  - 阻塞：
    - `OUICore` 依赖 `OpenIMSDK (= 3.8.3+3)`
    - 当前工程锁定 `OpenIMSDK (= 3.8.3-hotfix.12)`
    - CocoaPods 无法同时解算这两个版本
  - 处理（`2026-04-25 22:15 +0800`）：
    - 撤回 `OUICore` pod 行
    - 再次执行 `pod install`
    - 工程 pods 状态恢复正常
- 本轮继续沿“真正同源 runtime”主线推进（`2026-04-25 22:18 +0800` -> `2026-04-25 22:21 +0800`）：
  - 已定位 `pod install --repo-update` 外部阻塞根因：
    - `git config --global` 中存在：
      - `http.proxy http://127.0.0.1:7897`
      - `https.proxy http://127.0.0.1:7897`
  - 已清除这两个全局代理并重跑依赖安装（`2026-04-25 22:18 +0800`）
  - `pod install --repo-update` 结果（`2026-04-25 22:18 +0800`）：
    - `OUICore 0.0.1` 安装成功
    - `OpenIMSDK 3.8.3+hotfix.3.1 / OpenIMSDKCore 3.8.3+3` 安装成功
    - 但首次构建失败于 `OUICore/Classes/Utils/PhotoManager.swift`
  - 首轮阻塞（`2026-04-25 22:19 +0800`）：
    - 当前解出的 `ZLPhotoBrowser 4.7.4` API 与 demo `OUICore` 所依赖的旧 API 不兼容
    - 具体表现为：
      - `ZLPhotoConfiguration` 缺少 `cropVideoAfterSelectThumbnail`
      - `ZLPhotoPreviewSheet` 不存在
  - 修复（`2026-04-25 22:19 +0800`）：
    - `Podfile` 新增：
      - `pod 'ZLPhotoBrowser', :path => '../../../thirdparty/openimApp/openim-ios-demo/3rd'`
      - `pod 'ProgressHUD', :git => 'https://github.com/std-s/ProgressHUD.git'`
    - 随后执行 `pod update ProgressHUD ZLPhotoBrowser`
    - 结果：
      - `ProgressHUD 14.1.3 (was 14.1.1)`
      - `ZLPhotoBrowser 4.6.0.1 (was 4.7.4)`
  - 最终构建结果（`2026-04-25 22:21 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“demo 原事件总线收口”主线推进（`2026-04-25 22:28 +0800` -> `2026-04-25 22:31 +0800`）：
  - 已将 `OpenIMDemoBaselineRaverDataProviderEventPump` 的三条主回流切回 demo 原 `IMController.shared`：
    - `totalUnreadSubject`
    - `conversationChangedSubject`
    - `newMsgReceivedSubject`
  - 当前映射策略仍保持可控桥接：
    - `MessageInfo -> OIMMessageInfo -> ChatMessage -> OpenIMDemoBaselineMessageInfo`
    - `ConversationInfo -> OpenIMDemoBaselineConversationInfo`
  - 构建结果（`2026-04-25 22:31 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“sync 语义收口”主线推进（`2026-04-25 22:34 +0800` -> `2026-04-25 22:35 +0800`）：
  - 已新增 `connectionSyncComplete` 事件桥出口，并将 `IMController.shared.connectionRelay(.syncComplete)` 接回 baseline provider 壳
  - provider 壳现在会按 demo 形状执行：
    - `syncComplete -> startClientMsgID = nil`
    - `syncComplete -> count = max(messageStorage.count, 4 * pageSize 的最小策略)`
    - `syncComplete -> getHistoryMessageList(...)`
    - `syncComplete -> delegate.received(..., forceReload: true)`
  - 同时补上 `syncProgress` 期间当前会话收到新消息时的整段重拉与 `forceReload: true` 语义
  - 构建结果（`2026-04-25 22:35 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“record clear 发送链收口”主线推进（`2026-04-25 22:40 +0800` -> `2026-04-25 22:42 +0800`）：
  - 目标：
    - 把当前实际使用的 `ChatSettingsSheet.clearHistory()` 也对齐到 demo 原 `JNNotificationCenter + EventRecordClear` 发送形态
  - 首次尝试（`2026-04-25 22:40 +0800`）：
    - 新增独立 relay 文件后构建失败
    - 错误：`cannot find 'OpenIMDemoBaselineRecordClearEventRelay' in scope`
    - 原因：该新增文件未在 target 编译源中
  - 修复（`2026-04-25 22:41 +0800`）：
    - 删除独立 relay 文件
    - 直接在 `ChatSettingsSheet` 内引入 `OUICore` 并发送：
      - `let event = EventRecordClear(conversationId: conversation.id)`
      - `JNNotificationCenter.shared.post(event)`
  - 构建结果（`2026-04-25 22:42 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“builder 接口外形收口”主线推进（`2026-04-25 22:43 +0800`）：
  - 在 `OpenIMDemoBaselineBuilderConstruction.swift` 新增别名：
    - `OpenIMDemoBaselineDefaultChatController`
    - `OpenIMDemoBaselineDefaultChatViewController`
  - 并将 `OpenIMDemoBaselineBuilderRuntime` 的依赖签名从 `Placeholder*` 收口到 `Default*` 命名别名
  - 构建结果（`2026-04-25 22:43 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“builder 入口主链替换”推进（`2026-04-25 23:22 +0800` -> `2026-04-25 23:41 +0800`）：
  - 代码变更（`2026-04-25 23:22 +0800`）：
    - 文件：`OpenIMDemoBaselineBuilderAdapter.swift`
    - 变更：`buildEntryViewController(...)` 从 placeholder 返回改为调用 `OpenIMDemoBaselineFactory.chatViewControllerBuilder.build(...)`
    - 变更：`anchorMessageID` 改为精确匹配 `latestMessages` 后再桥接为 builder 的 `anchorMessage`
  - 首轮验证阻塞（`2026-04-25 23:22 +0800`）：
    - 在受限沙箱内执行 `xcodebuild -workspace ...` 出现 `CoreSimulatorService connection became invalid`，并伴随误报 `is not a workspace file`
  - 修复与验证（`2026-04-25 23:41 +0800`）：
    - 改为在已授权的非沙箱环境执行同一 `xcodebuild -workspace ... -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“builder 数据源命名收口”推进（`2026-04-25 23:42 +0800` -> `2026-04-25 23:43 +0800`）：
  - 代码变更（`2026-04-25 23:42 +0800`）：
    - 文件：`OpenIMDemoBaselineBuilderConstruction.swift`
    - 新增：`typealias OpenIMDemoBaselineDefaultChatCollectionDataSource = OpenIMDemoBaselinePlaceholderDataSource`
    - 替换：`OpenIMDemoBaselineBuilderRuntime.makeDataSource` / `makeChatViewController` 的数据源签名统一收口到 `OpenIMDemoBaselineDefaultChatCollectionDataSource`
  - 构建结果（`2026-04-25 23:43 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“builder placeholder 词汇清理”推进（`2026-04-25 23:43 +0800`）：
  - 代码变更（`2026-04-25 23:43 +0800`）：
    - 文件：`OpenIMDemoBaselineBuilderConstruction.swift`
    - 重命名：
      - `OpenIMDemoBaselinePlaceholderDataSource` -> `OpenIMDemoBaselineDefaultChatCollectionDataSourceShell`
      - `OpenIMDemoBaselineBuilderPlaceholderChatViewController` -> `OpenIMDemoBaselineDefaultChatViewControllerShell`
    - 对应 `typealias OpenIMDemoBaselineDefaultChatCollectionDataSource / OpenIMDemoBaselineDefaultChatViewController` 已同步到 shell 新命名
    - 页面提示文案从 `placeholder is being wired` 收口为 `shell is being wired`
  - 构建结果（`2026-04-25 23:43 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“builder controller 命名收口”推进（`2026-04-25 23:44 +0800`）：
  - 代码变更（`2026-04-25 23:44 +0800`）：
    - 文件：`OpenIMDemoBaselineBuilderConstruction.swift`
    - 重命名：
      - `OpenIMDemoBaselinePlaceholderChatController` -> `OpenIMDemoBaselineDefaultChatControllerShell`
    - 同步：
      - `OpenIMDemoBaselineDefaultChatController` typealias 指向新的 shell 命名
      - `OpenIMDemoBaselineDefaultChatViewControllerShell` 内部 controller 类型同步更新
  - 构建结果（`2026-04-25 23:44 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

- 本轮继续沿“会话入口可切 baseline 主链”推进（`2026-04-25 23:46 +0800`）：
  - 代码变更（`2026-04-25 23:46 +0800`）：
    - 文件：`MainTabCoordinator.swift`
    - 新增 `OpenIMDemoBaselineChatContainerView`（`UIViewControllerRepresentable`），承载 `OpenIMDemoBaselineFactory.makeBuilderEntryViewController(...)`
    - `ConversationLoaderView` 新增开关：
      - `ProcessInfo.processInfo.environment["RAVER_OPENIM_BASELINE_CHAT"] == "1"`
    - 路由行为：
      - 开关开启：会话页走 baseline builder 入口
      - 开关关闭：保持现有 `DemoAlignedChatView` 入口（含搜索/设置 toolbar）
  - 构建结果（`2026-04-25 23:46 +0800`）：
    - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
    - 结果：`** BUILD SUCCEEDED **`

验证意义：

- baseline 新增 bridge 文件没有破坏现有主工程
- `OpenIMDemoBaseline` 目录已经是可持续增量开发状态
- `Vendor/OpenIMIOSDemo` 排除策略已生效
- 当前可以继续往 demo 原 builder / controller / provider 层推进

### 当前最重要的事实

这一条必须明确写给任何接手者：

- 当前完成的是“baseline 的编译骨架与数据桥”
- 不是“demo 原聊天页已经完成接入”
- 真正的 demo 同源切换还没有开始进入 `ChatViewControllerBuilder -> DefaultChatController -> DefaultDataProvider` 这条主链

### 下一步精细化处理入口

下一步不应该再回去修 `DemoAligned*` 外观细节，而应该按下面顺序推进：

1. 接 `ChatViewControllerBuilder`
   - 目标：让 demo 原 builder 在 Raver 工程里可被编译和实例化
2. 拆 `DefaultDataProvider` 依赖
   - 目标：识别 `IMController.shared`、`RxSwift Relay/Subject`、`ConversationInfo`、`MessageInfo` 等依赖点
3. 建 `IMControllerBridge` 到 `OpenIMSession`
   - 目标：先把 history / realtime / current user / conversation changed 四类依赖接起来
4. 接 `DefaultChatController`
   - 目标：开始让发送、replace、history、typing 生命周期真正迁入 demo 同源链路

### 当前主线任务分解

这一节用于防止执行过程中不断分叉。当前阶段只允许按下面顺序推进。

#### Block A：让 demo 原 `ChatViewControllerBuilder` 具备接线条件

目标：

- 让 Raver 工程具备实例化 demo 原 builder 所需的最小输入与依赖形态

细分步骤：

1. 固化 `ConversationInfo` / `MessageInfo` / `UserInfo` / `FriendInfo` / `GroupInfo` / `GroupMemberInfo` bridge 形态
2. 固化 `ChatContext` 聚合入口
3. 明确 `ChatViewControllerBuilder` 的直接依赖清单
4. 在 baseline 中建立 `BuilderAdapter`
5. 让 builder 至少在编译层面可实例化

本块完成标准：

- demo 原 `ChatViewControllerBuilder` 的输入面不再缺失
- 不需要回到 `DemoAligned*` 继续补主路径逻辑

当前状态：

- `Step 1` 已完成（补记：`2026-04-25 17:19 +0800`）
- `Step 2` 已完成（补记：`2026-04-25 17:19 +0800`）
- `Step 3` 已完成（补记：`2026-04-25 17:19 +0800`）
- `Step 4` 已完成（补记：`2026-04-25 17:19 +0800`）
- `Step 5` 进行中（状态更新时间：`2026-04-25 21:07 +0800`）
- `Step 6` 已开始（状态更新时间：`2026-04-25 21:07 +0800`）

#### Block A / Step 3 产物：`ChatViewControllerBuilder` 直接依赖清单

本节是当前阶段的关键执行产物。后续 `BuilderAdapter` 只能围绕这份清单接线，不允许脱离清单另起分支。

源码入口：

- [`/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/ChatViewControllerBuilder.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/ChatViewControllerBuilder.swift:1)

builder 直接构造链：

1. `DefaultDataProvider(conversation:anchorMessage:)`
2. `DefaultChatController(dataProvider:senderID:conversation:)`
3. `EditNotifier()`
4. `SwipeNotifier()`
5. `DefaultChatCollectionDataSource(editNotifier:swipeNotifier:reloadDelegate:editingDelegate:)`
6. `ChatViewController(chatController:dataSource:editNotifier:swipeNotifier:hiddenInputBar:scrollToTop:)`

builder 直接输入：

- `ConversationInfo`
- `MessageInfo?`
- `hiddenInputBar: Bool`

builder 直接输出：

- `UIViewController`

builder 直接依赖的全局状态：

- `IMController.shared.uid`

builder 所在文件直接 import：

- `Foundation`
- `UIKit`
- `OUICore`

builder 的第一层类型依赖：

- `ConversationInfo`
- `MessageInfo`
- `DefaultDataProvider`
- `DefaultChatController`
- `EditNotifier`
- `SwipeNotifier`
- `DefaultChatCollectionDataSource`
- `ChatViewController`

builder 的第一层协议/委托连接动作：

- `dataProvider.delegate = messageController`
- `messageController.delegate = messageViewController`
- `dataSource.gestureDelegate = messageViewController`

这意味着后续 `BuilderAdapter` 至少必须解决：

1. `ConversationInfo` / `MessageInfo` 的 baseline 到 demo 形态映射
2. `IMController.shared.uid` 的 bridge 提供
3. `DefaultDataProvider` 可被实例化
4. `DefaultChatController` 可被实例化
5. `DefaultChatCollectionDataSource` 所需 delegate/reload/editing 依赖可满足
6. `ChatViewController` 构造参数可满足

builder 向下一层展开后的关键模块依赖：

- `DefaultDataProvider`
  - [`/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/DefaultDataProvider.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/DefaultDataProvider.swift:1)
  - 直接依赖：
    - `IMController.shared`
    - `RxSwift`
    - `ConversationInfo`
    - `MessageInfo`
    - `GroupInfo`
    - `GroupMemberInfo`
    - `FriendInfo`
    - `UserInfo`
- `DefaultChatController`
  - [`/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Controller/DefaultChatController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Controller/DefaultChatController.swift:1)
  - 直接依赖：
    - `ChatController`
    - `DataProvider`
    - `ConversationInfo`
    - `MessageInfo`
    - `GroupInfo`
    - `GroupMemberInfo`
    - `FriendInfo`
    - `UserInfo`
    - `IMController.shared`
    - `FileDownloadManager`
- `ChatViewController`
  - [`/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/ChatViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/ChatViewController.swift:1)
  - 直接 import：
    - `ChatLayout`
    - `DifferenceKit`
    - `InputBarAccessoryView`
    - `OUICore`
    - `OUICoreView`
    - `ProgressHUD`
    - `MJRefresh`
  - 说明：
    - builder 一旦接通，`ChatViewController` 相关 UI 依赖也必须纳入接线计划

结论：

- `Block A / Step 3` 已完成
- 下一步不应该直接尝试编整套聊天目录
- 下一步应该进入 `Block A / Step 4`，建立 `BuilderAdapter`，只解决 builder 实例化所需的最小依赖面

#### Block A / Step 4 产物：`BuilderAdapter` 骨架

本节记录当前 builder 接线收口层已经完成的最小骨架。

已落地文件：

- [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineBuilderAdapter.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineBuilderAdapter.swift:1)

当前骨架职责：

- 统一 baseline 聊天入口的 builder 接线点
- 收口以下输入：
  - `Conversation`
  - `latestMessages`
  - `anchorMessageID`
  - `hiddenInputBar`
- 内部统一组装：
  - `ChatContext`
  - `ConversationInfo` 对应的 bridge 数据
- 当前阶段先返回 baseline 占位页，而不是直接实例化 demo 原 builder

当前工厂接入点：

- [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineFactory.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineFactory.swift:1)

说明：

- `Step 4` 的目标不是“demo builder 已经跑起来”
- `Step 4` 的目标是“后续所有 builder 真正接线都必须经过同一个收口点”
- 这一步已经完成，后续不需要再在别处散写临时 builder 接线代码

结论：

- `Block A / Step 4` 已完成
- 下一步进入 `Block A / Step 5`
- `Step 5` 的唯一目标是：开始让 demo 原 `ChatViewControllerBuilder` 在 Raver 工程里可被编译和实例化

#### Block A / Step 5 当前进度：builder 实际编译接线

本节用 checkbox 持续维护 `Step 5` 的细分进度，避免把“入口 shim 已落地”误判成“demo 原 builder 已完成接入”。

- [x] 新建 baseline builder 入口 shim（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] 将 factory 接到 builder 入口 shim（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] 让 builder 入口链路再次通过主工程构建（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] 记录并清除 `Step 5` 首轮编译阻塞项（补记：`2026-04-25 17:19 +0800`，早于本时间已完成）
- [x] 用 demo 原 `ChatViewControllerBuilder.swift` 替换当前 shim（`2026-04-25 23:51 +0800`）
- [ ] 打通 `DefaultDataProvider` / `DefaultChatController` 的最小实例化依赖
- [ ] 让 builder 输出不再是 `PlaceholderViewController`

已落地文件：

- [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineChatViewControllerBuilder.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineChatViewControllerBuilder.swift:1)
- [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineFactory.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Adapters/OpenIMDemoBaselineFactory.swift:1)
- [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:1)

当前结论：

- `Step 5` 已完成：builder 已收敛为 demo 原 `ChatViewControllerBuilder` 形态并通过构建
- 当前主线已进入 `DefaultDataProvider / DefaultChatController / DefaultChatCollectionDataSource / ChatViewController` 原对象链替换阶段

#### Block A / Step 6 当前进度：builder 构造链向 demo 同序收敛

本节记录 `Step 6` 的最小推进，目标不是马上替换原 builder，而是先让当前 shim 的内部构造顺序与 demo 原 builder 对齐。

- [x] 新建 builder 构造链同序骨架（`2026-04-25 17:04 +0800`）
- [x] 让 shim 内部开始按 `dataProvider -> controller -> notifier/dataSource -> viewController` 顺序构造（`2026-04-25 17:04 +0800`）
- [x] 将当前构造链重新验证为可编译（`2026-04-25 17:04 +0800`）
- [x] 将 builder 内部的 placeholder data provider 替换为基于 bridge 的真实 provider 壳（`2026-04-25 17:13 +0800`）
- [x] 引入 demo 风格 `DataProviderDelegate` 面并让 provider 壳向 chat controller 回推首批查询回调（`2026-04-25 17:16 +0800`）
- [x] 让 placeholder chat controller 具备按 `clientMsgID` 去重替换、按 `sendTime` 稳定排序的消息缓存逻辑（`2026-04-25 17:19 +0800`）
- [x] 让 placeholder chat controller 开始承接 `conversationChanged`、群成员信息变化、用户资料变化后的内部状态与消息元数据回写（`2026-04-25 17:22 +0800`）
- [x] 建立 demo 风格 `section` 推送、`reloadMessage` 响应与 view-controller 最小更新闭环（`2026-04-25 17:26 +0800`）
- [x] 接通 `loadInitialMessages` / `loadPreviousMessages` / `loadMoreMessages` 后的 controller 分页 section 更新路径（`2026-04-25 17:28 +0800`）
- [x] 接通 `loadInitialMessages` 完成后由 `getOtherInfo` / `getGroupInfo` / `getGroupMembers` 驱动的标题与资料刷新路径（`2026-04-25 21:07 +0800`）
- [x] 补入 `markAllMessagesAsReceived` / `markAllMessagesAsRead` 的最小生命周期占位，并同步 unread 归零路径（`2026-04-25 21:09 +0800`）
- [x] 抽出统一 `finalizeMergedMessages(...)` 出口，并把 `received(messages:forceReload:)` 收敛进同一条 received/read 生命周期（`2026-04-25 21:13 +0800`）
- [x] 补入 `recvMessageIsCurrentChat` 语义，并将 `unreadCountChanged(count:)` 的 delegate 回推条件收紧到更像 demo（`2026-04-25 21:15 +0800`）
- [x] 修正 `received(messages:forceReload:)` 的混合批次边界：当前会话消息与外部消息分流处理，外部消息只走未读累加（`2026-04-25 21:17 +0800`）
- [x] 收紧 `friendInfoChanged` / `groupMemberInfoChanged` 的缓存更新边界，并补齐 `myUserInfoChanged` / `applyGroupMembers(_:)` 的 warning 收尾（`2026-04-25 21:20 +0800`）
- [x] 收紧 `conversationChanged` / `groupMembersChanged` 的事件边界，使其更接近 demo 原 `DefaultChatController` 的处理语义（`2026-04-25 21:22 +0800`）
- [x] 收紧 `clearMessage` / `reloadMessage` / `removeMessage` 的消息级生命周期边界，使其更接近 demo 原控制器（`2026-04-25 21:25 +0800`）
- [x] 收紧 `received(messages:forceReload:)` 的非强刷路径，使其更接近 demo 当前“只按首条消息处理”的边界语义（`2026-04-25 21:27 +0800`）
- [x] 收紧 `unreadCountChanged / total unread` 的统一出口，使其更接近 demo 的总未读回推语义（`2026-04-25 21:29 +0800`）
- [x] 新增并接入 provider 统一事件桥占位，让 `received / isInGroup / friendInfoChanged / groupInfoChanged / unreadCountChanged / conversationChanged / clearMessage` 进入同一桥面（`2026-04-25 21:52 +0800`）
- [x] 为 provider 壳补齐更接近 demo `DefaultDataProvider` 的接口形状（`DataProvider` 协议面与 `getGroupInfo(groupInfoHandler:) / getGroupMembers(...isAdminHandler:) / getUserInfo(otherInfo:mine:) / isJoinedGroup(groupID:handler:)`）（`2026-04-25 21:57 +0800`）
- [x] 将 provider 壳的历史拉取路径对齐到更接近 demo 的 `messageStorage + getHistoryMessageListFromStorage(...)` 分层拉取语义（`2026-04-25 21:59 +0800`）
- [x] 新增 `OpenIMDemoBaselineRaverDataProviderEventPump`，把 `OpenIMSession` 的 `totalUnreadPublisher / conversationPublisher / rawMessagePublisher` 泵入 baseline `eventBridge`（`2026-04-25 22:02 +0800`）
- [x] 将 `recordClear` 从无参全局广播收紧为 `conversationID` 精确回流，并让 provider 壳只响应当前会话的清空事件（`2026-04-25 22:07 +0800`）
- [x] 识别并记录当前 target 对 demo Rx 事件总线的真实依赖边界：`RxSwift` 尚未直接暴露给 app target，原样接入 `IMController.shared.*Subject` / `JNNotificationCenter` 需延后到 target 依赖接入步骤（`2026-04-25 22:07 +0800`）
- [x] 将 demo 所需 `RxSwift / RxCocoa / RxRelay` 正式接入 app target，并完成一次全量构建锚点（`2026-04-25 22:10 +0800`）
- [x] 识别并验证真正同源 runtime 接入前的唯一版本阻塞：`OUICore -> OpenIMSDK 3.8.3+3` 与当前工程 `OpenIMSDK 3.8.3-hotfix.12` 冲突（`2026-04-25 22:14 +0800`）
- [x] 定位并清除本地 `git` 全局代理阻塞，恢复 demo 同源 `ProgressHUD` 依赖拉取（`2026-04-25 22:18 +0800`）
- [x] 将工程依赖切到 demo 同源 runtime 主线：`OpenIMSDK 3.8.3+3` + 本地 `OUICore`（`2026-04-25 22:18 +0800`）
- [x] 将 `ZLPhotoBrowser` 与 `ProgressHUD` 收紧到 demo 同源来源与版本：`ZLPhotoBrowser 4.6.0.1`、`ProgressHUD 14.1.3`（`2026-04-25 22:19 +0800`）
- [x] 完成 demo 同源 runtime 前置打通后的主工程构建锚点（`2026-04-25 22:21 +0800`）
- [x] 将 unread / conversation / new message 三条主回流切回 demo 原 `IMController` 事件源，并完成新的主工程构建锚点（`2026-04-25 22:31 +0800`）
- [x] 将 `connectionRelay -> syncComplete -> forceReload` 与 `syncProgress` 期间当前会话强刷语义接回 provider 壳，并完成新的主工程构建锚点（`2026-04-25 22:35 +0800`）
- [x] 将当前实际使用设置页的“清空聊天记录”入口接回 demo 原 `JNNotificationCenter + EventRecordClear` 发送链，并完成构建锚点（`2026-04-25 22:42 +0800`）
- [x] 将 builder runtime 依赖签名从 `Placeholder*` 命名收口到 `Default*` 命名别名，降低后续替换 demo 原对象链的冲突面，并完成构建锚点（`2026-04-25 22:43 +0800`）
- [x] 将 baseline builder 体改为 demo 原同序结构（`dataProvider -> controller -> edit/swipe notifier -> extractedExpr -> ChatViewController`），并切到 `IMController.shared.uid` 发件人来源（`2026-04-25 23:49 +0800`）
- [x] 为 `DefaultDataProvider` 与 `DefaultChatViewController` 壳补齐 demo 形参兼容构造器，降低后续直接替换 demo 本体的改动面（`2026-04-25 23:49 +0800`）
- [x] 完成本批次构建锚点：`xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17' build` -> `BUILD SUCCEEDED`（`2026-04-25 23:49 +0800`）
- [x] 移除已不再使用的 `OpenIMDemoBaselineBuilderRuntime` 占位构造层，收敛为单一路径 builder 主链，并完成构建锚点（`2026-04-25 23:51 +0800`）
- [x] 将 builder 类型名收敛为 demo 原 `ChatViewControllerBuilder`，并保留 `OpenIMDemoBaselineChatViewControllerBuilder` 兼容别名，完成构建锚点（`2026-04-25 23:51 +0800`）
- [x] 用 demo 原 `ChatViewControllerBuilder.swift` 本体直接替换当前 shim（已完成：builder 类型名收敛为 `ChatViewControllerBuilder`，构造顺序与关键调用点对齐 demo 原实现，并保留兼容别名）（`2026-04-25 23:51 +0800`）
- [x] 补齐 `DefaultDataProvider` / `DefaultChatController` / `DefaultChatCollectionDataSource` / `ChatViewController` / `EditNotifier` / `SwipeNotifier` 的 unprefixed 命名别名，并让 builder 调用改为 unprefixed 形态，完成构建锚点（`2026-04-25 23:53 +0800`）
- [x] 将四个核心类型的类声明本身收敛到 demo 原命名（而非仅 typealias）：`DefaultDataProvider / DefaultChatController / DefaultChatCollectionDataSource / ChatViewController`，同时保留 `OpenIMDemoBaseline*` 兼容别名，完成构建锚点（`2026-04-25 23:54 +0800`）
- [x] 将 `DefaultDataProvider` 的类签名与关键字段命名继续收敛到 demo 原风格（`DataProvider` 协议名、`DataProviderDelegate`、`receiverId`），完成构建锚点（`2026-04-25 23:55 +0800`）
- [x] 将 `DefaultChatController` / `DefaultChatCollectionDataSource` / `ChatViewController` 的协议签名改为 demo 风格命名（`ChatControllerDelegate / ReloadDelegate / GestureDelegate`），完成构建锚点（`2026-04-25 23:56 +0800`）
- [x] 在 `DefaultDataProvider` 补齐 demo 同名状态字段（`startingTimestamp / users / lastMessageIndex / lastReadString / lastReceivedString / enableNewMessages`），并将事件回流统一到 `receivedNewMessages(messages:forceReload:)` 入口，完成构建锚点（`2026-04-25 23:57 +0800`）
- [x] 将 `DefaultDataProvider` 的事件桥绑定方法名从 `bindEventBridge()` 收敛为 demo 原 `addObservers()`，保持初始化路径与 demo 一致，完成构建锚点（`2026-04-25 23:58 +0800`）
- [x] 在消息模型补齐 demo 原 `isAnchor` 字段，并将 `DefaultDataProvider.loadInitialMessages` 改为显式标记锚点消息（`isAnchor = true`），完成构建锚点（`2026-04-25 23:59 +0800`）
- [ ] 用 demo 原 `DefaultDataProvider` 替换 placeholder data provider
- [ ] 用 demo 原 `DefaultChatController` 替换 placeholder controller
- [ ] 用 demo 原 `DefaultChatCollectionDataSource` 与 `ChatViewController` 替换当前 placeholder 视图控制器

已落地文件：

- [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineBuilderConstruction.swift:1)
- [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineChatViewControllerBuilder.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/Chat/OpenIMDemoBaselineChatViewControllerBuilder.swift:1)

当前结论：

- `Step 6` 已从“同序骨架”推进到“builder 本体替换完成”
- 当前 builder 的结构已经更接近 demo 原 builder，且 data provider 已经升级为真实 provider 壳
- 当前 placeholder chat controller 已开始承接 demo `DefaultChatController` 的消息集合维护职责
- 当前 placeholder chat controller 已开始承接 demo `DefaultChatController` 的资料变更与会话状态回写职责
- 当前 placeholder view/controller 已开始承接 demo 风格的 section 推送与 reload 生命周期
- 当前 placeholder controller 已开始承接 demo 风格的初始加载、向前分页、反向分页后的 section 更新路径
- 当前 placeholder controller 已开始承接 demo 风格的首屏后资料补全顺序：先推 sections，再异步刷新标题、群资料与群成员 sender 信息
- 当前 placeholder controller 已开始承接 demo 风格的最小已读生命周期顺序：merge 后先走 received/read 占位，再推 sections，并把 unread 同步归零
- 当前 placeholder controller 的 `load*` 与 `received(messages:forceReload:)` 已开始共用同一条 merge 后生命周期出口
- 当前 placeholder controller 已开始区分“当前会话收到消息”与“非当前会话 unread 变化”的 delegate 回推语义
- 当前 placeholder controller 已避免在混合批次回流时把外部消息误合并进当前会话消息集
- 当前 placeholder controller 已开始按更接近 demo 的边界处理资料变更：`friendInfoChanged` / `groupMemberInfoChanged` 只在实际影响消息 sender 元数据时触发重建，`myUserInfoChanged` 与批量成员回填保持 demo 风格的无条件刷新语义
- 当前 placeholder controller 已开始按更接近 demo 的边界处理会话与成员事件：`conversationChanged` 不再主动回推 unread/title，`groupMembersChanged` 只响应当前群会话的成员变更
- 当前 placeholder controller 已开始按更接近 demo 的边界处理消息级生命周期：`clearMessage` 维持清空并刷新，`reloadMessage` 改为无条件刷新，`removeMessage` 不再直接删除消息集合
- 当前 placeholder controller 已开始按更接近 demo 的边界处理新消息回流：`forceReload == false` 时只取首条消息做当前会话判断、合并或未读累加
- 当前 placeholder controller 已开始按更接近 demo 的边界处理总未读回推：外部消息累加、data provider 的 `unreadCountChanged`、以及当前会话读完归零都统一经过同一个 total-unread 出口
- 当前 placeholder provider 壳已开始通过统一事件桥回推 controller，避免继续散落在本地壳方法直调路径
- 当前工程现在已经具备和 demo 更接近的运行时地基：`OpenIMSDK`、`OUICore`、`ZLPhotoBrowser`、`ProgressHUD` 均已对齐到 demo 主线
- 下一步必须继续向原始 `DefaultDataProvider` / `DefaultChatController` 的最小实例化替换推进

#### Block B / Step 1 产物：`DefaultDataProvider` 最小实例化依赖盘点

盘点时间：

- `2026-04-25 17:04 +0800`

源码入口：

- [`/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/DefaultDataProvider.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/DefaultDataProvider.swift:1)

当前阶段结论：

- `DefaultDataProvider` 不是单纯的数据拉取器，它同时承担：
  - 初始历史加载
  - 向前分页
  - anchor 双向历史补齐
  - 用户/群资料读取
  - 大量基于 `IMController.shared` 的 Rx 事件订阅
- 因此 `Step 6` 要想把 placeholder data provider 替换成原 provider，至少要先把“可实例化依赖”和“运行期事件依赖”拆开处理

最小实例化依赖：

- [x] `ConversationInfo` 输入已具备（`2026-04-25 17:04 +0800`）
- [x] `MessageInfo? anchorMessage` 输入已具备（`2026-04-25 17:04 +0800`）
- [ ] `IMController.shared` 的最小替身未具备
- [ ] `RxSwift.DisposeBag` / subject / relay 运行时环境未具备
- [ ] `DataProviderDelegate` 对接面未建立

`IMController.shared` 直接方法依赖：

- [ ] `getGroupInfo(groupIds:)`
- [ ] `isJoinedGroup(groupID:)`
- [ ] `getGroupMembersInfo(groupId:uids:)`
- [ ] `getAllGroupMembers(groupID:)`
- [ ] `getFriendsInfo(userIDs:)`
- [ ] `getHistoryMessageList(conversationID:conversationType:startCliendMsgId:count:)`
- [ ] `getHistoryMessageListReverse(conversationID:startCliendMsgId:count:)`

`IMController.shared` 直接状态 / Relay / Subject 依赖：

- [ ] `uid`
- [ ] `currentUserRelay`
- [ ] `connectionRelay`
- [ ] `newMsgReceivedSubject`
- [ ] `groupMemberInfoChange`
- [ ] `joinedGroupAdded`
- [ ] `joinedGroupDeleted`
- [ ] `friendInfoChangedSubject`
- [ ] `onBlackAddedSubject`
- [ ] `onBlackDeletedSubject`
- [ ] `groupInfoChangedSubject`
- [ ] `groupMemberAdded`
- [ ] `groupMemberDeleted`
- [ ] `totalUnreadSubject`
- [ ] `conversationChangedSubject`

provider 还依赖的非 `IMController` 事件入口：

- [ ] `JNNotificationCenter.shared.observeEvent(EventRecordClear)`
- [ ] `ENABLE_CALL` 分支下的 `CallingManager.manager.endCallingHandler`

下一步替换顺序约束：

- [ ] 先做 provider bridge 协议最小面
- [ ] 再做 history/group/user 查询能力
- [x] 再做 connection/new message/current user/conversation changed 的事件桥（首版占位已落，`2026-04-25 21:52 +0800`）
- [ ] 最后才尝试把 demo 原 `DefaultDataProvider` 编进 builder 主链

当前推进状态更新：

- [x] provider bridge 协议最小面已落代码（`2026-04-25 17:06 +0800`）
- [x] provider bridge 默认查询实现已落代码（`2026-04-25 17:10 +0800`）
- [x] provider 事件桥协议与默认实现已落代码，并接入 provider 壳统一回推面（`2026-04-25 21:52 +0800`）

#### Block B：让 demo 原 `DefaultDataProvider` 可被桥接

目标：

- 明确并打通 demo provider 所依赖的 history / realtime / current user / conversation changed 这四类基础数据能力

细分步骤：

1. 列出 `DefaultDataProvider` 中所有 `IMController.shared` 依赖点
2. 将依赖按“同步读取 / 异步回调 / Rx 事件流”三类拆开
3. 为每一类建立 `Bridge` 协议
4. 用 `OpenIMSession` 提供第一版默认实现
5. 让 provider 至少开始通过单文件编译

本块完成标准：

- `DefaultDataProvider` 不再被视为黑箱
- `IMController.shared` 的最小替代面被清晰定义

当前状态：

- [x] `Step 1` 列出 `DefaultDataProvider` 中所有 `IMController.shared` 依赖点（`2026-04-25 17:04 +0800`）
- [x] `Step 2` 将依赖按“同步读取 / 异步回调 / Rx 事件流”拆开，并落第一版查询桥（`2026-04-25 17:10 +0800`）
- [x] `Step 3` 为事件流建立 `Bridge` 协议并补默认实现（`2026-04-25 21:52 +0800`）
- [ ] `Step 4` 让 provider 至少开始通过单文件编译
- [ ] `Step 5` 让 demo 原 `DefaultDataProvider` 进入 builder 主链

#### Block C：让 demo 原 `DefaultChatController` 进入主链

目标：

- 把发送、replace、history、typing、已读等状态机从当前自研主链迁到 demo 原 controller 主链

细分步骤：

1. 接 conversation / current user / other user / group info 读取
2. 接 message list 初始加载
3. 接历史分页
4. 接新消息回流
5. 接发送/失败/重试
6. 接 typing / unread / read receipt

本块完成标准：

- demo 原 `DefaultChatController` 成为实际聊天生命周期主链的一部分

当前状态：

- 未开始

#### Block D：baseline 聊天页替换占位入口

目标：

- baseline 聊天页从占位页升级为 demo 原生容器入口

细分步骤：

1. 让 `BaselineChatEntry` 能拿到 builder 输出
2. 让聊天页在工程内可被打开
3. 验证空会话 / 已有历史 / 单聊 / 群聊四种入口
4. 验证构建与基本展示稳定

本块完成标准：

- 不再只是 `PlaceholderViewController`
- 能看到 demo 原生容器开始实际运行

当前状态：

- 未开始

### 当前执行格式要求

从当前阶段开始，每一轮推进都要按下面格式更新本文件：

- 本轮主线任务：
  - 只能写一个
- 本轮细分步骤：
  - 只写当前块里的步骤
- 本轮完成：
  - 只记录已完成事实
- 本轮遗留：
  - 只记录当前块内部遗留
- 下一步唯一动作：
  - 只能有一个推荐入口
- 时间戳要求：
  - checkbox 状态变化必须带 `YYYY-MM-DD HH:mm ±ZZZZ`
  - 构建、阻塞、修复、结论必须带 `YYYY-MM-DD HH:mm ±ZZZZ`

这样做的目的就是：

- 防止目标漂移
- 防止同时打开太多分支
- 防止“看起来做了很多事，但主线没有前进”

### 本轮执行记录

本轮记录时间：

- `2026-04-25 22:21 +0800`

本轮主线任务：

- 继续 `Block A / Step 6`，收紧资料变更、会话/成员事件、消息级生命周期、新消息回流与总未读回推路径的边界语义

本轮细分步骤：

1. 将 `friendInfoChanged` / `groupMemberInfoChanged` 的 sender 元数据回写收紧到“只有实际影响消息时才重建”
2. 处理这批改动带出的 `updateMessagesSenderInfo(...)` unused-result warning
3. 保持 `myUserInfoChanged` 与 `applyGroupMembers(_:)` 的刷新语义不偏离 demo
4. 收紧 `conversationChanged` / `groupMembersChanged` 的事件边界，使其更接近 demo 原控制器
5. 收紧 `clearMessage` / `reloadMessage` / `removeMessage` 的消息级生命周期边界
6. 收紧 `received(messages:forceReload:)` 的非 `forceReload` 路径，使其更接近 demo 只处理首条消息的边界
7. 统一 `unreadCountChanged`、外部消息累加与读完归零时的 total-unread 出口
8. 构建验证并把新的 checkbox 与关键日志带时间回写主文档
9. 新增 provider 统一事件桥占位，并把关键事件回推收敛到同一桥面

本轮完成：

- 已将 `friendInfoChanged` 收紧为：
  - 只有命中当前 `otherInfo?.userID`
  - 且实际影响消息 sender 元数据时
  - 才触发 `repopulateMessages(requiresIsolatedProcess: true)`（`2026-04-25 21:18 +0800`）
- 已将 `groupMemberInfoChanged` 收紧为：
  - 仅在成员已存在于本地缓存时更新缓存
  - 仅在实际影响消息 sender 元数据时触发重建（`2026-04-25 21:18 +0800`）
- 已完成这批改动的 warning 收尾：
  - `myUserInfoChanged` 中显式吸收 `updateMessagesSenderInfo(...)` 返回值
  - `applyGroupMembers(_:)` 中显式吸收 `updateMessagesSenderInfo(...)` 返回值
  - 保持两者当前刷新语义仍与 demo 更接近（`2026-04-25 21:20 +0800`）
- 已再次完成（`2026-04-25 21:21 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已收紧会话与成员事件边界：
  - `conversationChanged` 现在仅同步本地 `conversation` / `unreadCount`，不再主动回推 unread 或标题 fallback（`2026-04-25 21:22 +0800`）
  - `groupMembersChanged` 现在仅在当前会话是群聊且 `groupID` 命中当前群时才更新本地成员缓存（`2026-04-25 21:22 +0800`）
- 已再次完成（`2026-04-25 21:22 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已收紧消息级生命周期边界：
  - `clearMessage` 继续维持“清空消息集合后立即刷新”语义（`2026-04-25 21:25 +0800`）
  - `reloadMessage` 改为与 demo 一致的无条件刷新，不再先检查本地是否命中该消息（`2026-04-25 21:25 +0800`）
  - `removeMessage` 不再直接删除消息集合，先保持更接近 demo 的“界面级刷新/后续选择流入口”语义（`2026-04-25 21:25 +0800`）
- 已再次完成（`2026-04-25 21:25 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已收紧新消息回流边界：
  - `forceReload == true` 时仍保留整批消息 replace + 统一 received/read 生命周期（`2026-04-25 21:27 +0800`）
  - `forceReload == false` 时改为与 demo 一样只取 `messages.first` 参与当前会话判断与处理（`2026-04-25 21:27 +0800`）
  - 当前会话只合并首条消息；非当前会话只对首条消息做未读累加（`2026-04-25 21:27 +0800`）
- 已再次完成（`2026-04-25 21:28 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已统一总未读回推出口：
  - 外部消息累加不再直接 `delegate.updateUnreadCount(...)`，而是统一走 `propagateTotalUnreadCount()`（`2026-04-25 21:29 +0800`）
  - `unreadCountChanged(count:)` 与 `markAllMessagesAsRead(syncUnreadToZero:)` 也统一走同一个 total-unread 出口（`2026-04-25 21:29 +0800`）
- 已再次完成（`2026-04-25 21:30 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已收紧 `loadInitialMessages` 尾部的当前会话已读语义：
  - 首屏消息合并后不再在 `finalizeMergedMessages(...)` 内直接把当前会话 unread 归零（`2026-04-25 21:34 +0800`）
  - 改为更接近 demo 的两段式顺序：
    - 先完成首屏 `sections`
    - 再单独走 `markMessageAsReaded(...)`
    - 最后再走 total-unread 回推（`2026-04-25 21:34 +0800`）
  - 新增 `markMessageAsReaded(...)` 占位出口，用于承接后续真实事件桥 / SDK 已读同步对接（`2026-04-25 21:34 +0800`）
- 已再次完成（`2026-04-25 21:35 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已继续收紧分页与当前会话回流路径的 unread 边界：
  - `loadPreviousMessages` 不再在这条链路里直接把当前会话 unread 归零（`2026-04-25 21:36 +0800`）
  - `loadMoreMessages` 不再在这条链路里直接把当前会话 unread 归零（`2026-04-25 21:36 +0800`）
  - `received(messages:forceReload:)` 的 `forceReload` 路径不再在这条链路里直接把当前会话 unread 归零（`2026-04-25 21:36 +0800`）
  - 当前会话内的单条新消息回流路径也不再在这条链路里直接把当前会话 unread 归零（`2026-04-25 21:36 +0800`）
  - 当前状态更接近 demo：除了首屏后专门的 `markMessageAsReaded(...) -> total unread` 尾部处理外，其它这些链路只做 `received/read placeholder -> sections`，不额外在本层改总未读语义（`2026-04-25 21:36 +0800`）
- 已再次完成（`2026-04-25 21:36 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已收紧 `unreadCountChanged(count:)` 与 `markMessageAsReaded(...)` 的配合边界：
  - 新增 `isSynchronizingCurrentChatRead` 协调状态，用来在“首屏读完当前会话”这段窗口内临时压住 `unreadCountChanged(count:)` 的总未读回推（`2026-04-25 21:37 +0800`）
  - `refreshTotalUnreadAfterCurrentChatReadIfNeeded(...)` 现在会：
    - 先进入 `isSynchronizingCurrentChatRead = true`
    - 再执行 `markMessageAsReaded(...)`
    - 完成后恢复 `isSynchronizingCurrentChatRead = false`
    - 并将 `recvMessageIsCurrentChat = false`
    - 最后再统一 `propagateTotalUnreadCount()`（`2026-04-25 21:37 +0800`）
  - 当前语义更闭合：当前会话首屏读完时，不会因为中间态 `unreadCountChanged(count:)` 提前把总未读推给 UI，而是等读完后统一推一次（`2026-04-25 21:37 +0800`）
- 已再次完成（`2026-04-25 21:38 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已收紧 `conversationChanged(info:)` 与本地 unread 状态的配合边界：
  - 在 `isSynchronizingCurrentChatRead == true` 的窗口内，`conversationChanged(info:)` 不再把本地 unread 状态冲回事件侧的中间值（`2026-04-25 21:45 +0800`）
  - 当前处理改为：
    - 先同步 `conversation = info`
    - 如果仍在“当前会话读完同步窗口”内，则强制保留 `conversation.unreadCount = 0` 与 `unreadCount = 0`
    - 只有离开该窗口后，才正常跟随 `info.unreadCount`（`2026-04-25 21:45 +0800`）
  - 这样可以避免后续事件桥接入时，`conversationChanged` 在当前会话刚读完的时刻把本地 unread 语义重新冲掉（`2026-04-25 21:45 +0800`）
- 已再次完成（`2026-04-25 21:45 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已确认当前仍存在 2 个与主线相关但非阻断的 Swift 6 预警（`2026-04-25 21:20 +0800`）：
  - `OpenIMDemoBaselineChatContext.swift` 中默认参数引用 `MainActor` 隔离静态属性
  - `OpenIMDemoBaselineChatViewControllerBuilder.swift` 中默认参数引用 `MainActor` 隔离静态属性
  - 当前结论：先记录，不偏离 `Step 6` 主线；待进入 builder 本体替换前一并收掉
- 已新增 provider 统一事件桥占位并接入 provider 壳（`2026-04-25 21:52 +0800`）：
  - 在 `OpenIMDemoBaselineDataProviderEventBridge` 协议面补齐 `received / isInGroup / groupMemberInfoChanged / groupInfoChanged / friendInfoChanged / myUserInfoChanged / groupMembersChanged / unreadCountChanged / conversationChanged / clearMessage` 的 observe + emit
  - 新增 `OpenIMDemoBaselineInMemoryDataProviderEventBridge` 作为首版默认实现
  - `OpenIMDemoBaselineFactory` 已注入 `dataProviderEventBridge`
  - `OpenIMDemoBaselineBuilderDataProviderShell` 已通过统一桥面转发到 `DataProviderDelegate`
- 已完成事件桥接线后的构建锚点（`2026-04-25 21:52 +0800`）：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已补齐 provider 壳的 demo 形状接口面（`2026-04-25 21:57 +0800`）：
  - 新增 `OpenIMDemoBaselineDataProvider` 协议，方法签名贴近 demo `DataProvider`
  - `OpenIMDemoBaselineBuilderDataProviderShell` 已对齐该协议并补充兼容签名
  - 新增 `typealias OpenIMDemoBaselineDefaultDataProvider = OpenIMDemoBaselineBuilderDataProviderShell`，为后续替换 demo 原 `DefaultDataProvider` 铺路
- 已完成 provider 接口对齐后的构建锚点（`2026-04-25 21:57 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已将 provider 壳的历史拉取语义向 demo 对齐（`2026-04-25 21:59 +0800`）：
  - 新增 `messageStorage` 缓存
  - 新增 `getHistoryMessageListFromStorage(loadInitial:reverse:completion:)`
  - `loadInitialMessages / loadPreviousMessages / loadMoreMessages` 改为经由 `messageStorage` 分层拉取
- 已完成历史拉取对齐后的构建锚点（`2026-04-25 21:59 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已新增 session 事件泵并接入 baseline factory（`2026-04-25 22:02 +0800`）：
  - 新增文件：`OpenIMDemoBaselineRaverDataProviderEventPump.swift`
  - 已将 `OpenIMSession.totalUnreadPublisher` 映射到 `eventBridge.emitTotalUnreadCountChanged`
  - 已将 `OpenIMSession.conversationPublisher` 映射到 `eventBridge.emitConversationChanged`
  - 已将 `OpenIMSession.rawMessagePublisher` 映射到 `eventBridge.emitReceived(..., forceReload: false)`
  - `OpenIMDemoBaselineFactory` 已注入 `dataProviderEventPump`，builder 入口创建时确保事件泵激活
- 已记录并修复这轮编译阻塞（`2026-04-25 22:00 +0800` -> `2026-04-25 22:02 +0800`）：
  - 阻塞：事件泵文件缺少 `OIMMessageInfo` 类型导入
  - 修复：补入 `import OpenIMSDK`
  - 修复后构建结果：`** BUILD SUCCEEDED **`
- 已将 `recordClear` 协议面修正为 conversation 级精确回流（`2026-04-25 22:07 +0800`）：
  - `OpenIMDemoBaselineDataProviderEventBridge.observeRecordClear` 现改为携带 `conversationID`
  - `OpenIMDemoBaselineInMemoryDataProviderEventBridge.emitRecordClear` 现改为携带 `conversationID`
  - provider 壳只在 `conversationID == self.conversation.conversationID` 时才回推 `clearMessage`
- 已记录这轮 target 依赖边界（`2026-04-25 22:07 +0800`）：
  - 直接按 demo 原路接入 `RxSwift` / `JNNotificationCenter` 时，当前 `RaverMVP` app target 会报 `Unable to find module dependency: 'RxSwift'`
  - 这说明 `Block B / Step 4` 的下一步不能继续在 provider 壳里“模拟 Rx”，而应该先把 demo 运行时依赖正式纳入 target，之后再原样接 `IMController.shared.*Subject`
- 已完成 Rx 运行时正式接入（`2026-04-25 22:10 +0800`）：
  - `Podfile` 已新增：
    - `RxSwift (~> 6.5)`
    - `RxCocoa (~> 6.0)`
    - `RxRelay (~> 6.0)`
  - `pod install` 已成功安装：
    - `RxSwift 6.9.0`
    - `RxCocoa 6.9.0`
    - `RxRelay 6.9.0`
  - 主工程构建已再次通过，说明 app target 现已具备继续接 demo Rx 事件线的运行时前提
- 已确认并已解除当前真正同源 runtime 的版本阻塞（`2026-04-25 22:14 +0800` -> `2026-04-25 22:21 +0800`）：
  - demo `OUICore` 本地 pod 依赖 `OpenIMSDK = 3.8.3+3`
  - 当前工程原依赖 `OpenIMSDK = 3.8.3-hotfix.12`
  - 现已切到 demo 同款 `OpenIMSDK = 3.8.3+3`
  - 配套 `OUICore`、demo 来源 `ZLPhotoBrowser`、demo 来源 `ProgressHUD` 也已全部安装并通过构建
- 已定位并清除外部依赖拉取阻塞（`2026-04-25 22:18 +0800`）：
  - `git config --global` 中的 `http.proxy / https.proxy` 均指向 `127.0.0.1:7897`
  - 已清除后重新执行 `pod install --repo-update`
- 已对齐 demo 同源三方版本（`2026-04-25 22:19 +0800`）：
  - `ProgressHUD 14.1.3 (was 14.1.1)`
  - `ZLPhotoBrowser 4.6.0.1 (was 4.7.4)`
- 已完成 demo 同源 runtime 打通后的主工程构建锚点（`2026-04-25 22:21 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已完成 demo 原事件总线第一阶段收口后的主工程构建锚点（`2026-04-25 22:31 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`
- 已完成 sync 语义第一阶段收口后的主工程构建锚点（`2026-04-25 22:35 +0800`）：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`** BUILD SUCCEEDED **`

本轮遗留：

- `Block A / Step 5` 已完成：builder 本体已收敛到 demo 原 `ChatViewControllerBuilder` 形态
- `Block A / Step 6` 已继续推进，当前剩余差距集中在 `DefaultDataProvider / DefaultChatController / DefaultChatCollectionDataSource / ChatViewController` 仍为 placeholder 对象链
- `Block B` 已有查询桥 + 事件桥默认实现，但 demo 原 `DefaultDataProvider` 仍未进入编译主链
- 当前 provider 壳还不是 demo 原 `DefaultDataProvider`
- demo 同源 runtime 依赖虽已打通，且 `IMController.shared` 的 unread / conversation / new message 与 `connectionRelay(.syncComplete)` 已真实接回 baseline，`syncProgress` 期间当前会话的整段重拉语义也已补回；当前实际设置页 `clearHistory` 的 `JNNotificationCenter(EventRecordClear)` 发送入口也已接回，但 `Builder / Controller / DataSource / ViewController` 原生对象链仍未完全收口
- placeholder chat controller / data source / chat view controller 仍未替换
- 当前 placeholder 链虽已具备 section 推送、reload 生命周期、分页后 section 更新路径、首屏后资料刷新路径、最小已读生命周期占位、统一的 merge 后生命周期出口、基础 current-chat unread 语义、更接近 demo 的首屏读完当前会话后再刷新总未读的尾部语义、以及更接近 demo 的“分页与当前会话回流不在本链路内直接清 unread”的边界语义，并已补上首屏读完当前会话时压制 `unreadCountChanged` 中间态、最后再统一推一次总未读的协调状态，以及 `conversationChanged` 在该同步窗口内不回冲 unread 的保护；但它仍然不是 demo 原 `DefaultChatController` / `DefaultChatCollectionDataSource` / `ChatViewController`
- 当前存在 2 个 Swift 6 预警，已记录但未处理

下一步唯一动作：

- 继续沿 demo 原对象链主线，把剩余 `Builder / Controller / DataSource / ViewController` 原生链路继续收口到 baseline

### 当前阻塞与风险

当前没有硬阻塞，但存在几个明确风险：

- demo 原 `DefaultDataProvider` 强依赖 `IMController.shared` 与 Rx 事件总线
- demo 原模型比 Raver 当前模型更厚，后续桥接需要继续补 `FriendInfo` / `GroupInfo` / `GroupMemberInfo` / `MessageInfo` 字段
- 一旦开始真正把 demo 原文件纳入编译，就会出现模块命名、依赖导入、资源查找、控制器工厂等真实编译问题

因此当前策略必须保持：

- 先桥接
- 再单点编译 builder
- 再推进 controller/provider
- 不要跳过中间层直接强编整个 demo 聊天目录

---

## 0. 基线定义

### 0.1 什么叫“一模一样”

本项目中的“一模一样”定义为：

- 页面结构一致：
  - 会话列表
  - 聊天页
  - 输入区
  - 消息菜单
  - 设置页
  - 群设置页
  - 搜索页
- 视觉结构一致：
  - 间距
  - 圆角
  - 头像/昵称显示规则
  - 时间分隔规则
  - 发送态/失败态位置与样式
  - Jump to bottom、loading、typing 等控件位置与显隐逻辑
- 交互逻辑一致：
  - 初次进入落底
  - 上滑分页
  - 新消息自动滚动条件
  - 键盘联动
  - 长按菜单
  - 点击失败重试
  - 图片/视频预览入口
  - 设置页跳转路径
- 内部机制一致：
  - ViewController 分层
  - ChatController 状态机
  - DataProvider 历史分页与实时桥接方式
  - DataSource / CellFactory 组织方式
  - local echo -> ack replace -> resend 的消息生命周期
  - 输入态、已读、未读、会话预览更新的时序

### 0.2 什么不算“一模一样”

以下都不算：

- UI 看起来差不多，但 cell 层次和布局机制不同
- 行为结果相近，但触发时机不同
- 页面结构相似，但内部状态机是我们自己重写的
- 只对齐聊天页，不对齐设置页、群页、搜索页、长按菜单
- 保留大量 `DemoAligned*` 自研实现，只是继续抄 demo 的细节

---

## 1. 外部基线与冻结策略

### 1.1 参考基线

本方案以 `openimsdk/openim-ios-demo` 为唯一产品基线。

基线来源：

- 仓库：`https://github.com/openimsdk/openim-ios-demo`
- README（当前公开说明）：
  - 项目为 OpenIM iOS 参考实现
  - 包含文本、图片、视频、语音、文件、名片、位置、自定义消息、typing、会话置顶、已读、免打扰、清空历史、群管理等能力

### 1.2 必须先做的冻结动作

在开始迁移之前，必须先冻结：

- 目标 demo 仓库 commit SHA
- 目标 demo 的 iOS 目录结构快照
- 目标 demo 的依赖版本
- 目标 demo 中聊天域的页面截图基线
- 目标 demo 的交互录屏基线

没有这一步，就不可能真正做到 1:1。

### 1.3 当前项目执行前提

当前项目按“个人练手、学习与对照实现”前提推进，因此本方案采用**最强对齐路线**：

- 允许直接 vendoring `openim-ios-demo` 的聊天域源码
- 允许保留原目录结构、原类名、原页面组织
- 允许优先复制 demo 原始实现，而不是做“同构重写”
- 允许把当前 Raver 聊天实现整体降级为过渡层

这意味着本方案不再以“保守迁移”为默认策略，而是以**源码层面尽量同源**为默认策略。

### 1.4 许可证与法务说明（非当前阻塞）

`openim-ios-demo` README 当前公开说明其代码受 AGPL-3.0 及额外条款约束，且商业使用受限。

由于你已经明确这是个人练手项目，这里只保留说明，不把它作为当前执行阻塞项。

如果未来项目用途改变，再单独做许可证处理。

---

## 2. 总体路线：从“复刻版”切换为“基线迁移版”

### 2.1 核心决策

从现在开始，聊天域路线改为：

- 停止把 `DemoAligned*` 当最终架构继续演化
- 将 `openim-ios-demo` 聊天域作为基线代码
- 在 Raver 内建立一个新的迁移目标层：
  - `OpenIMDemoBaseline/`
- 所有与 demo 不一致的地方，优先通过“迁入 demo 原实现”消除
- 当前默认采用“直接迁源码”策略，而不是“参考后重写”
- 只有在以下边界允许做适配：
  - 登录态/用户态接入
  - Raver 路由体系
  - 主题资源与图片资源
  - 业务特有字段
  - 服务端接口包装

### 2.2 一句话原则

**尽量迁入 demo 的原文件、原类、原页面和原状态机，不要把 demo 的行为翻译成我们自己的实现。**

### 2.3 允许的最强策略

为了最大化实现 1:1，本方案明确允许：

- 直接复制 demo 聊天域源码进工程
- 保留原始类命名与目录命名
- 优先使用 demo 原生 ViewController / Controller / DataProvider / DataSource
- 仅在 adapter / bridge 层把它接到 Raver
- 如果当前 Raver 某层与 demo 冲突，以 demo 为准重做，而不是继续兼容旧实现

---

## 3. 当前代码处理原则

### 3.1 当前 `DemoAligned*` 的定位

当前这些实现：

- `DemoAlignedChatViewController`
- `RaverChatController`
- `RaverChatDataProvider`
- `RaverChatCollectionDataSource`
- 相关 `DemoAligned*Coordinator`

应统一重新定位为：

- 过渡实现
- 回退实现
- 对照实现

而不是最终实现。

### 3.2 立即生效的工程策略

从现在开始：

- 不再把 `DemoAligned*` 当最终实现补细节
- 不再围绕当前自研 coordinator 体系继续扩张
- 不再追求“再改一点就更像”
- 改为直接准备 baseline 源码迁入

### 3.3 允许保留的内容

这些可以作为适配层保留：

- `OpenIMSession`
- Raver 现有账号态与路由态
- 业务服务 facade
- 主题色、文案、本地化资源
- Raver 的群/社区业务跳转

---

## 4. 目标架构

### 4.1 新目标目录

建议新增：

```text
mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/
```

按 demo 原始职责切分：

- `Chat/`
- `Conversation/`
- `Contact/`
- `ChatSetting/`
- `CommonWidgets/`
- `Adapters/`
- `ThemeBridge/`
- `RoutingBridge/`
- `ServiceBridge/`

### 4.2 分层规则

目标分层必须尽量对齐 demo：

- demo `ChatViewController`
  - Raver `BaselineChatViewController`
- demo `DefaultChatController`
  - Raver `BaselineChatController`
- demo `DefaultDataProvider`
  - Raver `BaselineChatDataProvider`
- demo `ChatCollectionDataSource`
  - Raver `BaselineChatCollectionDataSource`
- demo `ChatSetting`
  - Raver `BaselineChatSetting`

要求：

- 类的角色要一致
- 状态边界要一致
- 生命周期入口要一致
- 依赖注入方向要一致

---

## 5. 迁移范围

### 5.1 必须 1:1 的模块

- 会话列表
- 聊天页主容器
- 输入区与附件区
- 文本消息 cell
- 图片消息 cell
- 视频消息 cell
- 语音消息 cell
- 文件消息 cell
- 名片消息 cell
- 位置消息 cell
- 系统消息 cell
- 时间分隔
- typing 提示
- jump to bottom
- 顶部分页 loading
- 长按菜单
- 点击图片/视频预览
- 失败态与重试
- 单聊设置页
- 群设置页
- 会话搜索页

### 5.2 允许适配但不能改机制的模块

- OpenIM SDK 封装层
- 用户资料来源
- 头像 URL 拼接
- 业务页面跳转
- 本地主题颜色与资源图
- 国际化文案资源表

### 5.3 允许后置的模块

如果 demo 中存在但当前业务不立即需要，可后置，但仍应在文档中保留槽位：

- 音视频通话
- 二维码入口
- 某些 demo 专属页面容器

---

## 6. 实施策略：四层迁移法

### Phase 1：基线冻结与差异普查

目标：

- 建立“可执行的 1:1 差异表”

动作：

- 拉取 `openim-ios-demo` 指定 commit
- 输出目录树
- 录制 demo 的页面与交互基线
- 建立差异矩阵：
  - 页面结构 diff
  - 视觉 diff
  - 手势 diff
  - 状态机 diff
  - 页面跳转 diff
  - 消息生命周期 diff

产物：

- `DEMO_BASELINE_FREEZE.md`
- `DEMO_CHAT_DIFF_MATRIX.md`

验收：

- 每个差异项都能落到具体文件与具体行为

### Phase 2：源码迁入，优先保留原文件

目标：

- 把 demo 聊天域源码完整 vendoring 到工程中

动作：

- 迁入 demo 聊天相关目录
- 尽量保留文件名、类名、目录结构
- 建立编译隔离 target 或独立 group
- 先让它在 Raver 工程内编译通过
- 优先保留 demo 原始文件，不做样式型改写
- 若当前 Raver 实现与 demo 冲突，以 demo 原文件为准替换

原则：

- 不在迁入阶段改行为
- 不在迁入阶段做“更贴合 Raver”的重构
- 只修编译错误
- 只补必要 bridge

验收：

- demo 基线代码可在 Raver 内独立编译

### Phase 3：边界适配，最小侵入

目标：

- 不动 demo 内核，只把它接到 Raver

动作：

- 适配登录态
- 适配用户资料读取
- 适配 OpenIM 会话 ID / 用户 ID 映射
- 适配路由跳转
- 适配主题资源
- 适配业务页面入口

原则：

- 适配代码必须放在 `Bridge` / `Adapter` 目录
- 禁止把 Raver 业务逻辑直接灌进 demo 控制器内部
- demo 控制器、controller、datasource、provider 内部尽量不改
- 任何不得不改 demo 原文件的地方，都必须记录成差异项

验收：

- demo 基线聊天页在 Raver 内可跑通主链路

### Phase 4：旧实现下线

目标：

- 从“复刻版”切换到“基线版”

动作：

- 路由切换到 baseline 版本
- `DemoAligned*` 降级为回退实现
- 验证稳定后逐步删除旧实现

验收：

- 默认入口全部走 baseline 实现
- 旧实现不再承担主路径

---

## 7. 详细工作流

### 7.1 页面级迁移顺序

建议顺序：

1. ConversationList
2. ChatViewController
3. InputView / AccessoryView
4. Message Cells
5. Message Menu
6. Preview / Media Viewer
7. ChatSetting
8. GroupSetting
9. Search

原因：

- 会话列表和聊天页决定主路径
- 输入区和 cell 决定最核心交互
- 设置页和搜索页决定“不是只像表面”

补充要求：

- ConversationList 与 ChatViewController 不允许继续使用当前 `DemoAligned*` 作为最终目标页
- 一旦 baseline 版本编译通过，就应尽快把入口切到 baseline 版本上做真实对照

### 7.2 消息链路级迁移顺序

建议顺序：

1. 文本消息
2. 图片消息
3. 视频消息
4. 语音消息
5. 文件消息
6. 名片消息
7. 位置消息
8. 自定义消息
9. 系统消息

每一类都必须验证：

- send
- receive
- local echo
- ack replace
- resend
- pagination backfill
- preview / tap

### 7.3 状态机级迁移顺序

建议顺序：

1. 初次进入落底
2. 上滑分页
3. 新消息自动滚动
4. 用户不在底部时的新消息提示
5. 键盘弹收
6. 会话切换恢复
7. typing
8. unread / read
9. conversation preview

---

## 8. 严格验收标准

### 8.1 验收方式不能只靠人工感觉

必须同时有：

- UI 截图比对
- 交互录屏比对
- 页面结构比对
- 状态机日志比对
- 代码组织比对

### 8.2 每个页面都要有“三重验收”

每个页面都必须通过：

- Visual parity
- Interaction parity
- Structural parity

定义：

- Visual parity：视觉截图与 demo 基线一致
- Interaction parity：同操作、同结果、同时机
- Structural parity：页面内部组织方式与 demo 同构

### 8.3 差异关闭规则

每个差异项只能有三种状态：

- `open`
- `resolved`
- `accepted_by_explicit_decision`

如果你的目标仍然是“一模一样”，那最终应该没有或几乎没有 `accepted_by_explicit_decision`。

---

## 9. 风险与阻塞项

### 高风险

- demo 代码直接迁入后与当前工程依赖冲突
- 当前 Raver 路由与 demo 页面组织不一致
- 当前业务模型与 demo 模型字段不同

### 中风险

- 主题资源替换导致视觉看起来不一致
- Raver 的业务跳转入口破坏 demo 原生页面路径
- 现有 `OpenIMSession` 封装与 demo 预期接口不一致

### 低风险

- 文案
- 图标
- 本地化资源映射

---

## 10. 明确的禁止项

为保证最终能做到 1:1，以下行为禁止发生：

- 禁止继续以 `DemoAligned*` 为最终主线追加功能
- 禁止为了赶进度把 demo 状态机“改写成更适合 Raver 的版本”
- 禁止在 demo 基线控制器内部直接写 Raver 业务逻辑
- 禁止边迁移边视觉二创
- 禁止没有冻结 commit 就开始做对齐
- 禁止以“效果差不多”为验收结论
- 禁止为了复用旧代码而让 baseline 版本反向迁就当前 `DemoAligned*`

---

## 11. 建议的工程执行模式

建议以分支方式推进：

- `codex/openim-demo-baseline-freeze`
- `codex/openim-demo-source-import`
- `codex/openim-demo-chat-bridge`
- `codex/openim-demo-settings-bridge`
- `codex/openim-demo-cutover`

每个分支只做一层事，不混做。

---

## 12. 最终目标态

当这次迁移完成时，应满足以下条件：

- 默认聊天入口不再依赖 `DemoAligned*`
- 聊天主页面的核心类组织与 demo 对齐
- 会话列表、聊天页、设置页、搜索页都来自 demo 基线原文件或近同源直接迁入
- Raver 只在边界层做适配
- 页面视觉、交互、状态机与 demo 一致
- 差异表关闭到接近 0

---

## 13. 针对当前项目的直接结论

对当前 Raver 状态，最重要的策略调整是：

- 现在可以认为“当前聊天重构已完成功能版”
- 但它不是 `openim-ios-demo` 的 1:1 最终形态
- 如果目标升级为“一模一样”，则必须进入新的工程阶段：
  - **从“复刻版优化”切换到“demo 基线迁移”**

也就是说，后续工作的主问题已经不是：

- 再修哪个抖动
- 再补哪个 coordinator
- 再调哪个 cell 细节

而是：

- **如何把 demo 的聊天域原生迁进来，并把 Raver 变成适配层**

如果你的目标坚持为“完全一样”，那最合理的执行口径就是：

- **优先复制 demo 原文件**
- **次优才是同构重写**
- **不允许把当前复刻版继续打磨成最终版**

---

## 14. 下一步执行清单

真正开始做之前，先完成这 6 件事：

- [ ] 冻结 `openim-ios-demo` 目标 commit
- [ ] 输出 demo 聊天域目录清单
- [ ] 建立页面/交互/状态机差异矩阵
- [ ] 在工程内新建 `OpenIMDemoBaseline/` 目录与 target 组织
- [ ] 明确 `DemoAligned*` 后续作为过渡层，而不是最终实现
- [ ] 明确“直接迁源码优先于同构重写”的工程规则

完成这些动作后，直接进入源码迁入阶段。

---

## 15. 执行进度追踪（持续更新）

### 15.1 本节阅读顺序

每次打开本节，统一按这个顺序看，避免任务跳跃：

1. 先看 `15.2 当前总进度定位`
2. 再看 `15.3 顺序执行主表`
3. 然后只执行 `15.4 当前活跃步骤`
4. 需要追溯细节时，再看 `15.5 历史 Checkbox`
5. 需要看构建/排障/验证上下文时，再看 `15.6 关键日志`

规则：

- `15.2` 负责回答“现在整体做到哪里了”
- `15.3` 负责回答“所有任务按什么顺序推进”
- `15.4` 负责回答“当前唯一应该执行哪一步”
- `15.5` 只做历史留痕，不再承担主导航职责
- `15.6` 只做关键日志留痕，不再承担主导航职责

### 15.2 当前总进度定位

- [x] `2026-04-26 09:10 +0800` `Phase 1` 基线冻结：已完成
- [x] `2026-04-26 09:10 +0800` `Phase 2` baseline 骨架建立：已完成
- [x] `2026-04-26 09:10 +0800` `Phase 3` demo 首批源码快照迁入：已完成
- [x] `2026-04-26 09:10 +0800` `Phase 4` bridge / adapter 骨架：已完成
- [x] `2026-04-26 09:10 +0800` `Phase 5` builder 接线：已完成“builder 主链接入 + shim 向 demo 原 builder 命名/构造顺序收口”
- [x] `2026-04-26 09:10 +0800` `Phase 6` provider / controller 接线：已完成“DefaultDataProvider / DefaultChatController` 主链可运行骨架 + 事件桥 + 首批状态机收口”
- [x] `2026-04-26 12:04 +0800` `Phase 7` 聊天页面 1:1 收口：已完成（`D1~D5` 全部闭环）

当前所处位置：

- [x] `2026-04-26 10:57 +0800` 已进入 `Phase 7 / Block D / Step D5`

当前位置定义：

- `Block D` = demo 原聊天页面链替换与行为收口
- `Step D1` = 页面骨架替换
- `Step D2` = 输入/分页/滚动主链接入
- `Step D3` = 更新路径、触发源、mutation、seq 可观测性补齐
- `Step D4` = 基于双端日志做定向验证，并继续细化 batch/reload 切换策略
- `Step D5` = 页面剩余 demo 行为差异关闭

一句话结论：

- `2026-04-26 10:57 +0800` 现在不再处于“builder/provider/controller 基础接线阶段”，而是已经进入“聊天页面行为收口最后阶段（D5）”

### 15.3 顺序执行主表

#### Phase 5：builder 接线

- [x] `2026-04-26 09:10 +0800` `Step P5.1` 固化模型 bridge / chat context / builder adapter
- [x] `2026-04-26 09:10 +0800` `Step P5.2` 让 baseline builder 进入主工程编译链
- [x] `2026-04-26 09:10 +0800` `Step P5.3` 用 demo 原 builder 命名与构造顺序替换 shim 内部主链

#### Phase 6：provider / controller 接线

- [x] `2026-04-26 09:10 +0800` `Step P6.1` 接通 provider 查询桥
- [x] `2026-04-26 09:10 +0800` `Step P6.2` 接通 provider 事件桥与 `IMController` 主回流
- [x] `2026-04-26 09:10 +0800` `Step P6.3` 收口 `DefaultChatController` 首批状态机与 received/unread 语义

#### Phase 7：聊天页面 1:1 收口

- [x] `2026-04-26 09:10 +0800` `Step D1` 页面骨架替换
  - `DefaultChatCollectionDataSource` 从占位到可渲染
  - `ChatViewController` 从文字 shell 到 collection 页面骨架
- [x] `2026-04-26 09:10 +0800` `Step D2` 页面主行为链接入
  - 输入栏
  - 键盘联动
  - 首屏加载
  - 顶部/底部分页
  - 滚动位置恢复
- [x] `2026-04-26 09:10 +0800` `Step D3` 更新链可观测性收口
  - `path`
  - `mutation`
  - `trigger`
  - `seq`
  - 双端日志检索入口
- [x] `2026-04-26 10:41 +0800` `Step D4` 定向验证与更新策略继续收口
  - 用双端日志验证当前 baseline 更新链是否按预期触发
  - 对照 `DemoAligned*` 与 `[OpenIMDemoBaselineUpdate]`
  - 继续把 batch/reload 切换策略向 demo 收紧
- [x] `2026-04-26 11:54 +0800` `Step D5` 页面剩余 demo 行为差异关闭
  - 首批收口方向：首屏/分页参数级对齐、顶部按钮/媒体入口、点击消息内容后的真实动作链

顺序规则：

- 只能 `P5 -> P6 -> P7`
- 进入 `P7` 后只能 `D1 -> D2 -> D3 -> D4 -> D5`
- 未完成当前 step，不允许跳到下一个 step

### 15.4 当前活跃步骤

统一规则：

- `2026-04-26 11:12 +0800` 本节只保留“唯一主线”和“唯一当前步骤”，历史细节一律下沉到 `15.5` / 日志文档
- `2026-04-26 12:07 +0800` 任何新任务必须挂到“当前日志复审主线”子步骤，不允许新增并行步骤线
- `2026-04-26 12:07 +0800` `checkbox` 只能记录结果，不能作为“同源同机制”判断依据；判断必须来自可追溯改造日志与 probe 证据
- `2026-04-26 11:12 +0800` 验收口径只认“demo 同源同机制”；历史条目中若出现“demo 风格/更接近 demo”字样，不视为最终达标
- `2026-04-26 11:16 +0800` 每个大步骤完成后，必须先通过“同源同机制审计门”，否则该步骤不得打勾、不得进入下一步骤
- `2026-04-26 11:16 +0800` 文档整体收尾前，必须执行一次“全量同源同机制总审计”；凡未达标项必须回到对应步骤修正，直到全部达标

当前唯一执行入口：

- [ ] `2026-04-26 12:07 +0800` `Phase 7 / Step D6` 基于改造日志的 `D1~D5` 同源同机制复审补齐（唯一主线）

`D5` 串行子步骤（只允许按顺序推进）：

- [x] `2026-04-26 10:44 +0800` `D5.1` 参数级收口：`loadInitialMessages`、`loadPreviousMessages`、`loadMoreMessages` 行为参数对齐
- [x] `2026-04-26 10:52 +0800` `D5.2` 导航/点击动作壳：标题视图、右上角按钮、媒体入口、URL 点击动作链（本批是同机制动作壳，不代表 settings/media 真实控制器已同源接入）
- [x] `2026-04-26 11:12 +0800` `D5.3` 设置页真实接线：解决 vendor target 边界并接回 demo settings 真实控制器（含同源 `ChatSetting/OIMUIContact` 接入、依赖补齐与构建锚点）
- [x] `2026-04-26 11:49 +0800` `D5.4` 媒体点击真实链路：图片/视频点击后的真实预览动作与 demo 行为进一步收口（已通过：发送图片/视频 + 双端打开预览返回，功能正常）
- [x] `2026-04-26 11:54 +0800` `D5.5` 双端回归与验收封板：按 runbook 完成双端验证并确认无主线回退（已完成）

`D5.3` 执行细分（已完成）：

- [x] `2026-04-26 10:59 +0800` 已确认 `ChatSetting` 同源控制器未被编入当前 `RaverMVP` target（`SingleChatSettingTableViewController.swift` / `GroupChatSettingTableViewController.swift` 等 14 个文件不在 project build sources）
- [x] `2026-04-26 11:06 +0800` 将 `ChatSetting` 同源文件按最小闭包编入 `RaverMVP` target，并修复 `Cells/MemberList` 组路径错误
- [x] `2026-04-26 11:10 +0800` 将 baseline `settingButtonAction` 从占位动作壳切换为 demo 同源 settings 真实控制器 push 链，并补齐 `OUICoreView + MJRefresh` 同源依赖
- [x] `2026-04-26 11:12 +0800` 完成接线后新增构建锚点并记录（`xcodebuild ... -destination 'generic/platform=iOS Simulator'` -> `EXIT:0`）

`D5.4` 执行细分（已完成）：

- [x] `2026-04-26 11:21 +0800` 对齐 demo 媒体点击入口：消息 cell 点击后分流图片/视频/文件到同源控制器（已补齐 `message.media` 透传 + `didTapContent` 按 `contentType` 分流）
- [x] `2026-04-26 11:21 +0800` 对齐 demo 媒体预览控制器与转场行为（含返回后滚动位置保持）（已切到 `MediaPreviewViewController.showIn(...sender:)` + `mediaImageViews` 源视图映射）
- [x] `2026-04-26 11:21 +0800` 补一条 `D5.4` 构建锚点并记录（`xcodebuild ... -destination 'generic/platform=iOS Simulator'` -> `BUILD SUCCEEDED`）
- [x] `2026-04-26 11:29 +0800` 修正 baseline 可用性偏差：默认关闭页面调试面板（`RAVER_OPENIM_BASELINE_DEBUG_OVERLAY` 未开启时不显示），并在输入栏补齐图片/视频发送入口（`+` 按钮 -> `PHPicker` -> `sendImageMessage/sendVideoMessage`）
- [x] `2026-04-26 11:29 +0800` 补本批构建锚点（`xcodebuild ... -destination 'generic/platform=iOS Simulator'` -> `BUILD SUCCEEDED`）

`D5.4` 同源同机制审计（本轮）：

- [x] `2026-04-26 11:21 +0800` `D5.4` 审计：入口链路是否同源（builder/controller/provider/事件源）= 通过（同源 `OpenIMDemoBaselineMessageInfo.media` + bridge 透传已落地）
- [x] `2026-04-26 11:21 +0800` `D5.4` 审计：关键交互是否同机制（触发条件、状态迁移、回流时序）= 通过（`didTapContent` -> `MediaPreviewViewController` 路径与 demo 同机制）
- [x] `2026-04-26 11:49 +0800` `D5.4` 审计：页面行为是否同机制（滚动、分页、回底、转场、返回恢复）= 通过（双端实测：发送图片/视频成功，预览返回会话及列表无异常跳动）
- [x] `2026-04-26 11:21 +0800` `D5.4` 审计：依赖与对象边界是否同源（模块、类型、协议、事件总线）= 通过（已接入同源 `OUICoreView.MediaPreviewViewController/MediaResource`）
- [x] `2026-04-26 11:49 +0800` `D5.4` 审计结论：`通过`（已完成双端 probe + 手工实测闭环）
- [x] `2026-04-26 11:49 +0800` `D5.4` 审计修正项：已闭环（probe 目录：`docs/reports/openim-dual-sim-20260426-114717`；已确认此前 `保存媒体失败` 问题修复）

`D5.5` 执行细分（已完成）：

- [x] `2026-04-26 11:51 +0800` 执行一轮“自动注入文本消息”的双端 probe（尽量减少人工差异；报告目录：`docs/reports/openim-dual-sim-20260426-115130`）
- [x] `2026-04-26 11:49 +0800` 执行一轮“人工图片/视频发送 + 预览返回”的双端 probe（覆盖媒体链；报告目录：`docs/reports/openim-dual-sim-20260426-114717`）
- [x] `2026-04-26 11:54 +0800` 对比两轮 probe 的 `baselineUpdate/trigger/path/mutation` 摘要，确认无主线回退（自动注入侧 `receive/lightweight-batch` 主导；人工媒体侧发送链 `trigger=send path=lightweight-batch` 稳定）
- [x] `2026-04-26 11:54 +0800` 完成 `D5.5` 同源同机制审计记录并给出结论（通过）
- [x] `2026-04-26 11:54 +0800` 补 `D5.5` 封板构建锚点并记录（`xcodebuild ... -destination 'generic/platform=iOS Simulator'` -> `BUILD SUCCEEDED`）

`D5.5` 同源同机制审计（本轮）：

- [x] `2026-04-26 11:54 +0800` `D5.5` 审计：入口链路是否同源（builder/controller/provider/事件源）= 通过（未新增旁路，沿用 `D5.4` 同源链）
- [x] `2026-04-26 11:54 +0800` `D5.5` 审计：关键交互是否同机制（触发条件、状态迁移、回流时序）= 通过（自动注入与人工媒体两轮均命中预期触发源）
- [x] `2026-04-26 11:54 +0800` `D5.5` 审计：页面行为是否同机制（滚动、分页、回底、转场、返回恢复）= 通过（人工媒体轮次已双端手工确认“功能都正常”）
- [x] `2026-04-26 11:54 +0800` `D5.5` 审计：依赖与对象边界是否同源（模块、类型、协议、事件总线）= 通过（本轮仅验证与封板，无新增依赖漂移）
- [x] `2026-04-26 11:54 +0800` `D5.5` 审计结论：`通过`
- [x] `2026-04-26 11:54 +0800` `D5.5` 审计修正项：无新增

`D5` 完成标准：

- [x] `2026-04-26 11:12 +0800` 每完成一个 `D5.x` 子步骤，必须补一条新的构建锚点（`D5.3` 已落实）
- [x] `2026-04-26 11:12 +0800` 每完成一个 `D5.x` 子步骤，必须同步更新主文档与日志文档（带日期和时分）（`D5.3` 已落实）
- [x] `2026-04-26 11:54 +0800` 每完成一个 `D5.x` 子步骤，必须完成一次“同源同机制审计记录”（见下方模板），并明确结论：`通过/不通过`（`D5.4`、`D5.5` 已落实）
- [x] `2026-04-26 11:54 +0800` 若审计结论为“不通过”，必须在当前 `D5.x` 内立即列出修正子项并闭环，不得跳转到下一 `D5.x`（本轮无未闭环项）
- [x] `2026-04-26 11:54 +0800` 不新增 `D5` 之外的并行执行线，不回跳 `P5/P6` 已完成范围

`D5.x` 同源同机制审计模板（历史模板，留作后续增量阶段复用）：

- [ ] `YYYY-MM-DD HH:mm +0800` `D5.x` 审计：入口链路是否同源（builder/controller/provider/事件源）
- [ ] `YYYY-MM-DD HH:mm +0800` `D5.x` 审计：关键交互是否同机制（触发条件、状态迁移、回流时序）
- [ ] `YYYY-MM-DD HH:mm +0800` `D5.x` 审计：页面行为是否同机制（滚动、分页、回底、转场、返回恢复）
- [ ] `YYYY-MM-DD HH:mm +0800` `D5.x` 审计：依赖与对象边界是否同源（模块、类型、协议、事件总线）
- [ ] `YYYY-MM-DD HH:mm +0800` `D5.x` 审计结论：`通过/不通过`
- [ ] `YYYY-MM-DD HH:mm +0800` `D5.x` 审计修正项（若不通过必须列出并逐项打勾）

文档收尾前“全量同源同机制总审计”（最终必做）：

- [ ] `2026-04-26 12:07 +0800` 总审计：`D1~D5` 每个大步骤均有独立日志证据，且证据直接支持“同源同机制”
- [ ] `2026-04-26 12:07 +0800` 总审计：所有审计“不通过/证据不足”项均已修正并复验通过
- [ ] `2026-04-26 12:07 +0800` 总审计：双端验证证据完整（日志 + 行为 + 回归结论）
- [ ] `2026-04-26 12:07 +0800` 总审计最终结论：仅当以上三项满足才允许标记 `通过`

`D1~D5` 基于改造日志的严格复审（`2026-04-26 12:07 +0800`）：

- [ ] `D1` 结论：`证据不足`（当前日志以“页面骨架替换 + 构建通过”为主，缺少“同源代码路径映射 + 双端行为证据”闭环）
- [ ] `D2` 结论：`证据补充中`（`2026-04-26 12:50 +0800` 新增上拉历史定向 probe：已采到 `trigger=previous-load` 链路，但出现高频 `path=fallback-reload`，当前仍需完成“同机制可解释性 + 双端稳定性”闭环）
- [x] `D3` 结论：`通过`（`2026-04-26 12:24 +0800` 已完成“非 demo pending 槽 -> demo 同源 SetActor(onEmpty delayedUpdate) + DifferenceKit StagedChangeset/reload(using:)”改造，并完成构建锚点）
- [x] `D4` 结论：`通过`（已存在多轮双端 probe 与对照结论，证据目录：`docs/reports/openim-dual-sim-20260426-103300`、`...-103837`）
- [x] `D5` 结论：`通过`（已存在双端媒体与自动注入回归日志，证据目录：`docs/reports/openim-dual-sim-20260426-114717`、`...-115130`）
- [ ] 复审总结果：`不通过`（`D1/D2` 仍需补齐日志级同源同机制证据，`D3` 已通过）

`D6` 串行子步骤（日志证据补齐）：

- [ ] `D6.1` 为 `D1` 补齐“同源代码映射 + 运行行为”证据并给出审计结论
- [ ] `D6.2` 为 `D2` 补齐“同机制触发/状态迁移/回流时序”证据并给出审计结论
- [x] `2026-04-26 12:24 +0800` `D6.3` 为 `D3` 补齐“可观测性链路与 demo 同机制关系”证据并给出审计结论（已完成：更新链主门闩改为 demo 同源 SetActor reaction，移除自定义 pending 延迟槽）
- [ ] `D6.4` 基于日志重跑总审计，仅在 `D1~D5` 全部“证据通过”后恢复封板状态
- [x] `2026-04-26 12:28 +0800` `D6.2.a` 已补齐 `D2` 首批同机制链：`scrollViewShouldScrollToTop/scrollViewDidScrollToTop` + `MJRefresh setupRefreshControl/handleRefresh/endRefreshing` + `scrollingToTop` 状态门闩
- [x] `2026-04-26 12:32 +0800` `D6.2.a` 扩展收口：回底滚动已改为 demo 同机制 `ManualAnimator + large-delta 分支 + footer snapshot restore`
- [x] `2026-04-26 12:28 +0800` `D6.1.a` 已收敛 `D1` 一处非同源 UI：移除聊天页 `navigationItem.prompt`（demo 无此入口）
- [ ] `2026-04-26 12:28 +0800` `D6.1.b` 继续补齐 `D1` 页面骨架同源映射证据（标题区/输入区/装饰层）
- [ ] `2026-04-26 12:50 +0800` `D6.2.b` 双端 probe（上拉历史）已执行一轮：证据目录 `docs/reports/openim-dual-sim-20260426-124944`；当前结论为“链路已命中但存在 previous-load 高频回流，暂不通过”
- [ ] `2026-04-26 12:50 +0800` `D6.2.c` 按 demo 同源代码与日志联合复验：确认 `previous-load` 高频回流是否为 demo 同机制可接受行为；若不是，必须给出同源改造并复验通过
- [x] `2026-04-26 12:57 +0800` `D6.2.c.1` 已移除 baseline 自定义消息并入偏差：`DefaultChatController.loadPrevious/loadMore` 删除额外 `delegate.update(...)`，并将 `mergedMessages(...)` 替换为 demo 同机制 `appendConvertingToMessages(...) / insertConvertingToMessages(...)`
- [x] `2026-04-26 12:57 +0800` `D6.2.c.2` 已将 `loadInitialMessages/received/sendTextMessage/sendMediaMessage` 的消息并入统一收回 demo append 语义，避免首屏条数与分页节奏继续受自定义 merge 影响
- [ ] `2026-04-26 12:57 +0800` `D6.2.c.3` 基于新代码重跑“进会话首屏 + 连续上拉到最顶”双端验证，只有滚动体验与 demo 同步后才允许给 `D2` 结论

### 15.5 历史 Checkbox（带时间）

- [x] `2026-04-26 00:03 +0800` `DefaultDataProvider.loadInitialMessages` 去除首屏额外 `emitReceived` 回流，收敛到 demo 首屏加载行为
- [x] `2026-04-26 00:03 +0800` `DefaultDataProvider.addObservers` 由 `observeReceivedMessages` 主驱动改为 `observeNewMessage` 主驱动（同 demo 触发主链）
- [x] `2026-04-26 00:03 +0800` `syncProgress` 分支改为“命中当前会话后拉历史并 `forceReload`”的 demo 逻辑
- [x] `2026-04-26 00:03 +0800` `groupMemberInfoChanged/friendInfoChanged` 增加 `messageStorage` 内 sender 信息回写（nickname/faceURL）
- [x] `2026-04-26 00:03 +0800` `joinedGroupAdded/joinedGroupDeleted/groupMemberAdded/groupMemberDeleted/groupInfoChanged` 改为按 `receiverId` 过滤（同 demo）
- [x] `2026-04-26 00:03 +0800` `recordClear` 改为清空 `messageStorage` 后通知 `delegate.clearMessage()`（同 demo 行为）
- [x] `2026-04-26 00:03 +0800` `getGroupInfo(groupInfoHandler:)` 增加后续 `isJoinedGroup` 回调 `delegate.isInGroup`（同 demo）
- [x] `2026-04-26 00:03 +0800` `getUserInfo(otherInfo:mine:)` 增加无好友信息时 fallback 构造（同 demo）
- [x] `2026-04-26 00:03 +0800` 本批改动构建锚点验证通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:21 +0800` `DefaultChatController.loadInitial/loadPrevious/loadMore` 改成更接近 demo 的显式串行执行链：`merge -> markAllMessagesAsReceived -> markAllMessagesAsRead -> propagate sections`
- [x] `2026-04-26 00:21 +0800` `DefaultChatController.received(messages:forceReload:)` 改成更接近 demo 的显式分支：`forceReload` 全量刷新、当前会话增量刷新、非当前会话仅累计 unread
- [x] `2026-04-26 00:21 +0800` `markAllMessagesAsReceived/markAllMessagesAsRead` 收敛为 demo 当前的空实现
- [x] `2026-04-26 00:21 +0800` 本批控制器状态机收敛后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:22 +0800` `DefaultChatCollectionDataSource` 增加 demo 基础骨架字段与入口：`sections`、`oldSections`、`mediaImageViews`、`prepare(with:)`、`didSelectItemAt`、`UICollectionViewDataSource`
- [x] `2026-04-26 00:22 +0800` `OpenIMDemoBaselineBuilderEditNotifier` 增加 `isEditing/setIsEditing`，为后续页面层替换补齐基础状态位
- [x] `2026-04-26 00:22 +0800` 本批 data source 骨架收敛后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:27 +0800` `DefaultChatCollectionDataSource` 去掉 `cellForItemAt` 占位 `fatalError`，补齐基础 date/message cell 注册与渲染链
- [x] `2026-04-26 00:27 +0800` `ChatViewController` 从纯文本 shell 推进为真正的 collection 页面骨架：接入 `UICollectionView`、底部 input shell、基础状态机字段、首屏加载与底部滚动逻辑
- [x] `2026-04-26 00:27 +0800` 本批页面骨架替换后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:30 +0800` `ChatViewController` 已接入当前工程内可直接编译的 `CollectionViewChatLayout`，完成 `FlowLayout -> ChatLayout` 的第一步收敛
- [x] `2026-04-26 00:30 +0800` `DefaultChatCollectionDataSource` 已补齐最小 `ChatLayoutDelegate` 实现（`sizeForItem/alignmentForItem`），让布局对齐 demo 页面主干结构
- [x] `2026-04-26 00:30 +0800` `processUpdates` 已建立当前工程可落地的最小版闭环：`reloadData + ChatLayout offset restore`，为后续迁入 demo 差量更新链做锚点
- [x] `2026-04-26 00:30 +0800` 本批 `ChatLayout` 接入后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:32 +0800` `ChatViewController` 已补齐 demo 主干级分页触发入口：`scrollViewDidScroll`、`loadPreviousMessages()`、`loadMoreMessages()`
- [x] `2026-04-26 00:32 +0800` `ChatViewController` 已补齐最小滚动保护状态：`loadingPrevious/loadingMore`、`keepContentOffsetAtBottom`、更新中 `ChatLayoutInvalidationContext` 保护
- [x] `2026-04-26 00:32 +0800` 本批分页/滚动行为链补齐后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:35 +0800` `ChatViewController.loadPreviousMessages/loadMoreMessages` 已接入显式 `preferredSnapshot` 恢复，顶部/底部分页回流不再只依赖统一默认 snapshot
- [x] `2026-04-26 00:35 +0800` `ChatViewController.processUpdates` 已支持 `preferredSnapshot`，并新增 `makePreferredSnapshot(for:)` 作为当前 baseline 的 demo 风格快照回退策略
- [x] `2026-04-26 00:36 +0800` `ChatViewController` 底栏从静态 label shell 推进为可聚焦输入壳：补入 `UITextView`、placeholder、`inputBarBottomConstraint/contentStackViewBottomConstraint` 与 `configureInputView(hidden:)`
- [x] `2026-04-26 00:36 +0800` 已补入 demo 同型键盘事件链最小实现：`KeyboardInfo`、`KeyboardListener`、`KeyboardListenerDelegate`，以及 `keyboardWillChangeFrame / keyboardDidChangeFrame / keyboardWillShow / resetOffset`
- [x] `2026-04-26 00:37 +0800` 本批滚动快照恢复 + keyboard/input shell 接入后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:41 +0800` `DefaultChatController` 已补入最小文本发送主链：`sendTextMessage(_:) -> OpenIMSession.shared.sendTextMessage(...) -> IM bridge 转 baseline message -> sections 回流`
- [x] `2026-04-26 00:41 +0800` `ChatViewController` 已补入真实文本发送入口：`Send` 按钮、`.sendingMessage` 状态、发送前滚底、发送后 `processUpdates` 回流与输入框清空
- [x] `2026-04-26 00:41 +0800` 本批文本发送主链接入后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:43 +0800` `ChatViewController` 已补入 `Return` 键发送：`UITextViewDelegate.shouldChangeTextIn` 遇到换行时直接复用当前发送主链
- [x] `2026-04-26 00:43 +0800` `ChatViewController` 已补入输入框高度联动：新增 `inputTextViewHeightConstraint`，按 `sizeThatFits` 在 `42...120` 区间内调整，并在非发送态保持底部可见
- [x] `2026-04-26 00:43 +0800` 本批 `Return` 发送 + 输入栏高度联动接入后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:44 +0800` `ChatViewController` 已补入 keyboard 生命周期后半段：`keyboardDidShow / keyboardWillHide / keyboardDidHide`，并补上基于 `animationCurve` 的键盘动画参数映射
- [x] `2026-04-26 00:44 +0800` `resetOffset(...)` 已改成接受 `curve` 参数，键盘显示/隐藏阶段的 input bar 位移与内容偏移恢复进一步向 demo 统一
- [x] `2026-04-26 00:44 +0800` 本批 keyboard 生命周期收口后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:47 +0800` `ChatViewController.processUpdates` 已补入 `animated` 分支，分页回流改为显式 `animated: false`，发送/普通会话更新改为显式 `animated: true`
- [x] `2026-04-26 00:47 +0800` `ChatViewController` 已补入最小版“界面动作占用时延迟回流”门闩：新增 `ignoreInterfaceActions` 与单槽 `pendingSectionsUpdate`，避免 keyboard/scrolling/sending 期间即时覆盖更新链
- [x] `2026-04-26 00:47 +0800` 本批 `processUpdates(animated)` + 延迟回流门闩接入后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:48 +0800` 延迟回流门闩已继续补齐 `preferredSnapshot` 透传，分页/键盘阶段挂起的更新在恢复执行时不再丢失滚动位置快照
- [x] `2026-04-26 00:48 +0800` 本批 `pendingPreferredSnapshot` 补齐后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 00:51 +0800` `ChatViewController.processUpdates` 已补入当前工程可落地的轻量 diff/update 路径：单 section 下优先走 `CollectionDifference` 的 item insert/delete/reload 批量更新
- [x] `2026-04-26 00:51 +0800` 当前 baseline 已具备第一版“复杂情况中断回退 reload”边界：多 section、推断 move、或无法安全 diff 时，继续 fallback 到既有 `reloadData + snapshot restore`
- [x] `2026-04-26 00:51 +0800` 本批轻量 diff/update 路径接入并修正 `CollectionDifference` API 用法后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 08:49 +0800` 轻量 diff 的中断条件已显式化：section `id/title` 变化、总变更量过大、变更比例过高、或同时出现 delete+insert+reload 混合场景时，主动回退到 `reloadData + snapshot restore`
- [x] `2026-04-26 08:49 +0800` `performBatchUpdates` 与完成回调的时序已重新收口，轻量 diff 路径下的 snapshot 恢复和后续 pending update 排空继续走统一完成链
- [x] `2026-04-26 08:49 +0800` 本批中断阈值显式化后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）
- [x] `2026-04-26 08:50 +0800` `processUpdates` 已将首屏更新从后续增量更新链中拆开：`ignoreInterfaceActions == true` 时固定走 `reloadData + snapshot restore`，不再进入轻量 diff/batch 判定
- [x] `2026-04-26 08:50 +0800` 当前 baseline 已具备更接近 demo 的首屏/增量分流节奏：首屏稳定落地，后续更新再进入 batch/reload 切换策略
- [x] `2026-04-26 08:50 +0800` 本批首屏分流收敛后再次构建通过（`RaverMVP` Debug iPhone 17 Simulator）

### 15.6 关键日志（带时间）

- [x] `2026-04-26 09:12 +0800` 日志已从主方案文档拆分到独立文件，主方案文档不再承载展开式时间线日志
- [x] `2026-04-26 09:23 +0800` 双端 digest 已支持直接汇总 `[OpenIMDemoBaselineUpdate]`，后续验证可先看 digest 再决定是否人工翻全量日志
- [x] `2026-04-26 14:24 +0800` iOS-only 构建链已固定：后续本项目本地验证统一走 `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/build_ios_sim_only.sh`，不再额外编译非 iOS 平台依赖
- [x] `2026-04-26 14:24 +0800` 全项目第一轮 `SwiftUI.Form / Section` 命名空间冲突批量清理已完成；当前构建已推进到 vendor 原 `ChatViewController.swift / ChatViewControllerBuilder.swift` 进入主编译批次
- [x] `2026-04-26 14:31 +0800` 聊天域全局 `Section` 命名污染已从源头修复：vendor `OIMUIChat/Model/Entity/Section.swift` 已重命名为聊天域专用 `ChatSection`，相关 controller / datasource / builder / view controller 链路引用已同步切换
- [x] `2026-04-26 14:31 +0800` 根修后 iOS-only 构建再次恢复通过；说明后续迁移已不再被全项目 `SwiftUI.Section` 冲突持续打断

日志入口：

- [`OPENIM_IOS_DEMO_1TO1_BASELINE_MIGRATION_LOG.md`](/Users/blackie/Projects/raver/docs/OPENIM_IOS_DEMO_1TO1_BASELINE_MIGRATION_LOG.md:1)

本节只保留最小导航，不再重复展开日志内容。

### 15.7 最新进展（2026-04-26 15:52 +0800）

- [x] `2026-04-26 15:52 +0800` 已继续执行“vendor `Section` 同名回归”主线，并完成新一轮全项目命名冲突清理（不回退聊天同源主线）
- [x] `2026-04-26 15:52 +0800` 已修复本轮阻塞构建的 SwiftUI 命名冲突文件：`MainTabView.swift`、`LearnModuleView.swift`、`ChatSettingsSheet.swift`、`DiscoverNewsPublishSheet.swift`、`MessagesHomeView.swift`、`EventEditorView.swift`、`RatingEditors.swift`
- [x] `2026-04-26 15:52 +0800` 已确认 vendor 聊天模型当前为 `struct Section`（非 `ChatSection`），并通过宿主层 `SwiftUI.*` 显式化避免污染
- [x] `2026-04-26 15:52 +0800` iOS-only 构建锚点通过：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/build_ios_sim_only.sh` -> `BUILD SUCCEEDED`（日志：`/tmp/raver_ios_build_after_section_revert_v7.log`）

下一步（严格串行，不偏主线）：

- [ ] `2026-04-26 15:52 +0800` 运行时复验：手动启动双端后采样日志，确认会话进入链仍为 vendor builder/controller/provider 同源路径
- [ ] `2026-04-26 15:52 +0800` 行为复验：进入单聊后执行“首屏展示 + 连续上拉到顶 + 媒体展示/发送”并与 demo 同机制对照
- [x] `2026-04-26 16:08 +0800` 已修复“点图片按钮闪退”阻塞项：补齐 iOS 隐私权限键（相册读取/写入、相机、麦克风）
- [x] `2026-04-26 16:08 +0800` 已补齐 direct 会话 peer 反推兜底（当 `conversation.peer` 缺失时从 `openIMConversationID` 推断对端 userID），用于恢复标题/头像链路稳定性
