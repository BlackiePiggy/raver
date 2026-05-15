# RaveHub iOS 日本 App Store 上架合规缺口分析

> 版本：2026-05-15  
> 范围：`mobile/ios/RaverMVP` iOS App、Widget、Notification Service、`server` BFF/API、`web` 管理后台与公开页面。  
> 目标：把后续开发围绕“日本区 App Store 可审核、可运营、可解释”推进。本文不是法律意见；日本本地法务、税务、支付和隐私最终仍需由专业顾问确认。

## 0. 商用级交付口径

本文用于说明缺口和风险来源；后续开发的完整验收标准以 `docs/IOS_JAPAN_COMMERCIAL_DELIVERY_REQUIREMENTS.md` 为准，实际进度以 `docs/IOS_JAPAN_APP_STORE_COMPLIANCE_PROGRESS.md` 的 checkbox 为准。

本项目不按“先做一个简化版，商用要求以后再补”的口径验收。功能只有覆盖用户端、服务端、管理后台、审计、通知、申诉/撤销、三语文案、法务说明、测试回归和运营流程后，才视为商用级完成。

新增两项核心要求：

- 中英日三语适配：现有中文/英文能力必须扩展为中文、英文、日文完整适配，覆盖 App、Web、后台、API 展示文案、通知、法务页面和 App Store Connect 日本区资料。
- 账号处罚与封禁体系：账号必须支持举报审核确认后的处罚/封禁、管理员手动封禁、固定天数和自定义时长封禁、永久封禁、功能限制、申诉、自动解封、审计和后台运营。

## 1. 官方依据

- Apple App Review Guidelines：UGC 必须有过滤、举报、拉黑和公开联系方式；隐私政策和账号删除为必备项；IAP、登录、定位、知识产权均有明确要求。  
  https://developer.apple.com/app-store/review/guidelines/
- Apple 账号删除说明：支持账号创建的 App 必须允许用户在 App 内发起删除整个账号和关联个人数据。  
  https://developer.apple.com/support/offering-account-deletion-in-your-app
- Apple App Privacy：提交新 App/更新前必须在 App Store Connect 填写数据收集、关联身份、追踪等隐私标签。  
  https://developer.apple.com/app-store/app-privacy-details/
- Apple Privacy Manifest：App/SDK 需用 `PrivacyInfo.xcprivacy` 声明收集数据和 Required Reason API。  
  https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Apple 年龄分级：App Store Connect 年龄分级是必填项，应按 UGC、聊天、定位、夜生活/活动内容、可购买内容如实回答。  
  https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating
- 日本个人信息保护委员会 PPC：日本个人信息保护法 APPI 及指南。  
  https://www.ppc.go.jp/en/legal/
- 日本消费者厅/特定商取引法：在线有偿服务、票务/数字商品等可能触发通信贩卖表示义务。  
  https://www.no-trouble.caa.go.jp/what/mailorder/
- 日本金融厅/资金结算法：若虚拟资产、点数、充值余额可预付购买或兑换，需要另行评估前払式支払手段/资金结算风险。  
  https://www.fsa.go.jp/policy/virtual_currency/

## 2. 当前项目事实

### 已具备

- iOS 主体为原生 Swift/SwiftUI，含消息、Feed、活动、DJ/Set、资料、Squad、通知、Widget。
- 后端有用户、帖子、评论、消息、投稿审核、OpenIM/Tencent IM、推送设备、虚拟资产等模型。
- 后端已有部分安全基础：密码 hash、refresh token、登录/SMS 限流、Admin Audit、内容投稿审核表。
- Feed 已有“隐藏帖子”能力，消息有部分本地删除/隐藏会话能力。
- App 使用 `PhotosPicker` 作为相册入口，多数图片选择不需要完整相册权限。
- 已补齐部分合规基础：账号删除基础 API、Settings 删除账号入口、通用举报/拉黑基础模型与 API、麦克风/相机/定位权限文案、Release live 默认配置、生产 HTTPS base URL、Display Name 去 MVP。
- 这些基础能力仍未达到商用级完成：外部系统清理、后台审计、举报审核处理台、账号处罚/封禁/申诉、日文完整适配、法务页面、Privacy Manifest、App Privacy 数据矩阵仍需补齐。

### 关键证据路径

- iOS 权限/ATS/展示名：`mobile/ios/RaverMVP/RaverMVP/Info.plist`
- iOS 生产配置：`mobile/ios/RaverMVP/RaverMVP/Core/AppConfig.swift`
- 推送启动时授权：`mobile/ios/RaverMVP/RaverMVP/RaverMVPApp.swift`
- 登录/注册/第三方入口：`mobile/ios/RaverMVP/RaverMVP/Features/Auth/LoginView.swift`
- 设置页法务入口占位：`mobile/ios/RaverMVP/RaverMVP/Features/Profile/SettingsView.swift`
- 举报入口占位：`mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift`、`Features/Feed/PostDetailView.swift`、`Features/Messages/ChatSetting/ChatSettingsSheet.swift` 等
- 账号删除与举报基础 API：`server/src/routes/bff.routes.ts`
- Prisma 用户/UGC/虚拟资产/举报模型：`server/prisma/schema.prisma`

## 3. 上架阻断项 P0

### P0-0 中英日三语适配

现状：项目已有中文/英文文案基础，但大量文案散落在 Swift 代码、后台、API 响应、Toast/Alert、法务占位和通知模板中；尚未形成日文完整适配。  
风险：日本区上线时，日文用户关键路径不可理解会影响审核体验、客服处理、合规告知和真实运营。

需补齐：

- App：登录、注册、设置、Feed、消息、发现、活动、DJ、Set、Squad、举报、封禁、申诉、账号删除、权限弹窗全部三语。
- Web/后台：法务页面、管理后台菜单/筛选/状态/处理原因、CMS 三语内容录入与缺失检查。
- API/数据：系统枚举统一 reason code，展示文案按 locale 返回或由端上本地化。
- 通知：站内信、推送、邮件/SMS 模板支持 `zh-CN`、`en`、`ja-JP`。
- App Store：日本区名称、副标题、描述、关键词、隐私 URL、客服 URL、审核说明全部日文可用。

验收：

- 日文系统环境冷启动默认进入日文。
- 日本区首屏关键路径无中文残留。
- 日文长文案、动态字体、小屏布局无截断和重叠。
- 后台可导出缺日文文案清单。

### P0-1 App 内账号删除

现状：已补账号删除基础 API 和 iOS Settings 删除账号入口，但外部系统清理、匿名化策略、审计后台、失败重试、法务说明仍不完整。  
风险：Apple 5.1.1(v) 明确要求支持账号创建的 App 必须在 App 内提供账号删除；仅停用账号或只提供客服流程通常不足以通过完整审核。

需补齐：

- iOS：完善 `设置 -> 账号安全 -> 删除账号` 的风险说明、提交后状态反馈、本地 token/IM/push 清理。
- Server：完善 `DELETE /v1/auth/account` 或等价删除请求的幂等、匿名化、token/APNs/IM 清理。
- 数据策略：定义立即删除、软删除、匿名化、法定留存数据范围；撤销 refresh token、APNs token、IM 账号/群成员、分享链接。
- 后台：账号删除审计和失败重试队列，尤其 Tencent IM/OpenIM 外部账号删除。
- 法务：隐私政策写明数据保留/删除政策和联系渠道。

验收：

- 审核账号可在 3 次点击内找到删除入口。
- 删除后无法登录，公开资料、帖子作者展示、IM 身份有明确匿名化策略。
- App Store Review Notes 说明删除路径。

### P0-2 UGC 举报、拉黑、审核闭环

现状：项目存在 Feed、帖子评论、消息、头像/昵称、内容投稿等 UGC；已补通用举报和用户拉黑基础模型/API，但多处 iOS“举报”仍是占位，Feed/评论/消息查询过滤、审核后台、SLA、处罚联动尚未形成闭环。  
风险：Apple 1.2 要求 UGC/社交服务具备过滤、举报、及时响应、拉黑、公开联系方式。

需补齐：

- 完善统一举报 API：帖子、评论、私信/群消息、用户资料、活动投稿、DJ/Set/Tracklist、图片/视频/音频。
- iOS 统一 `ReportSheet`：原因、补充说明、提交成功、后续处理说明。
- 用户拉黑：完善 `BlockUser` 模型/API 后续效果；被拉黑后禁止私信、隐藏对方内容、评论/互动受限。
- 内容过滤：发布前敏感词/图片/视频/音频基础检测；发布后人工审核队列。
- 后台：举报队列、处理状态、处理备注、封禁/下架/恢复、SLA 指标。
- 联系方式：App 内和 App Store 元数据提供 support/contact URL 或邮箱。

验收：

- 每个 UGC 表面都有可见举报入口并成功入库。
- 任意用户资料页可拉黑/解除拉黑。
- 管理后台可以在 24 小时内处理举报并留下审计。

### P0-2A 账号处罚、手动封禁与举报确认封禁

现状：已新增基础举报和用户拉黑数据模型/API，但账号层面的处罚状态、临时封禁、永久封禁、手动封禁、举报审核确认封禁、申诉、自动解封、后台审计仍未形成完整体系。  
风险：只有“举报入库”不能满足成熟社交产品的商业运营要求。日本区上线后若发生骚扰、违法内容、隐私泄露、未成年人安全等问题，缺少处罚闭环会导致无法及时响应用户、审核团队和 App Review 对 UGC 治理的要求。

需补齐：

- 数据模型：账号基础状态与处罚状态拆分，新增处罚记录、处罚范围、处罚原因、开始/结束/撤销时间、证据、内部备注、关联举报/案件/申诉/审计。
- 处罚类型：警告、内容下架、功能限制、临时封禁、永久封禁、风控冻结。
- 时长：支持 1/3/7/14/30/90 天和自定义日期，到期自动解除。
- 举报确认封禁：举报聚合为审核案件，审核员查看上下文和历史记录后可触发限制/封禁。
- 手动封禁：管理员可从用户详情页发起处罚；超过 30 天、永久封禁、批量封禁支持二次确认和四眼审核配置。
- API 拦截：登录、刷新 token、发帖、评论、私信、上传、改资料、创建活动、位置共享、IM token、推荐流均感知处罚状态。
- 用户体验：被封禁用户可查看原因、范围、到期时间、申诉入口、客服入口；仍可访问法务、申诉、账号删除和数据请求。
- 申诉：用户可提交申诉，后台可维持、解除、缩短、改判，并通知用户。
- 审计与报表：所有处罚、撤销、申诉决定写审计，后台可筛选、导出、统计 SLA。

验收：

- 被封禁用户不能通过旧 token、IM token 或重启 App 绕过限制。
- 管理员可手动封禁固定天数或自定义时长，并可撤销/延长/缩短。
- 举报处理可以一键关联到处罚记录，且举报人和被举报人收到不同通知。
- 临时封禁到期自动恢复，后台留有任务记录和审计。
- 每个处罚都可申诉，申诉处理有结果通知和后台备注。

### P0-3 隐私政策、用户协议、日文法务页面

现状：登录页显示《用户服务条款》《用户协议》《隐私政策》，但不是可点击法务文档；设置页“服务条款/隐私政策”是 `Text` 占位。  
风险：Apple 5.1.1(i) 要求 App Store Connect 与 App 内可访问隐私政策；日本上线还需要日文隐私说明和经营者联系信息。

需补齐：

- 公开 Web 页面：`/legal/privacy`, `/legal/terms`, `/legal/contact`, `/legal/tokushoho`。
- App 内 WebView/SafariView 打开这些页面，登录注册勾选处每个协议可点。
- 日文版本优先：`ja-JP`，至少同时保留中文/英文。
- 隐私政策必须覆盖：账号、手机号/邮箱、头像、UGC、消息、位置、推送 token、设备信息、日志、第三方 SDK、跨境传输、保存期限、删除/撤回同意。
- 若上线收费：补充特商法页面，包括经营者名称、地址、电话/邮箱、价格、支付方式、提供时点、取消/退款条件。

验收：

- App Store Connect 可填 Privacy Policy URL。
- 未登录也可访问隐私政策和联系方式。
- 登录前可分别打开条款/隐私政策。

### P0-4 权限声明与实际调用不一致

现状：`Info.plist` 只有定位、相册读/写文案；代码中使用 `AVAudioRecorder.requestRecordPermission`，聊天附件面板有“拍摄”；缺少 `NSMicrophoneUsageDescription` 和可能的 `NSCameraUsageDescription`。  
风险：缺少权限描述会在调用时崩溃或被审核质疑；权限文案需要完整描述用途。

需补齐：

- `NSMicrophoneUsageDescription`：用于聊天语音消息。
- `NSCameraUsageDescription`：如果“拍摄”入口实际可调相机；若未实现则先隐藏“拍摄”。
- `NSLocationWhenInUseUsageDescription` 调整：覆盖发帖地点选择、活动地点选择、Squad 位置共享，不只“小队活动”。
- 推送：避免首次启动立即弹系统权限；改为用户进入通知相关功能或明确软提示后再请求。
- 相册：若仅使用 `PhotosPicker` 读取，不声明 full photo library；保存海报保留 `NSPhotoLibraryAddUsageDescription`。

验收：

- 权限弹窗文案与触发功能一致。
- 拒绝权限后仍有手动地点、手动上传、文本聊天等替代路径。

### P0-5 隐私标签与 Privacy Manifest

现状：主 App target 未发现 `PrivacyInfo.xcprivacy`；Pods 中部分三方有 manifest，但 App 自身没有。项目使用 `UserDefaults`、文件属性时间、位置、账号信息、UGC、消息、推送 token、日志。  
风险：App Store Connect 隐私标签必填；Required Reason API 需要 manifest 说明。

需补齐：

- 新增主 App、Widget、Notification Service 的隐私清单。
- Required Reason API 初步候选：
  - `UserDefaults`：用户偏好、会话/本地缓存。
  - File timestamp / file metadata：IM 缓存清理、临时媒体文件治理、日志文件属性读取。
- App Privacy 数据类型初步候选：
  - Contact Info：邮箱、手机号。
  - Identifiers：用户 ID、设备 push token。
  - User Content：头像、帖子、评论、聊天消息、图片/视频/音频、投稿内容。
  - Location：活动地点、发帖地点、Squad 位置共享。
  - Usage Data / Diagnostics：搜索、Feed 埋点、错误日志、推送送达状态。
  - Contacts：当前未见系统通讯录读取；不要申报除非后续新增。
- 第三方 SDK：Tencent IM、SDWebImage、Ali OSS、Spotify/SoundCloud/Discogs API、APNs 等数据流需映射到隐私政策和隐私标签。

验收：

- Xcode Archive 生成隐私报告无缺失/无 invalid manifest。
- App Store Connect 隐私标签与代码和政策一致。

### P0-6 生产环境配置

现状：Release 默认 live、生产 HTTPS base URL、Display Name 去 MVP 已补齐；仍需收敛 `NSAllowsArbitraryLoads = true`、核实 APNs 生产配置，并确认 Release 包无 localhost/mock 默认残留。  
风险：审核包若仍存在 ATS 全开、开发推送或测试环境残留，会被审核质疑或影响真实审核体验。

需补齐：

- 保持 Release 默认 `.live`，Base URL 为生产 HTTPS，如 `https://api.raver.app`，并在归档前复查。
- 移除全局 `NSAllowsArbitraryLoads`，仅对确有必要的域名做例外，优先全部 HTTPS。
- 推送 entitlement 使用生产 APNs，App Store 签名会处理但配置需核实。
- Display Name 去掉 `MVP`，Bundle ID 和 App Store Connect 记录一致。
- App Review Notes 提供审核账号、测试路径、账号删除路径、UGC 审核说明。

验收：

- Release 包启动即连接生产 API，不依赖环境变量。
- 无 localhost、mock 默认、任意 HTTP 全局放行。

## 4. 日本市场高风险项 P1

### P1-1 日本个人信息保护/APPI

需补齐：

- 日文隐私政策，明确利用目的、第三方提供、委托处理、跨境传输、开示/订正/删除/停止利用请求方式。
- 数据主体请求流程：用户可在 App 或网页提交访问、更正、删除、导出请求。
- 泄露响应 Runbook：日本用户个人数据泄露时的内部响应、PPC 报告判断和用户通知模板。
- 数据最小化：未登录可浏览的功能尽量不强制注册；位置共享按活动显式开启。

### P1-2 特定商取引法

当前 App 可能展示票务链接、活动价格、虚拟资产，未来可能收费。需分流：

- 若仅跳转第三方官方票务购买实体活动门票：App 内说明“由第三方售票方提供”，不要在 App 内代收款。
- 若 RaveHub 自营有偿会员、数字装扮、投稿加速、推广位、数字内容：必须评估 IAP + 特商法表示页面。
- 页面字段：经营者名称、地址、电话/邮箱、负责人、价格、额外费用、支付方式/时点、提供时点、取消/退款、系统要求。

### P1-3 虚拟资产、积分、随机奖励

现状：有 `VirtualAssetDefinition`、`UserVirtualAsset`、装扮展示；尚未见 StoreKit。  
需补齐：

- 明确虚拟资产是否免费、活动奖励、付费购买、可转让、可兑换。
- 若付费购买数字装扮/积分：iOS 内必须走 IAP；IAP 货币不得过期；可恢复项需恢复购买。
- 若随机获得付费虚拟物品：披露概率，避免抽奖/赌博风险。
- 若可储值、转让、兑换第三方价值：日本资金结算法风险需法务确认。

### P1-4 年龄分级与未成年人保护

RaveHub 是电子音乐/活动/社交/聊天/位置共享产品，日本区应保守处理：

- App Store Connect 年龄问卷如实声明 UGC、聊天、位置共享、可能的成人场所/酒精相关活动。
- App 内增加出生年份/年龄声明，未成年限制：位置共享、私信陌生人、夜间活动报名/票务跳转、NSFW 内容。
- 不使用 Kids Category；元数据避免“儿童/学生专用”等暗示。

### P1-5 知识产权与第三方音乐/视频

现状：DJSet 存 `videoUrl`，曲目外链 Spotify/Apple Music/SoundCloud/YouTube/Netease；App 内有 AVPlayer 播放用户提交音视频 URL 的能力。  
需补齐：

- 确认不会下载/转码第三方媒体；只做授权 API/外链/嵌入允许的播放。
- 用户上传/提交 DJ Set、未发行曲链接时加入版权确认和举报侵权入口。
- 隐私/条款加入 DMCA/日本版权投诉联系机制。
- App Review Notes 说明第三方音乐服务使用方式和授权依据。

## 5. P2 上线质量与运营项

- 日文本地化：权限文案、登录、设置、举报、账号删除、法务页面、App Store 元数据至少日文优先。
- 通知偏好：App 内支持关闭营销/活动/私信/系统通知，并同步后端 subscription。
- 位置共享安全：进入 Squad 活动前解释谁可见、多久保存、如何停止；活动结束自动停止上传。
- 数据导出：不是 Apple 硬性审核项，但建议提供“下载我的数据”或客服流程。
- 安全配置：`server/src/utils/auth.ts` 存在默认 JWT secret fallback，生产必须强制环境变量；HTTPS、CORS、日志脱敏、OSS 权限需生产检查。
- 审核账号：准备一个日本区可用测试账号，含普通用户、可触发 UGC 举报、删除账号、推送、位置拒绝路径。
- App Store 元数据：避免夸大“官方/认证/合作”措辞；活动价格、排行榜、DJ 信息来源需准确。

## 6. 建议开发推进方式

开发可以按工作流分支推进，但验收不拆减商用范围。每个工作流都必须以 `docs/IOS_JAPAN_COMMERCIAL_DELIVERY_REQUIREMENTS.md` 和 `docs/IOS_JAPAN_APP_STORE_COMPLIANCE_PROGRESS.md` 的完整 checkbox 为完成口径。

### 工作流 A：合规基线与数据地图

- 确定日本上线商业模式：免费、票务外链、会员、虚拟资产是否收费。
- 确定公司主体、客服邮箱、日文法务页域名。
- 出字段级数据地图：字段、用途、第三方、保留期限、是否关联用户、是否追踪、删除策略、App Privacy 类型。

### 工作流 B：账号生命周期

- 账号删除：App、API、匿名化、token/APNs/IM 清理、外部系统重试、后台审计。
- 账号状态：active、pending deletion、deleted、disabled、restricted、suspended、banned。
- 处罚/封禁：手动封禁、举报确认封禁、固定天数、自定义时长、永久封禁、功能限制、自动解封。
- 申诉：用户提交、后台处理、通知、审计、报表。

### 工作流 C：UGC 安全与审核

- 统一举报、拉黑、内容过滤、审核案件、处理台、SLA、告警。
- Feed、评论、消息、资料、活动、DJ/Set、媒体内容、小队全部覆盖。
- 举报处理可触发内容处置、账号处罚、申诉和通知。

### 工作流 D：三语与日本法务

- App、Web、后台、API 展示、通知、邮件、App Store Connect 全面中英日适配。
- 日文隐私政策、服务条款、社区规范、特商法、联系方式、数据请求、版权投诉、未成年人安全页面。
- 法务页面版本管理、预览、回滚、缺失翻译检查。

### 工作流 E：权限、隐私与发布包

- 权限软提示、拒绝后替代路径、通知偏好、位置共享安全说明。
- Privacy Manifest、App Privacy 数据矩阵、第三方 SDK 数据流。
- Release live 配置、ATS 收敛、APNs、审核账号、Review Notes、TestFlight 回归。

### 工作流 F：商业化与特殊风险

- IAP/StoreKit、恢复购买、退款、订阅管理、虚拟资产规则。
- 特商法、资金结算法、概率披露、未成年人限制、版权投诉。
- 若某商业能力不上线，必须在 App、后台、API、法务和 App Store 元数据中同时隐藏或说明，避免审核和用户误解。

## 7. 可直接拆分的开发任务清单

- `ios/legal-links`：登录/设置接入隐私政策、服务条款、联系方式、日文页面。
- `ios/account-deletion`：Settings 删除账号 UI、二次确认、调用后端、退出清理。
- `api/account-deletion`：删除/匿名化账号 API、token/APNs/IM 清理、审计。
- `api/user-blocks`：BlockUser 模型、block/unblock/list API、Feed/消息/评论查询过滤。
- `api/reports`：统一 Report 模型、report API、后台处理状态。
- `ios/report-sheet`：统一举报 Sheet 替换所有“即将开放”占位。
- `admin/moderation-console`：举报队列、处理动作、封禁/下架/恢复、SLA。
- `ios/permissions-release-config`：Info.plist 权限、ATS、Release live URL、Display Name、APNs。
- `ios/privacy-manifest`：主 App/扩展 `PrivacyInfo.xcprivacy`，生成隐私报告。
- `compliance/app-privacy-matrix`：App Store Connect 隐私标签填报表。
- `legal/japan-pages`：日文隐私、条款、特商法、客服/数据请求页面。
- `commerce/decision-gate`：虚拟资产/票务/会员商业模式决策，决定隐藏或 StoreKit 化。

## 8. 当前最应优先开的第一批 Issue

1. 账号删除：这是明确审核阻断项。
2. UGC 举报 + 拉黑：RaveHub 的社交/聊天/投稿属性很强，是第二个硬阻断项。
3. 生产配置：继续核实 Release 包无 mock/localhost 残留，并收敛 ATS 全开和 APNs 生产配置。
4. 法务页面：没有可访问隐私政策，App Store Connect 也无法完整提交。
5. 权限/Privacy Manifest：缺麦克风/相机声明和 App 自身 manifest，容易在运行或归档阶段暴露。
