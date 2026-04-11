# iOS 返回样式与页面清单

## 文档目标

这份文档用于集中整理当前项目中：

1. 已经包装好的返回/顶部导航样式
2. 当前所有带返回、关闭、dismiss 能力的页面
3. 每个页面当前所使用的样式
4. 每个页面是否已经接入公共包装
5. 后续要统一替换时的归类依据

后续新增页面时，也应优先在本文件中选择一种既有样式，而不是再新增散落的返回方案。

---

## 使用方式

建议后续维护时按下面流程执行：

1. 新页面先查“已包装样式”
2. 在“页面清单”里找到相近页面
3. 给该页面填写或更新“目标样式”
4. 按目标样式接入公共包装
5. 修改完成后，把“已接入公共包装”改成 `Yes`

---

## 已包装好的公共返回样式

当前公共实现文件：

- `mobile/ios/RaverMVP/RaverMVP/Shared/RaverNavigationChrome.swift`

### `BS-01` 系统导航栏默认返回

用途：

- 标准 push 页面
- 使用系统导航栏
- 返回按钮使用系统默认返回箭头
- 不需要自定义左上角按钮文案

包装入口：

- `raverSystemNavigation(title:displayMode:)`

代码位置：

- `RaverNavigationChrome.swift:128`

说明：

- 这是后续普通列表详情页、搜索结果页、标准设置页的首选方案
- 原第 5 类“内容区单独返回行”已决定不再新增，应改为这一类

### `BS-02` 系统导航栏 + 左上角文字操作

用途：

- 表单页
- 创建页
- 编辑页
- modal / sheet 风格页面
- 左上角需要 `取消`、`关闭`、`返回` 这种文字操作

包装入口：

- `raverSystemTextActionNavigation(title:leadingTitle:leadingRole:trailing:displayMode:onLeadingTap:)`

代码位置：

- `RaverNavigationChrome.swift:140`

说明：

- 适合“编辑器 / 创建器 / 导入流程 / 选择器”
- 这是当前项目里最常见的表单型返回方案

### `BS-03` 沉浸式浮动毛玻璃圆形返回

用途：

- 沉浸式详情页
- 顶部是大图、沉浸式内容
- 隐藏系统导航栏
- 左上角悬浮一个毛玻璃圆形返回按钮

包装入口：

- `raverImmersiveFloatingNavigationChrome(trailing:onBack:)`

依赖组件：

- `RaverImmersiveFloatingTopBar`
- `RaverNavigationCircleIconButton(style: .glass)`

代码位置：

- `RaverNavigationChrome.swift:44`
- `RaverNavigationChrome.swift:160`

说明：

- 当前 `EventDetail / DJDetail / FestivalDetail / SetDetail` 更接近这一类
- 后续如果这类页面要统一外观，应优先继续复用这个包装

### `BS-04` 顶栏 + 向下渐变遮罩 + 圆形返回按钮 + 中间标题

用途：

- 隐藏系统导航栏
- 页面顶部需要统一的自定义标题栏
- 左边是圆形返回按钮
- 中间有标题
- 顶部有向下渐变遮罩
- 页面内容从导航栏下方开始展示，不再被顶部遮挡

包装入口：

- `raverGradientNavigationChrome(title:trailing:onBack:)`

依赖组件：

- `RaverGradientMaskedTopBar`
- `RaverNavigationCircleIconButton(style: .dimmed)`

代码位置：

- `RaverNavigationChrome.swift:68`
- `RaverNavigationChrome.swift:176`
- `RaverNavigationChrome.swift:226`

说明：

- 这是当前已开始统一替换的重点样式
- 用户要求第 4 类页面统一使用这一种

### `BS-X` 特殊关闭型页面

用途：

- 全屏媒体浏览
- 预览器
- 与普通 push 返回行为不完全一致

当前状态：

- 暂未纳入统一返回样式体系
- 仅保留为“特殊能力页”

示例：

- `Shared/ImageLoaderView.swift` 内的 `FullscreenMediaViewer`

说明：

- 新页面默认不要优先选择这一类
- 只有在“全屏预览 / 查看器 / 关闭即退出”的场景才考虑

---

## 当前样式编码说明

为便于后续归类，本文件统一使用以下编码：

- `BS-01` 系统导航栏默认返回
- `BS-02` 系统导航栏 + 左上文字操作
- `BS-03` 沉浸式浮动毛玻璃圆形返回
- `BS-04` 顶栏 + 向下渐变遮罩
- `BS-X` 特殊关闭型页面
- `LEGACY` 历史写法，尚未接入公共包装

“已接入公共包装”字段说明：

- `Yes`：已经通过 `RaverNavigationChrome.swift` 里的统一接口接入
- `No`：当前仍是页面内自写，后续可按目标样式迁移
- `Partial`：页面属于该类，但内部仍有局部自定义逻辑

---

## 页面清单

> 说明：本清单按“返回样式类型”分组整理。后续你可以直接在每个类型下面增删页面，或者把页面从一个类型移动到另一个类型。

### 返回样式类型 1：`BS-01` 系统导航栏默认返回

- `DiscoverFullScreenSearchInputView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`
  - 已接入公共包装：`Yes`
  - 备注：已删除旧的内容区返回行，改为 `raverSystemNavigation(...)`
- `EventsSearchResultsView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`
  - 已接入公共包装：`No`
- `NewsSearchResultsView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`
  - 已接入公共包装：`No`
- `DJsSearchResultsView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`
  - 已接入公共包装：`No`
- `SetsSearchResultsView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`
  - 已接入公共包装：`No`
- `WikiSearchResultsView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`
  - 已接入公共包装：`No`
- `EventRoutineView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`
  - 已接入公共包装：`No`
- `EventCheckinSelectionSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`
  - 已接入公共包装：`No`
- `DJCheckinBindingSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`
  - 已接入公共包装：`No`
- `TracklistSelectorSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`
  - 已接入公共包装：`No`
- `RankingBoardDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`
  - 已接入公共包装：`No`
- `ChatView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift`
  - 已接入公共包装：`No`
- `CreateSquadView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift`
  - 已接入公共包装：`No`
  - 备注：当前依赖系统默认返回
- `MessageAlertDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift`
  - 已接入公共包装：`No`
- `MyPublishesView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift`
  - 已接入公共包装：`No`
- `FollowListView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/FollowListView.swift`
  - 已接入公共包装：`No`
- `UserProfileView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift`
  - 已接入公共包装：`No`
- `EditProfileView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/EditProfileView.swift`
  - 已接入公共包装：`No`
- `SettingsView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/SettingsView.swift`
  - 已接入公共包装：`No`
- `LanguageSettingsView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/SettingsView.swift`
  - 已接入公共包装：`No`
- `CircleRatingUnitDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`
- `RatingCommentsListView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`
  - 备注：评论列表

### 返回样式类型 2：`BS-02` 系统导航栏 + 左上角文字操作

- `DiscoverNewsPublishSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsPublishSheet.swift`
  - 已接入公共包装：`No`
- `PostLocationMapView`（活动场地地图）
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`
  - 已接入公共包装：`No`
  - 备注：左上 `关闭`
- `EventRoutePlannerView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`
  - 已接入公共包装：`No`
- `EventEditorView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`
  - 已接入公共包装：`No`
- `LineupImport`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`
  - 已接入公共包装：`No`
  - 备注：阵容导入页
- `EventLocationPickerSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`
  - 已接入公共包装：`No`
- `DJImport`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
  - 已接入公共包装：`No`
- `DJEditor`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
  - 已接入公共包装：`No`
- `SpotifyImport`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
  - 已接入公共包装：`No`
- `UploadTracklistSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`
  - 已接入公共包装：`No`
- `DJSetEditorView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`
  - 已接入公共包装：`No`
- `SetEventBindingSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`
  - 已接入公共包装：`No`
- `TracklistEditorView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`
  - 已接入公共包装：`No`
- `LearnLabelDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`
  - 已接入公共包装：`No`
  - 备注：当前是系统导航栏 + 左上 `关闭`
- `LearnFestivalEditorView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`
  - 已接入公共包装：`No`
- `RankingBoardEditor`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`
  - 已接入公共包装：`No`
  - 备注：榜单创建/编辑页
- `ComposePostView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Feed/ComposePostView.swift`
  - 已接入公共包装：`No`
- `PostLocationPickerSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Feed/ComposePostView.swift`
  - 已接入公共包装：`No`
- `PostLocationMapView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift`
  - 已接入公共包装：`No`
  - 备注：位置地图页
- `SquadManageSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift`
  - 已接入公共包装：`No`
- `RatingEventEditorSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/RatingEditors/RatingEditors.swift`
  - 已接入公共包装：`No`
- `RatingUnitEditorSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/RatingEditors/RatingEditors.swift`
  - 已接入公共包装：`No`
- `CircleIDDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`
- `CircleIDComposerSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`
- `CircleIDEventPickerSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`
- `CircleIDDJPickerSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`
- `CreateRatingEventSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`
- `CreateRatingEventFromEventSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`
- `CreateRatingUnitSheet`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`No`

### 返回样式类型 3：`BS-03` 沉浸式浮动毛玻璃圆形返回

- `EventDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`
  - 已接入公共包装：`No`
  - 备注：沉浸式详情页，当前仍保留页面内自定义实现
- `DJDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
  - 已接入公共包装：`No`
- `DJSetDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`
  - 已接入公共包装：`No`
- `LearnFestivalDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`
  - 已接入公共包装：`No`

### 返回样式类型 4：`BS-04` 顶栏 + 向下渐变遮罩

- `DiscoverNewsDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift`
  - 已接入公共包装：`Yes`
- `LearnFestivalRankingDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`
  - 已接入公共包装：`Yes`
- `PostDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift`
  - 已接入公共包装：`Yes`
- `SquadProfileView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift`
  - 已接入公共包装：`Yes`
- `MyCheckinsView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift`
  - 已接入公共包装：`Yes`
- `CircleRatingEventDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
  - 已接入公共包装：`Yes`

### 返回样式类型 X：`BS-X` 特殊关闭型页面

- `FullscreenMediaViewer`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Shared/ImageLoaderView.swift`
  - 已接入公共包装：`No`
  - 备注：更偏“关闭查看器”，不是常规 push 返回页

---

## 已经接入公共包装的页面汇总

### 已接入 `BS-01`

- `DiscoverFullScreenSearchInputView`

### 已接入 `BS-04`

- `DiscoverNewsDetailView`
- `PostDetailView`
- `SquadProfileView`
- `MyCheckinsView`
- `LearnFestivalRankingDetailView`
- `CircleRatingEventDetailView`

### 已有包装但尚未大规模接入

- `BS-02` 已有公共包装接口，但多数页面仍未迁移
- `BS-03` 已有公共包装接口，但沉浸式详情页仍大多保留原页面内实现

---

## 当前建议的替换优先级

### 第一优先级

- 所有已经明确归为第 4 类的页面，继续统一到 `BS-04`

### 第二优先级

- 所有表单/编辑/导入流程，统一到 `BS-02`

### 第三优先级

- 所有沉浸式详情页，统一到 `BS-03`

### 第四优先级

- 所有仍然只是“系统导航标题但未接入包装”的页面，可逐步接入 `BS-01`

---

## 新页面接入规则

新增页面时，按下列顺序判断：

1. 是否是普通 push 详情页
   - 是：优先 `BS-01`

2. 是否是表单 / 编辑 / 创建 / 导入 / 选择流程
   - 是：优先 `BS-02`

3. 是否是沉浸式大图详情页
   - 是：优先 `BS-03`

4. 是否需要统一的顶部标题条 + 渐变遮罩
   - 是：优先 `BS-04`

5. 是否属于全屏预览 / 浏览器 / 查看器
   - 是：可考虑 `BS-X`

如果不符合以上任一类，不建议先写新的返回方案，应该先回到本文件补充规则。

---

## 后续维护记录

### 待办

- [ ] 继续补齐尚未归档的返回页面
- [ ] 给每个页面补充“目标样式”
- [ ] 将 `BS-02` 页面逐步迁移到公共包装
- [ ] 将 `BS-03` 页面逐步迁移到公共包装
- [ ] 将 `BS-01` 的普通系统页逐步接入统一包装

### 本次整理结果

- [x] 已梳理当前公共返回样式
- [x] 已梳理当前主要带返回能力页面
- [x] 已形成可持续维护的 Markdown 清单
