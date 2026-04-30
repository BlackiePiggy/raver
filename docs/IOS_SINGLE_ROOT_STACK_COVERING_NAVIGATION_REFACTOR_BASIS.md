# iOS 单根栈覆盖式导航改造依据

- 文档版本: v1.0
- 创建日期: 2026-04-30
- 适用工程: `mobile/ios/RaverMVP/RaverMVP`
- 目标读者: 后续继续做 iOS 导航收口和页面迁移的开发者
- 关联文档:
  - `docs/IOS_GLOBAL_SINGLE_NAVIGATIONSTACK_REFACTOR_TRACKER.md`
  - `docs/IOS_MANUAL_NAVIGATION_CLICKPATH_CHECKLIST.md`
  - `docs/IOS_NAVIGATION_BACK_STYLE_CATALOG.md`

---

## 1. 文档目标

这份文档不重复记录“全局单 `NavigationStack` 改造已经做了什么”，而是专门回答下面这个问题：

> 在“主页整体包含内容区 + 底部 TabBar，所有正式二级页像覆盖在主页整体上的页面一样被 push，并在右滑返回时被拉开”的目标下，当前项目还需要继续做哪些导航收口和页面迁移。

本文作为后续改造依据，重点覆盖：

1. 目标体验与架构约束
2. 当前导航现状的真实结论
3. 哪些页面必须进入根栈
4. 哪些页面可以继续保留局部导航
5. 当前还不干净的链路与明确改造建议
6. 建议实施顺序与回归要点

---

## 2. 目标体验

目标体验必须满足以下约束：

1. `MainTabView` 是主站“底板”。
2. 底板本身包含一级内容区和底部 `TabBar`。
3. 正式二级页不是切换到另一棵导航树，而是覆盖在这张底板之上。
4. 右滑返回时，用户感知是“上层页面被拉开”，底下主页整体始终存在。
5. `TabBar` 不是返回时突然出现，而是一直存在于底层宿主中。

这意味着：

1. 主站区域只能有一个真正的 push 栈。
2. 各 tab 不能再各自维护正式业务栈。
3. 只要用户认知里是“正式打开了一个新页面”，它就应该进入根栈。

---

## 3. 当前架构结论

基于当前代码，真实结论如下：

1. 主站已经有一个全局根栈：`MainTabCoordinatorView -> NavigationStack(path: $router.path)`。
   - 代码位置: `Application/Coordinator/MainTabCoordinator.swift`
2. 根栈的状态源已经是 `AppRouter.path`，并由 `AppRoute` 承接公共 route。
3. `selectedTab` 和 `path` 是分离的，`TabBar` 本身属于底层宿主的一部分。
4. 目前主问题已经不是“有没有单根栈”，而是“还有少量正式详情页仍然躲在局部导航里”。
5. 当前代码中 `AppRouter.pop()` / `popToRoot()` 基本没有实际使用，绝大多数返回仍依赖 `dismiss()` 或绑定状态置空。
6. 当前代码里仍然存在混合语义：
   - 全局根栈 `appPush`
   - 模块 route 转发 `discoverPush/circlePush/messagesPush/profilePush`
   - 页面内 `navigationDestination(item:/isPresented:)`
   - 少量 `NavigationLink`
   - 少量“先 dismiss 再 push”的补丁链路

结论：

> 单根栈的大方向是正确的，但“正式二级页”和“页面内部小流程”之间的边界还没有完全收干净。

---

## 4. 导航判定规则

后续新增或迁移页面时，统一按下面的判定规则处理。

### 4.1 必须进入根栈的页面

满足任意两条及以上，就应进入根栈：

1. 用户会把它理解成“正式打开了一个新页面”。
2. 该页面从多个入口都可能被打开。
3. 该页面有独立的标题、独立信息密度、独立交互闭环。
4. 希望右滑返回时呈现“覆盖在主页整体上的页面被拉开”的效果。
5. 该页面未来可能被 deep link、通知、搜索结果、跨模块入口直接打开。

### 4.2 可以继续留在局部导航的页面

满足以下语义的页面可以保留局部 `navigationDestination` / `NavigationLink`：

1. 它是某个页面内部的小步骤。
2. 用户认知还是“我留在当前页里继续操作”，而不是“我打开了一个正式页面”。
3. 它主要服务于某个编辑器、选择器、导入器、预览器流程。
4. 即使未来被别处复用，也不打算给它独立的全局信息架构身份。

常见可保留局部导航的类型：

1. picker
2. import 子步骤
3. 图片预览
4. 位置选择
5. 编辑器中的辅助子流程

---

## 5. 当前页面分层结论

本节按“应该进根栈”和“可以留局部”两类整理。

### 5.1 已经符合根栈语义，后续继续保持

这些页面已经适合作为覆盖主页整体的正式二级页，后续不要再局部化。

#### 全局公共详情

1. `conversation`
2. `postDetail`
3. `eventDetail`
4. `eventSchedule`
5. `djDetail`
6. `rankingBoardDetail`
7. `userProfile`
8. `squadProfile`
9. `squadManage`
10. `ratingUnitDetail`

参考位置：

- `Application/Coordinator/MainTabCoordinator.swift`

#### Discover 正式页面

1. `searchInput`
2. `searchResults`
3. `labelDetail`
4. `festivalDetail`
5. `setDetail`
6. `newsDetail`
7. `eventCreate`
8. `eventEdit`
9. `setCreate`
10. `setEdit`
11. `learnFestivalCreate`
12. `learnFestivalEdit`
13. `newsPublish`

参考位置：

- `Features/Discover/Coordinator/DiscoverRoute.swift`

#### Circle 正式页面

1. `postCreate`
2. `postEdit`
3. `idCreate`
4. `ratingEventDetail`
5. `ratingEventCreate`
6. `ratingEventImportFromEvent`
7. `ratingUnitCreate`

参考位置：

- `Features/Circle/Coordinator/CircleCoordinator.swift`
- 当前真正承接仍在 `MainTabCoordinator.swift`

#### Messages / Profile 正式页面

1. `messages.alertCategory`
2. `messages.chatSettings`
3. `profile.followList`
4. `profile.settings`
5. `profile.tools`
6. `profile.movieBanner`
7. `profile.myPublishes`
8. `profile.myRoutes`
9. `profile.editProfile`
10. `profile.myCheckins`
11. `profile.publishEvent`
12. `profile.uploadSet`
13. `profile.editEvent`
14. `profile.editSet`
15. `profile.editRatingEvent`
16. `profile.editRatingUnit`

参考位置：

- `Features/Messages/Coordinator/MessagesCoordinator.swift`
- `Features/Profile/Coordinator/ProfileCoordinator.swift`

### 5.2 可以继续留在局部导航的页面

这些页面当前保留局部导航是合理的，前提是不要把它们演化成跨模块正式详情。

#### Event / EventEditor 内部子流程

1. `showRoutePlanner`
2. `showLineupImportEditor`
3. `showLocationPicker`

参考位置：

- `Features/Discover/Events/Views/EventDetailView.swift`
- `Features/Discover/Events/Views/EventEditorView.swift`

#### DJs 模块内部工作流

1. `showDJImportSheet`
2. `showDJEditSheet`
3. `showSpotifyImportSheet`

参考位置：

- `Features/Discover/DJs/Views/DJsModuleView.swift`

#### Learn / MainTab 内部小流程

1. `previewImage`
2. `showEventPicker`
3. `showDJPicker`
4. `showCreateSquad`
5. 聊天设置页中的群成员列表

参考位置：

- `Features/Discover/Learn/Views/LearnModuleView.swift`
- `Features/MainTabView.swift`
- `Features/Messages/ChatSetting/ChatSettingsSheet.swift`

---

## 6. 当前仍需改造的链路总表

本节只列“还需要进行改造”的部分，不重复列已经符合目标的链路。

### 6.1 P0: 必须优先收口

#### R-01 Circle ID 详情仍是局部页面，应提升到根栈

现状：

1. `CircleIDHubView` 通过 `selectedDetailRoute` 本地 `.navigationDestination(item:)` 打开 `CircleIDDetailView`。
2. `CircleIDDetailView` 内再点击 DJ / Event / User 时使用 `dismissAndPush`。
3. 这说明 ID 详情当前仍是 Circle 页内部小栈语义，而不是正式全局详情页。

参考位置：

- `Features/MainTabView.swift`

问题：

1. ID 详情是用户认知里的正式二级页，不应该只是模块内部局部 destination。
2. `dismiss + async push` 是导航语义不统一的补丁信号。
3. 返回链路会依赖当前局部宿主是否还在，长期容易变脆。

改造建议：

1. 为 ID 详情新增独立根路由，例如 `AppRoute.circleIDDetail(entryID: String)`。
2. `CircleIDHubView` 点击 ID 卡片时改为直接 `appPush(.circleIDDetail(...))`。
3. `CircleIDDetailView` 内部点击 DJ / Event / User 时直接继续 `appPush(...)`。
4. 下线 `dismissAndPush`。

完成标准：

1. ID 详情右滑返回直接回到 Circle 首页。
2. ID 详情到 DJ / Event / User 的跳转链不再依赖 `dismiss()` 补丁。

#### R-02 Festival 详情存在双轨打开方式，应统一到根栈

现状：

1. 项目已有正式 `DiscoverRoute.festivalDetail(festivalID:)`。
2. 同时 `LearnModuleView` 里仍有 `selectedFestivalForDetail` 驱动的本地 `.navigationDestination(item:)`。

参考位置：

- `Features/Discover/Coordinator/DiscoverRoute.swift`
- `Features/Discover/Learn/Views/LearnModuleView.swift`

问题：

1. 同一个实体详情存在两种导航语义。
2. 用户从不同入口进入 festival detail，返回体验不一致。
3. 后续维护时容易出现一处改样式、一处漏改的情况。

改造建议：

1. `FestivalDetail` 统一只允许通过 `discoverPush(.festivalDetail(...))` 进入。
2. 删除 `selectedFestivalForDetail` 的本地详情承接。
3. 如果确有局部预览需求，应单独命名为 preview，不应继续叫 detail。

完成标准：

1. Festival 详情全项目仅一种 push 语义。
2. 所有入口右滑返回体验一致。

### 6.2 P1: 建议尽快评估并收口

#### R-03 Event 详情中的评分事件详情需要明确产品语义

现状：

1. `EventDetailView` 里通过 `selectedRatingEventID` 本地 `.navigationDestination` 进入评分事件详情。
2. 当前语义更像“Event 页内部子页”。

参考位置：

- `Features/Discover/Events/Views/EventDetailView.swift`

问题：

1. 如果评分事件详情已经是独立内容页，那它不该继续留在局部导航里。
2. 如果保留本地，后续从别处进入评分事件详情就可能再造一套 route。

决策建议：

1. 如果评分事件详情未来会被搜索、通知、Feed、榜单、他处模块复用打开，则提升到根栈。
2. 如果它严格只是 Event 详情里的辅助子页，可以暂时保留局部。

建议倾向：

1. 只要该页面拥有独立评论、独立编辑、独立互动闭环，就应该提升到根栈。

#### R-04 统一“正式详情只允许一种打开方式”的约束

现状：

1. 项目里大部分详情页已经走根栈。
2. 少量页面仍然以“本地 detail / 全局 detail 并存”的方式存在。

问题：

1. 相同实体的详情页一旦有两种入口语义，后续会持续分叉。
2. 返回动画、TabBar 显隐、标题样式、deep link 映射都会越来越难统一。

改造建议：

1. 为所有正式详情页建立统一准则：
   - 同一实体 detail 只能存在一种正式打开方式。
2. 若保留局部页面，命名上改成：
   - `Preview`
   - `Picker`
   - `Selector`
   - `EditorStep`
3. 不再让局部页面继续叫 `Detail`。

### 6.3 P2: 结构清理与防回流

#### R-05 `CircleCoordinatorView` 的独立栈语义与当前实际不一致

现状：

1. `CircleCoordinatorView` 仍然定义了私有 `NavigationStack(path: $navPath)`。
2. 但当前主站入口并未真正使用它来承接 Circle 正式导航。

参考位置：

- `Features/Circle/Coordinator/CircleCoordinator.swift`

问题：

1. 代码阅读者会误以为 Circle 仍有独立正式栈。
2. 后续新增功能时容易误把页面继续挂到旧的局部栈上。

改造建议：

1. 如果它只剩环境桥接价值，则降级为纯桥接容器。
2. 如果已经没有实际入口使用，则在合适时机删除或显式标注“历史遗留，不再作为主导航入口”。

#### R-06 显式建立 `appPop` / 回退语义收口

现状：

1. push 已基本收口到 `appPush/appNavigate`。
2. pop 仍然大多依赖 `dismiss()`。

问题：

1. 当前代码并没有一个与 push 对应的统一“业务返回语义”。
2. 复杂链路要调试时，很难从代码上看出它到底是在 pop 根栈、关 sheet，还是关本地 destination。

改造建议：

1. 评估增加统一环境 API，例如 `appPop()`。
2. `appPop()` 内部可再按上下文决定：
   - 根栈 pop
   - sheet dismiss
   - fullScreen dismiss
3. 这不是当前最优先事项，但对长期维护有价值。

---

## 7. 分模块改造清单

### 7.1 Discover

需要继续改造：

1. 统一 `FestivalDetail` 只走 `discoverPush(.festivalDetail(...))`。
2. 评估 `EventDetail -> RatingEventDetail` 是否要提升到根栈。
3. 持续防止新增“局部 detail 与全局 detail 并存”的情况。

可以继续保留本地：

1. `EventRoutePlannerView`
2. `LineupImport`
3. `LocationPicker`
4. 图片预览
5. 搜索页里的临时小步骤

### 7.2 Circle

需要继续改造：

1. 将 `CircleIDDetailView` 从局部 destination 提升到根栈。
2. 去掉 `dismissAndPush`。
3. 视情况清理 `CircleCoordinatorView` 的历史独立栈语义。

可以继续保留本地：

1. `CreateSquadView`
2. 事件选择器 / DJ 选择器
3. 其它明确属于 Circle 内部工作流的小步骤页

### 7.3 Messages

当前整体方向正确：

1. `conversation` 应继续保持根栈正式页面身份。
2. `chatSettings` 应继续作为正式二级页承接。
3. `squadProfile` 如需从多个消息入口进入，也应继续沿用统一全局 route / modal 语义。

后续新增页面的规则：

1. 聊天详情里的“成员主页 / 会话详情 / 群资料页”这类正式页都进根栈。
2. 群成员列表、搜索页、媒体选择器这类可以局部化。

### 7.4 Profile

当前整体方向正确：

1. `followList`
2. `myCheckins`
3. `myPublishes`
4. `editProfile`
5. `settings`
6. `publishEvent`
7. `uploadSet`

这些继续保持正式根栈语义。

后续新增页面的规则：

1. 从个人主页按钮进入的正式二级页都应进根栈。
2. 编辑资料过程中的图片裁剪、选择器、辅助步骤可以留局部。

---

## 8. 建议实施顺序

### 第一阶段

1. 迁移 `CircleIDDetailView` 到根栈。
2. 下线 `dismissAndPush`。
3. 回归 Circle -> ID -> DJ/Event/User 的完整返回链路。

### 第二阶段

1. 统一 `FestivalDetail` 入口。
2. 删除 `LearnModuleView` 内本地 festival detail 承接。
3. 回归 Learn / Search / Ranking 等所有进入 festival detail 的入口。

### 第三阶段

1. 评估 `RatingEventDetail` 的产品语义。
2. 若确认为正式详情页，则提升到根栈。
3. 统一命名所有仍然保留局部的页面，避免继续使用 `Detail` 命名造成误导。

### 第四阶段

1. 结构收尾：
   - 清理 `CircleCoordinatorView`
   - 评估 `appPop`
   - 建立 lint / code review 规则，禁止新增双轨 detail

---

## 9. 回归清单

每完成一阶段改造，至少手工回归以下链路。

### 9.1 Circle

1. Circle 首页 -> ID 详情 -> 返回，确认直接回 Circle 首页。
2. Circle 首页 -> ID 详情 -> DJ 详情 -> 返回，确认回 ID 详情。
3. Circle 首页 -> ID 详情 -> Event 详情 -> 返回，确认回 ID 详情。
4. Circle 首页 -> ID 详情 -> UserProfile -> 返回，确认回 ID 详情。
5. 整个过程中底层 `TabBar` 视觉上始终属于底板，而非中途重新出现。

### 9.2 Discover

1. Learn -> FestivalDetail -> 返回。
2. Search -> FestivalDetail -> 返回。
3. Ranking / 关联入口 -> FestivalDetail -> 返回。
4. 确认不同入口进入的 festival detail 视觉与返回体验一致。

### 9.3 Event / Rating

1. EventDetail -> RatingEventDetail -> 返回。
2. 若改为根栈后，再验证 RatingEventDetail -> 其它公共详情 -> 返回。

### 9.4 Messages / Profile

1. Messages -> Conversation -> UserProfile -> 返回。
2. Profile -> FollowList -> UserProfile -> 返回。
3. Profile -> MyCheckins -> EventDetail -> 返回。
4. 确认所有正式子页都呈现为“盖在主页整体上的页面被拉开”。

---

## 10. 以后新增页面时的落地规则

提交新页面前，必须先回答下面三句：

1. 用户会不会把它叫做“一个页面”，而不是“当前页里的一个步骤”？
2. 这个页面是否可能从多个入口被打开？
3. 我是否希望它右滑返回时表现成覆盖在主页整体上的一层？

如果三句里有两句及以上答案为“是”，默认做法就是：

1. 新增根 route
2. 进入 `AppRouter.path`
3. 使用统一导航样式
4. 不在局部 `navigationDestination` 里再承接它

如果三句里大部分答案为“否”，再考虑保留局部导航。

---

## 11. 一句话结论

当前项目的单根栈方向是正确的，足以支撑“二级页覆盖主页整体、右滑时把上层拉开、底层 TabBar 始终属于主页宿主”的目标。

后续改造的重点不是再重做架构，而是继续收口那些仍然躲在局部导航里的正式详情页，尤其是：

1. `CircleIDDetailView`
2. `FestivalDetail` 双轨入口
3. 可能需要上升为正式详情的 `RatingEventDetail`

把这些点收干净之后，整套导航语义和返回体验才会真正稳定。
