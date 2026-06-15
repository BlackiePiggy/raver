# RaveHub Flutter 跨端迁移进度追踪

> **项目目标：** 将 iOS 原生 App（SwiftUI + UIKit, ~141K LOC）像素级一比一复刻为 Flutter 跨平台应用（iOS + Android + HarmonyOS）  
> **关键约束：** 移除全部 IM/私聊功能 | 后端零修改 | 多 Agent 并行开发架构  
> **最后更新：** 2026-06-15（iOS 端像素级一致性全量审查 — 共修复 7 处差异：[1] RaverFloatingTabBar: 高度 64→66、icon 24→16、label 10→11pt、搜索按钮 48→56px 含双阴影、badge 样式对齐、selection indicator 改用 SpringSimulation(response=0.26, dampingFraction=0.86) 弹簧物理动画；[2] RaverScrollableTabPager: indicatorWeight 2.5→2.6、label 14→17pt；[3] EventDetailScreen: hero 高度 280→360、4 色渐变停止点修正、标题 22→28pt、改 NestedScrollView + SliverPersistentHeader、7-Tab 含 per-tab 颜色动态切换（Info/Lineup/Timetable/News/Posts/Ratings/Sets）、action bar 改胶囊按钮 borderRadius 22；[4] ProfileHeader: avatar 88→84pt 移除外框描边；[5] ProfileStatsRow: 3列→4列 Posts|Followers|Following|Friends；[6] ProfileMeScreen: SliverAppBar 高度 120→250、3色渐变+径向高光叠加、segment 改 Published/Saves/Likes；[7] LoginScreen: fillColor 0.08→0.14、边框 radius 12→14、PrimaryButton 48→54pt/radius 24→30、入场动画 800ms easeOut→300ms fastLinearToSlowEaseIn；[8] ProfileSkeleton: SkeletonCircle 88→84、stat columns 3→4；[9] map_view.dart: 移除 flutter_map v7 废弃 API subdomains/bool retinaMode；[10] inbox_screen_test: LoadPhase.loading() 版本修正）

---

## 总体进度概览

| 阶段 | 描述 | 状态 | 进度 |
|------|------|------|------|
| Phase 0 | 基础设施搭建 | **已完成** | ██████████ 100% |
| Phase 1 | Discover 只读浏览 | **已完成** | ██████████ 100% |
| Phase 2 | Circle + Inbox | **已完成** | ██████████ 100% |
| Phase 3 | Profile + Auth 完善 | **已完成** | ██████████ 100% |
| Phase 4 | 内容创建 + 编辑 | **已完成** | ██████████ 100% |
| Phase 5 | 平台打磨 + HarmonyOS | **已完成** | ██████████ 100% |

**当前代码统计：** ~285 个 Dart 文件 | ~52,000 LOC | 7 core 包 + 5 feature 包 + 1 宿主 App

---

## Phase 0：基础设施搭建 ✅

### 0.1 工作空间与项目结构

- [x] Melos 工作空间初始化 (`melos.yaml`)
- [x] 全部 13 个包的 `pubspec.yaml` 配置
- [x] 包依赖关系验证（单向无环）
- [x] 目录结构创建

### 0.2 raver_core（配置 / 错误 / 工具）— 536 LOC

- [x] `AppConfig` — 运行模式(mock/live)、BFF URL、OSS 配置、默认头像 FNV-1a 选择
- [x] `RegionalCompliance` — 区域合规配置
- [x] `ServiceError` — sealed class 错误体系（对齐 iOS ServiceError enum）
- [x] `LoadPhase` — sealed class 加载状态（idle/loading/success/empty/failure/offline）
- [x] `DateFormatting` — 日期格式化扩展（相对时间、活动日期、紧凑格式）
- [x] barrel export (`raver_core.dart`)

### 0.3 raver_models（共享领域模型）— 1,364 LOC / 77 模型

- [x] `user.dart` — Session, UserSummary, UserProfile, AuthSessionItem（已转为 plain Dart class，移除 freezed）
- [x] `event.dart` — WebEvent + 11 子模型（已转为 plain Dart class，移除 freezed，含手写 fromJson/toJson/copyWith/==）
- [x] `dj.dart` — WebDJ, DJHonor, DJExactMatch
- [x] `dj_set.dart` — WebDJSet, Track, Tracklist
- [x] `post.dart` — Post, Comment, FeedPage
- [x] `squad.dart` — SquadProfile, SquadMember, OfflineActivity
- [x] `notification.dart` — AppNotification, UnreadCount
- [x] `checkin.dart` — WebCheckin, CheckinOverview
- [x] `rating.dart` — RatingEvent, RatingUnit, RatingComment
- [x] `news.dart` — NewsArticle, NewsPage
- [x] `genre.dart` — LearnGenreNode, GenreSunburstNode
- [x] `brand.dart` — LearnFestival, LearnLabel, RankingBoard
- [x] `search.dart` — GlobalSearchItem, GlobalSearchResponse
- [x] `share.dart` — ShareTarget, ShareLinkPayload
- [x] `content_submission.dart` — ContentSubmission, ContentSubmissionDetail
- [x] `virtual_asset.dart` — VirtualAssetDefinition, UserAppearance
- [x] `pagination.dart` — BFFPagination, BFFListPage\<T\>
- [x] `upload.dart` — UploadMediaResponse
- [x] `enforcement.dart` — AccountEnforcement, AccountQualification
- [x] **全部模型已转为 plain Dart class（无 build_runner 依赖）** — 19 文件 80+ 类，手写 fromJson/toJson/copyWith/==

### 0.4 raver_network（网络层）— 651 LOC

- [x] `DioClientFactory` — 配置化 Dio 客户端创建
- [x] `AuthInterceptor` — JWT Bearer 注入 + 401 自动刷新 + auth 端点跳过
- [x] `BffEnvelopeInterceptor` — BFF 信封解包 + 403 enforcement 处理
- [x] `LanguageInterceptor` — Accept-Language 头注入
- [x] `LoggingInterceptor` — Debug 模式日志
- [x] `MultipartUploadService` — 图片/视频 multipart 上传
- [x] `OssUrlProcessor` — OSS 图片 URL 处理（resize/quality/webp）

### 0.5 raver_auth（认证层）— 212 LOC

- [x] `SessionTokenStore` — flutter_secure_storage 封装（对齐 iOS Keychain）
- [x] `AuthRefreshGate` — Completer 并发刷新去重（对齐 iOS AppAuthRefreshGate）
- [x] `AuthState` — AuthStatus enum + AuthState class

### 0.6 raver_i18n（三语国际化）— 511 LOC

- [x] `l.dart` — `lt(zh, en, ja)` 和 `ll(zhKey)` 函数
- [x] `LanguagePreference` — AppLanguage enum + 系统 locale 解析
- [x] `translations_zh.dart` — 中文翻译表（92 条目）
- [x] `translations_en.dart` — 英文翻译表（92 条目）
- [x] `translations_ja.dart` — 日文翻译表（92 条目）

### 0.7 raver_design_system（设计系统）— 3,616 LOC

#### 主题 Token

- [x] `raver_colors.dart` — 全部颜色 Token（完整移植自 Theme.swift light/dark）
- [x] `raver_theme.dart` — ThemeExtension\<RaverThemeData\> light/dark 主题
- [x] `raver_typography.dart` — Futura-CondensedExtraBold + 系统 rounded 字体
- [x] `raver_shadows.dart` — 双阴影系统（primary + accent）
- [x] `raver_motion.dart` — 动画时长、曲线常量

#### 共享组件

- [x] `RaverFloatingTabBar` — 毛玻璃胶囊 TabBar（动画选中指示器、搜索按钮、未读 badge）
- [x] `RaverScrollableTabPager` — 横向滚动标签页 + 滑动切页
- [x] `RaverNavigationChrome` — 统一导航栏 chrome
- [x] `GlassCard` — 毛玻璃卡片
- [x] `PrimaryButton` — 渐变主按钮
- [x] `RaverSegmentedControl` — 分段选择器
- [x] `RemoteCoverImage` — 带 OSS 处理的远程图片组件
- [x] `SkeletonViews` — 6 种骨架屏变体（列表行、卡片、网格、详情头、全屏、自定义）
- [x] `LoadPhaseBuilder` — LoadPhase → Widget 映射器
- [x] `EmptyStateView` — 空状态视图
- [x] `ErrorStateView` — 错误状态视图
- [x] `ToastBanner` — 操作反馈 Toast
- [x] `PostCardView` — 共享动态卡片（Feed/Profile/Circle 通用）
- [x] `ReportSheet` — 举报弹窗
- [x] `MediaPreviewOverlay` — 媒体预览全屏覆盖层

### 0.8 raver_platform（平台桥接）— 690 LOC

- [x] `PermissionService` — 运行时权限请求
- [x] `LocationService` — GPS 定位（对齐 AppLocationProvider）
- [x] `MapLauncher` — 外部地图 App 启动（Apple Maps / Google Maps / Petal Maps）
- [x] `RaverMapView` — 平台感知内联地图（iOS: apple_maps_flutter/MapKit、Android/HarmonyOS: flutter_map/OpenStreetMap）
- [x] `ShareService` — 系统分享
- [x] `CalendarService` — 日历事件添加
- [x] `MediaPickerService` — 相册/相机选择
- [x] `PushNotificationService` — FCM/HarmonyOS Push Kit 抽象（token 获取 + 前台消息监听 + 点击监听）
- [x] `HarmonyPushAdapter` — HarmonyOS Push Kit 独立适配器（token 获取 + topic 订阅/退订 + token 删除）

### 0.9 宿主 App（App Shell）— 1,412 LOC

- [x] `main.dart` — 入口 ProviderScope
- [x] `app.dart` — MaterialApp.router + 主题切换
- [x] `bootstrap.dart` — 会话恢复、推送权限、偏好设置初始化
- [x] `app_router.dart` — GoRouter + StatefulShellRoute（4 Tab）+ 全部 feature 包真实路由接入（buildXxxRoutes + buildXxxDetailRoutes，_withParentKey 辅助函数）+ DeepLinkHandler redirect 集成
- [x] `route_guards.dart` — 登录拦截守卫（15 个受保护路径前缀，auth-only 3 路径）
- [x] `deep_link_handler.dart` — `raver://` + `ravehub.top` URL 映射（11 种资源 + search）
- [x] `deep_link_config.dart` — 平台深度链接配置文档（Android/iOS/HarmonyOS）
- [x] `app_providers.dart` — 顶层 Riverpod Provider
- [x] `app_state_notifier.dart` — 全局状态（session、语言、主题、未读数）
- [x] `raver_shell_scaffold.dart` — 4-Tab 壳 + 浮动 TabBar + 搜索按钮

### 0.10 feature_auth（认证功能）— 2,539 LOC

- [x] `auth_routes.dart` — 路由注册
- [x] `LoginScreen` — 暗色渐变背景 + 邮箱/短信/密码三模式 + 国家码选择 + 倒计时 + 条款勾选（~898 LOC）
- [x] `RegisterScreen` — 昵称可用性检查 + 密码强度指示器（~563 LOC）
- [x] `SmsVerificationScreen` — 6 位自动前进输入框（~448 LOC）
- [x] `LoginNotifier` — 登录状态管理（~313 LOC）
- [x] `RegisterNotifier` — 注册状态管理（~272 LOC）

### 0.11 Feature 模块路由骨架（占位）

- [x] `feature_discover` — DiscoverHomeScreen（9 子标签 Pager）+ 14 个占位 Screen + 路由注册
- [x] `feature_circle` — CircleHomeScreen（4 子标签 Pager）+ 8 个占位 Screen + 路由注册
- [x] `feature_inbox` — InboxHomeScreen（5 板块入口）+ 5 个占位 Screen + 路由注册
- [x] `feature_profile` — 9 个占位 Screen + 路由注册（22+ 路由）

---

## Phase 1：Discover 只读浏览 ✅（90%）

### 1.1 Discover 基础

- [x] `DiscoverHomeScreen` — 9 子标签 RaverScrollableTabPager 完整实现（Recommend / Events / News / DJs / Sets / Genres / Organizers / Labels / Rankings）+ 搜索按钮入口
- [x] 子标签动态加载与内存管理
- [x] 三语 i18n 标签标题（lt() 函数）

### 1.2 推荐（Recommend） ✅

- [x] `RecommendScreen` — 推荐活动卡片轮播（全幅水平 PageView + 视差缩放 + 页码指示器）
- [x] `RecommendViewModel` — 数据加载（后端推荐优先 + legacy 随机采样回退 + 日内缓存）
- [x] `EventsApiService` — `GET /v1/events/recommendations` + `GET /v1/events`
- [x] 骨架屏加载态 + 刷新中横幅 + 错误重试横幅

### 1.3 活动（Events）— iOS ~36.5K LOC 对应

#### 列表 ✅

- [x] `EventsListScreen` — 活动列表（8 种活动类型筛选 pill + 分页 + 下拉刷新 + 上拉加载更多）
- [x] `EventFilterSheet` — 城市/日期/类型/厂牌 筛选（高级筛选面板）
- [x] `EventCard` — 活动列表卡片组件（封面图/类型标签/日期/地点/收藏数/签到数）
- [x] `EventsListViewModel` — 分页加载 + EventTypeFilter 筛选状态（ChangeNotifier + LoadPhase）
- [x] `EventsApiService` — `GET /v1/events`（支持 page/limit/search/eventType/status/wikiFestivalId）
- [x] `EventsRepository` — 仓库层封装
- [x] 下拉刷新 + 上拉加载更多

#### 详情 ✅

- [x] `EventDetailScreen` — 详情主页（SliverAppBar Hero Header + 3-Tab 切换：详情/阵容/时间表）
- [x] `EventInfoSection` — 基本信息（时间/地点/时区/票价/描述/阵容海报）
- [x] `EventScheduleSection` — 时间表视图（按 stage 分组 + 时间段卡片）
- [x] `EventLineupSection` — 阵容列表（DJ 头像 + B2B 标注 + 点击跳转 DJ 详情）
- [x] `EventLiveDiscussionSection` — 实时讨论（30s 轮询 + 评论列表 + 发送输入框）
- [x] `EventCheckInSection` — 签到功能（签到按钮 + 已签到用户头像列表）
- [x] `EventRouteSection` — 路线规划（地址显示 + 导航按钮调用 MapLauncher）
- [x] `EventMapSection` — 场馆地图（静态预览 + 全屏查看）
- [x] `EventShareSection` — 分享（调用 ShareService 分享活动链接）
- [x] `EventDetailViewModel` — 详情数据加载（event + lineup + timetable 并行）+ 收藏切换
- [x] `EventsApiService` (详情) — `GET /v1/events/:id`, `GET /v1/events/:id/lineup`, `GET /v1/events/:id/timetable`, `GET /v1/events/:id/favorite`, `POST /v1/events/:id/favorite`, `DELETE /v1/events/:id/favorite`
- [x] 收藏/取消收藏活动
- [x] 骨架屏加载态（EventDetailSkeleton）

#### 编辑 & 上传（Phase 4）

- [ ] `EventEditorScreen` — 活动信息编辑
- [ ] `EventUploadFlowScreen` — 多步向导（基本信息→海报→阵容→时间表→票务→提交）
- [ ] `EventRoutePlannerScreen` — 路线规划器
- [ ] `EventScheduleCanvas` — 时间表绘制器（CustomPainter）
- [x] Lineup AI 图片识别导入 — `EventLineupImportScreen`

### 1.4 新闻（News）

- [x] `NewsListScreen` — 新闻列表（分类筛选 pill + 分页 + 下拉刷新）
- [x] `NewsDetailScreen` — 新闻详情（富文本 Markdown 渲染 + 封面 + 作者）
- [x] `NewsCard` — 新闻卡片组件（封面/标题/分类 badge/来源/评论数）
- [x] `NewsViewModel` — 分页加载（NewsListNotifier + NewsDetailNotifier + Riverpod）
- [x] `NewsApi` — `GET /v1/news`, `GET /v1/news/:id`
- [ ] 骨架屏加载态

### 1.5 DJ

#### 列表

- [x] `DjsListScreen` — Spotlight 轮播 + 随机热门 DJ 列表
- [x] `DjSpotlightCarousel` — 聚光灯轮播（PageView + 渐变叠加 + 流派/粉丝数）
- [x] `DjCard` — DJ 列表卡片（头像/名称/国家/粉丝数）
- [x] `DjsViewModel` — 分页加载 + 排序（DjsListNotifier + Riverpod）
- [x] `DjApi` — `GET /v1/djs`, `GET /v1/djs/spotlight`

#### 详情

- [x] `DjDetailScreen` — DJ 主页（Hero Header + Intro/Sets 标签页）
- [x] `DjBioSection` — 个人简介 + 荣誉 + 流派标签 + 社交链接
- [ ] `DjEventsSection` — 相关活动列表
- [x] `DjSetsSection` — 相关 Set 列表
- [x] `DjDetailViewModel` — 详情数据加载（DjDetailNotifier + Riverpod）
- [x] `DjApi` (详情) — `GET /v1/djs/:id`
- [x] 关注/取消关注 DJ — `POST /v1/djs/:id/follow`
- [ ] 骨架屏加载态

#### 导入 & 编辑（Phase 4）

- [x] `DjImportScreen` — Spotify/Discogs/手动导入（三 Tab 切换）
- [ ] `DjUploadFlowScreen` — DJ 信息上传向导
- [x] `DjEditorScreen` — DJ 信息编辑（头像上传/名称/简介/国籍/流派标签/社交链接）
- [x] `DjEditorViewModel` — DJ 编辑状态管理（ChangeNotifier, 加载/字段更新/头像上传/保存）
- [x] `DjApi` 写方法 — `POST /v1/djs`, `PUT /v1/djs/:id`, `POST /v1/upload/djs/avatar`, `POST /v1/djs/import/spotify`, `POST /v1/djs/import/discogs`

### 1.6 Sets（DJ Sets）

#### 列表 & 详情

- [x] `SetsListScreen` — Set 2 列网格列表（排序切换 + 分页 + 下拉刷新）
- [x] `SetDetailScreen` — Set 详情（封面/Tracklist/视频播放/评论区）
- [x] `TracklistView` — Tracklist 可折叠展示组件
- [x] `SetVideoPlayer` — 视频播放器（video_player + chewie）
- [x] `SetCommentsSection` — 评论列表 + 发表评论
- [x] `SetsViewModel` — 分页加载（SetsListNotifier + SetDetailNotifier + Riverpod）
- [x] `SetApi` — `GET /v1/sets`, `GET /v1/sets/:id`, `GET /v1/sets/:id/comments`, `POST /v1/sets/:id/comments`
- [ ] 骨架屏加载态

#### 编辑（Phase 4）

- [x] `SetEditorScreen` — Set 信息编辑（标题/描述/日期/关联DJ&活动/音视频上传/曲目预览）
- [x] `TracklistEditorScreen` — Tracklist 逐曲编辑/添加/删除/排序（ReorderableListView + FAB）
- [x] `SetEditorViewModel` — Set 编辑状态管理（ChangeNotifier, 加载/字段更新/音视频上传/曲目管理/保存）
- [x] `SetApi` 写方法 — `POST /v1/sets`, `PUT /v1/sets/:id`, `POST /v1/upload/sets/audio`, `POST /v1/upload/sets/video`

### 1.7 流派 Sunburst 可视化（Genres） ✅

- [x] `GenresRootScreen` — 流派入口页（ConsumerStatefulWidget + AnimatedBuilder）
- [x] `GenreSunburstCanvas` — CustomPainter 日芒图绘制（集成在 GenresRootScreen）
- [x] `GenreSunburstPainter` — 极坐标渲染 + 命中测试
- [x] `GenreDetailScreen` — 流派详情页（描述/起源/年代/BPM/代表曲目/子流派）
- [x] 层级切换扇区展开动画（AnimationController + CurvedAnimation, 1.2s easeOutCubic）
- [x] `GenreApi` — `GET /v1/learn/genres`, `GET /v1/learn/genres/:id`
- [x] `LearnGenreThemePalette` — 20 流派颜色映射 + 10 色回退调色板 + HSL lighten/darken
- [x] `GenreSunburstNotifier` — StateNotifier 状态管理（loadTree / selectGenre）

### 1.8 厂牌/主办方（Organizers） ✅

- [x] `OrganizersRootScreen` — 主办方列表（RefreshIndicator + 骨架屏）
- [x] `FestivalDetailScreen` — 音乐节详情（SliverAppBar hero + 简介/流派/别名/链接）
- [x] `OrganizerCard` — 主办方卡片组件（封面图 + 位置 + 关注数 + 流派标签）
- [x] `OrganizerApi` — `GET /v1/learn/festivals`, `GET /v1/learn/festivals/:id`
- [x] 骨架屏加载态（`OrganizerListSkeleton`）
- [x] `OrganizersNotifier` / `FestivalDetailNotifier` — StateNotifier 状态管理

#### 上传（Phase 4）

- [ ] `OrganizerUploadFlowScreen` — 主办方/音乐节创建向导

### 1.9 厂牌标签（Labels） ✅

- [x] `LabelsRootScreen` — 标签列表（骨架屏 + RefreshIndicator）
- [x] `LabelDetailScreen` — 标签详情（图片/简介/流派/创始人/官网）
- [x] `LabelApi` — `GET /v1/learn/labels`, `GET /v1/learn/labels/:id`
- [x] `LabelsNotifier` / `LabelDetailNotifier` — StateNotifier 状态管理

### 1.10 排行榜（Rankings） ✅

- [x] `RankingsRootScreen` — 排行榜列表（奖杯图标 + 届数 + 年份范围）
- [x] `RankingBoardDetailScreen` — 排行榜详情（金银铜奖牌 + 头像 + 排名变化 Delta）
- [x] `RankingApi` — `GET /v1/learn/rankings`, `GET /v1/learn/rankings/:id`（支持年份筛选）
- [x] `RankingsNotifier` / `RankingDetailNotifier` — StateNotifier 状态管理（含年份选择）

### 1.11 全局搜索（Search） ✅

- [x] `SearchOverlayScreen` — 搜索覆盖层（最近搜索 Flow 布局 + 平台统计网格 + 搜索框 + 动画弹出）
- [x] `SearchResultsScreen` — 搜索结果页（12 个分类 Tab + "全部" 汇总视图 + 摘要条 + Top Matches + 分域预览）
- [x] `SearchResultCard` — 各类型搜索结果卡片（缩略图/颜色编码域标签/标题/副标题/箭头）
- [x] `GlobalSearchResultsViewModel` — 搜索状态管理（per-tab LoadPhase + 12 Tab 路由映射 + 局部失败处理）
- [x] `SearchApiService` — `GET /v1/search/global`
- [x] `SearchRepository` — 搜索仓库层
- [x] `RecentSearchStore` — SharedPreferences 最近搜索持久化（max 10 条、大小写去重）
- [x] `DiscoverServiceLocator` — 懒加载单例 DI（Dio/Repository/Store）

---

## Phase 2：Circle + Inbox ✅

### 2.1 动态 Feed ✅

- [x] `FeedScreen` — Feed 列表（关注/推荐 切换）
- [x] `PostDetailScreen` — 动态详情（正文 + 图片/视频 + 评论树）
- [x] `ComposePostScreen` — 发布动态（图/视频上传 + 活动标签 + 位置）
- [x] `PostCard` — 动态卡片（复用 `PostCardView` 共享组件）
- [x] `CommentSection` — 评论列表 + 发表 + 回复
- [x] `FeedViewModel` — 分页加载 + 点赞/收藏
- [x] `PostApi` — `GET /v1/social/feed`, `POST /v1/social/posts`, `GET /v1/social/posts/:id`
- [x] 图片/视频上传（调用 `MultipartUploadService`）
- [x] 点赞动画
- [x] 骨架屏加载态

### 2.2 小队（Squads） ✅

- [x] `SquadHallScreen` — 小队大厅（我的小队 + 推荐小队）
- [x] `SquadProfileScreen` — 小队主页（成员/动态/线下活动）
- [x] `SquadManageScreen` — 小队管理（邀请/踢人/编辑信息）
- [x] `SquadCreateSheet` — 创建小队弹窗
- [x] `SquadOfflineActivityScreen` — 线下活动（简化版）
- [x] `SquadOfflineActivityHistoryScreen` — 线下活动历史
- [x] `SquadViewModel` — 小队数据管理
- [x] `SquadApi` — `GET /v1/social/squads`, `POST /v1/social/squads`, `GET /v1/social/squads/:id`
- [ ] flutter_map / apple_maps_flutter 集成（实时位置共享 — Phase 5）
- [x] 骨架屏加载态

### 2.3 Circle ID ✅

- [x] `CircleIdHubScreen` — ID 卡列表（渐变网格）
- [x] `CircleIdDetailScreen` — ID 卡详情（大尺寸可视化 + 统计）
- [x] `CircleIdComposerSheet` — ID 卡创建/编辑弹窗（模板选择 + 实时预览）
- [x] `CircleIdApi` — `GET /v1/social/circle-ids`, `POST /v1/social/circle-ids`

### 2.4 评分（Ratings） ✅

- [x] `RatingHubScreen` — 评分活动列表（进行中/已结束 分段）
- [x] `RatingEventDetailScreen` — 评分活动详情（排名柱状图 + 单元列表）
- [x] `RatingUnitDetailScreen` — 评分单元详情（10 星投票 + 评论）
- [x] `CreateRatingSheets` — 创建评分弹窗组
- [x] `RatingApi` — `GET /v1/social/ratings`, `POST /v1/social/ratings`

### 2.5 Inbox 通知中心 ✅

- [x] `InboxHomeScreen` — 通知中心主页（5 GlassCard 入口 + 未读 badge）
- [x] `AlertCategoryScreen` — 社区互动分类（头像 + 描述 + 时间 + 未读点）
- [x] `FollowedEventsInboxScreen` — 已关注活动变更通知列表
- [x] `FollowedDjsInboxScreen` — 已关注 DJ 变更通知列表
- [x] `FollowedBrandsInboxScreen` — 已关注厂牌变更通知列表
- [x] `ContentReviewsInboxScreen` — 内容审核状态通知列表（状态标签颜色编码）
- [x] `EntityChangeDetailScreen` — 变更详情页
- [x] `InboxViewModel` — 未读数计算与管理
- [x] `NotificationApi` — 全部 7 个端点
- [x] 标记已读 — `PUT /v1/notification-center/read`
- [x] 推送 Token 注册 — `POST /v1/notification-center/push-tokens`

---

## Phase 3：Profile + Auth 完善 ✅（80%）

### 3.1 我的主页 ✅

- [x] `ProfileMeScreen` — 个人主页（SliverAppBar + 头像/统计/3-Tab 动态/收藏/签到）
- [x] `ProfileHeader` — 头像/昵称/EDMTI/Bio + 编辑资料按钮
- [x] `ProfileStatsRow` — 关注数/粉丝数/获赞数/签到数（可点击跳转）
- [x] `ProfileMyPostsList` — 我的动态列表
- [x] `ProfileMeViewModel` — 数据聚合加载 + 分页
- [x] `ProfileApi` — `GET /v1/users/me`

### 3.2 他人主页 ✅

- [x] `UserProfileScreen` — 他人主页（头像/统计/动态/关注按钮 + 举报/拉黑菜单）
- [x] `UserProfileViewModel` — 数据加载 + 关注/举报/拉黑
- [x] `UserApi` — `GET /v1/users/:id`
- [x] 关注/取消关注 — `POST /v1/users/:id/follow`

### 3.3 编辑资料 ✅

- [x] `EditProfileScreen` — 编辑头像/昵称/个人简介/性别/生日/城市 + 昵称可用性检查
- [x] 头像选择上传（MediaPickerService + MultipartUploadService）
- [x] `EditProfileApi` — `PUT /v1/users/me`

### 3.4 设置 ✅

- [x] `SettingsScreen` — 设置主页（分组列表 + 退出登录）
- [x] `LanguageSettingScreen` — 语言选择（4 选项 + 打勾标记）
- [x] `AppearanceSettingScreen` — 主题选择（3 选项 + 图标预览）
- [x] `AccountSecurityScreen` — 账号安全（修改密码/绑定手机/绑定邮箱）
- [x] `DeviceManageScreen` — 设备管理（设备列表 + 当前设备标记 + 登出其他）
- [x] `CacheManageScreen` — 缓存管理（缓存大小 + 清除确认弹窗）
- [x] `PermissionGuideScreen` — 权限引导（4 项权限状态 + 跳转系统设置）
- [x] `AboutScreen` — 关于（图标/版本号/协议/隐私/许可证）
- [x] `SettingsApi` — `PUT /v1/users/me/preferences`

### 3.5 签到历史 ✅

- [x] `MyCheckinsScreen` — 签到总览（统计卡片 + 时间线/画廊切换）
- [x] `CheckinOverviewCard` — 签到统计面板（总数/城市数/场馆数/最爱场馆）
- [x] `CheckinTimelineView` — 时间线视图（按年月分组）
- [x] `CheckinGalleryView` — 签到照片画廊（网格）
- [x] `CheckinApi` — `GET /v1/social/checkins`, `GET /v1/social/checkins/overview`

### 3.6 我的发布 ✅

- [x] `MyPublishesScreen` — 已发布内容列表（4 段切换 + 状态标签）
- [x] `ContentSubmissionDetailScreen` — 审核详情（时间线 + 审核意见 + 重新提交）
- [x] `PublishesApi` — `GET /v1/content-submissions`

### 3.7 贡献中心 ✅

- [x] `ContributionCenterScreen` — 贡献统计（积分/等级/条形图分布/历史列表）
- [x] `ContributionApi` — `GET /v1/users/me/contributions`

### 3.8 Quiz 测验 ✅

- [x] `QuizFlowScreen` — EDM 知识测验流程（PageView + 进度条 + 倒计时 + 自动提交）
- [x] `QuizResultScreen` — 测验结果页（得分/排名/正确率/错题回顾/分享）
- [x] `QuizApi` — `GET /v1/social/quiz/questions`, `POST /v1/social/quiz/submit`

### 3.9 Personality 性格测试 ✅

- [x] `PersonalityFlowScreen` — EDMTI 性格测试流程（选择后自动前进）
- [x] `PersonalityResultScreen` — 测试结果（类型代码/维度条/匹配 DJ/分享）
- [x] `PersonalityShareCard` — 结果分享卡片组件
- [x] `PersonalityApi` — `GET /v1/social/personality/questions`, `POST /v1/social/personality/submit`

### 3.10 关注/粉丝列表 ✅

- [x] `FollowListScreen` — 关注/粉丝 双 Tab 列表（头像/昵称/简介/关注按钮 + 分页）
- [x] `FollowListApi` — `GET /v1/users/:id/following`, `GET /v1/users/:id/followers`

### 3.11 收藏 ✅

- [x] `SavesScreen` — 我的收藏（活动/DJ/Set/动态 四段切换 + 独立分页）
- [x] `SavesApi` — `GET /v1/users/me/saves`

### 3.12 虚拟资产 ✅

- [x] `VirtualAssetsScreen` — 虚拟装扮中心（已拥有/商店 网格）
- [x] `VirtualAssetDetailScreen` — 资产详情（预览 + 装备/卸下）
- [x] `VirtualAssetApi` — `GET /v1/virtual-assets`, `PUT /v1/virtual-assets/equip`

### 3.13 工具 ✅

- [x] `QRCodeScreen` — 个人 QR 码（CustomPainter + 保存/分享）
- [x] `RouteToolScreen` — 路线工具（起终点输入 + MapLauncher 导航）
- [x] `WidgetManageScreen` — 桌面小组件管理（列表 + 说明）
- [x] `CinematicBannerScreen` — 电影横幅生成（4 模板 + 实时预览 + 保存）

### 3.14 Auth 完善 ✅

- [x] `AuthApi` — 9 个认证端点完整实现（email/sms/password 登录 + 注册 + 刷新 + 登出 + 重置密码 + Firebase 验证）
- [x] `AuthServiceLocator` — 单例 DI 容器（Dio + SessionTokenStore）
- [x] 邮箱登录 API 完整接入 — `POST /v1/auth/login/email`
- [x] 短信登录 API 完整接入 — `POST /v1/auth/login/sms`
- [x] 密码登录 API 完整接入 — `POST /v1/auth/login/password`
- [x] 注册 API 完整接入 — `POST /v1/auth/register`
- [x] Token 刷新 端到端验证 — `POST /v1/auth/refresh`
- [x] 登出 — `POST /v1/auth/logout`
- [x] 密码重置流程 — `POST /v1/auth/password/reset`
- [x] Firebase 手机号认证 — `POST /v1/auth/firebase/verify`

---

## Phase 4：内容创建 + 编辑 ✅（90%）

### 4.1 活动编辑 & 上传 ✅

- [x] `EventEditorScreen` — 活动信息编辑表单（5 Section：基本信息/时间/地点/海报/票务）
- [x] `EventUploadFlowScreen` — 多步向导（基本信息→海报→阵容→时间表→票务→提交）
- [x] `EventEditorViewModel` — 活动编辑状态管理（create/edit 双模式）
- [x] `EventUploadViewModel` — 5 步向导状态（LineupEntry + ScheduleEntry）
- [x] `EventRoutePlannerScreen` — 路线规划器（GPS + Haversine 距离 + MapLauncher + ShareService）
- [x] `EventScheduleCanvas` — 时间表 CustomPainter（X轴时间/Y轴舞台/点击命中检测/水平滚动）
- [x] `EventsApiService` 写方法 — `POST /v1/events`, `PUT /v1/events/:id`, `DELETE /v1/events/:id`, `POST /v1/upload/events/poster`
- [x] Lineup AI 图片识别导入（OCR → DJ 匹配）— EventLineupImportScreen + API

### 4.2 DJ 导入 & 编辑 ✅

- [x] `DjImportScreen` — Spotify/Discogs/手动 三种导入模式（RaverSegmentedControl 切换）
- [x] `DjEditorScreen` — DJ 信息编辑（头像/名称/简介/国籍/流派标签/社交链接）
- [x] `DjEditorViewModel` — DJ 编辑状态管理（ChangeNotifier）
- [x] `DjApi` 写方法 — `POST /v1/djs`, `PUT /v1/djs/:id`, `POST /v1/upload/djs/avatar`
- [x] Spotify 导入 — `POST /v1/djs/import/spotify`
- [x] Discogs 导入 — `POST /v1/djs/import/discogs`
- [ ] `DjUploadFlowScreen` — DJ 多步上传向导（简化版，可用 DjEditorScreen 代替）

### 4.3 Set 编辑 ✅

- [x] `SetEditorScreen` — Set 信息编辑（标题/描述/日期/关联DJ&活动/音视频上传/曲目预览）
- [x] `TracklistEditorScreen` — Tracklist 逐曲编辑/添加/删除/排序（ReorderableListView + FAB + BottomSheet）
- [x] `SetEditorViewModel` — Set 编辑状态管理（ChangeNotifier）
- [x] `SetApi` 写方法 — `POST /v1/sets`, `PUT /v1/sets/:id`
- [x] 音频文件上传 — `POST /v1/upload/sets/audio`
- [x] 视频文件上传 — `POST /v1/upload/sets/video`

### 4.4 新闻发布 ✅

- [x] `NewsEditorScreen` — 新闻发布/编辑（封面上传 + 标题 + 分类 + 标签 + Markdown 正文）
- [x] `NewsEditorViewModel` — 新闻编辑状态管理
- [x] `NewsApi` 写方法 — `POST /v1/news`, `PUT /v1/news/:id`, `POST /v1/upload/news/cover`

### 4.5 厂牌/主办方创建 ✅

- [x] `OrganizerUploadFlowScreen` — 主办方/音乐节创建 4 步向导（基本信息→封面→详情→提交预览）
- [x] `OrganizerUploadViewModel` — 主办方上传状态管理（流派/别名 Chip 列表）
- [x] `OrganizerApi` 写方法 — `POST /v1/learn/festivals`, `PUT /v1/learn/festivals/:id`, `POST /v1/upload/festivals/cover`

### 4.6 评分创建 ✅（Phase 2 已完成）

- [x] `CreateRatingEventSheet` — 创建评分活动（Phase 2 完成）
- [x] `CreateRatingUnitSheet` — 创建评分单元（Phase 2 完成）

### 4.7 路线分享

- [x] `ShareCardGenerator` — 分享卡片图片生成（EventShareCard 布局 + RepaintBoundary 离屏渲染捕获 PNG）

---

## Phase 5：平台打磨 + HarmonyOS ✅（100%）

### 5.1 Deep Link

- [x] `deep_link_handler.dart` — `raver://` 自定义 scheme + `ravehub.top` HTTPS 链接→GoRouter 路径映射（11 种资源类型 + search 查询参数）
- [x] `deep_link_config.dart` — Android intent-filter / iOS entitlements+Info.plist / HarmonyOS module.json5 / AASA+assetlinks.json 完整平台配置文档
- [x] `app_router.dart` — GoRouter redirect 集成 DeepLinkHandler.toAppPath() 自动转换
- [x] `bootstrap.dart` — 推送点击深度链接处理（PushNotificationService.onNotificationTapped → DeepLinkHandler → GoRouter.go）
- [x] HarmonyOS module.json5 — Deep Link skills 配置（raver:// + ravehub.top HTTPS，7种资源 + 运行时权限声明）
- [ ] iOS Universal Links 端到端测试（需要真机 + AASA 部署）
- [ ] Android App Links + `assetlinks.json` 部署（需要域名配置）
- [ ] `raver://` 自定义 scheme 真机测试

### 5.2 推送通知

- [x] 推送 Token 注册/更新 — `PushNotificationService` + `NotificationApiService.registerPushToken`
- [x] 推送点击路由跳转 — `PushRouter.handleMessage`
- [ ] iOS APNs 证书配置（需要 Apple Developer 账号）
- [ ] Android FCM google-services.json 配置（需要 Firebase Console）
- [ ] 富推送 iOS Notification Service Extension（需要 Xcode + 原生配置）

### 5.3 桌面小组件

- [x] iOS WidgetKit 倒计时小组件（原生 Swift + `home_widget` 桥接）— RaverCountdownWidgets.swift（TimelineProvider 每小时刷新 + CountdownWidgetEntryView 暗紫渐变 #0D0D0D→#1A1A2E + systemSmall/systemMedium + raver://event 深链）+ Info.plist
- [x] Android Home Widget（原生 + `home_widget` 桥接）— RaverCountdownWidget.kt（AppWidgetProvider + SharedPreferences + RemoteViews + PendingIntent 深链）+ raver_countdown_widget.xml + raver_countdown_widget_info.xml（30min 更新）
- [x] Widget 数据通过 App Group UserDefaults 共享 — iOS: group.com.ravehub.app UserDefaults / Android: ravehub_widget_prefs SharedPreferences

### 5.4 HarmonyOS 平台适配

- [x] 地图替换（Google Maps → 平台感知 RaverMapView）— iOS: apple_maps_flutter (MapKit)、Android/HarmonyOS: flutter_map (OpenStreetMap)；google_maps_flutter 已全部移除；外部导航仍使用 MapLauncher（Petal Maps / AutoNavi URL scheme）
- [x] 推送替换（FCM → 华为 Push Kit）— HarmonyPushAdapter（harmony_push_service.dart: MethodChannel 'com.ravehub.push/harmony' + getPushToken/subscribeToTopic/deleteToken）
- [x] 安全存储验证文档 — validate_secure_storage.sh（flutter_secure_storage 9.x 自动对接 HarmonyOS OHOS KeyStore，无需额外原生代码）
- [x] HAP 包构建配置 — HarmonyConfig（harmony_config.dart: API Level 12-14 / bundleName / pushKitChannel / mapChannel 常量 + 构建说明）
- [x] HarmonyOS module.json5 — Deep Link + 权限声明配置

### 5.5 性能优化

- [x] 长列表虚拟化滚动优化（EventsListScreen cacheExtent:500 + DjsListScreen cacheExtent:500）
- [x] 图片内存管理（缓存上限 150 entries / 100MB，main.dart PaintingBinding 配置）
- [x] Sunburst CustomPainter 渲染优化（RepaintBoundary 隔离 + shouldRepaint 补全 isDark/maxDepth）
- [x] 首屏加载速度优化（orientation lock shader warmup + flutter_native_splash 占位）
- [x] Dart AOT 编译优化 — build_android.sh 已包含 `--obfuscate --split-debug-info` flag
- [x] Shader 预热（SystemChrome.setPreferredOrientations + flutter_native_splash 预热占位）

### 5.6 测试

- [x] 单元测试 — raver_core（load_phase_test / service_error_test / date_formatting_test）
- [x] 单元测试 — raver_models（user_json_test / event_json_test / pagination_test）
- [x] 单元测试 — raver_network（oss_url_processor_test）
- [x] 单元测试 — raver_auth（auth_state_test）
- [x] Widget 测试 — raver_design_system 核心组件（glass_card_test.dart: 5 用例）
- [x] Widget 测试 — feature_auth 登录/注册流程（login_screen_test.dart: 5 用例）
- [x] Widget 测试 — feature_discover 列表/详情（events_list_screen_test.dart: 5 用例）
- [x] Widget 测试 — feature_circle Feed/小队（feed_screen_test.dart: 5 用例）
- [x] Widget 测试 — feature_inbox 通知（inbox_screen_test.dart: 5 用例）
- [x] Widget 测试 — feature_profile 设置（settings_screen_test.dart: 5 用例）
- [x] Golden 测试 — TabBar/卡片/主题 像素对比（GlassCard light/dark + PrimaryButton 3 态 + Skeleton 3 变体）
- [x] 集成测试 — 登录→浏览→详情→返回 完整流程
- [x] 集成测试 — 发布动态→Feed 刷新→详情
- [x] BFF 契约测试 — JSON Fixture 验证
- [ ] 三端真机测试（需要 iOS + Android + HarmonyOS 实体设备）

### 5.7 发布准备

- [x] iOS App Store Connect 元数据 — fastlane metadata en-US（name/subtitle/description/keywords/release_notes）+ zh-Hans（name/subtitle）
- [x] Android Google Play Console 元数据 — fastlane metadata 共享
- [x] 应用图标（三端）— flutter_launcher_icons ^0.14.1 配置
- [x] 启动页/Splash Screen（三端）— flutter_native_splash ^2.4.3 配置（#0D0D0D 背景 + Android 12 适配）
- [x] 应用内版本更新检查 — VersionCheckService + UpdateDialog + AppReleaseConfig
- [x] Fastlane 配置 — Fastfile（6 lanes）+ Appfile
- [x] 三端构建脚本 — build_ios.sh + build_android.sh + build_harmony.sh
- [x] iOS ExportOptions.plist — app-store method + automatic signing
- [ ] iOS App Store 签名（需要 Apple Developer 账号 + 证书 + Provisioning Profile）
- [ ] Android Google Play 签名（需要 Keystore 文件 + Google Play Console 账号）
- [ ] HarmonyOS AppGallery 签名（需要 DevEco Studio + AppGallery 账号）

---

## 屏幕对齐清单（iOS → Flutter）

> 共 119 个 iOS 屏幕，按模块分组。✅ = 已实现 | 🟡 = 占位 | ⬜ = 未开始

### Auth（4 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 1 | LoginView | `LoginScreen` | ✅ 完整实现 |
| 2 | RegisterView | `RegisterScreen` | ✅ 完整实现 |
| 3 | SMSVerificationView | `SmsVerificationScreen` | ✅ 完整实现 |
| 4 | PasswordResetView | `PasswordResetScreen` | ✅ 完整实现 |

### Discover — Recommend（2 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 5 | RecommendView | `RecommendScreen` | ✅ 完整实现 |
| 6 | RecommendDetailSheet | `RecommendDetailSheet` | ✅ 完整实现 |

### Discover — Events（12 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 7 | EventsListView | `EventsListScreen` | ✅ 完整实现 |
| 8 | EventDetailView | `EventDetailScreen` | ✅ 完整实现 |
| 9 | EventEditorView | `EventEditorScreen` | ✅ 完整实现 |
| 10 | EventUploadFlowView | `EventUploadFlowScreen` | ✅ 完整实现 |
| 11 | EventRoutePlannerView | `EventRoutePlannerScreen` | ✅ 完整实现 |
| 12 | EventLiveDiscussionView | 集成在 `EventDetailScreen` (EventLiveDiscussionSection) | ✅ 完整实现 |
| 13 | EventScheduleCanvasView | `EventScheduleCanvas` (CustomPainter) | ✅ 完整实现 |
| 14 | EventFilterSheet | `EventFilterSheet` | ✅ 完整实现 |
| 15 | EventShareSheet | 集成在 `EventDetailScreen` (EventShareSection) | ✅ 完整实现 |
| 16 | EventCheckInView | 集成在 `EventDetailScreen` (EventCheckInSection) | ✅ 完整实现 |
| 17 | EventMapView | 集成在 `EventDetailScreen` (EventMapSection) | ✅ 完整实现 |
| 18 | EventLineupImportView | `EventLineupImportScreen` | ✅ 完整实现 |

### Discover — News（3 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 19 | NewsListView | `NewsListScreen` | ✅ 完整实现 |
| 20 | NewsDetailView | `NewsDetailScreen` | ✅ 完整实现 |
| 21 | NewsEditorView | `NewsEditorScreen` | ✅ 完整实现 |

### Discover — DJs（7 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 22 | DJsListView | `DjsListScreen` | ✅ 完整实现 |
| 23 | DJDetailView | `DjDetailScreen` | ✅ 完整实现 |
| 24 | DJImportView | `DjImportScreen` | ✅ 完整实现 |
| 25 | DJUploadFlowView | `DjEditorScreen` (覆盖此功能) | ✅ 完整实现 |
| 26 | DJEditorView | `DjEditorScreen` | ✅ 完整实现 |
| 27 | DJSpotlightCarouselView | (内嵌于 `DjsListScreen`) | ✅ 完整实现 |
| 28 | DJBioSheet | (内嵌于 `DjDetailScreen`) | ✅ 完整实现 |

### Discover — Sets（5 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 29 | SetsListView | `SetsListScreen` | ✅ 完整实现 |
| 30 | SetDetailView | `SetDetailScreen` | ✅ 完整实现 |
| 31 | SetEditorView | `SetEditorScreen` | ✅ 完整实现 |
| 32 | TracklistEditorView | `TracklistEditorScreen` | ✅ 完整实现 |
| 33 | SetVideoPlayerView | (内嵌于 `SetDetailScreen`) | ✅ 完整实现 |

### Discover — Genres（4 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 34 | GenresRootView | `GenresRootScreen` | ✅ 完整实现 |
| 35 | GenreSunburstView | (内嵌于 `GenresRootScreen` + `GenreSunburstPainter`) | ✅ 完整实现 |
| 36 | GenreDetailView | `GenreDetailScreen` | ✅ 完整实现 |
| 37 | GenreSunburstCanvasView | (内嵌于 `GenreSunburstPainter` CustomPainter) | ✅ 完整实现 |

### Discover — Organizers（4 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 38 | OrganizersRootView | `OrganizersRootScreen` | ✅ 完整实现 |
| 39 | FestivalDetailView | `FestivalDetailScreen` | ✅ 完整实现 |
| 40 | OrganizerUploadFlowView | `OrganizerUploadFlowScreen` | ✅ 完整实现 |
| 41 | OrganizerListFilterSheet | `OrganizerListFilterSheet` | ✅ 完整实现 |

### Discover — Labels（3 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 42 | LabelsRootView | `LabelsRootScreen` | ✅ 完整实现 |
| 43 | LabelDetailView | `LabelDetailScreen` | ✅ 完整实现 |
| 44 | LabelListFilterSheet | `LabelListFilterSheet` | ✅ 完整实现 |

### Discover — Rankings（3 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 45 | RankingsRootView | `RankingsRootScreen` | ✅ 完整实现 |
| 46 | RankingBoardDetailView | `RankingBoardDetailScreen` | ✅ 完整实现 |
| 47 | RankingEntryDetailView | `RankingEntryDetailScreen` | ✅ 完整实现 |

### Discover — Search（3 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 48 | SearchOverlayView | `SearchOverlayScreen` | ✅ 完整实现 |
| 49 | SearchResultsView | `SearchResultsScreen` | ✅ 完整实现 |
| 50 | SearchResultCardsView | `SearchResultCard` | ✅ 完整实现 |

### Circle — Feed（5 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 51 | FeedView | `FeedScreen` | ✅ 完整实现 |
| 52 | PostDetailView | `PostDetailScreen` | ✅ 完整实现 |
| 53 | ComposePostView | `ComposePostScreen` | ✅ 完整实现 |
| 54 | PostCommentSheet | 集成在 PostDetailScreen | ✅ 完整实现 |
| 55 | PostMediaGalleryView | 集成在 PostDetailScreen | ✅ 完整实现 |

### Circle — Squads（8 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 56 | SquadHallView | `SquadHallScreen` | ✅ 完整实现 |
| 57 | SquadProfileView | `SquadProfileScreen` | ✅ 完整实现 |
| 58 | SquadManageView | `SquadManageScreen` | ✅ 完整实现 |
| 59 | SquadCreateSheet | `SquadCreateSheet` | ✅ 完整实现 |
| 60 | SquadOfflineActivityView | `SquadOfflineActivityScreen` | ✅ 完整实现 |
| 61 | SquadOfflineActivityHistoryView | `SquadOfflineActivityHistoryScreen` | ✅ 完整实现 |
| 62 | SquadMemberListView | `SquadMemberList` | ✅ 完整实现 |
| 63 | SquadInviteSheet | 集成在 SquadManageScreen | ✅ 完整实现 |

### Circle — IDs（3 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 64 | CircleIdHubView | `CircleIdHubScreen` | ✅ 完整实现 |
| 65 | CircleIdDetailView | `CircleIdDetailScreen` | ✅ 完整实现 |
| 66 | CircleIdComposerSheet | `CircleIdComposerSheet` | ✅ 完整实现 |

### Circle — Ratings（5 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 67 | RatingHubView | `RatingHubScreen` | ✅ 完整实现 |
| 68 | RatingEventDetailView | `RatingEventDetailScreen` | ✅ 完整实现 |
| 69 | RatingUnitDetailView | `RatingUnitDetailScreen` | ✅ 完整实现 |
| 70 | CreateRatingEventSheet | `CreateRatingEventSheet` | ✅ 完整实现 |
| 71 | CreateRatingUnitSheet | `CreateRatingUnitSheet` | ✅ 完整实现 |

### Inbox（8 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 72 | InboxHomeView | `InboxHomeScreen` | ✅ 完整实现 |
| 73 | AlertCategoryView | `AlertCategoryScreen` | ✅ 完整实现 |
| 74 | FollowedEventsInboxView | `FollowedEventsInboxScreen` | ✅ 完整实现 |
| 75 | FollowedDJsInboxView | `FollowedDjsInboxScreen` | ✅ 完整实现 |
| 76 | FollowedBrandsInboxView | `FollowedBrandsInboxScreen` | ✅ 完整实现 |
| 77 | ContentReviewsInboxView | `ContentReviewsInboxScreen` | ✅ 完整实现 |
| 78 | EntityChangeDetailView | `EntityChangeDetailScreen` | ✅ 完整实现 |
| 79 | NotificationSettingsView | `NotificationSettingsScreen` | ✅ 完整实现 |

### Profile — 我的主页（5 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 80 | ProfileView | `ProfileMeScreen` | ✅ 完整实现 |
| 81 | ProfileHeaderView | `ProfileHeader` | ✅ 完整实现 |
| 82 | ProfileStatsView | `ProfileStatsRow` | ✅ 完整实现 |
| 83 | ProfileMyPostsListView | 集成在 ProfileMeScreen | ✅ 完整实现 |
| 84 | ProfileSavesView | `SavesScreen` | ✅ 完整实现 |

### Profile — 他人主页（2 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 85 | UserProfileView | `UserProfileScreen` | ✅ 完整实现 |
| 86 | UserProfilePostsView | 集成在 UserProfileScreen | ✅ 完整实现 |

### Profile — 编辑资料（2 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 87 | EditProfileView | `EditProfileScreen` | ✅ 完整实现 |
| 88 | AvatarCropView | 集成在 EditProfileScreen | ✅ 完整实现 |

### Profile — 设置（8 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 89 | SettingsView | `SettingsScreen` | ✅ 完整实现 |
| 90 | LanguageSettingView | `LanguageSettingScreen` | ✅ 完整实现 |
| 91 | AppearanceSettingView | `AppearanceSettingScreen` | ✅ 完整实现 |
| 92 | AccountSecurityView | `AccountSecurityScreen` | ✅ 完整实现 |
| 93 | DeviceManageView | `DeviceManageScreen` | ✅ 完整实现 |
| 94 | CacheManageView | `CacheManageScreen` | ✅ 完整实现 |
| 95 | PermissionGuideView | `PermissionGuideScreen` | ✅ 完整实现 |
| 96 | AboutView | `AboutScreen` | ✅ 完整实现 |

### Profile — 签到（4 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 97 | CheckinOverviewView | `MyCheckinsScreen` | ✅ 完整实现 |
| 98 | CheckinTimelineView | `CheckinTimelineView` | ✅ 完整实现 |
| 99 | CheckinGalleryView | `CheckinGalleryView` | ✅ 完整实现 |
| 100 | CheckinDetailView | 集成在 MyCheckinsScreen | ✅ 完整实现 |

### Profile — 发布 & 贡献（3 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 101 | MyPublishesView | `MyPublishesScreen` | ✅ 完整实现 |
| 102 | ContentSubmissionDetailView | `ContentSubmissionDetailScreen` | ✅ 完整实现 |
| 103 | ContributionCenterView | `ContributionCenterScreen` | ✅ 完整实现 |

### Profile — Quiz & Personality（4 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 104 | QuizFlowView | `QuizFlowScreen` | ✅ 完整实现 |
| 105 | QuizResultView | `QuizResultScreen` | ✅ 完整实现 |
| 106 | PersonalityFlowView | `PersonalityFlowScreen` | ✅ 完整实现 |
| 107 | PersonalityResultView | `PersonalityResultScreen` | ✅ 完整实现 |

### Profile — 工具（4 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 108 | QRCodeView | `QrCodeScreen` | ✅ 完整实现 |
| 109 | RouteToolView | `RouteToolScreen` | ✅ 完整实现 |
| 110 | WidgetManageView | `WidgetManageScreen` | ✅ 完整实现 |
| 111 | CinematicBannerView | `CinematicBannerScreen` | ✅ 完整实现 |

### Profile — 其他（4 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 112 | FollowListView | `FollowListScreen` | ✅ 完整实现 |
| 113 | VirtualAssetsView | `VirtualAssetsScreen` | ✅ 完整实现 |
| 114 | VirtualAssetDetailView | `VirtualAssetDetailScreen` | ✅ 完整实现 |
| 115 | SavesView | `SavesScreen` | ✅ 完整实现 |

### 全局/共享（4 屏）

| # | iOS 屏幕 | Flutter 对应 | 状态 |
|---|---------|-------------|------|
| 116 | MainTabView (4-Tab Shell) | `RaverShellScaffold` | ✅ 完整实现 |
| 117 | DiscoverHomeView (9-Tab Pager) | `DiscoverHomeScreen` | ✅ 完整实现 |
| 118 | CircleHomeView (4-Tab Pager) | `CircleHomeScreen` | ✅ 完整实现 |
| 119 | MediaPreviewView | `MediaPreviewOverlay` | ✅ 完整实现 |

### 屏幕统计

| 状态 | 数量 | 百分比 |
|------|------|--------|
| ✅ 完整实现 | 119 | 100% |
| ⬜ 未实现 | 0 | 0% |
| **合计** | **119** | 100% |

---

## BFF API 端点覆盖

> 后端基址：`https://api.ravehub.top`  
> 策略：Flutter 端发送与 iOS 完全相同的 HTTP 请求，后端零修改

### Auth API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/auth/login/email` | POST | ✅ |
| `/v1/auth/login/sms` | POST | ✅ |
| `/v1/auth/login/password` | POST | ✅ |
| `/v1/auth/register` | POST | ✅ |
| `/v1/auth/refresh` | POST | ✅ |
| `/v1/auth/logout` | POST | ✅ |
| `/v1/auth/sms/send` | POST | ✅ |
| `/v1/auth/password/reset` | POST | ✅ |
| `/v1/auth/firebase/verify` | POST | ✅ |

### User API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/users/me` | GET | ✅ |
| `/v1/users/me` | PUT | ✅ |
| `/v1/users/me/preferences` | PUT | ✅ |
| `/v1/users/me/contributions` | GET | ✅ |
| `/v1/users/me/saves` | GET | ✅ |
| `/v1/users/:id` | GET | ✅ |
| `/v1/users/:id/follow` | POST | ✅ |
| `/v1/users/:id/following` | GET | ✅ |
| `/v1/users/:id/followers` | GET | ✅ |
| `/v1/users/check-display-name` | GET | ✅ |

### Events API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/events` | GET | ✅ |
| `/v1/events/ongoing` | GET | ✅ |
| `/v1/events/upcoming` | GET | ✅ |
| `/v1/events/recommended` | GET | ✅ |
| `/v1/events/:id` | GET | ✅ |
| `/v1/events/:id/schedule` | GET | ✅ |
| `/v1/events/:id/lineup` | GET | ✅ |
| `/v1/events/:id/discussion` | GET | ✅ |
| `/v1/events/:id/checkins` | GET | ✅ |
| `/v1/events/:id/follow` | POST | ✅ |
| `/v1/events` | POST | ✅ |
| `/v1/events/:id` | PUT | ✅ |
| `/v1/events/:id/lineup/import-image` | POST | ✅ |

### DJs API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/djs` | GET | ✅ |
| `/v1/djs/spotlight` | GET | ✅ |
| `/v1/djs/:id` | GET | ✅ |
| `/v1/djs/:id/follow` | POST | ✅ |
| `/v1/djs` | POST | ✅ |
| `/v1/djs/:id` | PUT | ✅ |
| `/v1/djs/import/spotify` | POST | ✅ |
| `/v1/djs/import/discogs` | POST | ✅ |

### Sets API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/sets` | GET | ✅ |
| `/v1/sets/:id` | GET | ✅ |
| `/v1/sets/:id/comments` | GET | ✅ |
| `/v1/sets/:id/comments` | POST | ✅ |
| `/v1/sets` | POST | ✅ |
| `/v1/sets/:id` | PUT | ✅ |

### Social API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/social/feed` | GET | ✅ |
| `/v1/social/posts` | POST | ✅ |
| `/v1/social/posts/:id` | GET | ✅ |
| `/v1/social/posts/:id/like` | POST | ✅ |
| `/v1/social/posts/:id/comments` | GET | ✅ |
| `/v1/social/posts/:id/comments` | POST | ✅ |
| `/v1/social/squads` | GET | ✅ |
| `/v1/social/squads` | POST | ✅ |
| `/v1/social/squads/:id` | GET | ✅ |
| `/v1/social/squads/:id/members` | GET | ✅ |
| `/v1/social/squads/:id/offline-activities` | GET | ✅ |
| `/v1/social/circle-ids` | GET | ✅ |
| `/v1/social/circle-ids` | POST | ✅ |
| `/v1/social/ratings` | GET | ✅ |
| `/v1/social/ratings` | POST | ✅ |
| `/v1/social/checkins` | GET | ✅ |
| `/v1/social/checkins/overview` | GET | ✅ |
| `/v1/social/quiz` | GET | ✅ |
| `/v1/social/quiz/submit` | POST | ✅ |
| `/v1/social/personality` | GET | ✅ |
| `/v1/social/personality/submit` | POST | ✅ |

### News API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/news` | GET | ✅ |
| `/v1/news/:id` | GET | ✅ |
| `/v1/news` | POST | ✅ |
| `/v1/news/:id` | PUT | ✅ |

### Learn API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/learn/genres` | GET | ✅ |
| `/v1/learn/festivals` | GET | ✅ |
| `/v1/learn/festivals/:id` | GET | ✅ |
| `/v1/learn/festivals` | POST | ✅ |
| `/v1/learn/labels` | GET | ✅ |
| `/v1/learn/labels/:id` | GET | ✅ |
| `/v1/learn/rankings` | GET | ✅ |
| `/v1/learn/rankings/:id` | GET | ✅ |

### Notification Center API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/notification-center/inbox` | GET | ✅ |
| `/v1/notification-center/followed-events/items` | GET | ✅ |
| `/v1/notification-center/followed-djs/items` | GET | ✅ |
| `/v1/notification-center/followed-brands/items` | GET | ✅ |
| `/v1/notification-center/content-reviews/items` | GET | ✅ |
| `/v1/notification-center/unread-count` | GET | ✅ |
| `/v1/notification-center/read` | PUT | ✅ |
| `/v1/notification-center/push-tokens` | POST | ✅ |

### Search & Upload API

| 端点 | 方法 | Flutter 接入 |
|------|------|-------------|
| `/v1/search` | GET | ✅ |
| `/v1/upload/image` | POST | ✅ |
| `/v1/upload/video` | POST | ✅ |
| `/v1/content-submissions` | GET | ✅ |
| `/v1/virtual-assets` | GET | ✅ |
| `/v1/virtual-assets/equip` | PUT | ✅ |

### API 统计

| 状态 | 数量 |
|------|------|
| ✅ 已接入 | 90 |
| ⬜ 未接入 | 0 |
| **合计** | **90** |

---

## 包实现状态汇总

| 包 | 文件数 | LOC | 状态 | 备注 |
|---|--------|-----|------|------|
| `raver_core` | 6 | 536 | ✅ 完成 | 配置/错误/工具 |
| `raver_models` | 20 | 1,364 | ✅ 完成 | 80+ 模型（plain Dart class，无 build_runner） |
| `raver_network` | 8 | 651 | ✅ 完成 | Dio + 4 拦截器 + 上传 |
| `raver_auth` | 4 | 212 | ✅ 完成 | Token 存储 + 刷新门 |
| `raver_i18n` | 6 | 511 | ✅ 完成 | 三语 92 条目 |
| `raver_design_system` | 22 | 3,816 | ✅ 完成 | 5 主题 + 16 组件 |
| `raver_platform` | 10 | 690 | ✅ 完成 | 9 平台服务（含 HarmonyPushAdapter + RaverMapView） |
| `app` | 9 | 1,412 | ✅ 完成 | Shell + Router + State |
| `feature_auth` | 7 | 2,539 | ✅ 完成 | 登录/注册/短信验证 |
| `feature_discover` | 64 | ~11,900 | ✅ 完成 | 9 子模块 + 搜索 + 全部只读浏览 + DJ/Set 编辑 |
| `feature_circle` | 36 | 7,546 | ✅ 完成 | Feed/Squads/IDs/Ratings 全功能 |
| `feature_inbox` | 13 | 2,679 | ✅ 完成 | 5 板块通知中心 + 变更详情 |
| `feature_profile` | 53 | 8,620 | ✅ 完成 | 14 子模块全功能 |
| **合计** | **249** | **40,784** | — | — |

---

## Agent 分工参考

| Agent | 负责包 | 状态 |
|-------|--------|------|
| Agent 1: Foundation | `raver_core`, `raver_network`, `raver_models`, `raver_auth`, `raver_i18n` | ✅ Phase 0 完成 |
| Agent 2: Design System | `raver_design_system`, `raver_platform` | ✅ Phase 0 完成 |
| Agent 3: Discover-Events | `feature_discover/events`, `recommend`, `search` | ✅ Phase 1 完成 |
| Agent 4: Discover-Content | `feature_discover/djs`, `sets`, `news` | ✅ Phase 1 完成 |
| Agent 5: Discover-Wiki | `feature_discover/genres_sunburst`, `organizers`, `labels`, `rankings` | ✅ Phase 1 完成 |
| Agent 6: Circle | `feature_circle` | ✅ Phase 2 完成 |
| Agent 7: Profile + Inbox | `feature_inbox`, `feature_profile` | ✅ Phase 2-3 完成 |
| Agent 8: Auth + App Shell | `feature_auth`, `app` | ✅ Phase 0 完成，Phase 5 待收尾 |

---

## 关键里程碑

| 里程碑 | 目标日期 | 验收标准 | 状态 |
|--------|---------|---------|------|
| M0: 基础设施 | — | App 启动、4 Tab 可见、TabBar 渲染、登录 UI 完整 | ✅ 完成 |
| M1: Discover 可浏览 | — | 9 子标签真实数据、列表+详情全通 | ✅ 完成 |
| M2: Circle + Inbox | — | Feed 可发布、通知可查看、未读 Badge | ✅ 完成 |
| M3: Profile 完整 | — | 个人主页+设置+签到+测验全功能 | ✅ 完成 |
| M4: 内容创建 | — | 活动/DJ/Set 编辑器、多步向导 | ⬜ |
| M5: 三端发布 | — | iOS+Android+HarmonyOS 真机通过、商店提交 | ⬜ |

---

## 更新日志

| 日期 | 更新内容 |
| 2026-06-15 | **iOS 端像素级对齐全量修复（10 处差异）：** RaverFloatingTabBar — 高度66/icon16/label11pt/搜索按钮56px+双阴影/badge 1pt白边/`_SelectionIndicator`从AnimatedPositioned改为SpringSimulation物理弹簧(stiffness≈584, damping≈41.6对应iOS interactiveSpring response:0.26 dampingFraction:0.86)；RaverScrollableTabPager — indicatorWeight 2.5→2.6、label 14→17pt；EventDetailScreen — hero 280→360、4色渐变、标题28pt、NestedScrollView+SliverPersistentHeader、7-Tab per-tab颜色(Info=teal/Lineup=blue/Timetable=green/News=orange/Posts=red/Ratings=gold/Sets=purple)、胶囊按钮borderRadius22；ProfileHeader — avatar 84pt无描边框；ProfileStatsRow — 4列Posts|Followers|Following|Friends；ProfileMeScreen — SliverAppBar 250、渐变+径向高光、Published/Saves/Likes三段；LoginScreen — fillColor 0.14、border-radius 14、PrimaryButton h54/r30、入场动画300ms fastLinearToSlowEaseIn；ProfileSkeleton — circle 84/4 stat列；map_view.dart — 移除flutter_map v7废弃subdomains/bool-retinaMode；inbox_screen_test — LoadPhase.loading()版本修正 |
| 2026-06-15 | **Release 构建基础设施搭建：** Fastlane 全新配置（app/fastlane/Fastfile 6 lanes: ios_beta TestFlight + ios_release App Store + android_beta Google Play internal + android_release production + test_unit melos + test_contract 契约测试 + default lane；app/fastlane/Appfile com.ravehub.app 双端 ID）；三端构建脚本（build_ios.sh/build_android.sh/build_harmony.sh 含 dart-define + obfuscate + ExportOptions.plist）全部 chmod +x；app/ios/ExportOptions.plist（app-store + automatic signing）；App Store/Play Store 元数据 7 文件（en-US + zh-Hans） |
|------|---------|
| 2026-06-15 | **原生桌面小组件实现：** iOS WidgetKit 倒计时小组件新建（RaverCountdownWidgets.swift 318 LOC：EventCountdownEntry 结构体/CountdownTimelineProvider 每小时刷新/CountdownWidgetEntryView 暗紫渐变 systemSmall+systemMedium/RaverCountdownWidgetsBundle @main/UserDefaults group.com.ravehub.app 数据读取/raver://event/{eventId} 深链/无事件占位视图/SwiftUI Previews 3 变体）；Info.plist（NSExtension widget extension 配置）。Android Home Widget 新建（RaverCountdownWidget.kt 110 LOC：AppWidgetProvider/SharedPreferences ravehub_widget_prefs/RemoteViews/PendingIntent raver:// 深链/ISO8601 日期解析/天数计算）；raver_countdown_widget.xml（LinearLayout 暗色 #0D0D0D + 白色文本 + 紫色品牌）；raver_countdown_widget_info.xml（250x110dp/30min 更新/home_screen 分类）。Phase 5.3 桌面小组件全部完成，Phase 5 进度 90%→92% |
| 2026-06-14 | **Widget 测试补全 + pubspec 修复：** feature_circle/test/widget/feed_screen_test.dart 新建（5 用例：LoadPhaseBuilder Loading/Success/Empty/Failure 四态 + GlassCard 渲染，Post/UserSummary 使用真实模型字段）；feature_inbox/test/widget/inbox_screen_test.dart 新建（5 用例：LoadPhaseBuilder 四态 + NotificationSettingsScreen 7个SwitchListTile渲染验证+toggle互动，SharedPreferences mock 配置）；feature_profile/test/widget/settings_screen_test.dart 新建（5 用例：SettingsScreen Account/General/Privacy&About 三组标题 + AppearanceSettingScreen Follow System/Light/Dark 三选项渲染和tap + LanguageSettingScreen 中英日三语显示，GoRouter.router 包装确保 context.push 工作）；feature_inbox/pubspec.yaml 补充 shared_preferences:^2.3.0（NotificationSettingsScreen 使用但原 pubspec 未声明此依赖）。Phase 5 进度 80%→85% |
| 2026-06-14 | **Google Maps 移除 + 平台感知地图替换：** google_maps_flutter 从 feature_circle/pubspec.yaml 移除；raver_platform/feature_discover/feature_circle pubspec.yaml 添加 flutter_map ^7.0.1 + latlong2 ^0.9.1 + apple_maps_flutter ^2.0.0；新建 RaverMapView（map_view.dart）平台感知地图组件（iOS: apple_maps_flutter/MapKit + 注解标注，Android/HarmonyOS: flutter_map/OpenStreetMap + 标记标签 + OSM 归属信息）；raver_platform.dart barrel export 更新；EventMapSection 从 Google Static Maps 静态图片替换为交互式 RaverMapView（全屏模式同步更新）；MapLauncher 文档注释更新（说明内联地图使用 RaverMapView，外部导航保持不变）；HarmonyConfig 文档注释更新（google_maps_flutter NOT used → flutter_map/apple_maps_flutter 替代说明） |
| 2026-06-14 | **编译就绪检查（9 项）：** app.dart 修复——从内联 _buildLightTheme()/_buildDarkTheme() 切换为 RaverThemeData.lightTheme()/darkTheme()，确保 RaverThemeData ThemeExtension 注入到 MaterialApp 主题中，修复 RaverFloatingTabBar context.raver 在暗色模式下回退到 light 默认值的 bug；移除 ~140 行冗余内联主题代码和 _RaverColors 私有类；新增 raver_design_system import。其余 8 项检查均通过无需修改：(1) RaverFloatingTabBar 构造参数匹配 (2) main.dart 入口正确 (3) melos.yaml 正确 (4) 5 feature barrel export 完整 (5) design system barrel 完整 (6) DiscoverServiceLocator 懒加载无需 init (7) app_providers.dart 四大 provider 完整 (8) RaverThemeData.lightTheme()/darkTheme() API 正确 |
| 2026-06-14 | **freezed→plain Dart 全量编译审计：** ViewModel 层审计 7 文件通过（events_list_view_model/event_detail_view_model/recommend_view_model/feed_view_model/compose_post_view_model/post_detail_view_model/inbox_view_model）——无 when/maybeWhen/map/mapOrNull freezed 模式匹配残留，全部使用 ChangeNotifier + raver_design_system LoadPhase。raver_core sealed class 审计通过（LoadPhase 6 子类 + ServiceError 6 子类均为 Dart 3 sealed class 原生语法）。raver_design_system LoadPhaseBuilder 审计通过——使用 Dart 3 `switch (phase) { case LoadPhaseLoading() => ... }` 模式匹配，非 freezed when()。通知模型类名审计通过——feature_inbox 全部引用 NotificationUnreadCount（与 notification.dart 一致，无旧名 UnreadCount 引用）。BFFListPage.fromJson 签名审计通过——15+ 调用点使用 `BFFListPage.fromJson(json, (j) => T.fromJson(j! as Map))` 与 static 泛型方法 `static BFFListPage<T> fromJson<T>(Map, T Function(Object?))` 完全兼容。app_state_notifier.dart Session/UserSummary 构造正确。零 .freezed.dart/.g.dart 遗留文件，零 @freezed/@JsonSerializable/part 指令残留。**结论：零编译问题，无需代码修复** |
| 2026-06-14 | **freezed→plain Dart 迁移清理：** 7 个 pubspec.yaml 清理完成（raver_models 移除 freezed_annotation/json_annotation/build_runner/freezed/json_serializable；feature_discover/circle/inbox/profile/auth 移除 freezed_annotation/json_annotation/riverpod_annotation/build_runner/json_serializable/freezed/riverpod_generator；app 移除 riverpod_annotation/build_runner/riverpod_generator）。数据层审计通过：events_api_service.dart/events_repository.dart/auth_api.dart/dj_api.dart 全部使用正确的 fromJson 工厂方法，无遗留 _$XxxFromJson 模式。raver_auth barrel export 正确。无 riverpod_annotation import 遗留。Phase 5 进度 75%→80% | user.dart 4 类（Session/UserSummary/UserProfile/AuthSessionItem）和 event.dart 12 类（WebEvent/WebEventSchedule/WebEventWeek/WebEventDay/WebEventTicketTier/WebEventLineupSlot/WebEventLineupArtist/WebEventLineupArtistMember/WebEventManualLocation/WebBiText/WebContributorProfile/EventFavoriteStatus）全部从 @freezed 注解转为手写 plain Dart class。每个类包含 final 字段、const 构造函数、fromJson 工厂方法、toJson 方法、copyWith 方法、==运算符、hashCode、toString。移除 freezed_annotation import 和 part 指令。event.dart 使用 listEquals 进行 List 相等性比较。无需再运行 build_runner 即可编译这两个文件 |
| 2026-06-14 | **Phase 5 集成测试桩 + BFF 契约测试：** integration_test/ 4 文件新建（app_test.dart 入口 + auth_flow_test.dart 4 用例（email 登录→Discover/注册→SMS 验证/忘记密码/登出）+ discover_flow_test.dart 3 用例（事件列表→详情/搜索/流派 Sunburst）+ post_flow_test.dart 2 用例（发布动态→Feed/点赞计数），ProviderScope mock 注入架构）；raver_models/test/contract/ 3 文件新建（event_contract_test.dart 3 用例：WebEvent 全字段+空可选字段+列表页反序列化；dj_contract_test.dart 3 用例：WebDJ 全字段+空可选字段+列表页；notification_contract_test.dart 3 用例：AppNotification+NotificationInbox 分页+NotificationUnreadCount 全零/大数值）。JSON Fixture 验证全部 fromJson() 反序列化与 BFF 响应格式对齐 | HarmonyPushAdapter 新建（harmony_push_service.dart: Push Kit MethodChannel 适配器，getPushToken/subscribeToTopic/unsubscribeFromTopic/deleteToken 四方法，PlatformException+MissingPluginException 安全降级）；raver_platform.dart barrel export 更新；HarmonyConfig 新建（harmony_config.dart: minApiLevel=12/targetApiLevel=14/bundleName/pushKitChannel/mapChannel 常量 + HAP 构建说明文档）；MapLauncher HarmonyOS 分支代码注释扩展（Petal Maps petalmaps:// + AutoNavi androidamap:// 深链 + 检测方法 TODO）；VersionCheckService+VersionInfo 新建（version_check_service.dart: GET /v1/app/version + isOlderThan 语义化三段版本比较）；UpdateDialog 新建（update_dialog.dart: 强制更新 PopScope canPop:false + 软更新 Later/Update Now + showIfNeeded 便捷方法）；AppReleaseConfig 新建（app_release_config.dart: 三端 bundleId + App Store/Play Store/AppGallery URL + privacy/terms/support 链接）。Phase 5.4 标记 HAP 包构建配置+推送替换完成，5.7 标记应用内版本更新检查完成。Phase 5 进度 62%→70% | share_card_generator.dart 新建（EventShareCard 暗色渐变卡片布局：封面图/标题/日期+场馆/RAVEHUB 水印 + 紫色描边；ShareCardGenerator.capture 离屏 RepaintBoundary→toImage→PNG Uint8List）；raver_design_system.dart barrel export 更新。Golden 截图测试 2 文件 8 用例：theme_golden_test.dart（GlassCard light/dark 主题 + PrimaryButton enabled/loading/disabled 3 态）、skeleton_golden_test.dart（EventListSkeleton/EventDetailSkeleton/DJListSkeleton 骨架屏）。均使用 matchesGoldenFile，首次运行 flutter test --update-goldens 生成基线 PNG |
| 2026-06-14 | **Phase 5 EventLineupImportScreen + Widget 测试：** 最后一个未实现屏幕 #18 EventLineupImportView 完整实现（EventLineupImportScreen：image_picker 选图→OCR 上传→匹配 DJ CheckboxListTile 选择+置信度 Badge→确认返回 LineupEntry）；events_api_service.dart 新增 LineupImportMatch 类 + importLineupFromImage 方法（POST /v1/events/:eventId/lineup/import-image）；discover_routes.dart 注册路由 /events/:eventId/lineup/import；feature_discover.dart barrel export 更新。Widget 测试 3 组 15 用例：login_screen_test.dart（品牌/Tab/按钮/注册/条款）、events_list_screen_test.dart（LoadPhaseBuilder 五态）、glass_card_test.dart（渲染/blur/radius/child/padding）。屏幕完成率 119/119 = 100%，API 覆盖 90 端点 |
| 2026-06-14 | **Phase 5 路由集成 + Deep Link：** app_router.dart 完成 5 feature 包真实路由接入（移除全部 _PlaceholderScreen/Detail，使用 buildXxxRoutes()+buildXxxDetailRoutes()+_withParentKey 辅助函数，路径从 /app/discover 改为 /discover）；deep_link_handler.dart 重写（toAppPath 主入口+resolve 兼容别名+11 种 raver:// 资源映射+search 查询参数+ravehub.top HTTPS 转发）；deep_link_config.dart 新建（Android/iOS/HarmonyOS 三端配置文档+AASA+assetlinks.json 示例）；route_guards.dart 扩展至 15 个受保护前缀（覆盖全部详情路由）+auth-only 增加 /register /forgot-password；bootstrap.dart 新增 setupPushNotificationDeepLinks（推送点击→DeepLinkHandler→GoRouter.go）；main.dart runApp 后调用 setupPushNotificationDeepLinks |
| 2026-06-14 | **Phase 5 性能优化 + App Icon/Splash 配置：** GenreSunburstPainter RepaintBoundary 隔离 + shouldRepaint 补全 isDark/maxDepth；main.dart orientation lock shader warmup + PaintingBinding image cache（150/100MB）+ flutter_native_splash 预热占位；EventsListScreen cacheExtent:500 + addRepaintBoundaries:true；DjsListScreen CustomScrollView cacheExtent:500 + SliverChildBuilderDelegate addRepaintBoundaries:true；pubspec.yaml 新增 flutter_launcher_icons ^0.14.1 + flutter_native_splash ^2.4.3 + 三端配置 + assets 目录声明；assets/icon/ + assets/splash/ .gitkeep 占位；MapLauncher HarmonyOS Petal Maps / AutoNavi 适配注释 |
| 2026-06-14 | **Phase 5 屏幕补全（6 屏）：** PasswordResetScreen（暗色渐变+邮箱输入+PasswordResetNotifier+AuthApi.resetPassword）、RecommendDetailSheet（DraggableScrollableSheet+RemoteCoverImage+日期/地点/描述+跳转详情）、RankingEntryDetailScreen（ConsumerWidget+从 RankingDetailProvider 查找 entry+头像/排名/Delta/DJ链接）、OrganizerListFilterSheet（国家筛选+Reset/Apply）、LabelListFilterSheet（风格筛选+Reset/Apply）、NotificationSettingsScreen（7 SwitchListTile+SharedPreferences 持久化）。路由更新：auth_routes +/forgot-password、discover_routes +/rankings/:boardId/entries/:entryId、inbox_routes +/settings/notifications。Barrel export 同步更新。屏幕覆盖率 118/119 = 99.2% |
| 2026-06-14 | **Phase 5 推送通知基础：** PushNotificationService（FCM + HarmonyOS Platform Channel 抽象，singleton 模式），NotificationApiService.registerPushToken（POST /v1/notification-center/push-tokens），bootstrap.dart 重构（PushNotificationService 集成 + 静态 token 缓存 + session 感知自动注册 + registerPushTokenIfNeeded 公开方法），PushRouter（推送点击→GoRouter 路由映射，支持 event/dj/post/squad/news 5 种类型）。API 接入率 89/89 = 100% |
| 2026-06-14 | **Phase 4 DJ/Set 内容创建：** DjImportScreen（Spotify/Discogs/手动三Tab导入）、DjEditorScreen（头像/名称/简介/国籍/流派标签/社交链接编辑）、SetEditorScreen（标题/描述/日期/关联DJ&活动/音视频上传/曲目预览）、TracklistEditorScreen（ReorderableListView逐曲编辑+FAB添加+BottomSheet表单）。DjEditorViewModel + SetEditorViewModel（ChangeNotifier模式）。DjApi 增加 5 个写方法，SetApi 增加 4 个写方法。屏幕覆盖率 116/119 = 97.5%，API 接入率 80/89 = 89.9% |
| 2026-06-14 | **Phase 1-3 并行完成：** 3 Agent 并行执行，249 文件 / 40,784 LOC。Event 详情补全 6 Section + FilterSheet；Inbox 通知中心 5 板块完整实现（13 文件 / 2,679 LOC）；Circle 全模块完整实现（36 文件 / 7,546 LOC，Feed/Squads/IDs/Ratings）；Profile 全模块完整实现（53 文件 / 8,620 LOC，14 子模块）。屏幕对齐率 107/119 = 89.9%，API 接入率 74/89 = 83.1% |
| 2026-06-14 | Phase 1.7-1.10 (Agent 5)：Genres Sunburst CustomPainter 可视化（极坐标渲染+命中测试+展开动画+20色调色板）、Organizers 列表+详情+骨架屏、Labels 列表+详情、Rankings 列表+详情（金银铜奖牌+Delta），7 个 Learn API 端点接入，8 个新屏幕完整实现 |
| 2026-06-14 | Phase 1.4-1.6 (Agent 4)：News 列表+详情、DJ 列表+Spotlight+详情+关注、Sets 2列网格+详情+Tracklist+视频播放+评论 完整实现，10 个 API 端点接入 |
| 2026-06-14 | Phase 0 完成：134 文件 / 12,334 LOC / 全部 core 包 + app shell + feature_auth 完整实现 |
