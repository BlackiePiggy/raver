# iOS 图片加载统一改造计划（SDWebImageSwiftUI）

## 1. 背景与目标

### 背景
- 当前项目内图片远程加载方式较分散，`AsyncImage` 使用较多。
- 初步扫描基线：主工程（`RaverMVP`）内约 `98` 处 `AsyncImage(...)`。
- 点击行为存在不一致风险：部分页面可能是“点图片生效”，而不是“点卡片容器生效”。

### 目标
- 引入 `SDWebImageSwiftUI`，统一远程图片加载与缓存策略。
- 建立项目级统一图片组件（参考你提供的 trick）：
  - 图片本体 `allowsHitTesting(false)`，不直接响应点击。
  - 点击行为由外围容器/卡片承担（包含图片周边区域）。
- 分阶段替换项目中可点击场景的图片加载实现，再逐步覆盖全部远程图片加载。

### 非目标（本阶段不做）
- 不在本阶段做图片 CDN/压缩链路改造。
- 不在本阶段重做所有 UI 样式，仅保证行为一致与稳定。

---

## 2. 统一规范（必须遵守）

### 2.1 统一组件规范
- 新建统一组件（建议命名：`ImageLoaderView` 或 `RaverRemoteImage`）。
- 组件内部核心行为：
  1. 使用 `WebImage` 加载远程图。
  2. 图片 `.allowsHitTesting(false)`。
  3. 用透明背景/容器承接点击区域（如 `Rectangle().opacity(0.001).overlay(...)`）。
  4. 支持占位图、失败态、`ContentMode`、裁剪。

### 2.2 点击行为规范
- 禁止在图片本体上绑定点击跳转。
- 统一由外层 `Button` / `onTapGesture` 容器触发。
- 外层容器统一加 `contentShape(Rectangle())`（或对应形状）保证可点区域稳定。

### 2.3 缓存与加载规范
- 统一通过 `SDWebImageSwiftUI` 进行远程加载。
- 统一缓存策略（内存/磁盘上限、过期策略）在 App 启动时集中配置。

---

## 3. 总体实施阶段

## Phase 0 - 准备与冻结范围
- 输出本计划文档并确认范围。
- 固定首批改造模块（建议：Discover 全链路 + MainTab 常用入口）。
- 产出改造清单文件（按模块列出待替换点位）。

**验收标准**
- 计划文档确认。
- 首批改造范围确认。

## Phase 1 - 引入依赖与基础设施
- 将 `SDWebImageSwiftUI` 接入 `RaverMVP.xcodeproj`（SPM）。
- 统一建立图片组件文件（建议使用现有占位文件）：
  - `mobile/ios/RaverMVP/RaverMVP/Shared/ImageLoaderView.swift`
- 新建图片缓存配置入口（例如 App 启动处集中设置）。

**验收标准**
- 工程可编译。
- 新组件可在 Preview/真实页面加载网络图。

## Phase 2 - 可点击图片场景优先迁移
- 优先替换“可点击图片”场景，保证点击逻辑统一走外层容器。
- 重点模块建议顺序：
  1. Discover（Events / DJs / News / Sets / Learn / Search）
  2. MainTab（首页聚合卡片）
  3. Feed / Messages / Profile / Squads
- 每改一个页面做一次交互复核：点击图片本体、点击图片外围、快速连点。

**验收标准**
- 页面中点击跳转均由外围容器触发。
- 图片本体不直接响应点击。

## Phase 3 - 全量远程图片替换
- 分批将 `AsyncImage` 替换为统一组件。
- 保留本地 `Image(...)` 与非网络资源逻辑，不强制改造。
- 对特殊场景（缩放图、手势图、视频封面）单独适配。

**验收标准**
- 主工程远程图加载统一使用 `SDWebImageSwiftUI` 方案。
- `AsyncImage(...)` 使用量降至目标阈值（最终目标可为 0，或仅保留白名单）。

## Phase 4 - 回归与收尾
- 全链路回归：列表、详情、编辑页、弹窗、搜索页、弱网。
- 观测缓存命中、滚动流畅性、闪烁、重复请求。
- 更新文档：已完成页面、残留点位、后续优化项。

**验收标准**
- 编译通过、核心功能稳定。
- 文档与实际改造进度一致。

---

## 4. 详细改造步骤（执行清单）

### Step A. 接入 SDWebImageSwiftUI
1. 在 Xcode 中为 `RaverMVP` 主工程添加 SPM 依赖：
   - `SDWebImageSwiftUI`
2. 让目标 Target 正确链接该产品。
3. 本地编译验证。

### Step B. 建立统一组件
1. 在 `Shared` 下实现统一图片组件（按你提供的 trick 设计）。
2. 提供参数：
   - `urlString`
   - `resizingMode`
   - `placeholder`
   - `failureView`
3. 组件内部固定：
   - `WebImage(...).resizable().indicator(.activity)`
   - `.allowsHitTesting(false)`
   - 外层透明承载层 + `.clipped()`

### Step C. 点击交互规范落地
1. 将图片点击行为迁移到外围容器。
2. 外围容器统一 `contentShape(...)`。
3. 检查是否存在图片本体手势，逐步移除。

### Step D. 模块化替换（建议顺序）
1. Discover/Search/Recommend/Events/DJs/News/Sets/Learn
2. MainTab
3. Feed
4. Messages
5. Profile / Squads

每个模块替换后执行：
- 编译
- 关键页面手动点测
- 记录已完成条目到本文档

### Step E. 缓存策略配置
1. 在应用启动路径设置 `SDImageCache` 参数（内存/磁盘/过期）。
2. 确认弱网和重进页面的缓存命中表现。

---

## 5. 风险与应对

### 风险 1：点击事件丢失或范围变小
- 应对：统一加 `contentShape`，并在卡片层做点击。

### 风险 2：替换后样式偏差
- 应对：组件支持 `ContentMode` 与占位视图参数，逐页微调。

### 风险 3：列表滚动性能波动
- 应对：先改高频页面并压测滚动；必要时调整解码与缓存配置。

### 风险 4：一次改造过大导致回归困难
- 应对：按模块分批、每批可独立回滚。

---

## 6. 回滚策略

- 每个模块单独提交，出现问题可按模块回滚。
- 保持组件 API 稳定，避免中途频繁改签名。
- 保留阶段性里程碑标签（Tag/提交点）。

---

## 7. 进度跟踪（后续持续更新）

## 当前状态
- 文档状态：已创建
- 阶段状态：`Phase 0` 完成，`Phase 1` 完成，`Phase 2` 完成，`Phase 3` 完成，`Phase 4` 进行中
- 当前扫描：`AsyncImage(...)` 实际调用 `0` 处（基线约 `98` 处）
- 备注：代码中 `AsyncImage` 关键字与调用均已清零（含命名残留）

## 阶段看板
| 阶段 | 状态 | 开始日期 | 完成日期 | 负责人 | 备注 |
|---|---|---|---|---|---|
| Phase 0 计划确认 | Completed | 2026-04-11 | 2026-04-11 | Codex + User | 本文档建立 |
| Phase 1 依赖与基础设施 | Completed | 2026-04-11 | 2026-04-11 | Codex | 已接入 SPM + 建立统一组件 + 缓存配置 |
| Phase 2 可点击场景迁移 | Completed | 2026-04-11 | 2026-04-11 | Codex | Discover/MainTab/Feed/Messages/Profile/Squads 已完成替换 |
| Phase 3 全量远程图迁移 | Completed | 2026-04-11 | 2026-04-11 | Codex | 主工程 `AsyncImage(...)` 已清零 |
| Phase 4 回归与收尾 | In Progress | 2026-04-11 | - | Codex | 已完成编译回归，待继续页面交互复核 |

## 变更日志
- 2026-04-11：初始化迁移方案文档，确认目标、阶段、验收与进度模板。
- 2026-04-11：`Phase 1` 启动，完成以下事项：
  - 通过 SPM 将 `SDWebImageSwiftUI` 接入 `RaverMVP` target。
  - 新增统一图片组件 `Shared/ImageLoaderView.swift`（包含 `allowsHitTesting(false)` 容器点击 trick）。
  - 新增兼容包装 `Shared/ImageLoadView.swift`，避免旧引用断裂。
  - 将 `Shared/RemoteCoverImage.swift` 改为复用 `ImageLoaderView`。
  - 新增 `Core/ImageCacheBootstrap.swift` 并在 `RaverMVPApp` 启动时配置 SDWebImage 缓存策略。
  - 在 `RecommendEventsModuleView` 完成首个业务页面替换样例（封面图改用统一加载器）。
- 2026-04-11：`Phase 2`（Discover 第一批）完成：
  - `Discover/News/Views/NewsModuleView.swift`
  - `Discover/News/Views/DiscoverNewsDetailView.swift`
  - `Discover/Events/Views/EventPresentationSupport.swift`
  - `Discover/Events/Views/EventCalendarSupport.swift`
  - `Discover/Events/Views/EventDetailView.swift`
- 2026-04-11：`Phase 2`（Discover 第二批）完成：
  - `Discover/DJs/Views/DJsModuleView.swift`（已清零 `AsyncImage`）
  - `Discover/Sets/Views/SetsModuleView.swift`（已清零 `AsyncImage`）
  - `Discover/Learn/Views/LearnModuleView.swift`（已清零 `AsyncImage`）
  - 连续构建验证通过（`xcodebuild ... RaverMVP`）
- 2026-04-11：`Phase 2`（Discover 第三批）完成：
  - `Discover/Events/Views/EventEditorView.swift`（3 处替换完成）
  - 再次构建验证通过（`xcodebuild ... RaverMVP`）
- 2026-04-11：Discover 主链路（Recommend/Events/News/DJs/Sets/Learn）已完成 `AsyncImage` 清理，后续转入 `MainTab + Feed + Messages + Profile + Squads`。
- 2026-04-11：完成 `MainTab + Feed + Messages + Profile + Squads + Notifications` 收尾替换：
  - `Features/MainTabView.swift`
  - `Shared/PostCardView.swift`
  - `Features/Messages/MessagesHomeView.swift`
  - `Features/Messages/ChatView.swift`
  - `Features/Feed/ComposePostView.swift`
  - `Features/Feed/PostDetailView.swift`
  - `Features/Profile/ProfileView.swift`
  - `Features/Profile/EditProfileView.swift`
  - `Features/Profile/FollowListView.swift`
  - `Features/Profile/Views/Checkins/MyCheckinsView.swift`
  - `Features/Squads/SquadProfileView.swift`
  - `Features/Notifications/NotificationsView.swift`
  - 全量编译通过（`xcodebuild -project .../RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`）
  - 扫描结果：`rg "\\bAsyncImage\\s*\\("` 返回 `0`
- 2026-04-11：命名统一收尾：
  - `ZoomableAsyncImage` -> `ZoomableRemoteImage`
  - `ComposeZoomableAsyncImage` -> `ComposeZoomableRemoteImage`
  - 扫描结果：`rg "AsyncImage"` 返回 `0`

---

## 8. 完成定义（Definition of Done）

- 项目远程图片加载统一到 `SDWebImageSwiftUI` 方案。
- 可点击图片场景全部满足“图片不抢点击，容器承接点击”。
- 核心流程回归通过（Discover / Feed / Messages / Profile / Squads）。
- 本文档进度与实际代码状态一致。
