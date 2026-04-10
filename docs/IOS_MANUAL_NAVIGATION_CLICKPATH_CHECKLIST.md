# iOS 手工回归点击路径清单（全量跳转 + Sheet/Modal）

更新时间：2026-04-10
适用工程：`mobile/ios/RaverMVP/RaverMVP`

## 0. 说明

本文用于手工回归“当前代码里的全部页面跳转逻辑”，包含：
- `NavigationStack` / `navigationDestination` / `NavigationLink` 的 push 跳转
- `sheet` / `fullScreenCover` 的 modal 跳转
- Coordinator route 通道（`discoverPush/circlePush/messagesPush/messagesPresent/profilePush`）

术语：
- `PUSH`：栈内右滑/返回按钮可返回上一页
- `SHEET`：底部弹层（可下滑关闭）
- `FULL`：全屏覆盖层

---

## 1. 顶层容器与主导航骨架

### 1.1 App 启动流
- [ ] `AppCoordinatorView`：未登录进入 `LoginView`。
- [ ] 登录后进入 `MainTabCoordinatorView -> MainTabView`。

### 1.2 四个主 Tab（各自独立 NavigationStack）
- [ ] `DiscoverCoordinatorView { DiscoverHomeView() }`
- [ ] `CircleCoordinatorView { CircleHomeView() }`
- [ ] `MessagesCoordinatorView(repository:)`
- [ ] `ProfileCoordinatorView(repository:)`

---

## 2. Discover 模块点击路径

### 2.1 Discover 根页
- [ ] 顶部分段切页：`推荐/活动/资讯/DJ/Sets/Wiki` 正常切换。

### 2.2 推荐（RecommendEventsModuleView）
- [ ] 点击推荐卡片 -> `EventDetailView`（`PUSH`）。

### 2.3 活动（EventsModuleView）
- [ ] 点击活动卡片 -> `EventDetailView`（`PUSH`）。
- [ ] 右上角 `+` -> `EventEditorView(mode: .create)`（`PUSH`）。
- [ ] 点击日历按钮 -> `EventCalendarSheet`（`SHEET`）。
- [ ] 在日历中点击某活动 -> 关闭日历并进入活动详情（`PUSH`）。
- [ ] 点击筛选按钮 -> `EventCountryFilterSheet`（`SHEET`）。

### 2.4 活动详情（EventDetailView）
- [ ] 顶部返回按钮可返回上一级（`PUSH` 返回）。
- [ ] 个人发布者可见编辑按钮，点击 -> `EventEditorView(mode: .edit)`（`PUSH`）。
- [ ] `相关资讯` 列表点击 -> `DiscoverNewsDetailView`（`PUSH`）。
- [ ] 评分区域点击评分事件 -> `CircleRatingEventDetailView`（`PUSH`，本地 `navigationDestination`）。
- [ ] 日程里点击 `定制路线` -> `EventRoutePlannerView`（`PUSH`，本地 `navigationDestination`）。
- [ ] 打卡入口 -> `EventCheckinSelectionSheet`（`SHEET`）。
- [ ] 场馆地图入口 -> `EventVenueMapSheet`（`SHEET`）。
- [ ] 分享入口 -> `ActivityShareSheet`（`SHEET`）。

### 2.5 资讯（NewsModuleView + DiscoverNewsDetailView）
- [ ] 资讯列表点击 -> `DiscoverNewsDetailView`（`PUSH`）。
- [ ] 资讯搜索按钮 -> `DiscoverFullScreenSearchInputView(domain: .news)`（`PUSH`）。
- [ ] 搜索提交 -> `NewsSearchResultsView`（`PUSH`）。
- [ ] 搜索结果点击资讯 -> 资讯详情（`PUSH`）。
- [ ] 发布按钮 -> `DiscoverNewsPublishSheet`（页面名是 Sheet，但承载为 `PUSH`）。
- [ ] 资讯详情内关联 DJ -> `DJDetailView`（`PUSH`）。
- [ ] 资讯详情内关联 Festival -> `LearnFestivalDetailView`（`PUSH`）。
- [ ] 资讯详情内关联 Event -> `EventDetailView`（`PUSH`）。
- [ ] 资讯详情作者点击 -> `UserProfileView`（`PUSH`，`NavigationLink`）。
- [ ] 评论用户点击 -> `UserProfileView`（`PUSH`，`NavigationLink`）。

### 2.6 DJ（DJsModuleView + DJDetailView）
- [ ] 搜索按钮 -> `DiscoverFullScreenSearchInputView(domain: .djs)`（`PUSH`）。
- [ ] 热门 DJ 卡点击 -> `DJDetailView`（`PUSH`）。
- [ ] 榜单卡点击 -> `RankingBoardDetailView`（`PUSH`，本地 `navigationDestination`）。
- [ ] 浮动 `+`（导入 DJ） -> 导入页（`PUSH`，本地 `navigationDestination`）。
- [ ] DJ 详情内编辑入口 -> DJ 编辑页（`PUSH`，本地 `navigationDestination`）。
- [ ] DJ 详情内 Spotify 导入入口 -> Spotify 导入页（`PUSH`，本地 `navigationDestination`）。
- [ ] DJ 详情内贡献者点击 -> `UserProfileView`（`PUSH`，本地 `navigationDestination`）。
- [ ] DJ 详情内相关资讯 -> `DiscoverNewsDetailView`（`PUSH`）。
- [ ] DJ 详情内相关活动 -> `EventDetailView`（`PUSH`）。
- [ ] DJ 详情内 Sets 列表 -> `DJSetDetailView`（`PUSH`，`NavigationLink`）。
- [ ] DJ 详情内 Ratings 列表 -> `CircleRatingUnitDetailView`（`PUSH`，`NavigationLink`）。

### 2.7 Sets（SetsModuleView + DJSetDetailView）
- [ ] 搜索按钮 -> `DiscoverFullScreenSearchInputView(domain: .sets)`（`PUSH`）。
- [ ] 发布按钮 -> `DJSetEditorView(mode: .create)`（`PUSH`）。
- [ ] Set 卡片点击 -> `DJSetDetailView`（`PUSH`）。
- [ ] Set 详情内关联活动点击 -> `EventDetailView`（`PUSH`）。
- [ ] Set 详情编辑按钮 -> `DJSetEditorView(mode: .edit)`（`PUSH`）。
- [ ] Set 详情编辑 Tracklist -> `TracklistEditorView`（`PUSH`，本地 `navigationDestination`）。
- [ ] Set 详情选择 Tracklist -> `TracklistSelectorSheet`（名称是 Sheet，承载为 `PUSH`）。
- [ ] Set 详情上传 Tracklist -> `UploadTracklistSheet`（名称是 Sheet，承载为 `PUSH`）。
- [ ] Set 详情艺人点击 -> `DJDetailView`（`PUSH`，且包在 `DiscoverCoordinatorView` 内）。
- [ ] Set 详情贡献者点击 -> `UserProfileView`（`PUSH`）。
- [ ] Set 详情评论用户点击 -> `UserProfileView`（`PUSH`）。
- [ ] Set 播放器耳机按钮 -> 音频模式 `DJSetDetailView(playbackMode: .audioOnly)`（`FULL`）。
- [ ] Set 编辑页活动绑定入口 -> `SetEventBindingSheet`（名称是 Sheet，承载为 `PUSH`）。

### 2.8 Wiki/Learn（LearnModuleView）
- [ ] 搜索按钮（labels/festivals）-> `DiscoverFullScreenSearchInputView(domain: .wiki)`（`PUSH`）。
- [ ] 厂牌卡点击 -> `LearnLabelDetailView`（`PUSH`）。
- [ ] 电音节卡点击 -> `LearnFestivalDetailView`（`PUSH`）。
- [ ] 新增电音节 -> `LearnFestivalEditorView(mode: .create)`（`PUSH`）。
- [ ] 电音节详情编辑 -> `LearnFestivalEditorView(mode: .edit)`（`PUSH`）。
- [ ] 厂牌详情创始人 DJ 点击 -> `DJDetailView`（`PUSH`）。
- [ ] 厂牌/电音节图片预览 -> `LearnLabelImagePreviewView`（`PUSH`，本地 `navigationDestination`）。
- [ ] 榜单详情（RankingBoardDetailView）点击 DJ -> `DJDetailView`（`PUSH`，包裹 `DiscoverCoordinatorView`）。
- [ ] 榜单详情点击 Festival -> `LearnFestivalDetailView`（`PUSH`，包裹 `DiscoverCoordinatorView`）。
- [ ] Festival 榜单详情页点击某 Festival -> Festival 详情（`PUSH`，包裹 `DiscoverCoordinatorView`）。
- [ ] Festival 详情内发布新活动 -> `EventEditorView(mode: .create)`（`PUSH`）。
- [ ] Festival 详情内关联活动 -> `EventDetailView`（`PUSH`）。
- [ ] Festival 详情内关联资讯 -> `DiscoverNewsDetailView`（`PUSH`）。

### 2.9 Discover 搜索总链路（SearchInput -> SearchResults）
- [ ] Events 搜索结果 -> Event 详情（`PUSH`）。
- [ ] News 搜索结果 -> News 详情（`PUSH`）。
- [ ] DJs 搜索结果 -> DJ 详情（`PUSH`）。
- [ ] DJs 搜索结果中的榜单 -> 榜单详情（`PUSH`，本地 `navigationDestination`）。
- [ ] Sets 搜索结果 -> Set 详情（`PUSH`）。
- [ ] Wiki 搜索结果（Labels）-> Label 详情（`PUSH`）。
- [ ] Wiki 搜索结果（Festivals）-> Festival 详情（`PUSH`）。

---

## 3. Circle 模块点击路径

### 3.1 Feed
- [ ] Feed 点击作者 -> `UserProfileView`（`PUSH`）。
- [ ] Feed 点击卡片 -> `PostDetailView`（`PUSH`）。
- [ ] Feed 点击编辑 -> `ComposePostView(mode: .edit)`（`PUSH`）。
- [ ] Feed 右下角 `+` -> `ComposePostView(mode: .create)`（`PUSH`）。

### 3.2 PostDetail / PostCard 局部跳转
- [ ] PostDetail 点击作者/评论作者 -> `UserProfileView`（`PUSH`，本地 `navigationDestination`）。
- [ ] PostCard 点击定位标签 -> `PostLocationMapView`（`FULL`）。
- [ ] PostCard 点击媒体 -> `PostMediaBrowserView`（`FULL`）。

### 3.3 ID（CircleIDHub / CircleIDDetail / CircleIDComposer）
- [ ] ID Hub 发布按钮 -> `CircleIDComposerSheet`（名称是 Sheet，承载为 `PUSH`）。
- [ ] ID Hub 中 event 卡点击 -> `EventDetailView`（`PUSH`）。
- [ ] ID Hub 中 DJ 点击 -> `DJDetailView`（`PUSH`）。
- [ ] ID Hub 中贡献者点击 -> `UserProfileView`（`PUSH`）。
- [ ] ID Hub 评论按钮 -> `CircleIDDetailView`（`PUSH`，本地 `navigationDestination`）。
- [ ] ID 详情里 DJ/Event/用户点击：先 dismiss 当前页，再 `circlePush(...)` 到目标（`PUSH`，验证返回链路正确）。
- [ ] 发布 ID 流程里“选择活动” -> `CircleIDEventPickerSheet`（名称是 Sheet，承载为 `PUSH`）。
- [ ] 发布 ID 流程里“选择 DJ” -> `CircleIDDJPickerSheet`（名称是 Sheet，承载为 `PUSH`）。

### 3.4 Squads
- [ ] 小队广场卡片点击 -> `SquadProfileView`（`PUSH`）。
- [ ] 创建小队入口 -> `CreateSquadView`（`PUSH`，本地 `navigationDestination`）。
- [ ] 创建完成自动进入 `SquadProfileView`（`PUSH`）。

### 3.5 SquadProfile
- [ ] 进入小队后跳聊天 -> `ChatView`（`PUSH`，本地 `navigationDestination`）。
- [ ] 成员头像点击 -> `UserProfileView`（`PUSH`，本地 `navigationDestination`）。
- [ ] 管理按钮 -> `SquadManageSheet`（名称是 Sheet，承载为 `PUSH`，本地 `navigationDestination`）。

### 3.6 Rating
- [ ] 打分主页“从活动导入” -> `CreateRatingEventFromEventSheet`（名称是 Sheet，承载为 `PUSH`）。
- [ ] 打分主页“发布事件” -> `CreateRatingEventSheet`（名称是 Sheet，承载为 `PUSH`）。
- [ ] 打分事件卡点击 -> `CircleRatingEventDetailView`（`PUSH`）。
- [ ] 打分事件详情内“进入对应活动” -> `EventDetailView`（`PUSH`）。
- [ ] 打分事件详情内新增打分单位 -> `CreateRatingUnitSheet`（名称是 Sheet，承载为 `PUSH`）。

---

## 4. Messages 模块点击路径

### 4.1 消息主页
- [ ] 会话列表点击 -> `ChatView`（`PUSH`）。
- [ ] 顶部分类（系统提醒分类）点击 -> `MessageAlertDetailView`（`PUSH`）。

### 4.2 ChatView
- [ ] 私聊右上角头像按钮 -> `UserProfileView`（`PUSH`）。
- [ ] 群聊右上角 `...` -> `messagesPresent(.squadProfile)`（目前承载为 `PUSH` 的 modal 通道）。
- [ ] 消息气泡里的头像点击 -> `UserProfileView`（`PUSH`）。

### 4.3 MessageAlertDetailView
- [ ] 通知目标 `user` -> `UserProfileView`（`PUSH`）。
- [ ] 通知目标 `squad` -> `messagesPresent(.squadProfile)`（承载为 `PUSH` 的 modal 通道）。

---

## 5. Profile 模块点击路径

### 5.1 ProfileView（我的）
- [ ] 头像点击 -> `AvatarFullscreenView`（`PUSH`）。
- [ ] 粉丝/关注/好友 -> `FollowListView`（`PUSH`）。
- [ ] 我的打卡 -> `MyCheckinsView`（`PUSH`）。
- [ ] 工具栏编辑 -> `EditProfileView`（`PUSH`）。
- [ ] 工具栏设置 -> `SettingsView`（`PUSH`）。
- [ ] 快捷入口“我的发布” -> `MyPublishesView`（`PUSH`）。
- [ ] 快捷入口“发布活动” -> `EventEditorView(.create)`（`PUSH`）。
- [ ] 快捷入口“上传 Set” -> `DJSetEditorView(.create)`（`PUSH`）。
- [ ] 动态卡作者 -> `UserProfileView`（`PUSH`）。
- [ ] 动态卡点击 -> `PostDetailView`（`PUSH`）。

### 5.2 UserProfileView（他人）
- [ ] 粉丝/关注/好友 -> `FollowListView`（`PUSH`）。
- [ ] 私信按钮 -> `ChatView`（`PUSH`）。
- [ ] Ta 的打卡 -> `MyCheckinsView`（`PUSH`）。
- [ ] 动态卡点击 -> `PostDetailView`（`PUSH`）。

### 5.3 FollowListView
- [ ] 用户行点击 -> `UserProfileView`（`PUSH`）。

### 5.4 MyCheckinsView
- [ ] Event 打卡卡片点击 -> `EventDetailView`（`PUSH`）。
- [ ] DJ 打卡头像/条目点击 -> `DJDetailView`（`PUSH`）。

### 5.5 MyPublishesView
- [ ] Sets 页点击条目 -> `DJSetDetailView`（`PUSH`，`NavigationLink`）。
- [ ] Sets 条目滑动编辑 -> `profilePush(.editSet)`（`PUSH`）。
- [ ] Events 条目点击 -> `EventDetailView`（`PUSH`）。
- [ ] Events 条目滑动编辑 -> `profilePush(.editEvent)`（`PUSH`）。
- [ ] RatingEvent 滑动编辑 -> `RatingEventEditorSheet`（名称是 Sheet，承载为 `PUSH`）。
- [ ] RatingUnit 滑动编辑 -> `RatingUnitEditorSheet`（名称是 Sheet，承载为 `PUSH`）。

---

## 6. 跨入口页面（Search / Notifications）

### 6.1 SearchView
- [ ] 用户结果点击 -> `UserProfileView`（`PUSH`）。
- [ ] 动态作者点击 -> `UserProfileView`（`PUSH`）。
- [ ] 动态卡点击 -> `PostDetailView`（`PUSH`）。
- [ ] 小队按钮“进入/加入” -> `SquadProfileView`（`PUSH`）。

### 6.2 NotificationsView
- [ ] `user` 通知点击 -> `UserProfileView`（`PUSH`）。
- [ ] `squad` 通知点击 -> `SquadProfileView`（`PUSH`）。

---

## 7. 当前仍保留的真实 Modal 清单（必须包含在回归）

### 7.1 `.sheet`
- [ ] `EventsModuleView` -> `EventCalendarSheet`。
- [ ] `EventsModuleView` -> `EventCountryFilterSheet`。
- [ ] `EventDetailView` -> `EventCheckinSelectionSheet`。
- [ ] `EventDetailView` -> `EventVenueMapSheet`。
- [ ] `EventDetailView` -> `ActivityShareSheet`。

### 7.2 `.fullScreenCover`
- [ ] `PostCardView` -> `PostLocationMapView`。
- [ ] `PostCardView` -> `PostMediaBrowserView`。
- [ ] `ComposePostView` -> `ComposeMediaBrowserView`。
- [ ] `ComposePostView` -> `PostLocationPickerSheet`。
- [ ] `DJSetDetailView` -> 音频模式 `DJSetDetailView(playbackMode: .audioOnly)`。

---

## 8. 自动扫描索引（用于核对完整性）

### 8.1 Coordinator Push/Present 调用位点

```bash
rg -n "discoverPush\(|circlePush\(|messagesPush\(|messagesPresent\(|profilePush\(" mobile/ios/RaverMVP/RaverMVP -g '*.swift' | sort
```

### 8.2 本地导航位点

```bash
rg -n "\.navigationDestination\(|NavigationLink\(" mobile/ios/RaverMVP/RaverMVP/Features mobile/ios/RaverMVP/RaverMVP/Shared -g '*.swift' | sort
```

### 8.3 真实 Modal 位点

```bash
rg -n "\.sheet\(|\.fullScreenCover\(" mobile/ios/RaverMVP/RaverMVP -g '*.swift'
```

---

## 9. 执行建议（手工冒烟节奏）

- 第一轮：按 Tab 全链路过一遍 `PUSH` 返回行为（重点看返回是否回到正确列表位置）。
- 第二轮：只测第 7 节全部 `SHEET/FULL`（打开/关闭/取消/确认后的状态恢复）。
- 第三轮：做跨模块穿透链路：Discover -> Circle -> Profile -> Messages -> 返回。


## 10. 代码行级索引（当前仓库快照）

### 10.1 sheet/fullScreenCover 行号

```text
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift:164:        .fullScreenCover(isPresented: $isShowingLocationMap) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift:516:        .fullScreenCover(item: $selectedMedia) { selection in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/ComposePostView.swift:303:            .fullScreenCover(item: $selectedPreview) { preview in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/ComposePostView.swift:309:            .fullScreenCover(isPresented: $showLocationPicker) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:558:                .sheet(isPresented: $showEventCheckinSheet) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:581:                .sheet(item: $venueMapContext) { context in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:3207:            .sheet(isPresented: $showShareSheet) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:424:        .fullScreenCover(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventsModuleView.swift:101:        .sheet(isPresented: $showCalendar) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventsModuleView.swift:114:        .sheet(isPresented: $showCountryFilter) {
```

### 10.2 coordinator push/present 行号

```text
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:136:                            discoverPush(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:177:                                    discoverPush(.djDetail(djID: tapped.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:3038:                    discoverPush(.newsDetail(article: article))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:3169:                    discoverPush(.eventDetail(eventID: event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:1580:                    discoverPush(.eventEdit(event: event))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:813:                    discoverPush(.newsDetail(article: article))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventsModuleView.swift:109:                    discoverPush(.eventDetail(eventID: event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventsModuleView.swift:246:                    discoverPush(.eventCreate)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventsModuleView.swift:704:        discoverPush(.eventDetail(eventID: event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/RecommendEventsModuleView.swift:200:                discoverPush(.eventDetail(eventID: event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:1460:                    discoverPush(.djDetail(djID: founderDj.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:151:                discoverPush(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:174:                    discoverPush(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2319:                    discoverPush(.learnFestivalEdit(festival: currentFestival))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2513:                discoverPush(.eventCreate)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2541:                            discoverPush(.eventDetail(eventID: event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2553:                            discoverPush(.eventDetail(eventID: event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2602:                    discoverPush(.newsDetail(article: article))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:340:                    discoverPush(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:374:                    discoverPush(.learnFestivalCreate)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:434:                                discoverPush(.labelDetail(label: label))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:469:                                        discoverPush(.festivalDetail(festival: festival))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift:217:                            discoverPush(.djDetail(djID: dj.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift:237:                            discoverPush(.djDetail(djID: id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift:252:                            discoverPush(.festivalDetail(festival: brand))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift:277:                            discoverPush(.eventDetail(eventID: event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift:292:                            discoverPush(.eventDetail(eventID: id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/NewsModuleView.swift:119:                            discoverPush(.newsPublish)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/NewsModuleView.swift:38:                                    discoverPush(.newsDetail(article: article))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/NewsModuleView.swift:96:                            discoverPush(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift:223:                                    discoverPush(.eventDetail(eventID: event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift:305:                                    discoverPush(.newsDetail(article: article))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift:387:                                                discoverPush(.djDetail(djID: dj.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift:489:                                    discoverPush(.setDetail(setID: set.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift:620:                                discoverPush(.labelDetail(label: label))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift:645:                                discoverPush(.festivalDetail(festival: festival))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:119:                        discoverPush(.setCreate)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:46:                                    discoverPush(.setDetail(setID: set.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:573:                discoverPush(.eventDetail(eventID: relatedEvent.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:621:                    discoverPush(.setEdit(set: set))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:75:                        discoverPush(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift:54:                                    circlePush(.userProfile(post.author.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift:60:                                        circlePush(.postEdit(post))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift:71:                                circlePush(.postDetail(post))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift:99:                circlePush(.postCreate)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:2032:                                circlePush(.squadProfile(squad.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:2058:                circlePush(.squadProfile(conversation.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:2340:                        circlePush(.ratingEventImportFromEvent)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:2351:                        circlePush(.ratingEventCreate)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:2393:                            circlePush(.ratingEventDetail(event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:2601:                circlePush(.eventDetail(sourceEventID))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:2703:                        circlePush(.ratingUnitCreate(eventID: eventID))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:366:                    circlePush(.idCreate)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:452:                    circlePush(.eventDetail(event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:486:                            circlePush(.djDetail(dj.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:538:                    circlePush(.userProfile(entry.contributor.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:970:            circlePush(route)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift:134:                    messagesPush(.userProfile(message.sender.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift:152:                    messagesPush(.userProfile(message.sender.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift:170:                    messagesPush(.userProfile(message.sender.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift:187:                    messagesPush(.userProfile(message.sender.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift:31:                        messagesPush(.userProfile(peer.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatView.swift:41:                        messagesPresent(.squadProfile(conversation.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift:609:                        messagesPush(.conversation(conversation))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift:661:                messagesPush(.alertCategory(category))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift:918:                messagesPush(.userProfile(actor.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift:921:            messagesPresent(.squadProfile(target.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsView.swift:101:            profilePush(.squadProfile(target.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsView.swift:98:                profilePush(.userProfile(actor.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/FollowListView.swift:50:                        profilePush(.userProfile(user.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:111:                    profilePush(.myPublishes)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:118:                    profilePush(.publishEvent)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:125:                    profilePush(.uploadSet)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:199:                                profilePush(.userProfile(post.author.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:207:                    profilePush(.postDetail(post))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:22:                                profilePush(.avatarFullscreen)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:25:                                profilePush(.followList(userID: currentUserID, kind: .followers))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:28:                                profilePush(.followList(userID: currentUserID, kind: .following))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:31:                                profilePush(.followList(userID: currentUserID, kind: .friends))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:40:                            profilePush(.myCheckins(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:74:                        profilePush(.editProfile)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift:83:                        profilePush(.settings)
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift:115:                                profilePush(.postDetail(post))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift:38:                                profilePush(.followList(userID: profile.id, kind: .followers))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift:45:                                profilePush(.followList(userID: profile.id, kind: .following))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift:51:                            profilePush(.followList(userID: profile.id, kind: .friends))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift:65:                                            profilePush(.conversation(conversation))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift:83:                        profilePush(.myCheckins(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift:1152:                profilePush(.djDetail(djID))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift:737:                            profilePush(.eventDetail(event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift:774:                                    profilePush(.djDetail(resolvedID))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift:845:                        profilePush(.eventDetail(event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift:990:                profilePush(.djDetail(resolvedID))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift:178:                                    profilePush(.editSet(editableSet))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift:200:                        profilePush(.eventDetail(event.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift:221:                                    profilePush(.editEvent(editableEvent))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift:259:                                            profilePush(.editRatingEvent(editableEvent))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Publishes/MyPublishesView.swift:294:                                            profilePush(.editRatingUnit(editableUnit))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchView.swift:127:                            profilePush(.userProfile(user.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchView.swift:159:                                    profilePush(.userProfile(post.author.id))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchView.swift:166:                                profilePush(.postDetail(post))
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchView.swift:201:                            profilePush(.squadProfile(squad.id))
```

### 10.3 navigationDestination / NavigationLink 行号

```text
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Circle/Coordinator/CircleCoordinator.swift:52:                .navigationDestination(for: CircleRoute.self) { route in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Coordinator/DiscoverCoordinator.swift:16:                .navigationDestination(for: DiscoverRoute.self) { route in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:2109:        .navigationDestination(isPresented: $showDJEditSheet) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:2112:        .navigationDestination(isPresented: $showSpotifyImportSheet) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:2115:        .navigationDestination(item: $selectedContributorUser) { user in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:243:            .navigationDestination(item: $selectedBoardForDetail) { board in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:251:            .navigationDestination(isPresented: $showDJImportSheet) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:3384:        .navigationDestination(isPresented: $showRoutePlanner) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:597:        .navigationDestination(
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift:1471:            .navigationDestination(isPresented: $showLineupImportEditor) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift:1474:            .navigationDestination(isPresented: $showLocationPicker) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:111:            .navigationDestination(item: $selectedFestivalRankingBoard) { board in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:1359:        .navigationDestination(item: $previewImage) { item in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:1923:        .navigationDestination(item: $selectedFestivalForDetail) { festival in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2272:        .navigationDestination(item: $previewImage) { item in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:2283:        .navigationDestination(item: $selectedContributorUser) { user in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:4142:        .navigationDestination(item: $selectedDJID) { djID in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift:4148:        .navigationDestination(item: $selectedFestival) { festival in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Search/Views/DiscoverSearchViews.swift:439:        .navigationDestination(item: $selectedBoardForDetail) { board in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:3454:            .navigationDestination(isPresented: $showEventBindingSheet) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:357:                .navigationDestination(isPresented: $showTrackEditor) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:366:                .navigationDestination(isPresented: $showTracklistSelector) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:377:                .navigationDestination(isPresented: $showTracklistUpload) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:413:        .navigationDestination(item: $selectedArtistDJ) { dj in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:418:        .navigationDestination(item: $selectedContributor) { contributor in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift:421:        .navigationDestination(item: $selectedCommentUser) { user in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift:168:        .navigationDestination(item: $selectedUserForProfile) { user in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:1443:            .navigationDestination(isPresented: $showEventPicker) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:1448:            .navigationDestination(isPresented: $showDJPicker) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:2055:        .navigationDestination(isPresented: $showCreateSquad) {
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift:409:        .navigationDestination(item: $selectedDetailRoute) { route in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/Coordinator/MessagesCoordinator.swift:55:                .navigationDestination(for: MessagesRoute.self) { route in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/Coordinator/MessagesCoordinator.swift:65:        .navigationDestination(item: $presentedModal) { route in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/Coordinator/ProfileCoordinator.swift:50:                .navigationDestination(for: ProfileRoute.self) { route in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift:109:        .navigationDestination(item: $pushedConversation) { conversation in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift:112:        .navigationDestination(item: $selectedMember) { member in
/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift:115:        .navigationDestination(isPresented: $showManageSheet) {
```
