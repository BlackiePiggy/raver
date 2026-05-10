# iOS 虚拟资产皮肤系统开发日志

Last Updated: 2026-05-10  
Owner: Product + Design + iOS + Backend + Codex

## 使用规则

这份日志只记录开发过程中的事实、决策、收口和下一步，不承载完整需求。完整需求和执行清单见：

- `docs/IOS_VIRTUAL_ASSET_SKIN_SYSTEM_PLAN.md`

每次推进时追加一条日志，格式保持一致，方便后续快速读上下文。

---

## 当前阶段

- 阶段：Phase 7 质量、灰度和上线收口
- 状态：灰度开关、基础埋点、质量闸门和开发库存 seed 已接入，待截图/滚动验收
- 核心路线：先完成资产定义、库存、装备、统一渲染，再接入 Profile 和 Messages
- 当前风险：虚拟资产类型容易扩张，需要把 V1 锁定在头像框、个人徽章、消息气泡、称号勋章四类

---

## 进度快照

- [x] 新建主方案文档。
- [x] 新建开发日志文档。
- [x] 明确 V1 四类核心资产。
- [x] 明确 V1 不做完整商城、交易、自定义上传、复杂动效。
- [x] 明确后端核心模型草案。
- [x] 明确 iOS 模块目录草案。
- [x] 明确 Profile 和 Messages 首批接入点。
- [x] 产品规则确认。
- [x] 设计尺寸和首批资产确认。
- [x] Phase 0 正式收口。
- [x] Phase 1 后端模型实现。
- [x] Phase 2 iOS 模型仓储实现。
- [x] Phase 3 渲染组件实现。
- [x] Phase 4 Profile 和资产中心接入。
- [x] Phase 5 Messages 接入。
- [x] Phase 6 Feed/评论/通知轻量接入。
- [ ] Phase 7 灰度和上线收口。

---

## 日志记录

### 2026-05-10：修复资产中心空列表和本地账号无库存问题

本次完成：

- 排查确认本地库已有 40 个 `VirtualAssetDefinition`，但 `UserVirtualAsset` 为空，导致账号无法装备资产。
- 扩展 `server/prisma/seed-virtual-assets.ts`：非生产环境默认给 `blackie`、`h3y2`、`leshanlijiayu`、`uploadtester` 发放 40 个资产库存，并写入默认装备。
- 支持 `VIRTUAL_ASSET_SEED_GRANT_USERS` 覆盖发放对象，支持 `none` 跳过发放、`all` 发给全部用户。
- 将 iOS `AppEnvironment.makeVirtualAssetRepository()` 改为按当前配置即时创建 repository，避免 DEBUG 开关或 baseURL 旧状态缓存导致装扮中心一直空。

验证结果：

- `npm run virtual-assets:seed` 通过，4 个本地常用账号各获得 40 个库存。
- `GET http://127.0.0.1:3901/v1/virtual-assets/catalog` 返回 40 个资产，每类 10 个。
- 使用 `blackie` 临时 token 调用 `GET /v1/me/virtual-assets` 返回 40 个库存，调用 `PUT /v1/me/virtual-assets/equips/profile_badge` 返回 200。
- 重新执行 seed 后恢复默认装备：头像框 1、徽章 3、消息气泡 1、称号 1。
- `npm run build` 通过。
- `git diff --check` 通过。
- `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 通过。

下一步：

- 用模拟器登录上述已发放账号，验收资产中心四类 tab、装备/卸下、Profile 预览刷新。
- 若 App 内仍显示 0 个，优先检查 App 当前 runtime 是否为 live、BFF baseURL 是否为 `http://127.0.0.1:3901` 或同一后端，以及设置页虚拟资产开关是否开启。

### 2026-05-10：建立虚拟资产皮肤系统主方案

本次完成：

- 新增主方案文档 `docs/IOS_VIRTUAL_ASSET_SKIN_SYSTEM_PLAN.md`。
- 新增开发日志文档 `docs/IOS_VIRTUAL_ASSET_SKIN_SYSTEM_DEV_LOG.md`。
- 将 V1 核心范围锁定为头像框、个人徽章、消息气泡皮肤、称号勋章 / Label 样式。
- 将个人主页背景、聊天背景、入场动效、小队专属徽章、活动纪念章等放入 V1.1/V2 候选扩展池。
- 根据现有项目结构确认 iOS 主要接入区域为 Profile 与 Messages/UIKitChat。
- 根据现有 Prisma `User` 和消息模型情况，建议虚拟资产独立建表，不继续扩展 `users` 主表字段。

关键决策：

- V1 不做商城支付闭环，先把资产模型、库存、装备、渲染、展示链路打通。
- 气泡皮肤 V1 优先 solid/gradient/code shape，图片九宫格切片放到 V1.1。
- OpenIM 不承载完整虚拟资产数据，Raver BFF 提供 appearance summary。
- 列表页不展示完整资产效果，只展示轻量头像框/主称号/少量徽章，避免视觉过载。

需要确认：

- 首批每类资产数量。
- 是否需要会员资产和限时资产在 V1 同时出现。
- 徽章在个人页和聊天中最多展示数量。
- 称号文案是否全部系统预置。
- 资产中心入口放在 Profile 顶部、设置页，还是个人页功能宫格。

收口状态：

- 需求框架已建立。
- Phase 0 还未正式冻结，等待产品/设计规则确认。

下一步：

- 对齐产品和设计规则后，冻结 Phase 0。
- 开始 Phase 1 后端 Prisma 模型和基础 API。

### 2026-05-10：确认 Phase 0 产品规则关键项

本次完成：

- 确认首批资产数量：每类约 10 个，总量约 40 个左右。
- 确认徽章展示数量：个人主页 Hero 区最多展示 5 个。
- 确认资产中心入口：个人主页快捷入口新增一个 icon。
- 确认 V1 包含会员资产和限时资产。
- 确认称号文案全部由系统预置，用户不能自定义。
- 已将上述决策同步回主方案文档。

关键决策：

- 个人主页 Hero 区是徽章的主展示场景，聊天和列表页仍保持轻量展示，避免视觉过载。
- 资产中心入口不放在深层设置页，优先作为个人主页可见的快捷入口，提升装扮系统感知。
- 称号是系统资产，不是用户输入内容，因此后端资产定义需要控制称号文案和样式。

仍需确认：

- 首批 40 个左右资产的设计尺寸、静态/动态资源比例和视觉主题。
- 装备数量限制是否沿用默认值：头像框 1 个、气泡 1 个、称号 1 个、徽章最多 5 个。
- 后端和 iOS 模块边界是否直接进入 Phase 1 实现。

收口状态：

- 产品规则关键项已确认。
- Phase 0 尚未完全收口，剩余设计规格和工程边界确认。

下一步：

- 确认首批资产设计规格后，更新 Phase 0 收口记录。
- 如果默认装备限制无异议，可开始 Phase 1 后端数据模型和 API。

### 2026-05-10：Phase 0 最终收口，允许进入开发

本次完成：

- 确认 V1.1/V2 仅保留四类候选扩展：小队身份徽章 / 小队专属头像框、活动纪念票根 / 纪念章、DJ / Festival / Label 联名资产、限时活动动态徽章。
- 确认其他扩展不做：主页背景、聊天背景、入场动效、资料卡皮肤、评论区高亮、Feed 卡片皮肤、成就自动解锁、会员等级权益资产、资产图鉴、资产分享卡片。
- 确认 V1 不需要稀有度体系。
- 确认 V1 不需要动态资源。
- 确认支持资产下架。
- 确认支持未拥有预览。
- 确认每类资产需要固定尺寸限制。
- 确认可以做暗色/浅色两套适配。
- 确认气泡皮肤允许影响文字颜色，但必须保留可读性 fallback。
- 确认称号 label 和头像框沿用默认策略。
- 用户明确允许开始做开发。

关键决策：

- Phase 0 正式收口，后续新增资产类型不进入 V1 主线。
- 后端模型不再包含 `rarity` 字段，改用可选主题/来源信息承载运营分类。
- V1 的资源类型以静态图、颜色、渐变、代码 shape 为主，不设计动态资源渲染链路。

下一步：

- 进入 Phase 1：后端 Prisma 模型、基础 service、routes、seed 和本地验证。

### 2026-05-10：Phase 1 后端模型和基础 API 完成

本次完成：

- 新增 Prisma 模型：`VirtualAssetDefinition`、`UserVirtualAsset`、`UserVirtualAssetEquip`。
- 在 `User` 模型补充虚拟资产库存和装备关系。
- 新增 migration：`20260510110000_add_virtual_asset_skin_system`。
- 新增 `virtual-asset.service.ts`，覆盖目录、我的库存、装备/卸下、用户 appearance、管理员发放。
- 新增 `virtual-asset.routes.ts`，挂载到 `/v1`。
- 新增 `seed-virtual-assets.ts`，首批生成约 40 个种子资产，每类约 10 个。
- 新增 `npm run virtual-assets:seed` 命令。
- 主方案 Phase 1 checkbox 已同步更新。

关键决策：

- 数据库不使用稀有度字段，使用 `source` 和 `themeTags` 承载来源与视觉主题。
- appearance 聚合先放在 `virtual-asset.service.ts` 内，暂不拆独立 service，避免 Phase 1 过度拆分。
- 目录接口保持公开读取；我的库存、装备、管理员发放需要鉴权。
- 装备限制落地：头像框 1 个、消息气泡 1 个、称号 1 个、个人徽章最多 5 个。

已验证：

- `npx prisma validate` 通过。
- `npx prisma generate` 通过。
- `npm run build` 通过。

补充验证：

- `npx prisma migrate deploy` 已成功应用 `20260510110000_add_virtual_asset_skin_system`。
- `npm run virtual-assets:seed` 已成功写入 40 个种子资产。
- 服务级冒烟通过：创建临时用户、发放 `avatar_frame_v1_01`、装备头像框、读取 appearance，最后删除临时用户。

未执行：

- 尚未启动 Express 服务做 HTTP 级接口冒烟；服务层链路已验证。

下一步：

- 进入 Phase 2：iOS `Features/VirtualAssets` 模型、Repository、API 对接和缓存。
- 如果要做 HTTP 联调，启动 server 后验证 `/v1/virtual-assets/catalog`、`/v1/me/virtual-assets`、`/v1/me/virtual-assets/equips/:assetType`。

### 2026-05-10：Phase 2 iOS 模型、仓储和缓存完成

本次完成：

- 新增 iOS `Features/VirtualAssets` 模块。
- 新增 `VirtualAssetModels.swift`，覆盖资产类型、资产定义、用户库存、装备状态、appearance 聚合和通用 render payload。
- 新增 `VirtualAssetRepository.swift`，定义目录、我的库存、装备、用户 appearance、缓存读取接口。
- 新增 `VirtualAssetCacheStore.swift`，使用 UserDefaults 保存最近一次我的库存和用户 appearance。
- 新增 `LiveVirtualAssetRepository.swift`，对接 `/v1/virtual-assets/catalog`、`/v1/me/virtual-assets`、`/v1/me/virtual-assets/equips/:assetType`、`/v1/users/:id/appearance`。
- 新增 `MockVirtualAssetRepository`，保证 mock 环境也能进入虚拟资产链路。
- 接入 `AppEnvironment`、`AppContainer`、`RaverMVPApp` 依赖注入。
- 更新 Xcode project 文件，确保新增 Swift 文件进入 iOS target。
- 修正多徽章装备去重逻辑，保留用户选择顺序。
- `VirtualAssetType` 支持未知类型安全解析，避免未来后端扩展导致旧客户端解码崩溃。

关键决策：

- iOS 不把 render payload 拆成多套强类型结构，先使用 `VirtualAssetJSONValue` 承载通用 JSON，渲染层按资产类型读取自己需要的字段。
- Repository 提供显式 cache 读取方法，不在数据层强行吞掉所有网络错误；页面层后续根据场景决定是否展示缓存或默认样式。
- 装备接口在客户端侧先做空值过滤、去重和数量截断，后端仍保留最终校验，形成双保险。

已验证：

- `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 通过。

补充说明：

- 单独使用 `.xcodeproj` 构建会命中既有 Pods 依赖问题：`DJsModuleView.swift` 报 `no such module 'SDWebImage'`；workspace 构建通过，因此本阶段以 `.xcworkspace` 为准。
- 构建中仍有既有 warning，包括 project 文件重复 group 引用、Pods script phase output、`LiveSocialService` Swift 6 actor 隔离 warning、Metal toolchain search path warning；这些不是本阶段新增虚拟资产代码引入。

收口状态：

- Phase 2 主体已收口。
- `断网时 Profile 不崩溃` 留到 Phase 4 Profile 接入时验收，因为当前阶段尚未接入 Profile UI。

下一步：

- 进入 Phase 3：实现头像框、徽章、称号 label、气泡皮肤 renderer 和降级策略。

### 2026-05-10：Phase 3 统一渲染组件主体完成

本次完成：

- 新增 `Features/VirtualAssets/Rendering/VirtualAssetRenderers.swift`。
- 新增 `VirtualAssetAvatarView`，支持头像内容 + 头像框 overlay、小尺寸隐藏和缺图降级。
- 新增 `VirtualAssetBadgeView`，支持 icon、pill、icon_text 三类显示模式。
- 新增 `VirtualAssetTitleMedalView`，支持 capsule、ticket、ribbon、hex、slant、neon_plate 形状。
- 新增 `VirtualAssetChatBubbleRenderer`，支持 UIKit 气泡 solid/gradient/border 样式解析和文本颜色 fallback。
- 新增 `VirtualAssetChatBubbleContainer`，提供 SwiftUI 预览/资产中心可复用气泡容器。
- 新增 `VirtualAssetRenderPreviewView`，用于资产中心和后续设计验收做组合预览。
- 新增 light/dark variant payload 合并逻辑。
- 新增 hex、rgba、hsl 颜色解析和文本对比度校验。
- 更新 Xcode project，加入 Rendering group 和渲染文件。

关键决策：

- 渲染层只读取 `renderPayload`，不承担库存、装备、接口请求职责，避免 UI 组件和业务状态耦合。
- UIKit 聊天气泡先提供 renderer，不直接改 chat cell；Phase 5 接入时只调用 renderer，减少对消息滚动/重试/cluster 逻辑的扰动。
- 缺资源 URL 时组件保持稳定展示：头像框可退化为轻量描边，badge/title icon 可退化为 SF Symbol，气泡退回默认样式或安全文字色。

已验证：

- `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 通过。

未执行：

- 尚未做真实页面截图验收，`所有组件在 3 种尺寸下可读` 留到 Phase 4 资产中心预览页一起验。
- 尚未做低端模拟器滚动性能验收，留到 Phase 5 Messages 接入后验证。

收口状态：

- Phase 3 渲染组件主体已收口，可以进入 Profile 和资产中心接入。
- 本阶段没有新增第五类资产，没有改变后端模型主结构。

下一步：

- 进入 Phase 4：Profile 顶部接入 appearance，新增资产中心入口、列表、预览和装备/卸下操作。

### 2026-05-10：Phase 4 Profile 接入和资产中心主体完成

本次完成：

- Profile 顶部接入 `UserAssetAppearance`，头像使用 `VirtualAssetAvatarView` 展示头像框。
- Profile / UserProfile 昵称区域展示主称号和最多 5 个个人徽章。
- 个人主页快捷入口新增“装扮中心”。
- 新增 `VirtualAssetCenterView` 和 `VirtualAssetCenterViewModel`。
- 资产中心支持按头像框、徽章、气泡、称号四类分组查看。
- 资产中心支持展示拥有、未拥有、已装备、不可用/过期和限时状态。
- 资产中心支持装备/卸下；未拥有资产按钮禁用，只允许预览展示。
- 装备成功后通过 `virtualAssetAppearanceDidUpdate` 通知刷新 Profile appearance。
- 更新 Xcode project，加入 `Features/VirtualAssets/Center` 文件。
- 主方案 Phase 4 checkbox 已同步更新。

关键决策：

- 资产中心保持在 `Features/VirtualAssets` 模块内，Profile 只承担入口和路由，避免装扮业务继续塞进 Profile。
- 装备成功后的 Profile 刷新使用通知触发 `ProfileViewModel.refreshAppearance()`，不重新拉完整 Profile dashboard。
- 资产中心的未拥有资产先允许在列表中预览视觉效果，但不进入装备链路；后续商城/获取方式不进入 V1。

已验证：

- `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 通过。

补充说明：

- 本次未做真实模拟器截图验收；三尺寸视觉验收仍留作后续 UI 验收项。
- 构建仍存在既有 warning，包括 project 重复 group 引用、Pods script phase output、ScreenErrorCard/ScreenStatusBanner trailing closure warning、`LiveSocialService` Swift 6 actor 隔离 warning；这些不是本阶段新增功能阻塞项。

收口状态：

- Phase 4 主体已收口，可以进入 Phase 5 Messages 接入。

下一步：

- 进入 Phase 5：消息成员上下文补充 appearance，聊天头像框、昵称称号/徽章和 outgoing 气泡皮肤接入。

### 2026-05-10：Phase 5 Messages 核心接入完成

本次完成：

- 新增 `VirtualAssetChatAppearanceResolver`，按聊天 sender userID 预热并缓存 `UserAssetAppearance`。
- 新增 UIKit 聊天渲染辅助，DemoAligned cell 只调用 renderer，不在 cell 内散落资产解析逻辑。
- DemoAligned 文本消息接入 outgoing 气泡皮肤；媒体消息先接入头像框和昵称装饰，媒体气泡边框后置。
- DemoAligned 数据源在消息更新时预热 sender appearance，并在缓存更新后刷新 collection view。
- 线上 `TencentUIKitChatView` 注入 `VirtualAssetRepository`，对当前会话 sender appearance 做轻量缓存。
- 线上 Exyte 头像 builder、聊天 header 头像、文件/卡片自绘头像接入 `VirtualAssetAvatarView` 头像框。
- 线上群聊昵称行接入主称号和最高优先级徽章，保持只在 cluster 首条展示。
- `MainTabCoordinator` 将 appContainer 的 shared virtual asset repository 传入会话页面，避免聊天入口重复创建 repository。
- 更新 Xcode project，加入聊天 resolver/renderers 文件。

关键决策：

- `ChatMessage` 模型暂不直接持久化 appearance；聊天层使用 resolver 旁路缓存，避免影响消息收发、搜索、重试和历史消息编码。
- DemoAligned 路径完成 outgoing 文本气泡皮肤接入；线上 Exyte 默认文本气泡没有强行替换，避免破坏第三方 ChatView 的连续气泡和交互行为。
- 线上入口先完成头像框、群聊称号/徽章、资源失败 fallback；Exyte 默认文本气泡皮肤作为后续独立深化项。

已验证：

- `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 通过。

补充说明：

- 本次未做真实模拟器截图验收，也未做 200 条聊天滚动性能验收。
- 构建仍存在既有 warning，包括 project 重复 group 引用、Pods script phase output、ScreenErrorCard/ScreenStatusBanner trailing closure warning、若干 iOS deprecated API warning；这些不是本阶段新增功能阻塞项。

收口状态：

- Phase 5 核心接入已完成，可以进入视觉/性能验收或 Phase 6 轻量接入。
- 线上 Exyte 默认文本气泡皮肤展示仍未完成，建议作为 Phase 5 follow-up 单独处理。

下一步：

- 做聊天截图/滚动验收；确认头像框外扩尺寸、群聊昵称装饰和 DemoAligned 气泡皮肤视觉是否达标。
- 进入 Phase 6：Feed / 评论 / 通知轻量展示头像框、主称号和少量徽章。

### 2026-05-10：Phase 6 Feed / 评论 / 通知轻量接入完成

本次完成：

- 新增 `VirtualAssetListAppearanceResolver`，为 SwiftUI 列表场景统一预热和缓存 `UserAssetAppearance`。
- Feed 主列表 `FeedView` 预热当前 posts 作者 appearance，并传入 `PostCardView`。
- `PostCardView` 作者头像接入 `VirtualAssetAvatarView`；作者名旁最多展示 1 个主称号或 1 个徽章。
- `PostDetailView` 预热帖子作者和评论作者 appearance；评论头像接入头像框，评论作者名旁轻量展示称号/徽章。
- `NotificationsView` 预热通知 actor appearance；通知发送者头像接入头像框。
- `PostDetailLoaderView` 通过 appContainer 注入 shared virtual asset repository，避免页面重复创建 repository。
- 更新 Xcode project，加入 `VirtualAssetListAppearanceResolver.swift`。

关键决策：

- 列表页最大展示规则收口为：头像框 + 1 个主称号，若无称号则展示 1 个徽章；不展示完整徽章组。
- 列表 appearance 使用容器层 resolver 预热 author/actor id，子 view 只读缓存，避免每个 cell 自己触发请求。
- appearance 缺失或接口失败时保持普通头像/昵称，不显示 loading 占位，减少列表抖动。

已验证：

- `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 通过。

补充说明：

- 本次未做真实模拟器截图验收，也未做 Feed 50 条列表滚动性能验收。
- 构建仍存在既有 warning，包括 project 重复 group 引用、Pods script phase output、ScreenErrorCard/ScreenStatusBanner trailing closure warning、若干 iOS deprecated API warning；这些不是本阶段新增功能阻塞项。

收口状态：

- Phase 6 核心接入已完成，可以进入视觉/性能验收或 Phase 7 质量、灰度和上线收口。

下一步：

- 做 Feed / 评论 / 通知列表截图和滚动验收，确认列表不抖动、文字不拥挤。
- 进入 Phase 7：feature flag、埋点、回归清单和上线收口。

### 2026-05-10：Phase 7 灰度开关与基础埋点接入

本次完成：

- 新增 `AppConfig.virtualAssetsEnabled`，支持环境变量 `RAVER_VIRTUAL_ASSETS_ENABLED` 和 DEBUG 持久化开关。
- 新增 `DisabledVirtualAssetRepository`，关闭虚拟资产后返回空目录、空库存、空 appearance，主流程继续走普通头像/昵称。
- 设置页 DEBUG 开发分区新增“虚拟资产装扮”开关；提示需要重启 App 后生效。
- Profile 快捷入口在关闭 flag 后隐藏；直接进入资产中心 route 时显示禁用态兜底页。
- 新增 `VirtualAssetTelemetry`，由 `RaverMVPApp` 在启动层注入 `SocialService`，避免虚拟资产模块直接调用 `AppEnvironment`。
- 接入基础埋点：`preview`、`exposure`、`equip`、`unequip`、`load_failed`，覆盖资产中心、Profile/UserProfile、Messages、Feed、评论和通知。
- 顺手修复两个 coordinator hardening 边界命中：Search 结果页移除 `AppEnvironment.makeWebService()` 默认参数；注册头像上传改走 `AppContainer.socialService`。

关键决策：

- feature flag 关闭策略以“隐藏入口 + 禁用 repository + route fallback”为主，不删除页面代码，方便灰度回滚。
- 埋点先做最小闭环，复用现有 `recordFeedEvent`，事件名统一为 `virtual_asset_<event>`。
- 资产中心 catalog 预览埋点当前记录首批最多 24 个资产，作为 V1 轻量近似曝光；精确 viewport 曝光后续再做。

已验证：

- `git diff --check` 通过。
- `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- `scripts/check-mvvm-coordinator-boundaries.sh` 通过。
- `scripts/run-coordinator-hardening-preflight.sh` 通过。
- `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` 通过。

补充说明：

- coordinator hardening guard 已更新到当前全局 `AppRoute` 根栈架构：route snapshot 现在覆盖 `AppRoute`，模块 route 检查以 `MainTabCoordinator` destination 为准。
- 已刷新 `scripts/modal-allowlist-signatures.txt`，并在 `docs/MVVM_COORDINATOR_MIGRATION_PLAN.md` 记录同步原因。
- 本次未做真实模拟器截图验收，也未做聊天 200 条、Feed 50 条、资产中心 100 个列表滚动验收。
- 线上 Exyte 默认文本气泡皮肤仍是 Phase 5 后续深化项；当前 DemoAligned 文本路径已接入。

收口状态：

- Phase 7 灰度开关、基础埋点和质量闸门主体已完成，仍需视觉/性能验收。

下一步：

- 跑 feature flag 关闭/打开的模拟器手动验收：Profile 入口、资产中心 route fallback、Feed/Messages/Profile 基础路径。
- 做截图和滚动性能验收，补齐 Phase 3/5/6/7 遗留 UI QA。

---

## 新增需求停车场

### 暂无

模板：

```md
- 需求：
- 来源：
- 影响范围：
- 是否进入 V1：否
- 原因：
- 后续阶段：V1.1 / V2 / 暂不做
```

---

## 阶段收口记录

### Phase 0：已收口

收口条件：

- [x] V1 四类核心资产确认。
- [x] V1 不做项确认。
- [x] 装备数量限制确认。
- [x] 首批资产数量确认：每类约 10 个，总量约 40 个左右。
- [x] 资产中心入口确认：个人主页快捷入口新增一个 icon。
- [x] 后端和 iOS 模块边界确认。

### Phase 1：已收口

收口条件：

- [x] Prisma 模型完成。
- [x] migration 完成。
- [x] service 完成。
- [x] routes 完成。
- [x] seed 脚本完成。
- [x] Prisma validate 通过。
- [x] Prisma generate 通过。
- [x] TypeScript build 通过。
- [x] 本地数据库 migration 已执行。
- [x] seed 已写入本地数据库。
- [x] 服务级冒烟已执行。
- [ ] HTTP 冒烟已执行。

### Phase 2：已收口

收口条件：

- [x] `Features/VirtualAssets` 模块完成。
- [x] Swift 模型完成。
- [x] Repository protocol 完成。
- [x] Live Repository 完成。
- [x] AppContainer 依赖注入完成。
- [x] 轻量缓存完成。
- [x] 未知 asset type 安全解析完成。
- [x] 未知 render payload 字段安全解析完成。
- [x] Xcode project 文件校验通过。
- [x] iOS workspace build 通过。
- [ ] 断网 Profile UI 降级验收。

### Phase 3：主体已收口

收口条件：

- [x] 头像框组件完成。
- [x] 徽章组件完成。
- [x] 称号 label 组件完成。
- [x] 气泡皮肤 renderer 完成。
- [x] 资源加载降级完成。
- [x] 视觉预览组件完成。
- [x] 文本对比度 fallback 完成。
- [x] Xcode project 文件校验通过。
- [x] iOS workspace build 通过。
- [ ] 三尺寸视觉验收。
- [ ] 低端模拟器滚动性能验收。

### Phase 4：已收口

收口条件：

- [x] Profile 顶部接入头像框/称号/徽章。
- [x] UserProfile 接入他人 appearance。
- [x] 资产中心入口完成。
- [x] 资产中心列表、预览、装备和卸下完成。
- [x] iOS workspace build 通过。

### Phase 5：主体已收口

收口条件：

- [x] DemoAligned 消息头像框、群聊昵称称号/徽章、outgoing 文本气泡皮肤接入。
- [x] TencentUIKitChatView 生产路径接入 shared repository、头像框和群聊昵称轻量装饰。
- [x] 消息发送、重试、搜索和连续气泡规则不回退。
- [x] iOS workspace build 通过。
- [ ] 线上 Exyte 默认文本气泡皮肤完整替换。
- [ ] 200 条聊天滚动性能验收。

### Phase 6：主体已收口

收口条件：

- [x] Feed 作者头像接入头像框。
- [x] 评论作者接入轻量称号/徽章。
- [x] 通知发送者接入头像框。
- [x] 列表页 appearance 预热和缓存接入。
- [x] iOS workspace build 通过。
- [ ] Feed / 评论 / 通知截图验收。
- [ ] Feed 50 条列表滚动性能验收。

### Phase 7：进行中

收口条件：

- [x] `virtualAssetsEnabled` 灰度开关接入。
- [x] 关闭 flag 后禁用 repository、隐藏 Profile 入口、资产中心 route fallback。
- [x] 基础埋点接入：曝光、预览、装备、卸下、加载失败。
- [x] MVVM + Coordinator 边界检查通过。
- [x] 完整 coordinator hardening preflight 通过。
- [x] Xcode project 文件校验通过。
- [x] iOS workspace build 通过。
- [ ] feature flag 关闭/打开模拟器手动验收。
- [ ] fallback 场景截图验收。
- [ ] 列表和聊天滚动性能验收。
