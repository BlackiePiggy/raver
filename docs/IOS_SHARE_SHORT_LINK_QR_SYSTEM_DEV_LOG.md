# iOS 分享短链与二维码系统开发日志

关联主方案：`docs/IOS_SHARE_SHORT_LINK_QR_SYSTEM_PLAN.md`
关联执行清单：`docs/IOS_SHARE_SHORT_LINK_QR_SYSTEM_EXECUTION_TRACKER.md`

## 记录规则

- 这里只记录重要开发日志、关键设计调整、阶段性完成情况
- 不记录日常碎片讨论，不把这里写成需求文档
- 每条日志尽量包含日期、阶段、动作、结果、后续影响

---

## 2026-05-07

### 初始化

- 建立了主方案文档之外的两份配套文档：执行清单和开发日志。
- 执行方式明确为“先主线、再收尾、再扩展”，防止开发过程中不断外扩能力边界。
- 当前 Phase 1 核心对象冻结为：`user_card`、`squad_card`、`post`、`event`、`news`、`squad_invite`。
- 当前域名策略冻结为：第一阶段统一走 `https://raver.app/s/{code}`，`ravehub.top` 备案完成后再迁移，不阻塞现阶段开发。

### 当前建议起步切片

- 先梳理 Prisma schema、后端路由入口和现有 iOS 分享入口。
- 第一批代码只做主链路，不先碰奖励扩展、复杂对象扩展和后台扩展。

### 代码入口梳理

- 后端主入口已经确认：`server/src/routes/bff.routes.ts` 是本期分享 BFF 的首选落点，现有 `POST /feed/posts/:id/share` 可作为事件写法参考。
- 后端服务挂载入口已经确认：`server/src/index.ts` 已挂载 `bff.routes` 和 `bff.web.routes`，说明后续增加 `/api/bff/share-links/*` 和最小承接页路由都能沿现有结构演进。
- Prisma 当前尚未有统一分享链路表，但已存在 `SquadInvite`、`PostShare` 等局部模型，后续要避免与新 `share_links` / `invite_referrals` 设计冲突。
- iOS 现有分享入口已经确认：`PostCardView`、`PostDetailView`、`EventDetailView`、`DiscoverNewsDetailView`、`ShareActionPanel` 是第一批核心改造点。
- 已确认存在直接复制旧链接的入口：
  - `PostCardView` 直接复制 `PostSharePayload(post: post).shareURLString`
  - `DiscoverNewsDetailView` 直接复制外链或 `newsDeeplink(...)`
- 这说明第一刀代码应先从“统一 payload 生成 + resolve API + copy link 替换”入手，而不是先扩展更多对象。

### 下一步编码建议

- 先看清 `SquadInvite` 现有数据模型和 `bff.web.routes.ts` 的承载能力。
- 然后设计第一版 Prisma migration，优先把 `share_links`、`share_link_events`、`invite_referrals` 定义清楚。
- 在 migration 定稿前，不先改大面积 iOS UI，避免前端先跑偏。

### 数据层第一刀已完成

- 已在 `server/prisma/schema.prisma` 中新增分享基础模型：`ShareLink`、`ShareLinkEvent`、`InviteReferral`。
- 已补充用户/群的永久分享字段：`users.profile_share_code`、`users.profile_share_qr_code_url`、`squads.share_code`。
- 已创建 migration：`server/prisma/migrations/20260507183000_add_share_link_foundation/migration.sql`。
- 已确认现有 `SquadInvite` 保持原有“站内邀请关系”职责，不直接替代新的外部分享邀请码短链模型。
- 已完成本地校验：
  - `./node_modules/.bin/prisma format --schema prisma/schema.prisma`
  - `./node_modules/.bin/prisma validate --schema prisma/schema.prisma`
- 这一刀只做数据层，不触发 UI 扩散，符合当前“先主链路、先收尾”的执行原则。

### 下一步

- 进入 BFF 第一版接口实现，只做 `resolve / detail / event` 三个主接口和 `/s/:code` redirect 主链路。
- 暂不进入二维码图片生成、海报生成、奖励发放细则实现，避免并行外扩。

### BFF 主链路第二刀已完成

- 已新增分享服务：`server/src/services/share-link.service.ts`。
- 已落 BFF API：
  - `POST /v1/share-links/resolve`
  - `GET /v1/share-links/:code`
  - `POST /v1/share-links/:code/events`
- 已新增公开分享入口：`GET /s/:code`，路由文件为 `server/src/routes/share.routes.ts`，并挂载到根路径。
- `GET /s/:code` 当前策略是：
  - 校验链接状态
  - 记录 `open` 事件
  - 有效时 302 到 `canonicalUrl`
  - 失效时返回最小 HTML 状态页
- 当前故意没有在这一刀实现：
  - `GET /qr/:code.png`
  - `GET /poster/:code.png`
  - `squad_invite` 的完整创建 / redeem / 发奖链路
- 这样做是为了先把主链路闭环，不把第二刀膨胀成“分享系统全量实现”。

### 本轮校验

- `./node_modules/.bin/prisma generate` 已完成。
- `npm run build` 已通过。

### 下一步

- 进入 iOS 核心服务层：`ShareTargetType`、`ShareTarget`、`ShareLinkPayload`、`ShareLinkService`。
- 第一批只替换 Post / Event / News 的复制链接，不先大面积改所有分享面板。

### iOS 核心服务第三刀已完成

- 已新增 iOS 分享基础模块：`mobile/ios/RaverMVP/RaverMVP/Core/ShareLinkService.swift`。
- 本刀已落地的核心抽象包括：
  - `ShareTargetType`
  - `ShareTarget`
  - `ShareLinkPayload`
  - `ShareLinkService`
  - `ShareLinkCoordinator`
- 已把分享服务接入 `AppEnvironment`，避免各页面自行拼接请求逻辑。
- 第一批 UI 接入范围严格控制在 `Post / Event / News` 的“复制链接”动作，没有扩散到二维码、海报、邀请奖励、更多对象迁移。
- 当前已完成的 iOS 接入点：
  - `Shared/PostCardView.swift`
  - `Features/Feed/PostDetailView.swift`
  - `Features/Discover/Events/Views/EventDetailView.swift`
  - `Features/Discover/News/Views/DiscoverNewsDetailView.swift`
- 复制链接当前策略为：
  - 优先请求后端 `resolve` 拿 `https://raver.app/s/{code}`
  - 后端失败时回退到 `canonicalUrl`
  - 再不行回退到 App 内 deep link
- 这一刀过程中出现了 2 个编译错误，都是 `OperationBannerCenter.shared.success(...)` 调用签名不匹配，已修复。

### 本轮校验

- 已完成 iOS 整包编译回归：
  - `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build -quiet`
- 本轮结果：构建通过，退出码为 `0`。
- 当前仍存在若干历史 warning，例如：
  - Xcode project 中 `RaverMVP/Core/Widget` 的重复 group 引用 warning
  - 若干 SwiftUI trailing closure deprecation warning
  - 若干 iOS API deprecation warning
- 这些 warning 不属于当前分享系统切片引入的问题，因此本轮没有扩边界去处理。

### 下一步

- 进入下一收尾切片，优先做个人名片 / 群名片 / 私密群邀请中的数据与接口主线。
- 在进入邀请奖励前，继续坚持“先闭环分享主链路，再补增长闭环”的顺序，不提前扩散到二维码图片渲染和海报系统。

### 个人名片 / 群名片 / 私密群邀请第四刀已完成

- 已在后端补齐 `squad_invite` 第一版主链路：
  - `POST /v1/share-links/resolve` 现已支持 `squad_invite`
  - `POST /v1/share-links/:code/redeem` 已新增
- 当前邀请码策略固定为第一版最小商用口径：
  - 默认 72 小时过期
  - 默认最多 10 次使用
  - 仅小队成员可生成邀请链接
  - 不允许自己兑换自己的邀请链接
  - 校验过期、次数耗尽、小队人数已满
- `redeem` 当前已完成的闭环职责：
  - 将用户加入 `squad_members`
  - 调用 Tencent IM 群成员加入
  - 记录 `invite_referrals`
  - 写入 `invite_accept` 事件
  - 递增 `share_links.used_count`
- 当前刻意没有在这一刀实现的邀请码扩展：
  - 邀请码重置
  - 发奖规则执行
  - 二维码图片 / 海报图片生成
  - Universal Link Router 全量接入

### iOS 本轮接入

- 已补当前个人主页复制入口：`Features/Profile/ProfileView.swift`
- 已补他人主页复制入口：`Features/Profile/UserProfileView.swift`
- 已补小队主页复制入口：`Features/Squads/SquadProfileView.swift`
- 当前小队分享策略：
  - 公开小队复制永久 `squad_card` 链接
  - 私密小队复制临时 `squad_invite` 邀请链接
- iOS 分享服务已补充可选参数：
  - `preferPermanent`
  - `expiresInHours`
  - `maxUses`

### 本轮校验

- 服务端构建通过：
  - `npm run build`
- iOS 整包编译再次通过：
  - `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build -quiet`
- 本轮结果：
  - server build 退出码 `0`
  - iOS build 退出码 `0`

### 下一步

- 继续收尾 `Step D` 中还没完成的部分：
- 邀请码重置
- 个人 / 小队二维码资产
- `qrCodeUrl` 兼容迁移
- 在这些完成前，不提前进入奖励发放复杂逻辑，也不扩展到海报系统。

### 二维码资产与邀请码重置第五刀已完成

- 已新增公开二维码接口：`GET /qr/:code.png`
- 当前二维码生成策略：
  - 服务端直接基于短链 `https://raver.app/s/{code}` 输出 PNG
  - 当前先只做二维码图片，不在这一刀扩展海报图片
- 已完成用户 / 小队二维码兼容回填：
  - 用户资料接口会自动补永久分享二维码地址
  - 小队资料接口在没有旧 `qrCodeUrl` 时，会自动回填新的分享二维码地址
  - 公开小队回填 `squad_card` 二维码
  - 私密小队回填当前成员自己的 `squad_invite` 二维码
- 已新增邀请码重置能力：
  - `POST /v1/share-links/:code/reset`
  - 当前策略为“撤销旧邀请码 + 生成新邀请码”
  - 仅原邀请码创建者可以重置

### 本轮工程调整

- 服务端新增二维码依赖：
  - `server/package.json`
  - `server/pnpm-lock.yaml`
- 分享公开路由已扩展：
  - `server/src/routes/share.routes.ts`
- 分享服务已扩展：
  - 二维码 URL helper
  - 邀请码 reset service
  - `server/src/services/share-link.service.ts`
- BFF 已扩展：
  - 资料页二维码回填
  - 邀请码 reset 路由
  - `server/src/routes/bff.routes.ts`
- iOS `UserProfile` 已接收 `qrCodeURL` 字段，便于后续个人二维码页直接接入：
  - `mobile/ios/RaverMVP/RaverMVP/Core/Models.swift`

### 本轮校验

- 服务端构建通过：
  - `npm run build`
- iOS 整包编译通过：
  - `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build -quiet`
- 本轮结果：
  - server build 退出码 `0`
  - iOS build 退出码 `0`

### 下一步

- 继续做 `qrCodeUrl` 兼容迁移的最后一小步：
  - 梳理旧编辑入口和新分享二维码的边界，避免“自填二维码 URL”和“系统生成二维码 URL”长期混用
- 然后再进入下一阶段：
  - 个人二维码页
  - 小队二维码页
  - 邀请奖励状态流转

### 二维码详情页与旧编辑入口收尾第六刀已完成

- 已在 iOS 侧补齐统一二维码详情页，当前通过一个轻量复用视图承接：
  - 个人主页二维码页
  - 他人主页二维码页
  - 小队二维码页
- 当前二维码页策略保持最小闭环，不扩展到保存图片或海报编辑：
  - 展示分享对象基础信息
  - 展示系统生成的二维码图片
  - 明确二维码与短链一致、后续切域名时历史码继续兼容
- 已完成导航接入：
  - `ProfileRoute` 新增 `shareQRCode`
  - 个人主页工具栏增加二维码入口
  - 他人主页工具栏增加二维码入口
  - 小队主页工具栏增加二维码入口
  - 小队详情中的二维码卡片支持点按进入详情页

### 本轮边界清理

- 已从 iOS 小队编辑页移除旧的“手填二维码 URL”输入入口
- 当前策略调整为：
  - 二维码统一由分享系统自动生成
  - `UpdateSquadInfoInput.qrCodeURL` 继续保留兼容字段
  - iOS 编辑流程不再暴露人工编辑入口，避免与新系统长期混用
- 这一步只清理了主线冲突入口，没有扩散去修改服务端兼容字段或历史翻译词条

### 本轮工程落点

- 路由扩展：
  - `mobile/ios/RaverMVP/RaverMVP/Features/Profile/Coordinator/ProfileCoordinator.swift`
  - `mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`
- 二维码详情页与个人页入口：
  - `mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift`
- 他人主页二维码入口：
  - `mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift`
- 小队二维码入口与旧编辑入口清理：
  - `mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift`

### 本轮校验

- iOS 整包编译通过：
  - `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build -quiet`
- 本轮结果：
  - iOS build 退出码 `0`
- 当前仍存在历史 warning：
  - `RaverMVP/Core/Widget` 的 group warning
  - 若干 SwiftUI trailing closure deprecation warning
  - 若干 link/script phase warning
- 这些 warning 不属于本轮分享系统切片引入的问题，因此本轮没有扩边界处理

### 下一步

- 进入 `Step E`，先做最小奖励状态流转：
  - `pending -> granted / rejected`
  - 基础防重复发奖
  - 最小发奖日志或状态变更记录
- 在奖励状态闭环完成前，不提前扩到海报系统、复杂运营后台或 Android 端接入

### 邀请奖励最小状态闭环第七刀已完成

- 已在服务端完成第一版奖励状态决策收口，当前 `redeem` 不再只停留在 `pending`：
  - 合格邀请加入：写入 `granted`
  - 不合格邀请兑换：写入 `rejected`
- 当前一期奖励规则刻意保持最小商用口径，不扩成复杂积分系统：
  - 触发条件：首次通过分享邀请码成功加入小队
  - 发奖结果：即时决策，不引入异步审核队列
  - 防重复：同一 invitee 如果已经有历史 `granted`，后续邀请奖励拒绝
  - 异常拒绝：已是成员、缺少 inviter、自邀等场景直接拒绝奖励

### 本轮实现细节

- 已补奖励决策 helper，统一产出：
  - `rewardStatus`
  - `rewardReason`
  - `rewardType`
  - `qualifiedAt`
  - `grantedAt`
- 已补邀请兑换返回值：
  - `rewardStatus`
  - `rewardReason`
- 已补奖励事件记录：
  - 奖励发放时新增 `reward_grant` 事件
- 已补邀请关系状态落库：
  - `invite_referrals.reward_status`
  - `invite_referrals.reward_type`
  - `invite_referrals.reward_payload`
  - `invite_referrals.qualified_at`
  - `invite_referrals.granted_at`

### 当前一期奖励口径

- `granted`
  - 首次成功邀请新成员加入小队
- `rejected`
  - invitee 已经是该小队成员
  - inviter 缺失
  - inviter 与 invitee 相同
  - invitee 已存在历史已发奖邀请
- `pending`
  - 字段仍保留兼容，但当前主链路已优先在兑换时直接收敛到 `granted / rejected`

### 本轮工程落点

- 奖励状态与事件逻辑：
  - `server/src/services/share-link.service.ts`

### 本轮校验

- 服务端构建通过：
  - `npm run build`
- 本轮结果：
  - server build 退出码 `0`

### 下一步

- 继续完成 `Step E` 里还没收口的部分：
  - 分享链路 `copy / open / redirect / app_open` 埋点补齐
  - 承接页最小状态页与 `Open App / Download App` 按钮
  - 风控与回归测试
- 在这些没收尾前，不进入海报系统和复杂奖励后台
