# 全局单 NavigationStack 导航系统改造追踪文档

- 文档版本: v1.0
- 创建日期: 2026-04-11
- 最近更新: 2026-04-11
- 当前状态: 阶段 6 完成（S6-T01/S6-T02/S6-T03/S6-T04/S6-D01 已完成）
- 当前进行任务: 阶段 6 人工回归复核
- 下一任务: 无（等待新阶段或问题回流）
- 目标分支建议: `codex/global-single-navstack-refactor`
- 适用范围: `mobile/ios/RaverMVP/RaverMVP`

---

## 1. 文档目标

本文件是“导航改造唯一执行依据 + 实时进度面板 + 交接日志”。

任何 agent 接手时应先读本文件，再开始改造。改造期间只要发生以下变化，都必须回写本文件：

1. 计划变更
2. 架构决策变更
3. 阶段完成/阻塞
4. 风险发现
5. 回归结果

---

## 2. 当前基线（As-Is）

### 2.1 已确认现状

1. 应用登录后从 `AppCoordinatorView` 进入 `MainTabCoordinatorView`。
2. `MainTabCoordinatorView` 已有根 `NavigationStack(path: $navPath)`，但仅承接 `DiscoverRoute`。
3. `MainTabView` 仍维护 tab 本地状态和 `navigationDepthByTab`，用于 TabBar 显隐。
4. Circle / Messages / Profile 仍有各自 coordinator 和局部 `NavigationStack`。
5. 业务跳转方式混合：`*Push`、`NavigationLink`、`sheet`、`fullScreenCover`、局部 `navigationDestination`、少量 lifecycle 补丁。

### 2.2 基线关键文件

- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/AppCoordinator.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Coordinator/DiscoverRoute.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Circle/Coordinator/CircleCoordinator.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/Coordinator/MessagesCoordinator.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Coordinator/ProfileCoordinator.swift`

---

## 3. 目标架构（To-Be）

```swift
AppCoordinatorView
  -> MainTabCoordinatorView
      -> NavigationStack(path: $router.path)
          -> MainTabView()
          -> .navigationDestination(for: AppRoute.self)
      -> .sheet(item: $router.sheet)
      -> .fullScreenCover(item: $router.fullScreen)
```

目标约束：

1. 主站区只有一个真正的 push 栈。
2. 路由语义统一到 `AppRoute`（公共详情优先上浮）。
3. `TabView` 不再拥有私有 push 栈。
4. `push/sheet/fullScreen` 统一由 `AppRouter` 托管。

---

## 4. 设计原则

1. 路由按页面语义定义，不按模块边界重复定义。
2. 业务跳转统一走 router；本地 `NavigationLink` 仅限纯局部子页（过渡期）。
3. 不在 `onDisappear` 做业务导航。
4. route 参数优先 ID 化（长期）。
5. TabBar 显隐由全局导航状态统一计算。

---

## 5. 分阶段改造计划

### 5.0 任务编号规则（统一追踪）

- 编号格式：`S{阶段}-T{任务序号}`，例如 `S4-T03`。
- 每个任务点必须唯一编号，后续日志与回归都引用编号，避免“上一个/下一个”语义不清。
- 依赖规则：若任务有前置，写成 `前置: Sx-Tyy`。

### 5.1 全局执行顺序（跨阶段主链）

1. `S0-T01` -> `S0-T02` -> `S0-T03`
2. `S1-T01` -> `S1-T02` -> `S1-T03` -> `S1-T04`
3. `S2-T01` -> `S2-T02` -> `S2-T03`
4. `S3-T01` -> `S3-T02` -> `S3-T03`
5. `S4-T01` -> `S4-T02` -> `S4-T03` -> `S4-T04`
6. `S5-T01` -> `S5-T02` -> `S5-T03`
7. `S6-T01` -> `S6-T02` -> `S6-T03` -> `S6-T04`

## 阶段 0: 基线与回归矩阵固化

目标：冻结改造前行为，建立可回归标准。

执行项：

- [x] `S0-T01` 输出“导航人工回归矩阵”并纳入文档。前置: 无
- [x] `S0-T02` 标注当前存在的本地栈/本地跳转/补丁跳转。前置: `S0-T01`
- [x] `S0-T03` 明确每条核心链路的预期返回行为与 TabBar 行为。前置: `S0-T02`

完成标准：

- [x] `S0-D01` 回归清单可直接执行。
- [x] `S0-D02` 至少覆盖 Discover/Circle/Messages/Profile 四域核心路径。

## 阶段 1: 建立统一总线（AppRouter + AppRoute）

目标：不破坏现有功能前提下先统一入口总线。

执行项：

- [x] `S1-T01` 新增 `AppRouter`（过渡实现：内嵌在 `MainTabCoordinator.swift`）。前置: `S0-T03`
- [x] `S1-T02` 新增 `AppRoute`（过渡实现：内嵌在 `MainTabCoordinator.swift`，先桥接模块 route + 少量公共 route）。前置: `S1-T01`
- [x] `S1-T03` `MainTabCoordinatorView` 从 `NavigationPath` 升级到 `AppRouter`。前置: `S1-T02`
- [x] `S1-T04` 新增 `AppRoute` 级 destination 桥接（当前实现为 `routeDestination(for: AppRoute)`）。前置: `S1-T03`

完成标准：

- [x] `S1-D01` 根栈承接类型变为 `AppRoute`。
- [x] `S1-D02` Discover 仍完整可用。

## 阶段 2: 统一 tab 状态与 TabBar 逻辑

目标：`MainTabView` 不再维护导航深度来源。

执行项：

- [x] `S2-T01` `selectedTab` 切换到 `router.selectedTab`。前置: `S1-D01`
- [x] `S2-T02` 删除 `navigationDepthByTab` 和 depth 回调依赖。前置: `S2-T01`
- [x] `S2-T03` TabBar 显隐改为基于 `router.path`/`AppRoute` 元信息。前置: `S2-T02`

完成标准：

- [x] `S2-D01` TabBar 行为不依赖各模块 coordinator depth 上报。

## 阶段 3: 下线模块私有 NavigationStack

目标：Circle/Messages/Profile 不再持有自己的 push 栈。

执行项：

- [x] `S3-T01` Circle 私有栈已从 `MainTabView` 入口下线（`CircleCoordinatorView` 文件待阶段收尾清理）。前置: `S2-D01`
- [x] `S3-T02` MessagesCoordinator 退化为根容器，不持有 path。前置: `S3-T01`
- [x] `S3-T03` ProfileCoordinator 退化为根容器，不持有 path。前置: `S3-T02`

完成标准：

- [x] `S3-D01` 根栈成为唯一 push 栈（主站四 tab 入口不再持有私有 push 栈）。

## 阶段 4: 公共详情页上浮至 AppRoute

目标：消除跨模块重复 route case。

优先级：

1. eventDetail
2. userProfile
3. djDetail
4. postDetail
5. squadProfile
6. conversation
7. setDetail
8. ratingUnitDetail
9. ratingEventDetail

执行项：

- [x] `S4-T01` 上浮 `conversation` 到 `AppRoute.conversation` 并接入 Messages/Profile 入口映射。前置: `S3-D01`
- [x] `S4-T02` 上浮 `postDetail` 到 `AppRoute.postDetail` 并接入 Circle/Profile 入口映射。前置: `S4-T01`
- [x] `S4-T03` Discover 公共详情 push 映射上浮（`eventDetail/userProfile/djDetail/ratingUnitDetail`）。前置: `S4-T02`
- [x] `S4-T04` 从模块 route 中删除重复公共 case（过渡桥接结束后执行）。前置: `S4-T03`
  - [x] `S4-T04a` MessagesRoute 去重：移除 `conversation/userProfile`，统一走 `AppRoute`。
  - [x] `S4-T04b` ProfileRoute 去重：下线 `userProfile/squadProfile/conversation/postDetail/eventDetail/djDetail` 重复 case。
  - [x] `S4-T04c` CircleRoute 去重：下线 `eventDetail/djDetail/userProfile/postDetail/squadProfile` 重复 case。
  - [x] `S4-T04d` DiscoverRoute 去重：评估并下线 `eventDetail/userProfile/djDetail/ratingUnitDetail` 重复 case。

完成标准：

- [x] `S4-D01` 公共详情页在 `AppRoute` 只定义一次。

## 阶段 5: 清理本地 NavigationLink 与补丁链路

目标：移除隐式导航副作用，链路可追踪。

执行项：

- [x] `S5-T01` 清理业务型本地 `NavigationLink`。前置: `S4-D01`
  - [x] `S5-T01a` `PostDetailView`：作者/评论作者跳转从本地 `navigationDestination` 改为 `appPush(.userProfile)`。
  - [x] `S5-T01b` `DJSetDetailView`：DJ/贡献者/评论用户跳转从本地 `navigationDestination` 改为 `appPush(.djDetail/.userProfile)`。
  - [x] `S5-T01c` 继续迁移剩余业务型本地跳转（`NavigationLink`/本地 `navigationDestination`）。
    - [x] `S5-T01c1` `SquadProfileView`：成员主页/会话跳转从本地 `navigationDestination` 改为 `appPush(.userProfile/.conversation)`。
    - [x] `S5-T01c2` 继续迁移 `MainTabView` 与其它模块剩余业务型 `NavigationLink`。
      - [x] `S5-T01c2a` `MainTabView/CircleRatingUnitDetailView`：相关 DJ、评论作者跳转从 `NavigationLink` 改为 `appPush`。
      - [x] `S5-T01c2b` 迁移 `MainTabView/CircleRatingEventDetailView` 的评分单位详情入口到 `appPush(.ratingUnitDetail)` 并补刷新回流。
    - [x] `S5-T01c3` 继续迁移其它页面剩余业务型本地跳转（`NavigationLink`/本地 `navigationDestination`）。
      - [x] `S5-T01c3a` `MyPublishesView`：Set 详情入口从 `NavigationLink` 改为 `appPush(.discover(.setDetail))`。
      - [x] `S5-T01c3b` 继续清理其它模块残留业务型本地跳转。
- [x] `S5-T02` 清理 `pendingRouteAfterDismiss`/`onDisappear push` 之类补丁。前置: `S5-T01`
- [x] `S5-T03` 统一环境导航 API（建议 `appNavigate`）。前置: `S5-T02`

完成标准：

- [x] `S5-D01` 复杂链路不再依赖生命周期补跳。

## 阶段 6: 统一 modal + route 参数 ID 化

目标：为 deep link/推送跳转/状态恢复做准备。

执行项：

- [x] `S6-T01` 建立 `AppSheetRoute`。前置: `S5-D01`
- [x] `S6-T02` 建立 `AppFullScreenRoute`。前置: `S6-T01`
- [x] `S6-T03` 将对象型 route 逐步改为 ID 型。前置: `S6-T02`
  - [x] `S6-T03a` `AppRoute.conversation` 由对象改为 `conversationID`，并引入根路由 `ConversationLoaderView` 按 ID 拉取会话后进入 `ChatView`。
  - [x] `S6-T03b` `AppRoute.postDetail` 由对象改为 `postID`，并引入根路由 `PostDetailLoaderView` 按 ID 拉取帖子后进入 `PostDetailView`。
  - [x] `S6-T03c` 继续推进其余对象型模块路由 ID 化（如 `ProfileRoute.edit*`、`DiscoverRoute.newsDetail/learnFestivalEdit/setEdit/eventEdit` 等）。
    - [x] `S6-T03c1` `CircleRoute.postEdit` 由对象改为 `postID`，并引入 `CirclePostEditorLoaderView` 按 ID 加载后进入编辑页。
    - [x] `S6-T03c2` 继续推进 `ProfileRoute.edit*` 与 `DiscoverRoute` 对象型 case 的 ID 化。
      - [x] `S6-T03c2a` `ProfileRoute.edit*` 全量改为 ID 路由（`eventID/setID/ratingEventID/ratingUnitID`），并在根路由引入编辑加载器按 ID 拉取后进入编辑页。
      - [x] `S6-T03c2b` 推进 `DiscoverRoute` 对象型 case（`newsDetail/learnFestivalEdit/setEdit/eventEdit/labelDetail/festivalDetail`）ID 化。
        - [x] `S6-T03c2b1` `DiscoverRoute.eventEdit/setEdit` 改为 `eventID/setID`，并引入对应编辑加载器按 ID 拉取后进入编辑页。
        - [x] `S6-T03c2b2` 继续推进 `newsDetail/learnFestivalEdit/labelDetail/festivalDetail` 的 ID 化。
          - [x] `S6-T03c2b2a` `DiscoverRoute.newsDetail` 改为 `articleID`，并引入新闻详情加载器按 ID 拉取文章。
          - [x] `S6-T03c2b2b` 继续推进 `learnFestivalEdit/labelDetail/festivalDetail` 的 ID 化。
- [x] `S6-T04` 为 route 补充元信息（`hidesTabBar/analyticsName/preferredTab`）。前置: `S6-T03`

完成标准：

- [x] `S6-D01` push/sheet/fullScreen 三类导航全部统一管理。

---

## 6. 实时进度看板（必须持续更新）

| 阶段 | 状态 | 负责人 | 开始时间 | 完成时间 | 备注 |
|---|---|---|---|---|---|
| 阶段 0 基线固化 | Done | 当前会话 | 2026-04-11 | 2026-04-11 | 已补齐核心链路预期返回与 TabBar 行为矩阵 |
| 阶段 1 统一总线 | Done | 当前会话 | 2026-04-11 | 2026-04-11 | 根栈承接 AppRoute，Discover 静态链路与编译验证通过 |
| 阶段 2 统一 Tab 状态 | Done | 当前会话 | 2026-04-11 | 2026-04-11 | 已移除 depth 依赖，TabBar 显隐收敛到 router.path |
| 阶段 3 下线私有栈 | Done | 当前会话 | 2026-04-11 | 2026-04-11 | Circle、Messages、Profile 主入口均已去私有栈并接入根栈 |
| 阶段 4 公共页上浮 | Done | 当前会话 | 2026-04-11 | 2026-04-11 | 已完成 S4-T01~S4-T04（含 DiscoverRoute 去重）并通过编译 |
| 阶段 5 清理补丁 | Done | 当前会话 | 2026-04-11 | 2026-04-11 | 已完成 S5-T01/S5-T02/S5-T03（业务型本地跳转清理 + 生命周期补跳下线 + appNavigate 收口） |
| 阶段 6 提纯收尾 | Done | 当前会话 | 2026-04-11 | 2026-04-11 | 已完成 S6-T01/S6-T02/S6-T03/S6-T04/S6-D01（建议继续执行人工回归） |

状态枚举约定：`Todo / In Progress / Blocked / Done`

---

## 7. 执行日志（按时间追加，禁止覆盖）

## 2026-04-11

- 完成导航全链路盘点，确认当前是“根栈仅 Discover + 其他模块局部栈”的过渡架构。
- 已确认四类路由定义文件：Discover/Circle/Messages/Profile。
- 已确认本地 `NavigationLink/sheet/fullScreenCover` 分布，后续阶段 5 将重点清理业务型入口。
- 产出本追踪文档，作为后续所有改造的唯一进度来源。

## 2026-04-11 10:55
- 执行阶段: 阶段 1（统一总线）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
- 完成内容:
  - 新增过渡版 `AppRoute` 与 `AppRouter`（先内嵌在 `MainTabCoordinator.swift`，避免 xcodeproj 清单同步风险）。
  - 根 `NavigationStack` 路径从 `NavigationPath` 切为 `[AppRoute]`。
  - 根 `navigationDestination` 从 `DiscoverRoute` 切为 `AppRoute`。
  - `discoverPush` 改为统一进入 `router.push(.discover(...))`。
  - 新增 `AppRoute` 目的地桥接：`discover` 与若干公共详情（event/dj/user/squad/ratingUnit）。
- 验证结果:
  - `xcodebuild -project RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - `AppRoute`/`AppRouter` 目前是“同文件过渡实现”，阶段 1 后半程拆分到独立文件并同步 `project.pbxproj`。
  - 阶段 2 开始接管 `MainTabView.selectedTab` 与 TabBar 显隐来源。

## 2026-04-11 10:56
- 执行阶段: 阶段 2（统一 tab 状态）- 部分完成
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
- 完成内容:
  - `MainTabView` 新增 `@EnvironmentObject private var router: AppRouter`。
  - 当前 tab 状态来源由本地 `@State selectedTab` 切换为 `router.selectedTab`。
  - TabBar 点击切换改为 `router.switchTab(tab)`。
- 验证结果:
  - `xcodebuild -project RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - `navigationDepthByTab` 仍在，TabBar 显隐尚未完全迁到 `router.path` / `AppRoute` 元信息。
  - Circle/Messages/Profile 私有栈尚未下线（阶段 3）。

## 2026-04-11 11:00
- 执行阶段: 阶段 3（下线私有栈）- Circle 部分完成
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
- 完成内容:
  - `AppRoute` 新增 `.circle(CircleRoute)` 过渡桥接 case。
  - 根层注入 `circlePush`，统一由 `MainTabCoordinatorView` 接管并推入根 `router.path`。
  - `MainTabCoordinatorView` 新增 Circle route destination 承接（从原 CircleCoordinator 迁移）。
  - `MainTabView` 的 Circle Tab 改为直接渲染 `CircleHomeView()`，不再挂载 `CircleCoordinatorView` 本地 `NavigationStack`。
  - Circle 公共详情入口（event/dj/user/squad）在 push 时直接上浮到 `AppRoute` 公共 case，其余 Circle 专属页暂走 `.circle(...)`。
- 验证结果:
  - `xcodebuild -project RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - Messages/Profile 仍是私有栈，继续按阶段 3 迁移。
  - `CircleCoordinatorView` 仍保留代码文件（未被 MainTab 使用），待阶段 3 收尾后清理。
  - TabBar 显隐仍部分依赖 `navigationDepthByTab`，待阶段 2 收尾统一。

## 2026-04-11 11:08
- 执行阶段: 阶段 3（下线私有栈）- Messages 部分完成
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/Coordinator/MessagesCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
- 完成内容:
  - `AppRoute` 新增 `.messages(MessagesRoute)` 过渡桥接 case。
  - 根层新增 `messagesPush/messagesPresent` 注入，统一由 `MainTabCoordinatorView` 接管并推入根 `router.path`。
  - 根 destination 新增 Messages 路由承接：`conversation`、`alertCategory`、`userProfile`。
  - 新增 `MessagesAlertDetailContainerView`，为消息通知详情提供独立 `MessageNotificationsViewModel` 生命周期与加载。
  - `MessagesCoordinatorView` 从“私有 NavigationStack”退化为“状态容器 + Home 承载”，不再持有本地 path/modal。
  - `MainTabView` 中 Messages tab 改为无 depth 回调接入（依赖根栈接管跳转）。
  - TabBar 显隐增加 `router.path` 判定，避免已迁移模块出现显隐失真。
- 验证结果:
  - `xcodebuild -project RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - Profile 仍是私有栈，继续按阶段 3 迁移。
  - 阶段 2 收尾仍需移除 `navigationDepthByTab` 并统一到 router/path 元信息。

## 2026-04-11 11:14
- 执行阶段: 阶段 3（下线私有栈）- Profile 完成
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Coordinator/ProfileCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
- 完成内容:
  - `AppRoute` 新增 `.profile(ProfileRoute)` 过渡桥接 case。
  - 根层新增 `profilePush` 注入，统一由 `MainTabCoordinatorView` 接管并推入根 `router.path`。
  - 根 destination 新增 Profile 路由承接（含 `followList/settings/myPublishes/myCheckins/postDetail/edit*` 等）。
  - `editProfile/avatarFullscreen` 改为根路由按需加载当前用户资料（`CurrentUserProfileLoaderView`），并通过 `Notification.Name.profileDidUpdate` 回写 Profile 首页状态。
  - `ProfileCoordinatorView` 退化为状态容器，不再持有本地 `NavigationStack/navPath`。
  - `MainTabView` 的 Profile tab 改为无 depth 回调接入（依赖根栈接管跳转）。
- 验证结果:
  - `xcodebuild -project RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 阶段 2 收尾：删除 `navigationDepthByTab`、`updateNavigationDepth` 等遗留深度逻辑，TabBar 显隐彻底收敛到 `router.path` / route 元信息。
  - 阶段 4：继续把公共详情（conversation 等）从模块 route 进一步上浮到纯 `AppRoute` 语义。

## 2026-04-11 11:15
- 执行阶段: 阶段 2（统一 Tab 状态）- 收尾完成
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
- 完成内容:
  - 删除 `navigationDepthByTab` 与 `updateNavigationDepth` 遗留逻辑。
  - TabBar 显隐完全收敛为基于 `router.path` 的全局状态判断（Discover 保持原有显示策略）。
- 验证结果:
  - `xcodebuild -project RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 下一步:
  - 进入阶段 4：继续上浮公共详情页（优先 `conversation`）到纯 `AppRoute` 语义。

## 2026-04-11 11:19
- 执行阶段: 阶段 4（公共详情页上浮）- 第一批完成
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
- 完成内容:
  - 新增 `AppRoute.postDetail(post:)` 公共路由。
  - `CircleRoute.postDetail` 与 `ProfileRoute.postDetail` push 映射改为上浮到 `AppRoute.postDetail`。
  - 新增 `pushDiscoverRoute(_:)`，将 Discover 侧公共详情（`eventDetail/userProfile/djDetail/ratingUnitDetail`）统一映射到 AppRoute 公共 case。
  - 根层 `discoverPush` 注入与 Discover destination 内部二次 push 均改为走 `pushDiscoverRoute(_:)`，保证跨页面链路持续上浮。
- 验证结果:
  - `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续阶段 4：抽离并下线模块 route 中的重复公共 case（最终达到“AppRoute 只定义一次”）。
  - 阶段 5 将开始引入统一导航 API（`appNavigate`）并清理业务型 `NavigationLink`。

## 2026-04-11 11:23
- 执行阶段: 阶段 0 / 阶段 1（验收补齐）
- 变更文件:
  - /Users/blackie/Projects/raver/docs/IOS_MANUAL_NAVIGATION_CLICKPATH_CHECKLIST.md
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - 在手工回归清单中新增“核心链路预期返回与 TabBar 行为矩阵”（覆盖 Discover/Circle/Messages/Profile/跨入口核心链路）。
  - 更新顶层导航骨架说明为“单根 NavigationStack + 各 Tab 根页承载”，与当前代码一致。
  - 勾选 `S0-T03/S0-D01/S0-D02`，阶段 0 状态更新为 `Done`。
  - 基于 Discover 路由静态检查与编译结果，勾选 `S1-D02`，阶段 1 状态更新为 `Done`。
- 验证结果:
  - 静态检查：`MainTabCoordinatorView` 为唯一根 `NavigationStack`；Discover push 统一经过 `pushDiscoverRoute(_:)`。
  - 编译验证：`xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 按主链继续执行 `S4-T04`：删除模块 route 中重复公共 case，收敛至单一 AppRoute 语义。

## 2026-04-11 11:29
- 执行阶段: 阶段 4（S4-T04 子任务推进）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/Coordinator/MessagesCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - 新增全局环境导航入口 `appPush(AppRoute)`，由根协调器注入。
  - 完成 `S4-T04a`：`MessagesRoute` 删除 `conversation/userProfile` 重复公共 case，仅保留模块专属 `alertCategory`。
  - Messages 首页、聊天页、提醒详情里的会话/用户主页跳转改为直接走 `appPush(.conversation/.userProfile)`。
  - 根协调器中 `.messages(MessagesRoute)` 承接与 `pushMessagesRoute` 同步收敛到模块专属 case。
- 验证结果:
  - `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S4-T04b`：推进 ProfileRoute 重复公共 case 下线。

## 2026-04-11 11:34
- 执行阶段: 阶段 4（S4-T04 子任务推进）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Coordinator/ProfileCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/FollowListView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - 完成 `S4-T04b`：`ProfileRoute` 删除重复公共 case（`userProfile/squadProfile/conversation/postDetail/eventDetail/djDetail`）。
  - Profile 相关调用点统一改为 `appPush(.userProfile/.squadProfile/.conversation/.postDetail/.eventDetail/.djDetail)`。
  - 根协调器 `.profile(ProfileRoute)` 承接与 `pushProfileRoute` 同步收敛到 Profile 模块专属 case。
- 验证结果:
  - `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S4-T04c`：推进 CircleRoute 重复公共 case 下线。

## 2026-04-11 11:39
- 执行阶段: 阶段 4（S4-T04 子任务推进）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Circle/Coordinator/CircleCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - 完成 `S4-T04c`：`CircleRoute` 删除重复公共 case（`eventDetail/djDetail/userProfile/postDetail/squadProfile`）。
  - Circle 侧公共详情调用改为 `appPush(.eventDetail/.djDetail/.userProfile/.postDetail/.squadProfile)`。
  - 根协调器 `.circle(CircleRoute)` 承接与 `pushCircleRoute` 收敛为 Circle 模块专属 case。
  - `circlePush` 在 Circle 页面中仅保留模块专属跳转（`idCreate/postCreate/postEdit/rating*`）。
- 验证结果:
  - `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S4-T04d`：评估并推进 DiscoverRoute 重复公共 case 下线。

## 2026-04-11 11:46
- 执行阶段: 阶段 4（S4-T04d + S4-D01 收口）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Coordinator/DiscoverRoute.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventsModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Recommend/Views/RecommendEventsModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - Discover 侧公共详情入口（`eventDetail/djDetail/userProfile/ratingUnitDetail`）全部改为 `appPush(AppRoute.*)`。
  - `DiscoverRoute` 删除上述 4 个重复公共 case，并同步删除 `makeDiscoverRouteDestination` 中对应分支。
  - `MainTabCoordinator.pushDiscoverRoute(_:)` 收敛为仅桥接 Discover 模块专属 route（直接 `router.push(.discover(route))`）。
  - 完成 `S4-T04d`，并满足 `S4-D01`（已上浮公共详情在 `AppRoute` 仅定义一次）。
- 验证结果:
  - 静态检查：全项目已无 `discoverPush(.eventDetail/.djDetail/.userProfile/.ratingUnitDetail)` 调用。
  - 编译验证：`xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 进入阶段 5：`S5-T01` 开始清理业务型本地 `NavigationLink`。

## 2026-04-11 11:50
- 执行阶段: 阶段 5（S5-T01 首批）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `PostDetailView` 移除 `selectedUserForProfile + navigationDestination(item:)`，改为作者/评论作者统一 `appPush(.userProfile)`。
  - `DJSetDetailView` 移除 `selectedArtistDJ/selectedContributor/selectedCommentUser + navigationDestination(item:)`，改为统一 `appPush(.djDetail/.userProfile)`。
  - 阶段 5 拆分子任务并打勾 `S5-T01a/S5-T01b`，当前推进到 `S5-T01c`。
- 验证结果:
  - `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S5-T01c`：迁移剩余业务型本地跳转（优先 `SquadProfileView`、`MainTabView` 内剩余业务 `NavigationLink`）。

## 2026-04-11 11:52
- 执行阶段: 阶段 5（S5-T01c1）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `SquadProfileView` 移除本地 `pushedConversation/selectedMember + navigationDestination(item:)`。
  - “加入并进入小队”与成员点击统一改为 `appPush(.conversation/.userProfile)`，纳入全局根栈。
  - 阶段 5 子任务进度更新为 `S5-T01c1` 完成，当前推进 `S5-T01c2`。
- 验证结果:
  - `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S5-T01c2`：迁移 `MainTabView` 与其它模块剩余业务型 `NavigationLink`。

## 2026-04-11 11:53
- 执行阶段: 阶段 5（S5-T01c2a）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `CircleRatingUnitDetailView` 中“相关 DJ”和“评论作者”跳转由 `NavigationLink` 改为 `Button + appPush(.djDetail/.userProfile)`。
  - `S5-T01c2` 下新增子任务并完成 `S5-T01c2a`，保留 `S5-T01c2b` 继续清理剩余业务型跳转。
- 验证结果:
  - `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S5-T01c2b`：迁移 `MainTabView` 中评分单位列表入口等剩余业务型 `NavigationLink`。

## 2026-04-11 11:54
- 执行阶段: 阶段 5（S5-T01c2b）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `CircleRatingEventDetailView` 的评分单位详情入口由 `NavigationLink` 改为 `appPush(.ratingUnitDetail)`。
  - 补充 `discoverRatingUnitDidUpdate` 监听，在评分提交后回流刷新当前评分事件页与上层回调。
  - `MainTabView` 业务型 `NavigationLink` 已清零，`S5-T01c2a/S5-T01c2b` 全部完成。
- 验证结果:
  - 静态检查：`rg -n \"\\bNavigationLink\\b\" .../Features/MainTabView.swift` 无结果。
  - 编译验证：`xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 进入 `S5-T01c3`：清理其余模块残留业务型本地跳转。

## 2026-04-11 11:55
- 执行阶段: 阶段 5（S5-T01c3a）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `MyPublishesView` 中 Set 详情入口由本地 `NavigationLink` 改为 `appPush(.discover(.setDetail(setID:)))`，统一进入根栈路由总线。
  - 阶段 5 子任务更新：完成 `S5-T01c3a`，继续推进 `S5-T01c3b`。
- 验证结果:
  - `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S5-T01c3b`：清理其余模块残留业务型本地跳转。

## 2026-04-11 12:01
- 执行阶段: 阶段 5（S5-T01c3b / S5-T02 / S5-T03 收口）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `CircleIDDetailView` 清理 `pendingRouteAfterDismiss + onDisappear` 生命周期补跳，改为显式用户动作内 `dismiss + push`。
  - 全局复扫 `pendingRoute/onDisappear push`，未发现残留生命周期补跳链路。
  - 全局复扫 `NavigationLink`，业务型本地跳转已清理完成，剩余仅 `SettingsView` 的局部设置导航（按策略允许保留）。
  - 根环境导航 API 新增 `appNavigate`，并让 `appPush` 作为兼容别名映射到同一入口，完成统一收口。
  - 阶段勾选更新：`S5-T01/S5-T02/S5-T03/S5-D01` 全部完成。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
  - 静态检查：`rg -n \"\\bNavigationLink\\b\" .../Features` 仅剩 `SettingsView`。
  - 静态检查：`rg -n -U \"onDisappear\\s*\\{[\\s\\S]{0,250}?(appPush|discoverPush|circlePush|messagesPush|profilePush)\" .../Features` 无结果。
- 遗留问题/下一步:
  - 进入阶段 6：从 `S6-T01`（建立 `AppSheetRoute`）开始，继续推进 modal 统一。

## 2026-04-11 12:05
- 执行阶段: 阶段 6（S6-T01）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - 新增 `AppSheetRoute`（当前首个 case：`squadProfile(squadID:)`）。
  - `AppRouter` 新增 `sheet` 状态与 `presentSheet/dismissSheet` API。
  - 根协调器新增 `.sheet(item: $router.sheet)` 与 `sheetDestination(for:)` 承接。
  - `messagesPresent(.squadProfile)` 从旧的 push 链路切换为 `router.presentSheet(.squadProfile(...))`，完成首个 modal 桥接。
  - `sheetDestination` 中使用 `NavigationStack` 承载 `SquadProfileView`，确保其内部 `navigationDestination` 链路保持可用。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S6-T02`：建立 `AppFullScreenRoute` 并桥接现有全屏展示入口。

## 2026-04-11 12:07
- 执行阶段: 阶段 6（S6-T02）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - 新增 `AppFullScreenRoute`（当前首个 case：`avatarFullscreen`）。
  - `AppRouter` 新增 `fullScreen` 状态与 `presentFullScreen/dismissFullScreen` API。
  - 根协调器新增 `.fullScreenCover(item: $router.fullScreen)` 与 `fullScreenDestination(for:)` 承接。
  - `profilePush(.avatarFullscreen)` 入口从 push 路由改为 `router.presentFullScreen(.avatarFullscreen)`，完成首个全屏路由桥接。
  - `fullScreenDestination` 复用 `CurrentUserProfileLoaderView + AvatarFullscreenView`，保持现有头像全屏体验。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S6-T03`：启动对象型 route 的 ID 化改造（优先公共详情高频入口）。

## 2026-04-11 12:15
- 执行阶段: 阶段 6（S6-T03a）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `AppRoute.conversation` 完成 ID 化：从 `Conversation` 对象改为 `conversationID: String`。
  - 新增根路由 `ConversationLoaderView`：按 `conversationID` 拉取 direct/group 会话并定位目标，再进入 `ChatView`。
  - 入口调用点统一改为 `appPush(.conversation(conversationID: ...))`（MessagesHome / SquadProfile / UserProfile）。
  - 文档任务细化：新增 `S6-T03a/S6-T03b` 子任务，便于后续 agent 继续分步推进。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 成功（`BUILD SUCCEEDED`）。
- 遗留问题/下一步:
  - 继续 `S6-T03b`：推进 `postDetail` 等对象型路由 ID 化（先补齐单条资源加载方案）。

## 2026-04-11 12:23
- 执行阶段: 阶段 6（S6-T03b）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/MockSocialService.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `AppRoute.postDetail` 完成 ID 化：从 `Post` 对象改为 `postID: String`。
  - 新增根路由 `PostDetailLoaderView`：通过 `SocialService.fetchPost(postID:)` 拉取帖子后进入 `PostDetailView`。
  - `SocialService`/`LiveSocialService`/`MockSocialService` 增加单条帖子拉取能力，支持按 ID 导航重建。
  - 帖子详情入口统一改为 `appPush(.postDetail(postID: post.id))`（Feed/Profile/UserProfile/Search）。
- 验证结果:
  - 首次验证失败原因为本地 Simulator 名称不匹配（`iPhone 16` 不存在），非代码问题。
  - 修正后执行：
    - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。
- 遗留问题/下一步:
  - 进入 `S6-T03c`：继续收敛其余对象型模块路由为 ID 型（优先 edit 相关入口）。
  - 完成 `S6-T03` 后进入 `S6-T04`（route 元信息）。

## 2026-04-11 12:28
- 执行阶段: 阶段 6（S6-T03c1）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Circle/Coordinator/CircleCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `CircleRoute.postEdit` 完成 ID 化：从 `Post` 对象改为 `postID: String`。
  - 根路由与 Circle coordinator 承接均切换为 `CirclePostEditorLoaderView`，按 `postID` 拉取帖子后进入 `ComposePostView(mode: .edit)`。
  - Feed 页面编辑入口改为 `circlePush(.postEdit(postID: post.id))`，与新路由签名一致。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。
- 遗留问题/下一步:
  - 继续 `S6-T03c2`：推进 `ProfileRoute.edit*` 和 `DiscoverRoute` 中对象型 case 的 ID 化。

## 2026-04-11 12:31
- 执行阶段: 阶段 6（S6-T03c2a）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Coordinator/ProfileCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `ProfileRoute.editEvent/editSet/editRatingEvent/editRatingUnit` 全量改为 ID 参数（`eventID/setID/eventID/unitID`）。
  - `MyPublishesView` 编辑入口改为直接 push ID 路由，移除“先 fetch editable 对象再 push”的页面级补丁逻辑。
  - 根路由新增四个编辑加载器（Event/Set/RatingEvent/RatingUnit），统一按 ID 拉取资源后进入对应编辑页。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。
- 遗留问题/下一步:
  - 进入 `S6-T03c2b`：推进 `DiscoverRoute` 剩余对象型 case 的 ID 化（优先 `eventEdit/setEdit/newsDetail`）。

## 2026-04-11 12:33
- 执行阶段: 阶段 6（S6-T03c2b1）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Coordinator/DiscoverRoute.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `DiscoverRoute.eventEdit/setEdit` 从对象参数改为 ID 参数（`eventID/setID`）。
  - 在 Discover 路由目标中新增 `DiscoverEventEditorLoaderView` 与 `DiscoverSetEditorLoaderView`，按 ID 拉取后进入编辑页。
  - Discover 侧编辑入口同步改为 push ID（`EventDetailView`、`SetsModuleView`）。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。
- 遗留问题/下一步:
  - 继续 `S6-T03c2b2`：推进 `newsDetail/learnFestivalEdit/labelDetail/festivalDetail` 的 ID 化。

## 2026-04-11 12:36
- 执行阶段: 阶段 6（S6-T03c2b2a）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Models/DiscoverNewsModels.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Coordinator/DiscoverRoute.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/NewsModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `DiscoverRoute.newsDetail` 从 `DiscoverNewsArticle` 对象改为 `articleID: String`。
  - `DiscoverNewsRepository` 增加 `fetchArticle(id:)`，通过 `SocialService.fetchPost(postID:) + DiscoverNewsCodec.decode` 支持按 ID 重建文章。
  - 新增 `DiscoverNewsDetailLoaderView`，统一按 `articleID` 拉取后进入新闻详情页。
  - Discover 各入口（Events/DJs/Learn/News/Search）统一改为 `discoverPush(.newsDetail(articleID: ...))`。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。
- 遗留问题/下一步:
  - 继续 `S6-T03c2b2b`：推进 `learnFestivalEdit/labelDetail/festivalDetail` 的 ID 化。

## 2026-04-11 12:41
- 执行阶段: 阶段 6（S6-T03c2b2b + S6-T03 收口）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Coordinator/DiscoverRoute.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `DiscoverRoute.labelDetail/festivalDetail/learnFestivalEdit` 全量改为 ID 参数（`labelID/festivalID/festivalID`）。
  - 新增 Wiki 相关加载器（Label/Festival 详情与 Festival 编辑），统一按 ID 拉取后进入目标页面。
  - Discover 所有相关入口同步改为 push ID（Search/Learn/News 等）。
  - 至此阶段 `S6-T03`（对象型 route ID 化）全部完成。
- 验证结果:
  - 首次编译失败为参数标签误用（`onSave` -> `onSaved`），已修正。
  - 修正后执行：
    - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。
- 遗留问题/下一步:
  - 进入 `S6-T04`：为 `AppRoute` 增补元信息（`hidesTabBar/analyticsName/preferredTab`）并接入使用点。

## 2026-04-11 12:45
- 执行阶段: 阶段 6（S6-T04）
- 变更文件:
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
  - /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - `AppRoute` 新增元信息：`hidesTabBar`、`analyticsName`、`preferredTab`。
  - TabBar 显隐逻辑接入 `AppRoute.hidesTabBar`（在非 Discover tab 下按当前栈顶路由控制）。
  - 阶段任务勾选：`S6-T04` 完成。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。
- 遗留问题/下一步:
  - 执行 `S6-D01` 验收回归（确认 push/sheet/fullScreen 三类导航统一管理且行为一致）。

## 2026-04-11 12:46
- 执行阶段: 阶段 6（S6-D01 验收）
- 变更文件:
  - /Users/blackie/Projects/raver/docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md
- 完成内容:
  - 完成 `S6-D01` 验收勾选。
  - 静态核对结果：
    - 根协调器统一持有 `router.path/router.sheet/router.fullScreen`。
    - 根容器统一注册 `NavigationStack + sheet + fullScreenCover`。
    - push/sheet/fullScreen 三类 app 级导航入口均收口到 `AppRouter`。
- 验证结果:
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`。
- 遗留问题/下一步:
  - 建议按文档回归清单执行 UI 手工链路复核，确认交互体验层无回归。

---

## 8. 决策记录（ADR 简版）

### ADR-001（已采纳）

- 决策：采用“分阶段桥接迁移”，不做一次性重写。
- 原因：当前线上/主干风险可控，便于每阶段独立回归。
- 影响：短期会存在 `AppRoute + 模块 Route` 共存，属于可控过渡。

### ADR-002（待执行）

- 决策：公共详情页上浮优先级先 EventDetail/UserProfile/DJDetail。
- 原因：入口最多、跨模块最多、收益最大。

---

## 9. 风险与阻塞追踪

| 编号 | 风险/阻塞 | 级别 | 状态 | 处理策略 | Owner |
|---|---|---|---|---|---|
| R-001 | 迁移期双入口并存导致重复 push | High | Open | 每迁一模块即收敛为单入口 | 待分配 |
| R-002 | TabBar 显隐逻辑变更引发回归 | High | Open | 先引入 route 元信息再切逻辑 | 待分配 |
| R-003 | 对象型 route 改 ID 影响页面数据加载 | Medium | Open | 分批改造并保留兜底加载状态 | 待分配 |
| R-004 | 历史本地 NavigationLink 隐性依赖 | Medium | Open | 阶段 5 集中清理并逐条回归 | 待分配 |

---

## 10. 回归与验收清单（持续补充）

### A. 根级行为

- [ ] 登录后进入主界面正常。
- [ ] 四个 tab 切换正常。
- [ ] 根栈 push/back 正常。

### B. 公共详情页一致性

- [ ] EventDetail 多入口一致。
- [ ] UserProfile 多入口一致。
- [ ] DJDetail 多入口一致。
- [ ] Conversation 多入口一致。

### C. 复杂链路

- [ ] sheet 内跳详情行为一致。
- [ ] 连续 push + 连续 back 不乱栈。
- [ ] 不再依赖 `onDisappear` 补跳。

### D. UI 行为

- [ ] TabBar 隐藏/恢复稳定。
- [ ] 返回后来源页状态保留符合预期。

---

## 11. Agent 交接说明（必须阅读）

新接手 agent 开始前必须执行：

1. 先读本文件第 6/7/8/9 节。
2. 在第 6 节把自己接手的阶段状态改为 `In Progress`。
3. 改代码前先在第 7 节追加一条“准备执行项”日志。
4. 每次提交后在第 7 节追加“已完成项 + 回归结果 + 遗留问题”。
5. 若计划有变更，必须更新第 5 节对应阶段内容。

日志追加模板：

```md
## YYYY-MM-DD HH:mm
- 执行阶段: 阶段 X
- 变更文件:
  - /abs/path/A.swift
  - /abs/path/B.swift
- 完成内容:
  - xxx
- 验证结果:
  - xxx
- 遗留问题/下一步:
  - xxx
```

---

## 12. 下一步（当前建议）

1. `S6-T03b`：推进 `postDetail` 等对象型路由 ID 化（先明确单条资源加载策略）。
2. `S6-T04`：补充 route 元信息（`hidesTabBar/analyticsName/preferredTab`）。
3. `S6-D01`：完成 push/sheet/fullScreen 三类导航统一验收。
