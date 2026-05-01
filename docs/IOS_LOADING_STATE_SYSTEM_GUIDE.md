# Raver iOS 加载态系统设计规范

- 文档版本：v1.1
- 创建日期：2026-05-01
- 最近更新：2026-05-01
- 适用仓库：`/Users/blackie/Projects/raver`
- 适用范围：`mobile/ios/RaverMVP/RaverMVP`
- 适用技术栈：SwiftUI + UIKit Bridge + MVVM + Coordinator
- 文档目标：
  - 统一 iOS App 在弱网、慢接口、分页、下拉刷新、上传、提交、登录恢复等场景下的加载体验
  - 作为后续 iOS 页面开发、重构、提测、回归的执行标准
  - 让 ViewModel 的状态设计和 View 的反馈设计形成统一约束，避免每个页面各写一套
  - 作为本轮改造的唯一进度跟踪台账，确保页面改造有清单、有状态、有验收

---

## 0. 实施进度台账

本节从现在开始作为加载态系统改造的主进度表使用。

后续执行规则：

1. 每完成一批共享组件或页面改造，必须先更新这里，再继续下一批
2. 页面状态统一使用：
   - `未开始`
   - `进行中`
   - `已完成`
   - `已完成，待弱网验收`
3. “已完成”只表示代码已接入，不代表体验已经完全验收
4. 最终交付标准不是“文档写完”，而是本节所有目标页面进入 `已完成`

### 0.1 当前阶段

- 当前阶段：`Phase 3 - 核心详情、路由壳与 MainTab 聚合页推进中`
- 当前目标：
  - 先完成共享反馈底座
  - 再完成高频核心页面
  - 再完成剩余详情页、列表页、聚合页

### 0.2 共享能力进度

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| `LoadPhase` | 已完成 | 统一一级状态模型 |
| `ScreenStatusBanner` | 已完成 | 顶部轻量错误/刷新提示 |
| `ScreenErrorCard` | 已完成 | 页面级失败态 |
| `FeedSkeletonView` | 已完成 | 列表骨架 |
| `SearchResultsSkeletonView` | 已完成 | 搜索结果骨架 |
| `ProfileSkeletonView` | 已完成 | 个人主页骨架 |
| `NotificationListSkeletonView` | 已完成 | 通知骨架 |
| `EventDetailSkeletonView` | 已完成 | 活动详情骨架 |
| `FollowListSkeletonView` | 已完成 | 关注/粉丝列表骨架 |
| `SquadProfileSkeletonView` | 已完成 | 小队详情骨架 |
| `CommentSectionSkeletonView` | 已完成 | 评论区骨架 |
| `DJDetailSkeletonView` | 已完成 | DJ 详情骨架 |
| `SetDetailSkeletonView` | 已完成 | Set 详情骨架 |
| `Coordinator Loader Scaffold` | 已完成 | 路由级加载壳统一为骨架 + 失败卡片 |
| `FormStatusMessage` | 已完成 | 表单内轻量失败提示统一组件 |

### 0.3 页面改造进度

| 页面 | 状态 | 说明 |
| --- | --- | --- |
| `Feed` | 已完成 | 首屏骨架、刷新保留旧内容、分页 loading |
| `Search` | 已完成 | 搜索空闲态、首屏骨架、失败提示 |
| `UserProfile` | 已完成 | 首屏骨架、刷新 banner、分页保留 |
| `Notifications` | 已完成 | 通知骨架、空态/失败态分离 |
| `EventDetail` | 已完成 | 详情骨架、失败卡片、缓存回退提示 |
| `PostDetail` | 已完成 | 评论区骨架、刷新保留旧评论 |
| `FollowList` | 已完成 | 列表骨架、分页 loading、失败卡片 |
| `SquadProfile` | 已完成 | 首屏骨架、刷新 banner、失败卡片 |
| `Profile` | 已完成 | 首屏骨架、离线快照提示、刷新 banner |
| `DJ Detail` | 已完成 | 详情骨架、缓存回退 banner |
| `Set Detail` | 已完成 | 详情骨架、刷新 banner |
| `MessagesHome` | 已完成 | 会话骨架、失败卡片、刷新 banner |
| `DiscoverRoute` 路由壳 | 已完成 | 编辑/详情加载壳统一为骨架 + 失败卡片 |
| `MyCheckins` | 已完成 | 首屏骨架、刷新 banner、失败卡片 |
| `DJs` 列表页 | 已完成 | 首屏骨架、刷新 banner、失败卡片 |
| `Sets` 列表页 | 已完成 | 首屏骨架、刷新 banner、失败卡片 |
| `MainTab` 聚合模块 | 已完成 | 已完成 Squads、Rating Events、Event/DJ Picker、Event Import、Rating Event Detail、Rating Unit Detail |
| `News` 列表页 | 已完成 | 首屏骨架、刷新 banner、页面内失败卡片 |
| `News Detail` | 已完成 | 评论区骨架、评论失败卡片、发送失败内联提示 |
| `Coordinator` 路由加载壳 | 已完成 | MainTab/Circle 协调器内的详情与编辑加载壳已统一 |
| `RecommendEvents` | 已完成 | 首屏骨架、刷新 banner、失败卡片 |
| `DiscoverSearch` 结果页 | 已完成 | Events/News/DJs/Sets/Wiki 搜索结果统一骨架、刷新 banner、失败卡片 |
| `Learn` 模块 | 已完成 | Rankings/Genres/Labels/Festivals 首屏骨架、刷新保留、失败卡片 |

### 0.4 当前剩余主任务

1. 继续把剩余表单类动作失败反馈迁移到 `FormStatusMessage`
2. 继续扫描零散详情页和局部模块中的旧 loading
3. 后续新增页面默认按本规范直接接入，不再新增旧式 loading 写法

### 0.5 验收回填规则

每个页面从 `已完成，待弱网验收` 升级到 `已完成` 之前，至少要检查：

1. 首屏进入是否为骨架，而非空白或纯转圈
2. 下拉刷新是否保留旧内容
3. 请求失败是否为页面内错误态，而不是卡死
4. 弱网/超时是否出现轻量提示
5. 分页是否只影响底部，不影响整页

---

## 1. 为什么要单独建设这套系统

当前 iOS App 已经逐步迁移到 `MVVM + Coordinator`，但“加载态系统”还没有真正统一。

从现有代码可以看到几个典型现状：

1. 列表页、搜索页、详情页大量使用 `isLoading + error + ProgressView`
2. 错误提示很多仍通过 `.alert` 弹出，而不是内联在页面结构中
3. 首屏加载、刷新中、分页加载中、动作提交中，经常共用一个 `isLoading`
4. 已有内容刷新时，缺少“保留旧内容 + 局部更新反馈”的统一模式
5. 页面 loading 主要是纯文本 `ProgressView`，和 Raver 的视觉语言没有真正融合

这会导致在弱网或慢接口下出现一组稳定问题：

1. 页面像“卡住”而不是“正在工作”
2. 下拉刷新和首次加载体验几乎一样，层级不清
3. 局部失败会被放大成全页失败，或者只能弹一个 alert
4. 上传、点赞、关注、评论发送、登录、搜索等动作的反馈方式不一致
5. 用户不知道当前是否应该继续等待、下拉重试、还是返回上一页

这份规范不是为了“把 loading 做漂亮”，而是为了把等待体验设计成 iOS App 的一套基础设施。

---

## 2. 基于当前 iOS 工程的现状判断

基于仓库当前代码，iOS 端有几个重要事实：

1. 当前主架构是 `MVVM + Coordinator`
2. ViewModel 已经普遍承载异步任务和页面状态，这是非常好的基础
3. 典型页面已经存在，但加载态语义仍比较粗：
   - [`FeedViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift)
   - [`SearchViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchViewModel.swift)
   - [`UserProfileViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileViewModel.swift)
   - [`NotificationsViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsViewModel.swift)
4. 当前 View 层已经使用的加载表达主要是：
   - `ProgressView`
   - `ContentUnavailableView`
   - `.refreshable`
   - `.alert`
5. 当前已有稳定视觉 token，可直接用于加载态系统：
   - [`Theme.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/Theme.swift)
   - [`GlassCard.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Shared/GlassCard.swift)
   - [`PrimaryButtonStyle.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Shared/PrimaryButtonStyle.swift)
6. 登录与 token 恢复链路已经存在：
   - [`AppState.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
   - [`SessionTokenStore.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SessionTokenStore.swift)
   - [`LiveSocialService.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift)

因此，iOS 端的正确方向不是先换框架，而是：

1. 先统一状态语义
2. 先统一 ViewModel 输出模型
3. 先统一 SwiftUI 反馈组件
4. 再逐步改造重点页面
5. 最后再沉淀成共享 `Shared/Feedback` 能力

---

## 3. 设计目标

iOS 加载态系统必须同时满足以下目标：

1. `即时响应`
用户点击后的 100ms 到 150ms 内必须看到界面反馈。

2. `首屏不空白`
页面进入后先稳定展示导航壳、标题、列表框架或详情框架。

3. `保留旧内容`
刷新、切换筛选、切 tab、后台回前台重新同步时，默认保留旧内容。

4. `状态可区分`
明确区分首次加载、刷新中、分页加载中、提交中、上传中、恢复会话中、空态、错误态、离线态。

5. `错误可恢复`
错误不能只告诉用户“失败了”，还要告诉用户下一步能做什么。

6. `符合 iOS 交互心智`
优先采用 SwiftUI 原生体验：下拉刷新、内联错误、局部 loading、内容占位、轻量提示，而不是频繁弹 alert。

7. `适配当前 Raver 视觉语言`
使用现有 `RaverTheme`、`GlassCard`、品牌字体、卡片样式，不引入风格割裂的系统默认 loading 页面。

---

## 4. 总体原则

### 4.1 首屏优先渲染结构，不优先纯转圈

进入一个页面后，应该优先看到：

1. 导航标题或页面标题
2. 主要布局容器
3. 列表或卡片骨架
4. 详情页的头部骨架

不建议长期使用：

1. 整页只有一个 `ProgressView`
2. 顶部和内容一起消失，只剩“加载中...”
3. 页面数据回来前完全没有尺寸和布局

### 4.2 首次加载和刷新中必须分开

这是 iOS 端最重要的一条。

1. `首次加载`
页面还没有任何有效内容。

2. `刷新中`
页面已经有内容，只是在后台更新。

首次加载应该用骨架或页面占位。

刷新中应该：

1. 保留原内容
2. 顶部显示轻量刷新提示，或依赖系统 `refreshable` 的交互反馈
3. 避免整个列表重新切回空白/转圈状态

### 4.3 分页加载只能影响列表底部

列表翻页、无限滚动、`loadMoreIfNeeded` 场景，不能把整页切回 loading。

应采用：

1. 底部 `ProgressView`
2. 底部“加载更多”文案
3. 分页失败后底部重试单元

### 4.4 局部动作只影响局部控件

点赞、关注、保存、评论发送、上传头像、发送验证码、开启私信等动作，不应锁死整页。

默认规则：

1. 按钮 loading 只作用于当前按钮
2. 单元格动作只影响当前 cell
3. 上传动作只影响当前上传位
4. 不因一个局部动作阻断整个页面浏览

### 4.5 加载态要先于错误态设计

页面设计时先问：

1. 首屏怎么加载
2. 刷新怎么加载
3. 分页怎么加载
4. 局部动作怎么加载
5. 失败时如何从每种状态恢复

不要先写 `alert(error)`，再回头补结构化反馈。

---

## 5. 统一状态模型

### 5.1 一级状态

每个页面或模块都应显式落到以下一级状态之一：

```swift
@MainActor
final class ExampleViewModel: ObservableObject {
    enum LoadPhase: Equatable {
        case idle
        case initialLoading
        case success
        case empty
        case failure(message: String)
        case offline(message: String)
    }
}
```

含义：

1. `idle`
尚未触发加载，通常只在页面初始化前短暂存在。

2. `initialLoading`
首次加载中，当前没有可渲染内容。

3. `success`
请求成功且有可展示内容。

4. `empty`
请求成功，但当前条件下没有内容。

5. `failure(message:)`
请求失败，且当前没有可用内容。

6. `offline(message:)`
明显处于离线或网络不可用场景。

### 5.2 二级状态

一级状态之外，再增加以下局部派生状态：

1. `isRefreshing`
下拉刷新或后台同步中

2. `isLoadingMore`
列表分页中

3. `isSubmitting`
表单提交、登录、保存、发送评论中

4. `isUploading`
上传图片、视频、头像中

5. `isRestoringSession`
正在恢复登录态或 silently refresh token

6. `isSlowNetwork`
请求持续过久，需要升级用户反馈

### 5.3 推荐 ViewModel 结构

#### 列表页

```swift
struct ListViewState<Item> {
    var items: [Item] = []
    var phase: LoadPhase = .idle
    var isRefreshing = false
    var isLoadingMore = false
    var hasLoadedOnce = false
    var bannerMessage: String?
}
```

#### 详情页

```swift
struct DetailViewState<Model> {
    var model: Model?
    var phase: LoadPhase = .idle
    var isRefreshing = false
    var bannerMessage: String?
}
```

#### 表单页

```swift
struct FormViewState {
    var isBootstrapping = false
    var isSubmitting = false
    var uploadStates: [String: UploadState] = [:]
    var fieldErrors: [String: String] = [:]
    var formError: String?
    var successMessage: String?
}
```

---

## 6. 页面分类与推荐策略

### 6.1 动态流/列表页

典型页面：

1. [`FeedView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift)
2. [`NotificationsView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsView.swift)
3. `小队列表`、`推荐列表`、`活动流` 一类页面

推荐策略：

1. 首屏使用列表骨架，而不是纯 `ProgressView`
2. 下拉刷新保留内容，用顶部轻提示或系统刷新反馈
3. 分页只在底部显示 `load more`
4. 局部操作失败不打断整个列表滚动

### 6.2 搜索页

典型页面：

1. [`SearchView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchView.swift)
2. [`SearchViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchViewModel.swift)

推荐策略：

1. 未搜索时显示引导态或推荐态，不要直接空白
2. 搜索中保留上一次结果，顶部显示“正在搜索”
3. 切 scope 时，不要所有内容闪空再重建
4. 搜索失败优先内联提示，不优先弹 alert

### 6.3 用户主页/详情页

典型页面：

1. [`UserProfileView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift)
2. 未来所有 `Post Detail`、`Event Detail`、`Squad Detail` 页面

推荐策略：

1. 头部卡片先骨架
2. 帖子列表和资料区分层加载
3. 主体成功后，次模块失败不能盖掉整页
4. 关注、私信、点赞等动作单独 loading

### 6.4 后台/管理型页面

典型页面：

1. 审核中心
2. OpenIM 管理页
3. 运营表格页

推荐策略：

1. 头部统计卡和主体表格拆开加载
2. Tab 切换只刷新当前 tab 内容
3. 空态、错误态、权限态明确分开

### 6.5 登录与会话恢复页

典型页面：

1. [`LoginView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Auth/LoginView.swift)
2. `App launch session restore`

推荐策略：

1. `登录中`、`发送验证码中`、`会话恢复中` 必须分开
2. 会话恢复是 App 级状态，不应和普通页面 loading 混在一起
3. 发送验证码只锁按钮，不锁整个手输面板
4. 登录失败优先在面板内展示错误，不只弹 alert

---

## 7. iOS 端专属状态规则

### 7.1 `refreshable` 不是完整的刷新系统

`.refreshable` 只提供交互入口，不等于完成了刷新体验设计。

仍然需要：

1. ViewModel 有 `isRefreshing`
2. 已有内容保留
3. 刷新失败时保留旧内容并给出恢复提示
4. 刷新完成时必要时给出轻量反馈

### 7.2 `alert` 不能承担主要错误态职责

`.alert` 适合：

1. 高风险确认
2. 需要用户做明确选择的失败
3. 登录权限提醒
4. 破坏性操作失败

`.alert` 不适合承担：

1. 首屏加载失败
2. 搜索失败
3. 列表更新失败
4. 详情页模块拉取失败

这些更适合用：

1. 页面内错误卡片
2. 顶部 banner
3. 模块内联错误区

### 7.3 `ContentUnavailableView` 是空态，不是错误态

`ContentUnavailableView` 很适合：

1. 搜索无结果
2. 暂无动态
3. 暂无通知
4. 还未发布内容

但不应把它直接拿来表示网络错误，除非配合错误 icon、重试动作和明确文案。

### 7.4 会话恢复是 App 级 loading

App 启动、前后台切换、token 刷新时，推荐存在单独的 `SessionRestoringPhase`：

```swift
enum SessionPhase {
    case launching
    case restoring
    case authenticated
    case unauthenticated
    case failed(message: String)
}
```

目的：

1. 区分“用户未登录”和“系统还在恢复登录态”
2. 避免页面过早跳登录
3. 为 App 启动时提供稳定壳层体验

---

## 8. 加载时序规范

### 8.1 时间阈值

建议统一以下阈值：

1. `0ms - 150ms`
不展示显式 loading 组件，只需要按钮按压或切换反馈。

2. `150ms - 3000ms`
展示标准 loading。

3. `3000ms - 8000ms`
展示慢网提示，例如 `网络较慢，仍在继续加载`。

4. `8000ms+`
升级为可恢复态，例如展示 `重试`、`返回`、`稍后再试`。

### 8.2 最短展示时长

为了避免闪烁：

1. loading 一旦展示，建议至少停留 `300ms`
2. 骨架切内容使用轻微淡入
3. 不要让 `ProgressView` 一闪而过

### 8.3 体验超时而不是请求超时

即使底层请求还没真正 timeout，UI 也应在体验层面升级反馈：

1. 3 秒提示慢网
2. 8 秒给重试入口
3. 15 秒提示检查网络

---

## 9. 统一页面结构规范

每个 Screen 推荐按这个层次组织：

```swift
ScreenContainer {
    ScreenHeader()
    ScreenControls()
    ScreenStatusBanner()
    ScreenBody()
}
```

### 9.1 `ScreenHeader`

负责：

1. 标题
2. 分段选择器
3. 筛选器
4. 主按钮

应在数据加载前就保持稳定，不应跟随列表一起消失。

### 9.2 `ScreenStatusBanner`

用于展示：

1. 正在更新
2. 网络较慢
3. 使用的是旧数据
4. 某个模块更新失败

它是替代“大量 alert”的关键。

### 9.3 `ScreenBody`

负责根据 `phase` 切换：

1. skeleton
2. empty
3. failure
4. content

---

## 10. 通用组件设计规范

建议未来沉淀到：

```text
mobile/ios/RaverMVP/RaverMVP/Shared/Feedback/
```

### 10.1 `RaverSkeletonView`

用途：

1. 首屏列表骨架
2. 详情页骨架
3. 卡片骨架
4. 表单骨架

要求：

1. 基于 `RaverTheme.card` 和 `RaverTheme.cardBorder`
2. 与真实布局尽量接近
3. 动效低对比度，不刺眼

### 10.2 `InlineLoadingBadge`

用途：

1. 正在刷新
2. 正在同步
3. 正在搜索
4. 正在上传某个局部资源

要求：

1. 体积小
2. 不抢主视觉
3. 能放在 header 下方或 section 顶部

### 10.3 `ScreenErrorCard`

用途：

1. 首屏失败
2. 模块失败
3. 搜索失败

必须包含：

1. 错误标题
2. 简短说明
3. 重试按钮
4. 可选返回入口

### 10.4 `ScreenEmptyState`

用途：

1. 搜索无结果
2. 个人主页无内容
3. 通知为空
4. 活动为空

优先复用 `ContentUnavailableView`，但外层应允许统一封装文案和动作。

### 10.5 `SlowNetworkBanner`

用途：

1. 请求较慢但未失败

表现：

1. 轻量横幅
2. 品牌色弱提示
3. 文案不制造焦虑

### 10.6 `ActionButtonState`

用于统一按钮 loading：

1. 登录
2. 发送验证码
3. 关注
4. 保存
5. 上传
6. 评论发送

要求：

1. 按钮尺寸前后一致
2. 支持 `loadingText`
3. 支持局部禁用

---

## 11. ViewModel 设计规则

### 11.1 不再只用 `isLoading`

旧方式：

```swift
@Published var isLoading = false
@Published var error: String?
```

这对复杂页面不够。

推荐方式：

```swift
@Published private(set) var phase: LoadPhase = .idle
@Published private(set) var isRefreshing = false
@Published private(set) var isLoadingMore = false
@Published var bannerMessage: String?
@Published var actionError: String?
```

### 11.2 首屏与刷新分开实现

例如 `FeedViewModel`、`UserProfileViewModel`、`NotificationsViewModel` 后续都应逐步统一成：

1. `loadInitialIfNeeded()`
2. `refresh()`
3. `loadMoreIfNeeded()`
4. `retryInitialLoad()`

而不是所有入口都回到同一个 `load()`。

### 11.3 动作错误和页面错误分开

例如：

1. 页面拉取失败 -> `phase = .failure(...)`
2. 点赞失败 -> `actionError`
3. 上传失败 -> `uploadStates[id].errorMessage`
4. 搜索建议失败 -> `bannerMessage`

### 11.4 `userFacingMessage` 必须继续统一

当前项目里已经大量使用 `error.userFacingMessage`，这很好。

要求继续保持：

1. ViewModel 对外只暴露可直接展示的文案
2. View 层不拼接底层技术错误

---

## 12. View 渲染规则

### 12.1 列表页渲染规则

```swift
if case .initialLoading = viewModel.phase, viewModel.items.isEmpty {
    ListSkeletonView()
} else if case .failure(let message) = viewModel.phase, viewModel.items.isEmpty {
    ScreenErrorCard(message: message)
} else if case .empty = viewModel.phase {
    ScreenEmptyState(...)
} else {
    ActualListContent()
}
```

同时：

1. `isRefreshing == true` 时保留内容
2. `isLoadingMore == true` 时底部显示加载更多
3. 页面已有内容时的失败优先走 banner，不走整页错误

### 12.2 详情页渲染规则

1. 主体还没拿到时显示 detail skeleton
2. 主体拿到后，评论区、推荐区等独立加载
3. 次模块失败不覆盖主内容

### 12.3 表单页渲染规则

1. 编辑页初始化阶段显示表单骨架
2. `isSubmitting` 只影响主提交按钮
3. `isUploading` 只影响对应上传控件
4. 字段错误显示在字段附近，不统一堆到 alert

### 12.4 登录页渲染规则

对 [`LoginView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Auth/LoginView.swift) 这类页面：

1. `isLoading` 需要拆为：
   - `isSubmittingAuth`
   - `isSendingSMS`
   - `isRestoringSession`（App 级）
2. 手输登录面板和一键登录按钮应有独立 loading
3. 发送验证码倒计时和发送中不能共用一个布尔值

---

## 13. 错误态分层

错误必须分四层：

1. `字段错误`
手机号格式、验证码为空、昵称非法

2. `动作错误`
点赞失败、关注失败、上传失败、发送评论失败

3. `模块错误`
评论区失败、推荐区失败、筛选数据失败

4. `页面错误`
主页主数据失败、列表首屏失败、详情主体失败

展示位置规则：

1. 字段错误 -> 字段下方
2. 动作错误 -> 控件附近或轻量 toast/banner
3. 模块错误 -> 模块内部
4. 页面错误 -> 页面内 error card

不建议所有错误都落到 `.alert`。

---

## 14. 空态规范

空态不等于失败。

### 14.1 空态分类

1. `系统空态`
还没有任何动态、活动、通知

2. `搜索空态`
当前关键词无结果

3. `个人空态`
该用户还没发内容

4. `权限空态`
该用户关闭了粉丝列表等

### 14.2 空态要求

必须包含：

1. 标题
2. 一句解释
3. 一个主行动

例如：

1. `暂无动态`
2. `试试切换关键词或稍后再来`
3. `重新加载` / `去发布` / `返回` / `清除筛选`

---

## 15. 弱网与离线策略

### 15.1 弱网分级

1. `慢`
请求仍在继续，但响应时间过长

2. `不稳定`
部分接口成功，部分失败

3. `离线`
设备明确断网，或请求明确因网络失败

### 15.2 对应体验

1. `慢`
显示 `SlowNetworkBanner`

2. `不稳定`
保留旧内容 + banner 说明

3. `离线`
显示离线空态或错误卡，并保留已缓存内容

### 15.3 iOS 端实现建议

未来可封装统一网络状态观察：

1. `NWPathMonitor` 监听在线状态
2. ViewModel 根据错误类型判断是否进入 `.offline`
3. 页面已有内容时优先展示“离线但保留旧内容”

---

## 16. 动作反馈规范

### 16.1 点赞/关注/保存

1. 优先局部反馈
2. 可采用乐观更新
3. 失败时回滚并给轻量错误提示
4. 不弹全页 alert

### 16.2 评论发送

1. 发送按钮进入 loading
2. 输入框保持上下文
3. 成功后清空输入并插入新评论
4. 失败后保留输入内容

### 16.3 上传图片/视频/头像

1. 显示局部上传进度或上传中状态
2. 上传位保留预览框架
3. 失败时允许原位重试
4. 不锁死整页表单

### 16.4 登录和短信验证码

1. 登录中：主按钮 loading
2. 发送验证码中：验证码按钮 loading
3. 倒计时中：按钮变禁用态 + 秒数
4. 登录失败：面板内错误提示优先

---

## 17. 文案规范

文案要求：

1. 简洁
2. 可理解
3. 不技术化
4. 不制造惊慌

### 17.1 推荐文案

首次加载：

1. `正在加载动态`
2. `正在准备用户主页`
3. `正在获取通知`

刷新中：

1. `正在更新`
2. `正在同步最新内容`

慢网：

1. `网络较慢，内容还在路上`
2. `当前连接不太稳定，我们还在继续尝试`

错误：

1. `加载失败，请稍后重试`
2. `当前网络不稳定，暂时没有拿到最新内容`

空态：

1. `暂时还没有内容`
2. `换个关键词试试看`

### 17.2 不推荐文案

1. `Loading...`
2. `Request failed`
3. `Unknown error`
4. `服务器异常`
5. `操作失败`

---

## 18. 推荐目录结构

建议未来逐步沉淀：

```text
mobile/ios/RaverMVP/RaverMVP/
  Shared/
    Feedback/
      LoadPhase.swift
      ScreenErrorCard.swift
      ScreenEmptyState.swift
      InlineLoadingBadge.swift
      SlowNetworkBanner.swift
      Skeleton/
        FeedSkeletonView.swift
        ProfileSkeletonView.swift
        DetailSkeletonView.swift
        FormSkeletonView.swift
```

以及：

```text
mobile/ios/RaverMVP/RaverMVP/Core/
  Networking/
    NetworkStatusMonitor.swift
```

---

## 19. 直接对应当前页面的改造建议

### 19.1 Feed

对应文件：

1. [`FeedView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedView.swift)
2. [`FeedViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed/FeedViewModel.swift)

当前问题：

1. 首屏只有 `ProgressView`
2. 错误主要通过 `.alert`
3. `refresh()` 直接复用 `load()`

建议改造：

1. 引入 `phase`
2. 首屏改骨架
3. 下拉刷新保留内容
4. 列表已有内容时失败转为 banner
5. 点赞/收藏/分享失败不作为页面加载失败处理

### 19.2 Search

对应文件：

1. [`SearchView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchView.swift)
2. [`SearchViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search/SearchViewModel.swift)

当前问题：

1. 搜索中整块切为 `ProgressView`
2. 会丢失上一次结果
3. 搜索失败主要靠 alert

建议改造：

1. 搜索时保留旧结果
2. 顶部显示搜索中 badge
3. 空结果和失败明确分离
4. 切 scope 时只刷新结果区

### 19.3 User Profile

对应文件：

1. [`UserProfileView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift)
2. [`UserProfileViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileViewModel.swift)

当前问题：

1. 首屏仅 `ProgressView`
2. 错误信息主要 `.alert`
3. 资料区和动态区未明显分层

建议改造：

1. 头部骨架 + 列表骨架
2. recent check-ins 模块单独处理失败
3. 私信按钮维持局部 loading
4. 下拉刷新只刷新已展示内容

### 19.4 Notifications

对应文件：

1. [`NotificationsView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsView.swift)
2. [`NotificationsViewModel.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsViewModel.swift)

建议改造：

1. 首屏通知列表骨架
2. 空态、失败态、离线态分开
3. 单条通知操作不阻断整页

### 19.5 Login

对应文件：

1. [`LoginView.swift`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Auth/LoginView.swift)

当前问题：

1. `isLoading` 同时承担登录/验证码/一键登录按钮的含义
2. 错误主要缺少面板内稳定反馈位

建议改造：

1. 拆分动作 loading
2. 验证码发送、登录提交、一键登录分别建状态
3. 手输面板固定错误提示区域
4. 登录成功后的跳转和会话恢复解耦

---

## 20. 实施优先级

### Phase 1：先统一高频核心流

1. Feed
2. Search
3. User Profile
4. Notifications

目标：

1. 建立统一 `LoadPhase`
2. 建立首批反馈组件
3. 替换首屏纯 `ProgressView`

### Phase 2：再统一详情和操作页

1. Post Detail
2. Squad Profile
3. 各类 detail 页

目标：

1. 详情页 skeleton
2. 评论/次模块分层错误处理
3. 行为按钮局部 loading

### Phase 3：再统一登录和编辑发布流

1. Login
2. Edit Profile
3. Compose Post
4. 上传与发布链路

目标：

1. 提交态标准化
2. 上传态标准化
3. 会话恢复态标准化

### Phase 4：后台和复杂运营页

1. OpenIM 管理相关
2. 运营审核和工具页

目标：

1. 表格骨架
2. tab 内局部刷新
3. 离线/慢网标准化

---

## 21. 验收标准

每个页面改造完成后，至少满足以下标准：

1. 首屏不再只有纯 `ProgressView`
2. 首次加载和刷新中已分离
3. 分页加载只影响底部
4. 空态和错误态分离
5. 页面已有内容时，失败优先保留旧内容
6. 局部动作只影响局部控件
7. 慢网超过 3 秒有升级反馈
8. 失败有明确恢复路径

---

## 22. QA 测试清单

建议纳入 iOS 自测和提测：

### 22.1 网络模拟

1. 正常 Wi‑Fi
2. Network Link Conditioner 慢网
3. 弱网抖动
4. 完全离线

### 22.2 首屏

1. Feed 首次进入
2. Search 首次进入
3. User Profile 首次进入
4. Notifications 首次进入

### 22.3 刷新

1. 下拉刷新成功
2. 下拉刷新失败
3. 下拉刷新时保留内容

### 22.4 分页

1. 加载更多成功
2. 加载更多失败
3. 列表到底部快速多次触发

### 22.5 动作

1. 点赞
2. 关注
3. 收藏
4. 评论发送
5. 上传头像/媒体
6. 登录
7. 发送验证码

### 22.6 会话

1. App 冷启动恢复 session
2. token 过期后 silent refresh
3. refresh 失败后回登录态

---

## 23. 与现有文档的关系

相关文档：

1. [`docs/IOS_INCREMENTAL_FEATURE_DEVELOPMENT_GUIDE.md`](/Users/blackie/Projects/raver/docs/IOS_INCREMENTAL_FEATURE_DEVELOPMENT_GUIDE.md)
2. [`docs/MVVM_COORDINATOR_MIGRATION_PLAN.md`](/Users/blackie/Projects/raver/docs/MVVM_COORDINATOR_MIGRATION_PLAN.md)
3. [`docs/IOS_MANUAL_NAVIGATION_CLICKPATH_CHECKLIST.md`](/Users/blackie/Projects/raver/docs/IOS_MANUAL_NAVIGATION_CLICKPATH_CHECKLIST.md)
4. [`docs/IOS_RELEASE_SMOKE_RUNBOOK.md`](/Users/blackie/Projects/raver/docs/IOS_RELEASE_SMOKE_RUNBOOK.md)

建议使用顺序：

1. 先看本规范：页面状态怎么设计
2. 再看增量开发规范：代码应放在哪一层
3. 再看迁移计划：架构现在推进到哪里
4. 最后按点击路径和发布冒烟清单回归

---

## 24. 最终决策

Raver iOS 的加载态系统采用以下默认决策：

1. 首屏优先骨架，不优先纯 `ProgressView`
2. 首次加载、刷新中、分页加载、动作提交中强制分离
3. 已有内容刷新时默认保留旧内容
4. 搜索失败、列表失败、详情失败优先页面内反馈，不优先 alert
5. 空态、错误态、离线态强制分离
6. 上传、关注、点赞、评论、登录等动作默认局部 loading
7. 慢网按 3s / 8s 分级反馈
8. 会话恢复作为 App 级独立状态建模

---

## 25. 给后续开发者的执行口令

以后任何 iOS 新页面或改造页面，在开始写代码前先回答这六个问题：

1. 首屏骨架是什么
2. 如果网络慢 5 秒，用户看到什么
3. 如果已经有旧内容，刷新时是否保留
4. 如果失败，恢复入口在哪里
5. 哪些 loading 是整页，哪些是局部
6. 这个状态属于首次加载、刷新、分页、提交、上传、还是会话恢复

如果这六个问题回答不清楚，说明这个页面的加载态设计还没有完成。
