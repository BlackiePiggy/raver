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

> 说明：已按你的要求完成“类型2并入类型1”。当前文档中不再保留返回样式类型2，原类型2页面全部按类型1管理。

### 返回样式类型 1：`BS-01` 系统导航栏默认返回

- `DiscoverFullScreenSearchInputView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`  
  已接入公共包装：`Yes`
- `EventsSearchResultsView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`  
  已接入公共包装：`Yes`
- `NewsSearchResultsView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`  
  已接入公共包装：`Yes`
- `DJsSearchResultsView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`  
  已接入公共包装：`Yes`
- `SetsSearchResultsView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`  
  已接入公共包装：`Yes`
- `WikiSearchResultsView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift`  
  已接入公共包装：`Yes`
- `DiscoverNewsPublishSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsPublishSheet.swift`  
  已接入公共包装：`Yes`
- `PostLocationMapView`（活动场地地图）  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`  
  已接入公共包装：`Yes`
- `EventRoutePlannerView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`  
  已接入公共包装：`Yes`
- `EventRoutineView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`  
  已接入公共包装：`Yes`
- `EventCheckinSelectionSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`  
  已接入公共包装：`Yes`
- `DJCheckinBindingSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`  
  已接入公共包装：`Yes`
- `EventEditorView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`  
  已接入公共包装：`Yes`
- `LineupImport`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`  
  已接入公共包装：`Yes`
- `EventLocationPickerSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift`  
  已接入公共包装：`Yes`
- `DJImport`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`  
  已接入公共包装：`Yes`
- `DJEditor`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`  
  已接入公共包装：`Yes`
- `SpotifyImport`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`  
  已接入公共包装：`Yes`
- `TracklistSelectorSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`  
  已接入公共包装：`Yes`
- `UploadTracklistSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`  
  已接入公共包装：`Yes`
- `DJSetEditorView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`  
  已接入公共包装：`Yes`
- `SetEventBindingSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`  
  已接入公共包装：`Yes`
- `TracklistEditorView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`  
  已接入公共包装：`Yes`
- `LearnLabelDetailView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`  
  已接入公共包装：`Yes`
- `LearnFestivalEditorView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`  
  已接入公共包装：`Yes`
- `RankingBoardDetailView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`  
  已接入公共包装：`Yes`
- `RankingBoardEditor`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`  
  已接入公共包装：`Yes`
- `ComposePostView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Feed/ComposePostView.swift`  
  已接入公共包装：`Yes`
- `PostLocationPickerSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Feed/ComposePostView.swift`  
  已接入公共包装：`Yes`
- `PostLocationMapView`（动态卡片）  
  文件：`mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift`  
  已接入公共包装：`Yes`
- `SquadManageSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift`  
  已接入公共包装：`Yes`
- `ChatView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift`  
  已接入公共包装：`Yes`
- `CreateSquadView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift`  
  已接入公共包装：`Yes`
- `MessageAlertDetailView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift`  
  已接入公共包装：`Yes`
- `MyPublishesView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift`  
  已接入公共包装：`Yes`
- `FollowListView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/FollowListView.swift`  
  已接入公共包装：`Yes`
- `UserProfileView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift`  
  已接入公共包装：`Yes`
- `EditProfileView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/EditProfileView.swift`  
  已接入公共包装：`Yes`
- `SettingsView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/SettingsView.swift`  
  已接入公共包装：`Yes`
- `LanguageSettingsView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/SettingsView.swift`  
  已接入公共包装：`Yes`
- `RatingEventEditorSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/RatingEditors/RatingEditors.swift`  
  已接入公共包装：`Yes`
- `RatingUnitEditorSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/RatingEditors/RatingEditors.swift`  
  已接入公共包装：`Yes`
- `CircleIDDetailView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`  
  已接入公共包装：`Yes`
- `CircleIDComposerSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`  
  已接入公共包装：`Yes`
- `CircleIDEventPickerSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`  
  已接入公共包装：`Yes`
- `CircleIDDJPickerSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`  
  已接入公共包装：`Yes`
- `CircleRatingUnitDetailView`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`  
  已接入公共包装：`Yes`
- `CreateRatingEventSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`  
  已接入公共包装：`Yes`
- `CreateRatingEventFromEventSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`  
  已接入公共包装：`Yes`
- `CreateRatingUnitSheet`  
  文件：`mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`  
  已接入公共包装：`Yes`

### 返回样式类型 3：`BS-03` 沉浸式浮动毛玻璃圆形返回

- `EventDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`
  - 已接入公共包装：`Yes`
- `DJDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
  - 已接入公共包装：`Yes`
- `DJSetDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift`
  - 已接入公共包装：`Yes`
- `LearnFestivalDetailView`
  - 文件：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift`
  - 已接入公共包装：`Yes`

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
- `EventsSearchResultsView`
- `NewsSearchResultsView`
- `DJsSearchResultsView`
- `SetsSearchResultsView`
- `WikiSearchResultsView`
- `DiscoverNewsPublishSheet`
- `EventRoutineView`
- `EventCheckinSelectionSheet`
- `DJCheckinBindingSheet`
- `EventEditorView`
- `LineupImport`
- `EventLocationPickerSheet`
- `PostLocationMapView`（活动场地地图）
- `EventRoutePlannerView`
- `DJImport`
- `DJEditor`
- `SpotifyImport`
- `TracklistSelectorSheet`
- `UploadTracklistSheet`
- `DJSetEditorView`
- `SetEventBindingSheet`
- `TracklistEditorView`
- `LearnLabelDetailView`
- `LearnFestivalEditorView`
- `RankingBoardDetailView`
- `RankingBoardEditor`
- `ComposePostView`
- `PostLocationPickerSheet`
- `PostLocationMapView`（动态卡片）
- `SquadManageSheet`
- `ChatView`
- `CreateSquadView`
- `MessageAlertDetailView`
- `MyPublishesView`
- `FollowListView`
- `UserProfileView`
- `EditProfileView`
- `SettingsView`
- `LanguageSettingsView`
- `RatingEventEditorSheet`
- `RatingUnitEditorSheet`
- `CircleIDDetailView`
- `CircleIDComposerSheet`
- `CircleIDEventPickerSheet`
- `CircleIDDJPickerSheet`
- `CircleRatingUnitDetailView`
- `CreateRatingEventSheet`
- `CreateRatingEventFromEventSheet`
- `CreateRatingUnitSheet`

### 已接入 `BS-04`

- `DiscoverNewsDetailView`
- `PostDetailView`
- `SquadProfileView`
- `MyCheckinsView`
- `LearnFestivalRankingDetailView`
- `CircleRatingEventDetailView`

### 已接入 `BS-03`

- `EventDetailView`
- `DJDetailView`
- `DJSetDetailView`
- `LearnFestivalDetailView`

---

## 当前建议的替换优先级

### 第一优先级

- 所有已经明确归为第 4 类的页面，继续统一到 `BS-04`

### 第二优先级

- 所有沉浸式详情页，统一到 `BS-03`

### 第三优先级

- 所有仍然只是“系统导航标题但未接入包装”的页面，可逐步接入 `BS-01`

---

## 新页面接入规则

新增页面时，按下列顺序判断：

1. 是否是普通 push 详情页
   - 是：优先 `BS-01`

2. 是否是沉浸式大图详情页
   - 是：优先 `BS-03`

3. 是否需要统一的顶部标题条 + 渐变遮罩
   - 是：优先 `BS-04`

4. 是否属于全屏预览 / 浏览器 / 查看器
   - 是：可考虑 `BS-X`

如果不符合以上任一类，不建议先写新的返回方案，应该先回到本文件补充规则。

---

## 后续维护记录

### 待办

- [ ] 继续补齐尚未归档的返回页面
- [ ] 给每个页面补充“目标样式”
- [ ] 将 `BS-03` 页面逐步迁移到公共包装
- [x] 已将原 `BS-02` 页面并入 `BS-01`
- [x] 已将 `BS-01` 清单页面全部接入统一包装

### 本次整理结果

- [x] 已梳理当前公共返回样式
- [x] 已梳理当前主要带返回能力页面
- [x] 已形成可持续维护的 Markdown 清单
