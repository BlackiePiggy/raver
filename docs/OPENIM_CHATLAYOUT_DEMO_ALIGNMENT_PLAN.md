# Raver iOS 聊天重构（UIKit + ChatLayout，对齐 openim-ios-demo）

> 目标：将 Raver 聊天模块从当前 SwiftUI 聊天页，重构为与 `openim-ios-demo` 同构的 UIKit + ChatLayout 架构，优先对齐核心机制（滚动稳定性、分页、会话恢复、发送状态、多媒体与设置页链路）。

---

## 1) 重构原则（冻结）

- 结构同构：按 demo 的 `ViewController + Controller + DataProvider + DataSource` 分层推进。
- 机制同构：优先保证
  - 初次进入默认落底
  - 上滑分页不跳底
  - 新消息仅在“用户接近底部”时自动滚底
  - 前后台恢复后会话可继续实时同步
- 渐进替换：采用开关式切换，旧 `ChatView` 保留直到新链路达成验收。
- 文档即事实：所有阶段勾选、日志、风险在本文持续更新。

---

## 2) demo 对标映射（目标态）

- demo `ChatViewController`
  -> Raver `DemoAlignedChatViewController`（UIKit 主聊天容器）
- demo `DefaultChatController`
  -> Raver `RaverChatController`（消息处理、发送动作、会话状态编排）
- demo `DefaultDataProvider`
  -> Raver `RaverChatDataProvider`（OpenIM 历史分页、缓存窗口、监听桥接）
- demo `ChatCollectionDataSource`
  -> Raver `RaverChatCollectionDataSource`（Cell 注册与渲染）
- demo `IMController`
  -> Raver 继续复用 `OpenIMSession`（后续分层收口为 ChatDomain Facade）

---

## 3) 分阶段计划（执行版）

### Phase A0：基线与开关（1 天）
- [x] 新建重构主文档（本文件）
- [x] 增加路由开关：`RAVER_CHAT_USE_DEMO_ALIGNED_UIKIT`
- [x] 会话路由支持新聊天页入口（开关式）

验收：
- 不开开关时，旧聊天页行为不变。
- 开开关后可进入新 UIKit 聊天容器。

---

### Phase A1：UIKit 主容器 + ChatLayout 骨架（1-2 天）
- [x] 引入 ChatLayout 源码到本工程（Vendor）
- [x] 新增 `DemoAlignedChatView`（SwiftUI -> UIKit 容器）
- [x] 新增 `DemoAlignedChatViewController`：
  - [x] CollectionView + CollectionViewChatLayout
  - [x] 文本发送入口
  - [x] 首屏加载/已读同步
  - [x] 上滑分页触发 + 顶部加载指示
  - [x] “初始强制落底 + 分页不跳底”首版机制

验收：
- 新容器可稳定收发文本。
- 上滑至顶部会继续拉历史。
- 分页加载后当前位置保持稳定，不自动跳底。

---

### Phase A2：同构分层（2-4 天）
- [x] 拆分 `RaverChatController`（替代 VC 内业务逻辑）- 首版
- [x] 拆分 `RaverChatDataProvider`（分页游标、消息窗口、回放策略）- 首版
- [x] 拆分 `RaverChatCollectionDataSource`（渲染解耦）- 首版
- [x] 文本发送与 `sendButton` 交互下沉（`DemoAlignedTextSendCoordinator` 首版）
- [x] 会话分页触发与顶部 loading 下沉（`DemoAlignedPaginationCoordinator` 首版）
- [x] 键盘联动 + 回到底部浮层状态下沉（`DemoAlignedViewportCoordinator` 首版）
- [x] 设置页路由与会话退出回调下沉（`DemoAlignedChatRouteCoordinator` 首版）
- [x] 会话消息应用流程下沉（`DemoAlignedMessageApplyCoordinator` 首版）
- [x] 会话滚动能力下沉（`DemoAlignedMessageViewportScrollCoordinator` 首版）
- [x] 将 `DemoAlignedChatViewController` 收敛为纯 UI 容器（继续瘦身）

验收：
- VC 文件规模显著下降；
- 发送/分页/状态更新流程可单测；
- 与 demo 分层结构一致。

---

### Phase A3：消息渲染对齐（3-5 天）
- [x] 文本/图片/视频/语音/文件/系统消息 Cell 同构
  - [x] UIKit `CellFactory` 首版（文本 vs 媒体分流）
  - [x] 媒体消息基础 Cell（image/video/voice/file）首版
  - [x] image/video 缩略图与视频播放标识（UIKit）
  - [x] image/video 点击全屏预览（UIKit）
- [x] 发送中/失败/重发状态 UI 同构
  - [x] 失败态文案提示“点按重发”（UIKit）
  - [x] 点击失败消息触发重发（UIKit）
  - [x] UIKit 气泡内发送状态胶囊（发送中/失败）首版
- [x] 分组（按时间）与时间分隔样式同构
  - [x] UIKit 时间分隔行首版（首条/跨天/间隔 >= 5 分钟插入）
  - [x] 时间分隔文案本地化首版（Today/Yesterday/同年/跨年）
  - [x] cluster 首尾判定模型（同发送者+时间窗）与连续气泡分组
- [x] 头像、昵称、群聊显示规则同构
  - [x] 群聊他人消息头像昵称与连续折叠规则首版
  - [x] 群聊 sender meta 跟随 cluster 首条显示

验收：
- 现有消息类型在新页全部可用；
- UI 状态切换无闪烁、无重复插入。

---

### Phase A4：输入区与交互对齐（2-4 天）
- [x] 输入组件迁移到 UIKit（含媒体按钮）
  - [x] 媒体发送进度可视化（UIKit）
  - [x] 弱网失败非阻断提示条（点按气泡重试）
- [x] 键盘动画与底部偏移对齐 demo（不抖动）
- [x] 用户上滑阅读时新消息提示（不强拉到底）
- [x] “回到底部”显式按钮机制

验收：
- 键盘弹收 + 发送动作连续操作无跳动；
- 历史阅读不被新消息打断。

---

### Phase A5：设置页与群管理对齐（2-4 天）
- [x] ChatSetting 单聊/群聊入口迁移对齐
  - [x] UIKit 聊天页右上角 `...` 设置入口
  - [x] 接入 `ChatSettingsSheet`（免打扰/清空历史/退群）
  - [x] 群聊设置内“查看小队主页”路由打通
  - [x] 群聊设置内“管理小队”一跳路由打通
- [x] 免打扰、清空历史、退群、群管理动作连通
  - [x] 免打扰、清空历史、退群动作可在 UIKit 聊天设置页直达
  - [x] 群管理入口（小队管理页）可在 UIKit 聊天设置页直达
  - [x] 解散群等高权限动作从聊天路径验收收口
    - 已补齐：`POST /v1/squads/:id/disband` + iOS 聊天设置页“解散小队（仅队长）”。
- [x] 审核/管理员动作提示链路对齐
  - [x] 群聊设置页展示“我的身份（队长/管理员/成员）”
  - [x] 无权限状态下展示管理员动作提示文案
  - [x] 队长退群拦截时给出“去管理小队”快捷引导
  - [x] 审核流入口（邀请审核/入群审核）从聊天设置页可达

验收：
- 设置页全链路与当前服务端能力一致；
- 权限动作反馈可见且可追踪。

---

### Phase A6：灰度切换与收口（1-2 天）
- [x] 默认开启新聊天页（旧页仅回滚保留）
- [x] 回滚开关与 runbook 完整化
- [x] 清理旧聊天页重复逻辑

验收：
- 双机稳定通过主路径 smoke；
- 出现异常可一键回滚旧页。

---

### Phase A7：单实现收口（1-2 天）
- [x] 路由策略收敛为“默认新页”
- [x] 旧页入口彻底下线（移除 `ChatView` 路由分支）
- [x] 旧页代码退役（按模块分批删除）
  - [x] 第一批：删除 `ChatView.swift`
  - [x] 第二批：清理旧页遗留辅助模块（actions/rendering 等仅旧页使用的能力）

验收：
- 默认路径不再受灰度比例/白名单影响；
- 会话入口仅保留新 UIKit 页；
- 双机主链路 smoke 通过。

---

## 4) 关键风险与策略

- 风险 R1：SwiftUI / UIKit 混用导致导航和状态竞态
  - 策略：开关灰度 + ConversationLoader 单一入口。
- 风险 R2：分页与实时消息并发导致滚动抖动
  - 策略：分页时位置锚点恢复；自动滚底仅在“接近底部”触发。
- 风险 R3：新页初期功能缺失
  - 策略：旧页保留回退，按 Phase A3/A4 分批补齐。

---

## 5) 进度看板

- [x] A0 完成
- [x] A1 完成（骨架版）
- [x] A2 开始并完成第一轮落地
- [x] A3 完成（渲染对齐项收口）
- [x] A4 完成（输入与交互对齐收口）
- [x] A5 完成
- [x] A6 完成（灰度开关 + runbook + 旧页去冗余）
- [x] A7 完成（会话入口单实现 + 旧页代码退役）

---

## 6) 执行日志

### 2026-04-23

- 新建重构主文档：`docs/OPENIM_CHATLAYOUT_DEMO_ALIGNMENT_PLAN.md`。
- 新增运行时开关：
  - `RAVER_CHAT_USE_DEMO_ALIGNED_UIKIT`（默认关闭）。
  - 代码位置：`Core/AppConfig.swift`。
- 会话路由支持新容器：
  - `MainTabCoordinator.ConversationLoaderView` 按开关在 `ChatView` 与 `DemoAlignedChatView` 间切换。
- 引入 ChatLayout 源码（Vendor）并新增 UIKit 聊天骨架：
  - `Features/Messages/UIKitChat/DemoAlignedChatView.swift`
  - `Features/Messages/UIKitChat/DemoAlignedChatViewController.swift`
- 骨架能力：
  - OpenIM 消息加载/展示/文本发送
  - 顶部触发历史分页
  - 初次进入落底，分页后保持阅读位置

### 2026-04-23（A2 第一轮）

- 新增同构分层首版：
  - `Features/Messages/UIKitChat/RaverChatDataProvider.swift`
  - `Features/Messages/UIKitChat/RaverChatController.swift`
  - `Features/Messages/UIKitChat/RaverChatCollectionDataSource.swift`
  - `Features/Messages/UIKitChat/DemoAlignedMessageCell.swift`
- `DemoAlignedChatViewController` 已改为通过 `RaverChatController` 驱动：
  - VC 负责 UI 与滚动策略
  - Controller 负责加载/发送/状态编排
  - DataProvider 负责与 `OpenIMChatStore` 交互
  - DataSource 负责消息 Cell 绑定与渲染分发
- 工程同步：
  - 已执行 `xcodegen generate`，确保新增文件入 target。
- 验证日志：
  - `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`

### 2026-04-23（A2/A3 继续推进）

- `DemoAlignedChatViewController` 进一步瘦身：
  - 新增 `RaverChatScrollCoordinator`，收敛“自动滚底 + 分页位置保持”规则；
  - VC 仅保留 UI 装配与事件路由。
- A3 首轮落地：
  - 新增 `RaverChatMessageCellFactory`（按 `ChatMessageKind` 分流）；
  - 新增 `DemoAlignedMediaMessageCell`（image/video/voice/file 基础样式）。
  - `RaverChatCollectionDataSource` 改为通过 factory 出 cell，VC 不再关心具体 cell 类型。
- 验证日志：
  - 已执行 `xcodegen generate`；
  - 已执行 `xcodebuild ...`（同上命令）；
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-23（A4 首轮落地：新消息提示与回到底部）

- `DemoAlignedChatViewController` 新增会话内浮层交互：
  - 用户离开底部时显示“回到底部”按钮；
  - 阅读历史期间有新消息到达时，按钮文案切换为“`N` 条新消息”（超过 99 显示 `99+`）；
  - 点击后滚动到底部并清空提示计数。
- 滚动策略加固：
  - 首次进入会话补一层稳态落底（防止极端时序下首次未落底）；
  - 仅在“非分页且尾消息变化”时累计新消息提示，不打断用户历史阅读。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-23（A4/A3 继续：媒体发送入口 + 失败重发）

- UIKit 输入区新增媒体入口（与旧 SwiftUI 聊天能力对齐）：
  - 新增图片/视频按钮（`PHPickerViewController`）；
  - 图片/视频选取后拷贝到本地临时目录，再走 `OpenIMChatStore` 发送链路；
  - 媒体发送中禁用媒体按钮与发送按钮，避免重复触发。
- UIKit 会话内失败重发交互补齐：
  - 点击失败消息直接触发 `resendFailedMessage`；
  - 文案改为“发送失败·点按重发”，增强可发现性（文本/媒体 cell 都已覆盖）。
- 控制层补齐：
  - `RaverChatController` / `RaverChatDataProvider` 新增 `sendImageMessage`、`sendVideoMessage`、`resendFailedMessage` 封装方法。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 OpenIM Pods 的 iOS deployment target 警告）。

### 2026-04-23（A3 继续：媒体缩略图与点击预览）

- UIKit 媒体消息渲染增强：
  - `DemoAlignedMediaMessageCell` 支持 image/video 缩略图展示；
  - video 增加播放图标与时长 badge；
  - 媒体 cell 复用时增加异步加载防错图处理（token + cancel load）。
- 点击行为对齐：
  - 失败消息点击优先走重发；
  - 正常 image/video 点击进入 `FullscreenMediaViewer` 全屏预览（与现有 SwiftUI 预览组件复用）。
- 代码补充：
  - 新增 `RaverChatMediaResolver` 统一解析媒体 URL（与 SwiftUI 渲染规则一致）。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅 Pods deployment target 警告）。

### 2026-04-23（A4 继续：媒体发送进度可视化）

- `DemoAlignedChatViewController` 输入区新增媒体发送进度显示：
  - 新增 `UIProgressView + 百分比文本`；
  - 媒体发送中实时更新进度，发送完成后自动收起；
  - 发送期间继续禁用媒体按钮与发送按钮，避免重复触发。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：`BUILD SUCCEEDED`（仅 Pods deployment target 警告）。

### 2026-04-23（双机探针可观测性加固）

- 新增 iOS 端文件日志通道（Debug）：
  - 新文件：`Core/OpenIMProbeLogger.swift`
  - `OpenIMSession` / `OpenIMChatStore` / `AppState` / `ConversationLoader` 的 debug 日志除 `print/os_log` 外，额外写入 App 沙盒 `Library/Caches/openim-probe.log`。
- 双机探针脚本增强：
  - `openim_dual_sim_probe.sh` 新增 `OPENIM_PROBE_USE_APP_LOG=1`（默认开启）。
  - 探针启动时会清空两台模拟器的 `openim-probe.log`，结束时自动合并到 `sim1.log/sim2.log`，再跑 digest。
  - 即便 `simctl log stream` 出现空采集，也可用 app-probe 文件日志完成链路判定。
- digest 增强：
  - `openim_probe_digest.sh` 新增 `ConversationLoader` 事件计数，减少“无有效事件”误判。

### 2026-04-23（双机实时链路手测通过）

- 手测结论：
  - 聊天消息稳定走 `realtime message received`
  - 未触发 `catchup messages changed / catchup conversations changed`
  - 未触发 `10102 / OpenIM ... unavailable`
- 判定：
  - A3/A4 这一轮主链路回归通过，可继续推进下一步（键盘与输入区动画收口）。

### 2026-04-23（A4 收口：键盘弹收与输入区动画）

- `DemoAlignedChatViewController` 新增键盘帧监听：
  - 监听 `keyboardWillChangeFrame / keyboardWillHide`；
  - 动画参数按键盘系统时序同步（duration + curve）。
- 滚动策略对齐 demo 体验：
  - 仅当“用户接近底部”或“正在输入”时，键盘动画过程中自动贴底；
  - 键盘收起后做一次短延迟稳态贴底，避免偶发半屏抖动；
  - 输入框开始编辑时主动滚到底部，减少首击输入时的视觉跳动。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A5 第一轮：设置入口与群管理路由）

- `DemoAlignedChatViewController` 新增右上角设置按钮（`ellipsis.circle`）。
- UIKit 聊天页已接入 `ChatSettingsSheet`：
  - 单聊：查看用户主页入口可用；
  - 群聊：查看小队主页、管理小队、退群、免打扰、清空历史可用。
- 路由打通方式：
  - `DemoAlignedChatView` 注入 `appPush/dismiss` 环境能力；
  - 设置页内跳转统一回调到 `MainTabCoordinator` 路由。
- 退群行为：
  - 在设置页触发退群后，UIKit 会话页自动退出当前会话（回到上一层）。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A5 第二轮：管理员提示与高权限引导）

- `ChatSettingsSheet` 群聊态增强：
  - 加入小队权限信息加载（`fetchSquadProfile`），显示“我的身份：队长/管理员/成员”；
  - 管理按钮改为权限感知：无权限时禁用并展示提示文案；
  - 退群加入二次确认（`confirmationDialog`）。
- 队长退群拦截链路：
  - 若服务端返回“队长需先转让”类错误，弹出引导弹窗并一键跳转“管理小队”。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A5 第三轮：邀请审核入口可达）

- 聊天设置页补齐“邀请审核”路径：
  - 群聊 `ChatSettingsSheet` 新增“邀请审核”按钮；
  - 点击后从当前会话页跳转到消息分类 `小队邀请（squadInvite）`。
- 消息分类对齐：
  - `MessageAlertCategory` 增加 `squadInvite`，入口在消息页可见并显示未读角标；
  - 聊天路径与消息路径共享同一审核入口，便于回归验证。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅 Pods deployment target + 现存 iOS17 deprecate 警告）。

### 2026-04-23（A5 第四轮：解散小队能力收口）

- 服务端新增解散接口：
  - `POST /v1/squads/:id/disband`（仅队长可执行）；
  - OpenIM 侧增加 `dismiss_group` 调用，解散 OpenIM 群后删除本地 squad 数据。
  - 注意：当前 Prisma 关系为级联删除，解散会一并删除该 squad 关联数据（含 squad 下 posts/messages 等）。
- iOS 聊天设置页新增“解散小队（仅队长）”：
  - 队长可见可点，非队长置灰；
  - 二次确认后执行，成功则退出当前会话并移除会话项。
- 验证日志：
  - `pnpm -C server build`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：Server 编译通过；iOS 构建通过（仅既有 warning）。

### 2026-04-23（A6 第一轮：灰度开关与回滚 runbook）

- 客户端开关升级为“可灰度 + 可强制回滚”：
  - 新增 `RAVER_CHAT_FORCE_LEGACY_CHAT_VIEW`（最高优先级回滚）；
  - 新增 `RAVER_CHAT_FORCE_UIKIT_CHAT_VIEW`（强制新页）；
  - 新增 `RAVER_CHAT_UIKIT_ROLLOUT_PERCENT`（按用户稳定分桶灰度）；
  - 新增 `RAVER_CHAT_UIKIT_ALLOWLIST_USER_IDS`（白名单放量）。
- 会话入口已按用户命中灰度规则：
  - `ConversationLoaderView` 使用 `AppConfig.shouldUseDemoAlignedChatUIKit(userID:)` 决定新旧页。
- 新增 runbook：
  - [`docs/OPENIM_CHAT_UIKIT_ROLLOUT_RUNBOOK.md`](/Users/blackie/Projects/raver/docs/OPENIM_CHAT_UIKIT_ROLLOUT_RUNBOOK.md)
  - 并在双机验收文档补充“新旧页对照验收”章节。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

### 2026-04-23（A6 第二轮：旧页去冗余收口）

- 旧页与新页的媒体临时文件逻辑已收敛为单实现：
  - 新增 `ChatMediaTempFileStore` 作为统一媒体临时目录管理；
  - 旧 `ChatView` 与新 `DemoAlignedChatViewController` 共用该模块，移除重复实现。
- 工程收口：
  - 已重新执行 `xcodegen generate`，确保新增共享文件被 target 正确收录；
  - 规避了新增文件后 `cannot find ... in scope` 的工程同步类问题。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

### 2026-04-23（A6 第三轮：双机探针稳定性加固）

- `openim_dual_sim_probe.sh` 增强：
  - 采集前/采集中增加模拟器 boot 状态校验与自动恢复；
  - 增加 `OPENIM_PROBE_OPEN_SIM_WINDOWS=1` 可选 UI 开窗（默认关闭，优先稳定采集）。
- 验证日志：
  - `OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=20 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
  - 结果：采集流程可完整结束，无“device is not booted”中断。

### 2026-04-23（A7 第一轮：路由策略收敛）

- iOS 会话入口路由改为“默认新页”：
  - `AppConfig.shouldUseDemoAlignedChatUIKit` 仅保留 `RAVER_CHAT_FORCE_LEGACY_CHAT_VIEW=1` 回滚语义；
  - 移除百分比灰度、白名单与多开关分流对默认路径的影响。
- 收口目标：
  - 新页成为唯一默认实现；
  - 旧页仅作紧急回滚保留。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

### 2026-04-23（A7 第二轮：旧页入口下线）

- `ConversationLoaderView` 已移除旧 `ChatView` 分支：
  - 会话入口统一走 `DemoAlignedChatView`；
  - 不再保留运行时路由回滚开关。
- `AppConfig` 收口：
  - 删除 `shouldUseDemoAlignedChatUIKit` 及相关开关解析逻辑，避免“假开关”误导。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

### 2026-04-23（A7 第三轮：旧页主文件退役）

- 已删除旧页主文件：
  - `Features/Messages/ChatView.swift`。
- 工程同步：
  - 执行 `xcodegen generate` 清理旧文件的 build input 残留引用。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

### 2026-04-23（A7 第三轮第二批：旧页遗留模块退役）

- 已清理仅旧页使用的遗留模块：
  - 删除 `Features/Messages/Chat/Rendering/ChatMessageRenderRegistry.swift`；
  - `ChatMediaTempFileStore.swift` 迁移至 `Features/Messages/UIKitChat/Support/`，旧 `Features/Messages/Chat` 目录完成退役。
- 工程同步：
  - 执行 `xcodegen generate` 刷新项目文件，移除旧文件引用并纳入迁移后的路径。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅既有 warning）。

### 2026-04-23（A3 补齐：时间分隔 + 群聊头像昵称规则）

- 新增消息列表分层渲染项：
  - `RaverChatCollectionDataSource` 引入 `RaverChatListItem`（`timeSeparator` / `message`）；
  - 时间分隔插入策略：首条消息、跨天、或消息间隔 >= 5 分钟。
- 新增时间分隔 Cell：
  - `Features/Messages/UIKitChat/DemoAlignedTimeSeparatorCell.swift`。
- 群聊显示规则首版：
  - `DemoAlignedMessageCell` / `DemoAlignedMediaMessageCell` 支持“他人消息头像 + 昵称”；
  - 连续消息折叠：同一发送者且间隔 < 3 分钟时不重复展示 sender meta。
- 代码收口：
  - `RaverChatMessageCellFactory` 改为按 `RaverChatListItem` 出 cell；
  - `DemoAlignedChatViewController` 会话切换时同步 `conversationType` 给 data source。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A3/A4 继续：时间分隔文案 + 发送状态视觉）

- 时间分隔文案升级（更接近 demo 的阅读语义）：
  - `RaverChatCollectionDataSource` 的分隔文案支持 `Today/Yesterday`；
  - 同年与跨年分别走不同本地化日期模板（`MMMdHHmm` / `yMMMdHHmm`）。
- 发送状态视觉升级（文本/媒体统一）：
  - `DemoAlignedMessageCell` / `DemoAlignedMediaMessageCell` 将状态从时间后缀改为独立“状态胶囊”；
  - `sending` 显示中性胶囊，`failed` 显示红色失败胶囊，`sent` 隐藏胶囊。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A3/A4 继续：样式微调 + 弱网失败提示）

- 时间分隔样式微调：
  - `DemoAlignedTimeSeparatorCell` 调整为更轻视觉（更淡背景、10pt 字号、最小高度约束），减少阅读干扰。
- 发送状态可见性增强：
  - 文本/媒体消息的失败胶囊文案升级为“失败·点重试”；
  - 发送状态胶囊仅对“我发出的消息”展示，避免对端状态噪音。
- 弱网失败提示（非阻断）：
  - `DemoAlignedChatViewController` 在检测到消息由非失败变为失败时，输入区上方显示 2s 提示条：
    - “消息发送失败，点按气泡重试”；
  - 不弹系统 alert，不打断当前阅读/输入。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A4 继续：失败反馈去打断化 + 观测日志增强）

- 失败反馈策略收口（更贴近成熟 IM 体验）：
  - 文本发送失败、图片发送失败、视频发送失败、失败重发再次失败，统一改为“非阻断提示条”；
  - 取消这几条路径的 alert 弹窗，避免弱网时频繁打断输入和阅读。
- 观测增强：
  - `DemoAlignedChatViewController` 在失败路径新增 probe 日志：
    - `send text failed`
    - `send image failed`
    - `send video failed`
    - `resend failed`
    - `send failure hint shown`
  - 日志写入 `openim-probe.log`，便于双机 probe 后快速判定“失败提示链路”是否触发。
  - `openim_probe_digest.sh` 已扩展失败相关计数：
    - `sendFailed`
    - `resendFailed`
    - `failureHint`
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A3 收口：消息 cluster 分组模型首版）

- 分组模型下沉到 DataSource：
  - `RaverChatCollectionDataSource` 新增 cluster 计算：
    - `isClusterStart / isClusterEnd`
    - 判定条件：同发送者、同方向（mine/other）、同日、间隔 < 3 分钟；
  - presentation 结构扩展并贯通至 cell factory 与 cell。
- 渲染行为升级：
  - 文本/媒体消息气泡按 cluster 首尾设置圆角（连续气泡视觉）；
  - 行间距按 cluster 首尾收敛（首尾更疏、中间更紧）；
  - 群聊昵称与头像仅在 cluster 首条显示，减少重复信息。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A2 收口：失败提示条从 VC 下沉）

- VC 瘦身改造：
  - 新增 `Features/Messages/UIKitChat/Support/DemoAlignedSendFailureHintPresenter.swift`；
  - `DemoAlignedChatViewController` 不再直接维护失败提示条 view/timer，改为调用 presenter。
- 收益：
  - 会话页职责更聚焦于路由与状态编排；
  - 失败提示逻辑可复用，可单独继续扩展（样式/时长/触发策略）。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A2 收口：媒体选择与发送流程下沉）

- 新增独立协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMediaSendCoordinator.swift`；
  - 职责：`PHPicker` 展示、文件读取、临时文件落地、错误回调。
- `DemoAlignedChatViewController` 收口：
  - 移除 `PHPickerViewControllerDelegate` 扩展与 picker 细节方法；
  - 改为通过 `mediaSendCoordinator` 接收 `image/video` 结果并调用发送方法；
  - picker 侧错误统一通过失败提示 presenter 展示，并写入 probe 日志。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

### 2026-04-23（A2 收口：发送动作与进度展示下沉）

- 新增发送进度 presenter：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMediaSendProgressPresenter.swift`；
  - 职责：按钮可用状态、发送中透明度、进度条展示与隐藏。
- 新增媒体发送协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMediaMessageSendCoordinator.swift`；
  - 职责：图片/视频发送动作、进度更新回调、失败日志与失败提示触发。
- `DemoAlignedChatViewController` 收口：
  - 删除媒体发送状态与进度细节方法；
  - 由 `mediaProgressPresenter + mediaMessageSendCoordinator + mediaSendCoordinator` 协同驱动媒体发送链路。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：iOS 构建通过（仅 Pods deployment target 警告）。

### 2026-04-24（A2 收口：文本发送协调器下沉）

- 新增文本发送协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedTextSendCoordinator.swift`；
  - 职责：输入裁剪、发送按钮可用态、回车发送、发送失败回填输入、失败日志与提示触发。
- `DemoAlignedChatViewController` 收口：
  - 删除 `sendCurrentInput` 具体实现，改由 `textSendCoordinator.sendCurrentInput()` 驱动；
  - 输入框 `editingChanged` 与媒体发送状态变化统一回调到 `refreshSendButtonState()`；
  - `DemoAlignedMediaSendProgressPresenter` 不再直接管理 `sendButton`，改为通过状态回调与文本发送协调器联动。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅 Pods deployment target 警告）。

### 2026-04-24（A2 收口：消息点击动作下沉）

- 新增消息动作协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageActionCoordinator.swift`；
  - 职责：失败消息重发、媒体消息全屏预览、失败日志与失败提示触发。
- `DemoAlignedChatViewController` 收口：
  - 移除 `resendMessageIfNeeded` 与 `presentMediaPreviewIfNeeded` 细节实现；
  - `didSelectItemAt` 仅保留事件分发，交由 `messageActionCoordinator` 处理。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet`
  - 结果：构建通过（仅编译警告，无 error）。

### 2026-04-24（A2 收口：分页触发与顶部 loading 下沉）

- 新增分页协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedPaginationCoordinator.swift`；
  - 职责：顶部阈值触发分页、触发节流（需离开顶部再触发下一次）、顶部 loading 指示同步。
- `DemoAlignedChatViewController` 收口：
  - 删除 `syncOlderLoadingIndicator` 细节方法；
  - `scrollViewDidScroll` 中分页逻辑改为调用 `paginationCoordinator`；
  - `chatController.$isLoadingOlder` 直接绑定到 `paginationCoordinator.updateLoadingState`；
  - 会话切换时由 `paginationCoordinator.reset()` 统一复位分页状态。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`（构建通过）。

### 2026-04-24（A2 收口：Viewport 协调器下沉）

- 新增视口协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedViewportCoordinator.swift`；
  - 职责：键盘动画联动、未读新增计数、回到底部按钮文案与显示状态。
- `DemoAlignedChatViewController` 收口：
  - 删除本地 `pendingNewMessageCount` / `isJumpToBottomVisible` 状态；
  - 删除本地键盘动画方法与回到底部按钮状态管理方法；
  - 键盘通知、消息应用后按钮状态、滚动时按钮状态、按钮点击事件统一交由 `viewportCoordinator`。
- 编译兼容热修：
  - `Core/OpenIMSession.swift` 的 `currentBusinessUserIDSnapshot()` 增加 `#if canImport(OpenIMSDK)` 分支，避免无 SDK 编译路径下引用 `decodeRaverID` 失败。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：设置页路由协调器下沉）

- 新增路由协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatRouteCoordinator.swift`；
  - 职责：聊天设置页弹出、设置页内路由跳转（`appPush`）、退群后回退/自定义回调链路。
- `DemoAlignedChatViewController` 收口：
  - 删除 `handleSettingsTapped` 中的 `ChatSettingsSheet` 组装与 dismiss 路由细节；
  - 会话上下文变更时统一调用 `chatRouteCoordinator.updateContext(...)`。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：消息应用协调器下沉）

- 新增消息应用协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageApplyCoordinator.swift`；
  - 职责：会话消息列表应用、自动滚底判定、新增未读累计增量、新失败消息检测。
- `DemoAlignedChatViewController` 收口：
  - `applyMessagesFromController` 改为只保留“调用协调器 + 消费结果”；
  - 删除 VC 内部 `hasNewFailedOutgoingMessage` 细节实现。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：滚动协调器下沉）

- 新增滚动协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageViewportScrollCoordinator.swift`；
  - 职责：`scrollToBottom`、`isNearBottom`、分页锚点 `capture/restore`、`forceScrollOnNextApply` 统一编排。
- 关联改造：
  - `DemoAlignedChatViewController` 中的 `scrollToBottom` 私有实现已移除；
  - 键盘联动、输入框聚焦、回到底部按钮、分页前后锚点恢复均改为通过滚动协调器调用；
  - `DemoAlignedMessageApplyCoordinator` 改为基于滚动协调器计算 near-bottom 与 auto-scroll 判定。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：ComposerAction 协调器下沉）

- 新增输入动作协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedComposerActionCoordinator.swift`；
  - 职责：发送按钮、图片/视频按钮、输入框 begin/end/return 事件统一编排。
- `DemoAlignedChatViewController` 收口：
  - 新增 `configureComposerActionCoordinator()` 注入闭包依赖（文本发送、媒体发送、滚底、跳底按钮状态更新）；
  - `handleSendTapped / handleInputFieldEditingChanged / handleImageTapped / handleVideoTapped` 改为仅事件转发；
  - `UITextFieldDelegate` 的 begin/end/return 逻辑改为交由协调器处理。
- 收益：
  - 会话页 VC 进一步贴近 demo 风格的“容器 + 协调器组合”；
  - 输入区动作路径集中，后续扩展（草稿、@、输入状态）更容易。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：KeyboardLifecycle 协调器下沉）

- 新增键盘生命周期协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedKeyboardLifecycleCoordinator.swift`；
  - 职责：统一订阅/管理 `keyboardWillChangeFrame` 与 `keyboardWillHide`，统一计算 `shouldStickToBottom`。
- `DemoAlignedChatViewController` 收口：
  - 删除本地 `keyboardCancellables`；
  - 删除 `bindKeyboardChanges`、`handleKeyboardWillChangeFrame`、`handleKeyboardWillHide`；
  - 新增 `configureKeyboardLifecycleCoordinator()`，由 coordinator 回调 `viewportCoordinator` 与 `viewportScrollCoordinator` 完成动画与滚底联动。
- 收益：
  - 键盘监听与业务响应解耦，VC 继续减重；
  - 键盘策略可单点维护，后续引入输入态事件更容易。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：ControllerBinding 协调器下沉）

- 新增控制器绑定协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedControllerBindingCoordinator.swift`；
  - 职责：统一管理 `chatController.$messages` 与 `chatController.$isLoadingOlder` 订阅，向 VC 回调“消息刷新 / 分页 loading 状态”。
- `DemoAlignedChatViewController` 收口：
  - 删除本地 `cancellables` 与 `bindController()`；
  - 新增 `configureControllerBindingCoordinator()`，在 `viewDidLoad` 完成绑定启动。
- 修复记录：
  - 初版在 `deinit` 调用了 `@MainActor stop()` 导致编译报错；
  - 已移除 `deinit` 中同步 stop 调用，改为依赖对象释放自动清理。
- 收益：
  - 会话页订阅逻辑与 UI 逻辑解耦；
  - VC 继续向“组装容器”收敛。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：ChatScreenLifecycle 协调器下沉）

- 新增会话生命周期协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenLifecycleCoordinator.swift`；
  - 职责：统一 `start` 与 `updateConversation` 的生命周期编排。
- `DemoAlignedChatViewController` 收口：
  - 新增 `configureChatScreenLifecycleCoordinator()`；
  - `viewDidLoad` 中由 `chatScreenLifecycleCoordinator.start()` 启动会话；
  - `updateConversation(...)` 改为委托生命周期协调器执行上下文切换（标题更新、分页/视口重置、发送提示复位、路由上下文同步、`chatController.updateContext`）。
- 收益：
  - 会话上下文切换逻辑从 VC 中剥离，和 UI 组装边界更清晰；
  - 后续迭代“会话进入/离开策略”可在单点调整。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：首屏稳定滚底状态迁移到生命周期协调器）

- 代码变更：
  - `DemoAlignedChatScreenLifecycleCoordinator` 新增 `hasPerformedInitialStableScroll` 内部状态；
  - 新增 `handleViewDidAppear(hasMessages:) -> Bool`，统一计算是否需要首屏滚底；
  - 会话切换（`updateConversation`）时统一重置该状态为 `false`。
- `DemoAlignedChatViewController` 收口：
  - 删除本地 `hasPerformedInitialStableScroll` 字段；
  - `viewDidAppear` 改为调用生命周期协调器返回值决定是否滚底；
  - 配置生命周期协调器时移除 `resetInitialStableScroll` 依赖注入。
- 收益：
  - “首屏滚底一次”策略完全从 VC 剥离；
  - 会话生命周期状态集中在单一协调器，便于后续对齐 demo 的入场策略。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：ChatScreenAssembly 协调器下沉）

- 新增装配协调器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyCoordinator.swift`；
  - 职责：统一执行会话页初始化步骤顺序（`steps`）并在装配完成后触发生命周期启动（`onAssembled`）。
- `DemoAlignedChatViewController` 收口：
  - `viewDidLoad` 改为：
    - `configureChatScreenAssemblyCoordinator()`
    - `chatScreenAssemblyCoordinator?.assemble()`
  - 新增 `chatScreenAssemblyCoordinator` 属性与 `configureChatScreenAssemblyCoordinator()`；
  - 将原本 `viewDidLoad` 的 20+ 条配置调用按原顺序迁移为装配步骤闭包，行为保持一致。
- 收益：
  - 初始化顺序从 VC 主流程剥离，`viewDidLoad` 可读性明显提升；
  - 后续新增/重排装配步骤只需改装配清单，不需要在 VC 主流程中穿插。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：装配命名步骤与 DEBUG 顺序断言）

- `DemoAlignedChatScreenAssemblyCoordinator` 升级：
  - 引入 `Step(id, action)` 模型，装配步骤从匿名闭包改为命名步骤；
  - 新增 `expectedOrder`（可选）并在 `#if DEBUG` 下进行顺序断言；
  - `#if DEBUG` 下新增重复 step id 断言，防止装配定义出现冲突。
- `DemoAlignedChatViewController` 改造：
  - `configureChatScreenAssemblyCoordinator()` 引入 `expectedOrder` 常量；
  - 所有装配步骤改为显式 `id` 定义（如 `layout`, `collection_view`, `keyboard_lifecycle_coordinator` 等）。
- 收益：
  - 装配流程可读性与可维护性提升；
  - debug 阶段能提前发现初始化顺序偏移，降低隐性回归风险。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：`configure*` 分组重排与最小注释）

- `DemoAlignedChatViewController` 改造：
  - 按职责新增 `MARK` 分区：
    - `UI Assembly`
    - `Coordinator Assembly`
    - `Message Rendering`
    - `User Actions`
  - 将 `configureJumpToBottomButton` 与 `configureOlderLoadingIndicator` 归并到 UI 组装区；
  - 其余 `configure*` 与渲染/交互方法按分区归类，保持原有行为不变。
- 收益：
  - 文件可读性提升，定位“UI 搭建 vs 协调器组装 vs 渲染逻辑”更直接；
  - 新同学 onboarding 时不需要在单一长段中混读多类职责。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：消息流程编排器下沉）

- 新增消息流程编排器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageFlowCoordinator.swift`；
  - 职责：历史分页触发后的加载/锚点恢复、消息流应用、未读增量与滚动状态联动、失败提示触发。
- `DemoAlignedChatViewController` 收口：
  - 删除本地 `messages` 状态；
  - 删除 `loadOlderMessagesIfNeeded` 与 `applyMessagesFromController` 两个流程方法；
  - `configurePaginationCoordinator` 改为调用 `messageFlowCoordinator.loadOlderMessagesIfNeeded()`；
  - `configureControllerBindingCoordinator` 改为调用 `messageFlowCoordinator.applyMessagesFromController()`；
  - `viewDidAppear` 的 `hasMessages` 判定改为读取 `messageFlowCoordinator.hasMessages`。
- 生命周期同步：
  - `DemoAlignedChatScreenLifecycleCoordinator` 增加 `resetMessageFlowState` 回调；
  - 会话切换时统一触发 `messageFlowCoordinator.reset()`，避免旧会话消息状态污染。
- 收益：
  - 会话页的“流程编排”与“UI 事件”职责分离更彻底；
  - 消息加载/应用链路单点收口，更接近 demo 的分层策略。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：失败反馈编排器下沉）

- 新增失败反馈编排器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageFailureFeedbackCoordinator.swift`；
  - 职责：统一“发送失败提示”与“自定义失败提示（如媒体选择错误）”展示，并承接日志与重置。
- `DemoAlignedChatViewController` 收口：
  - 新增 `messageFailureFeedbackCoordinator` 属性；
  - 文本发送、媒体发送、消息重发、消息流检测失败全部改为调用 `messageFailureFeedbackCoordinator.showSendFailureHint()`；
  - 媒体选择错误由 `messageFailureFeedbackCoordinator.show(message:reason:)` 统一处理；
  - 删除 VC 内 `showSendFailureHint()`，避免失败提示策略分散。
- 装配顺序更新：
  - 新增装配步骤 `message_failure_feedback_coordinator`（位于 `send_failure_hint_presenter` 之后）；
  - `ChatScreenLifecycle` 的 `resetSendFailureHint` 改为触发 `messageFailureFeedbackCoordinator.reset()`。
- 收益：
  - 失败提示链路单点收口，VC 继续向“纯 UI 容器”靠拢；
  - 失败提示文案与日志策略后续可在单一 coordinator 演进。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：媒体选择错误触发点下沉）

- `DemoAlignedMediaSendCoordinator` 接口升级：
  - 新增 `conversationIDProvider`，由 coordinator 自行打日志；
  - `onError` 升级为 `onErrorFeedback(message, reason)`，将错误语义显式传递到失败反馈层。
- 媒体选择错误收口：
  - `loadFileRepresentation` 失败、URL 缺失、临时文件复制失败、不支持媒体类型，统一通过 `dispatchError(message, reason)` 处理；
  - 错误日志统一在 coordinator 内输出：
    - `[DemoAlignedChat] media picker error conversation=... reason=... message=...`
- `DemoAlignedChatViewController` 进一步瘦身：
  - `configureMediaSendCoordinator` 删除 picker 错误日志代码；
  - VC 仅保留 `messageFailureFeedbackCoordinator.show(message:reason:)` 展示调用。
- 收益：
  - picker 错误“日志 + 触发 + 展示”链路从 VC 下沉到发送链路 coordinator；
  - 失败反馈策略保持统一，VC 事件分支进一步减少。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：发送失败日志模板统一）

- 新增统一日志 helper：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatLogger.swift`；
  - 提供 `sendFailed` / `resendFailed` / `mediaPickerError` 三类日志入口。
- 发送链路替换：
  - `DemoAlignedTextSendCoordinator`：文本发送失败改用 `DemoAlignedChatLogger.sendFailed(kind: "text", ...)`
  - `DemoAlignedMediaMessageSendCoordinator`：图片/视频发送失败改用 `sendFailed(kind: "image"|"video", ...)`
  - `DemoAlignedMessageActionCoordinator`：重发失败改用 `resendFailed(...)`
  - `DemoAlignedMediaSendCoordinator`：picker 错误日志改用 `mediaPickerError(...)`
- 收益：
  - coordinator 内重复日志模板收口；
  - 后续统一扩展日志字段（traceID/device/session）只需改单点。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：ChatContextProvider 注入统一）

- 新增共享上下文提供器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatContextProvider.swift`
  - 统一提供 `conversationID`，用于发送链路与失败提示链路。
- coordinator 注入改造：
  - `DemoAlignedTextSendCoordinator`
  - `DemoAlignedMediaMessageSendCoordinator`
  - `DemoAlignedMediaSendCoordinator`
  - `DemoAlignedMessageActionCoordinator`
  - `DemoAlignedMessageFailureFeedbackCoordinator`
  - 上述模块全部由 `conversationIDProvider` 闭包改为 `chatContextProvider` 对象注入。
- `DemoAlignedChatViewController` 收口：
  - 新增 `chatContextProvider` 属性；
  - 新增装配步骤 `chat_context_provider`，并纳入装配顺序断言；
  - 删除多处重复的 `conversationIDProvider` 构造闭包。
- 修复记录：
  - 首次编译出现 actor 隔离报错（`conversationID` 在非隔离上下文读取）；
  - 已将 `DemoAlignedChatContextProvider` 从 `@MainActor` 下放为普通类型，复编通过。
- 收益：
  - 构造参数更简洁，重复闭包注入显著减少；
  - 会话上下文读取入口单点化，后续扩展（如 trace/session）更容易。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：FailureFeedbackActions 注入统一）

- 新增失败反馈动作分发器：
  - `Features/Messages/UIKitChat/Support/DemoAlignedFailureFeedbackActions.swift`
  - 统一封装：
    - `showSendFailureHint()`
    - `show(message:reason:)`
    - `reset()`
- coordinator 注入改造：
  - `DemoAlignedTextSendCoordinator`
  - `DemoAlignedMediaMessageSendCoordinator`
  - `DemoAlignedMessageActionCoordinator`
  - `DemoAlignedMediaSendCoordinator`
  - 上述模块由原始闭包注入改为 `failureFeedbackActions` 对象注入。
- `DemoAlignedChatViewController` 收口：
  - 新增 `failureFeedbackActions` 属性；
  - 新增装配步骤 `failure_feedback_actions`（位于 `message_failure_feedback_coordinator` 之后）；
  - 删除多处重复的 `messageFailureFeedbackCoordinator?.showSendFailureHint()` 闭包构造；
  - 生命周期复位改为 `failureFeedbackActions?.reset()`。
- 收益：
  - 失败提示触发入口统一、VC 装配参数噪音继续下降；
  - 后续替换失败提示策略（toast/banner）只需改单一动作分发器。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：日志事件模型统一）

- 日志层重构：
  - 在 `DemoAlignedChatLogger` 新增 `DemoAlignedChatLogEvent` 枚举；
  - 日志输出统一走 `DemoAlignedChatLogger.log(.event)`，由事件枚举生成标准日志行。
- 已覆盖事件：
  - `sendFailed`
  - `resendFailed`
  - `mediaPickerError`
  - `sendFailureHintShown`
  - `failureHintShown`
- 替换结果：
  - `DemoAlignedMessageFailureFeedbackCoordinator` 内两处 `OpenIMProbeLogger.log(...)` 直写已替换为 `DemoAlignedChatLogger`；
  - UIKitChat 模块内 `OpenIMProbeLogger.log(...)` 仅保留 `DemoAlignedChatLogger` 一处出口。
- 收益：
  - 日志语义与字符串模板解耦，避免散落字符串；
  - 后续扩展日志字段时只改 event->line 映射。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：装配依赖缺失可观测性增强）

- 新增装配依赖缺失报告：
  - `DemoAlignedChatViewController` 增加 `reportAssemblyDependencyMissing(step:dependencies:)`；
  - 行为：
    - 写入 `DemoAlignedChatLogger.assemblyDependencyMissing(...)`
    - `DEBUG` 下触发 `assertionFailure`。
- 覆盖的装配步骤：
  - `message_apply_coordinator`
  - `message_failure_feedback_coordinator`
  - `failure_feedback_actions`
  - `media_send_coordinator`
  - `media_progress_presenter`
  - `text_send_coordinator`
  - `media_message_send_coordinator`
  - `message_action_coordinator`
  - `message_flow_coordinator`
- 日志事件扩展：
  - `DemoAlignedChatLogEvent` 新增 `assemblyDependencyMissing`。
- 收益：
  - 初始化依赖异常不再静默失败，能快速定位“哪一步缺了哪个依赖”；
  - 与装配顺序断言形成互补（顺序正确但依赖缺失时也可观察）。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Assembly Step Builder 抽离）

- 新增独立 assembly plan builder：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyPlanBuilder.swift`
  - 提供：
    - `DemoAlignedChatScreenAssemblyActions`
    - `DemoAlignedChatScreenAssemblyPlan`
    - `DemoAlignedChatScreenAssemblyPlanBuilder.make(actions:)`
- `DemoAlignedChatViewController` 收口：
  - `configureChatScreenAssemblyCoordinator()` 不再内联超长 `expectedOrder + steps`；
  - VC 仅负责组织 actions，builder 统一生成 steps 与 expectedOrder；
  - `DemoAlignedChatScreenAssemblyCoordinator` 保持原逻辑（断言与执行）不变。
- 收益：
  - 初始化步骤定义从 VC 抽离，VC 继续瘦身；
  - assembly 顺序变更只改 builder，降低主控制器认知负担。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：装配依赖解析容器化）

- `DemoAlignedChatViewController` 新增轻量依赖解析容器：
  - `ContextFailureDependencies`
  - `MediaCoordinatorDependencies`
  - 解析函数：
    - `resolveContextFailureDependencies(step:)`
    - `resolveMediaCoordinatorDependencies(step:)`
- 改造点：
  - `configureMediaSendCoordinator`
  - `configureTextSendCoordinator`
  - `configureMediaMessageSendCoordinator`
  - `configureMessageActionCoordinator`
  - 以上方法由重复 `guard` 逻辑切换为依赖解析容器调用。
- 收益：
  - 重复依赖检查与错误上报逻辑收敛；
  - 装配函数可读性更高，依赖关系更显式。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Assembly Action 枚举执行器）

- Assembly builder 升级：
  - `DemoAlignedChatScreenAssemblyPlanBuilder` 改为基于 `DemoAlignedChatScreenAssemblyAction` 枚举生成 plan；
  - 移除原 `DemoAlignedChatScreenAssemblyActions` 大型闭包结构体。
- `DemoAlignedChatViewController` 收口：
  - 新增 `performAssemblyAction(_:)`，集中映射 action -> configure 方法；
  - `configureChatScreenAssemblyCoordinator()` 改为只注入统一 executor 闭包并创建 coordinator。
- 收益：
  - VC 不再维护 25 个 inline action 闭包；
  - 装配 action 定义（顺序/标识）与执行映射（switch）职责清晰分离。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Assembly Action 分组执行器）

- `DemoAlignedChatViewController` 进一步收口：
  - `performAssemblyAction(_:)` 改为两段式分发：
    - `performUIAssemblyAction(_:)`
    - `performCoordinatorAssemblyAction(_:)`
  - 未命中的 action 统一走 `assembly_action_dispatch` 缺失上报（日志 + DEBUG 断言）。
- 收益：
  - 单个 switch 体积下降，UI 与 coordinator 装配职责更清楚；
  - 新增 action 时更容易定位应归属的执行分组。
- 修复记录：
  - 首次改造遗漏 `collectionView` 分支的 `return true`，已修复并复编通过。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：未命中 Action 日志语义修正）

- `DemoAlignedChatLogger` 新增事件：
  - `assemblyActionUnhandled(conversationID, action)`
- `DemoAlignedChatViewController.performAssemblyAction`：
  - 未命中 action 时不再复用 `assemblyDependencyMissing`；
  - 改为记录 `assemblyActionUnhandled`，并在 `DEBUG` 下断言。
- 收益：
  - “依赖缺失”与“分发未覆盖”两类异常日志语义解耦；
  - 后续排查初始化问题时信号更准确。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Assembly Dispatcher 抽离为独立执行器）

- 新增执行器文件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyActionExecutor.swift`
  - 统一封装 action 执行流程：`UI 分发 -> Coordinator 分发 -> 未命中回调`。
- `DemoAlignedChatViewController` 收口：
  - 新增 `chatScreenAssemblyActionExecutor` 属性；
  - 删除 VC 内 `performAssemblyAction(_:)`；
  - `configureChatScreenAssemblyCoordinator()` 改为通过 `chatScreenAssemblyActionExecutor.execute(_:)` 执行 plan action；
  - 未命中 action 逻辑收口为 `handleUnhandledAssemblyAction(_:)`。
- 收益：
  - Assembly 总分发逻辑正式移出 VC，控制器职责继续收窄；
  - 下一步仅需继续把两段 switch 分发下沉即可完成该收口链路。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：UI/Coordinator Action 映射层下沉）

- 新增映射层文件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyActionHandlers.swift`
  - 将 `DemoAlignedChatScreenAssemblyAction` 的 UI 与 Coordinator 分组映射收口为独立 handlers。
- `DemoAlignedChatViewController` 收口：
  - 删除 `performUIAssemblyAction(_:)` / `performCoordinatorAssemblyAction(_:)` 两段 switch；
  - 新增 `chatScreenAssemblyActionHandlers` 属性；
  - 新增 `configureChatScreenAssemblyActionHandlers()`，通过闭包依赖注入绑定具体 `configure*` 方法；
  - `DemoAlignedChatScreenAssemblyActionExecutor` 改为调用 handlers 的 `performUIAction` / `performCoordinatorAction`。
- 收益：
  - Assembly action 总分发 + 分组映射都已从 VC 逻辑层抽离；
  - VC 剩余装配责任更聚焦在“依赖 wiring”，后续可继续抽掉样板注入代码。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Action Handler 依赖注入样板压缩）

- `DemoAlignedChatViewController` 收口：
  - 新增 `bindAssemblyAction(_:)` 通用绑定器；
  - 新增 `makeChatScreenAssemblyActionHandlerDependencies()`；
  - `configureChatScreenAssemblyActionHandlers()` 由大段重复 `[weak self]` 闭包，收敛为依赖构建函数调用。
- 收益：
  - Assembly handler wiring 的重复样板显著下降；
  - 后续继续把 dependencies builder 外移到独立 factory 会更平滑。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Handler Dependencies Builder 外移）

- 新增独立工厂：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyActionHandlerDependenciesFactory.swift`
  - 负责构建 `DemoAlignedChatScreenAssemblyActionHandlers.Dependencies`，用 `action -> configure` 的中间闭包做桥接。
- `DemoAlignedChatViewController` 收口：
  - 删除 `makeChatScreenAssemblyActionHandlerDependencies()`；
  - 新增 `performAssemblyConfigurationAction(_:)`（VC 内部私有分发，不扩大 `configure*` 访问域）；
  - `configureChatScreenAssemblyActionHandlers()` 改为调用 factory。
- 收益：
  - dependencies builder 已迁移到 Support 层，VC 的装配职责进一步收敛；
  - 保持 `configure*` 方法私有，不引入访问控制扩散。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：VC 内配置分发双段化 + Factory 覆盖断言）

- `DemoAlignedChatViewController` 收口：
  - `performAssemblyConfigurationAction(_:)` 改为双段式分发：
    - `performUIAssemblyConfigurationAction(_:)`
    - `performCoordinatorAssemblyConfigurationAction(_:)`
  - 两段均返回 `Bool`，未命中统一走 `handleUnhandledAssemblyAction(_:)`。
- `DemoAlignedChatScreenAssemblyActionHandlerDependenciesFactory` 增强：
  - 新增 `coveredActions` 清单；
  - `DEBUG` 下新增 `assertActionCoverage()`，校验 `coveredActions` 与 `DemoAlignedChatScreenAssemblyPlanBuilder.orderedActions` 一致性；
  - 防止 factory 与 assembly plan 发生漏配或偏移。
- 修复记录：
  - 首次引入覆盖断言时，`make()` 中 `.init(...)` 因编译器上下文推断失败导致构建失败；
  - 已改为显式 `return DemoAlignedChatScreenAssemblyActionHandlers.Dependencies(...)` 并复编通过。
- 收益：
  - 配置分发职责更清晰，VC 与 executor/handler 的边界更稳定；
  - action 覆盖在 DEBUG 期即可暴露，降低后续 silent-miswire 风险。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：VC 内 action->configure 映射表化）

- `DemoAlignedChatViewController` 收口：
  - 新增私有映射表：
    - `uiAssemblyConfigurationActions`
    - `coordinatorAssemblyConfigurationActions`
  - `performUIAssemblyConfigurationAction(_:)` / `performCoordinatorAssemblyConfigurationAction(_:)` 改为通过统一 helper：
    - `performAssemblyConfigurationAction(_:from:)`
  - 删除两段分发中的大 `switch`，改为映射表查找执行。
- `DEBUG` 保护：
  - 新增 `assertAssemblyConfigurationActionCoverage()`；
  - 校验 VC 内两张映射表的 action 覆盖集合与 `orderedActions` 一致，防止漏挂/多挂。
- 收益：
  - action 新增/迁移时只维护映射表，分发逻辑更稳定、可读性更高；
  - 与 factory 覆盖断言形成“双侧保护”，降低 silent wiring 风险。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：映射表下沉到私有 Mapper 类型）

- 新增 Support 类型：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyConfigurationActionMapper.swift`
  - 提供：
    - `performUIAction(_:)`
    - `performCoordinatorAction(_:)`
    - `coveredActions`
- `DemoAlignedChatViewController` 收口：
  - 删除 `uiAssemblyConfigurationActions` / `coordinatorAssemblyConfigurationActions` 两张字典属性；
  - 新增单一 `assemblyConfigurationActionMapper` 注入 closures；
  - `performUIAssemblyConfigurationAction` 与 `performCoordinatorAssemblyConfigurationAction` 改为直接委托 mapper；
  - 覆盖校验改为读取 `assemblyConfigurationActionMapper.coveredActions`。
- 收益：
  - VC 内“映射存储 + 执行细节”再次收缩到单一 mapper 依赖；
  - 后续若需要替换执行策略，可在 mapper 内独立演进。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Mapper 初始化噪音外移为 Factory）

- 新增 Support 工厂：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyConfigurationActionMapperFactory.swift`
  - 用 action-list + binder 生成 `DemoAlignedChatScreenAssemblyConfigurationActionMapper`（不在 VC 内手写大段闭包表）。
- `DemoAlignedChatViewController` 收口：
  - `assemblyConfigurationActionMapper` 改为由 factory 生成；
  - 新增 `executeAssemblyConfigurationAction(_:)` 专职执行 action -> `configure*`；
  - 保持 `configure*` 方法私有，不扩大访问域。
- 收益：
  - VC 初始化区块继续瘦身，action 分组表迁移到 Support；
  - action-list 与映射生成逻辑集中，后续扩展成本更低。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build > /tmp/raver_build.log 2>&1`
  - 结果：`EXIT:0`，`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：移除 VC 装配二次分发链路）

- `DemoAlignedChatViewController` 收口：
  - 删除 `assemblyConfigurationActionMapper` 相关依赖；
  - 删除 `performAssemblyConfigurationAction` 与 mapper 委托分发；
  - `executeAssemblyConfigurationAction(_:)` 改为单入口分发：
    - `executeUIAssemblyConfigurationAction(_:)`
    - `executeCoordinatorAssemblyConfigurationAction(_:)`
    - `executeCoordinatorContextAssemblyAction(_:)`
    - `executeCoordinatorMediaAssemblyAction(_:)`
    - `executeCoordinatorFlowAssemblyAction(_:)`
  - `configureChatScreenAssemblyActionHandlers()` 直接回调 `executeAssemblyConfigurationAction(_:)`。
- 清理无用 Support 文件：
  - 删除 `Support/DemoAlignedChatScreenAssemblyConfigurationActionMapper.swift`
  - 删除 `Support/DemoAlignedChatScreenAssemblyConfigurationActionMapperFactory.swift`
- 收益：
  - 装配动作从“handler -> perform -> mapper -> execute”收敛为“handler -> execute”；
  - VC action 执行路径更短，可读性与可维护性更高。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Coordinator 分发再细分为三域）

- `DemoAlignedChatViewController` 收口：
  - 将原 `executeCoordinatorFlowAssemblyAction(_:)` 再拆为：
    - `executeCoordinatorScrollAssemblyAction(_:)`
    - `executeCoordinatorMessagePipelineAssemblyAction(_:)`
    - `executeCoordinatorRouteLifecycleAssemblyAction(_:)`
  - `executeCoordinatorAssemblyConfigurationAction(_:)` 改为按 context/media/scroll/message-pipeline/route-lifecycle 顺序分发。
- 收益：
  - Coordinator 执行职责按能力域进一步拆开，单函数复杂度继续下降；
  - 后续若继续下沉到 Support（表驱动或策略对象）边界更清晰。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：Coordinator 主分发下沉到 Support）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenCoordinatorAssemblyActionDispatcher.swift`
  - 统一承接 coordinator 五段顺序分发（context/media/scroll/message-pipeline/route-lifecycle）。
- `DemoAlignedChatViewController` 收口：
  - 新增 `coordinatorAssemblyActionDispatcher`；
  - `executeCoordinatorAssemblyConfigurationAction(_:)` 收敛为单行委托：`coordinatorAssemblyActionDispatcher.execute(action)`；
  - VC 保留各域具体执行函数，分发编排逻辑迁出 VC。
- 收益：
  - VC 主分发函数复杂度继续下降；
  - 分发顺序策略集中在 Support，后续策略调整不会扰动 VC 主体。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：域内分发从 switch 切换为 map dispatcher）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyActionMapDispatcher.swift`
  - 用 action -> closure 映射统一执行，未命中返回 `false`。
- `DemoAlignedChatViewController` 收口：
  - UI + 5 个 coordinator 域（context/media/scroll/message-pipeline/route-lifecycle）均改为 map dispatcher 执行；
  - 删除各域内 `switch` 分支。
- 收益：
  - 域内分发逻辑从条件分支改为表驱动，新增/迁移动作时改动点更集中；
  - 与主 dispatcher（编排层）形成“编排 + 执行”双层解耦。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：多 dispatcher 属性聚合为 bundle）

- 新增 Support 类型：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyActionDispatcherBundle.swift`
  - 聚合 `ui/context/media/scroll/messagePipeline/routeLifecycle` 六个 dispatcher。
- `DemoAlignedChatViewController` 收口：
  - 删除 6 个分散 lazy dispatcher 属性；
  - 新增单一 `assemblyActionDispatcherBundle` + `makeAssemblyActionDispatcherBundle()`；
  - `executeUIAssemblyConfigurationAction` 与 5 个 coordinator 域执行函数改为通过 bundle 访问。
- 收益：
  - VC 顶部状态区块更紧凑，装配分发依赖更容易扫读；
  - 保持行为不变，仅收敛结构复杂度。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：装配依赖解析下沉到 Support）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatAssemblyDependencyResolver.swift`
  - 统一封装：
    - 依赖缺失上报（`assemblyDependencyMissing` + DEBUG 断言）
    - `contextFailureDependencies` 解析
    - `mediaCoordinatorDependencies` 解析
- `DemoAlignedChatViewController` 收口：
  - 删除 VC 内部 `ContextFailureDependencies` / `MediaCoordinatorDependencies` 与 3 个解析/上报方法；
  - 新增 `assemblyDependencyResolver`，各 `configure*Coordinator` 改为通过 resolver 完成依赖校验与依赖聚合。
- 收益：
  - VC coordinator 装配逻辑进一步聚焦在“组装行为”，不再承载依赖解析细节；
  - 缺依赖日志行为保持一致，后续可在 Support 统一增强。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：dispatcher bundle 构建迁移到 Support Factory）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyActionDispatcherBundleFactory.swift`
  - 统一承载 action->dispatcher 的映射装配逻辑。
- `DemoAlignedChatViewController` 收口：
  - `assemblyActionDispatcherBundle` 改为通过 factory 生成；
  - 删除 VC 内 `makeAssemblyActionDispatcherBundle()` 的映射构建实现；
  - VC 仅保留 `makeAssemblyActionDispatcherBundleDependencies()`，负责注入具体 `configure*` 闭包。
- 收益：
  - 分发表定义彻底迁出 VC 主体，VC 继续收敛为“依赖注入 + 业务装配”；
  - 后续若调整 action 分组或 dispatcher 映射，只改 Support Factory。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（A2 收口：装配闭包绑定压缩 + Composer/Keyboard Factory 下沉）

- `DemoAlignedChatViewController` 收口：
  - `makeAssemblyActionDispatcherBundleDependencies()` 的 `configure*` 注入统一改用 `bindAssemblyConfiguration(...)`，减少重复 `[weak self]` 样板；
  - `configureComposerActionCoordinator()` 改为调用 `DemoAlignedComposerActionCoordinatorFactory`；
  - `configureKeyboardLifecycleCoordinator()` 改为调用 `DemoAlignedKeyboardLifecycleCoordinatorFactory`。
- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedComposerActionCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedKeyboardLifecycleCoordinatorFactory.swift`
- 收益：
  - VC 内 coordinator wiring 噪音继续降低，装配方法更接近“纯注入”；
  - keyboard/composer 的闭包拼装逻辑迁出 VC，便于后续继续模块化。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

### 2026-04-24（A2 收口：MessageFlow/ControllerBinding Factory 下沉）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageFlowCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedControllerBindingCoordinatorFactory.swift`
- `DemoAlignedChatViewController` 收口：
  - `configureMessageFlowCoordinator()` 改为调用 `DemoAlignedMessageFlowCoordinatorFactory`；
  - `configureControllerBindingCoordinator()` 改为调用 `DemoAlignedControllerBindingCoordinatorFactory`；
  - `message_flow_coordinator` 的缺依赖上报从 VC guard 下沉为 factory 注入回调。
- 收益：
  - VC 内 message pipeline 装配继续简化为“依赖注入 + 调用工厂”；
  - `messages`/`loadingOlder` 绑定闭包样板迁出 VC，后续扩展更集中。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

### 2026-04-24（A2 收口：Route/Lifecycle Factory 下沉）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatRouteCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenLifecycleCoordinatorFactory.swift`
- `DemoAlignedChatViewController` 收口：
  - `configureChatRouteCoordinator()` 改为通过 `DemoAlignedChatRouteCoordinatorFactory` 注入；
  - `configureChatScreenLifecycleCoordinator()` 改为通过 `DemoAlignedChatScreenLifecycleCoordinatorFactory` 注入；
  - 生命周期协调器里 `title/dataSource/scroll/pagination/viewport/resetSendFailureHint/routeContext` 闭包 wiring 全部迁出 VC。
- 收益：
  - route 与 screen lifecycle 的闭包拼装逻辑集中到 Support；
  - VC coordinator 组装进一步接近“纯依赖注入”。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

### 2026-04-24（A2 收口：ChatScreenAssemblyCoordinator Factory 下沉）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyCoordinatorFactory.swift`
  - 统一装配 `DemoAlignedChatScreenAssemblyActionHandlers` + `DemoAlignedChatScreenAssemblyActionExecutor` + `DemoAlignedChatScreenAssemblyCoordinator`。
- `DemoAlignedChatViewController` 收口：
  - 删除 `configureChatScreenAssemblyActionHandlers()` / `configureChatScreenAssemblyActionExecutor()` 两段样板；
  - `configureChatScreenAssemblyCoordinator()` 改为一次 factory 调用；
  - 移除 `chatScreenAssemblyActionHandlers` / `chatScreenAssemblyActionExecutor` 属性，减少 VC 状态面。
- 收益：
  - 装配编排链路迁出 VC，A2“VC 只保留容器与注入”目标继续推进；
  - 后续若调整 assembly plan 执行链路，可在 factory 单点演进。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

### 2026-04-24（A2 收口：Assembly Configuration Executor 下沉）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyConfigurationExecutor.swift`
  - 包含：
    - `DemoAlignedChatScreenAssemblyConfigurationExecutor`
    - `DemoAlignedChatScreenAssemblyConfigurationExecutorFactory`
- `DemoAlignedChatViewController` 收口：
  - 删除 `assemblyActionDispatcherBundle` 与 `coordinatorAssemblyActionDispatcher` 两个属性；
  - 删除多段执行分发函数：
    - `executeUIAssemblyConfigurationAction`
    - `executeCoordinatorAssemblyConfigurationAction`
    - `executeCoordinatorContextAssemblyAction`
    - `executeCoordinatorMediaAssemblyAction`
    - `executeCoordinatorScrollAssemblyAction`
    - `executeCoordinatorMessagePipelineAssemblyAction`
    - `executeCoordinatorRouteLifecycleAssemblyAction`
  - 新增单一 `assemblyConfigurationExecutor`，`executeAssemblyConfigurationAction(_:)` 改为一行委托执行。
- 收益：
  - assembly action 执行路径从 VC 内多层分发收敛为单执行器；
  - VC 继续向“UI 容器 + 依赖注入”目标收口。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

### 2026-04-24（A2 收口：Media/Text/MessageAction Factory 下沉）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMediaSendCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedTextSendCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedMediaMessageSendCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageActionCoordinatorFactory.swift`
- `DemoAlignedChatViewController` 收口：
  - `configureMediaSendCoordinator()` 改为通过 `DemoAlignedMediaSendCoordinatorFactory` 注入；
  - `configureTextSendCoordinator()` 改为通过 `DemoAlignedTextSendCoordinatorFactory` 注入；
  - `configureMediaMessageSendCoordinator()` 改为通过 `DemoAlignedMediaMessageSendCoordinatorFactory` 注入；
  - `configureMessageActionCoordinator()` 改为通过 `DemoAlignedMessageActionCoordinatorFactory` 注入；
  - 各工厂统一接管依赖 guard，并通过 `onMissingDependencies` 回调复用原 `assemblyDependencyMissing` 上报路径。
- 收益：
  - 发送链路与消息动作链路的装配逻辑继续迁出 VC；
  - 缺依赖处理语义保持一致，同时降低 VC 内重复 guard/注入样板。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

### 2026-04-24（A2 收口：MessageApply/Pagination/Viewport/FailureFeedback/MediaProgress Factory 下沉）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageApplyCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedPaginationCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedViewportCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedMediaSendProgressPresenterFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedMessageFailureFeedbackCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedFailureFeedbackActionsFactory.swift`
- `DemoAlignedChatViewController` 收口：
  - `configureMessageApplyCoordinator()` 改为 `DemoAlignedMessageApplyCoordinatorFactory`；
  - `configurePaginationCoordinator()` 改为 `DemoAlignedPaginationCoordinatorFactory`；
  - `configureViewportCoordinator()` 改为 `DemoAlignedViewportCoordinatorFactory`；
  - `configureMediaProgressPresenter()` 改为 `DemoAlignedMediaSendProgressPresenterFactory`；
  - `configureMessageFailureFeedbackCoordinator()` 改为 `DemoAlignedMessageFailureFeedbackCoordinatorFactory`；
  - `configureFailureFeedbackActions()` 改为 `DemoAlignedFailureFeedbackActionsFactory`；
  - 缺依赖 guard 统一由 factory 内处理，并通过 `onMissingDependencies` 回调复用 `assemblyDependencyResolver.reportMissing(...)`。
- 收益：
  - 分页/视口/失败反馈/发送进度装配逻辑进一步迁出 VC；
  - coordinator 装配风格更统一，后续扩展依赖校验更集中。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

### 2026-04-24（A2 收口：ViewportScroll/HintPresenter/ChatContext Factory 下沉）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedViewportScrollCoordinatorFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedSendFailureHintPresenterFactory.swift`
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatContextProviderFactory.swift`
- `DemoAlignedChatViewController` 收口：
  - `configureViewportScrollCoordinator()` 改为通过 `DemoAlignedViewportScrollCoordinatorFactory` 注入；
  - `configureSendFailureHintPresenter()` 改为通过 `DemoAlignedSendFailureHintPresenterFactory` 注入；
  - `configureChatContextProvider()` 改为通过 `DemoAlignedChatContextProviderFactory` 注入。
- 收益：
  - 常驻辅助对象的装配路径与其他 coordinator 保持一致；
  - VC 内“直接 new 对象”样板继续减少，A2 收口一致性更高。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target 警告）。

### 2026-04-24（A2 收口：UI Assembly Factory 下沉）

- 新增 Support 组件：
  - `Features/Messages/UIKitChat/Support/DemoAlignedChatUIAssemblyFactory.swift`
  - 包含 `layout / collectionView / composer / jumpToBottomButton / olderLoadingIndicator` 五段 UI 装配工厂方法。
- `DemoAlignedChatViewController` 收口：
  - `configureLayout()` 改为 `DemoAlignedChatUIAssemblyFactory.configureLayout(...)`；
  - `configureCollectionView()` 改为 `DemoAlignedChatUIAssemblyFactory.makeCollectionView(...)`；
  - `configureComposer()` 改为 `DemoAlignedChatUIAssemblyFactory.configureComposer(...)` 并返回 `mediaProgressHeightConstraint`；
  - `configureJumpToBottomButton()` / `configureOlderLoadingIndicator()` 改为对应工厂方法；
  - `inputField.delegate = self` 仍留在 VC，行为保持不变。
- 收益：
  - VC 内大段 UIKit 约束与控件初始化样板迁出；
  - A2 目标下“VC 仅保留编排与注入”的结构更稳定。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：`traitCollectionDidChange` deprecate、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：UI Factory 覆盖导航项与输入 delegate）

- `DemoAlignedChatUIAssemblyFactory` 扩展：
  - 新增 `configureNavigationItems(...)`；
  - `configureComposer(...)` 依赖新增 `inputFieldDelegate`，由工厂统一设置 `inputField.delegate`。
- `DemoAlignedChatViewController` 收口：
  - `configureNavigationItems()` 改为通过 UI factory 注入；
  - `configureComposer()` 删除 VC 内 `inputField.delegate = self` 直写，改由 factory 注入。
- 收益：
  - UI 装配职责进一步集中，VC 的直接 UIKit 赋值继续减少；
  - 导航栏动作与 composer 输入行为装配风格保持一致。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`traitCollectionDidChange` deprecate、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：缺依赖回调样板收口）

- `DemoAlignedChatViewController` 收口：
  - 新增私有 helper：`makeMissingDependencyReporter(step:)`；
  - 将 9 处 `onMissingDependencies` 重复闭包统一替换为 helper 注入：
    - `message_apply_coordinator`
    - `message_failure_feedback_coordinator`
    - `failure_feedback_actions`
    - `media_send_coordinator`
    - `media_progress_presenter`
    - `text_send_coordinator`
    - `media_message_send_coordinator`
    - `message_action_coordinator`
    - `message_flow_coordinator`
- 收益：
  - 缺依赖上报语义保持一致，避免后续新增 step 时复制粘贴闭包；
  - VC 内 coordinator wiring 样板继续下降，更贴近“容器 + 装配”职责。
- 验证日志：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：resolver/provider 闭包样板收口）

- `DemoAlignedChatViewController` 收口：
  - 新增私有 helper：
    - `makeConversationIDResolver()`
    - `makeOnSendSucceededHandler()`
    - `makeOnSendFailureHintHandler()`
  - 复用路径：
    - `assemblyDependencyResolver.conversationIDProvider`
    - `configureChatContextProvider().conversationIDResolver`
    - `configureTextSendCoordinator().onSendSucceeded`
    - `configureMediaMessageSendCoordinator().onSendSucceeded`
    - `configureMessageFlowCoordinator().onSendFailureHint`
- 收益：
  - resolver/provider 注入写法一致，减少重复 `[weak self]` 闭包；
  - VC 装配段进一步聚焦“依赖声明”而非重复实现细节。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：装配绑定由闭包改为方法引用）

- `DemoAlignedChatViewController` 收口：
  - `bindAssemblyConfiguration` 从 `(DemoAlignedChatViewController) -> Void` 闭包绑定，改为 `(DemoAlignedChatViewController) -> () -> Void` 方法引用绑定；
  - `makeAssemblyActionDispatcherBundleDependencies()` 的 25 处 `bindAssemblyConfiguration { $0.configure... }` 全部改为：
    - `bindAssemblyConfiguration(DemoAlignedChatViewController.configure...)`。
- 收益：
  - 装配分发表保持不变，但闭包噪音进一步减少；
  - VC 中 action wiring 更接近“声明式绑定”。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：异步回调闭包收口）

- `DemoAlignedChatViewController` 收口：
  - 新增回调 helper：
    - `makeOnLoadOlderHandler()`
    - `makeOnMediaPickedHandler()`
    - `handleMediaPicked(_:)`
  - 替换内联闭包：
    - `configurePaginationCoordinator().onLoadOlder`
    - `configureMediaSendCoordinator().onPicked`
- 收益：
  - 分页与媒体发送链路的异步回调从装配段迁到统一 handler；
  - coordinator 装配代码继续“声明化”，减少大段 Task/switch 嵌套。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：ChatScreen 装配回调闭包收口）

- `DemoAlignedChatViewController` 收口：
  - 新增通用 helper：
    - `bindActionHandler<Value>(...)`
    - `bindCallback(...)`
    - `startChatScreenLifecycleCoordinator()`
  - `assemblyConfigurationExecutor.onUnhandledAction` 改为方法引用绑定；
  - `configureChatScreenAssemblyCoordinator()` 的 3 处回调改为绑定方法引用：
    - `executeAssemblyConfigurationAction`
    - `onUnhandledAction`
    - `onAssembled`
- 收益：
  - `configureChatScreenAssemblyCoordinator` 从闭包装配进一步收口为“声明式绑定”；
  - 生命周期启动入口语义更集中，便于后续做 A2 最终清理。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：UI/发送态闭包再压缩）

- `DemoAlignedChatViewController` 收口：
  - `configureCollectionView().registerCells` 改为方法引用绑定：
    - `bindActionHandler(DemoAlignedChatViewController.registerCollectionCells)`
  - `configureMediaProgressPresenter().onSendingStateChanged` 改为方法引用绑定：
    - `bindActionHandler(DemoAlignedChatViewController.handleMediaSendingStateChanged)`
  - `handleJumpToBottomTapped()` 改为显式 `scrollToBottom:` 绑定：
    - `bindActionHandler(DemoAlignedChatViewController.handleJumpToBottomAnimation)`
- 收益：
  - VC 内匿名闭包继续减少，UI/发送态/滚动行为入口更可读；
  - 与前面 A2 的 “方法引用化” 风格保持一致。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：`make*` 闭包统一为方法引用绑定）

- `DemoAlignedChatViewController` 收口：
  - 新增通用 helper：
    - `bindAsyncCallback(...)`
    - `bindValueProvider(...)`
  - 逐步替换 `make*` 闭包入口：
    - `conversationIDProvider` / `conversationIDResolver` 改为 `bindValueProvider(currentConversationID, fallback: "unknown")`；
    - `onLoadOlder` 改为 `bindAsyncCallback(loadOlderMessagesIfNeeded)`；
    - `onPicked` 改为 `bindActionHandler(handleMediaPicked)`；
    - `onSendSucceeded` 改为 `bindCallback(handleSendSucceeded)`；
    - `onSendFailureHint` 改为 `bindCallback(handleSendFailureHint)`；
  - 删除重复的 `makeConversationIDResolver / makeOnSendSucceeded / makeOnSendFailureHint / makeOnLoadOlder / makeOnMediaPicked` 闭包样板。
- 收益：
  - 装配段中“闭包工厂函数”显著减少，VC 更接近 demo 风格的声明式 wiring；
  - async/value/action 三类回调路径统一，后续继续拆分时更不易回归。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：MainActor 异步动作绑定统一）

- `DemoAlignedChatViewController` 收口：
  - 新增 `bindMainActorAsyncAction(...)`，统一“同步回调 -> MainActor async 行为”调度；
  - `configureMediaSendCoordinator().onPicked` 改为 `bindMainActorAsyncAction(handleMediaPicked)`；
  - `handleMediaPicked` 改为 `async` 方法（移除内联 `Task {}`）；
  - `collectionView(_:didSelectItemAt:)` 改为通过 `bindMainActorAsyncAction(handleMessageTappedAction)` 触发；
  - 新增 `handleMessageTappedAction(_:) async` 作为消息点击入口。
- 收益：
  - VC 中剩余异步 `Task` 闭包进一步减少并统一调度风格；
  - 消息点击与媒体选择路径在 MainActor 下行为更一致。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：缺依赖上报 step 类型化）

- `DemoAlignedChatViewController` 收口：
  - 新增 `MissingDependencyStep` 枚举，承载所有 `onMissingDependencies` 上报步骤；
  - 将 `makeMissingDependencyReporter(step: String)` 改为 `bindMissingDependencyReporter(_ step: MissingDependencyStep)`；
  - `message_apply_coordinator / media_send_coordinator / text_send_coordinator / message_flow_coordinator` 等全部改为类型化 step 注入。
- 收益：
  - 移除字符串 step 的手写风险，缺依赖观测点更稳；
  - VC wiring 继续压缩，A2 “纯容器 + 注入”目标进一步靠近。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：resolver/provider 回调复用）

- `DemoAlignedChatViewController` 收口：
  - 新增复用闭包属性：
    - `conversationIDProvider`
    - `onSendSucceededCallback`
    - `onSendFailureHintCallback`
  - `assemblyDependencyResolver` 与 `chatContextProvider` 统一复用 `conversationIDProvider`；
  - 文本/媒体发送成功回调统一复用 `onSendSucceededCallback`；
  - 消息流失败提示回调统一复用 `onSendFailureHintCallback`。
- 收益：
  - provider/callback 重复注入继续下降，VC 装配段更接近“声明式清单”；
  - 关键回调语义单点化，后续修改不易遗漏。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：缺依赖 reporter 下沉到 Resolver）

- `DemoAlignedChatAssemblyDependencyResolver` 收口：
  - 新增 `DemoAlignedChatAssemblyMissingDependencyStep`（typed step 枚举）；
  - 新增 `makeMissingDependencyReporter(for:)`；
  - 新增 `reportMissing(step: DemoAlignedChatAssemblyMissingDependencyStep, ...)` 重载。
- `DemoAlignedChatViewController` 收口：
  - 删除 VC 内 `MissingDependencyStep` 与 `bindMissingDependencyReporter(...)`；
  - 新增 `missingDependencyReporter`（由 resolver 提供）；
  - 所有 `onMissingDependencies` 改为 `missingDependencyReporter(.xxx)`。
- 收益：
  - 缺依赖上报逻辑从 VC 迁移到 Support 层，VC 继续减重；
  - step 类型与 reporter 绑定集中管理，后续扩展更一致。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：装配依赖清单 bind 样板压缩）

- `DemoAlignedChatViewController` 收口：
  - 在 `makeAssemblyActionDispatcherBundleDependencies()` 内引入局部 `let bind = bindAssemblyConfiguration`；
  - 装配清单由 `bindAssemblyConfiguration(...)` 统一缩写为 `bind(...)`，降低重复噪音。
- 收益：
  - action->configure 依赖清单更紧凑，读起来更像声明式配置表；
  - VC 在不改行为的前提下继续减重。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：弱绑定器统一下沉）

- `DemoAlignedChatViewController` 收口：
  - 删除 VC 内 6 个通用绑定方法：
    - `bindAssemblyConfiguration`
    - `bindActionHandler`
    - `bindMainActorAsyncAction`
    - `bindCallback`
    - `bindAsyncCallback`
    - `bindValueProvider`
  - 新增 `DemoAlignedWeakBinder`，统一承接弱引用绑定（`assemblyConfiguration/action/mainActorAsyncAction/callback/asyncCallback/valueProvider`）。
  - VC 内所有装配与交互回调注入统一改为 `DemoAlignedWeakBinder.*(owner:self, ...)` 风格。
- 收益：
  - VC 通用绑定基础设施代码继续下降，装配段更聚焦业务语义；
  - 弱引用策略单点化，后续扩展/审查更稳定。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：装配清单迁出 VC 主体）

- `DemoAlignedChatViewController` 收口：
  - `assemblyConfigurationExecutor` 的 `dispatcherBundleDependencies` 改为通过 `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.make(owner:)` 注入；
  - 删除 VC 主体内 `makeAssemblyActionDispatcherBundleDependencies()` 大清单方法。
- 新增类外工厂（同文件私有类型）：
  - `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory` 统一承载 25 项 action->configure 方法引用清单；
  - 保持 `DemoAlignedWeakBinder.assemblyConfiguration` 的方法引用绑定风格。
- 可见性处理：
  - 将参与清单映射的 `configure*` 方法调整为 `fileprivate`，继续限定在当前文件内使用。
- 收益：
  - VC 主体进一步瘦身，装配清单从主类逻辑中剥离；
  - action->configure 映射集中在单点工厂，后续继续下沉到 Support 文件更顺滑。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A2 收口：Dispatcher/WeakBinder 迁入 Support 独立文件）

- `DemoAlignedChatViewController` 收口：
  - `assemblyConfigurationExecutor` 的 `dispatcherBundleDependencies` 改为通过
    `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.make(executeAction:)` 注入；
  - 新增 `performAssemblyConfigurationAction(_:)` 作为 action 分发入口（25 项 action -> `configure*`）。
- 新增 Support 独立文件：
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Support/DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.swift`
  - 文件内承载：
    - `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory`
    - `DemoAlignedWeakBinder`
- 可见性收口：
  - 将此前为清单映射放宽为 `fileprivate` 的 `configure*` 方法恢复为 `private`。
- 收益：
  - `DemoAlignedChatViewController` 内部类型继续减重，Support 分层与 demo 对齐度更高；
  - weak binding 与 action->configure 清单都进入可复用文件，后续 A2 清尾改动面更集中。
- 验证日志：
  - `xcodegen generate`（cwd: `/Users/blackie/Projects/raver/mobile/ios/RaverMVP`）
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`asset.duration` deprecate、`Metadata extraction skipped`）。

### 2026-04-24（A2 清尾：移除 VC 内 `performAssemblyConfigurationAction` 分发）

- `DemoAlignedChatViewController` 收口：
  - 删除 VC 内 `performAssemblyConfigurationAction(_:)`（25 项 switch 分发）；
  - 新增 `assemblyDispatcherBundleDependencies`，直接注入 `DemoAlignedChatScreenAssemblyActionDispatcherBundleDependencies`；
  - `assemblyConfigurationExecutor` 改为直接消费上述 dependencies，不再走 `executeAction -> switch` 中转链路。
- 收益：
  - Assembly action 分发从 VC 彻底下沉到 Support dispatcher/executor；
  - VC 进一步接近“UI 容器 + 注入”形态，A2 清尾目标继续收敛。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`asset.duration` deprecate、`Metadata extraction skipped`）。

### 2026-04-24（OpenIM/BFF 默认端口收口：统一到 3901）

- 代码与脚本收口：
  - `server/src/scripts/openim-bff-squad-manage-smoke.ts` 默认 `OPENIM_BFF_BASE_URL` 改为 `http://localhost:3901`；
  - `server/.env.openim.example` 默认 `OPENIM_BFF_BASE_URL` 改为 `http://localhost:3901`；
  - 本地启动脚本统一后端端口到 `3901`：
    - `restart-dev.sh`
    - `start-all.sh`
    - `check-status.sh`
    - `status.sh`
    - `start.sh`
- 文档示例收口（避免环境污染）：
  - `docs/OPENIM_LOCAL_DEV.md`
  - `docs/OPENIM_INTEGRATION_PLAN.md`
  - `docs/DEV_PROXY_DB_RUNBOOK.md`
  - `docs/TEST_ENV_DEPLOYMENT_PLAN.md`
- 结果：
  - OpenIM/BFF 关键默认源头已统一为 `3901`，减少 Xcode/脚本回落到 `3001` 的风险。

### 2026-04-24（A2 清尾：移除 `make(executeAction:)` 遗留工厂路径）

- 代码清理：
  - `Support/DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.swift` 删除
    `DemoAlignedChatScreenAssemblyDispatcherBundleDependenciesFactory.make(executeAction:)`；
  - 保留 `DemoAlignedWeakBinder` 作为通用弱绑定工具。
- 收益：
  - A2 本轮“executeAction 中转链路”遗留代码清理完成；
  - Assembly dependencies 注入路径收敛为单实现，降低后续维护歧义。

### 2026-04-24（A2 清尾：VC 装配清单噪音收口）

- `DemoAlignedChatViewController` 收口：
  - `assemblyDispatcherBundleDependencies` 改为一行 `makeAssemblyDispatcherBundleDependencies()`；
  - 新增 `bindAssemblyConfiguration(...)` 与 `makeAssemblyDispatcherBundleDependencies()`，
    将 25 项 action->configure 绑定集中到单个 helper，移出属性区。
- 收益：
  - VC 主体可读性提升，属性定义区显著减噪；
  - A2「VC 收敛为 UI 容器」收口项完成并勾选。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A3 第一刀：系统消息专用 Cell 分流）

- 渲染补齐：
  - 新增 `DemoAlignedSystemMessageCell`（居中胶囊样式）用于 `system` 消息渲染；
  - `RaverChatMessageCellFactory` 新增 `.system` 分流：
    - `system` -> `DemoAlignedSystemMessageCell`
    - `image/video/voice/file` -> `DemoAlignedMediaMessageCell`
    - 其余 -> `DemoAlignedMessageCell`
  - `RaverChatCollectionDataSource` 在 `updateMessages` 入口过滤 `typing`，仅保留输入状态层展示，不混入历史消息列表。
- 文档进度：
  - A3 子项“文本/图片/视频/语音/文件/系统消息 Cell 同构”已勾选完成。
- 验证日志：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A3 收口：发送态细节 + 勾选闭环）

- 视觉补齐：
  - `DemoAlignedMessageCell` / `DemoAlignedMediaMessageCell` 的 `sending` 状态图标新增旋转动效；
  - 在 `sent/failed/reuse` 场景统一停止动画，避免复用残留与状态串色。
- 文档收口：
  - A3 三个剩余父项统一勾选完成：
    - 发送中/失败/重发状态 UI 同构
    - 分组（按时间）与时间分隔样式同构
    - 头像、昵称、群聊显示规则同构
- 阶段状态：
  - A3 由“已开始”更新为“完成（渲染对齐项收口）”。

### 2026-04-24（A4 回归增强：分页/滚动/跳底可观测性）

- 新增 A4 结构化日志（App 内 probe）：
  - `DemoAlignedPaginationCoordinator`：
    - 分页触发 `trigger load-older`
    - 触发复位 `rearm`
    - 顶部 loading 状态变化
  - `RaverChatScrollCoordinator`：
    - 自动滚底判定日志（`result=1/0 + reason`），用于区分
      “应滚底”与“分页/离底部时禁止滚底”。
  - `DemoAlignedViewportCoordinator`：
    - 新消息累积、回到底部按钮 show/hide、按钮点击日志。
  - `DemoAlignedMessageFlowCoordinator`：
    - 历史分页加载 start/end；
    - 消息 apply 后 auto-scroll / pendingDelta / failure-hint 结果日志。
- 双机探针与 digest 同步增强：
  - `openim_dual_sim_probe.sh` 的 focus 规则纳入上述 A4 日志前缀；
  - `openim_probe_digest.sh` 新增指标：
    - `paginationTrigger`
    - `autoScrollYes / autoScrollNo`
    - `jumpShow / jumpHide`
- 验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅保留既有 warning：Pods deployment target、`Metadata extraction skipped`）。

### 2026-04-24（A4 回归复测：90s 双机探针）

- 执行命令：
  - `OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=90 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
  - 并行注入：
    - `OPENIM_PROBE_SESSION_TYPE=single OPENIM_PROBE_SENDER_IDENTIFIER=blackie OPENIM_PROBE_RECEIVER_IDENTIFIER=uploadtester OPENIM_PROBE_MESSAGE_COUNT=5 OPENIM_PROBE_INTERVAL_MS=600 npm run openim:probe:send`
- 报告目录：
  - `/Users/blackie/Projects/raver/docs/reports/openim-dual-sim-20260424-192315`
- digest 结论：
  - `overall: 双侧日志有效`
  - `SIM1`: realtime=10 / catchup=0 / login10102=0 / unavailable=0
  - `SIM2`: realtime=15 / catchup=0 / login10102=0 / unavailable=0
  - `paginationTrigger=0`（本轮未触发会话内“上滑到顶分页”手势）
- 阶段判断：
  - 实时链路与 A4 观测链路验证通过；
  - 分页专项仍需一轮“进入会话后上滑到最顶”复测来补齐 `paginationTrigger > 0` 的证据。

### 2026-04-24（A4 回归复测补样：会话内手势分页通过）

- 执行命令：
  - `OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=90 OPENIM_PROBE_USE_APP_LOG=1 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
- 报告目录：
  - `/Users/blackie/Projects/raver/docs/reports/openim-dual-sim-20260424-212001`
- digest 结论：
  - `overall: 双侧日志有效`
  - `SIM1`: realtime=5 / catchup=0 / login10102=0 / unavailable=0
  - `SIM2`: realtime=20 / catchup=0 / login10102=0 / unavailable=0
  - A4 指标：
    - `SIM1`: `paginationTrigger=0`，`autoScrollYes=14`，`autoScrollNo=21`，`jumpShow=8`，`jumpHide=8`
    - `SIM2`: `paginationTrigger=9`，`autoScrollYes=4`，`autoScrollNo=35`，`jumpShow=10`，`jumpHide=9`
- 阶段判断：
  - 会话内“上滑到顶触发分页 + 新消息不打断 + jump 按钮显隐 + 回到底部”证据已闭环；
  - A4 分页专项回归完成，可进入下一阶段。

### 2026-04-24（S-3：媒体缓存管理器 V1）

- iOS 落地：
  - `ChatMediaTempFileStore` 升级为统一缓存管理器，目录切换为 `Library/Caches/raver-chat-media-cache`；
  - 按类型分目录：`image / video / voice / file / other`；
  - 清理策略：TTL 7 天、容量上限 512MB（按最近访问时间淘汰）、10 分钟清理节流；
  - 命中可观测：新增 `write/hit/miss/evict` DEBUG 日志并写入 probe log。
- 接线：
  - 媒体选择后落盘改为按类型缓存目录（image/video）；
  - 本地媒体 URL 解析接入缓存命中统计；
  - 媒体 cell 预览本地文件时刷新访问时间，降低误淘汰概率。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（S-4：搜索索引预埋 V1）

- iOS 落地：
  - 新增 `Core/ChatMessageSearchIndex.swift`，完成会话内倒排索引基础层；
  - 新增 `ChatMessageSearchRemoteDataSource` 协议，预埋远端补偿查询扩展点；
  - `OpenIMChatStore` 接入索引更新与清理链路，并提供 `searchMessages(...)`（本地优先 + 远端补偿）；
  - `RaverChatDataProvider` / `RaverChatController` 增加搜索接口透传，为 F11 UI 接线做准备。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
  - 结果：`BUILD SUCCEEDED`（仅既有 Pods deployment target warning）。

### 2026-04-24（S-5：数据治理与容量策略 V1）

- iOS 落地：
  - 新增 `OpenIMStorageGovernance`（本地 OpenIM 库 / 媒体缓存 / probe 日志容量审计）；
  - 审计阈值：OpenIM 数据目录 `warn >= 1GiB`、`critical >= 2GiB`；
  - `openim-probe.log` 超过 4MiB 自动裁剪到 1MiB；
  - `AppState` 启动与前台激活接入治理触发（10 分钟节流）。
- 缓存治理补充：
  - `ChatMediaTempFileStore` 对外开放 `performMaintenance(force:)` 与 `managedRootURL()`，用于统一维护与统计。
- Runbook：
  - 新增 `docs/OPENIM_STORAGE_GOVERNANCE_RUNBOOK.md`。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
  - 结果：`BUILD SUCCEEDED`。

### 2026-04-24（F11 第一刀：会话内搜索 UI 首版接线）

- iOS 落地：
  - `DemoAlignedChatViewController` 新增会话内搜索入口（导航栏放大镜按钮）；
  - 新增 `DemoAlignedConversationSearchCoordinator`：
    - 关键词输入、执行搜索、空结果/失败提示；
  - 新增 `DemoAlignedChatSearchResultsViewController`：
    - 展示搜索结果列表，支持点击后回跳聊天页并定位消息；
  - `RaverChatCollectionDataSource` 新增 `indexPath(forMessageID:)`，用于结果定位；
  - 聊天页补齐“定位不到结果时自动尝试一次加载更早历史”的回退链路。
- 构建验证：
  - `xcodegen generate`
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
  - 结果：`BUILD SUCCEEDED`（仅既有 Pods deployment target warning）。

### 2026-04-24（F11 第二刀：搜索结果关键词高亮）

- iOS 落地：
  - `DemoAlignedChatSearchResultsViewController` 新增结果预览高亮；
  - 对关键词命中片段应用 accent 色 + semibold 字重，提升扫描效率。
- 收益：
  - 搜索结果首屏可读性更接近 demo 使用习惯；
  - 定位前的“命中确认成本”更低。

### 2026-04-24（F11 二轮收口：全局搜索入口 + 会话分组结果）

- iOS 落地：
  - `MessagesHomeView` 新增全局搜索入口（导航栏放大镜）；
  - 新增 `MessageGlobalSearchSheet`（SwiftUI）：
    - 支持全局关键词搜索；
    - 按会话分组展示结果；
    - 点击结果可直达对应会话。
  - `MessagesViewModel` 新增跨会话聚合能力：
    - `searchGlobally(query:)`；
    - `GlobalSearchSection` 分组模型；
    - 搜索状态（loading/error/clear）统一管理。
- 构建验证：
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
  - 结果：`BUILD SUCCEEDED`（仅既有 Pods deployment target warning）。
- 阶段判断：
  - F11 已完成“会话内搜索 + 全局入口 + 分组展示”主路径；
  - 后续进入“跨会话结果定位到消息锚点”与搜索专项探针补样。

### 2026-04-24（F11 三轮收口：全局结果点击后消息锚点定位）

- iOS 落地：
  - `OpenIMChatStore` 新增 pending focus 存取能力：
    - `setPendingMessageFocus(messageID:conversationID:)`
    - `consumePendingMessageFocus(for:)`
    - 并在 `reset/clearMessages/removeConversation` 同步清理残留 focus。
  - `MessageGlobalSearchSheet` 点击结果时，先写入 pending focus，再跳转会话。
  - `DemoAlignedChatViewController` 在 `viewDidAppear` 消费 pending focus：
    - 等待 `hasCompletedInitialLoad` 后执行 `revealMessage(withID:allowLoadOlder: true)`；
    - 兼容目标消息尚未在当前窗口时自动补拉历史再定位。
- 构建验证：
  - `xcodebuild -project /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
    - 结果：`BUILD FAILED`（`MJExtension/OpenIMSDK` 链接缺失，属于 project 入口与 Pods 链接差异，不是业务代码错误）。
  - `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`
    - 结果：`BUILD SUCCEEDED`（仅保留既有 Pods deployment target warning）。
- 阶段判断：
  - F11 主链路已覆盖“会话内搜索 + 全局搜索 + 分组展示 + 结果点击定位”。

### 2026-04-24（F11 四轮收口：搜索专项探针可观测性）

- Probe/日志落地：
  - `openim_dual_sim_probe.sh`
    - `FOCUS_REGEX` 纳入 `\[GlobalSearch\]`、`\[DemoAlignedSearch\]`，搜索链路日志会进入 `*.focus.log`。
  - `openim_probe_digest.sh`
    - 新增 F11 指标汇总：
      - `searchGlobal`：`trigger/submit/result/selected/failed`
      - `searchInConversation`：`submit/result/empty/selected/failed`
      - `searchAnchor`：`focusRequest/revealHit/revealMiss/loadOlder/pendingConsume/pendingReveal`
    - `key tail` 增加 `GlobalSearch/DemoAlignedSearch` 关键行。
  - iOS 搜索业务日志已就位（本轮用于 probe 对齐）：
    - `MessagesViewModel`、`MessagesHomeView`
    - `DemoAlignedConversationSearchCoordinator`
    - `DemoAlignedChatSearchResultsViewController`
    - `DemoAlignedChatViewController`
- 脚本校验：
  - `bash -n /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`
  - `bash -n /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh`
  - 结果：均通过。
- 阶段判断：
  - F11 专项探针“可观测性能力”已完成；
  - 剩余仅是补一轮含真实搜索动作的 90s 样本（把新增搜索指标打成非 0 证据）。

### 2026-04-24（A4 弱网回放：服务抖动自动回归）

- 脚本化能力：
  - 新增 `mobile/ios/RaverMVP/scripts/openim_a4_weaknet_replay.sh`：
    - 自动启动双机 probe；
    - 自动执行 OpenIM 短暂停机/恢复（`openim-server/openim-chat`）；
    - 自动执行停机前/恢复后消息注入；
    - 自动 digest 并输出报告目录。
  - Runbook 补充一键入口与参数说明：`docs/OPENIM_DUAL_SIM_BADGE_RUNBOOK.md`（3.3）。
- 回归样本（有效）：
  - `run`: `/Users/blackie/Projects/raver/docs/reports/openim-dual-sim-20260424-223332`
  - `SIM1`: connected=1, realtime=10, catchup=0, login10102=0, unavailable=0
  - `SIM2`: connected=1, realtime=18, catchup=0, login10102=0, unavailable=0
  - digest：`overall: 双侧日志有效，可用于判断实时链路与回退情况。`
  - 弱网抖动证据：两侧可见 `OpenIM state -> failed("dial tcp 127.0.0.1:10001: connect: connection refused")`，恢复后回到 `connected` 且 realtime 继续增长。
- 结论：
  - A4 在“服务抖动 -> 恢复 -> 实时链路回稳”维度通过；
  - `sendFailed/resendFailed/failureHint` 在该样本为 0（该样本主要验证链路恢复，不等价于会话内手动失败重试样本）。

---

## 7) 下一步（固定顺序）

1. F11 专项探针补样（搜索场景）：固定执行“会话内搜索 + 全局搜索 + 结果点击定位”90s 回归，让 `searchGlobal/searchInConversation/searchAnchor` 出现非 0，同时验证 `catchup/login10102/unavailable` 持续为 0。
2. 回归结果写回执行文档并收口 F11 状态（`InProgress -> Done`）。
3. A4 失败提示补样：在会话内补一轮“失败胶囊可见 + 点按重试成功”的最小证据样本（可与下一次日常回归合并）。
