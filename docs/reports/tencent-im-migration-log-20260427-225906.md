# Raver 腾讯云 IM 迁移执行日志

> 状态：进行中  
> 分支：`thirdPartyIM`  
> 日志创建时间：2026-04-27 22:59:06 +0800  
> 对应总方案：`docs/TENCENT_IM_MIGRATION_MASTER_PLAN.md`

## 1. 当前目标

将 Raver 的聊天能力从当前自建 / OpenIM 方向切换到腾讯云 IM，并最终形成单一、可维护、可交接的第三方 IM 基础设施。

## 2. 当前共识

- [x] 2026-04-27 22:59:06 +0800 已确认：不再继续走 OpenIM 路线。
- [x] 2026-04-27 22:59:06 +0800 已确认：新的迁移工作在 `thirdPartyIM` 分支进行。
- [x] 2026-04-27 22:59:06 +0800 已确认：旧自建 IM 可以被完全摒弃，不要求长期并行。
- [x] 2026-04-27 22:59:06 +0800 已完成：生成迁移总方案文档。
- [x] 2026-04-27 22:59:06 +0800 已完成：生成本执行日志文档。
- [x] 2026-04-27 23:04:54 +0800 已确认：一期只做 `iOS`。
- [x] 2026-04-27 23:04:54 +0800 已确认：旧聊天历史不保留，采用`不迁移 + 归档`。
- [x] 2026-04-27 23:04:54 +0800 已确认：活动内测规模按 `50-100` 人设计。
- [x] 2026-04-27 23:04:54 +0800 已确认：腾讯云 IM 部署地域为`上海`。
- [x] 2026-04-27 23:04:54 +0800 已确认：一期包含后台审核 / 举报 / 撤回处理能力。
- [x] 2026-04-27 23:04:54 +0800 已记录：一期高级能力范围进入细化确认阶段。
- [x] 2026-04-27 23:08:02 +0800 已确认：一期补充纳入语音、视频、引用回复、`@`、已读回执。
- [x] 2026-04-27 23:08:02 +0800 已确认：`Web / Android` 不在一期范围内。
- [x] 2026-04-27 23:08:02 +0800 已确认：腾讯云 IM 控制台账号与密钥由开发者本人负责。
- [x] 2026-04-27 23:08:02 +0800 已确认：视频消息属于一期必做能力。
- [x] 2026-04-27 23:13:54 +0800 已确认：撤回后的客户端默认显示“消息已撤回”占位样式。
- [x] 2026-04-27 23:13:54 +0800 已确认：语音 / 视频限制先按“腾讯云默认能力 + 仓库现有上传限制”执行。
- [x] 2026-04-27 23:13:54 +0800 已确认：`@` 一期只限群聊。
- [x] 2026-04-27 23:18:28 +0800 已完成：整理第一周执行清单。
- [x] 2026-04-27 23:26:29 +0800 已完成：将第一周执行清单并回总方案文档，不再单独维护 week1 文档。
- [x] 2026-04-27 23:34:45 +0800 已完成：落地服务端 `tencent-im` 模块骨架与路由挂载。
- [x] 2026-04-27 23:34:45 +0800 已完成：实现 `GET /v1/im/tencent/bootstrap` 最小可用接口。
- [x] 2026-04-27 23:34:45 +0800 已完成：实现腾讯云 IM `UserSig` 基础生成逻辑。
- [x] 2026-04-27 23:50:28 +0800 已完成：iOS 侧接入腾讯云 IM 官方 CocoaPods SDK（`TXIMSDK_Plus_iOS_XCFramework`）。
- [x] 2026-04-27 23:50:28 +0800 已完成：在 `AppState` 中新增 `TencentIMSession` 运行时实现与生命周期接线。
- [x] 2026-04-27 23:50:28 +0800 已完成：`SocialService` / `LiveSocialService` / `MockSocialService` 接入腾讯云 IM bootstrap 获取能力。
- [x] 2026-04-27 23:50:28 +0800 已完成：腾讯云 IM 连接状态、未读总数与 App badge 汇总逻辑接通。
- [x] 2026-04-27 23:50:28 +0800 已完成：本地 `xcodebuild` 编译通过，腾讯云 IM SDK 已成功进入 iOS 工程。
- [x] 2026-04-28 00:10:06 +0800 已完成：按“不要 OpenIM 兜底”的口径，把会话列表、会话打开、文本 / 图片 / 视频发送切到腾讯云 IM 单通道代码路径。
- [x] 2026-04-28 00:10:06 +0800 已完成：`RaverChatController` 新增最小兼容聊天控制路径，不再依赖 OpenIM 原始消息控制器才能进入会话。
- [x] 2026-04-28 00:10:06 +0800 已完成：`LiveSocialService` 改为优先且仅走腾讯云 IM 的会话、消息、已读、免打扰、清空历史接口。
- [x] 2026-04-28 00:10:06 +0800 已完成：再次执行本地 `xcodebuild`，腾讯云 IM 单通道改造后仍编译通过。
- [x] 2026-04-28 09:44:40 +0800 已完成：服务端改用腾讯云 IM 官方 REST API 同步用户账号与用户资料。
- [x] 2026-04-28 09:44:40 +0800 已完成：新增 `POST /v1/im/tencent/users/me/sync` 手动用户同步接口。
- [x] 2026-04-28 09:44:40 +0800 已完成：新增 `POST /v1/im/tencent/squads/:squadId/sync` 手动 Squad 群同步接口。
- [x] 2026-04-28 09:44:40 +0800 已完成：Squad 创建、接受邀请、主动离队已接入腾讯云 IM 群同步基础链路。
- [x] 2026-04-28 09:54:25 +0800 已完成：新增 `POST /v1/im/tencent/squads/:squadId/messages/test` 开发联调用测试群消息接口。
- [x] 2026-04-28 10:00:48 +0800 已确认：iOS 聊天相关界面操作逻辑向腾讯云 UIKit 对齐。
- [x] 2026-04-28 10:05:09 +0800 已确认：iOS 聊天相关视觉效果也可向腾讯云 UIKit 对齐（保留 Raver 品牌主题）。
- [x] 2026-04-28 10:05:09 +0800 已完成：第一批 UIKit 视觉对齐代码落地：输入区媒体入口改为“+ 菜单 + 快捷视频”，消息发送状态信息常驻展示。
- [x] 2026-04-28 10:13:28 +0800 已完成：`RaverChatController` 移除 OpenIM 兜底分支，聊天运行时不再回退到 OpenIM legacy 控制器。
- [x] 2026-04-28 10:13:28 +0800 已完成：`AppState` 移除 OpenIM 未读数实时合并路径，仅保留腾讯云 IM 未读聚合。
- [x] 2026-04-28 10:17:33 +0800 已完成：iOS `Podfile` 移除 `OpenIMSDK`，并执行 `pod install` 完成依赖清理。
- [x] 2026-04-28 10:17:33 +0800 已完成：服务端 `index.ts` 下线 `/v1/openim` 路由入口与 OpenIM worker 启动调用。
- [x] 2026-04-28 10:17:33 +0800 已完成：验证 `pnpm -C server exec tsc --noEmit` 与 iOS `xcodebuild` 均通过。
- [x] 2026-04-28 10:21:51 +0800 已完成：`AppState` 清理 OpenIM bootstrap 刷新与恢复逻辑，登录态生命周期只保留腾讯云 IM 刷新链路。
- [x] 2026-04-28 10:21:51 +0800 已完成：`SocialService` 移除 `fetchOpenIMBootstrap` 协议要求，并删除 `LiveSocialService` / `MockSocialService` 对应实现。
- [x] 2026-04-28 10:21:51 +0800 已完成：再次验证 `pnpm -C server exec tsc --noEmit` 与 iOS `xcodebuild`，结果通过。
- [x] 2026-04-28 10:31:05 +0800 已完成：修复 `bff.routes.ts` 腾讯群操作签名，覆盖入群、建群、转让群主等调用并与 `tencent-im-group.service.ts` 对齐。
- [x] 2026-04-28 10:31:05 +0800 已完成：`auth.controller.ts` 用户注册/登录/资料更新/头像更新后的 IM 同步切换为腾讯云 IM 用户同步，不再依赖 OpenIM 同步队列。
- [x] 2026-04-28 10:31:05 +0800 已完成：通知中心清理 `openim` 渠道类型与过滤逻辑，统一为 `in_app` + `apns` 双通道。
- [x] 2026-04-28 10:31:05 +0800 已完成：验证 `pnpm -C server exec tsc --noEmit` 通过。
- [x] 2026-04-28 10:31:05 +0800 已完成：验证 iOS `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build` 通过。
- [x] 2026-04-28 10:37:00 +0800 已完成：新增 `GET /v1/im/tencent/squads/mine` 联调接口，用于查询当前登录用户可同步的 Squad 列表。
- [x] 2026-04-28 10:37:00 +0800 已完成：新增 `POST /v1/im/tencent/squads/sync-all` 联调接口，用于批量同步当前用户全部 Squad 到腾讯云 IM。
- [x] 2026-04-28 10:37:00 +0800 已完成：验证 `pnpm -C server exec tsc --noEmit` 通过（新增接口后）。
- [x] 2026-04-28 12:49:07 +0800 已完成：删除服务端 OpenIM 路由文件 `server/src/routes/openim.routes.ts`（此前已下线挂载，现执行实体删除）。
- [x] 2026-04-28 12:49:07 +0800 已完成：清理 `notification-outbox-gray-verify.ts` 中 `openim` 渠道类型，仅保留 `in_app` / `apns`。
- [x] 2026-04-28 12:49:07 +0800 已完成：清理 `server/package.json` 中全部 `openim:*` 脚本入口，避免误触发旧链路。
- [x] 2026-04-28 12:49:07 +0800 已完成：验证 `pnpm -C server exec tsc --noEmit` 通过（本轮清理后）。
- [x] 2026-04-28 12:49:47 +0800 已完成：删除 `server/src/services/openim/*` 目录下全部 OpenIM 服务实现文件。
- [x] 2026-04-28 12:49:47 +0800 已完成：删除 `server/src/scripts/openim*` 全部 OpenIM 相关脚本文件。
- [x] 2026-04-28 12:49:47 +0800 已完成：验证服务端源码中不再存在 OpenIM 服务引用（`rg` 检查为空）。
- [x] 2026-04-28 12:49:47 +0800 已完成：再次验证 `pnpm -C server exec tsc --noEmit` 通过（物理删除后）。
- [x] 2026-04-28 18:28:12 +0800 已完成：回复协议改为仅接受腾讯 IM 新格式 `[reply:id|sender|preview]`，移除旧格式解析与 `inline-reply` 兜底 ID。
- [x] 2026-04-28 18:28:12 +0800 已完成：核心命名清理继续推进，`SocialService.swift` 中 `OpenIMRawChatService` / `OpenIMChatCompatibilityService` 别名已移除，主链路日志调用改为 `IMProbeLogger`。
- [x] 2026-04-28 18:33:38 +0800 已完成：`OpenIMProbeLogger` 调用点已在消息主链路与 UIKit Chat 辅助模块切换为 `IMProbeLogger`，并删除 `OpenIMProbeLogger` 别名定义。
- [x] 2026-04-28 18:33:38 +0800 已完成：执行 iOS `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [x] 2026-04-28 18:37:20 +0800 已完成：删除剩余 OpenIM 兼容别名定义（`OpenIMSession`、`OpenIMChatStore`、`OpenIMStorageGovernance`、`OpenIMBootstrap`、`OpenIMConnectionState`、`OpenIMInputStatusEvent`、`OpenIMMessageHistoryPage`、`OpenIMRawMessagePage`）。
- [x] 2026-04-28 18:37:20 +0800 已完成：再次执行 iOS `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [x] 2026-04-28 18:38:25 +0800 已完成：`IMStorageGovernance` 语义清理，快照字段与日志键从 `openim` 收口为 `im`（仅命名调整，不改行为）。
- [x] 2026-04-28 18:38:25 +0800 已完成：执行 iOS `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [x] 2026-04-28 18:40:29 +0800 已完成：文件名收口，`OpenIMChatStore.swift` / `OpenIMProbeLogger.swift` / `OpenIMSession.swift` / `OpenIMStorageGovernance.swift` 重命名为 `IM*.swift`，并同步 `RaverMVP.xcodeproj/project.pbxproj` 引用。
- [x] 2026-04-28 18:40:29 +0800 已完成：执行 iOS `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [x] 2026-04-28 18:42:23 +0800 已完成：`IMSession.swift` 内容语义收口，清理 OpenIM 文案与私有命名（错误提示、内部函数/变量名、缓存目录名）为中性 IM 术语。
- [x] 2026-04-28 18:42:23 +0800 已完成：执行 iOS `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [x] 2026-04-28 18:43:44 +0800 已完成：`IMSession.swift` 进一步清理条件编译块细节，统一 `imConversationID` 命名与 `IM SDK timestamp` 注释，移除残留 `openIMConversation*` 语义。
- [x] 2026-04-28 18:43:44 +0800 已完成：执行 iOS `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [x] 2026-04-28 18:56:19 +0800 已完成：修复真机聊天页实时刷新问题：`RaverChatController.matchesCurrentConversation` 优先按 SDK `message.conversationID` 与当前会话 `openIMConversationID` 匹配，再回退业务会话ID匹配，避免实时消息被误过滤。
- [x] 2026-04-28 18:56:19 +0800 已完成：执行 iOS `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [x] 2026-04-28 22:17:58 +0800 已完成：聊天页继续向腾讯 IM Demo 视觉规格收口，完成消息气泡宽度、头像尺寸、气泡圆角、消息内边距等参数调整。
- [x] 2026-04-28 22:17:58 +0800 已完成：输入区（Composer）继续向腾讯 IM Demo 规格收口，完成媒体入口按钮尺寸、输入框高度/留白、发送按钮尺寸与内边距调整。
- [x] 2026-04-28 22:17:58 +0800 已完成：执行 iOS `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [x] 2026-04-28 22:24:03 +0800 已完成：输入区进一步对齐（语音键按下态缩放/高亮、按下反馈、键盘联动节奏微调、安全区下输入区布局保持稳定）。
- [x] 2026-04-28 22:24:03 +0800 已完成：会话列表视觉规格收口（头像尺寸、标题/副标题/时间字号、未读角标间距）。
- [x] 2026-04-28 22:24:03 +0800 已完成：多媒体消息细节收口（视频 16:9、图片比例区间、语音条宽度按时长映射）。
- [x] 2026-04-28 22:24:03 +0800 已完成：长按菜单第一版对齐（复制/引用回复/@/重发/删除 顺序与层级，失败消息支持重发与本地删除）。
- [x] 2026-04-28 22:24:03 +0800 已完成：已读回执文案收口（单聊已读/未读，群聊已读人数与未读人数展示）。
- [x] 2026-04-28 22:24:03 +0800 已完成：发送出现过渡动画与滚动策略小幅收口（新消息轻量渐显、近底部自动滚动逻辑保持）。
- [x] 2026-04-28 22:24:03 +0800 已完成：执行 iOS `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`，结果 `BUILD SUCCEEDED`。
- [ ] 待完成：使用真实腾讯云 `SDKAppID` / `UserSig` 做真机或模拟器联调。记录时间：待完成

## 3. 已识别的仓库现状

- [x] 2026-04-27 22:59:06 +0800 已识别：iOS 有较深的 OpenIM 依赖，包括 `OpenIMSession.swift`、`OpenIMChatStore.swift`、`LiveSocialService.swift`。
- [x] 2026-04-27 22:59:06 +0800 已识别：服务端已有 `server/src/routes/openim.routes.ts` 和 `server/src/services/openim/*`。
- [x] 2026-04-27 22:59:06 +0800 已识别：Prisma 中同时存在旧自建消息模型和 OpenIM 相关运维表。
- [x] 2026-04-27 22:59:06 +0800 已识别：`thirdparty/openimApp/` 为 OpenIM 实验资产，后续应进入删除清单。

## 4. 重要决策记录

- [x] 2026-04-27 22:59:06 +0800 决策：正式产线优先接腾讯云 IM SDK 能力层，不优先整套 TUIKit UI 重做。
- [x] 2026-04-27 22:59:06 +0800 决策：Raver Server 继续作为用户、小队、权限、事件、审核的权威源。
- [x] 2026-04-27 22:59:06 +0800 决策：腾讯云 IM 负责单聊、群聊、会话、消息同步、离线消息、回调。
- [x] 2026-04-27 22:59:06 +0800 决策：默认不迁移旧聊天历史，先做归档快照。
- [x] 2026-04-27 23:26:29 +0800 决策修正：Squad 群优先改用 `Public`，活动群优先用 `Meeting`，不再推荐 `Work` 作为 Squad 主群型。
- [x] 2026-04-27 23:26:29 +0800 决策修正：`UserID` / `groupID` 不能直接用完整 UUID 前缀拼接，需改为短 ID 映射。
- [x] 2026-04-27 23:26:29 +0800 决策修正：媒体大小上限按腾讯云 IM 官方限制与现有上传限制中的更严格者执行。
- [x] 2026-04-28 00:10:06 +0800 决策确认：IM 运行链路不再保留 OpenIM 兜底，先以腾讯云 IM 单通道跑通并测试，再逐步清理旧链路。

## 5. 当前待确认问题

- [ ] 待确认：语音消息是否需要最长时长上限提示。记录时间：待完成
- [ ] 待确认：视频消息是否需要客户端压缩策略和清晰度档位。记录时间：待完成
- [ ] 待确认：群聊里 `@所有人` 是否要纳入一期。记录时间：待完成

## 6. 下一步执行队列

- [ ] 待执行：补齐剩余未决项，尤其是媒体压缩策略、语音时长提示与 `@所有人` 规则。计划时间：待定
- [x] 2026-04-27 23:18:28 +0800 已完成：输出“第一周迁移任务清单”。
- [x] 2026-04-27 23:26:29 +0800 已完成：将“第一周迁移任务清单”并回总方案主文档。
- [x] 2026-04-27 23:34:45 +0800 已完成：设计并落地服务端 `tencent-im` 模块骨架。
- [x] 2026-04-28 00:10:06 +0800 已完成：开始 Day 4，会话列表与会话打开改造。
- [x] 2026-04-28 00:10:06 +0800 已完成：落地 iOS 最小兼容 IM 抽象层，用于承接腾讯云 IM 单通道切换。
- [ ] 待执行：拿真实腾讯云测试账号验证会话列表、1v1 文本、群文本。计划时间：待定
- [ ] 待执行：选一个真实 Squad 执行 `/v1/im/tencent/squads/:squadId/sync`，确认腾讯云 IM 会话列表出现群会话。计划时间：待定
- [ ] 待执行：补齐语音发送、消息实时接收、滚动刷新与未读联动。计划时间：待定
- [ ] 待执行：收口私聊入口全链路（用户主页发起私聊 -> C2C 会话创建/拉起 -> 会话列表可见 -> 聊天页首屏可发）。计划时间：待定
- [ ] 待执行：收口会话列表排序与未读同步细节，对齐腾讯 IM Demo 行为。计划时间：待定
- [ ] 待执行：按腾讯云 UIKit 口径补齐会话页与聊天页操作逻辑对齐清单（回复、@、已读、长按菜单）。计划时间：待定
- [ ] 待执行：继续做第二批视觉对齐（会话列表 cell 信息层级、长按菜单样式与动作排序）。计划时间：待定
- [ ] 待执行：列出 OpenIM 删除清单。计划时间：待定
- [x] 2026-04-28 12:51:20 +0800 已完成：iOS 探针日志能力中立化，新增 `IMProbeLogger` 并保留 `OpenIMProbeLogger` 类型别名兼容现有调用。
- [x] 2026-04-28 12:51:20 +0800 已完成：存储巡检日志前缀由 `OpenIMStorageGovernance` 调整为 `IMStorageGovernance`，探针文件名改为 `im-probe.log`。
- [x] 2026-04-28 12:51:20 +0800 已完成：`OpenIMSession` 运行日志前缀由 `[OpenIMSession]` 调整为 `[IMSession]`。
- [x] 2026-04-28 12:51:20 +0800 已完成：iOS `xcodebuild`（iPhone 17 Simulator）编译通过（本轮日志与命名收口后）。
- [x] 2026-04-28 13:01:17 +0800 已完成：`OpenIMSession` / `OpenIMChatStore` / `OpenIMConnectionState` / `OpenIMInputStatusEvent` 定义本体切换为 `IM*`，并保留反向 `typealias` 兼容旧引用。
- [x] 2026-04-28 13:01:17 +0800 已完成：聊天控制器命名收口：`RaverOpenIMChatController` 重命名为 `RaverIMChatController`，`OpenIMChatItem` / `OpenIMMessageRenderMapper` 收口为 `IM*`。
- [x] 2026-04-28 13:01:17 +0800 已完成：核心调用点改用中性命名入口（`IMSession.shared`、`IMChatStore.shared`）。
- [x] 2026-04-28 13:01:17 +0800 已完成：iOS `xcodebuild`（iPhone 17 Simulator）再次编译通过（本轮本体命名迁移后）。
- [x] 2026-04-28 17:49:22 +0800 已完成：`IMBootstrap` 成为主定义，`OpenIMBootstrap` 降级为兼容别名；`IMStorageGovernance` 成为主定义并保留兼容别名。
- [x] 2026-04-28 17:49:22 +0800 已完成：发送/登录错误文案与本地快照 key 从 `OpenIM` 前缀切换为中性 `IM` 前缀。
- [x] 2026-04-28 17:49:22 +0800 已完成：iOS `xcodebuild`（iPhone 17 Simulator）编译通过（本轮命名收口后）。

## 7. 风险与阻塞

- [ ] 待跟踪：如果需求边界不先确定，后续会在“是否迁移旧消息”和“是否重写 UI”上来回返工。记录时间：待完成
- [ ] 待跟踪：如果活动群实际规模很大，群类型和套餐可能需要重新评估。记录时间：待完成
- [ ] 待跟踪：如果继续让团队同时维护 OpenIM 和腾讯云 IM，后续会形成双栈混乱。记录时间：待完成
- [ ] 待跟踪：腾讯云 IM 官方 iOS Pod 当前会带入较多第三方头文件 warning，后续若影响 CI 需单独处理。记录时间：待完成
- [ ] 待跟踪：当前“文本 / 图片 / 视频可用”仍停留在编译级与代码路径级验证，尚未完成真实腾讯云账号运行态验证。记录时间：待完成

## 8. 交接说明

接手人打开本日志后，应该先做以下事情：

1. 阅读 `docs/TENCENT_IM_MIGRATION_MASTER_PLAN.md` 第 5 节需求确认清单。
2. 先补齐未决需求，不要直接开始删代码。
3. 先做腾讯云 IM 基础环境和服务端鉴权，再做 iOS 页面替换。
4. OpenIM 相关代码暂时不要盲删，待腾讯云链路跑通后再集中清理。

## 9. 备注

本日志用于持续记录：

- 已完成事项
- 决策时间点
- 当前阻塞
- 下一步负责人动作

后续每完成一项，都应补一条带时间戳的 checkbox，而不是只改状态不记时间。
