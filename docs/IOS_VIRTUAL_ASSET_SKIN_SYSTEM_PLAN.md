# iOS 虚拟资产皮肤系统落地方案

Last Updated: 2026-05-10  
Owner: Product + Design + iOS + Backend + Codex

## 1. 目标

为 Raver iOS 建立一套可持续扩展的虚拟资产皮肤系统，首期覆盖：

- 头像框
- 个人徽章
- 消息气泡皮肤
- 称号勋章 / Label 形状样式

这套系统要做到：

- 资产定义集中管理，不散落在各个页面里硬编码。
- 用户拥有关系、装备状态、展示渲染分层清晰。
- iOS 展示一致，Profile、Messages、Feed、Comments 等入口复用同一套渲染能力。
- 后端能支持资产发放、过期、装备、下架、运营活动和后续商业化。
- 开发过程可按 checkbox 跟踪，阶段性收口，避免新增虚拟资产无限扩张导致路线漂移。

---

## 2. 核心路线

### 2.1 V1 必做范围

- [x] 资产类型注册表：定义头像框、徽章、消息气泡、称号勋章四类资产。
- [x] 用户资产库存：记录用户拥有哪些资产、来源、有效期、状态。
- [x] 用户装备状态：记录每类资产当前装备项。
- [x] iOS 统一渲染组件：同一个资产 payload 在不同页面有一致降级和展示逻辑。
- [x] Profile 展示：个人页、公域用户资料页展示头像框、徽章、称号。
- [x] Messages 展示：聊天气泡皮肤、聊天头像框、昵称旁称号/徽章。注：DemoAligned 文本气泡和 TencentUIKitChatView 轻量展示已接入，线上 Exyte 默认文本气泡完整替换仍作为深化项。
- [x] 资产中心：查看已拥有/未拥有资产、装备/卸下。
- [ ] 灰度与降级：资产缺图、过期、下架、版本不兼容时不影响主流程。代码路径已接入，待模拟器截图和弱网验收。

### 2.2 V1 明确不做

- [ ] 不做完整商城支付闭环。
- [ ] 不做复杂拍卖/交易/转赠市场。
- [ ] 不做用户自定义上传头像框或气泡图。
- [ ] 不做强实时多人同步动画特效。
- [ ] 不做全量运营后台，只预留数据结构和简单管理能力。
- [ ] 不把资产系统嵌入每个页面单独开发，必须优先做统一模型和渲染层。

### 2.3 V1.1 / V2 候选扩展池

这些不进入 V1 主线，只作为后续版本候选；除以下明确保留项外，其他扩展不做。

- [ ] 小队身份徽章 / 小队专属头像框。
- [ ] 活动纪念票根 / 纪念章。
- [ ] DJ / Festival / Label 联名资产。
- [ ] 限时活动动态徽章。

明确不做：

- [ ] 个人主页背景皮肤 / 资料卡皮肤。
- [ ] 聊天背景皮肤。
- [ ] 入场动效 / 在线状态光效。
- [ ] 资料卡名片皮肤。
- [ ] 评论区高亮边框。
- [ ] Feed 帖子卡片皮肤。
- [ ] 成就体系自动解锁。
- [ ] 会员等级权益资产。
- [ ] 资产图鉴、稀有度收藏进度。
- [ ] 资产分享卡片。

---

## 3. 需求对接清单

开始开发前，需要把下面问题逐项确认并打勾。未确认项可以先按默认值实现，但必须记录在日志里。

### 3.1 产品规则

- [x] 资产是否分免费、活动、会员、付费、运营发放？确认：V1 包含会员资产和限时资产，其他来源保留扩展能力。
- [x] 资产是否会过期？确认：支持永久和限时两种。
- [x] 同一类型是否只能装备一个？确认：头像框、气泡、称号各只能装备一个；徽章可装备多个但个人主页 Hero 区最多展示 5 个。
- [x] 徽章最多展示几个？确认：个人主页 Hero 区最多展示 5 个；聊天昵称旁最多 1 个；列表页最多 2 个。
- [x] 是否支持稀有度？确认：不需要稀有度。
- [x] 是否支持动态资源？确认：不需要动态资源。
- [x] 是否支持资产下架？确认：支持；已拥有用户可继续展示或按配置隐藏。
- [x] 是否支持未拥有预览？确认：资产中心支持未拥有预览。
- [x] 首批每类资产数量？确认：每类约 10 个，总量约 40 个左右。
- [x] 称号文案是否允许用户自定义？确认：不允许，称号文案全部由系统预置。

### 3.2 设计规则

- [x] 每类资产是否有固定尺寸规范？确认：需要一定尺寸限制，按本文设计规格执行。
- [x] 是否需要暗色/浅色两套适配？确认：可以做暗色/浅色两套适配。
- [x] 气泡皮肤是否允许影响文字颜色？确认：允许，但必须提供可读性 fallback。
- [x] 称号 label 是否纯代码绘制还是图片切片？确认：沿用默认策略，首期优先代码绘制，复杂款可图片资源。
- [x] 头像框是否覆盖头像边缘还是外扩？确认：沿用默认策略，外扩 2-4pt，避免遮挡头像主体。
- [ ] 是否需要动效？默认：只允许轻量加载/装备反馈，不做持续高耗电动画。

### 3.3 技术规则

- [ ] 资产资源存储位置：默认走远程 CDN/OSS URL，本地只放占位和基础 fallback。
- [ ] 资产配置来源：默认后端 API 返回，不在 iOS 静态写死。
- [ ] 是否需要离线缓存：默认需要，使用图片缓存 + 最近一次装备状态缓存。
- [ ] OpenIM 用户资料是否需要同步资产摘要：默认不把完整资产写入 OpenIM，只在 Raver BFF 返回会话成员装扮信息。
- [ ] 是否需要埋点：默认需要，包含曝光、预览、装备、卸下、资源加载失败。

---

## 4. 虚拟资产分类

### 4.1 头像框 Avatar Frame

使用场景：

- 个人主页头像
- 公域用户资料页头像
- 聊天头像
- Feed / 评论 / 通知用户头像
- 小队成员列表

推荐字段：

- `assetType = avatar_frame`
- `frameImageURL`
- `frameInsets`
- `minAvatarSize`
- `supportsCircularAvatar`
- `renderPriority`

首期展示规则：

- 头像本身仍使用原头像 URL。
- 头像框作为透明 PNG/WebP 叠层。
- 加载失败时只展示原头像。
- 小尺寸头像低于 24pt 时默认不展示复杂头像框，避免糊成一圈霓虹蚊香。

### 4.2 个人徽章 Profile Badge

使用场景：

- 个人主页徽章墙
- 用户名旁身份展示
- 聊天昵称旁轻量展示
- Feed / 评论作者信息

推荐字段：

- `assetType = profile_badge`
- `iconURL`
- `compactIconURL`
- `title`
- `description`
- `displayMode = icon | pill | icon_text`
- `maxDisplayContext`

首期展示规则：

- 个人主页 Hero 区最多展示 5 个。
- 聊天和列表页只展示最高优先级 1-2 个。
- 官方认证、管理员、小队身份等功能性 badge 不与装饰徽章混用，需要单独分组。

### 4.3 消息气泡 Chat Bubble Skin

使用场景：

- 单聊文本消息
- 群聊文本消息
- 后续可扩展到媒体消息边框

推荐字段：

- `assetType = chat_bubble_skin`
- `bubbleStyle = solid | gradient | image_9slice`
- `backgroundColorHex`
- `gradientColors`
- `textColorHex`
- `borderColorHex`
- `cornerProfile`
- `imageURL`
- `capInsets`
- `incomingSupported`
- `outgoingSupported`

首期展示规则：

- 只影响自己发送消息的 outgoing bubble。
- incoming bubble 默认展示发送者的头像框和昵称徽章，但不强制套用对方气泡，避免群聊视觉过载。
- 文字颜色必须通过对比度检查；不合格则回退到默认文字色。
- 图片切片气泡进入 V1.1，V1 先完成 solid/gradient/code shape。

### 4.4 称号勋章 / Label Title Medal

使用场景：

- 昵称后方称号
- 个人主页称号区
- 聊天群昵称下方或旁边
- 资产中心预览

推荐字段：

- `assetType = title_medal`
- `labelShape = capsule | ticket | ribbon | hex | slant | neon_plate`
- `text`
- `textColorHex`
- `backgroundColorHex`
- `gradientColors`
- `borderColorHex`
- `iconURL`
- `maxTextLength`

首期展示规则：

- 用户可拥有多个称号，但只装备一个主称号。
- 系统称号文案由后端资产定义控制，用户不可自由编辑。
- 超长称号按上下文截断，资产中心可展示完整标题和描述。

### 4.5 其他建议资产

按优先级从高到低：

- [ ] 个人主页背景皮肤：增强资料页商业化和收藏价值。
- [ ] 聊天背景皮肤：强个性化，但容易影响阅读，建议 V2。
- [ ] 小队徽章 / 小队名牌：与 Raver 社群玩法匹配度高。
- [ ] 活动纪念章：适合活动打卡、票根、Festival 参与证明。
- [ ] DJ/Festival/Label 联名徽章：适合内容生态与运营合作。
- [ ] 入场动效：高感知但技术和性能成本高，建议后置。
- [ ] 资料卡皮肤：适合分享和个人主页展示，依赖资产中心成熟后推进。

---

## 5. 核心概念模型

### 5.1 资产定义 AssetDefinition

资产定义描述“这个资产是什么”。它是运营配置和客户端渲染的基础。

建议字段：

```ts
type VirtualAssetDefinition = {
  id: string;
  code: string;
  type: 'avatar_frame' | 'profile_badge' | 'chat_bubble_skin' | 'title_medal';
  name: string;
  description?: string;
  status: 'draft' | 'active' | 'hidden' | 'retired';
  renderPayload: Record<string, unknown>;
  previewImageURL?: string;
  source: 'system' | 'event' | 'membership' | 'purchase' | 'manual_grant';
  startsAt?: string;
  endsAt?: string;
  createdAt: string;
  updatedAt: string;
};
```

### 5.2 用户拥有 UserAssetOwnership

用户拥有关系描述“这个用户有没有这个资产”。

建议字段：

```ts
type UserVirtualAsset = {
  id: string;
  userId: string;
  assetId: string;
  acquisitionSource: 'default' | 'event_reward' | 'membership' | 'purchase' | 'admin_grant' | 'achievement';
  status: 'active' | 'expired' | 'revoked';
  acquiredAt: string;
  expiresAt?: string;
  metadata?: Record<string, unknown>;
};
```

### 5.3 用户装备 UserAssetEquipState

装备状态描述“用户当前展示哪一个资产”。

建议字段：

```ts
type UserVirtualAssetEquip = {
  userId: string;
  assetType: 'avatar_frame' | 'profile_badge' | 'chat_bubble_skin' | 'title_medal';
  equippedAssetIds: string[];
  updatedAt: string;
};
```

装备限制：

- `avatar_frame`: 最多 1 个。
- `chat_bubble_skin`: 最多 1 个。
- `title_medal`: 最多 1 个。
- `profile_badge`: 默认最多 6 个，聊天上下文只取优先级最高的 1 个。

### 5.4 展示摘要 UserAssetAppearance

展示摘要是页面最常用的数据结构，用于避免每个列表页都查询完整资产库存。

建议字段：

```ts
type UserAssetAppearance = {
  userId: string;
  avatarFrame?: VirtualAssetDefinition;
  titleMedal?: VirtualAssetDefinition;
  profileBadges: VirtualAssetDefinition[];
  chatBubbleSkin?: VirtualAssetDefinition;
  version: number;
};
```

使用原则：

- 列表、聊天、评论使用 appearance summary。
- 资产中心和装备页使用完整 inventory。
- appearance 可以由后端聚合返回，也可以由 iOS 在本地缓存中补齐，但首选后端聚合。

---

## 6. 后端设计

### 6.1 Prisma 模型建议

新增模型建议：

```prisma
model VirtualAssetDefinition {
  id              String   @id @default(uuid())
  code            String   @unique
  type            String
  name            String
  description     String?  @db.Text
  status          String   @default("draft")
  renderPayload   Json     @map("render_payload")
  previewImageUrl String?  @map("preview_image_url")
  source          String   @default("system")
  themeTags       String[] @default([]) @map("theme_tags")
  startsAt        DateTime? @map("starts_at")
  endsAt          DateTime? @map("ends_at")
  createdAt       DateTime @default(now()) @map("created_at")
  updatedAt       DateTime @updatedAt @map("updated_at")

  userAssets UserVirtualAsset[]

  @@index([type, status])
  @@index([source])
  @@map("virtual_asset_definitions")
}

model UserVirtualAsset {
  id                String   @id @default(uuid())
  userId            String   @map("user_id")
  assetId           String   @map("asset_id")
  acquisitionSource String   @default("default") @map("acquisition_source")
  status            String   @default("active")
  acquiredAt        DateTime @default(now()) @map("acquired_at")
  expiresAt         DateTime? @map("expires_at")
  metadata          Json?

  user  User @relation(fields: [userId], references: [id], onDelete: Cascade)
  asset VirtualAssetDefinition @relation(fields: [assetId], references: [id], onDelete: Cascade)

  @@unique([userId, assetId])
  @@index([userId, status])
  @@index([assetId])
  @@map("user_virtual_assets")
}

model UserVirtualAssetEquip {
  id         String   @id @default(uuid())
  userId     String   @map("user_id")
  assetType  String   @map("asset_type")
  assetIds   String[] @default([]) @map("asset_ids")
  updatedAt  DateTime @updatedAt @map("updated_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, assetType])
  @@index([userId])
  @@map("user_virtual_asset_equips")
}
```

注意：当前 `User` 模型已有头像、资料审核、OpenIM 同步等能力。虚拟资产不要直接塞进 `users` 表字段，避免用户主表继续膨胀。

### 6.2 API 草案

面向 iOS：

- [x] `GET /v1/virtual-assets/catalog`：资产目录，支持按类型过滤。
- [x] `GET /v1/me/virtual-assets`：我的资产库存 + 当前装备。
- [x] `PUT /v1/me/virtual-assets/equips/:assetType`：装备/卸下某类型资产。
- [x] `GET /v1/users/:id/appearance`：用户展示摘要。
- [x] `POST /v1/admin/virtual-assets/grants`：运营/管理员发放，V1 可先内部脚本化。

可随业务接口顺带返回：

- [ ] 会话成员信息返回 `appearance`。
- [ ] Feed 作者信息返回轻量 `appearance`。
- [ ] 评论作者信息返回轻量 `appearance`。
- [ ] 通知发送者信息返回轻量 `appearance`。

### 6.3 服务层建议

建议新增：

- [x] `virtual-asset.service.ts`：资产目录、库存、装备、发放和 appearance 聚合核心逻辑。
- [x] `virtual-asset.routes.ts`：iOS API 路由。
- [x] `seed-virtual-assets.ts`：本地种子资产。

服务规则：

- [x] 装备前必须校验用户拥有资产。
- [x] 装备前必须校验资产 `status = active`。
- [x] 装备前必须校验未过期。
- [x] 单装备类型自动替换旧装备。
- [x] 多装备类型按排序和数量上限截断。
- [x] 资产过期后 appearance 不再返回，库存页可显示为不可用。

---

## 7. iOS 设计

### 7.1 目录建议

建议新增统一模块：

```text
mobile/ios/RaverMVP/RaverMVP/Features/VirtualAssets/
  Models/
    VirtualAssetDefinition.swift
    UserVirtualAsset.swift
    UserAssetAppearance.swift
    VirtualAssetRenderPayload.swift
  Services/
    VirtualAssetService.swift
    VirtualAssetRepository.swift
    LiveVirtualAssetRepository.swift
  Rendering/
    AvatarFrameView.swift
    ProfileBadgeView.swift
    ChatBubbleSkinRenderer.swift
    TitleMedalLabelView.swift
    VirtualAssetImageLoader.swift
  Views/
    VirtualAssetCenterView.swift
    VirtualAssetInventoryView.swift
    VirtualAssetPreviewView.swift
  ViewModels/
    VirtualAssetCenterViewModel.swift
```

如果后续确认资产中心属于 Profile 子功能，也可以将入口放在 `Features/Profile`，但模型、渲染、仓储仍建议保持 `Features/VirtualAssets` 独立。

### 7.2 iOS 分层

- [ ] `View`：只负责渲染资产组件和触发装备意图。
- [ ] `ViewModel`：负责加载库存、预览状态、装备/卸下状态转换。
- [ ] `Repository`：负责 API 调用和本地缓存组合。
- [ ] `Renderer`：负责 payload 到 UIKit/SwiftUI 样式的转换。
- [ ] `Coordinator`：负责资产中心入口和资产详情/预览页面导航。

必须遵守现有 `MVVM + Coordinator` 增量规范：

- [ ] 不在 View 中直接调用 service factory。
- [ ] 新页面通过 Profile 或全局 Coordinator 接入。
- [ ] 默认 push-first。
- [ ] 装备结果通过 ViewModel 状态驱动 UI。

### 7.3 渲染组件边界

头像框组件：

- [ ] 输入：头像 URL、本地占位、`avatarFrame`。
- [ ] 输出：可复用头像视图。
- [ ] 降级：头像框加载失败时只展示头像。

徽章组件：

- [ ] 输入：badge asset、context size。
- [ ] 输出：icon / pill / icon_text 三种展示。
- [ ] 降级：图标加载失败时展示文本 pill 或隐藏。

称号组件：

- [ ] 输入：title medal payload、context。
- [ ] 输出：代码绘制 label。
- [ ] 降级：样式不支持时使用默认 capsule。

气泡渲染器：

- [ ] 输入：chat message、sender appearance、isMine、cluster 信息。
- [ ] 输出：bubble background、text color、corner radius、border。
- [ ] 降级：payload 不合法或对比度不足时使用现有默认气泡。

### 7.4 Messages 接入点

当前聊天气泡路径包含：

- `Features/Messages/UIKitChat/DemoAlignedMessageCell.swift`
- `Features/Messages/UIKitChat/DemoAlignedMediaMessageCell.swift`
- `Features/Messages/UIKitChat/RaverChatMessageCellFactory.swift`
- `Features/Messages/UIKitChat/RaverChatDataProvider.swift`

当前线上会话入口还包含：

- `Features/Messages/UIKitChat/TencentUIKitChatView.swift`

接入策略：

- [x] 不直接在 cell 内写死所有资产逻辑。
- [x] 先扩展 `ChatMessage` 或 sender context，使其包含轻量 `UserAssetAppearance`。
- [x] cell 调用 `ChatBubbleSkinRenderer` 和头像/徽章组件。
- [x] 渲染失败不影响消息收发、重试、滚动、已读、搜索。
- [x] 群聊中仅在 cluster 首条显示头像框和昵称徽章，保持现有连续气泡规则。

### 7.5 Profile 接入点

当前 Profile 相关路径包含：

- `Features/Profile/ProfileView.swift`
- `Features/Profile/UserProfileView.swift`
- `Features/Profile/ProfileViewModel.swift`
- `Features/Profile/UserProfileViewModel.swift`
- `Features/Profile/Coordinator/ProfileCoordinator.swift`

接入策略：

- [x] `ProfileViewModel` 加载我的 appearance 和资产中心入口状态。
- [x] `UserProfileViewModel` 加载他人 appearance。
- [x] Profile 顶部头像改用统一头像框组件。
- [x] 昵称区域展示主称号和少量徽章。
- [x] 我的页面增加“装扮中心/资产中心”入口。

---

## 8. 设计规格

### 8.1 通用视觉原则

- [ ] 资产要强化 Raver 的电子音乐、夜场、Festival、厂牌文化氛围。
- [ ] 不使用过度廉价的满屏闪光，优先精致、克制、有识别度。
- [ ] 小尺寸必须可识别，大尺寸可以展示细节。
- [ ] 不牺牲文字可读性和聊天效率。
- [ ] 同一屏多用户资产同时出现时，视觉不能打架。

### 8.2 资源尺寸建议

头像框：

- [ ] 透明 PNG/WebP。
- [ ] 设计基准：160x160、240x240、320x320。
- [ ] 安全区：头像主体 72%-82%，外圈装饰不超过 18%。
- [ ] 小尺寸策略：低于 32pt 使用 simplified frame 或隐藏。

徽章：

- [ ] 图标基准：48x48、72x72。
- [ ] 聊天小尺寸：12-16pt。
- [ ] 个人页尺寸：24-32pt。

称号 label：

- [ ] 高度：18pt、22pt、28pt 三档。
- [ ] 文案长度：中文建议 2-8 字，英文建议 4-16 字符。
- [ ] 支持 icon + text，但小尺寸只显示 text 或 icon。

消息气泡：

- [ ] V1 优先代码样式：solid、gradient、border、shadow。
- [ ] 最小内边距保持现有聊天气泡可读性。
- [ ] 文字颜色对比度不得低于 4.5:1，低于则 fallback。

### 8.3 视觉主题标签

V1 不做稀有度体系，但资产可以保留视觉主题标签，方便设计和运营归类。

- `festival`：活动现场、票根、纪念章氛围。
- `squad`：小队身份、组队、社群归属。
- `dj`：DJ 联名、舞台、声音波形元素。
- `label`：厂牌、Logo、唱片、黑胶元素。
- `member`：会员权益、身份识别，但不做单独会员等级资产池。

---

## 9. 开发步骤总览

### Phase 0：需求冻结与路线收口

- [ ] 确认 V1 四类资产范围。
- [ ] 确认 V1 不做项。
- [ ] 确认资产类型命名和渲染 payload 基本结构。
- [ ] 确认装备数量限制。
- [x] 确认首批种子资产数量：每类约 10 个，总量约 40 个左右。
- [x] 确认资产中心入口位置：个人主页快捷入口新增一个 icon。
- [x] 确认产品和设计核心规则：不做稀有度、不做动态资源、支持下架、支持未拥有预览、支持暗色/浅色适配。
- [ ] 更新开发日志，记录冻结范围。

收口标准：

- [ ] 本文档第 2、3、4 节无阻塞问题。
- [ ] 不再向 V1 增加第五类核心资产。

### Phase 1：后端数据模型和基础 API

大步骤：

- [x] 新增 Prisma 模型。
- [x] 新增 migration。
- [x] 新增资产 service。
- [x] 新增 API routes。
- [x] 新增 seed 脚本。
- [x] 增加基础测试或本地验证脚本。

小步骤：

- [x] 添加 `VirtualAssetDefinition`。
- [x] 添加 `UserVirtualAsset`。
- [x] 添加 `UserVirtualAssetEquip`。
- [x] 在 `User` relation 中补充关联。
- [x] 实现资产目录查询。
- [x] 实现我的库存查询。
- [x] 实现装备/卸下接口。
- [x] 实现用户 appearance 聚合。
- [x] 实现过期和下架过滤。
- [x] 写入约 40 个本地 seed 资产。

验收：

- [x] `GET /v1/me/virtual-assets` 返回库存和装备。
- [x] `PUT /v1/me/virtual-assets/equips/avatar_frame` 可装备并替换旧头像框。
- [x] 过期资产不能装备。
- [x] 未拥有资产不能装备。
- [x] appearance API 可返回当前装备摘要。

### Phase 2：iOS 模型、仓储和缓存

大步骤：

- [x] 新增 `Features/VirtualAssets` 模块。
- [x] 定义 Swift 模型。
- [x] 定义 Repository protocol。
- [x] 实现 Live Repository。
- [x] 接入 AppContainer 依赖注入。
- [x] 增加轻量本地缓存。

小步骤：

- [x] `VirtualAssetType` enum。
- [x] `VirtualAssetDefinition` model。
- [x] `VirtualAssetJSONValue` 通用 render payload model。
- [x] `UserVirtualAsset` model。
- [x] `UserAssetAppearance` model。
- [x] `VirtualAssetRepository` protocol。
- [x] `LiveVirtualAssetRepository` API 对接。
- [x] API 错误统一为用户可读错误。
- [x] 最近一次 appearance 缓存。

验收：

- [x] iOS 可加载我的库存。
- [x] iOS 可加载用户 appearance。
- [ ] 断网时 Profile 不崩溃。
- [x] 解析未知 asset type 不崩溃。
- [x] 解析未知 render payload 字段不崩溃。

### Phase 3：统一渲染组件

大步骤：

- [x] 头像框组件。
- [x] 徽章组件。
- [x] 称号 label 组件。
- [x] 气泡皮肤 renderer。
- [x] 资源加载降级。
- [x] 视觉预览页面。

小步骤：

- [x] `AvatarFrameView` 支持头像 + frame overlay。
- [x] `ProfileBadgeView` 支持 icon、pill、icon_text。
- [x] `TitleMedalLabelView` 支持 capsule、ticket、ribbon、hex、slant、neon_plate。
- [x] `ChatBubbleSkinRenderer` 支持 solid/gradient/border。
- [x] 文本对比度校验。
- [x] 小尺寸隐藏/简化策略。
- [x] 缺图占位和失败降级。

验收：

- [ ] 所有组件在 3 种尺寸下可读。
- [ ] 深色背景下对比度合格。
- [x] 缺资源 URL 时 UI 稳定。
- [ ] 低端模拟器滚动无明显卡顿。

### Phase 4：Profile 接入和资产中心

大步骤：

- [x] Profile 顶部接入头像框/称号/徽章。
- [x] UserProfile 接入他人 appearance。
- [x] 新增资产中心入口。
- [x] 新增资产中心列表和预览。
- [x] 实现装备/卸下。

小步骤：

- [x] Profile route 增加资产中心页面。
- [x] `ProfileViewModel` 加载我的 appearance。
- [x] `UserProfileViewModel` 加载他人 appearance。
- [x] 资产中心按类型分组。
- [x] 资产卡片展示拥有、未拥有、已装备、已过期状态。
- [x] 装备成功后刷新 Profile appearance。
- [x] 装备失败显示 toast/feedback。

验收：

- [x] 我的 Profile 展示当前装备。
- [x] 他人 Profile 展示对方装备。
- [x] 可在资产中心装备和卸下。
- [x] 装备后返回 Profile 即时更新。
- [x] 未拥有资产只能预览不能装备。

### Phase 5：Messages 接入

大步骤：

- [x] 消息成员上下文补充 appearance。
- [x] 聊天头像接入头像框。
- [x] 群聊昵称接入徽章/称号。
- [x] outgoing 文本气泡接入气泡皮肤。
- [x] 保护现有滚动、重试、搜索、连续气泡逻辑。

小步骤：

- [x] DataProvider 或 message context 返回 sender appearance。
- [x] `DemoAlignedMessageCell` 只调用 renderer，不内联业务判断。
- [x] `DemoAlignedMediaMessageCell` 至少接入头像框，气泡边框后置。
- [x] 群聊 cluster 首条展示头像框/称号。
- [x] 单聊对方昵称区域保持简洁。
- [x] 自己的 outgoing bubble 应用我的气泡皮肤。
- [x] 资源加载失败 fallback 到默认气泡。

验收：

- [ ] 单聊文本消息气泡皮肤生效。当前 DemoAligned 文本路径已接入；线上 Exyte 默认文本气泡仍需独立深化。
- [x] 群聊头像框/称号只在合适位置出现。
- [x] 连续气泡圆角规则不回退。
- [x] 消息发送失败、重试、搜索结果不受影响。
- [ ] 大量消息滚动性能可接受。

### Phase 6：Feed / 评论 / 通知轻量接入

大步骤：

- [x] Feed 作者头像接入头像框。
- [x] 评论作者接入轻量徽章/称号。
- [x] 通知发送者接入头像框。
- [x] 避免列表页视觉过载。

小步骤：

- [x] 定义 list context 的最大展示规则。
- [x] 列表页只展示 1 个主称号或 1 个徽章。
- [x] 小头像低于阈值隐藏复杂头像框。
- [x] 复用 appearance summary，避免 N+1 请求。

验收：

- [ ] 列表页不新增明显加载抖动。
- [x] appearance 缺失时回退普通头像/昵称。
- [x] 不影响现有 Feed/评论点击路径。

### Phase 7：质量、灰度和上线

大步骤：

- [x] 质量闸门。
- [x] 埋点。
- [x] 灰度开关。
- [x] 回归清单。
- [x] 文档收口。

小步骤：

- [ ] 后端接口错误码整理。
- [ ] iOS fallback 场景截图确认。
- [x] 添加 feature flag：`virtualAssetsEnabled`。
- [x] 添加埋点：资产曝光、预览、装备、卸下、加载失败。
- [x] 跑 coordinator hardening preflight。
- [x] 跑 iOS build。
- [x] 更新开发日志。
- [x] 更新相关回归文档。

验收：

- [ ] 关闭 feature flag 后所有入口恢复原样。代码路径已接入，待模拟器视觉验证。
- [ ] 打开 feature flag 后核心路径通过。iOS build 已通过，待端到端手动验收。
- [x] 资产接口失败不阻断 Profile 和 Messages。
- [x] 文档 checkbox 与实际状态一致。

---

## 10. 防漂移机制

### 10.1 每阶段必须收口

每个 Phase 完成后必须更新：

- [ ] 本主方案对应 checkbox。
- [ ] `docs/IOS_VIRTUAL_ASSET_SKIN_SYSTEM_DEV_LOG.md`。
- [ ] 当前阶段的“新增需求停车场”。
- [ ] 下一阶段入口条件。

### 10.2 新需求准入规则

新增需求进入 V1 必须同时满足：

- [ ] 不新增第五类核心资产。
- [ ] 不改变已确认的数据模型主结构。
- [ ] 不阻塞 Profile 和 Messages 两条主路径。
- [ ] 可在 1 个小阶段内完成并验收。
- [ ] 有明确降级策略。

不满足则放入 V1.1/V2 候选扩展池。

### 10.3 停车场模板

```md
- 需求：
- 来源：
- 影响范围：
- 是否进入 V1：否
- 原因：
- 后续阶段：V1.1 / V2 / 暂不做
```

---

## 11. 测试清单

### 11.1 后端

- [x] 资产目录查询。2026-05-10 验证本机 `/v1/virtual-assets/catalog` 返回 40 个资产，每类 10 个。
- [x] 我的库存查询。2026-05-10 验证 `blackie` 返回 40 个库存。
- [x] 装备成功。2026-05-10 验证 `PUT /v1/me/virtual-assets/equips/profile_badge` 返回 200。
- [ ] 重复装备幂等。
- [ ] 未拥有资产装备失败。
- [ ] 过期资产装备失败。
- [ ] 下架资产展示策略正确。
- [ ] appearance 聚合正确。
- [ ] 多徽章数量限制正确。

### 11.2 iOS

- [x] Profile 加载成功。
- [x] Profile 加载失败 fallback。
- [x] UserProfile 展示他人 appearance。
- [x] 资产中心分组展示。
- [x] 装备/卸下状态刷新。
- [ ] 聊天气泡皮肤展示。当前 DemoAligned 文本路径已接入；线上 Exyte 默认文本气泡仍需独立深化。
- [x] 聊天头像框展示。
- [x] 群聊 cluster 规则不回退。
- [x] Feed / 评论 / 通知轻量展示。
- [ ] feature flag 关闭回退。代码路径已接入，待模拟器视觉验证。

### 11.3 视觉 QA

- [ ] 小头像 24pt。
- [ ] 中头像 40pt。
- [ ] 大头像 96pt。
- [ ] 聊天气泡短文本。
- [ ] 聊天气泡长文本。
- [ ] 中英文称号。
- [ ] 缺图 fallback。
- [ ] 弱网加载。
- [ ] 暗色背景对比度。

### 11.4 性能

- [ ] 聊天 200 条消息滚动。
- [ ] Feed 50 条列表滚动。
- [ ] 资产中心 100 个资产列表滚动。
- [ ] 图片缓存命中后无明显闪烁。
- [ ] 首屏不因 appearance 串行请求变慢。

---

## 12. 推荐命令

后端：

```bash
cd server
npx prisma validate
npx prisma migrate dev
npm test
```

项目级预检：

```bash
scripts/run-coordinator-hardening-preflight.sh
```

iOS build：

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build
```

---

## 13. 相关文档

- `docs/IOS_INCREMENTAL_FEATURE_DEVELOPMENT_GUIDE.md`
- `docs/OPENIM_CHATLAYOUT_DEMO_ALIGNMENT_PLAN.md`
- `docs/CHAT_CUSTOM_CARDS_PLAN.md`
- `DESIGN_SYSTEM.md`
- `docs/IOS_VIRTUAL_ASSET_SKIN_SYSTEM_DEV_LOG.md`
