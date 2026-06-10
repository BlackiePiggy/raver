# iOS Learn Module 拆分方案

## 背景

当前 Learn 相关实现虽然在 `DiscoverHomeView` 中已经按页面入口拆成了：

- `Rankings`
- `Organizers`
- `Labels`
- `Genres`

但它们仍然共用同一个超大文件：

- [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift)

这个文件目前约 `7578` 行，混合承载了以下多类职责：

- Learn 容器页和 section 切换逻辑
- 榜单列表页
- 流派旭日图页
- 流派详情页
- 厂牌列表页
- 厂牌详情页
- 主办方列表页
- 主办方详情页
- 主办方榜单页
- 各种 share card / preview / 更多操作弹层
- 多个共享 UI 组件与布局工具
- 多个数据模型与 enum
- 各 section 的加载、分页、筛选、刷新状态

这使得当前文件同时存在这些问题：

- 单文件职责过多，理解和改动成本高
- 任一子模块改动都容易影响其他 Learn 子模块
- 编译增量不友好，Review 范围过大
- 状态管理耦合，容易继续长成“第二个超级页面”
- 后续把流派 / 厂牌 / 主办方分别演进成独立 feature 时阻力很大

## 现状校正

这里需要先明确一个现状，避免后续方案基于错误前提：

- `DiscoverHomeView` 已经把 `rankings / organizers / labels / genres` 当成独立页面入口使用，只是入口仍然调用同一个 `LearnModuleView(initialSection:..., showsSectionTabs: false, isActive: ...)`

参考：

- [DiscoverHomeView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DiscoverHomeView.swift:107)
- [DiscoverHomeView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DiscoverHomeView.swift:121)

这意味着拆分目标不是“先把一个大 Tab 拆成多个页面”，而是：

- 保留已经拆好的页面入口
- 去掉这些入口背后共享的单体实现
- 让每个页面只负责自己的加载、状态和 UI

## 目标

### 主要目标

- 让 `Genres / Labels / Organizers / Rankings` 各自有独立 root view
- 把每个页面的数据加载、列表状态、过滤条件、分页状态收回到各自模块内
- 把 detail view、share view、辅助组件按 feature 收拢到各自目录
- 只保留少量真正跨 feature 复用的共享组件到 `Shared`
- 彻底移除 `LearnModuleView.swift` 这类聚合实现，不保留兼容壳
- 进入 Discover 对应 tab 时，只加载当前 tab 自己的数据，不再触发其他 Learn 子模块预加载

### 非目标

- 本轮不强行把所有 Learn 模块都 MVVM 化到最彻底
- 本轮不重写现有 UI 风格和交互
- 本轮不顺手重构 Discover 整体导航体系
- 本轮不改动后端接口契约

## 当前代码职责盘点

### 1. 容器与入口职责

当前容器职责主要在：

- [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:13)

它目前负责：

- `initialSection`
- `showsSectionTabs`
- `selectedSection`
- 每个 section 的 loading / refresh / banner 状态
- 各类列表数据源
- labels 和 festivals 的筛选、排序、分页
- section 切换后的内容渲染

### 2. 流派相关职责

目前流派相关主要集中在：

- `LearnGenreSunburstSection` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:971)
- `LearnGenreDetailView` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:1568)
- `GenreSunburstCanvasView` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2789)
- `GenreSunburstRenderableCanvas` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2933)
- `GenreSunburstLayoutCache / Layout / HitTesting / Node / Segment / Focus`

这部分已经天然是一个独立 feature。

### 3. 厂牌相关职责

目前厂牌相关主要集中在：

- `LearnLabelCard` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:3495)
- `LearnLabelDetailView` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:3661)
- `LearnLabelMultiSelectPanel`
- `LearnLabelExpandableText`
- `LearnLabelExternalLinkRow`
- `LearnLabelAvatarStyling`
- `LearnLabelInfoRow`
- `LearnLabelImagePreviewView`

### 4. 主办方相关职责

目前主办方相关主要集中在：

- `LearnFestival` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:4331)
- `LearnFestivalCard` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:4691)
- `LearnFestivalDetailView` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:4986)
- `LearnFestivalRankingBoardCard`
- `LearnFestivalRankingDetailView`
- `FestivalDetailMoreActionPanel`
- `BrandSharePreviewCard`

### 5. 榜单相关职责

目前榜单相关主要集中在：

- `RankingBoardDetailView` [LearnModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:6806)
- `RankingEntryCard`
- `RankingBoardSharePreviewCard`

### 6. 共享职责

当前真正可能跨 feature 复用的内容包括：

- `LearnLabelInfoRow`
- `LearnLabelExpandableText`
- `LearnLabelExternalLinkRow`
- `LearnLabelImagePreviewView`
- `WrapFlowLayout`

但这些命名都偏向 `Label`，如果被多模块复用，应该抽成中性名字后移动到 shared 目录。

## 拆分原则

### 1. 页面入口独立

每个 Discover page 只依赖自己的 root view，不再经过 `LearnModuleView(initialSection: ...)` 做分发。

### 2. feature 自治

每个 feature 自己维护：

- 加载逻辑
- 刷新逻辑
- 分页逻辑
- filter / sort 状态
- 本 feature 的临时 view state

### 3. 共享能力下沉到 Shared，而不是继续上浮到巨型容器

只有在至少两个 feature 真实复用时，才进入 shared。

### 4. 先拆文件边界，再决定是否进一步抽 ViewModel

第一阶段优先把“文件和职责边界”拆干净，避免一开始同时做：

- 文件迁移
- 状态迁移
- 逻辑重写
- 架构升级

这样风险太高。

### 5. 不做旧兼容层

因为当前线上没有存量用户，也不需要保留旧入口兼容，所以本次拆分按“完整改造”执行：

- 不保留旧 `LearnModuleView` 兼容壳
- 不保留 `initialSection + showsSectionTabs` 这种过渡型 API
- 直接让 `DiscoverHomeView` 对接各自独立 root view

## 建议的目标目录结构

建议在 `Features/Discover/Learn` 下形成以下结构：

```text
Features/Discover/Learn
├── Genres
│   ├── Models
│   │   ├── LearnGenreSunburstNode.swift
│   │   ├── LearnGenreSunburstLayout.swift
│   │   └── LearnGenreSearchItem.swift
│   ├── ViewModels
│   │   └── LearnGenresRootViewModel.swift
│   └── Views
│       ├── LearnGenresRootView.swift
│       ├── LearnGenreSunburstSection.swift
│       ├── LearnGenreSunburstCanvasView.swift
│       ├── LearnGenreSunburstSearchPanel.swift
│       ├── LearnGenreSelectionCard.swift
│       └── LearnGenreDetailView.swift
├── Labels
│   ├── Models
│   │   └── LearnLabelListFilter.swift
│   ├── ViewModels
│   │   ├── LearnLabelsRootViewModel.swift
│   │   └── LearnLabelDetailViewModel.swift
│   └── Views
│       ├── LearnLabelsRootView.swift
│       ├── LearnLabelsToolbar.swift
│       ├── LearnLabelCard.swift
│       ├── LearnLabelDetailView.swift
│       ├── LearnLabelMultiSelectPanel.swift
│       └── LearnLabelShareViews.swift
├── Organizers
│   ├── Models
│   │   ├── LearnFestival.swift
│   │   ├── LearnFestivalLink.swift
│   │   ├── LearnFestivalRankingBoard.swift
│   │   └── LearnFestivalRankedFestival.swift
│   ├── ViewModels
│   │   ├── LearnOrganizersRootViewModel.swift
│   │   └── LearnFestivalDetailViewModel.swift
│   └── Views
│       ├── LearnOrganizersRootView.swift
│       ├── LearnFestivalsToolbar.swift
│       ├── LearnFestivalCard.swift
│       ├── LearnFestivalDetailView.swift
│       ├── LearnFestivalRankingDetailView.swift
│       └── LearnFestivalShareViews.swift
├── Rankings
│   ├── ViewModels
│   │   └── LearnRankingsRootViewModel.swift
│   └── Views
│       ├── LearnRankingsRootView.swift
│       ├── LearnRankingBoardCard.swift
│       ├── RankingBoardDetailView.swift
│       └── LearnRankingShareViews.swift
├── Shared
│   ├── Models
│   ├── ViewModels
│   └── Views
│       ├── LearnMetadataInfoRow.swift
│       ├── LearnExpandableText.swift
│       ├── LearnExternalLinkRow.swift
│       ├── LearnImagePreviewView.swift
│       └── LearnWrapFlowLayout.swift
```

## 目标架构

### 每个 section 一个 root view

#### `LearnGenresRootView`

负责：

- `fetchLearnGenreTreeSummary`
- root node / search index / 详情缓存
- 旭日图状态
- 当前选中节点和 drill-down 逻辑
- 仅在 `Genres` tab 激活时触发加载

#### `LearnLabelsRootView`

负责：

- 厂牌首屏加载
- labels 分页
- sort / order / filters
- 顶部 toolbar
- 仅在 `Labels` tab 激活时触发加载

#### `LearnOrganizersRootView`

负责：

- 主办方首屏加载
- festivals 分页
- 主办方榜单跳转入口
- 仅在 `Organizers` tab 激活时触发加载

#### `LearnRankingsRootView`

负责：

- `fetchRankingBoards`
- 榜单列表页展示
- 仅在 `Rankings` tab 激活时触发加载

## 是否需要 ViewModel

建议分层如下：

### 必须上 ViewModel 的

- `LabelsRoot`
- `OrganizersRoot`
- `RankingsRoot`

原因：

- 这些页面都有明确的数据加载生命周期
- 有分页 / 刷新 / banner / phase 状态
- 迁移到 `ObservableObject` 后更利于测试与复用

### 可以先不强制上 ViewModel 的

- `GenresRoot`

原因：

- 流派页的复杂度主要在“本地布局 / 交互 / 详情预取”，不完全是列表数据流
- 第一阶段可以先拆文件与对象边界
- 第二阶段再评估是否把“树加载 + 搜索索引 + detail cache”抽成独立 view model

不过结合本次“行为也要改”的要求，推荐把 `GenresRoot` 也一起建立根级 view model，至少承接：

- 树 summary 加载
- detail cache
- 首次加载状态
- root node / search index 的异步准备

## 迁移策略

建议分 5 个阶段，逐步推进。

### Phase 0: 文档与边界冻结

产出：

- 本方案文档
- 明确新的目录结构
- 明确各 root view 命名

目标：

- 后续拆分时不再临时命名、临时决定放哪里

### Phase 1: 按 feature 拆文件，并同步改成按 tab 独立加载

做法：

- 先从 `LearnModuleView.swift` 中把已有独立块迁出
- 同时把加载逻辑改到各自 root view / view model 中
- 确保进入某个 tab 时，只触发该 tab 对应的数据请求

建议拆分顺序：

1. `Genres`
2. `Labels`
3. `Organizers`
4. `Rankings`
5. `Shared`

原因：

- 流派模块边界最清晰，最容易先切出去
- 厂牌和主办方都依赖较多共享小组件，放在流派之后更稳

这一阶段的标准：

- 编译通过
- 页面入口切换到独立 root view
- 不再发生“进入流派 tab 时顺带加载 labels / organizers / rankings”的行为
- 同时完成第一批共享组件改名

### Phase 2: 根页面入口替换

做法：

- 在 `DiscoverHomeView` 中把：
  - `LearnModuleView(initialSection: .rankings, showsSectionTabs: false, ...)`
  - `LearnModuleView(initialSection: .festivals, showsSectionTabs: false, ...)`
  - `LearnModuleView(initialSection: .labels, showsSectionTabs: false, ...)`
  - `LearnModuleView(initialSection: .genres, showsSectionTabs: false, ...)`
- 逐步替换为：
- 彻底替换为：
  - `LearnRankingsRootView`
  - `LearnOrganizersRootView`
  - `LearnLabelsRootView`
  - `LearnGenresRootView`

目标：

- 页面入口和实现彻底一一对应
- 删除 `LearnModuleView` 的最后引用

### Phase 3: 状态下沉到各 feature

做法：

- 把 `LearnModuleView` 中各自的 `@State` 迁回对应 root view / view model
- 去掉巨型容器中对各 feature 的全局持有

重点迁移：

- labels 的 sort / filter / pagination
- festivals 的 pagination / selected ranking board
- rankings 的 phase / loading
- genres 的 tree / details / focused state

### Phase 4: Shared 抽象清理

做法：

- 把共享组件换成中性名字
- 消除 `Label*` 命名污染到其他模块的情况

典型例子：

- `LearnLabelInfoRow` -> `LearnMetadataInfoRow`
- `LearnLabelExpandableText` -> `LearnExpandableText`
- `LearnLabelExternalLinkRow` -> `LearnExternalLinkRow`
- `LearnLabelImagePreviewView` -> `LearnImagePreviewView`

### Phase 5: 删除 `LearnModuleView`

做法：

- 删除聚合页实现
- 删除 `initialSection`
- 删除 `showsSectionTabs`
- 删除容器内跨模块状态

目标：

- Learn 四个页面完全独立
- 不再存在过渡结构

## 推荐的具体拆分顺序

### Step 1

先拆流派相关到：

- `Features/Discover/Learn/Genres/...`

包含：

- `LearnGenreSunburstSection`
- `GenreSunburstCanvasContainer`
- `GenreSunburstSelectionCard`
- `LearnGenreDetailView`
- `GenreSunburstSearchPanel`
- `GenreSunburstNode`
- `GenreSunburstSegment`
- `GenreSunburstFocus`
- `GenreSunburstLayoutCache`
- `GenreSunburstLayout`
- `GenreSunburstHitTesting`
- `GenreSunburstStaticRecordBackground`
- `GenreSunburstCanvasView`
- `GenreSunburstRenderableCanvas`

理由：

- 这块文件边界清晰
- 最近改动频率最高
- 性能问题也集中在这里

### Step 2

拆厂牌相关到：

- `Features/Discover/Learn/Labels/...`

### Step 3

拆主办方相关到：

- `Features/Discover/Learn/Organizers/...`

### Step 4

拆榜单相关到：

- `Features/Discover/Learn/Rankings/...`

### Step 5

把共享组件收口到：

- `Features/Discover/Learn/Shared/...`

### Step 6

最后删除 `DiscoverHomeView` 里对旧聚合入口的最后依赖，并移除 `LearnModuleView.swift`。

这样做的好处是：

- 前几步都是“内部重排”
- 路由和入口不动，回归成本更低
- 最后一把再切入口，风险最可控

## 风险点

### 1. 类型可见性风险

目前很多类型是 `private struct` 或 file-private 级别。

拆文件后需要重新梳理：

- 哪些仍然应该 `private`
- 哪些要改成 `internal`
- 哪些需要放到 feature 内其他文件可见

### 2. 共享工具误归属风险

像 `LearnLabelInfoRow` 这类组件，名字挂着 Label，但实际被 Genre / Festival 复用。  
如果直接复制到各 feature，会制造新的重复代码。

### 3. 导航耦合风险

当前很多 detail view 直接从环境里拿：

- `discoverPush`
- `appPush`
- `appContainer`

拆分时要避免把这些依赖又塞回一个新的超级 shared 文件。

### 4. 编译 target 风险

Swift 文件拆分后如果 Xcode project 没自动纳入 target，会出现“本地有文件但 target 不编译”的问题。  
每一阶段都需要完整 `xcodebuild` 验证。

## 验收标准

拆分完成后应满足：

- `DiscoverHomeView` 中每个 Learn page 都有独立 root view
- `LearnModuleView.swift` 不再承载四个 feature 的完整实现
- 任一单文件不再接近当前这种 7000+ 行规模
- 流派、厂牌、主办方、榜单改动不会互相污染
- 现有用户可见行为不回退
- `xcodebuild` 构建通过

## 已确认决策

以下决策已经确认，本方案以后续实现时应直接遵守：

1. 不保留兼容壳，不做旧入口兼容，直接做完整改造
2. 行为同步调整：进入哪个 tab，就只加载哪个 tab 的内容
3. 共享组件和命名清理可以在第一阶段一起做

## 执行清单

### Phase 1: Genres

- [x] 为 `Genres` 建立独立 root view 和独立加载入口
- [x] 在 `DiscoverHomeView` 中把 `genres` tab 改为直接使用独立 root view
- [x] 将 `LearnGenreSunburstSection` 从 `LearnModuleView.swift` 迁出
- [x] 将 `LearnGenreDetailView` 从 `LearnModuleView.swift` 迁出
- [x] 将旭日图布局 / hit test / cache / canvas 相关类型迁出
- [x] 将 `Genres` 首屏改为骨架先出，`searchIndex` / `layoutCache` 异步准备
- [x] 从 `LearnModuleView.swift` 删除旧的 `Genres` 实现
- [x] 完成一次 `xcodebuild` 验证

### Phase 2: Shared

- [x] 为跨模块信息行创建中性共享组件
- [x] 为跨模块外链行创建中性共享组件
- [x] 为跨模块可展开文本创建中性共享组件
- [x] 为跨模块图片预览创建中性共享组件
- [x] 更新 `Genres` 先使用新的中性 shared 组件

### Phase 3: Labels

- [x] 建立 `LearnLabelsRootView`
- [x] 将 labels 的 sort / filter / pagination / 列表状态迁出
- [x] 将 labels 详情和相关共享视图迁出
- [x] 将 `DiscoverHomeView` 的 `labels` tab 切到独立 root view
- [x] 从 `LearnModuleView.swift` 删除旧的 `Labels` 实现

### Phase 4: Organizers

- [x] 建立 `LearnOrganizersRootView`
- [x] 将 festivals 的分页 / 列表 / 榜单入口状态迁出
- [x] 将主办方详情与相关 share 视图迁出
- [x] 将 `DiscoverHomeView` 的 `organizers` tab 切到独立 root view
- [x] 从 `LearnModuleView.swift` 删除旧的 `Organizers` 实现

### Phase 5: Rankings

- [x] 建立 `LearnRankingsRootView`
- [x] 将 rankings 列表与详情迁出
- [x] 将 `DiscoverHomeView` 的 `rankings` tab 切到独立 root view
- [x] 从 `LearnModuleView.swift` 删除旧的 `Rankings` 实现

### Phase 6: Cleanup

- [x] 删除 `LearnModuleView.swift`
- [x] 删除 `LearnModuleSection`
- [x] 清理 `initialSection / showsSectionTabs` 相关旧结构
- [x] 完成最终 `xcodebuild` 验证

## 建议的实施方式

建议按下面顺序和节奏推进：

1. 先做 `Genres`，直接切成独立 root view + 独立加载
2. 再做 `Labels`，连同 filter / sort / pagination 一起迁出
3. 再做 `Organizers`
4. 再做 `Rankings`
5. 同步完成共享组件中性化命名
6. 最后删除 `LearnModuleView.swift`

## 需要你确认的决策点

当前还剩下一个值得在动手前确认的问题。

### 待确认: Genres 是否接受“首屏骨架 + 异步构建搜索索引 / 布局缓存”

可选方向：

- 接受：先尽快展示基础骨架，再异步准备搜索索引与 layout cache
- 不接受：必须等完整缓存都准备好再一起展示

我的建议：

- `接受异步准备`

原因：

- 这样能显著改善流派页首进感知速度
- 也更符合你现在“进入该 tab 只加载该 tab 内容”的目标
- UI 上可以先给用户稳定的占位和渐进呈现

## 推荐结论

推荐采用下面这条执行路线：

1. 直接把 `Genres` 整块从 `LearnModuleView.swift` 切成独立 root view 和独立文件
2. 同步修正 `Genres` 的首屏加载策略，只加载它自己的数据
3. 再按 `Labels -> Organizers -> Rankings` 顺序切出
4. 第一阶段就把共享组件中性化并迁入 `Shared`
5. 完成后删除 `LearnModuleView.swift`

这条路线的优点是：

- 风险低
- 回滚简单
- 每一步都能独立验收
- 符合当前项目“不需要兼容旧壳”的现实条件

## 后续可选工作

下面这些不属于“必须完成当前拆分”的范围，而是拆分完成后的第二轮整理项。  
我把它们按“值不值得继续做”分成了三档，方便直接判断投入产出。

### 结论先看

如果你现在只想把时间花在最值的地方，我建议只优先考虑下面两件事：

1. `继续拆大文件，尤其是 Organizers 详情页`
2. `清理 Learn 相关 warning 和少量共享工具归属`

其他项都不是现在必须做。

---

## 推荐继续做

### Option A: 继续把各 feature 内部大文件再细分一轮

当前还有几个文件虽然已经不再是“超级聚合文件”，但本身仍然偏大：

- `LearnFestivalDetailView.swift` 约 `1507` 行
- `LearnLabelDetailView.swift` 约 `650` 行
- `LearnRankingDetailView.swift` 约 `644` 行
- `LearnGenreDetailView.swift` 约 `425` 行

#### 这项具体做什么

- [ ] 将 `LearnFestivalDetailView.swift` 拆成：
  - `Hero / Tabs / RelatedEvents / RelatedPosts / ShareViews / MoreActionPanel`
- [ ] 将 `LearnLabelDetailView.swift` 拆成：
  - `Hero / Metadata / Links / ShareViews`
- [ ] 将 `LearnRankingDetailView.swift` 拆成：
  - `Header / EntryGrid / ShareViews`
- [ ] 只保留各详情页主文件中的：
  - 页面级状态
  - 导航
  - 数据装配

#### 收益

- Review 范围更小
- 后续改 share、hero、links 时不容易互相污染
- 能把当前“页面独立”进一步变成“页面内部结构也清晰”

#### 成本

- 中等
- 主要是文件移动和可见性梳理
- 风险低于上一轮，因为不会再动页面入口

#### 我的判断

- `值得做`
- 尤其是 `LearnFestivalDetailView.swift`
- 这是后续收益最高的一项
- [x] 删除 `Organizers` 中已无入口的 `LearnFestivalRankingViews.swift` 孤儿文件，避免工程残留无效页面实现
- [x] 修复 `Genres` 根状态默认节点回退错误，避免信息区无限 loading 和根节点误显示“查看详情”
- [x] 对齐 `Genres` 详情页头部样式到 DJ / Event：hero 顶到屏幕顶部、隐藏系统标题栏、改为半透明悬浮返回按钮
- [x] 为 `Genres` 详情页的代表艺人头像补充 DJ 详情跳转能力，并与流派树页保持相同的可跳转判断
- [x] 调整 `Genres` 详情页文案排版：介绍默认全文、层级关系移到介绍上方并去掉外框、标题字体对齐推荐页活动卡片
- [x] 微调 `Genres` 详情页标题：保留 36pt 大小，只替换字体风格，不再使用 rounded 字形
- [x] 微调 `Genres` 详情页标题字重：在保留 36pt 的前提下从 `semibold` 提升为 `bold`
- [x] 修复 `Genres` 详情页艺人宫格对齐：名字区统一预留两行高度，头像顶部保持对齐，超长名称以省略号截断
- [x] 固定 `Genres` 旭日图顶层分类主题色：按分类身份稳定映射颜色，不再受接口返回顺序影响
- [x] 将 `Genres` 详情页 hero 右侧主题色与旭日图顶层分类打通，子分类详情继承所属顶层分类配色
- [x] 打通 `Genre.color` 字段到 BFF / iOS：公开树摘要与详情接口返回继承后的有效主题色，客户端优先使用服务端配置
- [x] 在 web `Genres` 管理页增加独立的“分支主题色”配置区：支持预设色卡、自定义选色器与继承预览，仅允许旭日图第一层分类编辑
- [x] 将 `Genres` 背景图从手填 URL 改为 OSS 上传流：补充 `learn/genres` 图片上传/删除接口，并将 web 新建页与编辑页切换为横版图片上传面板
- [x] 完成颜色配置链路构建验证：`server` TypeScript 构建通过、`web` Next.js 生产构建通过、iOS `RaverMVP` 模拟器构建通过
- [x] 为 iOS DJ 详情页流派标签补充精确名称匹配跳转：命中流派库时进入对应 `Genre` 详情，未命中时保持静态标签
- [x] 为 iOS 个人主页流派标签补充同一套精确名称匹配跳转，并保持未命中标签仅展示不跳转
- [x] 为 iOS EDMTI 结果页流派标签补充同一套精确名称匹配跳转，统一复用流派树 summary 缓存
- [x] 为 web `DJStudioForm` 的流派编辑区改造成“绑定库内流派 + 自定义标签”模式，交互与 EDMTI 后台绑定流派逻辑对齐
- [x] 完成本轮流派标签联动改造验证：`web` Next.js 生产构建通过，iOS `RaverMVP` 模拟器构建通过
- [x] 放弃运行时名称匹配方案，改为“显式 `genreId` 绑定 + 一次性回填”主线，避免客户端实时猜测流派归属
- [x] 新增 [backfill-genre-id-bindings.ts](/Users/blackie/Projects/raver/server/prisma/backfill-genre-id-bindings.ts)：
  - 支持 `djs / personality / users / all`
  - 支持 `dry-run / apply / overwrite-existing / report`
  - 用于把历史字符串标签批量回填成显式 `genreId` 绑定
- [x] 打通 DJ 显式绑定写入链路：
  - `POST /v1/djs/manual/import`
  - `PATCH /v1/djs/:id` 提审 payload
  - `content-submission-dj.service.ts` 审核通过后的真正入库
- [x] 打通 DJ 显式绑定读取链路：BFF `mapDJ(...)` 返回 `genreBindings`，客户端点击只认绑定 ID
- [x] 为用户主页接口补充 `tagBindings`：
  - `/v1/users/:id/profile`
  - `/v1/profile/me`
  - `/v1/profile/bootstrap`
  - 未能映射到库内流派的标签保留占位展示，但不跳转
- [x] 为 EDMTI 结果补充 `genreBindings`，iOS 结果页直接消费服务端绑定，不再依赖本地流派匹配缓存
- [x] 将 iOS DJ 详情页、个人主页、EDMTI 结果页的流派跳转切到显式绑定消费
- [x] 调整 iOS DJ / Profile / EDMTI 的标签展示策略：
  - 跳转能力只认显式 `genreId` 绑定
  - 历史字符串标签仍可展示，但没有绑定时只做占位展示、不允许跳转
  - 客户端不再做运行时名称匹配或兜底猜测
- [x] 将 web `DJStudioForm` 改为显式 `genreBindings` + `genres` 展示快照并存模式
- [x] 完成显式绑定链路构建验证：
  - `pnpm --dir /Users/blackie/Projects/raver/server build`
  - `pnpm --dir /Users/blackie/Projects/raver/web build`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
- [x] 根据首轮 DJ `dry-run` 补一轮保守映射规则：
  - 为 `Big Room / Trap / House Music / Peak Time / Driving` 等明确别名补显式候选
  - 修复 `Techno (Peak Time / Driving)` 这类带括号和斜杠标签的拆分问题
  - 继续保持“只做保守绑定，模糊标签不瞎绑”的策略，未绑定项仍留给客户端做纯展示
- [x] 调整流派详情页内容区块顺序：
  - 删除“基础信息”卡片
  - 删除“风格特征”卡片
  - 将“经典曲目”移动到“代表艺人”下方
- [x] 修复流派详情页“经典曲目”外链按钮展示：
  - 不再只渲染 Spotify / SoundCloud
  - 与 set 详情页 tracklist 一致补上 Apple Music / 网易云等多平台跳转入口
- [x] 调整流派详情页下方内容分组样式：
  - “代表艺人 / 经典曲目 / 延伸阅读”去掉 icon
  - 去掉卡片底色与边框，改为透明背景内容分组
- [x] 对齐流派详情页加载骨架样式：
  - 路由层不再复用活动详情骨架
  - 新增流派详情专用 skeleton，对齐 hero 高度、文案结构与下方透明内容分组
- [ ] 如回填结果符合预期，再执行 `apply` 并复查 `users / djs / personality` 三类数据的命中率

### 显式绑定回填命令

- [x] `pnpm --dir /Users/blackie/Projects/raver/server genres:backfill:bindings`
- [x] `pnpm --dir /Users/blackie/Projects/raver/server genres:backfill:bindings --target=djs`
- [x] `pnpm --dir /Users/blackie/Projects/raver/server genres:backfill:bindings:apply --target=djs`
- [x] `pnpm --dir /Users/blackie/Projects/raver/server genres:backfill:bindings:apply --target=all --overwrite-existing`

---

### Option B: 清理这轮拆分后暴露出来的 warning / 语法债

这轮构建虽然已经通过，但项目里仍然有不少既有 warning，尤其是：

- `ScreenErrorCard` / `ScreenStatusBanner` 的 trailing closure 旧写法 warning
- 一些 Swift 6 并发 warning
- 少量 deprecated API warning

#### 这项具体做什么

- [ ] 优先只清理 `Learn` 相关 warning
- [ ] 再决定是否扩展到 `Discover` 其他模块
- [ ] 不在这一轮强行处理全项目 warning

#### 收益

- 降低后续真正错误被 warning 淹没的概率
- Swift 6 迁移时阻力更小
- 代码可读性会更统一

#### 成本

- 小到中等
- 如果只清理 `Learn` 范围，成本很可控
- 如果扩到全项目，成本会迅速变大

#### 我的判断

- `值得做，但建议限范围`
- 只做 `Learn` 和少量直接相关 shared 即可

---

## 可做可不做

### Option C: 统一零散 extension / utility 的归属

这轮里为了保证删除旧文件后还能编译，通过把一些 extension 暂时放到了稳定位置来收口，比如：

- `Calendar.startOfMonth`
- `String.nilIfEmpty`

#### 这项具体做什么

- [ ] 统一检查 `Learn` 和 `Discover` 里零散 extension 的归属
- [ ] 能进入 `Core` 的放 `Core`
- [ ] 仅被单 feature 使用的，尽量收回对应 feature

#### 收益

- 让“为什么这个工具在这里”更清楚
- 避免以后再次出现“删一个页面文件，顺手删掉全局 extension”的问题

#### 成本

- 小
- 但收益也没有前两项高

#### 我的判断

- `可做`
- 更适合作为前两项过程里的顺手整理

---

### Option D: 为 Learn 四个页面补最小化验证用例

不是完整 UI 自动化，而是做最低限度的 smoke 级验证。

#### 这项具体做什么

- [ ] 对 root view model 增加最小加载状态测试
- [ ] 对 tab 只加载当前页这一行为补最小验证
- [ ] 对 `Genres` 的异步准备流程补最小回归测试

#### 收益

- 后续再改时更安心
- 对“不要回到旧的全量预加载行为”有长期保护

#### 成本

- 中等
- 取决于项目当前测试基础

#### 我的判断

- `如果后续还会继续频繁改 Learn，值得做`
- `如果 Learn 暂时进入稳定期，可以先不做`

---

## 现在不建议做

### Option E: 继续大规模架构升级

例如：

- 全部改成更重的 MVVM / Coordinator 细分
- 统一重写导航
- 全量抽象成更多 shared protocol / generic layer

#### 我的判断

- `现在不建议做`
- 当前拆分目标已经达成
- 这类工作投入大、收益慢，而且容易把代码重新抽象过头

---

## 推荐的下一步顺序

如果继续做，我建议按这个顺序：

1. `先做 Option A，只拆大文件，尤其是 LearnFestivalDetailView`
2. `再做 Option B，只清 Learn 范围 warning`
3. `Option C 作为顺手整理`
4. `Option D 看你后续是否还会频繁改 Learn 再决定`
5. `Option E 暂不进入`

---

## 我的最终建议

如果你问我“还值不值得继续做”，我的答案是：

- `值得继续做一小轮`
- 但不建议再开一轮大的架构工程

最值的收尾点只有两个：

- `把 Organizers / Labels / Rankings 详情页继续拆细`
- `把 Learn 范围 warning 清干净`

做完这两件事，Learn 这一块的可维护性就会从“已经拆开了”进一步变成“真正好维护了”。
