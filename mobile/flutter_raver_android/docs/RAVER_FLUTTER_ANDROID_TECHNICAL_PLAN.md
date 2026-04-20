# Raver Flutter Android 技术路线与实现方案

创建日期：2026-04-19  
适用目录：`/Users/blackie/Projects/raver/mobile/flutter_raver_android`  
目标：用 Flutter 复现现有 iOS 原生 App 的 Android 版本，并尽可能保持与 iOS 原生开发相同的工程体验、交互品质、导航语义和业务能力。

## 0. 当前结论

推荐方案是：**Flutter 单独承载 Android App，复用现有 Node/Express BFF，架构对齐 iOS 的 MVVM + Coordinator + Repository + Service。**

不要先做一层简单 WebView，也不要直接把 iOS 页面逐行翻译成 Flutter Widget。Raver iOS 已经进入“全局单导航栈 + Coordinator + Repository”的状态，Flutter 侧应从第一天就按这个结构建，不然 Android 很快会出现另一套导航和状态债务。

本机现状：

- 仓库根目录：`/Users/blackie/Projects/raver`
- iOS 工程：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP`
- 本机当前没有 `flutter` 命令，因此本次没有直接运行 `flutter create`
- 已提供启动脚本：`/Users/blackie/Projects/raver/mobile/flutter_raver_android/scripts/bootstrap_flutter_project.sh`

Flutter 项目生成后建议路径：

```text
/Users/blackie/Projects/raver/mobile/flutter_raver_android/app/raver_android
```

## 0.1 文档体系

本文件是总技术路线图，负责回答“为什么这样做、整体怎么分阶段做、架构边界是什么”。每个底层能力、业务板块和页面的详细复刻方法已经拆到独立 Markdown：

- 总目录：`DOCUMENTATION_INDEX.md`
- 基础能力：`foundation/`
- 页面与业务：`pages/`
- 对齐检查：`IOS_ANDROID_PARITY_CHECKLIST.md`

执行规则：

1. 新功能先读本总图，再读对应 `foundation/` 和 `pages/` 文档。
2. 每个页面实现前，必须确认页面文档里的 iOS 来源、Flutter 目标路径、API、状态、步骤、验收。
3. 如果 iOS 页面或 BFF 契约变化，先更新对应页面文档，再改 Flutter。
4. 每完成一个页面，在 `IOS_ANDROID_PARITY_CHECKLIST.md` 标记状态。

## 1. 调研依据

### 1.1 本地项目依据

现有 iOS 端关键事实：

- App 入口：`RaverMVPApp.swift` 创建 `AppContainer`、`AppState`，渲染 `AppCoordinatorView`
- 根流：`AppCoordinatorView` 根据登录态切换 `MainTabCoordinatorView` 或 `LoginView`
- 主导航：`MainTabCoordinatorView` 使用单一 `NavigationStack(path:)` + `AppRouter`
- 路由：`AppRoute` 已收敛公共详情页，包含 event/dj/set/post/user/squad/conversation/rating 等语义
- Tab：Discover / Circle / Messages / Profile
- DI：`AppContainer` 注入 `SocialService`、`WebFeatureService` 和各 feature repository
- 运行模式：`AppConfig` 支持 mock/live，默认 BFF 是 `http://localhost:8787`
- i18n：当前 iOS 使用 `L(zh,en)` 和 `AppLanguagePreference`
- 视觉：`RaverTheme` 使用动态 light/dark 色，底部 Tab 是自定义胶囊毛玻璃样式
- 媒体：iOS 内含图片缓存、视频播放、图片/视频上传、横竖屏控制

### 1.2 官方资料依据

- Flutter macOS + Android 安装文档：<https://docs.flutter.dev/get-started/install/macos/mobile-android>
- Flutter 架构指南：<https://docs.flutter.dev/app-architecture/guide>
- Flutter Platform Channels：<https://docs.flutter.dev/platform-integration/platform-channels>
- Flutter Android 发布：<https://docs.flutter.dev/deployment/android>
- Flutter 测试文档：<https://docs.flutter.dev/testing/overview>
- Google Play target API 要求：<https://developer.android.com/google/play/requirements/target-sdk>
- go_router package：<https://pub.dev/packages/go_router>
- Riverpod package：<https://pub.dev/packages/flutter_riverpod>

截至 2026-04-19，Google Play 官方要求是：从 2025-08-31 起，新 App 和更新必须 target Android 15/API 35 或更高；Android 15 以下设备兼容要求不等于 target 要求，实际 minSdk 可按产品覆盖面单独设定。

## 2. 产品目标

Android Flutter 版不只是“能跑”，而是要达到以下体验目标：

- **导航像原生 App**：底部自定义 Tab、详情页隐藏/显示 Tab 的规则、沉浸式返回、sheet/fullscreen 语义与 iOS 保持一致。
- **交互像原生 App**：Android 使用系统返回手势、系统权限弹窗、系统分享/地图/相册入口；视觉层复刻 Raver 的品牌，而不是简单 Material 默认样式。
- **工程像原生开发**：强类型模型、清晰路由、ViewModel 驱动状态、Repository 接 BFF、Mock/Live 可切换、可做 golden/widget/integration test。
- **业务复用 BFF**：不在 Flutter 里重复业务算法，优先复用 `/v1` BFF 契约。
- **先稳定核心链路**：先让 Discover、活动详情、DJ 详情、Sets、登录、Tab 导航跑通，再逐步补齐发布/编辑/上传/消息。

## 3. 技术选型

### 3.1 Flutter 与 Android 基线

建议：

- Flutter：稳定版 stable channel，使用本机 `flutter doctor -v` 的结果作为锁定基线
- Dart：跟随 Flutter stable
- Android Studio：官方最新版稳定渠道
- Android Gradle Plugin / Gradle：由 `flutter create` 生成后再按 Flutter 官方推荐升级
- minSdk：23 起步
- targetSdk：至少 35
- compileSdk：跟随 Flutter/Android SDK 最新稳定
- 架构：仅 Android，暂不生成 iOS/macOS/web 桌面平台，避免维护面扩大

为什么 minSdk 先定 23：

- 覆盖绝大多数仍有现实意义的 Android 设备
- 支持运行时权限模型
- 避免过早处理 Android 5.x/6.x 的大量兼容问题

若后续目标用户明显偏新机，可提高到 minSdk 26，以简化通知、媒体、存储和 TLS 兼容。

### 3.2 App 架构

Flutter 侧采用：

```text
View / Widget
  -> ViewModel / Notifier
  -> UseCase
  -> Repository
  -> Service / API Client
  -> BFF
```

与 iOS 对应关系：

| iOS | Flutter |
|---|---|
| SwiftUI View | Widget / Screen |
| ObservableObject ViewModel | Riverpod AsyncNotifier / Notifier / StateNotifier |
| AppContainer | Riverpod Provider graph |
| Coordinator + AppRouter | go_router + typed route wrappers |
| SocialService/WebFeatureService | Retrofit/Dio API services |
| URLSession request helper | Dio interceptors + generated clients |
| UserDefaults | shared_preferences |
| Keychain token | flutter_secure_storage |
| RaverTheme | ThemeExtension + design tokens |

核心原则：

- View 不直接调用 Dio，不直接拼 URL
- 路由参数尽量 ID 化，与 iOS 的 AppRoute S6 结果一致
- 全局状态只放 session/language/theme/unread/banners 这种真正跨模块状态
- 列表分页、搜索、编辑表单状态归 feature ViewModel
- 复杂业务动作放 UseCase，避免 ViewModel 变成大杂烩

### 3.3 状态管理

推荐：`flutter_riverpod`

原因：

- Provider graph 与 iOS `AppContainer` 思路接近
- 易于 mock API、切换 live/mock runtime
- AsyncNotifier 适合列表/详情/分页状态
- widget test 可覆盖依赖注入

用法约定：

- `Provider`：Dio、配置、repository、usecase
- `NotifierProvider`：同步 UI 状态，例如 tab selection、theme、language
- `AsyncNotifierProvider`：详情页、列表首屏、远程配置
- `StateProvider` 只用于非常局部、短生命周期的 UI 状态

### 3.4 网络层

推荐：

- `dio`：HTTP client、interceptor、multipart、timeout、cancel token
- `retrofit` + `json_serializable`：生成 API client
- `freezed`：不可变 state 和 union 状态

网络层必须支持：

- `RAVER_BFF_BASE_URL` 等价配置
- mock/live runtime mode
- Bearer token 自动注入
- 401 统一触发 session expired
- BFF envelope 解包
- multipart 上传
- 列表分页
- 请求取消，避免搜索输入快速变化导致旧结果覆盖新结果
- 日志开关，仅 debug 打印

建议默认 base URL：

```text
Android emulator: http://10.0.2.2:8787
Physical device:  http://<Mac LAN IP>:8787
iOS/current docs: http://localhost:8787
```

Flutter 里不要硬编码 `localhost` 给 Android 模拟器；Android 模拟器访问宿主机要用 `10.0.2.2`。

### 3.5 本地存储与缓存

推荐分层：

- Token：`flutter_secure_storage`
- 用户偏好：`shared_preferences`
- 结构化离线缓存：`drift` + SQLite
- 图片缓存：`cached_network_image`
- 临时文件：`path_provider`

首期只做：

- token 安全存储
- language/theme/runtime/baseURL 偏好
- 图片缓存
- Discover/events/djs/sets 首屏只读缓存

第二期再做：

- feed 草稿缓存
- 上传草稿媒体清理
- check-in 离线队列
- 消息最近会话缓存

### 3.6 导航

推荐：`go_router` + `ShellRoute` 或 `StatefulShellRoute`

目标与 iOS 对齐：

```text
AppRouter
  /login
  /app
    shell tabs:
      /discover
      /circle
      /messages
      /profile
    details:
      /events/:eventId
      /djs/:djId
      /sets/:setId
      /posts/:postId
      /users/:userId
      /squads/:squadId
      /conversations/:conversationId
      /ratings/units/:unitId
```

实现规则：

- Tab 根页面保留状态，切换 Tab 不重建已加载页
- 公共详情页不重复定义在各 Tab 下
- 页面是否隐藏 TabBar 由 route metadata 决定
- Android 系统返回键等价于 pop；Tab 根页返回可二次确认退出
- sheet/fullscreen 用统一 presentation helper，不散落 `showModalBottomSheet`
- deep link 直接进入详情时，先完成 session bootstrap，再加载 loader screen

### 3.7 UI 与设计系统

Flutter 侧建立 `RaverThemeData`：

```text
core/design_system/
  colors.dart
  typography.dart
  spacing.dart
  radii.dart
  shadows.dart
  motion.dart
  theme.dart
```

从 iOS `RaverTheme` 迁移 token：

- background light `#F7F7FB` / dark near `#08080A`
- card light `#FFFFFF` / dark near `#1C1C1F`
- accent light approx `#6B42DB` / dark approx `#8C5CF5`
- tab chrome gradient and selected capsule gradient

Flutter 控件策略：

- App 主框架用自定义 `Scaffold` + bottom tab bar，不直接使用默认 `BottomNavigationBar`
- 列表页遵循 Material 滚动手感，但视觉按 Raver 定制
- 沉浸式详情页使用 `CustomScrollView` + `SliverAppBar`/自定义 overlay
- 标准返回页使用统一 `RaverNavigationChrome`
- 输入框、按钮、标签、头像、卡片全部抽成 core widgets
- 保留 light/dark，默认跟随系统
- 字体优先使用仓库已有 `altehaasgroteskbold.ttf` 做品牌标题，正文使用系统字体

### 3.8 媒体能力

Flutter 侧等价能力：

- 图片加载：`cached_network_image`
- 图片选择：`image_picker`
- 权限：`permission_handler`
- 视频播放：`video_player` + `chewie`
- 音频预览：`just_audio`
- 外链打开：`url_launcher`
- 视频横屏：Android 通过 platform channel 或 `SystemChrome.setPreferredOrientations`

KSPlayer 的 iOS 能力不直接迁移。Flutter Android 先用 `video_player` 跑通 mp4/m3u8 主链路；如果遇到 HLS/缓存/倍速/后台播放要求，再评估 Better Player、Media3 或自写 Android platform view。

### 3.9 原生桥接

优先用成熟 Flutter 插件；只有以下场景用 platform channel：

- Android 端强制/恢复横竖屏策略无法满足现有详情页播放器体验
- 系统日历、地图、分享需要更细粒度控制
- 推送 token 或厂商通道
- 后台任务/通知点击 deep link
- 复杂媒体能力需要接 Android Media3

Platform channel 的边界必须在 `core/platform`，不要从 feature screen 直接调用 channel。

## 4. 目标目录结构

Flutter app 生成后建议结构：

```text
mobile/flutter_raver_android/app/raver_android/
  lib/
    main.dart
    app/
      app.dart
      bootstrap.dart
      di/
      router/
    core/
      config/
      design_system/
      i18n/
      networking/
      persistence/
      platform/
      widgets/
    features/
      auth/
        data/
        domain/
        presentation/
      discover/
        recommend/
        events/
        news/
        djs/
        sets/
        learn/
        search/
        shared/
      circle/
        feed/
        squads/
        ids/
        ratings/
      messages/
      profile/
      media/
  test/
  integration_test/
  android/
```

feature 内部约定：

```text
feature_name/
  data/
    api/
    dto/
    repositories/
  domain/
    models/
    repositories/
    use_cases/
  presentation/
    screens/
    view_models/
    widgets/
```

## 5. BFF 接入方案

### 5.1 API 分组

按 iOS 的 `LiveSocialService` 与 `LiveWebFeatureService` 拆两个 client：

```text
SocialApiClient
  auth
  feed
  users
  squads
  chat
  profile
  notifications

WebFeatureApiClient
  events
  djs
  dj_sets
  checkins
  ratings
  learn
  publishes
  uploads
```

后续如文件膨胀，再拆：

- `AuthApi`
- `DiscoverApi`
- `CircleApi`
- `MessagesApi`
- `ProfileApi`
- `UploadApi`

### 5.2 必接首批接口

首批 P0/P1：

- `POST /v1/auth/login`
- `POST /v1/auth/register`
- `GET /v1/profile/me`
- `GET /v1/notifications/unread-count`
- `GET /v1/events`
- `GET /v1/events/recommendations`
- `GET /v1/events/:id`
- `GET /v1/djs`
- `GET /v1/djs/:id`
- `GET /v1/dj-sets`
- `GET /v1/dj-sets/:id`
- `GET /v1/learn/genres`
- `GET /v1/learn/labels`
- `GET /v1/learn/festivals`

P2：

- follow/unfollow DJ
- checkins CRUD
- feed list/post/comment/like/repost
- messages conversations/messages
- image/video upload
- set comments and tracklists

P3：

- event editor
- DJ import/edit
- set editor
- rating events/units editor
- wiki/festival/ranking editor

### 5.3 数据模型

优先从 Swift `Codable` 模型迁移到 Dart DTO，不从数据库 schema 直接推导，因为 iOS 已经暴露了实际客户端契约。

命名规则：

- BFF DTO：`WebEventDto`, `WebDjDto`, `FeedPostDto`
- Domain model：`RaverEvent`, `DjProfile`, `DjSet`, `Post`
- UI model：必要时用 `EventCardViewData`，不要滥用

日期：

- iOS `JSONDecoder.raver` 处理 Date；Flutter 侧统一用 `DateTime.parse` + UTC/local 明确转换
- 所有日历、演出时间、lineup slot 必须留意跨天、跨时区

## 6. iOS 体验复刻重点

### 6.1 主 Tab

iOS 现状：

- Discover / Circle / Messages / Profile
- 自定义胶囊 TabBar
- 选中项紫色渐变胶囊
- 非选中项灰色文字
- 某些详情页隐藏 TabBar

Flutter 实现：

- `RaverShellScaffold`
- `IndexedStack` 或 `StatefulShellRoute` 保留各 tab state
- `RaverFloatingTabBar` 复刻胶囊背景、渐变、阴影、选中动画
- route meta `hideBottomBar`

### 6.2 Discover

iOS Discover 子栏目：

- 推荐 Picks
- 活动 Events
- 资讯 News
- DJ
- Sets
- Wiki

Flutter 先做：

- 顶部品牌/搜索入口
- 横向 tab pager
- 每个栏目先接 mock repo，再换 BFF
- 搜索使用全屏 search screen，结果按栏目分模块

### 6.3 详情页

重点页：

- EventDetail
- DJDetail
- DJSetDetail
- UserProfile
- PostDetail
- SquadProfile
- RatingUnitDetail

Flutter 统一：

- loader screen 只收 ID
- 大图 hero + 悬浮返回
- pinned tab bar 用 `SliverPersistentHeader`
- 内容子 tab 保持懒加载
- bottom action area 避免与系统 navigation bar 冲突

### 6.4 表单与上传

首期只做必要上传：

- 发帖图片/视频
- 活动封面/阵容图
- DJ 头像/banner
- Set 缩略图/视频

策略：

- 图片选择后先本地预览
- 上传前压缩和 MIME 校验
- 上传进度进入 ViewModel
- 失败可重试
- 创建/编辑接口只存上传返回 URL

### 6.5 登录与 Session

实现：

- App 启动先从 secure storage 读取 token
- 若 token 存在，调用 `/v1/profile/me` 验证
- 401 清空 token，跳 login
- login/register 成功后写 token 并刷新全局 app state
- `Dio` interceptor 自动注入 Bearer token

## 7. 开发环境路线

### 7.1 安装

官方路线：

1. 安装 Android Studio
2. 安装 Flutter SDK stable
3. 配置 shell PATH
4. 运行 `flutter doctor -v`
5. 接受 Android licenses
6. 创建 Android emulator 或连接真机

建议命令：

```bash
# Flutter SDK 安装完成后
flutter doctor -v
flutter doctor --android-licenses

cd /Users/blackie/Projects/raver/mobile/flutter_raver_android
./scripts/bootstrap_flutter_project.sh
```

### 7.2 后端联调

本地后端：

```bash
cd /Users/blackie/Projects/raver
docker-compose up -d

cd /Users/blackie/Projects/raver/server
pnpm dev
```

Android 模拟器访问：

```text
RAVER_BFF_BASE_URL=http://10.0.2.2:8787
```

真机访问：

```text
RAVER_BFF_BASE_URL=http://<Mac局域网IP>:8787
```

## 8. 分阶段实施计划

### Phase 0: 环境与工程基座

目标：生成 Flutter 项目并建立工程规则。

任务：

- 安装 Flutter/Android Studio
- 运行 `bootstrap_flutter_project.sh`
- 建立 `analysis_options.yaml`
- 建立 `app/bootstrap.dart`
- 建立 `core/config/AppConfig`
- 建立 `core/design_system`
- 建立 `go_router` 根路由
- 建立 `Riverpod` provider graph
- 建立 `Dio` client 和 token interceptor

验收：

- `flutter doctor -v` 无关键错误
- `flutter analyze` 通过
- `flutter test` 通过
- Android emulator 能打开空 shell app

### Phase 1: App Shell 与认证

目标：跑通登录态、四 Tab、mock/live 切换。

任务：

- Splash/bootstrap session
- Login/register screen
- secure token storage
- Main shell + floating TabBar
- route meta 控制 TabBar 显隐
- language/theme/runtime settings
- unread count 拉取

验收：

- 未登录打开 Login
- 登录后进入 Discover
- 关闭重启仍保持登录
- 401 自动退登
- 四 Tab 切换不丢状态

### Phase 2: Discover 核心只读链路

目标：用户可浏览核心内容。

任务：

- Discover home pager
- Events list/recommend/detail
- DJs list/detail
- Sets list/detail/tracklists
- Wiki genres/labels/festivals
- Search shell
- common card/image/empty/loading/error/retry widgets

验收：

- 可用 BFF 数据打开活动、DJ、Set 详情
- 列表分页、下拉刷新、搜索可用
- 图片缓存可用
- 系统返回行为符合 Android 预期

### Phase 3: 社交与个人中心

目标：形成完整用户闭环。

任务：

- Circle feed
- Post detail/comment/like/repost
- Compose post with image upload
- Messages conversations/chat
- Profile me/public profile
- follow/followers/following/friends
- my checkins/my publishes
- squads read/join/basic settings

验收：

- 用户能发帖、评论、点赞、私信
- 个人主页数据与 iOS/BFF 一致
- 上传失败/弱网有明确状态

### Phase 4: 活动/DJ/Set/Rating 编辑能力

目标：补齐 iOS 的内容生产和编辑工具。

任务：

- Event editor
- Lineup import image
- DJ import from Spotify/Discogs/manual
- DJ editor
- Set editor
- Tracklist editor
- Rating event/unit editor
- Wiki/festival/ranking editor

验收：

- 与 iOS 创建/编辑同一类数据，BFF 数据无兼容问题
- 大表单支持草稿、校验、上传进度、失败重试

### Phase 5: Android 原生体验打磨

目标：让 Flutter App 在 Android 上像认真做过的原生应用。

任务：

- Android back behavior matrix
- Deep links/app links
- Share sheet
- Maps/calendar external intents
- Push notification
- Media fullscreen/orientation
- Permission education UI
- Performance profiling
- Golden screenshot regression
- Play release signing

验收：

- 低端机列表滚动无明显 jank
- 详情页 hero/Tab/header 动画稳定
- Android 12-15 真机/模拟器通过 smoke
- `flutter build appbundle --release` 成功

## 9. 测试策略

### 9.1 测试分层

- Unit test：model parse、usecase、repository mock
- Widget test：关键 card、empty/error/loading、form validation
- Golden test：TabBar、EventCard、DJCard、详情页 hero、dark/light
- Integration test：login -> discover -> detail -> back -> tab switch
- Contract test：BFF DTO fixture decode
- Manual smoke：Android emulator + 真机

### 9.2 必备回归矩阵

首批必须覆盖：

- 未登录 -> 登录 -> Discover
- Discover Events -> EventDetail -> back
- Discover DJs -> DJDetail -> follow -> back
- Discover Sets -> SetDetail -> video preview
- Circle Feed -> PostDetail -> comment
- Messages -> Conversation -> send message
- Profile -> My Checkins -> EventDetail
- 401 token expired
- light/dark/theme switch
- zh/en language switch

## 10. 性能策略

首期硬指标：

- 冷启动到首屏 shell：开发机 debug 不超过 3s；release 后再定严值
- 列表滚动：避免同步 JSON 大解析阻塞主 isolate
- 图片：必须设置尺寸、placeholder、错误态、缓存
- 搜索：debounce 300ms，取消旧请求
- 详情页：首屏优先加载基本信息，评论/关联内容懒加载
- 视频：列表不自动播放，详情页用户主动播放

工具：

- Flutter DevTools
- `flutter run --profile`
- Performance overlay
- `flutter build apk --analyze-size`

## 11. 发布与合规

Android 发布路线：

- 配置 applicationId：`com.raver.android`
- 配置 app name、icon、adaptive icon
- 配置 signing key，不提交私钥
- `flutter build appbundle --release`
- targetSdk 至少 35
- network security config 仅 debug 允许 cleartext 本地 HTTP
- release 必须使用 HTTPS BFF
- 权限最小化：相册/相机/通知/定位按需申请
- 隐私政策覆盖上传、位置、通知、社交数据

debug/release 差异：

- debug 可使用 `10.0.2.2:8787`
- release 禁止明文 HTTP
- release 禁止 verbose 网络日志
- release crash/reporting 后续可接 Sentry/Firebase Crashlytics

## 12. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| iOS 仍快速演进 | Android 复刻目标漂移 | 每周从 iOS route/API/UI 做一次 diff 清单 |
| BFF 契约无 OpenAPI | DTO 手写易错 | 从 Swift Codable + BFF route 建 fixture，后续补 OpenAPI |
| 视频能力差异 | Sets 体验下降 | 先 video_player，复杂场景切 Media3 platform channel |
| Android 本地路径/权限复杂 | 上传失败 | 统一 file picker/upload service，真机验证 |
| Flutter 默认 Material 味太重 | 不像 Raver/iOS | 从第一天建设 design_system 和自定义 Tab/navigation chrome |
| 导航散落 | 后续维护痛苦 | 所有 push/sheet/fullscreen 走 router/presentation helper |
| 离线缓存过早复杂化 | 延误首版 | P0/P1 只做 token/prefs/image，结构化缓存逐步加 |

## 13. 第一周可执行任务

Day 1:

- 安装 Flutter/Android Studio
- 跑 `flutter doctor -v`
- 执行 bootstrap 脚本
- 建立 lint/test baseline

Day 2:

- 建 `AppConfig`、`DioClient`、`TokenStore`
- 建 mock/live runtime
- 建 Router shell

Day 3:

- 复刻 Raver floating tab bar
- 建 light/dark theme tokens
- 建 common image/card/loading/error widgets

Day 4:

- 登录/注册/session bootstrap
- profile me 验证 token
- 401 退登

Day 5:

- Discover shell + 子栏目 pager
- Events repository + list/detail
- 首个 integration smoke

第一周结束交付：

- Android emulator 可登录进入四 Tab
- Discover/Events 基本浏览可用
- 工程结构、测试、网络、主题、路由都已成型

## 14. 决策记录

| 决策 | 结论 |
|---|---|
| 是否用 Flutter 做 iOS + Android 双端 | 现阶段只生成 Android，避免影响已有 iOS 原生工程 |
| 是否复用现有 BFF | 是，Flutter 不重写后端业务 |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 网络 | Dio + Retrofit + JSON generated models |
| 本地数据库 | Drift，分阶段引入 |
| iOS KSPlayer 能力 | Android 首期 video_player/chewie，必要时 Media3 bridge |
| 工程生成 | 等 Flutter SDK 安装后由 bootstrap 脚本生成 |

## 15. 后续文档建议

建议在 Flutter 项目生成后补充：

- `docs/API_CONTRACTS.md`
- `docs/ANDROID_NAVIGATION_MATRIX.md`
- `docs/ANDROID_DESIGN_TOKENS.md`
- `docs/ANDROID_RELEASE_RUNBOOK.md`

当前已先建立 `docs/IOS_ANDROID_PARITY_CHECKLIST.md`，作为后续复刻体验的核对表。其余文档不用一开始写满，但每个阶段完成时应该同步更新。
